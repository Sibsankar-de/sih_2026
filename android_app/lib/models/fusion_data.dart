import 'package:latlong2/latlong.dart';

enum NavMode {
  gnssOnly,
  deadReckoning,
  fusedEkf,
}

class FusionSnapshot {
  final DateTime timestamp;
  final LatLng gnssPosition;
  final LatLng insPosition;
  final LatLng fusedPosition;
  final double gnssAccuracyMeters;
  final double estimatedDriftMeters;
  final double errorReductionPercentage; // e.g. 78.4%
  final double kalmanGainWeight;         // dynamic gain alpha (0..1)
  final NavMode activeMode;
  final int visibleSatellites;
  final double hdop;

  // Real 8-state EKF telemetry
  final String fusionModeName;    // 'GNSS_AIDED', 'DEAD_RECKONING', 'GNSS_DEGRADED', etc.
  final String gnssQualityName;   // 'AVAILABLE', 'DEGRADED', 'LOST'
  final double positionSigmaMeters;
  final double velocitySigmaMps;
  final double headingSigmaRad;
  final double accelBiasX;
  final double accelBiasY;
  final double gyroBias;
  final double eastMeters;
  final double northMeters;
  final int imuProcessedCount;
  final int gnssAppliedCount;
  final int gnssRejectedCount;
  final int mlAppliedCount;
  final int nhcAppliedCount;
  final int zuptAppliedCount;

  const FusionSnapshot({
    required this.timestamp,
    required this.gnssPosition,
    required this.insPosition,
    required this.fusedPosition,
    required this.gnssAccuracyMeters,
    required this.estimatedDriftMeters,
    required this.errorReductionPercentage,
    required this.kalmanGainWeight,
    required this.activeMode,
    required this.visibleSatellites,
    required this.hdop,
    this.fusionModeName = 'GNSS_AIDED',
    this.gnssQualityName = 'AVAILABLE',
    this.positionSigmaMeters = 1.2,
    this.velocitySigmaMps = 0.2,
    this.headingSigmaRad = 0.05,
    this.accelBiasX = 0.0,
    this.accelBiasY = 0.0,
    this.gyroBias = 0.0,
    this.eastMeters = 0.0,
    this.northMeters = 0.0,
    this.imuProcessedCount = 0,
    this.gnssAppliedCount = 0,
    this.gnssRejectedCount = 0,
    this.mlAppliedCount = 0,
    this.nhcAppliedCount = 0,
    this.zuptAppliedCount = 0,
  });

  factory FusionSnapshot.initial(LatLng defaultPos) {
    return FusionSnapshot(
      timestamp: DateTime.now(),
      gnssPosition: defaultPos,
      insPosition: defaultPos,
      fusedPosition: defaultPos,
      gnssAccuracyMeters: 2.1,
      estimatedDriftMeters: 0.12,
      errorReductionPercentage: 84.5,
      kalmanGainWeight: 0.85,
      activeMode: NavMode.fusedEkf,
      visibleSatellites: 14,
      hdop: 0.8,
      fusionModeName: 'GNSS_AIDED',
      gnssQualityName: 'AVAILABLE',
      positionSigmaMeters: 1.2,
      velocitySigmaMps: 0.2,
      headingSigmaRad: 0.04,
      accelBiasX: 0.0,
      accelBiasY: 0.0,
      gyroBias: 0.0,
      eastMeters: 0.0,
      northMeters: 0.0,
      imuProcessedCount: 0,
      gnssAppliedCount: 0,
      gnssRejectedCount: 0,
      mlAppliedCount: 0,
      nhcAppliedCount: 0,
      zuptAppliedCount: 0,
    );
  }
}
