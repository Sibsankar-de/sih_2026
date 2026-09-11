import 'dart:math' as math;

// State dimensions
const int kStateDim = 8;

// State vector indices
const int kIdxPx = 0;   // Position East (m)
const int kIdxPy = 1;   // Position North (m)
const int kIdxVx = 2;   // Velocity East (m/s)
const int kIdxVy = 3;   // Velocity North (m/s)
const int kIdxYaw = 4;  // Heading (rad), counter-clockwise from East
const int kIdxBax = 5;  // Accel bias X (m/s^2)
const int kIdxBay = 6;  // Accel bias Y (m/s^2)
const int kIdxBg = 7;   // Gyro bias Z (rad/s)

const double kEarthRadiusWgs84 = 6378137.0; // WGS84 semi-major axis [m]
const double kDegToRad = math.pi / 180.0;
const double kRadToDeg = 180.0 / math.pi;

double wrapAngle(double angle) {
  while (angle > math.pi) {
    angle -= 2.0 * math.pi;
  }
  while (angle < -math.pi) {
    angle += 2.0 * math.pi;
  }
  return angle;
}

class IMUSample {
  final double timestamp; // seconds
  final double accelX;   // vehicle horizontal forward/lateral accel [m/s^2]
  final double accelY;
  final double gyroZ;    // vehicle yaw rate [rad/s]

  const IMUSample({
    required this.timestamp,
    required this.accelX,
    required this.accelY,
    required this.gyroZ,
  });
}

class GNSSMeasurement {
  final double timestamp;
  final double latitudeDeg;
  final double longitudeDeg;
  final double horizontalAccuracyM;
  final bool hasVelocity;
  final double velocityEastMps;
  final double velocityNorthMps;
  final double velocityAccuracyMps;
  final bool hasCourse;
  final double courseRad; // heading from GNSS [rad]
  final bool valid;

  const GNSSMeasurement({
    required this.timestamp,
    required this.latitudeDeg,
    required this.longitudeDeg,
    required this.horizontalAccuracyM,
    this.hasVelocity = false,
    this.velocityEastMps = 0.0,
    this.velocityNorthMps = 0.0,
    this.velocityAccuracyMps = 0.5,
    this.hasCourse = false,
    this.courseRad = 0.0,
    this.valid = true,
  });
}

class MLVelocityMeasurement {
  final double timestamp;
  final double forwardVelocityMps;
  final double confidence; // [0.0, 1.0]
  final double sigmaMps;
  final bool valid;

  const MLVelocityMeasurement({
    required this.timestamp,
    required this.forwardVelocityMps,
    required this.confidence,
    this.sigmaMps = 0.5,
    this.valid = true,
  });
}

class VibrationInfo {
  final double timestamp;
  final double noiseScore; // [0.0, 1.0]
  final bool severeVibration;
  final double confidence;

  const VibrationInfo({
    required this.timestamp,
    required this.noiseScore,
    this.severeVibration = false,
    this.confidence = 1.0,
  });
}

class MapConstraint {
  final double timestamp;
  final double crossTrackErrorM;
  final double roadHeadingRad;
  final double confidence;
  final bool valid;

  const MapConstraint({
    required this.timestamp,
    required this.crossTrackErrorM,
    required this.roadHeadingRad,
    this.confidence = 1.0,
    this.valid = true,
  });
}

enum FusionMode {
  uninitialized,
  initializing,
  gnssAided,
  gnssDegraded,
  deadReckoning,
  gnssReacquiring,
  error,
}

enum GNSSQuality {
  available,
  degraded,
  lost,
}

class FusionStatus {
  FusionMode mode;
  GNSSQuality gnssQuality;
  double lastGnssTimestamp;
  double gnssOutageDuration;
  int imuSamplesProcessed;
  int gnssUpdatesApplied;
  int gnssUpdatesRejected;
  int mlUpdatesApplied;
  int mlUpdatesRejected;
  int nhcUpdatesApplied;
  int zuptUpdatesApplied;

  FusionStatus({
    this.mode = FusionMode.uninitialized,
    this.gnssQuality = GNSSQuality.lost,
    this.lastGnssTimestamp = 0.0,
    this.gnssOutageDuration = 0.0,
    this.imuSamplesProcessed = 0,
    this.gnssUpdatesApplied = 0,
    this.gnssUpdatesRejected = 0,
    this.mlUpdatesApplied = 0,
    this.mlUpdatesRejected = 0,
    this.nhcUpdatesApplied = 0,
    this.zuptUpdatesApplied = 0,
  });
}

class EkfNavigationState {
  final double timestamp;
  final double latitudeDeg;
  final double longitudeDeg;
  final double eastM;
  final double northM;
  final double velocityEastMps;
  final double velocityNorthMps;
  final double speedMps;
  final double headingRad;
  final double headingDeg;
  final double positionSigmaM;
  final double velocitySigmaMps;
  final double headingSigmaRad;
  final double accelBiasX;
  final double accelBiasY;
  final double gyroBias;
  final bool gnssAvailable;
  final bool deadReckoning;

