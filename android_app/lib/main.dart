import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/services/fusion_service.dart';
import 'core/services/location_service.dart';
import 'core/services/map_matching_service.dart';
import 'core/services/mock_ai_service.dart';
import 'core/services/navigation_service.dart';
import 'core/services/sensor_service.dart';
import 'core/theme/app_theme.dart';
import 'features/fusion_demo/fusion_screen.dart';
import 'features/navigation/navigation_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/simulation/simulation_center_screen.dart';
import 'features/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FineLineApp());
}

class FineLineApp extends StatefulWidget {
  const FineLineApp({super.key});

  @override
  State<FineLineApp> createState() => _FineLineAppState();
}

class _FineLineAppState extends State<FineLineApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  late final GoRouter _router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const NavigationScreen(),
      ),
      GoRoute(
        path: '/navigation',
        builder: (context, state) => const NavigationScreen(),
      ),
      GoRoute(
        path: '/telemetry',
        builder: (context, state) => const FusionScreen(),
      ),
      GoRoute(
        path: '/fusion',
        builder: (context, state) => const FusionScreen(),
      ),
      GoRoute(
        path: '/ai-speed',
        builder: (context, state) => const FusionScreen(),
      ),
      GoRoute(
        path: '/sensors',
        builder: (context, state) => const FusionScreen(),
      ),
      GoRoute(
        path: '/simulation',
        builder: (context, state) => const SimulationCenterScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => SettingsScreen(
          currentThemeMode: _themeMode,
          onThemeModeChanged: _setThemeMode,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SensorService>(create: (_) => SensorService()),
        Provider<LocationService>(create: (_) => LocationService()),
        Provider<MockAIService>(create: (_) => MockAIService()),
        Provider<FusionService>(create: (_) => FusionService()),
        Provider<MapMatchingService>(create: (_) => MapMatchingService()),
        ChangeNotifierProvider<NavigationService>(
          create: (context) => NavigationService(
            sensorService: context.read<SensorService>(),
            locationService: context.read<LocationService>(),
            aiService: context.read<MockAIService>(),
            fusionService: context.read<FusionService>(),
            mapMatchingService: context.read<MapMatchingService>(),
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'Fine Line',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode,
        routerConfig: _router,
      ),
    );
  }
}
