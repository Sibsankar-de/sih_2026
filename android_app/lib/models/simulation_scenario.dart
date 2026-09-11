import 'package:latlong2/latlong.dart';
import '../core/constants/mock_routes.dart';

enum ScenarioType {
  tunnelNavigation,
  urbanCanyon,
  iovnbBenchmark,
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
        title: 'Underground Tunnel Outage',
        description: 'Vehicular tunnel where GNSS drops completely to 0 satellites. Demonstrates AI velocity & EKF sustaining the trajectory until tunnel exit.',
        badgeText: 'GNSS Blackout (25s)',
        waypoints: MockRoutes.tunnelRoute,
        expectedOutageDurationSec: 25.0,
        maxExpectedDriftMeters: 4.2,
        environmentChallenge: 'Complete satellite obstruction; dead reckoning relies strictly on AI forward speed and EKF heading.',
      ),
      SimulationScenario(
        type: ScenarioType.urbanCanyon,
        title: 'Dense Urban Canyon',
        description: 'Downtown high-rise corridor with severe multipath reflections. Tests EKF Chi-Square innovation gating rejecting GPS outlier spikes.',
        badgeText: 'Multipath Gating',
        waypoints: MockRoutes.urbanCanyonRoute,
        expectedOutageDurationSec: 20.0,
        maxExpectedDriftMeters: 3.5,
        environmentChallenge: 'Multipath signal delay and false reflections rejected by Chi-square innovation gating.',
      ),
      SimulationScenario(
        type: ScenarioType.iovnbBenchmark,
        title: 'IO-VNBD Vehicle Dataset',
        description: 'Authentic real-world vehicular drive sequence from IO-VNBD Benchmark (Driver A, S1). Real smartphone IMU dynamics fused with RTK reference.',
        badgeText: 'IO-VNBD Benchmark',
        waypoints: MockRoutes.iovnbDriveRoute,
        expectedOutageDurationSec: 30.0,
        maxExpectedDriftMeters: 2.5,
        environmentChallenge: 'Authentic asphalt road vibration, engine dynamics, acceleration curves, and real cornering.',
      ),
    ];
  }
}
