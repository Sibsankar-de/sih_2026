import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

class NavDrawer extends StatelessWidget {
  final String currentRoute;

  const NavDrawer({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final selectedColor = isDark ? AppColors.primaryBlueLight : AppColors.primaryBlue;

    return Drawer(
      backgroundColor: drawerBg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.cardBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selectedColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.navigation_rounded,
                    color: selectedColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Intelligent Dead Reckoning',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selectedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              children: [
                _buildDrawerItem(
                  context: context,
                  icon: Icons.map_outlined,
                  selectedIcon: Icons.map_rounded,
                  title: 'Map Navigation',
                  subtitle: 'Real-time location & tracking',
                  route: '/',
                  selected: currentRoute == '/' || currentRoute == '/navigation',
                  selectedColor: selectedColor,
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.analytics_outlined,
                  selectedIcon: Icons.analytics_rounded,
                  title: 'System Telemetry',
                  subtitle: 'EKF 8-state, AI models & sensors',
                  route: '/telemetry',
                  selected: currentRoute == '/telemetry' || currentRoute == '/fusion',
                  selectedColor: selectedColor,
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.science_outlined,
                  selectedIcon: Icons.science_rounded,
                  title: 'Simulations',
                  subtitle: 'Tunnel, urban canyon & dataset',
                  route: '/simulation',
                  selected: currentRoute == '/simulation',
                  selectedColor: selectedColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.cardBorder : AppColors.lightBorder,
                ),
                const SizedBox(height: 12),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings_rounded,
                  title: 'Settings',
                  subtitle: 'Units, theme & preferences',
                  route: '/settings',
                  selected: currentRoute == '/settings',
                  selectedColor: selectedColor,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.cardBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Autonomous Dead Reckoning',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                Text(
                  AppConstants.appVersion.split(' ').first,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selectedColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    required String subtitle,
    required String route,
    required bool selected,
    required Color selectedColor,
    required bool isDark,
  }) {
    final textColor = selected
        ? selectedColor
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final subtitleColor = selected
        ? selectedColor.withValues(alpha: 0.8)
        : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight);
    final iconColor = selected
        ? selectedColor
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: selected
            ? selectedColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Icon(selected ? selectedIcon : icon, color: iconColor, size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: textColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: subtitleColor,
          ),
        ),
        dense: true,
        onTap: () {
          Navigator.of(context).pop();
          if (!selected) {
            context.go(route);
          }
        },
      ),
    );
  }
}
