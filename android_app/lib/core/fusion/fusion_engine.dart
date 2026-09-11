import 'dart:math' as math;
import 'fusion_types.dart';
import 'ekf.dart';
import 'local_frame.dart';
import 'noise_model.dart';

/// Top-level 2D GNSS + IMU + ML Dead Reckoning Fusion Engine.
///
/// Ported from the high-precision C++ fusion engine with exact 8-state EKF,
/// Joseph form updates, Chi-square gating, and adaptive vibration scaling.
class FusionEngine {
  late EKF _ekf;
  final LocalFrame _localFrame = LocalFrame();
  final NoiseModel _noiseModel = NoiseModel();
  late FusionConfig _config;

  FusionMode _mode = FusionMode.uninitialized;
  GNSSQuality _gnssQuality = GNSSQuality.lost;
  final FusionStatus _status = FusionStatus();

  double _lastGnssTime = 0.0;
  double _currentTime = 0.0;
  int _consecutiveGnssRejections = 0;

  bool get isInitialized =>
      _mode != FusionMode.uninitialized &&
      _mode != FusionMode.initializing &&
      _ekf.isInitialized;

  FusionMode get mode => _mode;
  GNSSQuality get gnssQuality => _gnssQuality;
  EKF get ekf => _ekf;
  LocalFrame get localFrame => _localFrame;
  NoiseModel get noiseModel => _noiseModel;
  FusionConfig get config => _config;

  FusionEngine([FusionConfig? config]) {
    initialize(config ?? FusionConfig());
  }

  bool initialize(FusionConfig config) {
    _config = config;
    _ekf = EKF(_config);
    _noiseModel.configure(_config.minNoiseScale, _config.maxNoiseScale);
    _mode = FusionMode.initializing;
    _status.mode = _mode;
    return true;
  }

  /// Process an IMU sample (EKF prediction step)
  bool processIMU(IMUSample sample) {
    if (!sample.timestamp.isFinite || !sample.accelX.isFinite || !sample.accelY.isFinite || !sample.gyroZ.isFinite) {
      return false;
    }

    if (_mode == FusionMode.uninitialized || _mode == FusionMode.initializing) {
      _currentTime = sample.timestamp;
      return false;
    }

    final double noiseScale = _noiseModel.noiseScale;
    if (!_ekf.predict(sample, noiseScale)) {
      return false;
    }

    _currentTime = sample.timestamp;
    _status.imuSamplesProcessed++;

    // Check GNSS timeout
    _updateGNSSQuality(_currentTime, false);
    return true;
  }

  /// Process a GNSS measurement (EKF correction step)
  bool processGNSS(GNSSMeasurement measurement) {
    if (!measurement.valid ||
        !measurement.latitudeDeg.isFinite ||
        !measurement.longitudeDeg.isFinite ||
        measurement.horizontalAccuracyM <= 0.0) {
      return false;
    }

    if (_mode == FusionMode.uninitialized || _mode == FusionMode.initializing) {
      return _tryInitialize(measurement);
    }

    // Convert lat/lon to local ENU
    final posEnu = _localFrame.geoToLocal(measurement.latitudeDeg, measurement.longitudeDeg);
    bool updateApplied = false;

    // Position update
    if (_ekf.updateGNSSPosition(posEnu, measurement.horizontalAccuracyM)) {
      updateApplied = true;
    }

    // Velocity update
    if (measurement.hasVelocity) {
      final velEnu = [measurement.velocityEastMps, measurement.velocityNorthMps];
      if (_ekf.updateGNSSVelocity(velEnu, measurement.velocityAccuracyMps)) {
        updateApplied = true;
      }
    }

    // Course update (only at sufficient vehicle speed)
    if (measurement.hasCourse && _ekf.speed > _config.gnssMinCourseSpeedMps) {
      if (_ekf.updateGNSSCourse(measurement.courseRad, 0.1)) {
        updateApplied = true;
      }
    }

    if (updateApplied) {
      _status.gnssUpdatesApplied++;
      _consecutiveGnssRejections = 0;
    } else {
      _status.gnssUpdatesRejected++;
      _consecutiveGnssRejections++;
    }

    _updateGNSSQuality(measurement.timestamp, updateApplied);
    return updateApplied;
  }

  bool _tryInitialize(GNSSMeasurement gnss) {
    if (!_localFrame.isInitialized) {
      _localFrame.setOrigin(gnss.latitudeDeg, gnss.longitudeDeg);
    }

    final initialState = List<double>.filled(kStateDim, 0.0);
    if (gnss.hasVelocity) {
      initialState[kIdxVx] = gnss.velocityEastMps;
      initialState[kIdxVy] = gnss.velocityNorthMps;
    }

    if (gnss.hasCourse && gnss.hasVelocity) {
      final double spd = math.sqrt(gnss.velocityEastMps * gnss.velocityEastMps + gnss.velocityNorthMps * gnss.velocityNorthMps);
      if (spd > _config.initMinCourseSpeed) {
        initialState[kIdxYaw] = gnss.courseRad;
      }
    }

    _ekf.initialize(initialState, _config);

    _mode = FusionMode.gnssAided;
    _status.mode = _mode;
    _lastGnssTime = gnss.timestamp;
    _currentTime = gnss.timestamp;
    _gnssQuality = GNSSQuality.available;
    _status.gnssQuality = _gnssQuality;
    return true;
  }

