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
  String _statusText = 'Initializing Sensors & IMU Pipeline...';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startInitSequence();
  }

  void _startInitSequence() {
    _timer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted) return;
      setState(() {
        _progress += 0.015;
        if (_progress > 0.25 && _progress < 0.55) {
          _statusText = 'Calibrating Extended Kalman Filter (EKF)...';
        } else if (_progress >= 0.55 && _progress < 0.85) {
          _statusText = 'Loading Deep Learning Velocity Models...';
        } else if (_progress >= 0.85 && _progress < 1.0) {
          _statusText = 'Synchronizing Map Matching Topology...';
        } else if (_progress >= 1.0) {
          _progress = 1.0;
          _timer?.cancel();
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              context.go('/');
            }
          });
        }
      });
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
      body: Stack(
        children: [
          // Background subtle cyber glow
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryBlue.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    // Animated Logo Mark
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.primaryBlue, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.explore_rounded,
                        color: AppColors.primaryBlue,
                        size: 54,
                      ),
                    )
                        .animate()
                        .scale(duration: 800.ms, curve: Curves.easeOutBack)
                        .shimmer(delay: 600.ms, duration: 1200.ms),
                    const SizedBox(height: 28),
                    // App Title
                    Text(
                      AppConstants.appName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimaryDark,
                        letterSpacing: 0.8,
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 8),
                    // Subtitle / Problem Code
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.4)),
                      ),
                      child: const Text(
                        'Smart India Hackathon 2026 • SIH26168',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
                    const SizedBox(height: 12),
                    Text(
                      'AI-ML Based Intelligent Dead Reckoning System',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryDark.withOpacity(0.9),
                        fontWeight: FontWeight.w400,
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 600.ms),
                    const Spacer(),
                    // Progress Indicator & Status Message
                    Column(
                      children: [
                        Text(
                          'Initializing Intelligent Navigation Engine',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 6,
                            child: LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: AppColors.darkCard,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _statusText,
                                style: TextStyle(
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
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
