import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/navigation_state.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final SignalHealth health;
  final String? customText;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.health,
    this.customText,
    this.icon,
  });

  Color _getColor() {
    switch (health) {
      case SignalHealth.excellent:
        return AppColors.statusGreen;
      case SignalHealth.degraded:
        return AppColors.statusYellow;
      case SignalHealth.lost:
        return AppColors.statusRed;
    }
  }

  String _getText() {
    if (customText != null) return customText!;
    switch (health) {
      case SignalHealth.excellent:
        return 'ONLINE';
      case SignalHealth.degraded:
        return 'DEGRADED';
      case SignalHealth.lost:
        return 'OFFLINE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            '$label: ${_getText()}',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
