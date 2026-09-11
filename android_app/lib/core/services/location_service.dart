import 'dart:async';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'service_interfaces.dart';

class LocationService implements ILocationService {
  final StreamController<LatLng> _gnssStreamController = StreamController<LatLng>.broadcast();
  LatLng _currentPosition = const LatLng(28.6139, 77.2090);
  bool _isGnssAvailable = true;
  double _gnssAccuracyMeters = 1.8;
  int _satelliteCount = 16;
  double _hdop = 0.75;
  final math.Random _random = math.Random();

  @override
  Stream<LatLng> get gnssStream => _gnssStreamController.stream;

  @override
  LatLng get currentGnssPosition => _currentPosition;

  @override
  bool get isGnssAvailable => _isGnssAvailable;

  @override
  double get gnssAccuracyMeters => _gnssAccuracyMeters;

  @override
  int get satelliteCount => _satelliteCount;

  @override
  double get hdop => _hdop;

  @override
  void simulateGnssLoss() {
    _isGnssAvailable = false;
    _satelliteCount = 0;
    _hdop = 9.99;
    _gnssAccuracyMeters = 99.0;
  }

  @override
  void restoreGnss() {
    _isGnssAvailable = true;
    _satelliteCount = 14 + _random.nextInt(6);
    _hdop = 0.8 + _random.nextDouble() * 0.4;
    _gnssAccuracyMeters = 1.6 + _random.nextDouble() * 0.8;
  }

  @override
  void updatePosition(LatLng position) {
    _currentPosition = position;
    if (_isGnssAvailable && !_gnssStreamController.isClosed) {
      _gnssStreamController.add(position);
    }
  }

  @override
  void dispose() {
    _gnssStreamController.close();
  }
}
