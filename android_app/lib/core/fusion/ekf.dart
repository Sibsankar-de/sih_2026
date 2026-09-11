import 'dart:math' as math;
import 'fusion_types.dart';
import 'matrix_math.dart';

/// 8-State Extended Kalman Filter for 2D Vehicle Dead Reckoning.
///
/// State: [px, py, vx, vy, yaw, bax, bay, bg]
class EKF {
  final List<double> _x = List<double>.filled(kStateDim, 0.0);
  final List<double> _p = MatrixMath.identity8();
  late FusionConfig _config;

  double _lastTimestamp = 0.0;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  double get lastTimestamp => _lastTimestamp;

  List<double> get state => List.unmodifiable(_x);
  List<double> get covariance => List.unmodifiable(_p);

  double get px => _x[kIdxPx];
  double get py => _x[kIdxPy];
  double get vx => _x[kIdxVx];
  double get vy => _x[kIdxVy];
  double get yaw => _x[kIdxYaw];
  double get bax => _x[kIdxBax];
  double get bay => _x[kIdxBay];
  double get bg => _x[kIdxBg];

  double get speed => math.sqrt(_x[kIdxVx] * _x[kIdxVx] + _x[kIdxVy] * _x[kIdxVy]);
  double get positionSigma => math.sqrt(_p[kIdxPx * 8 + kIdxPx] + _p[kIdxPy * 8 + kIdxPy]);
  double get velocitySigma => math.sqrt(_p[kIdxVx * 8 + kIdxVx] + _p[kIdxVy * 8 + kIdxVy]);
  double get headingSigma => math.sqrt(_p[kIdxYaw * 8 + kIdxYaw]);

  EKF([FusionConfig? config]) {
    _config = config ?? FusionConfig();
  }

  void initialize(List<double> initialState, FusionConfig config) {
    _config = config;
    for (int i = 0; i < kStateDim; i++) {
      _x[i] = i < initialState.length ? initialState[i] : 0.0;
    }
    _x[kIdxYaw] = wrapAngle(_x[kIdxYaw]);

    for (int i = 0; i < 64; i++) {
      _p[i] = 0.0;
    }
    _p[kIdxPx * 8 + kIdxPx] = _config.initPositionSigma * _config.initPositionSigma;
    _p[kIdxPy * 8 + kIdxPy] = _config.initPositionSigma * _config.initPositionSigma;
    _p[kIdxVx * 8 + kIdxVx] = _config.initVelocitySigma * _config.initVelocitySigma;
    _p[kIdxVy * 8 + kIdxVy] = _config.initVelocitySigma * _config.initVelocitySigma;
    _p[kIdxYaw * 8 + kIdxYaw] = _config.initYawSigma * _config.initYawSigma;
    _p[kIdxBax * 8 + kIdxBax] = _config.initAccelBiasSigma * _config.initAccelBiasSigma;
    _p[kIdxBay * 8 + kIdxBay] = _config.initAccelBiasSigma * _config.initAccelBiasSigma;
    _p[kIdxBg * 8 + kIdxBg] = _config.initGyroBiasSigma * _config.initGyroBiasSigma;

    _lastTimestamp = 0.0;
    _initialized = true;
  }

