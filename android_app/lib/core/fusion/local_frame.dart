import 'dart:math' as math;
import 'fusion_types.dart';

/// Local Tangent Plane (ENU) coordinate frame around an origin (lat0, lon0).
class LocalFrame {
  double _originLatDeg = 0.0;
  double _originLonDeg = 0.0;
  double _cosLat0 = 1.0;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  double get originLatDeg => _originLatDeg;
  double get originLonDeg => _originLonDeg;

  void setOrigin(double latDeg, double lonDeg) {
    _originLatDeg = latDeg;
    _originLonDeg = lonDeg;
    _cosLat0 = math.cos(latDeg * kDegToRad);
    if (_cosLat0.abs() < 1e-6) {
      _cosLat0 = 1e-6; // Guard against polar singularities
    }
    _initialized = true;
  }

  /// Geographic coordinates (lat, lon degrees) -> Local ENU [East, North] in meters
  List<double> geoToLocal(double latDeg, double lonDeg) {
    if (!_initialized) return [0.0, 0.0];
    final double dLatRad = (latDeg - _originLatDeg) * kDegToRad;
    final double dLonRad = (lonDeg - _originLonDeg) * kDegToRad;

    final double east = dLonRad * kEarthRadiusWgs84 * _cosLat0;
    final double north = dLatRad * kEarthRadiusWgs84;
    return [east, north];
  }

  /// Local ENU [East, North] in meters -> Geographic coordinates [lat, lon degrees]
  List<double> localToGeo(double eastM, double northM) {
    if (!_initialized) return [_originLatDeg, _originLonDeg];
    final double dLatRad = northM / kEarthRadiusWgs84;
    final double dLonRad = eastM / (kEarthRadiusWgs84 * _cosLat0);

    final double lat = _originLatDeg + dLatRad * kRadToDeg;
    final double lon = _originLonDeg + dLonRad * kRadToDeg;
    return [lat, lon];
  }

  void reset() {
    _originLatDeg = 0.0;
    _originLonDeg = 0.0;
    _cosLat0 = 1.0;
    _initialized = false;
  }
}
