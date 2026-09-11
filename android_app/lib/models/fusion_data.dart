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
    );
  }
}