  /// Predict state forward using an IMU sample
  bool predict(IMUSample imu, [double noiseScale = 1.0]) {
    if (!_initialized) return false;

    if (_lastTimestamp == 0.0) {
      _lastTimestamp = imu.timestamp;
      return true;
    }

    final double dt = imu.timestamp - _lastTimestamp;
    if (dt <= 0.0 || dt > _config.maxImuDt) {
      _lastTimestamp = imu.timestamp;
      return false;
    }

    if (!imu.accelX.isFinite || !imu.accelY.isFinite || !imu.gyroZ.isFinite) {
      return false;
    }

    // 1. Bias-corrected acceleration and angular rate
    final double ax = imu.accelX - _x[kIdxBax];
    final double ay = imu.accelY - _x[kIdxBay];
    final double omega = imu.gyroZ - _x[kIdxBg];

    // 2. Rotate to ENU frame
    final double cy = math.cos(_x[kIdxYaw]);
    final double sy = math.sin(_x[kIdxYaw]);

    final double aE = cy * ax - sy * ay;
    final double aN = sy * ax + cy * ay;

    // 3. State propagation
    final double dt2 = dt * dt;
    _x[kIdxPx] += _x[kIdxVx] * dt + 0.5 * aE * dt2;
    _x[kIdxPy] += _x[kIdxVy] * dt + 0.5 * aN * dt2;
    _x[kIdxVx] += aE * dt;
    _x[kIdxVy] += aN * dt;
    _x[kIdxYaw] += omega * dt;
    _x[kIdxYaw] = wrapAngle(_x[kIdxYaw]);

    // 4. Compute Jacobian F
    final f = _computeF(dt, ax, ay, cy, sy);

    // 5. Compute Process Noise Q
    final q = _computeQ(dt, cy, sy, noiseScale);

    // 6. Propagate Covariance: P = F * P * F^T + Q
    final pNext = MatrixMath.propagateCovariance(f, _p, q);
    for (int i = 0; i < 64; i++) {
      _p[i] = pNext[i];
    }

    _lastTimestamp = imu.timestamp;
    return true;
  }

  List<double> _computeF(double dt, double ax, double ay, double cy, double sy) {
    final f = MatrixMath.identity8();
    final double dt2 = 0.5 * dt * dt;

    f[kIdxPx * 8 + kIdxVx] = dt;
    f[kIdxPy * 8 + kIdxVy] = dt;

    final double daeDyaw = -sy * ax - cy * ay;
    final double danDyaw =  cy * ax - sy * ay;

    f[kIdxPx * 8 + kIdxYaw] = daeDyaw * dt2;
    f[kIdxPy * 8 + kIdxYaw] = danDyaw * dt2;
    f[kIdxVx * 8 + kIdxYaw] = daeDyaw * dt;
    f[kIdxVy * 8 + kIdxYaw] = danDyaw * dt;

    f[kIdxPx * 8 + kIdxBax] = -cy * dt2;
    f[kIdxPx * 8 + kIdxBay] =  sy * dt2;
    f[kIdxPy * 8 + kIdxBax] = -sy * dt2;
    f[kIdxPy * 8 + kIdxBay] = -cy * dt2;

    f[kIdxVx * 8 + kIdxBax] = -cy * dt;
    f[kIdxVx * 8 + kIdxBay] =  sy * dt;
    f[kIdxVy * 8 + kIdxBax] = -sy * dt;
    f[kIdxVy * 8 + kIdxBay] = -cy * dt;

    f[kIdxYaw * 8 + kIdxBg] = -dt;

    return f;
  }