  const EkfNavigationState({
    required this.timestamp,
    required this.latitudeDeg,
    required this.longitudeDeg,
    required this.eastM,
    required this.northM,
    required this.velocityEastMps,
    required this.velocityNorthMps,
    required this.speedMps,
    required this.headingRad,
    required this.headingDeg,
    required this.positionSigmaM,
    required this.velocitySigmaMps,
    required this.headingSigmaRad,
    required this.accelBiasX,
    required this.accelBiasY,
    required this.gyroBias,
    required this.gnssAvailable,
    required this.deadReckoning,
  });

  factory EkfNavigationState.zero() {
    return const EkfNavigationState(
      timestamp: 0.0,
      latitudeDeg: 0.0,
      longitudeDeg: 0.0,
      eastM: 0.0,
      northM: 0.0,
      velocityEastMps: 0.0,
      velocityNorthMps: 0.0,
      speedMps: 0.0,
      headingRad: 0.0,
      headingDeg: 0.0,
      positionSigmaM: 0.0,
      velocitySigmaMps: 0.0,
      headingSigmaRad: 0.0,
      accelBiasX: 0.0,
      accelBiasY: 0.0,
      gyroBias: 0.0,
      gnssAvailable: false,
      deadReckoning: false,
    );
  }
}

class ProcessNoiseParameters {
  double accelNoise;             // m/s^2/sqrt(Hz)
  double gyroNoise;              // rad/s/sqrt(Hz)
  double accelBiasRandomWalk;    // m/s^3/sqrt(Hz)
  double gyroBiasRandomWalk;     // rad/s^2/sqrt(Hz)

  ProcessNoiseParameters({
    this.accelNoise = 0.5,
    this.gyroNoise = 0.01,
    this.accelBiasRandomWalk = 0.001,
    this.gyroBiasRandomWalk = 0.0001,
  });
}

class GatingThresholds {
  double gnssPosition;   // chi-square for 2-DOF (e.g. 25.0)
  double gnssVelocity;   // chi-square for 2-DOF (e.g. 16.0)
  double gnssCourse;     // chi-square for 1-DOF (e.g. 9.0)
  double mlVelocity;     // chi-square for 1-DOF (e.g. 9.0)
  double nhc;            // chi-square for 1-DOF (e.g. 9.0)
  double zupt;           // chi-square for 2-DOF (e.g. 16.0)
  double mapConstraint;  // chi-square for 1-DOF (e.g. 9.0)

  GatingThresholds({
    this.gnssPosition = 25.0,
    this.gnssVelocity = 16.0,
    this.gnssCourse = 9.0,
    this.mlVelocity = 9.0,
    this.nhc = 9.0,
    this.zupt = 16.0,
    this.mapConstraint = 9.0,
  });
}

class FusionConfig {
  ProcessNoiseParameters processNoise;
  GatingThresholds gating;

  double gnssMinAccuracyM;
  double gnssMinVelocityAccuracy;
  double gnssOutageTimeoutS;
  double gnssMaxInnovationM;
  double gnssMinCourseSpeedMps;

  double mlMinSigma;
  double mlMaxSigma;
  double mlMaxVelocity;

  double nhcSigma;
  double nhcSigmaDegraded;

  double zuptSigma;
  double zuptAccelThreshold;
  double zuptGyroThreshold;
  double zuptSpeedThreshold;

  double minNoiseScale;
  double maxNoiseScale;

  double maxImuDt;

  double mapCrossTrackSigma;
  double mapHeadingSigma;

  double initPositionSigma;
  double initVelocitySigma;
  double initYawSigma;
  double initAccelBiasSigma;
  double initGyroBiasSigma;
  double initMinCourseSpeed;

  FusionConfig({
    ProcessNoiseParameters? processNoise,
    GatingThresholds? gating,
    this.gnssMinAccuracyM = 1.0,
    this.gnssMinVelocityAccuracy = 0.1,
    this.gnssOutageTimeoutS = 5.0,
    this.gnssMaxInnovationM = 100.0,
    this.gnssMinCourseSpeedMps = 3.0,
    this.mlMinSigma = 0.1,
    this.mlMaxSigma = 10.0,
    this.mlMaxVelocity = 80.0,
    this.nhcSigma = 0.1,
    this.nhcSigmaDegraded = 1.0,
    this.zuptSigma = 0.01,
    this.zuptAccelThreshold = 0.3,
    this.zuptGyroThreshold = 0.05,
    this.zuptSpeedThreshold = 0.5,
    this.minNoiseScale = 1.0,
    this.maxNoiseScale = 10.0,
    this.maxImuDt = 0.5,
    this.mapCrossTrackSigma = 2.0,
    this.mapHeadingSigma = 0.1,
    this.initPositionSigma = 10.0,
    this.initVelocitySigma = 1.0,
    this.initYawSigma = math.pi,
    this.initAccelBiasSigma = 0.5,
    this.initGyroBiasSigma = 0.05,
    this.initMinCourseSpeed = 2.0,
  })  : processNoise = processNoise ?? ProcessNoiseParameters(),
        gating = gating ?? GatingThresholds();
}
