import 'package:latlong2/latlong.dart';
import '../utils/geo_utils.dart';
import 'service_interfaces.dart';

class MapMatchingService implements IMapMatchingService {
  @override
  LatLng matchToRoute(LatLng rawPosition, List<LatLng> routeWaypoints) {
    if (routeWaypoints.isEmpty) return rawPosition;
    return GeoUtils.projectPointToPolyline(rawPosition, routeWaypoints);
  }

  @override
  double computeCrossTrackError(LatLng position, List<LatLng> routeWaypoints) {
    if (routeWaypoints.isEmpty) return 0.0;
    final snapped = matchToRoute(position, routeWaypoints);
    return GeoUtils.calculateDistance(position, snapped);
  }

  @override
  double calculateRouteBearing(LatLng position, List<LatLng> routeWaypoints) {
    if (routeWaypoints.length < 2) return 0.0;

    int closestSegmentIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < routeWaypoints.length - 1; i++) {
      final pA = routeWaypoints[i];
      final pB = routeWaypoints[i + 1];
      final snapped = GeoUtils.projectPointToPolyline(position, [pA, pB]);
      final dist = GeoUtils.calculateDistance(position, snapped);
      if (dist < minDistance) {
        minDistance = dist;
        closestSegmentIndex = i;
      }
    }

    return GeoUtils.calculateBearing(
      routeWaypoints[closestSegmentIndex],
      routeWaypoints[closestSegmentIndex + 1],
    );
  }
}
