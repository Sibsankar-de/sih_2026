import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final String currentRoute;

  const AppBottomNav({
    super.key,
    required this.currentRoute,
  });

  int _getSelectedIndex() {
    switch (currentRoute) {
      case '/':
      case '/navigation':
        return 0;
      case '/telemetry':
      case '/fusion':
      case '/ai-speed':
      case '/sensors':
        return 1;
      case '/simulation':
        return 2;
      case '/settings':
        return 3;
      default:
        return 0;
    }
  }

  void _onDestinationSelected(BuildContext context, int index) {
    String target;
    switch (index) {
      case 0:
        target = '/';
        break;
      case 1:
        target = '/telemetry';
        break;
      case 2:
        target = '/simulation';
        break;
      case 3:
        target = '/settings';
        break;
      default:
        target = '/';
    }
    if (target != currentRoute) {
      context.go(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.cardBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _getSelectedIndex(),
        onDestinationSelected: (index) => _onDestinationSelected(context, index),
        height: 64,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'Telemetry',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science_rounded),
            label: 'Simulations',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
