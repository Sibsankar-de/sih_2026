import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;
  String _statusText = 'Booting navigation framework...';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startBootSequence();
  }

  void _startBootSequence() {
    const totalSteps = 10;
    int currentStep = 0;

    final statuses = [
      'Booting navigation framework...',
      'Initializing hardware IMU abstraction layer...',
      'Binding WGS-84 / ENU local tangent frame...',
      'Loading IO-VNBD velocity estimator weights...',
      'Initializing road vibration CNN classifier...',
      'Loading 6-class motion temporal model...',
      'Configuring 8-state Extended Kalman Filter...',
      'Calibrating process & measurement noise matrices...',
      'Establishing offline OSM vector tiles cache...',
      'Autonomous dead reckoning engine ready.',
    ];

    _timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      currentStep++;
      if (currentStep <= totalSteps) {
        setState(() {
          _progress = currentStep / totalSteps;
          _statusText = statuses[currentStep - 1];
        });
      } else {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            context.go('/');
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Clean Logo Badge
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.cardBorder, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: AppColors.primaryBlueLight,
                    size: 38,
                  ),
                ).animate().scale(duration: 500.ms, curve: Curves.easeOutCubic),
                const SizedBox(height: 24),
                // App Title
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryDark,
                    letterSpacing: -0.3,
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 10),
                const Text(
                  'AI-ML Based Intelligent Dead Reckoning System',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryDark,
                    fontWeight: FontWeight.w400,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                const Spacer(),
                // Progress Indicator & Status Message
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _statusText,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMutedDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlueLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: AppColors.darkCard,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlueLight),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
