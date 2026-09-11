import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/navigation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/fusion_data.dart';
import '../../models/navigation_state.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/nav_drawer.dart';
import '../../widgets/status_badge.dart';

class FusionScreen extends StatelessWidget {
  const FusionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final navService = context.watch<NavigationService>();
    final fusion = navService.latestFusionSnapshot;
    final speedEst = navService.latestSpeedEstimate;
    final sensor = navService.latestSensorSnapshot;
    final state = navService.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.cardBorder : AppColors.lightBorder;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;

    final rad = (state.currentHeadingDeg * math.pi) / 180.0;
    final ve = state.currentSpeedMs * math.cos(rad);
    final vn = state.currentSpeedMs * math.sin(rad);

    return Scaffold(
      appBar: const CustomAppBar(title: 'System Telemetry'),
      drawer: const NavDrawer(currentRoute: '/telemetry'),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/telemetry'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. AI Perception State Box
            _buildSectionCard(
              title: 'AI Perception State',
              icon: Icons.memory_rounded,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Forward Speed', style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight)),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                (speedEst.predictedSpeedMs * 3.6).toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text('km/h', style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Model Confidence', style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight)),
                          const SizedBox(height: 4),
                          Text(
                            '${(speedEst.confidenceScore * 100).toInt()}%',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.statusGreen),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: borderColor),
                  const SizedBox(height: 12),
                  // Simple State Summary Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStateTile(
                          label: 'Motion State',
                          value: speedEst.motionState.replaceAll('_', ' ').toUpperCase(),
                          color: speedEst.isZuptActive ? AppColors.statusCyan : AppColors.statusPurple,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStateTile(
                          label: 'Road Surface',
                          value: speedEst.vibrationClass.toUpperCase(),
                          color: speedEst.vibrationClass == 'smooth'
                              ? AppColors.statusGreen
                              : (speedEst.vibrationClass == 'moderate' ? AppColors.statusYellow : AppColors.statusRed),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStateTile(
                          label: 'ZUPT Status',
                          value: speedEst.isZuptActive ? 'ACTIVE' : 'INACTIVE',
                          color: speedEst.isZuptActive ? AppColors.statusCyan : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. 8-State EKF Core Box
            _buildSectionCard(
              title: 'EKF Navigation Vector (x̂)',
              icon: Icons.hub_rounded,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              trailing: StatusBadge(
                label: 'FILTER',
                health: state.isGnssOutageSimulated ? SignalHealth.degraded : SignalHealth.excellent,
                customText: state.navMode == NavMode.deadReckoning ? 'DEAD RECKONING' : 'GNSS AIDED',
              ),
              child: Column(
                children: [
                  _buildVectorRow('Position East (p_E)', '${fusion.eastMeters.toStringAsFixed(2)} m', isDark),
                  _buildVectorRow('Position North (p_N)', '${fusion.northMeters.toStringAsFixed(2)} m', isDark),
                  _buildVectorRow('Velocity East (v_E)', '${ve.toStringAsFixed(2)} m/s', isDark),
                  _buildVectorRow('Velocity North (v_N)', '${vn.toStringAsFixed(2)} m/s', isDark),
                  _buildVectorRow('Heading (ψ)', '${state.currentHeadingDeg.toStringAsFixed(1)}° (${rad.toStringAsFixed(3)} rad)', isDark),
                  _buildVectorRow('Accel Bias X (b_ax)', '${fusion.accelBiasX.toStringAsFixed(4)} m/s²', isDark),
                  _buildVectorRow('Accel Bias Y (b_ay)', '${fusion.accelBiasY.toStringAsFixed(4)} m/s²', isDark),
                  _buildVectorRow('Gyro Bias Z (b_g)', '${fusion.gyroBias.toStringAsFixed(5)} rad/s', isDark, isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Covariance & Bounds Box
            _buildSectionCard(
              title: 'Filter Uncertainty (1σ Bounds)',
              icon: Icons.straighten_rounded,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Position σ',
                      value: '±${fusion.positionSigmaMeters.toStringAsFixed(2)} m',
                      color: fusion.positionSigmaMeters < 2.0 ? AppColors.statusGreen : AppColors.statusYellow,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Velocity σ',
                      value: '±${fusion.velocitySigmaMps.toStringAsFixed(2)} m/s',
                      color: AppColors.primaryBlueLight,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Drift Est.',
                      value: '${fusion.estimatedDriftMeters.toStringAsFixed(2)} m',
                      color: fusion.estimatedDriftMeters > 3.0 ? AppColors.statusRed : AppColors.statusGreen,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Hardware Sensor Feeds Box
            _buildSectionCard(
              title: '6-DOF IMU Sensor Feeds',
              icon: Icons.sensors_rounded,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              trailing: Text(
                sensor.isHardwareAvailable ? 'Physical IMU (100Hz)' : 'Synthetic (50Hz)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: sensor.isHardwareAvailable ? AppColors.statusGreen : AppColors.statusYellow,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildAxisCard('acc_x', sensor.accelerometer.x.toStringAsFixed(2), isDark)),
                      const SizedBox(width: 6),
                      Expanded(child: _buildAxisCard('acc_y', sensor.accelerometer.y.toStringAsFixed(2), isDark)),
                      const SizedBox(width: 6),
                      Expanded(child: _buildAxisCard('acc_z', sensor.accelerometer.z.toStringAsFixed(2), isDark)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildAxisCard('gyro_z', sensor.gyroscope.z.toStringAsFixed(3), isDark)),
                      const SizedBox(width: 6),
                      Expanded(child: _buildAxisCard('gyro_y', sensor.gyroscope.y.toStringAsFixed(3), isDark)),
                      const SizedBox(width: 6),
                      Expanded(child: _buildAxisCard('gyro_x', sensor.gyroscope.x.toStringAsFixed(3), isDark)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: isDark ? AppColors.primaryBlueLight : AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildStateTile({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVectorRow(String label, String value, bool isDark, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: (isDark ? AppColors.cardBorder : AppColors.lightBorder).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAxisCard(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
