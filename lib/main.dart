import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'theme/app_theme.dart';
import 'providers/app_state_provider.dart';
import 'providers/run_provider.dart';
import 'providers/crew_provider.dart';
import 'providers/hex_data_provider.dart';
import 'screens/team_selection_screen.dart';
import 'screens/home_screen.dart';
import 'config/mapbox_config.dart';
import 'services/hex_service.dart';
import 'services/location_service.dart';
import 'services/run_tracker.dart';
import 'services/in_memory_storage_service.dart';
import 'services/points_service.dart';
import 'services/supabase_service.dart';
import 'services/flip_cooldown_service.dart';
import 'storage/local_storage.dart';

/// Global LocalStorage instance for flip cooldown persistence
late final LocalStorage _localStorage;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService.initialize();

  // Initialize HexService
  await HexService().initialize();

  // Initialize LocalStorage for flip cooldown persistence
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

/// Create and initialize FlipCooldownService with LocalStorage callbacks
FlipCooldownService _createFlipCooldownService() {
  final service = FlipCooldownService(
    cooldownDuration: const Duration(minutes: 10),
  );
  // For MVP, we use a fixed user ID - in production this comes from auth
  const userId = 'local_user';

  service.initialize(
    userId: userId,
    onFlipRecorded: (hexId, timestamp) async {
      await _localStorage.recordFlipWithTimestamp(
        userId: userId,
        hexId: hexId,
        timestamp: timestamp,
      );
    },
    loadRecentFlips: () async {
      return await _localStorage.getRecentFlips(
        userId: userId,
        maxAge: FlipCooldownService.defaultCooldown,
      );
    },
    cleanupOldFlips: (maxAge) async {
      await _localStorage.cleanupOldFlips(maxAge: maxAge);
    },
  );

  return service;
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
        ChangeNotifierProvider(create: (_) => _createFlipCooldownService()),
        ChangeNotifierProxyProvider2<
          PointsService,
          FlipCooldownService,
          RunProvider
        >(
          create: (context) {
            final flipCooldownService = context.read<FlipCooldownService>();
            // Connect FlipCooldownService to HexDataProvider singleton
            HexDataProvider().setFlipCooldownService(flipCooldownService);

            final provider = RunProvider(
              locationService: LocationService(),
              runTracker: RunTracker(),
              storageService: InMemoryStorageService(),
              pointsService: context.read<PointsService>(),
            );
            provider.initialize();
            return provider;
          },
          update: (context, pointsService, flipCooldownService, previous) {
            previous?.updatePointsService(pointsService);
            // Ensure FlipCooldownService stays connected
            HexDataProvider().setFlipCooldownService(flipCooldownService);
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
