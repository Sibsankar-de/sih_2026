import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../models/fusion_data.dart';
import '../../models/navigation_state.dart';
import '../../models/sensor_data.dart';
import '../../models/simulation_scenario.dart';
import '../../models/speed_estimate.dart';
import '../constants/mock_routes.dart';
import '../utils/geo_utils.dart';
import 'fusion_service.dart';
import 'location_service.dart';
import 'map_matching_service.dart';
import 'mock_ai_service.dart';
import 'sensor_service.dart';
import 'service_interfaces.dart';

class NavigationService extends ChangeNotifier implements INavigationService {
  final ISensorService sensorService;
  final ILocationService locationService;
  final IMockAIService aiService;
  final IFusionService fusionService;
  final IMapMatchingService mapMatchingService;

  late NavigationState _state;
  late SpeedEstimate _latestSpeedEstimate;
  late FusionSnapshot _latestFusionSnapshot;
  late SensorSnapshot _latestSensorSnapshot;

  Timer? _navigationTimer;
  StreamSubscription<SensorSnapshot>? _sensorSubscription;

  // Trajectory history buffers for charts and visualizers
  final List<double> _speedHistory = [];
  final List<double> _confidenceHistory = [];
  final List<double> _driftHistory = [];
  final List<double> _gnssErrorHistory = [];
  final List<double> _fusedErrorHistory = [];

  // Active scenario
  SimulationScenario _currentScenario = SimulationScenario.getAllScenarios().first;
  double _routeProgress = 0.0; // 0.0 to length of route
  final math.Random _random = math.Random();

  NavigationState get state => _state;
  SpeedEstimate get latestSpeedEstimate => _latestSpeedEstimate;
  FusionSnapshot get latestFusionSnapshot => _latestFusionSnapshot;
  SensorSnapshot get latestSensorSnapshot => _latestSensorSnapshot;
  SimulationScenario get currentScenario => _currentScenario;

  List<double> get speedHistory => List.unmodifiable(_speedHistory);
  List<double> get confidenceHistory => List.unmodifiable(_confidenceHistory);
  List<double> get driftHistory => List.unmodifiable(_driftHistory);
  List<double> get gnssErrorHistory => List.unmodifiable(_gnssErrorHistory);
  List<double> get fusedErrorHistory => List.unmodifiable(_fusedErrorHistory);

  NavigationService({
    ISensorService? sensorService,
    ILocationService? locationService,
    IMockAIService? aiService,
    IFusionService? fusionService,
    IMapMatchingService? mapMatchingService,
  })  : sensorService = sensorService ?? SensorService(),
        locationService = locationService ?? LocationService(),
        aiService = aiService ?? MockAIService(),
        fusionService = fusionService ?? FusionService(),
        mapMatchingService = mapMatchingService ?? MapMatchingService() {
    final initialRoute = MockRoutes.standardCityRoute;
    _state = NavigationState.initial(initialRoute);
    _latestSpeedEstimate = SpeedEstimate.initial();
    _latestFusionSnapshot = FusionSnapshot.initial(initialRoute.first);
    _latestSensorSnapshot = SensorSnapshot.initial();

    _sensorSubscription = this.sensorService.sensorStream.listen((snapshot) {
      _latestSensorSnapshot = snapshot;
    });

    _startNavigationLoop();
  }

