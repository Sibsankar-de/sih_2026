import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/nav_drawer.dart';

class SystemArchitectureScreen extends StatefulWidget {
  const SystemArchitectureScreen({super.key});

  @override
  State<SystemArchitectureScreen> createState() => _SystemArchitectureScreenState();
}

class _SystemArchitectureScreenState extends State<SystemArchitectureScreen> {
  int? _selectedBlockIndex;

  final List<Map<String, dynamic>> _architectureBlocks = [
    {
      'title': '1. IMU Physical Sensors',
      'subtitle': '3-Axis Accelerometer + Gyroscope + Magnetometer',
      'desc': 'Streams high-rate raw sensor data at 50Hz. Provides raw specific force, angular rates, and local geomagnetic field vector.',
      'icon': Icons.sensors_rounded,
      'color': AppColors.primaryBlue,
      'tech': 'sensors_plus (Hardware) / Synthetic Physics Generator',
    },
    {
      'title': '2. Noise Filtering & Signal Preprocessing',
      'subtitle': 'Exponential Moving Average + Low-Pass Filter',
      'desc': 'Attenuates high-frequency chassis vibrations, engine harmonics, and thermal sensor bias. Isolates kinematic forward acceleration from gravitational components.',
      'icon': Icons.filter_alt_rounded,
      'color': AppColors.statusCyan,
      'tech': 'Butterworth IIR / Exponential Moving Average (EMA)',
    },
    {
      'title': '3. AI Speed & Velocity Estimation',
      'subtitle': 'Temporal Convolutional Network + Bi-LSTM',
      'desc': 'Computes instantaneous forward speed and certainty scores directly from windowed IMU waveforms. Eliminates classic double-integration quadratic drift.',
      'icon': Icons.psychology_rounded,
      'color': AppColors.statusPurple,
      'tech': 'Quantized TFLite INT8 / ONNX Runtime C++ API',
    },
    {
      'title': '4. Inertial Dead Reckoning Engine (INS)',
      'subtitle': '6-DoF Kinematic State Propagator',
      'desc': 'Integrates gyro yaw rates and AI velocity vectors over delta-time steps. Continues high-precision dead reckoning during complete GNSS outages.',
      'icon': Icons.navigation_rounded,
      'color': AppColors.statusYellow,
      'tech': 'Quaternion Integration / Geodesic Haversine Math',
    },
    {
      'title': '5. Map Matching & Topological Snapping',
      'subtitle': 'Road Network Vector Polyline Projector',
      'desc': 'Snaps fused position to road centerline vectors. Calculates perpendicular cross-track error bounds and maintains heading lock on curved and tunnel segments.',
      'icon': Icons.alt_route_rounded,
      'color': AppColors.statusGreen,
      'tech': 'OpenStreetMap Vector Topology / Orthogonal Projection',
    },
    {
      'title': '6. Extended Kalman Filter (EKF) Fusion',
      'subtitle': 'Tightly Coupled Multi-Sensor State Estimator',
      'desc': 'Dynamically computes Kalman Gain weights between GNSS fixes and INS propagation. Binds residual drift and smoothly recovers trajectory when GNSS is restored.',
      'icon': Icons.hub_rounded,
      'color': AppColors.primaryBlue,
      'tech': '15-State Error Covariance Matrix (EKF / UKF)',
    },
    {
      'title': '7. Navigation Output & Telemetry Layer',
      'subtitle': 'Sub-Meter Guidance & Presentation HUD',
      'desc': 'Renders 60fps real-time map positions, heads-up display telemetry, live confidence scores, and seamless alert states for driver navigation.',
      'icon': Icons.dashboard_customize_rounded,
      'color': AppColors.statusGreen,
      'tech': 'flutter_map + Material 3 Canvas Rendering',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'System Architecture'),
      drawer: const NavDrawer(currentRoute: '/architecture'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Architecture Header Intro
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
                    children: [
                      const Icon(Icons.account_tree_rounded, color: AppColors.primaryBlue, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'FineLine Intelligent Pipeline',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'End-to-end dataflow from raw smartphone inertial sensors to sub-meter navigation output. Tap any block for technical implementation details.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Flow Diagram with Animated Blocks & Arrows
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _architectureBlocks.length,
              itemBuilder: (context, index) {
                final block = _architectureBlocks[index];
                final isSelected = _selectedBlockIndex == index;
                final Color blockColor = block['color'] as Color;

                return Column(
                  children: [
                    // Flow Block
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedBlockIndex = isSelected ? null : index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? blockColor : (isDark ? AppColors.cardBorder : AppColors.lightBorder),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected ? blockColor.withOpacity(0.2) : Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: blockColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(block['icon'] as IconData, color: blockColor, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        block['title'] as String,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        block['subtitle'] as String,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: blockColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isSelected ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ],
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 14),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Text(
                                block['desc'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.code_rounded, size: 14, color: AppColors.primaryBlue),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Core Tech: ${block['tech']}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: (index * 80).ms, duration: 400.ms).slideY(begin: 0.1, end: 0),

                    // Downward Connecting Flow Arrow (except after last item)
                    if (index < _architectureBlocks.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 14,
                              width: 2,
                              color: AppColors.primaryBlue.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_downward_rounded,
                              size: 16,
                              color: AppColors.primaryBlue.withOpacity(0.8),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: (index * 80 + 40).ms),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
