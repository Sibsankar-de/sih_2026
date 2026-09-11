import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/services/navigation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/live_chart.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/nav_drawer.dart';
import '../../widgets/telemetry_tile.dart';

class FusionScreen extends StatelessWidget {
  const FusionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final navService = context.watch<NavigationService>();
    final fusion = navService.latestFusionSnapshot;
    final state = navService.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'GNSS + INS Fusion'),
      drawer: const NavDrawer(currentRoute: '/fusion'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Interactive Fusion Flow Block
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.cardBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Extended Kalman Filter (EKF) Core',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.statusGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.statusGreen),
                        ),
                        child: Text(
                          'Error Reduced: ${fusion.errorReductionPercentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: AppColors.statusGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2 Inputs -> EKF Filter -> Output Fused
                  Row(
                    children: [
                      // Input 1: GNSS
                      Expanded(
                        child: _buildFlowNode(
                          title: 'GNSS Input',
                          value: state.isGnssOutageSimulated
                              ? 'Outage (No Fix)'
                              : '±${fusion.gnssAccuracyMeters.toStringAsFixed(1)}m Acc',
                          statusColor: state.isGnssOutageSimulated ? AppColors.statusRed : AppColors.statusGreen,
                          icon: Icons.satellite_alt_rounded,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Input 2: IMU INS
                      Expanded(
                        child: _buildFlowNode(
                          title: 'INS Dead Reckoning',
                          value: 'Drift: ${Formatters.formatDrift(fusion.estimatedDriftMeters)}',
                          statusColor: AppColors.primaryBlue,
                          icon: Icons.sensors_rounded,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Center Kalman Gain Indicator
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.statusCyan.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hub_rounded, size: 18, color: AppColors.statusCyan),
                          const SizedBox(width: 8),
                          Text(
                            'Kalman Weight (K): ${fusion.kalmanGainWeight.toStringAsFixed(2)} | HDOP: ${fusion.hdop.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.statusCyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().pulse(duration: 1500.ms),
                  const SizedBox(height: 12),

                  // Output Fused Node
                  _buildFlowNode(
                    title: 'Optimal Fused Position (Output)',
                    value: '${Formatters.formatCoordinate(fusion.fusedPosition.latitude)}, ${Formatters.formatCoordinate(fusion.fusedPosition.longitude)}',
                    statusColor: AppColors.statusCyan,
                    icon: Icons.my_location_rounded,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Performance Metrics
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                MetricCard(
                  title: 'Error Reduction',
                  value: '${fusion.errorReductionPercentage.toStringAsFixed(1)}%',
                  subtitle: 'vs Unfiltered INS Drift',
                  icon: Icons.auto_graph_rounded,
                  accentColor: AppColors.statusGreen,
                ),
                MetricCard(
                  title: 'Estimated Drift',
                  value: Formatters.formatDrift(fusion.estimatedDriftMeters),
                  subtitle: state.isGnssOutageSimulated ? 'INS Propagation' : 'Residual Bounded',
                  icon: Icons.timeline_rounded,
                  accentColor: state.isGnssOutageSimulated ? AppColors.statusRed : AppColors.primaryBlue,
                ),
                MetricCard(
                  title: 'Satellites Locked',
                  value: '${fusion.visibleSatellites}',
                  subtitle: state.isGnssOutageSimulated ? '0 (Outage)' : 'GPS + Galileo Constellation',
                  icon: Icons.satellite_outlined,
                  accentColor: fusion.visibleSatellites > 0 ? AppColors.statusGreen : AppColors.statusRed,
                ),
                MetricCard(
                  title: 'Filter Mode',
                  value: state.isGnssOutageSimulated ? 'INS-DR' : 'EKF-FUSED',
                  subtitle: state.isGnssOutageSimulated ? 'Autonomous Dead Reckoning' : 'Tightly Coupled',
                  icon: Icons.filter_center_focus_rounded,
                  accentColor: AppColors.statusCyan,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Trajectory Error Comparison Live Chart
            LiveLineChart(
              title: 'Trajectory Error Comparison (Meters)',
              dataPoints: navService.gnssErrorHistory,
              secondaryDataPoints: navService.fusedErrorHistory,
              primaryLegend: 'Raw GNSS / Unchecked (m)',
              secondaryLegend: 'FineLine Fused (m)',
              primaryColor: AppColors.statusRed,
              secondaryColor: AppColors.statusGreen,
              minY: 0,
              maxY: 20,
            ),
            const SizedBox(height: 16),

            // Kalman Math Equations Explanation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.cardBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mathematical State Vector',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const TelemetryTile(
                    label: 'State Vector [x]',
                    value: '[Lat, Lon, Velocity_N, Velocity_E, GyroBias, AccelBias]^T',
                    icon: Icons.functions_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(height: 8),
                  const TelemetryTile(
                    label: 'Measurement [z]',
                    value: 'GNSS Pseudoranges + AI Speed + ZUPT Flags',
                    icon: Icons.calculate_outlined,
                    color: AppColors.statusPurple,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowNode({
    required String title,
    required String value,
    required Color statusColor,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
