import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'theme/app_theme.dart';
import 'providers/app_state_provider.dart';
import 'providers/run_provider.dart';
import 'providers/crew_provider.dart';
import 'screens/team_selection_screen.dart';
import 'screens/home_screen.dart';
import 'config/mapbox_config.dart';
import 'services/hex_service.dart';
import 'services/location_service.dart';
import 'services/run_tracker.dart';
import 'services/in_memory_storage_service.dart';
import 'services/points_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize HexService
  await HexService().initialize();

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
        ChangeNotifierProvider(
          create: (_) => PointsService(
            initialPoints: 0, // Start fresh, or load from storage
          ),
        ),
        ChangeNotifierProxyProvider<PointsService, RunProvider>(
          create: (context) {
            final provider = RunProvider(
              locationService: LocationService(),
              runTracker: RunTracker(),
              storageService: InMemoryStorageService(),
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
