import 'package:latlong2/latlong.dart';
import '../core/constants/mock_routes.dart';

enum ScenarioType {
  tunnelNavigation,
  parkingGarage,
  urbanCanyon,
  denseForest,
}

class SimulationScenario {
  final ScenarioType type;
  final String title;
  final String description;
  final String badgeText;
  final List<LatLng> waypoints;
  final double expectedOutageDurationSec;
  final double maxExpectedDriftMeters;
  final String environmentChallenge;

  const SimulationScenario({
    required this.type,
    required this.title,
    required this.description,
    required this.badgeText,
    required this.waypoints,
    required this.expectedOutageDurationSec,
    required this.maxExpectedDriftMeters,
    required this.environmentChallenge,
  });

  static List<SimulationScenario> getAllScenarios() {
    return [
      SimulationScenario(
        type: ScenarioType.tunnelNavigation,
        title: 'Scenario 1: Underground Tunnel',
        description: 'Complete GNSS blackout upon entering subterranean vehicular tunnel. High velocity dead reckoning with zero satellite updates.',
        badgeText: 'GNSS Blackout (0 Sats)',
        waypoints: MockRoutes.tunnelRoute,
        expectedOutageDurationSec: 30.0,
        maxExpectedDriftMeters: 4.8,
        environmentChallenge: 'Total signal obstruction, lack of visual landmarks, high reverberation.',
      ),
      SimulationScenario(
        type: ScenarioType.parkingGarage,
        title: 'Scenario 2: Multi-Level Parking Garage',
        description: 'Multi-story concrete structure with tight helical turns and stop-and-go maneuvers. Validates ZUPT zero-velocity updates.',
        badgeText: 'ZUPT & Sharp Rotations',
        waypoints: MockRoutes.parkingGarageRoute,
        expectedOutageDurationSec: 45.0,
        maxExpectedDriftMeters: 3.2,
        environmentChallenge: 'Massive multipath reflections, low speeds, periodic stops, vertical ramp elevation.',
      ),
      SimulationScenario(
        type: ScenarioType.urbanCanyon,
        title: 'Scenario 3: Dense Urban Canyon',
        description: 'High-rise downtown district with glass facades causing extreme multipath pseudorange errors and HDOP spikes.',
        badgeText: 'Severe Multipath & Spoofing',
        waypoints: MockRoutes.urbanCanyonRoute,
        expectedOutageDurationSec: 25.0,
        maxExpectedDriftMeters: 5.5,
        environmentChallenge: 'Multipath signal delay, satellite constellation occlusion, rapid HDOP degradation.',
      ),
      SimulationScenario(
        type: ScenarioType.denseForest,
        title: 'Scenario 4: Dense Forest Canopy',
        description: 'Winding mountain pass beneath thick vegetative canopy causing intermittent signal attenuation and intermittent dropouts.',
        badgeText: 'Intermittent Dropouts',
        waypoints: MockRoutes.denseForestRoute,
        expectedOutageDurationSec: 20.0,
        maxExpectedDriftMeters: 3.9,
        environmentChallenge: 'Foliage attenuation, varying SNR, high-frequency atmospheric fluctuations.',
      ),
    ];
  }
}
