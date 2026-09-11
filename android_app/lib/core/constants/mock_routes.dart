import 'package:latlong2/latlong.dart';

class MockRoutes {
  // Standard Urban Navigation Route (smooth highway & city arterial)
  static final List<LatLng> standardCityRoute = [
    const LatLng(28.6139, 77.2090),
    const LatLng(28.6148, 77.2095),
    const LatLng(28.6160, 77.2102),
    const LatLng(28.6175, 77.2110),
    const LatLng(28.6190, 77.2120),
    const LatLng(28.6205, 77.2132),
    const LatLng(28.6220, 77.2145),
    const LatLng(28.6235, 77.2160),
    const LatLng(28.6248, 77.2178),
    const LatLng(28.6259, 77.2198),
    const LatLng(28.6268, 77.2220),
    const LatLng(28.6274, 77.2245),
    const LatLng(28.6278, 77.2270),
    const LatLng(28.6280, 77.2300),
  ];

  // Scenario 1: Long Underground Tunnel (Complete GNSS Blockage for 2 km)
  static final List<LatLng> tunnelRoute = [
    const LatLng(28.6120, 77.2050),
    const LatLng(28.6130, 77.2062),
    const LatLng(28.6142, 77.2078), // Tunnel Portal In
    const LatLng(28.6155, 77.2095),
    const LatLng(28.6168, 77.2112),
    const LatLng(28.6180, 77.2130),
    const LatLng(28.6195, 77.2150),
    const LatLng(28.6210, 77.2170),
    const LatLng(28.6225, 77.2192), // Tunnel Portal Out
    const LatLng(28.6240, 77.2215),
    const LatLng(28.6255, 77.2240),
  ];

  // Scenario 2: Multi-Level Parking Garage (Spirals, tight turns, multi-floor ZUPT)
  static final List<LatLng> parkingGarageRoute = [
    const LatLng(28.6185, 77.2150),
    const LatLng(28.6189, 77.2155),
    const LatLng(28.6193, 77.2162),
    const LatLng(28.6196, 77.2158),
    const LatLng(28.6198, 77.2152),
    const LatLng(28.6194, 77.2148),
    const LatLng(28.6190, 77.2144),
    const LatLng(28.6186, 77.2149),
    const LatLng(28.6188, 77.2155),
    const LatLng(28.6192, 77.2160),
    const LatLng(28.6195, 77.2165),
  ];

  // Scenario 3: Dense Urban Canyon (Skyscrapers with severe multipath reflections)
  static final List<LatLng> urbanCanyonRoute = [
    const LatLng(28.6300, 77.2180),
    const LatLng(28.6315, 77.2185),
    const LatLng(28.6330, 77.2190),
    const LatLng(28.6345, 77.2195),
    const LatLng(28.6360, 77.2200),
    const LatLng(28.6375, 77.2205),
    const LatLng(28.6390, 77.2210),
    const LatLng(28.6405, 77.2215),
  ];

  // Scenario 4: Dense Forest Canopy (Continuous signal attenuation & dropouts)
  static final List<LatLng> denseForestRoute = [
    const LatLng(28.6050, 77.1950),
    const LatLng(28.6062, 77.1968),
    const LatLng(28.6078, 77.1982),
    const LatLng(28.6095, 77.1995),
    const LatLng(28.6110, 77.2012),
    const LatLng(28.6128, 77.2030),
    const LatLng(28.6145, 77.2050),
  ];
}
