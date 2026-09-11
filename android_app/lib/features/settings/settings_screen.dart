import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/nav_drawer.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const SettingsScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _useKmh = true;
  bool _showGhostTrajectory = true;
  double _simulationMultiplier = 1.0;
  double _driftTolerance = 5.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryBlueLight : AppColors.primaryBlue;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Settings'),
      drawer: const NavDrawer(currentRoute: '/settings'),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Settings
          _buildSettingsSection(
            title: 'Appearance & Theme',
            icon: Icons.palette_outlined,
            isDark: isDark,
            children: [
              ListTile(
                title: const Text('Theme Mode', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  widget.currentThemeMode == ThemeMode.system
                      ? 'System Adaptive'
                      : widget.currentThemeMode == ThemeMode.dark
                          ? 'Automotive Dark'
                          : 'Clean Light',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                trailing: DropdownButton<ThemeMode>(
                  value: widget.currentThemeMode,
                  underline: const SizedBox(),
                  dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark Mode', style: TextStyle(fontSize: 13)),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light Mode', style: TextStyle(fontSize: 13)),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) {
                      widget.onThemeModeChanged(mode);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Unit Preferences
          _buildSettingsSection(
            title: 'Units & Measurements',
            icon: Icons.straighten_rounded,
            isDark: isDark,
            children: [
              SwitchListTile(
                title: const Text('Metric Speed (km/h)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _useKmh ? 'Displaying speeds in km/h' : 'Displaying speeds in m/s',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                ),
                value: _useKmh,
                onChanged: (val) {
                  setState(() {
                    _useKmh = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Map & Navigation Settings
          _buildSettingsSection(
            title: 'Map & Display',
            icon: Icons.map_outlined,
            isDark: isDark,
            children: [
              SwitchListTile(
                title: const Text('Show Raw GNSS Ghost Path', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Displays unfiltered / multipath GNSS ghost position during outages',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                ),
                value: _showGhostTrajectory,
                onChanged: (val) {
                  setState(() {
                    _showGhostTrajectory = val;
                  });
                },
              ),
              ListTile(
                title: const Text('Map Provider', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'OpenStreetMap (OSM Standard Tiles)',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                ),
                trailing: const Icon(Icons.check_circle_rounded, color: AppColors.statusGreen, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Simulation Tuning
          _buildSettingsSection(
            title: 'Dead Reckoning & EKF Tuning',
            icon: Icons.tune_rounded,
            isDark: isDark,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Simulation Speed Multiplier', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${_simulationMultiplier.toStringAsFixed(1)}x', style: TextStyle(fontWeight: FontWeight.w700, color: primaryColor)),
                      ],
                    ),
                    Slider(
                      value: _simulationMultiplier,
                      min: 0.5,
                      max: 3.0,
                      divisions: 5,
                      onChanged: (val) {
                        setState(() {
                          _simulationMultiplier = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Max Allowed Drift Threshold', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${_driftTolerance.toStringAsFixed(1)} m', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.statusYellow)),
                      ],
                    ),
                    Slider(
                      value: _driftTolerance,
                      min: 1.0,
                      max: 10.0,
                      divisions: 9,
                      onChanged: (val) {
                        setState(() {
                          _driftTolerance = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // About App Section
          _buildSettingsSection(
            title: 'About ${AppConstants.appName}',
            icon: Icons.info_outline_rounded,
            isDark: isDark,
            children: [
              ListTile(
                title: const Text(AppConstants.appName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                subtitle: const Text(
                  'AI-ML Based Intelligent Dead Reckoning System',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                trailing: Text(
                  AppConstants.appVersion,
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Autonomous multi-model edge AI inference pipeline (Velocity CNN-GRU, Road Vibration 1D-CNN, Motion State Classifier) tightly coupled with an 8-state Extended Kalman Filter (EKF) with Local Tangent Plane (ENU) mechanization, Non-Holonomic Constraints (NHC), and Zero Velocity Updates (ZUPT).',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isDark,
  }) {
    final borderColor = isDark ? AppColors.cardBorder : AppColors.lightBorder;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final primaryColor = isDark ? AppColors.primaryBlueLight : AppColors.primaryBlue;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 17, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}
