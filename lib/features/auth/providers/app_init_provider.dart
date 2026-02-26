import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/prefetch_service.dart';
import '../../../core/services/sync_retry_service.dart';
import '../../../core/services/app_lifecycle_manager.dart';
import '../../../core/storage/local_storage.dart';
import 'app_state_provider.dart';
import '../../team/providers/buff_provider.dart';
import '../../leaderboard/providers/leaderboard_provider.dart';
import '../../../core/providers/points_provider.dart';
import '../../run/providers/run_provider.dart';
import '../../map/providers/hex_data_provider.dart';
import '../../../core/providers/user_repository_provider.dart';
import '../../../core/providers/pro_provider.dart';

class AppInitState {
  final bool isPrefetching;
  final String? prefetchError;

  const AppInitState({
    this.isPrefetching = true,
    this.prefetchError,
  });

  AppInitState copyWith({
    bool? isPrefetching,
    String? Function()? prefetchError,
  }) {
    return AppInitState(
      isPrefetching: isPrefetching ?? this.isPrefetching,
      prefetchError: prefetchError != null ? prefetchError() : this.prefetchError,
    );
  }
}

class AppInitNotifier extends Notifier<AppInitState> {
  @override
  AppInitState build() => const AppInitState();

  Future<void> initialize() async {
    final appState = ref.read(appStateProvider.notifier);
    final appStateValue = ref.read(appStateProvider);

    // Guest path: initialize location and download hex snapshot
    if (appStateValue.isGuest) {
      // Set isPrefetching=true so router blocks /home until location is ready
      state = state.copyWith(isPrefetching: true, prefetchError: () => null);
      await ref.read(runProvider.notifier).doInitialize();
      try {
        await PrefetchService().initializeGuestLocation();
        // Notify map that hex data changed (snapshot downloaded)
        ref.read(hexDataProvider.notifier).notifyHexDataChanged();
      } catch (e) {
        debugPrint('AppInitNotifier: Guest location init failed - $e');
      }
      state = state.copyWith(isPrefetching: false);
      _initializeGuestMidnightWipe();
      _initializeLifecycleManager();
      return;
    }

    await appState.initialize();

    // Initialize RunProvider
    await ref.read(runProvider.notifier).doInitialize();

    if (appState.hasUser) {
      // Prefetch MUST complete first: it sets home_hex on server (for first-
      // time / wiped users) and locally.  _loadTodayFlipPoints calls
      // appLaunchSync which reads home_hex from the server and merges it into
      // the UserModel — running them in parallel causes a race where
      // appLaunchSync reads NULL before _syncHomeToServer writes it.
      await _initializePrefetch();
      await Future.wait([
        _loadTodayFlipPoints(),
        _retryFailedSyncs(),
        _syncPurpleDefectionIfNeeded(),
      ]);
    } else {
      state = state.copyWith(isPrefetching: false);
    }

    _initializeLifecycleManager();
  }

  /// Schedule guest data wipe at local midnight.
  void _initializeGuestMidnightWipe() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final untilMidnight = midnight.difference(now);

    debugPrint(
      'AppInitNotifier: Guest midnight wipe scheduled in '
      '${untilMidnight.inMinutes} minutes',
    );

