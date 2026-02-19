import 'dart:async';
import 'package:flutter/widgets.dart';
import 'remote_config_service.dart';
import 'season_service.dart';

/// Manages app lifecycle events, midnight snapshot refresh, and data sync.
///
/// ## Refresh Triggers
///
/// 1. **OnResume** (AppLifecycleState.resumed):
///    - Refreshes hex map data + leaderboard
///    - Skipped during active runs, throttled to 30s minimum
///
/// 2. **Midnight GMT+2** (daily snapshot boundary):
///    - Schedules a timer for the next server midnight
///    - If NOT running: downloads new snapshot immediately
///    - If running: sets [_midnightCrossedDuringRun] flag
///
/// 3. **Post-run** (after run completes, if midnight crossed):
///    - If [_midnightCrossedDuringRun] is true, triggers snapshot refresh
///    - Ensures the user sees new-day data without manually restarting the app
class AppLifecycleManager with WidgetsBindingObserver {
  static final AppLifecycleManager _instance = AppLifecycleManager._internal();
  factory AppLifecycleManager() => _instance;
  AppLifecycleManager._internal();

  /// Minimum interval between refreshes (from RemoteConfigService)
  static Duration get _throttleInterval => Duration(
    seconds: RemoteConfigService().config.timingConfig.refreshThrottleSeconds,
  );

  DateTime? _lastRefreshTime;
  bool _isInitialized = false;

  /// Callback to check if a run is currently active
  bool Function()? _isRunningChecker;

  /// Callback to perform the actual data refresh
  Future<void> Function()? _onRefreshCallback;

  /// Stream controller for resume events (for widgets to listen)
  final _resumeController = StreamController<void>.broadcast();

  /// Stream of resume events
  Stream<void> get onResume => _resumeController.stream;

  /// Timer that fires at the next server midnight (GMT+2)
  Timer? _midnightTimer;

  /// True if midnight GMT+2 crossed while the user was on an active run.
  /// Cleared after the post-run refresh completes.
  bool _midnightCrossedDuringRun = false;

  /// Whether a midnight-triggered refresh is pending (for post-run use)
  bool get hasPendingMidnightRefresh => _midnightCrossedDuringRun;

  /// Initialize the lifecycle manager with callbacks.
  ///
  /// [isRunning] - Function that returns true if a run is currently active
  /// [onRefresh] - Async function to call when data should be refreshed
  void initialize({
    required bool Function() isRunning,
    required Future<void> Function() onRefresh,
  }) {
    if (_isInitialized) return;

    _isRunningChecker = isRunning;
    _onRefreshCallback = onRefresh;

    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightTimer();
    _isInitialized = true;

    debugPrint('AppLifecycleManager: Initialized');
  }

  /// Dispose the lifecycle manager
  void dispose() {
    if (!_isInitialized) return;

    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _midnightTimer = null;
    _resumeController.close();
    _isInitialized = false;
    _isRunningChecker = null;
    _onRefreshCallback = null;

    debugPrint('AppLifecycleManager: Disposed');
  }

  // ---------------------------------------------------------------------------
  // MIDNIGHT TIMER
  // ---------------------------------------------------------------------------

  /// Schedule a timer to fire at the next server midnight (GMT+2).
  ///
  /// Uses [SeasonService.serverTime] to compute time until midnight,
  /// adds a small delay (5s) to ensure the server snapshot cron has completed.
  void _scheduleMidnightTimer() {
    _midnightTimer?.cancel();

    final season = SeasonService();
    final serverNow = season.serverTime; // Current time in GMT+2
    // Next midnight GMT+2
    final nextMidnight = DateTime(
      serverNow.year,
      serverNow.month,
      serverNow.day + 1,
    );
    // Duration until midnight + 5 second buffer for cron completion
    var delay = nextMidnight.difference(serverNow) + const Duration(seconds: 5);

    // Safety: if delay is negative or zero (clock drift), fire in 60s
    if (delay.isNegative || delay == Duration.zero) {
      delay = const Duration(seconds: 60);
    }

    _midnightTimer = Timer(delay, _onMidnightReached);

    final hours = delay.inHours;
    final minutes = delay.inMinutes % 60;
    debugPrint(
      'AppLifecycleManager: Midnight timer scheduled in '
      '${hours}h ${minutes}m',
    );
  }

  /// Called when the midnight timer fires.
  void _onMidnightReached() {
    debugPrint('AppLifecycleManager: Midnight GMT+2 reached');

    if (_isRunningChecker?.call() == true) {
      // User is running — defer refresh until run completes
      _midnightCrossedDuringRun = true;
      debugPrint(
        'AppLifecycleManager: Run in progress — deferring snapshot refresh',
      );
    } else {
      // Not running — refresh immediately
      debugPrint(
        'AppLifecycleManager: Triggering midnight snapshot refresh',
      );
      _performRefresh(reason: 'midnight');
    }

    // Schedule the next midnight timer (for tomorrow)
    _scheduleMidnightTimer();
  }

  // ---------------------------------------------------------------------------
  // POST-RUN REFRESH (called by RunProvider after stopRun)
  // ---------------------------------------------------------------------------

  /// Notify that a run has completed.
  ///
  /// If midnight crossed during the run, triggers a snapshot refresh
  /// so the user sees new-day data without restarting the app.
  Future<void> onRunCompleted() async {
    if (!_midnightCrossedDuringRun) return;

    _midnightCrossedDuringRun = false;
    debugPrint(
      'AppLifecycleManager: Midnight crossed during run — '
      'refreshing snapshot now',
    );
    await _performRefresh(reason: 'post-run midnight');
  }

  // ---------------------------------------------------------------------------
  // LIFECYCLE EVENTS
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  Future<void> _handleResume() async {
    debugPrint('AppLifecycleManager: App resumed');

    // Skip if currently running (data syncs via location stream)
    if (_isRunningChecker?.call() == true) {
      debugPrint('AppLifecycleManager: Skipping refresh - run in progress');
      return;
    }

    // Check throttle (30 second minimum between refreshes)
    final now = DateTime.now();
    if (_lastRefreshTime != null) {
      final elapsed = now.difference(_lastRefreshTime!);
      if (elapsed < _throttleInterval) {
        debugPrint(
          'AppLifecycleManager: Skipping refresh - '
          'throttled (${elapsed.inSeconds}s < ${_throttleInterval.inSeconds}s)',
        );
        return;
      }
    }

    await _performRefresh(reason: 'resume');
  }

  /// Force a manual refresh (bypasses throttle check).
  ///
  /// Use sparingly - mainly for pull-to-refresh actions.
  Future<void> forceRefresh() async {
    if (_isRunningChecker?.call() == true) {
      debugPrint(
        'AppLifecycleManager: Force refresh skipped - run in progress',
      );
      return;
    }

    await _performRefresh(reason: 'force');
  }

  // ---------------------------------------------------------------------------
  // SHARED REFRESH LOGIC
  // ---------------------------------------------------------------------------

  Future<void> _performRefresh({required String reason}) async {
    _lastRefreshTime = DateTime.now();
    debugPrint('AppLifecycleManager: Triggering data refresh ($reason)');

    // Notify stream listeners
    _resumeController.add(null);

    // Call the refresh callback
    try {
      await _onRefreshCallback?.call();
      debugPrint('AppLifecycleManager: Data refresh completed ($reason)');
    } catch (e) {
      debugPrint('AppLifecycleManager: Data refresh failed ($reason): $e');
    }
  }
}
