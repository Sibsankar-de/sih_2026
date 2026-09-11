import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/services/navigation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/fusion_data.dart';
import '../../models/navigation_state.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/live_chart.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/nav_drawer.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/telemetry_tile.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final navService = context.watch<NavigationService>();
    final state = navService.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Home Dashboard',
        actions: [
          IconButton(
            icon: Icon(
              state.isGnssOutageSimulated ? Icons.gps_off : Icons.gps_fixed,
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
            tooltip: 'Reset Navigation',
            onPressed: () => navService.resetNavigation(),
          ),
        ],
      ),
      drawer: const NavDrawer(currentRoute: '/'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badges Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  StatusBadge(
                    label: 'GNSS',
                    health: state.gnssHealth,
                    icon: Icons.satellite_alt_outlined,
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    label: 'INS / IMU',
                    health: state.insHealth,
                    icon: Icons.sensors,
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    label: 'EKF FUSION',
                    health: state.fusionHealth,
                    icon: Icons.hub,
                    customText: state.navMode == NavMode.deadReckoning ? 'DEAD RECKONING' : 'FUSED OPTIMAL',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Outage Alert Banner if outage is simulated
            if (state.isGnssOutageSimulated) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.statusRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.statusRed.withOpacity(0.5), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.statusRed, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GNSS Signal Denied / Outage Active',
                            style: TextStyle(
                              color: AppColors.statusRed,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Intelligent AI Dead Reckoning is maintaining continuous positioning.',
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => navService.restoreGnss(),
                      child: const Text('Restore', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ).animate().shake(duration: 400.ms),
              const SizedBox(height: 16),
            ],

            // 2x2 Metric Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                MetricCard(
                  title: 'Vehicle Speed',
                  value: Formatters.formatSpeed(state.currentSpeedMs),
                  subtitle: 'Est. Confidence: ${(navService.latestSpeedEstimate.confidenceScore * 100).toInt()}%',
                  icon: Icons.speed_rounded,
                  accentColor: AppColors.primaryBlue,
                  onTap: () => context.go('/ai-speed'),
                ),
                MetricCard(
                  title: 'Heading',
                  value: Formatters.formatHeading(state.currentHeadingDeg),
                  subtitle: 'Gyro + Mag Fusion',
                  icon: Icons.explore_rounded,
                  accentColor: AppColors.statusCyan,
                  onTap: () => context.go('/navigation'),
                ),
                MetricCard(
                  title: 'Position Accuracy',
                  value: '± ${state.positionAccuracyMeters.toStringAsFixed(1)} m',
                  subtitle: state.isGnssOutageSimulated ? 'INS Covariance Bound' : 'GNSS Fix Bound',
                  icon: Icons.gps_fixed_rounded,
                  accentColor: state.positionAccuracyMeters < 3.0 ? AppColors.statusGreen : AppColors.statusYellow,
                  onTap: () => context.go('/fusion'),
                ),
                MetricCard(
                  title: 'Drift Estimate',
                  value: Formatters.formatDrift(state.driftEstimateMeters),
                  subtitle: state.isGnssOutageSimulated ? 'Accumulating' : 'Nominal Drift',
                  icon: Icons.timeline_rounded,
                  accentColor: state.driftEstimateMeters > 3.0 ? AppColors.statusRed : AppColors.statusGreen,
                  onTap: () => context.go('/fusion'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live Telemetry Details
            Text(
              'System Telemetry & Health',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 10),
            TelemetryTile(
              label: 'IMU Sensor Health',
              value: navService.latestSensorSnapshot.isHardwareAvailable ? 'Physical (50 Hz)' : 'Synthetic Physics (20 Hz)',
              icon: Icons.memory,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(height: 8),
            TelemetryTile(
              label: 'Active Scenario',
              value: navService.currentScenario.title.split(': ').last,
              icon: Icons.tune,
              color: AppColors.statusPurple,
            ),
            const SizedBox(height: 8),
            TelemetryTile(
              label: 'Error Reduction via EKF',
              value: '${navService.latestFusionSnapshot.errorReductionPercentage.toStringAsFixed(1)}%',
              icon: Icons.auto_graph_rounded,
              color: AppColors.statusGreen,
            ),
            const SizedBox(height: 16),

            // Real-time Speed & Drift Live Chart
            LiveLineChart(
              title: 'Real-time Speed (km/h) & Drift (m)',
              dataPoints: navService.speedHistory,
              secondaryDataPoints: navService.driftHistory,
              primaryLegend: 'Speed (km/h)',
              secondaryLegend: 'Drift (m)',
              primaryColor: AppColors.primaryBlue,
              secondaryColor: AppColors.statusRed,
              minY: 0,
              maxY: 60,
            ),
            const SizedBox(height: 20),

            // Quick Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Live Navigation Map'),
                    onPressed: () => context.go('/navigation'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.science_rounded),
                    label: const Text('Simulation Center'),
                    onPressed: () => context.go('/simulation'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
