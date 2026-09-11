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

class AISpeedScreen extends StatelessWidget {
  const AISpeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final navService = context.watch<NavigationService>();
    final speedEst = navService.latestSpeedEstimate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'AI Speed Estimation'),
      drawer: const NavDrawer(currentRoute: '/ai-speed'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Model Running On Device Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue.withOpacity(0.2),
                    AppColors.statusCyan.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.memory_rounded, color: Colors.black, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Model Running On Device (Edge AI)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          speedEst.modelName,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.statusGreen),
                    ),
                    child: const Text(
                      'TFLite INT8',
                      style: TextStyle(
                        color: AppColors.statusGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().shimmer(duration: 2000.ms),
            const SizedBox(height: 16),

            // AI Speed Metrics Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                MetricCard(
                  title: 'Raw Acceleration',
                  value: '${Formatters.formatSensorVal(speedEst.rawAcceleration)} m/s²',
                  subtitle: 'Unfiltered IMU Y-Axis',
                  icon: Icons.trending_up_rounded,
                  accentColor: AppColors.statusYellow,
                ),
                MetricCard(
                  title: 'Filtered Acceleration',
                  value: '${Formatters.formatSensorVal(speedEst.filteredAcceleration)} m/s²',
                  subtitle: 'Low-Pass Exponential EMA',
                  icon: Icons.filter_alt_rounded,
                  accentColor: AppColors.primaryBlue,
                ),
                MetricCard(
                  title: 'Predicted Speed',
                  value: Formatters.formatSpeed(speedEst.predictedSpeedMs),
                  subtitle: '${speedEst.predictedSpeedMs.toStringAsFixed(2)} m/s velocity',
                  icon: Icons.speed_rounded,
                  accentColor: AppColors.statusGreen,
                ),
                MetricCard(
                  title: 'Confidence Score',
                  value: Formatters.formatPercentage(speedEst.confidenceScore),
                  subtitle: speedEst.confidenceScore > 0.9 ? 'High Certainty' : 'Vibration Detected',
                  icon: Icons.verified_rounded,
                  accentColor: speedEst.confidenceScore > 0.9 ? AppColors.statusGreen : AppColors.statusYellow,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live Inference Speed Chart
            LiveLineChart(
              title: 'Live Model Speed Estimation (km/h) & Confidence (%)',
              dataPoints: navService.speedHistory,
              secondaryDataPoints: navService.confidenceHistory,
              primaryLegend: 'Predicted Speed (km/h)',
              secondaryLegend: 'Confidence (%)',
              primaryColor: AppColors.primaryBlue,
              secondaryColor: AppColors.statusGreen,
              minY: 0,
              maxY: 100,
            ),
            const SizedBox(height: 16),

            // Model Architecture Overview Card
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
                    'Inference Pipeline Architecture',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const TelemetryTile(
                    label: 'Input Features',
                    value: '100Hz 3-Axis Accel + 3-Axis Gyro (6x50 window)',
                    icon: Icons.input_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(height: 8),
                  const TelemetryTile(
                    label: 'Network Type',
                    value: 'Temporal Convolutional Network (TCN) + GRU',
                    icon: Icons.psychology_rounded,
                    color: AppColors.statusPurple,
                  ),
                  const SizedBox(height: 8),
                  TelemetryTile(
                    label: 'Zero Velocity Update (ZUPT)',
                    value: speedEst.isZuptActive ? 'STATIONARY (ACTIVE)' : 'IN MOTION',
                    icon: Icons.pause_circle_outline_rounded,
                    color: speedEst.isZuptActive ? AppColors.statusGreen : AppColors.primaryBlue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
