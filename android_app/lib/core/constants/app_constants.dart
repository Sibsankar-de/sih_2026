class AppConstants {
  static const String appName = 'FineLine Navigator';
  static const String appSubtitle = 'Intelligent Dead Reckoning Navigation';
  static const String sihProblemCode = 'SIH26168';
  static const String sihProblemTitle = 'AI-ML Based Intelligent Dead Reckoning System for Seamless Navigation';
  static const String appVersion = 'v1.0.0 (SIH 2026 Edition)';

  // OpenStreetMap Tile URL
  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String mapPackageUserAgent = 'com.sih2026.fineline_navigator';

  // Navigation & Refresh Rates
  static const int sensorSamplingRateMs = 50; // 20 Hz
  static const int navigationUpdateRateMs = 100; // 10 Hz
  static const int chartBufferSize = 40;

  // Initial Coordinates (e.g. New Delhi Innovation Hub route)
  static const double defaultLatitude = 28.6139;
  static const double defaultLongitude = 77.2090;
  static const double defaultZoom = 16.5;

  // Storage Keys
  static const String prefThemeMode = 'pref_theme_mode';
  static const String prefSpeedUnit = 'pref_speed_unit';
  static const String prefDriftThreshold = 'pref_drift_threshold';
  static const String prefMapStyle = 'pref_map_style';
}
