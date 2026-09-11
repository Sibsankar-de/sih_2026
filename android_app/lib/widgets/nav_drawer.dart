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
    final selectedColor = AppColors.primaryBlue;

    return Drawer(
      backgroundColor: drawerBg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0D1B44), const Color(0xFF070D1E)]
                    : [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)],
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.cardBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryBlue, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: AppColors.primaryBlue,
                    size: 26,
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
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SIH 2026 • SIH26168',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
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
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              children: [
                _buildDrawerItem(
                  context: context,
                  icon: Icons.dashboard_outlined,
                  title: 'Home Dashboard',
                  route: '/',
                  selected: currentRoute == '/',
                  selectedColor: selectedColor,
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.map_outlined,
                  title: 'Live Navigation',
                  route: '/navigation',
                  selected: currentRoute == '/navigation',
                  selectedColor: selectedColor,
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.sensors_outlined,
                  title: 'Sensor Monitoring',
                  route: '/sensors',
                  selected: currentRoute == '/sensors',
                  selectedColor: selectedColor,
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.speed_outlined,
                  title: 'AI Speed Estimation',
                  route: '/ai-speed',
                  selected: currentRoute == '/ai-speed',
                  selectedColor: selectedColor,
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.hub_outlined,
                  title: 'GNSS + INS Fusion',
                  route: '/fusion',
                  selected: currentRoute == '/fusion',
                  selectedColor: selectedColor,
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.science_outlined,
                  title: 'Simulation Center',
                  route: '/simulation',
                  selected: currentRoute == '/simulation',
                  selectedColor: selectedColor,
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.account_tree_outlined,
                  title: 'System Architecture',
                  route: '/architecture',
                  selected: currentRoute == '/architecture',
                  selectedColor: selectedColor,
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.menu_book_outlined,
                  title: 'Research & References',
                  route: '/research',
                  selected: currentRoute == '/research',
                  selectedColor: selectedColor,
                  isDark: isDark,
                ),
                const Divider(height: 20),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  route: '/settings',
                  selected: currentRoute == '/settings',
                  selectedColor: selectedColor,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.cardBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SIH 2026 Finalist Edition',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                Text(
                  AppConstants.appVersion.split(' ').first,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
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
    required String title,
    required String route,
    required bool selected,
    required Color selectedColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          size: 20,
          color: selected
              ? selectedColor
              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? selectedColor
                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
          ),
        ),
        selected: selected,
        selectedTileColor: selectedColor.withOpacity(0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () {
          Navigator.pop(context); // Close drawer
          if (!selected) {
            context.go(route);
          }
        },
      ),
    );
  }
}