    Future.delayed(untilMidnight, () {
      final currentState = ref.read(appStateProvider);
      if (!currentState.isGuest) return;

      debugPrint('AppInitNotifier: Guest midnight wipe triggered');
      LocalStorage().clearAllGuestData().then((_) {
        ref.read(appStateProvider.notifier).endGuestSession();
      });
    });
  }

  Future<void> _loadTodayFlipPoints() async {
    final appState = ref.read(appStateProvider.notifier);
    final points = ref.read(pointsProvider.notifier);

    if (!appState.hasUser) return;

    try {
      final supabase = SupabaseService();
      final launchCityHex = PrefetchService().homeHexCity;
      final result = await supabase.appLaunchSync(
        appState.currentUser!.id,
        districtHex: launchCityHex,
      );

      final userStats = result['user_stats'] as Map<String, dynamic>?;
      final seasonPoints = (userStats?['season_points'] as num?)?.toInt() ?? 0;
      points.setSeasonPoints(seasonPoints);

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
      ref.read(buffProvider.notifier).setBuffFromLaunchSync(userBuff);

      await points.refreshFromLocalTotal();

      debugPrint(
        'AppInitNotifier: Launch sync - '
        'buff: ${ref.read(buffProvider).effectiveMultiplier}x, '
        'todayTotal: ${points.todayFlipPoints}, '
        'season: $seasonPoints',
      );
    } catch (e) {
      debugPrint('AppInitNotifier: Failed to load today flip points - $e');
      final localSeasonPoints = await LocalStorage().sumAllFlipPoints();
      if (localSeasonPoints > 0) {
        points.setSeasonPoints(localSeasonPoints);
      }
      await points.refreshLocalUnsyncedPoints();
    }
  }

  Future<void> _retryFailedSyncs() async {
    final points = ref.read(pointsProvider.notifier);
    try {
      final syncedPoints = await SyncRetryService().retryUnsyncedRuns();
      if (syncedPoints > 0) {
        points.onRunSynced(syncedPoints);
        debugPrint('AppInitNotifier: Retried syncs - $syncedPoints points synced');
      }
    } catch (e) {
      debugPrint('AppInitNotifier: Retry failed syncs error - $e');
    }
  }

  /// Retry purple defection server sync if local says purple.
  /// Harmless if server is already purple (idempotent update).
  Future<void> _syncPurpleDefectionIfNeeded() async {
    final user = ref.read(userRepositoryProvider);
    if (user == null || user.team.name != 'purple') return;

    try {
      await SupabaseService().updateUserTeam(user.id, 'purple');
      debugPrint('AppInitNotifier: Purple defection server sync confirmed');
    } catch (e) {
      debugPrint('AppInitNotifier: Purple defection sync retry failed: $e');
    }
  }

  Future<void> initializePrefetch() async {
    state = state.copyWith(isPrefetching: true, prefetchError: () => null);

    try {
      await PrefetchService().initialize();
      // Notify map that hex data changed (colors downloaded from snapshot)
      ref.read(hexDataProvider.notifier).notifyHexDataChanged();
      debugPrint('AppInitNotifier: PrefetchService initialized successfully');
    } catch (e) {
      debugPrint('AppInitNotifier: PrefetchService failed - $e');
      state = state.copyWith(prefetchError: () => e.toString());
    } finally {
      state = state.copyWith(isPrefetching: false);
    }
  }

  Future<void> _initializePrefetch() => initializePrefetch();

  void _initializeLifecycleManager() {
    final runNotifier = ref.read(runProvider.notifier);

    AppLifecycleManager().initialize(
      isRunning: () => runNotifier.isRunning,
      onRefresh: _onAppResume,
    );
  }

  Future<void> _onAppResume() async {
    // Guest mode: skip all server refresh
    if (ref.read(appStateProvider).isGuest) return;

    // Refresh pro status (purchase may have completed externally)
    ref.read(proProvider.notifier).refresh();

    final leaderboard = ref.read(leaderboardProvider.notifier);
    final appState = ref.read(appStateProvider.notifier);
    final points = ref.read(pointsProvider.notifier);

    await PrefetchService().refresh();
    // Notify map that hex data changed from server refresh
    ref.read(hexDataProvider.notifier).notifyHexDataChanged();
    await leaderboard.refreshLeaderboard();

    final userId = appState.currentUser?.id;
    if (userId == null) return;

    final syncedPoints = await SyncRetryService().retryUnsyncedRuns();
    if (syncedPoints > 0) {
      points.onRunSynced(syncedPoints);
    }

    final cityHex = PrefetchService().homeHexCity;
    try {
      final supabase = SupabaseService();
      final result = await supabase.appLaunchSync(
        userId,
        districtHex: cityHex,
      );
      final userStats = result['user_stats'] as Map<String, dynamic>?;
      final serverSeasonPoints =
          (userStats?['season_points'] as num?)?.toInt() ?? 0;
      final safeSeasonPoints = math.max(
        serverSeasonPoints,
        points.totalSeasonPoints,
      );
      points.setSeasonPoints(safeSeasonPoints);

      if (userStats != null && appState.currentUser != null) {
        appState.setUser(
          UserModel.mergeWithServerStats(
            appState.currentUser!,
            userStats,
            safeSeasonPoints,
          ),
        );
      }

      // Use buff data from appLaunchSync instead of separate getUserBuff RPC
      final userBuff = result['user_buff'] as Map<String, dynamic>?;
      ref.read(buffProvider.notifier).setBuffFromLaunchSync(userBuff);

      await points.refreshFromLocalTotal();
    } catch (e) {
      debugPrint('OnResume: Failed to refresh points - $e');
      await points.refreshFromLocalTotal();
    }
  }

  void clearPrefetchError() {
    state = state.copyWith(prefetchError: () => null);
  }
}

final appInitProvider = NotifierProvider<AppInitNotifier, AppInitState>(
  AppInitNotifier.new,
);
