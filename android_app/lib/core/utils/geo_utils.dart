import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class GeoUtils {
  static const double earthRadiusMeters = 6371000.0;

  static double degreesToRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  static double radiansToDegrees(double radians) {
    return radians * 180.0 / math.pi;
  }

  // Calculate distance between two lat/lng coordinates in meters
  static double calculateDistance(LatLng start, LatLng end) {
    final double dLat = degreesToRadians(end.latitude - start.latitude);
    final double dLon = degreesToRadians(end.longitude - start.longitude);

    final double lat1 = degreesToRadians(start.latitude);
    final double lat2 = degreesToRadians(end.latitude);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(lat1) * math.cos(lat2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  // Calculate initial bearing between two coordinates in degrees (0..360)
  static double calculateBearing(LatLng start, LatLng end) {
    final double lat1 = degreesToRadians(start.latitude);
    final double lat2 = degreesToRadians(end.latitude);
    final double dLon = degreesToRadians(end.longitude - start.longitude);

    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final double radians = math.atan2(y, x);
    final double degrees = radiansToDegrees(radians);
    return (degrees + 360) % 360;
  }

  // Dead reckoning step: compute new LatLng given start point, heading in deg, and distance in meters
  static LatLng computeDeadReckoningStep(LatLng from, double headingDegrees, double distanceMeters) {
    final double distRatio = distanceMeters / earthRadiusMeters;
    final double headingRad = degreesToRadians(headingDegrees);
    final double lat1 = degreesToRadians(from.latitude);
    final double lon1 = degreesToRadians(from.longitude);

    final double lat2 = math.asin(
      math.sin(lat1) * math.cos(distRatio) +
      math.cos(lat1) * math.sin(distRatio) * math.cos(headingRad)
    );

    final double lon2 = lon1 + math.atan2(
      math.sin(headingRad) * math.sin(distRatio) * math.cos(lat1),
      math.cos(distRatio) - math.sin(lat1) * math.sin(lat2)
    );

    return LatLng(radiansToDegrees(lat2), radiansToDegrees(lon2));
  }

  // Find closest point on polyline for map-matching
  static LatLng projectPointToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return point;
    if (polyline.length == 1) return polyline.first;

    LatLng closest = polyline.first;
    double minDistance = double.infinity;

    for (int i = 0; i < polyline.length - 1; i++) {
      final pA = polyline[i];
      final pB = polyline[i + 1];

      final proj = _projectOnSegment(point, pA, pB);
      final dist = calculateDistance(point, proj);
      if (dist < minDistance) {
        minDistance = dist;
        closest = proj;
      }
    }
    return closest;
  }

  static LatLng _projectOnSegment(LatLng p, LatLng a, LatLng b) {
    final double dx = b.longitude - a.longitude;
    final double dy = b.latitude - a.latitude;
    if (dx == 0 && dy == 0) return a;

    final double t = ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) / (dx * dx + dy * dy);
    final double clampedT = t.clamp(0.0, 1.0);

    return LatLng(
      a.latitude + clampedT * dy,
      a.longitude + clampedT * dx,
    );
  }
}
