import 'dart:async';
import 'package:flutter/widgets.dart';
import 'remote_config_service.dart';

/// Manages app lifecycle events and triggers data refresh on resume.
///
/// On resume (AppLifecycleState.resumed):
/// - Refreshes hex map data
/// - Refreshes leaderboard rankings
///
/// Constraints:
/// - 30-second throttle to prevent excessive refreshes
/// - Skips refresh during active run (data is synced differently)
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
    _isInitialized = true;

    debugPrint('AppLifecycleManager: Initialized');
  }

  /// Dispose the lifecycle manager
  void dispose() {
    if (!_isInitialized) return;

    WidgetsBinding.instance.removeObserver(this);
    _resumeController.close();
    _isInitialized = false;
    _isRunningChecker = null;
    _onRefreshCallback = null;

    debugPrint('AppLifecycleManager: Disposed');
  }

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

    // Perform refresh
    _lastRefreshTime = now;
    debugPrint('AppLifecycleManager: Triggering data refresh');

    // Notify stream listeners
    _resumeController.add(null);

    // Call the refresh callback
    try {
      await _onRefreshCallback?.call();
      debugPrint('AppLifecycleManager: Data refresh completed');
    } catch (e) {
      debugPrint('AppLifecycleManager: Data refresh failed: $e');
    }
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

    _lastRefreshTime = DateTime.now();
    debugPrint('AppLifecycleManager: Force refresh triggered');

    _resumeController.add(null);

    try {
      await _onRefreshCallback?.call();
      debugPrint('AppLifecycleManager: Force refresh completed');
    } catch (e) {
      debugPrint('AppLifecycleManager: Force refresh failed: $e');
    }
  }
}