  /// Process an ML forward velocity measurement
  bool processMLVelocity(MLVelocityMeasurement measurement) {
    if (!measurement.valid ||
        !measurement.forwardVelocityMps.isFinite ||
        !measurement.confidence.isFinite ||
        measurement.confidence <= 0.0) {
      return false;
    }

    if (!isInitialized) return false;

    if (_ekf.updateMLVelocity(measurement)) {
      _status.mlUpdatesApplied++;
      return true;
    }

    _status.mlUpdatesRejected++;
    return false;
  }

  /// Process vibration information (adaptive noise scaling)
  bool processVibration(VibrationInfo vibration) {
    _noiseModel.updateVibration(vibration);
    return true;
  }

  /// Apply non-holonomic constraint (lateral velocity approx 0)
  bool processNHC() {
    if (!isInitialized) return false;

    final double nhcSigma = _noiseModel.getNHCSigma(_config.nhcSigma, _config.nhcSigmaDegraded);
    if (_ekf.updateNHC(nhcSigma)) {
      _status.nhcUpdatesApplied++;
      return true;
    }
    return false;
  }

  /// Apply zero velocity update (if vehicle is stationary)
  bool processZUPT() {
    if (!isInitialized) return false;

    if (_ekf.updateZUPT(_config.zuptSigma)) {
      _status.zuptUpdatesApplied++;
      return true;
    }
    return false;
  }

  /// Process map cross-track constraint
  bool processMapConstraint(MapConstraint constraint) {
    if (!constraint.valid || !constraint.crossTrackErrorM.isFinite || !constraint.roadHeadingRad.isFinite) {
      return false;
    }
    if (!isInitialized) return false;

    double sigma = _config.mapCrossTrackSigma;
    if (constraint.confidence > 0.0 && constraint.confidence < 1.0) {
      sigma /= math.max(constraint.confidence, 0.1);
    }

    return _ekf.updateMapCrossTrack(constraint.crossTrackErrorM, constraint.roadHeadingRad, sigma);
  }

  /// Get the current navigation state
  EkfNavigationState getState() {
    if (!isInitialized) {
      return EkfNavigationState.zero();
    }

    final double east = _ekf.px;
    final double north = _ekf.py;
    final geo = _localFrame.localToGeo(east, north);

    final double spd = _ekf.speed;
    final double yawRad = _ekf.yaw;
    final double yawDeg = ((yawRad * kRadToDeg) % 360.0 + 360.0) % 360.0;

    return EkfNavigationState(
      timestamp: _ekf.lastTimestamp,
      latitudeDeg: geo[0],
      longitudeDeg: geo[1],
      eastM: east,
      northM: north,
      velocityEastMps: _ekf.vx,
      velocityNorthMps: _ekf.vy,
      speedMps: spd,
      headingRad: yawRad,
      headingDeg: yawDeg,
      positionSigmaM: _ekf.positionSigma,
      velocitySigmaMps: _ekf.velocitySigma,
      headingSigmaRad: _ekf.headingSigma,
      accelBiasX: _ekf.bax,
      accelBiasY: _ekf.bay,
      gyroBias: _ekf.bg,
      gnssAvailable: (_gnssQuality == GNSSQuality.available || _gnssQuality == GNSSQuality.degraded),
      deadReckoning: (_mode == FusionMode.deadReckoning),
    );
  }

  /// Get the current fusion status
  FusionStatus getStatus() {
    _status.mode = _mode;
    _status.gnssQuality = _gnssQuality;
    _status.lastGnssTimestamp = _lastGnssTime;
    _status.gnssOutageDuration = _currentTime - _lastGnssTime;
    return _status;
  }

  void _updateGNSSQuality(double currentTime, bool gnssUpdateApplied) {
    if (gnssUpdateApplied) {
      _lastGnssTime = currentTime;
      _consecutiveGnssRejections = 0;

      if (_mode == FusionMode.deadReckoning) {
        _mode = FusionMode.gnssReacquiring;
      } else {
        _mode = FusionMode.gnssAided;
      }
      _gnssQuality = GNSSQuality.available;
    } else {
      final double timeSinceGnss = currentTime - _lastGnssTime;

      if (_consecutiveGnssRejections >= 5 || timeSinceGnss > _config.gnssOutageTimeoutS) {
        _gnssQuality = GNSSQuality.lost;
        _mode = FusionMode.deadReckoning;
      } else if (timeSinceGnss > 2.0 || _consecutiveGnssRejections >= 2) {
        _gnssQuality = GNSSQuality.degraded;
        if (_mode == FusionMode.gnssAided) {
          _mode = FusionMode.gnssDegraded;
        }
      }
    }
  }

  void reset() {
    _noiseModel.reset();
    _mode = FusionMode.uninitialized;
    _gnssQuality = GNSSQuality.lost;
    _lastGnssTime = 0.0;
    _currentTime = 0.0;
    _consecutiveGnssRejections = 0;
    _localFrame.reset();
  }
}