  List<double> _computeQ(double dt, double cy, double sy, double noiseScale) {
    final double scale = noiseScale.clamp(_config.minNoiseScale, _config.maxNoiseScale);
    final double nAx = _config.processNoise.accelNoise * scale;
    final double nAy = _config.processNoise.accelNoise * scale;
    final double nGz = _config.processNoise.gyroNoise * scale;
    final double nBax = _config.processNoise.accelBiasRandomWalk * scale;
    final double nBay = _config.processNoise.accelBiasRandomWalk * scale;
    final double nBgz = _config.processNoise.gyroBiasRandomWalk * scale;

    // Qc diagonal variances
    final qc = [
      nAx * nAx,
      nAy * nAy,
      nGz * nGz,
      nBax * nBax,
      nBay * nBay,
      nBgz * nBgz,
    ];

    // G: 8x6 mapping matrix
    // Row 0: PX, Row 1: PY, Row 2: VX, Row 3: VY, Row 4: YAW, Row 5: BAX, Row 6: BAY, Row 7: BG
    final g = List<double>.filled(48, 0.0); // 8 rows x 6 cols
    final double dt2 = 0.5 * dt;

    g[kIdxPx * 6 + 0] =  dt2 * cy;
    g[kIdxPx * 6 + 1] = -dt2 * sy;
    g[kIdxPy * 6 + 0] =  dt2 * sy;
    g[kIdxPy * 6 + 1] =  dt2 * cy;

    g[kIdxVx * 6 + 0] =  cy;
    g[kIdxVx * 6 + 1] = -sy;
    g[kIdxVy * 6 + 0] =  sy;
    g[kIdxVy * 6 + 1] =  cy;

    g[kIdxYaw * 6 + 2] = 1.0;
    g[kIdxBax * 6 + 3] = 1.0;
    g[kIdxBay * 6 + 4] = 1.0;
    g[kIdxBg  * 6 + 5] = 1.0;

    // Q = G * Qc * G^T * dt
    final q = List<double>.filled(64, 0.0);
    for (int i = 0; i < 8; i++) {
      final int i6 = i * 6;
      final int i8 = i * 8;
      for (int j = 0; j < 8; j++) {
        final int j6 = j * 6;
        double sum = 0.0;
        for (int k = 0; k < 6; k++) {
          sum += g[i6 + k] * qc[k] * g[j6 + k];
        }
        q[i8 + j] = sum * dt;
      }
    }
    return q;
  }

  // --- Measurement Updates ---

  /// GNSS Position Update (2D ENU)
  bool updateGNSSPosition(List<double> posEnu, double accuracyM) {
    if (!_initialized) return false;
    if (!posEnu[0].isFinite || !posEnu[1].isFinite || !accuracyM.isFinite) return false;

    final innovation = [posEnu[0] - _x[kIdxPx], posEnu[1] - _x[kIdxPy]];

    final h = List<double>.filled(16, 0.0); // 2 rows x 8 cols
    h[0 * 8 + kIdxPx] = 1.0;
    h[1 * 8 + kIdxPy] = 1.0;

    final double sigma = math.max(accuracyM, _config.gnssMinAccuracyM);
    final rDiag = [sigma * sigma, sigma * sigma];

    return MatrixMath.applyUpdate2D(
      state: _x,
      covariance: _p,
      h: h,
      innovation: innovation,
      rDiag: rDiag,
      gateThreshold: _config.gating.gnssPosition,
    );
  }

  /// GNSS Velocity Update (2D ENU)
  bool updateGNSSVelocity(List<double> velEnu, double accuracyMps) {
    if (!_initialized) return false;
    if (!velEnu[0].isFinite || !velEnu[1].isFinite || !accuracyMps.isFinite) return false;

    final innovation = [velEnu[0] - _x[kIdxVx], velEnu[1] - _x[kIdxVy]];

    final h = List<double>.filled(16, 0.0);
    h[0 * 8 + kIdxVx] = 1.0;
    h[1 * 8 + kIdxVy] = 1.0;

    final double sigma = math.max(accuracyMps, _config.gnssMinVelocityAccuracy);
    final rDiag = [sigma * sigma, sigma * sigma];

    return MatrixMath.applyUpdate2D(
      state: _x,
      covariance: _p,
      h: h,
      innovation: innovation,
      rDiag: rDiag,
      gateThreshold: _config.gating.gnssVelocity,
    );
  }

  /// GNSS Course / Heading Update (1D)
  bool updateGNSSCourse(double courseRad, double accuracyRad) {
    if (!_initialized) return false;
    if (!courseRad.isFinite || !accuracyRad.isFinite) return false;

    final double innovation = wrapAngle(courseRad - _x[kIdxYaw]);

    final h = List<double>.filled(8, 0.0);
    h[kIdxYaw] = 1.0;

    final double r = accuracyRad * accuracyRad;

    return MatrixMath.applyUpdate1D(
      state: _x,
      covariance: _p,
      h: h,
      innovation: innovation,
      r: r,
      gateThreshold: _config.gating.gnssCourse,
    );
  }

