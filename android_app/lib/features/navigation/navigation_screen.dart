import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/navigation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/nav_drawer.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapController = MapController();
  bool _followVehicle = true;
  bool _isMapReady = false;

  @override
  Widget build(BuildContext context) {
    final navService = context.watch<NavigationService>();
    final state = navService.state;
    final speedEst = navService.latestSpeedEstimate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.cardBorder : AppColors.lightBorder;
    final surfaceBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final isSim = state.isSimulationActive;

    // Follow vehicle when moving
    if (_isMapReady && _followVehicle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isMapReady) {
          try {
            _mapController.move(state.currentPosition, _mapController.camera.zoom);
          } catch (_) {}
        }
      });
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: isSim ? 'Simulation' : 'Navigation',
        actions: [
          IconButton(
            icon: Icon(
              state.isGnssOutageSimulated ? Icons.gps_off_rounded : Icons.gps_fixed_rounded,
              color: state.isGnssOutageSimulated ? AppColors.statusRed : AppColors.statusGreen,
            ),
            tooltip: state.isGnssOutageSimulated ? 'Restore GNSS' : 'Simulate GNSS Loss',
            onPressed: () {
              if (state.isGnssOutageSimulated) {
                navService.restoreGnss();
              } else {
                navService.simulateGnssLoss();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset',
            onPressed: () => navService.resetNavigation(),
          ),
        ],
      ),
      drawer: const NavDrawer(currentRoute: '/'),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/'),
      body: Stack(
        children: [
          // OpenStreetMap Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: state.currentPosition,
              initialZoom: AppConstants.defaultZoom,
              minZoom: 5,
              maxZoom: 19,
              onMapReady: () {
                setState(() {
                  _isMapReady = true;
                });
              },
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
              // Scenario Route Polyline (Shown only during simulation)
              if (isSim && state.activeRoute.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: state.activeRoute,
                      color: AppColors.routePath.withValues(alpha: 0.6),
                      strokeWidth: 4.5,
                    ),
                    Polyline(
                      points: state.historicalTrail,
                      color: state.isGnssOutageSimulated ? AppColors.insDriftPath : AppColors.fusedPath,
                      strokeWidth: 3.5,
                    ),
                  ],
                ),
              // Markers Layer
              MarkerLayer(
                markers: [
                  // Vehicle Marker
                  Marker(
                    point: state.currentPosition,
                    width: 38,
                    height: 38,
                    child: Transform.rotate(
                      angle: (state.currentHeadingDeg * math.pi) / 180.0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: state.isGnssOutageSimulated ? AppColors.statusRed : AppColors.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Simulation Mode Banner (ONLY shown when simulation is running!)
          if (isSim)
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.statusYellow.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.science_rounded, color: Colors.black, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SIMULATION: ${navService.currentScenario.title}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            state.isGnssOutageSimulated ? 'Tunnel Blackout • Dead Reckoning' : 'Nominal Track Progress',
                            style: const TextStyle(fontSize: 10.5, color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(50, 28),
                      ),
                      onPressed: () => navService.stopSimulation(),
                      child: const Text('Exit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),

          // Map Control Floating Buttons (Right edge)
          Positioned(
            right: 12,
            bottom: 155,
            child: Column(
              children: [
                _buildMapFloatingButton(
                  icon: _followVehicle ? Icons.my_location_rounded : Icons.location_searching_rounded,
                  color: _followVehicle ? AppColors.primaryBlue : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                  backgroundColor: surfaceBg,
                  borderColor: borderColor,
                  tooltip: _followVehicle ? 'Centered' : 'Center on Location',
                  onTap: () {
                    setState(() {
                      _followVehicle = true;
                    });
                    _mapController.move(state.currentPosition, 16.0);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapFloatingButton(
                  icon: Icons.add_rounded,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  backgroundColor: surfaceBg,
                  borderColor: borderColor,
                  tooltip: 'Zoom In',
                  onTap: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildMapFloatingButton(
                  icon: Icons.remove_rounded,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  backgroundColor: surfaceBg,
                  borderColor: borderColor,
                  tooltip: 'Zoom Out',
                  onTap: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                ),
              ],
            ),
          ),

          // Clean Unified State Box (At Bottom of Map)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceBg.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Speed & Motion State
                  Row(
                    children: [
                      // Speed
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            (state.currentSpeedMs * 3.6).toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'km/h',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      // Motion State & Road Vibration Chips
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              _buildChip(
                                label: speedEst.motionState.replaceAll('_', ' ').toUpperCase(),
                                color: speedEst.isZuptActive ? AppColors.statusCyan : AppColors.statusPurple,
                                icon: speedEst.isZuptActive ? Icons.pause_circle_filled_rounded : Icons.directions_car_rounded,
                                isDark: isDark,
                              ),
                              _buildChip(
                                label: speedEst.vibrationClass.toUpperCase(),
                                color: speedEst.vibrationClass == 'smooth'
                                    ? AppColors.statusGreen
                                    : (speedEst.vibrationClass == 'moderate' ? AppColors.statusYellow : AppColors.statusRed),
                                icon: Icons.vibration_rounded,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: borderColor),
                  const SizedBox(height: 8),
                  // Row 2: Filter Mode & Position Lat/Lon
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: state.isGnssOutageSimulated ? AppColors.statusRed : AppColors.statusGreen,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                state.isGnssOutageSimulated ? 'Dead Reckoning (AI+EKF)' : 'GNSS Locked',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: state.isGnssOutageSimulated ? AppColors.statusRed : AppColors.statusGreen,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${state.currentPosition.latitude.toStringAsFixed(4)}°, ${state.currentPosition.longitude.toStringAsFixed(4)}°',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapFloatingButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required Color borderColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: backgroundColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
