import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/navigation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/fusion_data.dart';
import '../../models/navigation_state.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/nav_drawer.dart';
import '../../widgets/status_badge.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapController = MapController();
  bool _followVehicle = true;

  @override
  Widget build(BuildContext context) {
    final navService = context.watch<NavigationService>();
    final state = navService.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Follow vehicle if enabled
    if (_followVehicle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(state.currentPosition, _mapController.camera.zoom);
      });
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Live Navigation',
        actions: [
          IconButton(
            icon: Icon(
              _followVehicle ? Icons.my_location_rounded : Icons.location_searching_rounded,
              color: _followVehicle ? AppColors.primaryBlue : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
            tooltip: 'Center Vehicle',
            onPressed: () {
              setState(() {
                _followVehicle = !_followVehicle;
              });
              _mapController.move(state.currentPosition, 16.5);
            },
          ),
        ],
      ),
      drawer: const NavDrawer(currentRoute: '/navigation'),
      body: Stack(
        children: [
          // OpenStreetMap Vector / Raster Tile Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: state.currentPosition,
              initialZoom: AppConstants.defaultZoom,
              minZoom: 10,
              maxZoom: 19,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _followVehicle) {
                  setState(() {
                    _followVehicle = false;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: AppConstants.osmTileUrl,
                userAgentPackageName: AppConstants.mapPackageUserAgent,
                maxNativeZoom: 19,
              ),
              // Planned Route Polyline
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: state.activeRoute,
                    color: AppColors.routePath.withOpacity(0.45),
                    strokeWidth: 6.0,
                  ),
                  // Historical Trajectory Path
                  Polyline(
                    points: state.historicalTrail,
                    color: state.isGnssOutageSimulated ? AppColors.insDriftPath : AppColors.fusedPath,
                    strokeWidth: 4.5,
                  ),
                ],
              ),
              // Dynamic Markers (Vehicle, GNSS Fix, Snapped Path)
              MarkerLayer(
                markers: [
                  // GNSS Raw Ghost Marker (if GNSS lost or drifting)
                  if (state.isGnssOutageSimulated)
                    Marker(
                      point: state.gnssPosition,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.statusRed.withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.statusRed, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.satellite_alt_rounded,
                          color: AppColors.statusRed,
                          size: 14,
                        ),
                      ),
                    ),
                  // Primary Vehicle Marker
                  Marker(
                    point: state.currentPosition,
                    width: 52,
                    height: 52,
                    child: Transform.rotate(
                      angle: (state.currentHeadingDeg * 3.141592653589793) / 180.0,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Pulse ripple effect
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (state.isGnssOutageSimulated
                                      ? AppColors.statusYellow
                                      : AppColors.primaryBlue)
                                  .withOpacity(0.25),
                            ),
                          ),
                          // Arrow vehicle badge
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: state.isGnssOutageSimulated
                                  ? AppColors.statusRed
                                  : AppColors.primaryBlue,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (state.isGnssOutageSimulated
                                          ? AppColors.statusRed
                                          : AppColors.primaryBlue)
                                      .withOpacity(0.6),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Top Floating Status HUD
          PositionArea(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkSurface : AppColors.lightSurface).withOpacity(0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.cardBorder : AppColors.lightBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StatusBadge(
                        label: 'GNSS',
                        health: state.gnssHealth,
                        icon: Icons.satellite_alt,
                      ),
                      StatusBadge(
                        label: 'MODE',
                        health: state.isGnssOutageSimulated ? SignalHealth.degraded : SignalHealth.excellent,
                        customText: state.navMode == NavMode.deadReckoning ? 'DEAD RECKONING' : 'FUSED EKF',
                      ),
                      StatusBadge(
                        label: 'DRIFT',
                        health: state.driftEstimateMeters > 3.0 ? SignalHealth.lost : SignalHealth.excellent,
                        customText: Formatters.formatDrift(state.driftEstimateMeters),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHUDItem('Speed', Formatters.formatSpeed(state.currentSpeedMs), isDark),
                      _buildHUDItem('Heading', Formatters.formatHeading(state.currentHeadingDeg), isDark),
                      _buildHUDItem('Accuracy', '±${state.positionAccuracyMeters.toStringAsFixed(1)}m', isDark),
                      _buildHUDItem('Scenario', navService.currentScenario.type.name.replaceAll('Navigation', ''), isDark),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Control Panel with "Simulate GNSS Loss" & "Restore GNSS"
          PositionArea(
            bottom: 20,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.isGnssOutageSimulated)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.statusRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'GNSS OUTAGE: INS Dead Reckoning Active (${Formatters.formatDrift(state.driftEstimateMeters)} drift)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ).animate().pulse(duration: 1000.ms),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: state.isGnssOutageSimulated ? AppColors.darkCard : AppColors.statusRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.gps_off_rounded),
                        label: const Text('Simulate GNSS Loss'),
                        onPressed: state.isGnssOutageSimulated ? null : () => navService.simulateGnssLoss(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: state.isGnssOutageSimulated ? AppColors.statusGreen : AppColors.darkCard,
                          foregroundColor: state.isGnssOutageSimulated ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.gps_fixed_rounded),
                        label: const Text('Restore GNSS'),
                        onPressed: !state.isGnssOutageSimulated ? null : () => navService.restoreGnss(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHUDItem(String label, String val, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }
}

class PositionArea extends StatelessWidget {
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final Widget child;

  const PositionArea({
    super.key,
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: child,
    );
  }
}
