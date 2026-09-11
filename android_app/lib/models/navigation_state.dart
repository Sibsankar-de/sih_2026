import 'package:latlong2/latlong.dart';
import 'fusion_data.dart';

enum SignalHealth {
  excellent,
  degraded,
  lost,
}

class NavigationState {
  final LatLng currentPosition;
  final LatLng gnssPosition;
  final LatLng insPosition;
  final LatLng snappedPosition;
  final double currentSpeedMs;
  final double currentHeadingDeg;
  final double driftEstimateMeters;
  final double positionAccuracyMeters;
  final NavMode navMode;
  final SignalHealth gnssHealth;
  final SignalHealth insHealth;
  final SignalHealth fusionHealth;
  final bool isGnssOutageSimulated;
  final bool isSimulationActive;
  final List<LatLng> activeRoute;
  final List<LatLng> historicalTrail;
  final List<LatLng> gnssTrail;
  final List<LatLng> insTrail;
  final int currentWaypointIndex;

  const NavigationState({
    required this.currentPosition,
    required this.gnssPosition,
    required this.insPosition,
    required this.snappedPosition,
    required this.currentSpeedMs,
    required this.currentHeadingDeg,
    required this.driftEstimateMeters,
    required this.positionAccuracyMeters,
    required this.navMode,
    required this.gnssHealth,
    required this.insHealth,
    required this.fusionHealth,
    required this.isGnssOutageSimulated,
    required this.isSimulationActive,
    required this.activeRoute,
    required this.historicalTrail,
    required this.gnssTrail,
    required this.insTrail,
    required this.currentWaypointIndex,
  });

  factory NavigationState.initial([List<LatLng> initialRoute = const []]) {
    final startPos = initialRoute.isNotEmpty ? initialRoute.first : const LatLng(28.6139, 77.2090);
    return NavigationState(
      currentPosition: startPos,
      gnssPosition: startPos,
      insPosition: startPos,
      snappedPosition: startPos,
      currentSpeedMs: 0.0,
      currentHeadingDeg: 0.0,
      driftEstimateMeters: 0.0,
      positionAccuracyMeters: 1.8,
      navMode: NavMode.fusedEkf,
      gnssHealth: SignalHealth.excellent,
      insHealth: SignalHealth.excellent,
      fusionHealth: SignalHealth.excellent,
      isGnssOutageSimulated: false,
      isSimulationActive: false,
      activeRoute: initialRoute,
      historicalTrail: [startPos],
      gnssTrail: [startPos],
      insTrail: [startPos],
      currentWaypointIndex: 0,
    );
  }

  NavigationState copyWith({
    LatLng? currentPosition,
    LatLng? gnssPosition,
    LatLng? insPosition,
    LatLng? snappedPosition,
    double? currentSpeedMs,
    double? currentHeadingDeg,
    double? driftEstimateMeters,
    double? positionAccuracyMeters,
    NavMode? navMode,
    SignalHealth? gnssHealth,
    SignalHealth? insHealth,
    SignalHealth? fusionHealth,
    bool? isGnssOutageSimulated,
    bool? isSimulationActive,
    List<LatLng>? activeRoute,
    List<LatLng>? historicalTrail,
    List<LatLng>? gnssTrail,
    List<LatLng>? insTrail,
    int? currentWaypointIndex,
  }) {
    return NavigationState(
      currentPosition: currentPosition ?? this.currentPosition,
      gnssPosition: gnssPosition ?? this.gnssPosition,
      insPosition: insPosition ?? this.insPosition,
      snappedPosition: snappedPosition ?? this.snappedPosition,
      currentSpeedMs: currentSpeedMs ?? this.currentSpeedMs,
      currentHeadingDeg: currentHeadingDeg ?? this.currentHeadingDeg,
      driftEstimateMeters: driftEstimateMeters ?? this.driftEstimateMeters,
      positionAccuracyMeters: positionAccuracyMeters ?? this.positionAccuracyMeters,
      navMode: navMode ?? this.navMode,
      gnssHealth: gnssHealth ?? this.gnssHealth,
      insHealth: insHealth ?? this.insHealth,
      fusionHealth: fusionHealth ?? this.fusionHealth,
      isGnssOutageSimulated: isGnssOutageSimulated ?? this.isGnssOutageSimulated,
      isSimulationActive: isSimulationActive ?? this.isSimulationActive,
      activeRoute: activeRoute ?? this.activeRoute,
      historicalTrail: historicalTrail ?? this.historicalTrail,
      gnssTrail: gnssTrail ?? this.gnssTrail,
      insTrail: insTrail ?? this.insTrail,
      currentWaypointIndex: currentWaypointIndex ?? this.currentWaypointIndex,
    );
  }
}
