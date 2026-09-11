import 'package:latlong2/latlong.dart';
import '../../models/sensor_data.dart';
import '../../models/speed_estimate.dart';
import '../../models/fusion_data.dart';

abstract class ISensorService {
  Stream<SensorSnapshot> get sensorStream;
  SensorSnapshot get currentSnapshot;
  bool get isHardwareAvailable;
  void start();
  void stop();
  void dispose();
}

abstract class ILocationService {
  Stream<LatLng> get gnssStream;
  LatLng get currentGnssPosition;
  bool get isGnssAvailable;
  double get gnssAccuracyMeters;
  int get satelliteCount;
  double get hdop;
  void simulateGnssLoss();
  void restoreGnss();
  void updatePosition(LatLng position);
  void dispose();
}

abstract class IMockAIService {
  SpeedEstimate estimateSpeed(SensorSnapshot sensorSnapshot, double previousSpeed);
  double estimateHeadingCorrection(Vector3D gyro, double currentHeading, double dt);
  bool detectZeroVelocity(Vector3D accel, Vector3D gyro);
}

abstract class IFusionService {
  FusionSnapshot computeFusion({
    required LatLng gnssPosition,
    required LatLng deadReckonedPosition,
    required bool isGnssValid,
    required double insDriftMeters,
    required double gnssAccuracy,
    required double dt,
  });
  void resetFilter(LatLng resetPosition);
}

abstract class IMapMatchingService {
  LatLng matchToRoute(LatLng rawPosition, List<LatLng> routeWaypoints);
  double computeCrossTrackError(LatLng position, List<LatLng> routeWaypoints);
  double calculateRouteBearing(LatLng position, List<LatLng> routeWaypoints);
}

abstract class INavigationService {
  void simulateGnssLoss();
  void restoreGnss();
  void switchScenario(String scenarioId);
  void toggleSimulation(bool running);
  void resetNavigation();
}
