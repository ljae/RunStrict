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
import 'services/remote_config_service.dart';
import 'services/prefetch_service.dart';
import 'services/app_lifecycle_manager.dart';
import 'storage/local_storage.dart';

/// Global LocalStorage instance for run history persistence
late final LocalStorage _localStorage;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService.initialize();

  // Initialize RemoteConfig (fallback chain: server → cache → defaults)
  await RemoteConfigService().initialize();

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
        home: const _AppInitializer(),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/team-selection': (context) => const TeamSelectionScreen(),
        },
      ),
    );
  }
}

/// Handles app initialization: restores session then navigates
class _AppInitializer extends StatefulWidget {
  const _AppInitializer();

  @override
  State<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer> {
  bool _isPrefetching = false;
  String? _prefetchError;

  @override
  void initState() {
    super.initState();
    // Defer initialization until after the build phase completes
    // This prevents "setState() called during build" errors when
    // AppStateProvider.initialize() calls notifyListeners()
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    final appState = context.read<AppStateProvider>();
    await appState.initialize();

    // After app state is initialized and user exists, initialize prefetch
    if (appState.hasUser && mounted) {
      await _initializePrefetch();
    }

    // Initialize AppLifecycleManager for data refresh on resume
    if (mounted) {
      _initializeLifecycleManager();
    }
  }

  Future<void> _initializePrefetch() async {
    if (!mounted) return;

    setState(() {
      _isPrefetching = true;
      _prefetchError = null;
    });

    try {
      await PrefetchService().initialize();
      debugPrint('AppInitializer: PrefetchService initialized successfully');
    } catch (e) {
      debugPrint('AppInitializer: PrefetchService failed - $e');
      if (mounted) {
        setState(() {
          _prefetchError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrefetching = false;
        });
      }
    }
  }

  void _initializeLifecycleManager() {
    final runProvider = context.read<RunProvider>();
    final leaderboardProvider = context.read<LeaderboardProvider>();

    AppLifecycleManager().initialize(
      isRunning: () => runProvider.isRunning,
      onRefresh: () async {
        // Refresh prefetched data (hex colors, leaderboard)
        await PrefetchService().refresh();
        // Also refresh leaderboard provider
        await leaderboardProvider.refreshLeaderboard();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        // Show loading while initializing
        if (!appState.isInitialized) {
          return _buildLoadingScreen('Initializing...');
        }

        // Show loading while prefetching (only if user exists)
        if (appState.hasUser && _isPrefetching) {
          return _buildLoadingScreen('Getting your location...');
        }

        // Show error with retry option if prefetch failed
        if (appState.hasUser && _prefetchError != null) {
          return _buildErrorScreen(_prefetchError!);
        }

        // After initialization, show appropriate screen
        return appState.hasUser
            ? const HomeScreen()
            : const TeamSelectionScreen();
      },
    );
  }

  Widget _buildLoadingScreen(String message) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'RUN',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.electricBlue),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'RUN',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 32),
              Icon(
                Icons.location_off,
                size: 48,
                color: AppTheme.athleticRed.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'Location Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'RunStrict needs your location to show nearby runners and territories.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializePrefetch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.electricBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Try Again'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // Allow user to continue without prefetch
                  setState(() {
                    _prefetchError = null;
                  });
                },
                child: Text(
                  'Continue without location',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
