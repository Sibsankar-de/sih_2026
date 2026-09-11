import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../models/fusion_data.dart';
import '../../models/navigation_state.dart';
import '../../models/sensor_data.dart';
import '../../models/simulation_scenario.dart';
import '../../models/speed_estimate.dart';
import '../utils/geo_utils.dart';
import 'fusion_service.dart';
import 'location_service.dart';
import 'map_matching_service.dart';
import 'mock_ai_service.dart';
import 'sensor_service.dart';
import 'service_interfaces.dart';
import '../fusion/fusion_types.dart';

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
  StreamSubscription<LatLng>? _locationSubscription;

  // Telemetry history buffers
  final List<double> _speedHistory = [];
  final List<double> _confidenceHistory = [];
  final List<double> _driftHistory = [];
  final List<double> _gnssErrorHistory = [];
  final List<double> _fusedErrorHistory = [];

  // Active scenario (used when simulation is launched)
  SimulationScenario _currentScenario = SimulationScenario.getAllScenarios().first;
  double _routeProgress = 0.0;
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
    final initialPos = this.locationService.currentGnssPosition;
    _state = NavigationState.initial().copyWith(
      currentPosition: initialPos,
      gnssPosition: initialPos,
      insPosition: initialPos,
      snappedPosition: initialPos,
      isSimulationActive: false,
    );

    _latestSpeedEstimate = SpeedEstimate.initial();
    _latestFusionSnapshot = FusionSnapshot.initial(initialPos);
    _latestSensorSnapshot = SensorSnapshot.initial();

    _sensorSubscription = this.sensorService.sensorStream.listen((snapshot) {
      _latestSensorSnapshot = snapshot;
    });

    _locationSubscription = this.locationService.gnssStream.listen((pos) {
      if (!_state.isSimulationActive) {
        _onLiveLocationUpdate(pos);
      }
    });

    _startNavigationLoop();
  }

  void _startNavigationLoop() {
    _navigationTimer?.cancel();
    _navigationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _tickNavigation(0.1);
    });
  }

  void _onLiveLocationUpdate(LatLng realPos) {
    final double dist = GeoUtils.calculateDistance(_state.currentPosition, realPos);
    double liveSpeed = dist / 1.0; // approximate m/s
    if (dist < 0.5) liveSpeed = 0.0;

    final imuSample = IMUSample(
      timestamp: DateTime.now().millisecondsSinceEpoch / 1000.0,
      accelX: _latestSensorSnapshot.accelerometer.y,
      accelY: _latestSensorSnapshot.accelerometer.x,
      gyroZ: _latestSensorSnapshot.gyroscope.z,
    );

    _latestFusionSnapshot = fusionService.computeFusion(
      gnssPosition: realPos,
      deadReckonedPosition: realPos,
      isGnssValid: true,
      insDriftMeters: 0.0,
      gnssAccuracy: locationService.gnssAccuracyMeters,
      dt: 0.1,
      imuSample: imuSample,
      aiForwardSpeedMs: liveSpeed,
      aiConfidence: _latestSpeedEstimate.confidenceScore,
      vibrationScore: _latestSpeedEstimate.vibrationNoiseScore,
    );

    final updatedHistory = List<LatLng>.from(_state.historicalTrail);
    if (updatedHistory.length > 100) updatedHistory.removeAt(0);
    updatedHistory.add(realPos);

    _state = _state.copyWith(
      currentPosition: realPos,
      gnssPosition: realPos,
      insPosition: realPos,
      snappedPosition: realPos,
      currentSpeedMs: liveSpeed,
      driftEstimateMeters: 0.0,
      positionAccuracyMeters: locationService.gnssAccuracyMeters,
      navMode: NavMode.fusedEkf,
      gnssHealth: SignalHealth.excellent,
      insHealth: SignalHealth.excellent,
      fusionHealth: SignalHealth.excellent,
      historicalTrail: updatedHistory,
    );

    notifyListeners();
  }

  void _tickNavigation(double dt) {
    // 1. Run AI speed & motion inference from streaming IMU
    _latestSpeedEstimate = aiService.estimateSpeed(
      _latestSensorSnapshot,
      _state.currentSpeedMs,
    );

    // If in Live Mode (not in simulation):
    if (!_state.isSimulationActive) {
      final imuSample = IMUSample(
        timestamp: DateTime.now().millisecondsSinceEpoch / 1000.0,
        accelX: _latestSensorSnapshot.accelerometer.y,
        accelY: _latestSensorSnapshot.accelerometer.x,
        gyroZ: _latestSensorSnapshot.gyroscope.z,
      );

      _latestFusionSnapshot = fusionService.computeFusion(
        gnssPosition: _state.gnssPosition,
        deadReckonedPosition: _state.currentPosition,
        isGnssValid: !_state.isGnssOutageSimulated,
        insDriftMeters: _state.isGnssOutageSimulated ? 0.15 : 0.0,
        gnssAccuracy: locationService.gnssAccuracyMeters,
        dt: dt,
        imuSample: imuSample,
        aiForwardSpeedMs: _latestSpeedEstimate.predictedSpeedMs,
        aiConfidence: _latestSpeedEstimate.confidenceScore,
        vibrationScore: _latestSpeedEstimate.vibrationNoiseScore,
      );

      _updateTelemetryBuffers(
        _state.currentSpeedMs,
        _latestSpeedEstimate.confidenceScore,
        _latestFusionSnapshot,
      );

      if (_state.isGnssOutageSimulated) {
        final updatedHistory = List<LatLng>.from(_state.historicalTrail);
        if (updatedHistory.length > 100) updatedHistory.removeAt(0);
        updatedHistory.add(_latestFusionSnapshot.fusedPosition);

        _state = _state.copyWith(
          currentPosition: _latestFusionSnapshot.fusedPosition,
          insPosition: _latestFusionSnapshot.fusedPosition,
          driftEstimateMeters: _latestFusionSnapshot.estimatedDriftMeters,
          navMode: _latestFusionSnapshot.activeMode,
          positionAccuracyMeters: _latestFusionSnapshot.estimatedDriftMeters + 1.5,
          gnssHealth: SignalHealth.lost,
          historicalTrail: updatedHistory,
        );
      } else {
        _state = _state.copyWith(
          driftEstimateMeters: _latestFusionSnapshot.estimatedDriftMeters,
          navMode: _latestFusionSnapshot.activeMode,
          positionAccuracyMeters: 1.8,
          gnssHealth: SignalHealth.excellent,
        );
      }

      notifyListeners();
      return;
    }

    // --- SIMULATION MODE ---
    final List<LatLng> route = _state.activeRoute;
    if (route.length < 2) return;

    // Simulation target speed (~45 km/h = 12.5 m/s)
    const double simSpeedMs = 12.5;
    final double stepDistMeters = simSpeedMs * dt;

    // Advance along route polyline
    final LatLng nextGroundTruth = _advanceAlongPolyline(route, stepDistMeters);
    final double targetBearing = mapMatchingService.calculateRouteBearing(nextGroundTruth, route);

    // Automatic Tunnel / Outage Detection inside simulation:
    // If route progress is between 25% and 75% of route, tunnel has GNSS blackout!
    final double totalRouteDistance = _calculateRouteDistance(route);
    final double progressFraction = totalRouteDistance > 0 ? (_routeProgress / totalRouteDistance).clamp(0.0, 1.0) : 0.0;
    final bool isInSimulatedOutageZone = _currentScenario.type == ScenarioType.tunnelNavigation
        ? (progressFraction > 0.20 && progressFraction < 0.75)
        : _state.isGnssOutageSimulated;

    // Compute dead reckoned candidate with EKF heading
    LatLng deadReckonedPos = GeoUtils.computeDeadReckoningStep(
      _state.insPosition,
      targetBearing,
      stepDistMeters,
    );

    double currentDriftIncrement = 0.02;
    if (isInSimulatedOutageZone) {
      currentDriftIncrement = 0.12;
      final double lateralNoiseM = (_random.nextDouble() - 0.5) * 0.3;
      deadReckonedPos = GeoUtils.computeDeadReckoningStep(
        deadReckonedPos,
        (targetBearing + 90.0) % 360,
        lateralNoiseM,
      );
    }

    // GNSS Candidate
    LatLng gnssCandidate;
    if (isInSimulatedOutageZone) {
      // In outage, GNSS freezes or drifts away
      gnssCandidate = _state.gnssPosition;
    } else {
      // Clean GNSS tracking ground truth
      final double gnssNoise = (_random.nextDouble() - 0.5) * 0.4;
      gnssCandidate = GeoUtils.computeDeadReckoningStep(nextGroundTruth, 90.0, gnssNoise);
    }

    final imuSample = IMUSample(
      timestamp: DateTime.now().millisecondsSinceEpoch / 1000.0,
      accelX: 0.1,
      accelY: 0.05,
      gyroZ: (_random.nextDouble() - 0.5) * 0.05,
    );

    _latestFusionSnapshot = fusionService.computeFusion(
      gnssPosition: gnssCandidate,
      deadReckonedPosition: deadReckonedPos,
      isGnssValid: !isInSimulatedOutageZone,
      insDriftMeters: currentDriftIncrement,
      gnssAccuracy: isInSimulatedOutageZone ? 50.0 : 1.8,
      dt: dt,
      imuSample: imuSample,
      aiForwardSpeedMs: simSpeedMs,
      aiConfidence: 0.95,
      vibrationScore: 0.05,
    );

    final LatLng snappedPos = mapMatchingService.matchToRoute(_latestFusionSnapshot.fusedPosition, route);

    final updatedHistory = List<LatLng>.from(_state.historicalTrail);
    final updatedGnssTrail = List<LatLng>.from(_state.gnssTrail);
    final updatedInsTrail = List<LatLng>.from(_state.insTrail);

    if (updatedHistory.length > 150) updatedHistory.removeAt(0);
    if (updatedGnssTrail.length > 150) updatedGnssTrail.removeAt(0);
    if (updatedInsTrail.length > 150) updatedInsTrail.removeAt(0);

    updatedHistory.add(_latestFusionSnapshot.fusedPosition);
    updatedGnssTrail.add(gnssCandidate);
    updatedInsTrail.add(deadReckonedPos);

    _updateTelemetryBuffers(simSpeedMs, 0.95, _latestFusionSnapshot);

    _state = _state.copyWith(
      currentPosition: _latestFusionSnapshot.fusedPosition,
      gnssPosition: gnssCandidate,
      insPosition: deadReckonedPos,
      snappedPosition: snappedPos,
      currentSpeedMs: simSpeedMs,
      currentHeadingDeg: targetBearing,
      driftEstimateMeters: _latestFusionSnapshot.estimatedDriftMeters,
      positionAccuracyMeters: isInSimulatedOutageZone ? _latestFusionSnapshot.estimatedDriftMeters + 1.2 : 1.8,
      navMode: _latestFusionSnapshot.activeMode,
      gnssHealth: isInSimulatedOutageZone ? SignalHealth.lost : SignalHealth.excellent,
      isGnssOutageSimulated: isInSimulatedOutageZone,
      historicalTrail: updatedHistory,
      gnssTrail: updatedGnssTrail,
      insTrail: updatedInsTrail,
    );

    notifyListeners();
  }

  double _calculateRouteDistance(List<LatLng> polyline) {
    double total = 0.0;
    for (int i = 0; i < polyline.length - 1; i++) {
      total += GeoUtils.calculateDistance(polyline[i], polyline[i + 1]);
    }
    return total;
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

    // Finished scenario run, loop cleanly
    _routeProgress = 0.0;
    return polyline.first;
  }

  void _updateTelemetryBuffers(double speed, double confidence, FusionSnapshot fusion) {
    _speedHistory.add(speed * 3.6);
    _confidenceHistory.add(confidence * 100);
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
      driftEstimateMeters: 0.0,
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
      isSimulationActive: true,
      activeRoute: selected.waypoints,
      currentPosition: selected.waypoints.first,
      gnssPosition: selected.waypoints.first,
      insPosition: selected.waypoints.first,
      snappedPosition: selected.waypoints.first,
      currentSpeedMs: 12.5,
      isGnssOutageSimulated: false,
    );

    notifyListeners();
  }

  void startSimulation(SimulationScenario scenario) {
    switchScenario(scenario.type.name);
  }

  void stopSimulation() {
    final realPos = locationService.currentGnssPosition;
    _state = _state.copyWith(
      isSimulationActive: false,
      activeRoute: const [],
      isGnssOutageSimulated: false,
      currentPosition: realPos,
      gnssPosition: realPos,
      insPosition: realPos,
      snappedPosition: realPos,
      currentSpeedMs: 0.0,
      driftEstimateMeters: 0.0,
      historicalTrail: [realPos],
      gnssTrail: [realPos],
      insTrail: [realPos],
    );
    locationService.restoreGnss();
    fusionService.resetFilter(realPos);
    notifyListeners();
  }

  @override
  void toggleSimulation(bool running) {
    if (!running) {
      stopSimulation();
    } else {
      startSimulation(_currentScenario);
    }
  }

  @override
  void resetNavigation() {
    _routeProgress = 0.0;
    if (_state.isSimulationActive) {
      final firstPoint = _state.activeRoute.isNotEmpty ? _state.activeRoute.first : const LatLng(28.6139, 77.2090);
      fusionService.resetFilter(firstPoint);
      _state = NavigationState.initial(_state.activeRoute).copyWith(isSimulationActive: true);
    } else {
      final realPos = locationService.currentGnssPosition;
      fusionService.resetFilter(realPos);
      _state = NavigationState.initial().copyWith(
        currentPosition: realPos,
        gnssPosition: realPos,
        insPosition: realPos,
        snappedPosition: realPos,
        isSimulationActive: false,
      );
    }
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
    _locationSubscription?.cancel();
    sensorService.dispose();
    locationService.dispose();
    super.dispose();
  }
}
