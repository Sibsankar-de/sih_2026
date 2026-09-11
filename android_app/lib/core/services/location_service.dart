import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'service_interfaces.dart';

class LocationService implements ILocationService {
  final StreamController<LatLng> _gnssStreamController = StreamController<LatLng>.broadcast();
  StreamSubscription<Position>? _positionSub;

  LatLng _currentPosition = const LatLng(28.6139, 77.2090); // Default fallback
  bool _isGnssAvailable = true;
  double _gnssAccuracyMeters = 2.0;
  int _satelliteCount = 14;
  double _hdop = 0.8;
  bool _hasRealLocationFix = false;

  bool get hasRealLocationFix => _hasRealLocationFix;

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

  LocationService() {
    _initRealLocation();
  }

  Future<void> _initRealLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _hasRealLocationFix = true;
      _currentPosition = LatLng(pos.latitude, pos.longitude);
      _gnssAccuracyMeters = pos.accuracy;
      _gnssStreamController.add(_currentPosition);

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1,
        ),
      ).listen((pos) {
        if (_isGnssAvailable) {
          _hasRealLocationFix = true;
          _currentPosition = LatLng(pos.latitude, pos.longitude);
          _gnssAccuracyMeters = pos.accuracy;
          _gnssStreamController.add(_currentPosition);
        }
      });
    } catch (_) {
      // Fallback cleanly to default position
    }
  }

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
    _satelliteCount = 14;
    _hdop = 0.8;
    _gnssAccuracyMeters = 1.8;
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
    _positionSub?.cancel();
    _gnssStreamController.close();
  }
}
