import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/services/navigation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/simulation_scenario.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/nav_drawer.dart';

class SimulationCenterScreen extends StatelessWidget {
  const SimulationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final navService = context.watch<NavigationService>();
    final scenarios = SimulationScenario.getAllScenarios();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.cardBorder : AppColors.lightBorder;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final activeColor = isDark ? AppColors.primaryBlueLight : AppColors.primaryBlue;
    final isSimActive = navService.state.isSimulationActive;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Simulation Scenarios',
        actions: [
          if (isSimActive)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                icon: const Icon(Icons.stop_circle_outlined, color: AppColors.statusRed, size: 18),
                label: const Text('Exit Sim', style: TextStyle(color: AppColors.statusRed, fontWeight: FontWeight.w700)),
                onPressed: () {
                  navService.stopSimulation();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Simulation ended. Returned to live tracking.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      drawer: const NavDrawer(currentRoute: '/simulation'),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/simulation'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Mode Status Header Banner
          if (isSimActive)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.statusYellow.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.statusYellow.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.science_rounded, color: AppColors.statusYellow, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Simulation Active: ${navService.currentScenario.title}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.statusYellow,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The map is currently replaying simulated vehicle kinematics and testing dead reckoning during GNSS degradation.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: const Size(100, 34),
                        ),
                        icon: const Icon(Icons.map_rounded, size: 16),
                        label: const Text('View on Map', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        onPressed: () => context.go('/'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.statusRed,
                          side: const BorderSide(color: AppColors.statusRed),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(80, 34),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Stop Simulation', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          navService.stopSimulation();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Simulation stopped. Live GPS mode resumed.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed_rounded, color: AppColors.statusGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Hardware Tracking Active',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select any scenario below to benchmark AI dead reckoning and EKF resilience.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Scenario Cards Header
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text(
              'Curated Benchmark Scenarios (3)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),

          // List of Scenarios
          ...scenarios.map((scenario) {
            final isCurrent = isSimActive && navService.currentScenario.type == scenario.type;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent ? activeColor : borderColor,
                  width: isCurrent ? 2.0 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scenario.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isCurrent
                                      ? activeColor
                                      : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                scenario.badgeText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: activeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.statusGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.statusGreen),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 7, color: AppColors.statusGreen),
                                SizedBox(width: 4),
                                Text(
                                  'RUNNING',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.statusGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Description
                    Text(
                      scenario.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Challenge info box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.psychology_outlined, size: 14, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              scenario.environmentChallenge,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Metrics Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildInfoChip(
                          icon: Icons.timer_outlined,
                          label: '${scenario.expectedOutageDurationSec.toInt()}s outage',
                          isDark: isDark,
                        ),
                        _buildInfoChip(
                          icon: Icons.straighten_rounded,
                          label: 'Max drift: ±${scenario.maxExpectedDriftMeters.toStringAsFixed(1)}m',
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: isCurrent
                          ? ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: activeColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.navigation_rounded, size: 16),
                              label: const Text('View on Map', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              onPressed: () => context.go('/'),
                            )
                          : ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                                foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                side: BorderSide(color: activeColor.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: Icon(Icons.play_arrow_rounded, size: 18, color: activeColor),
                              label: Text(
                                'Start Simulation',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: activeColor),
                              ),
                              onPressed: () {
                                navService.startSimulation(scenario);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Started simulation: ${scenario.title}'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                context.go('/');
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
