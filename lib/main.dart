import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'theme/app_theme.dart';
import 'providers/app_state_provider.dart';
import 'providers/run_provider.dart';
import 'providers/crew_provider.dart';
import 'providers/leaderboard_provider.dart';
import 'providers/hex_data_provider.dart';
import 'screens/team_selection_screen.dart';
import 'screens/home_screen.dart';
import 'config/mapbox_config.dart';
import 'services/hex_service.dart';
import 'services/location_service.dart';
import 'services/run_tracker.dart';
// import 'services/in_memory_storage_service.dart'; // Now using LocalStorage
import 'services/points_service.dart';
import 'services/supabase_service.dart';
import 'storage/local_storage.dart';

/// Global LocalStorage instance for run history persistence
late final LocalStorage _localStorage;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService.initialize();

  // Initialize HexService
  await HexService().initialize();

  // Initialize LocalStorage for run history persistence
  _localStorage = LocalStorage();
  await _localStorage.initialize();

  // Set Mapbox access token
  MapboxOptions.setAccessToken(MapboxConfig.accessToken);

  // Set system UI overlay style for premium dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.backgroundStart,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const RunnerApp());
}

class RunnerApp extends StatelessWidget {
  const RunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider(create: (_) => HexDataProvider()),
        ChangeNotifierProvider(create: (_) => PointsService(initialPoints: 0)),
        ChangeNotifierProxyProvider<PointsService, RunProvider>(
          create: (context) {
            final provider = RunProvider(
              locationService: LocationService(),
              runTracker: RunTracker(),
              storageService: _localStorage, // Use SQLite for run persistence
              pointsService: context.read<PointsService>(),
            );
            provider.initialize();
            return provider;
          },
          update: (context, pointsService, previous) {
            previous?.updatePointsService(pointsService);
            return previous!;
          },
        ),
        ChangeNotifierProvider(create: (_) => CrewProvider()),
        ChangeNotifierProvider(create: (_) => LeaderboardProvider()),
      ],
      child: MaterialApp(
        title: 'RUN',
        theme: AppTheme.themeData,
        themeMode: ThemeMode.dark,
        debugShowCheckedModeBanner: false,
        home: Consumer<AppStateProvider>(
          builder: (context, appState, _) {
            return appState.hasUser
                ? const HomeScreen()
                : const TeamSelectionScreen();
          },
        ),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/team-selection': (context) => const TeamSelectionScreen(),
        },
      ),
    );
  }
}