  void _startNavigationLoop() {
    _navigationTimer?.cancel();
    _navigationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_state.isSimulationActive) return;
      _tickNavigation(0.1);
    });
  }

  void _tickNavigation(double dt) {
    // 1. AI Speed Estimation from sensor stream
    _latestSpeedEstimate = aiService.estimateSpeed(
      _latestSensorSnapshot,
      _state.currentSpeedMs,
    );

    // 2. Advance route progression
    final List<LatLng> route = _state.activeRoute;
    if (route.length < 2) return;

    final double speedMs = _latestSpeedEstimate.predictedSpeedMs;
    final double stepDistMeters = speedMs * dt;

    // Calculate position along polyline
    final LatLng nextGroundTruth = _advanceAlongPolyline(route, stepDistMeters);
    final double targetBearing = mapMatchingService.calculateRouteBearing(nextGroundTruth, route);

    // Calculate heading update
    final double integratedHeading = aiService.estimateHeadingCorrection(
      _latestSensorSnapshot.gyroscope,
      _state.currentHeadingDeg,
      dt,
    );
    final double blendedHeading = 0.8 * targetBearing + 0.2 * integratedHeading;

    // 3. Compute INS Dead Reckoning candidate
    LatLng deadReckonedPos = GeoUtils.computeDeadReckoningStep(
      _state.insPosition,
      blendedHeading,
      stepDistMeters,
    );

    // If GNSS is lost, accumulate simulated lateral bias/drift in INS
    double currentDriftIncrement = 0.02; // baseline drift
    if (_state.isGnssOutageSimulated) {
      currentDriftIncrement = 0.15; // accelerated drift per second
      final double lateralNoiseM = (_random.nextDouble() - 0.5) * 0.4;
      deadReckonedPos = GeoUtils.computeDeadReckoningStep(
        deadReckonedPos,
        (blendedHeading + 90.0) % 360,
        lateralNoiseM,
      );
    }

    // 4. Update GNSS Candidate
    LatLng gnssCandidate;
    if (_state.isGnssOutageSimulated) {
      // In outage, GNSS position freezes or wanders wildly with extreme multipath
      final double gnssWander = (_random.nextDouble() - 0.5) * 4.0;
      gnssCandidate = GeoUtils.computeDeadReckoningStep(_state.gnssPosition, _random.nextDouble() * 360, gnssWander);
    } else {
      // Clean GNSS with minor 0.5m gaussian noise
      final double gnssNoise = (_random.nextDouble() - 0.5) * 0.6;
      gnssCandidate = GeoUtils.computeDeadReckoningStep(nextGroundTruth, 90.0, gnssNoise);
      locationService.updatePosition(gnssCandidate);
    }

    // 5. Extended Kalman Filter Fusion
    _latestFusionSnapshot = fusionService.computeFusion(
      gnssPosition: gnssCandidate,
      deadReckonedPosition: deadReckonedPos,
      isGnssValid: !_state.isGnssOutageSimulated,
      insDriftMeters: currentDriftIncrement,
      gnssAccuracy: locationService.gnssAccuracyMeters,
      dt: dt,
    );

    // 6. Map Matching (Snap to road centerline)
    final LatLng snappedPos = mapMatchingService.matchToRoute(_latestFusionSnapshot.fusedPosition, route);

    // 7. Update Historical Trail lists
    final updatedHistory = List<LatLng>.from(_state.historicalTrail);
    final updatedGnssTrail = List<LatLng>.from(_state.gnssTrail);
    final updatedInsTrail = List<LatLng>.from(_state.insTrail);

    if (updatedHistory.length > 150) updatedHistory.removeAt(0);
    if (updatedGnssTrail.length > 150) updatedGnssTrail.removeAt(0);
    if (updatedInsTrail.length > 150) updatedInsTrail.removeAt(0);

    updatedHistory.add(_latestFusionSnapshot.fusedPosition);
    updatedGnssTrail.add(gnssCandidate);
    updatedInsTrail.add(deadReckonedPos);

    // 8. Update rolling telemetry histories for charts
    _updateTelemetryBuffers(speedMs, _latestSpeedEstimate.confidenceScore, _latestFusionSnapshot);

    // 9. Update State
    _state = _state.copyWith(
      currentPosition: _latestFusionSnapshot.fusedPosition,
      gnssPosition: gnssCandidate,
      insPosition: deadReckonedPos,
      snappedPosition: snappedPos,
      currentSpeedMs: speedMs,
      currentHeadingDeg: blendedHeading,
      driftEstimateMeters: _latestFusionSnapshot.estimatedDriftMeters,
      positionAccuracyMeters: _state.isGnssOutageSimulated ? _latestFusionSnapshot.estimatedDriftMeters + 1.2 : 1.8,
      navMode: _latestFusionSnapshot.activeMode,
      gnssHealth: _state.isGnssOutageSimulated ? SignalHealth.lost : SignalHealth.excellent,
      insHealth: SignalHealth.excellent,
      fusionHealth: _state.isGnssOutageSimulated ? SignalHealth.degraded : SignalHealth.excellent,
      historicalTrail: updatedHistory,
      gnssTrail: updatedGnssTrail,
      insTrail: updatedInsTrail,
    );

    notifyListeners();
  }

  LatLng _advanceAlongPolyline(List<LatLng> polyline, double distMeters) {
    if (polyline.length < 2) return polyline.first;

    _routeProgress += distMeters;

    double accumulated = 0.0;
    for (int i = 0; i < polyline.length - 1; i++) {
      final double segmentLen = GeoUtils.calculateDistance(polyline[i], polyline[i + 1]);
      if (accumulated + segmentLen >= _routeProgress) {
        final double remaining = _routeProgress - accumulated;
        final double ratio = (segmentLen > 0) ? (remaining / segmentLen).clamp(0.0, 1.0) : 0.0;
        final double lat = polyline[i].latitude + ratio * (polyline[i + 1].latitude - polyline[i].latitude);
        final double lon = polyline[i].longitude + ratio * (polyline[i + 1].longitude - polyline[i].longitude);
        return LatLng(lat, lon);
      }
      accumulated += segmentLen;
    }

    // Loop back to start if end of route reached
    _routeProgress = 0.0;
    return polyline.first;
  }

  void _updateTelemetryBuffers(double speed, double confidence, FusionSnapshot fusion) {
    _speedHistory.add(speed * 3.6); // in km/h
    _confidenceHistory.add(confidence * 100); // percentage
    _driftHistory.add(fusion.estimatedDriftMeters);
    _gnssErrorHistory.add(fusion.gnssAccuracyMeters);
    _fusedErrorHistory.add(fusion.estimatedDriftMeters * 0.4);

    if (_speedHistory.length > 40) _speedHistory.removeAt(0);
    if (_confidenceHistory.length > 40) _confidenceHistory.removeAt(0);
    if (_driftHistory.length > 40) _driftHistory.removeAt(0);
    if (_gnssErrorHistory.length > 40) _gnssErrorHistory.removeAt(0);
    if (_fusedErrorHistory.length > 40) _fusedErrorHistory.removeAt(0);
  }

  @override
  void simulateGnssLoss() {
    locationService.simulateGnssLoss();
    _state = _state.copyWith(
      isGnssOutageSimulated: true,
      gnssHealth: SignalHealth.lost,
      navMode: NavMode.deadReckoning,
    );
    notifyListeners();
  }

  @override
  void restoreGnss() {
    locationService.restoreGnss();
    fusionService.resetFilter(_state.snappedPosition);
    _state = _state.copyWith(
      isGnssOutageSimulated: false,
      gnssHealth: SignalHealth.excellent,
      navMode: NavMode.fusedEkf,
      insPosition: _state.snappedPosition,
      currentPosition: _state.snappedPosition,
      driftEstimateMeters: 0.12,
    );
    notifyListeners();
  }

  @override
  void switchScenario(String scenarioId) {
    final scenarios = SimulationScenario.getAllScenarios();
    final selected = scenarios.firstWhere(
      (s) => s.type.name == scenarioId,
      orElse: () => scenarios.first,
    );

    _currentScenario = selected;
    _routeProgress = 0.0;
    fusionService.resetFilter(selected.waypoints.first);

    _state = NavigationState.initial(selected.waypoints).copyWith(
      activeRoute: selected.waypoints,
      currentPosition: selected.waypoints.first,
      gnssPosition: selected.waypoints.first,
      insPosition: selected.waypoints.first,
      snappedPosition: selected.waypoints.first,
    );

    notifyListeners();
  }

  @override
  void toggleSimulation(bool running) {
    _state = _state.copyWith(isSimulationActive: running);
    notifyListeners();
  }

  @override
  void resetNavigation() {
    _routeProgress = 0.0;
    final firstPoint = _state.activeRoute.isNotEmpty ? _state.activeRoute.first : const LatLng(28.6139, 77.2090);
    fusionService.resetFilter(firstPoint);
    _state = NavigationState.initial(_state.activeRoute);
    _speedHistory.clear();
    _confidenceHistory.clear();
    _driftHistory.clear();
    _gnssErrorHistory.clear();
    _fusedErrorHistory.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _sensorSubscription?.cancel();
    sensorService.dispose();
    locationService.dispose();
    super.dispose();
  }
}
