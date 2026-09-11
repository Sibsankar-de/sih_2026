import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/services/navigation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/simulation_scenario.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/nav_drawer.dart';

class SimulationCenterScreen extends StatelessWidget {
  const SimulationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final navService = context.watch<NavigationService>();
    final scenarios = SimulationScenario.getAllScenarios();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Simulation Center',
        actions: [
          IconButton(
            icon: Icon(
              navService.state.isSimulationActive ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
              color: navService.state.isSimulationActive ? AppColors.statusYellow : AppColors.statusGreen,
              size: 28,
            ),
            tooltip: navService.state.isSimulationActive ? 'Pause Simulation' : 'Resume Simulation',
            onPressed: () {
              navService.toggleSimulation(!navService.state.isSimulationActive);
            },
          ),
        ],
      ),
      drawer: const NavDrawer(currentRoute: '/simulation'),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: scenarios.length,
        itemBuilder: (context, index) {
          final scenario = scenarios[index];
          final isSelected = navService.currentScenario.type == scenario.type;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primaryBlue : (isDark ? AppColors.cardBorder : AppColors.lightBorder),
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.primaryBlue.withOpacity(0.18)
                      : Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        scenario.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? AppColors.primaryBlue
                              : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.4)),
                      ),
                      child: Text(
                        scenario.badgeText,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  scenario.description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                // Challenge & Limits Row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Environmental Factor', scenario.environmentChallenge, isDark),
                      const SizedBox(height: 6),
                      _buildDetailRow('Outage Duration', '${scenario.expectedOutageDurationSec.toInt()} seconds', isDark),
                      const SizedBox(height: 6),
                      _buildDetailRow('Max Tolerable Drift', '< ${scenario.maxExpectedDriftMeters} meters', isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? AppColors.primaryBlue : (isDark ? AppColors.darkSurface : AppColors.lightBackground),
                          foregroundColor: isSelected ? Colors.black : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                          side: BorderSide(
                            color: isSelected ? AppColors.primaryBlue : (isDark ? AppColors.cardBorder : AppColors.lightBorder),
                          ),
                        ),
                        icon: Icon(isSelected ? Icons.check_circle_rounded : Icons.play_arrow_rounded, size: 18),
                        label: Text(isSelected ? 'Active Scenario' : 'Launch Scenario'),
                        onPressed: () {
                          navService.switchScenario(scenario.type.name);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('View Live'),
                      onPressed: () {
                        if (!isSelected) {
                          navService.switchScenario(scenario.type.name);
                        }
                        context.go('/navigation');
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }
}
