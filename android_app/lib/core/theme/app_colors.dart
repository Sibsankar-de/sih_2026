import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand & UI Accents (Professional Cobalt / Slate)
  static const Color primaryBlue = Color(0xFF2563EB); // Tailwind Blue 600
  static const Color primaryBlueLight = Color(0xFF3B82F6); // Tailwind Blue 500
  static const Color deepNavy = Color(0xFF0F172A); // Slate 900

  // Dark Theme Surfaces (Clean Slate / Charcoal, no harsh neon)
  static const Color darkBackground = Color(0xFF0B0F19); // Deep dark slate
  static const Color darkSurface = Color(0xFF111827);    // Slate 900
  static const Color darkCard = Color(0xFF1F2937);       // Slate 800
  static const Color cardBorder = Color(0xFF374151);     // Slate 700 subtle border

  // Text Dark
  static const Color textPrimaryDark = Color(0xFFF9FAFB);   // Slate 50
  static const Color textSecondaryDark = Color(0xFF9CA3AF); // Slate 400
  static const Color textMutedDark = Color(0xFF6B7280);     // Slate 500

  // Light Theme Surfaces (Clean neutral canvas)
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);    // White
  static const Color lightCard = Color(0xFFFFFFFF);       // White
  static const Color lightBorder = Color(0xFFE2E8F0);     // Slate 200

  // Text Light
  static const Color textPrimaryLight = Color(0xFF0F172A);   // Slate 900
  static const Color textSecondaryLight = Color(0xFF475569); // Slate 600
  static const Color textMutedLight = Color(0xFF94A3B8);     // Slate 400

  // Semantic Status Colors (Automotive Standards)
  static const Color statusGreen = Color(0xFF10B981);  // Emerald 500 (GNSS Locked / Optimal)
  static const Color statusYellow = Color(0xFFF59E0B); // Amber 500 (Dead Reckoning / Warning)
  static const Color statusRed = Color(0xFFEF4444);    // Red 500 (Outage / Alert)
  static const Color statusPurple = Color(0xFF8B5CF6); // Violet 500 (EKF Analytics)
  static const Color statusCyan = Color(0xFF0EA5E9);   // Sky 500 (Sensor / Heading)

  // Navigation Map Paths (High contrast, clearly distinguishable)
  static const Color routePath = Color(0xFF3B82F6);    // Clean Planned Route
  static const Color gnssPath = Color(0xFF10B981);     // Pure GNSS Ground Truth
  static const Color insDriftPath = Color(0xFFEF4444); // Uncorrected INS Drift
  static const Color fusedPath = Color(0xFF8B5CF6);    // AI+EKF Fused Trajectory
}
