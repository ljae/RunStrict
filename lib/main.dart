import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'theme/app_theme.dart';
import 'models/user_model.dart';
import 'providers/app_state_provider.dart';
import 'providers/run_provider.dart';
import 'providers/leaderboard_provider.dart';
import 'providers/hex_data_provider.dart';
import 'screens/login_screen.dart';
import 'screens/profile_register_screen.dart';
import 'screens/team_selection_screen.dart';
import 'screens/season_register_screen.dart';
import 'screens/home_screen.dart';
import 'config/mapbox_config.dart';
import 'services/hex_service.dart';
import 'services/location_service.dart';
import 'services/run_tracker.dart';
import 'services/points_service.dart';
import 'services/supabase_service.dart';
import 'services/remote_config_service.dart';
import 'services/prefetch_service.dart';
import 'services/app_lifecycle_manager.dart';
import 'services/buff_service.dart';
import 'services/ad_service.dart';
import 'services/sync_retry_service.dart';
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

  // One-time cleanup: remove local-only runs that were never synced to server.
  // This ensures the app shows only server-verified data for production review.
  final deletedCount = await _localStorage.deleteUnsyncedRuns();
  if (deletedCount > 0) {
    debugPrint('main: Cleaned up $deletedCount unsynced local runs');
  }

  // Initialize AdMob SDK
  await AdService().initialize();

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
          '/login': (context) => const LoginScreen(),
          '/profile-register': (context) => const ProfileRegisterScreen(),
          '/team-selection': (context) => const TeamSelectionScreen(),
          '/season-register': (context) => const SeasonRegisterScreen(),
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
  // Start true to prevent HomeScreen from rendering before prefetch.
  // Set to false after prefetch completes, or if user is not logged in.
  bool _isPrefetching = true;
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

    if (appState.hasUser && mounted) {
      await Future.wait([
        _initializePrefetch(),
        _loadTodayFlipPoints(),
        _retryFailedSyncs(),
      ]);
    } else if (mounted) {
      // No user — no prefetch needed, allow login screen to render
      setState(() {
        _isPrefetching = false;
      });
    }

    if (mounted) {
      _initializeLifecycleManager();
    }
  }

  Future<void> _loadTodayFlipPoints() async {
    if (!mounted) return;

    final appState = context.read<AppStateProvider>();
    final pointsService = context.read<PointsService>();

    if (!appState.hasUser) return;

    try {
      final supabase = SupabaseService();
      // Use PrefetchService as single source of truth for home hex
      final launchCityHex = PrefetchService().homeHexCity;
      final result = await supabase.appLaunchSync(
        appState.currentUser!.id,
        districtHex: launchCityHex,
      );

      final userStats = result['user_stats'] as Map<String, dynamic>?;
      final seasonPoints = (userStats?['season_points'] as num?)?.toInt() ?? 0;
      pointsService.setSeasonPoints(seasonPoints);

      if (userStats != null && appState.currentUser != null) {
        appState.setUser(
          UserModel.mergeWithServerStats(
            appState.currentUser!,
            userStats,
            seasonPoints,
          ),
        );
      }

      final userBuff = result['user_buff'] as Map<String, dynamic>?;
      BuffService().setBuffFromLaunchSync(userBuff);

      await pointsService.refreshFromLocalTotal();

      debugPrint(
        'AppInitializer: Launch sync - '
        'buff: ${BuffService().multiplier}x, '
        'todayTotal: ${pointsService.todayFlipPoints}, '
        'season: $seasonPoints',
      );
    } catch (e) {
      debugPrint('AppInitializer: Failed to load today flip points - $e');
      // Derive season points from local runs when server is unavailable
      final localSeasonPoints = await _localStorage.sumAllFlipPoints();
      if (localSeasonPoints > 0) {
        pointsService.setSeasonPoints(localSeasonPoints);
      }
      // Still try to load local unsynced points even if server fails
      await pointsService.refreshLocalUnsyncedPoints();
    }
  }

  /// Retry any runs that failed to sync on previous sessions.
  /// Called on initial app launch (complements OnResume retry).
  Future<void> _retryFailedSyncs() async {
    if (!mounted) return;
    final pointsService = context.read<PointsService>();
    try {
      final syncedPoints = await SyncRetryService().retryUnsyncedRuns();
      if (syncedPoints > 0) {
        pointsService.onRunSynced(syncedPoints);
        debugPrint('AppInitializer: Retried syncs - $syncedPoints points synced');
      }
    } catch (e) {
      debugPrint('AppInitializer: Retry failed syncs error - $e');
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

    AppLifecycleManager().initialize(
      isRunning: () => runProvider.isRunning,
      onRefresh: _onAppResume,
    );
  }

  Future<void> _onAppResume() async {
    final leaderboardProvider = context.read<LeaderboardProvider>();
    final appState = context.read<AppStateProvider>();
    final pointsService = context.read<PointsService>();

    // Refresh prefetched data (hex colors, leaderboard)
    await PrefetchService().refresh();
    await leaderboardProvider.refreshLeaderboard();

    final userId = appState.currentUser?.id;
    if (userId == null) return;

    // Retry failed syncs
    final syncedPoints = await SyncRetryService().retryUnsyncedRuns();
    if (syncedPoints > 0) {
      pointsService.onRunSynced(syncedPoints);
    }

    // Refresh buff multiplier (may have changed at midnight)
    // Use PrefetchService as single source of truth for home hex
    final cityHex = PrefetchService().homeHexCity;
    await BuffService().refresh(userId, districtHex: cityHex);

    // Refresh season points from server + today's points from local
    try {
      final supabase = SupabaseService();
      final result = await supabase.appLaunchSync(
        userId,
        districtHex: cityHex,
      );
      final userStats = result['user_stats'] as Map<String, dynamic>?;
      final serverSeasonPoints =
          (userStats?['season_points'] as num?)?.toInt() ?? 0;
      // Use max to prevent stale server data from overwriting locally-known
      // higher values (e.g., after a just-completed run where finalize_run
      // already incremented points but replication lag returns old value).
      final safeSeasonPoints = math.max(
        serverSeasonPoints,
        pointsService.totalSeasonPoints,
      );
      pointsService.setSeasonPoints(safeSeasonPoints);

      if (userStats != null && appState.currentUser != null) {
        appState.setUser(
          UserModel.mergeWithServerStats(
            appState.currentUser!,
            userStats,
            safeSeasonPoints,
          ),
        );
      }

      await pointsService.refreshFromLocalTotal();
    } catch (e) {
      debugPrint('OnResume: Failed to refresh points - $e');
      await pointsService.refreshFromLocalTotal();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        if (!appState.isInitialized) {
          return _buildLoadingScreen('Initializing...');
        }

        if (appState.hasUser && _isPrefetching) {
          return _buildLoadingScreen('Getting your location...');
        }

        if (appState.hasUser && _prefetchError != null) {
          return _buildErrorScreen(_prefetchError!);
        }

        if (!appState.isAuthenticated) {
          return const LoginScreen();
        }

        if (!appState.hasProfile) {
          return const ProfileRegisterScreen();
        }

        if (!appState.hasTeamSelected) {
          return const SeasonRegisterScreen();
        }

        return const HomeScreen();
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