  /// ML Forward Velocity Update (1D)
  bool updateMLVelocity(MLVelocityMeasurement ml) {
    if (!_initialized) return false;
    if (!ml.valid || !ml.forwardVelocityMps.isFinite || ml.confidence <= 0.0) return false;
    if (ml.forwardVelocityMps < 0.0 || ml.forwardVelocityMps > _config.mlMaxVelocity) return false;

    final double cy = math.cos(_x[kIdxYaw]);
    final double sy = math.sin(_x[kIdxYaw]);

    // Forward velocity predicted from state
    final double vForwardPred = cy * _x[kIdxVx] + sy * _x[kIdxVy];
    final double innovation = ml.forwardVelocityMps - vForwardPred;

    final h = List<double>.filled(8, 0.0);
    h[kIdxVx] = cy;
    h[kIdxVy] = sy;
    h[kIdxYaw] = -sy * _x[kIdxVx] + cy * _x[kIdxVy];

    final double conf = ml.confidence.clamp(0.01, 1.0);
    double sigmaEffective = ml.sigmaMps / conf;
    sigmaEffective = sigmaEffective.clamp(_config.mlMinSigma, _config.mlMaxSigma);
    final double r = sigmaEffective * sigmaEffective;

    return MatrixMath.applyUpdate1D(
      state: _x,
      covariance: _p,
      h: h,
      innovation: innovation,
      r: r,
      gateThreshold: _config.gating.mlVelocity,
    );
  }

  /// Non-Holonomic Constraint (lateral velocity = 0)
  bool updateNHC(double sigma) {
    if (!_initialized) return false;
    if (!sigma.isFinite || sigma <= 0.0) return false;

    final double cy = math.cos(_x[kIdxYaw]);
    final double sy = math.sin(_x[kIdxYaw]);

    // Lateral velocity
    final double vLateral = -sy * _x[kIdxVx] + cy * _x[kIdxVy];
    final double innovation = 0.0 - vLateral;

    final h = List<double>.filled(8, 0.0);
    h[kIdxVx] = -sy;
    h[kIdxVy] =  cy;
    h[kIdxYaw] = -cy * _x[kIdxVx] - sy * _x[kIdxVy];

    final double r = sigma * sigma;

    return MatrixMath.applyUpdate1D(
      state: _x,
      covariance: _p,
      h: h,
      innovation: innovation,
      r: r,
      gateThreshold: _config.gating.nhc,
    );
  }

  /// Zero Velocity Update (ZUPT)
  bool updateZUPT(double sigma) {
    if (!_initialized) return false;
    if (!sigma.isFinite || sigma <= 0.0) return false;

    final innovation = [-_x[kIdxVx], -_x[kIdxVy]];

    final h = List<double>.filled(16, 0.0);
    h[0 * 8 + kIdxVx] = 1.0;
    h[1 * 8 + kIdxVy] = 1.0;

    final rDiag = [sigma * sigma, sigma * sigma];

    return MatrixMath.applyUpdate2D(
      state: _x,
      covariance: _p,
      h: h,
      innovation: innovation,
      rDiag: rDiag,
      gateThreshold: _config.gating.zupt,
    );
  }

  /// Map Cross-Track Constraint
  bool updateMapCrossTrack(double crossTrackError, double roadHeading, double sigma) {
    if (!_initialized) return false;
    if (!crossTrackError.isFinite || !roadHeading.isFinite || !sigma.isFinite) return false;

    final double innovation = -crossTrackError;

    final h = List<double>.filled(8, 0.0);
    h[kIdxPx] = -math.sin(roadHeading);
    h[kIdxPy] =  math.cos(roadHeading);

    final double r = sigma * sigma;

    return MatrixMath.applyUpdate1D(
      state: _x,
      covariance: _p,
      h: h,
      innovation: innovation,
      r: r,
      gateThreshold: _config.gating.mapConstraint,
    );
  }
}
