import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/navigation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/sensor_data.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/live_chart.dart';
import '../../widgets/nav_drawer.dart';

class SensorMonitoringScreen extends StatefulWidget {
  const SensorMonitoringScreen({super.key});

  @override
  State<SensorMonitoringScreen> createState() => _SensorMonitoringScreenState();
}

class _SensorMonitoringScreenState extends State<SensorMonitoringScreen> {
  final List<double> _accelXHistory = [];
  final List<double> _accelYHistory = [];
  final List<double> _gyroZHistory = [];

  @override
  Widget build(BuildContext context) {
    final navService = context.watch<NavigationService>();
    final snapshot = navService.latestSensorSnapshot;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Buffer sensor history
    _accelXHistory.add(snapshot.accelerometer.x);
    _accelYHistory.add(snapshot.accelerometer.y);
    _gyroZHistory.add(snapshot.gyroscope.z * 10); // scaled for visual distinction

    if (_accelXHistory.length > 30) _accelXHistory.removeAt(0);
    if (_accelYHistory.length > 30) _accelYHistory.removeAt(0);
    if (_gyroZHistory.length > 30) _gyroZHistory.removeAt(0);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Sensor Monitoring',
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (snapshot.isHardwareAvailable ? AppColors.statusGreen : AppColors.statusYellow).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: snapshot.isHardwareAvailable ? AppColors.statusGreen : AppColors.statusYellow,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  snapshot.isHardwareAvailable ? Icons.sensors_rounded : Icons.computer_rounded,
                  size: 14,
                  color: snapshot.isHardwareAvailable ? AppColors.statusGreen : AppColors.statusYellow,
                ),
                const SizedBox(width: 4),
                Text(
                  snapshot.isHardwareAvailable ? 'Physical IMU' : 'Simulated IMU',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: snapshot.isHardwareAvailable ? AppColors.statusGreen : AppColors.statusYellow,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: const NavDrawer(currentRoute: '/sensors'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppColors.cardBorder : AppColors.lightBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildHeaderStat('Sampling Rate', '${snapshot.updateFrequencyHz.toInt()} Hz', Icons.speed_rounded, isDark),
                  _buildHeaderStat('Sensor Status', snapshot.isHardwareAvailable ? 'Live Hardware' : 'Physics Sim', Icons.check_circle_outline, isDark),
                  _buildHeaderStat('Gravity Bias', '9.81 m/s²', Icons.arrow_downward_rounded, isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Accelerometer Card
            _buildSensorCard(
              title: '3-Axis Accelerometer (m/s²)',
              icon: Icons.vibration_rounded,
              vector: snapshot.accelerometer,
              accentColor: AppColors.primaryBlue,
              isDark: isDark,
            ),
            const SizedBox(height: 14),

            // Gyroscope Card
            _buildSensorCard(
              title: '3-Axis Gyroscope (rad/s)',
              icon: Icons.rotate_right_rounded,
              vector: snapshot.gyroscope,
              accentColor: AppColors.statusCyan,
              isDark: isDark,
            ),
            const SizedBox(height: 14),

            // Magnetometer Card
            _buildSensorCard(
              title: '3-Axis Magnetometer (µT)',
              icon: Icons.explore_outlined,
              vector: snapshot.magnetometer,
              accentColor: AppColors.statusPurple,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Live Waveform Chart
            LiveLineChart(
              title: 'Real-time IMU Waveform (Accel X vs Y)',
              dataPoints: _accelXHistory,
              secondaryDataPoints: _accelYHistory,
              primaryLegend: 'Lateral (X)',
              secondaryLegend: 'Forward (Y)',
              primaryColor: AppColors.primaryBlue,
              secondaryColor: AppColors.statusGreen,
              minY: -2.0,
              maxY: 2.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.primaryBlue),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildSensorCard({
    required String title,
    required IconData icon,
    required Vector3D vector,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
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
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildAxisBadge('X-Axis', Formatters.formatSensorVal(vector.x), isDark)),
              const SizedBox(width: 8),
              Expanded(child: _buildAxisBadge('Y-Axis', Formatters.formatSensorVal(vector.y), isDark)),
              const SizedBox(width: 8),
              Expanded(child: _buildAxisBadge('Z-Axis', Formatters.formatSensorVal(vector.z), isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAxisBadge(String axis, String val, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.cardBorder.withOpacity(0.5) : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Text(
            axis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
