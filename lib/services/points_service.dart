import 'package:flutter/foundation.dart';
import '../repositories/user_repository.dart';
import '../storage/local_storage.dart';

/// Manages flip points with hybrid calculation for today's points.
///
/// Season points delegate to UserRepository (single source of truth).
/// Today's flip points = server baseline + local unsynced runs
///
/// This architecture handles:
/// - "The Final Sync" (no real-time sync during runs)
/// - Multi-device scenarios (server has other device's synced runs)
/// - Local runs that haven't synced yet
class PointsService extends ChangeNotifier {
  final UserRepository _userRepository = UserRepository();
  int _serverTodayBaseline; // From app_launch_sync (synced runs only)
  int _localUnsyncedToday; // From local DB (pending sync runs)

  final LocalStorage _localStorage;

  PointsService({
    int initialPoints = 0,
    int todayPoints = 0,
    LocalStorage? localStorage,
  }) : _serverTodayBaseline = todayPoints,
       _localUnsyncedToday = 0,
       _localStorage = localStorage ?? LocalStorage() {
    // Initialize UserRepository if initial points provided
    if (initialPoints > 0) {
      _userRepository.updateSeasonPoints(initialPoints);
    }
    // Listen to UserRepository changes and forward notifications
    _userRepository.addListener(_onUserRepositoryChanged);
  }

  void _onUserRepositoryChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _userRepository.removeListener(_onUserRepositoryChanged);
    super.dispose();
  }

  /// Season points from UserRepository (single source of truth)
  int get seasonPoints => _userRepository.seasonPoints;

  /// Today's flip points using hybrid calculation.
  /// = server baseline (synced runs) + local unsynced runs
  int get todayFlipPoints => _serverTodayBaseline + _localUnsyncedToday;

  @Deprecated('Use todayFlipPoints for header display, seasonPoints for totals')
  int get currentPoints => todayFlipPoints;

  /// Add points from a run (updates both season and local unsynced today).
  /// Called during active runs when hexes are flipped.
  void addRunPoints(int points) {
    _userRepository.updateSeasonPoints(seasonPoints + points);
    _localUnsyncedToday += points;
    // notifyListeners() called via _onUserRepositoryChanged
  }

  void setSeasonPoints(int points) {
    _userRepository.updateSeasonPoints(points);
    // notifyListeners() called via _onUserRepositoryChanged
  }

  /// Set the server baseline for today's flip points.
  /// Called on app launch after receiving data from app_launch_sync.
  ///
  /// The server baseline includes all synced runs from today (including
  /// runs from other devices). Local unsynced runs are added on top.
  void setServerTodayBaseline(int points) {
    _serverTodayBaseline = points;
    notifyListeners();
  }

  /// Refresh local unsynced points from database.
  /// Call this on app launch and after sync operations.
  Future<void> refreshLocalUnsyncedPoints() async {
    try {
      _localUnsyncedToday = await _localStorage.sumUnsyncedTodayPoints();
      notifyListeners();
    } catch (e) {
      debugPrint('PointsService: Failed to refresh local unsynced points - $e');
    }
  }

  /// Called after a successful Final Sync.
  /// The synced run's points move from local unsynced to server baseline.
  void onRunSynced(int syncedPoints) {
    // Points are now server-side, so they'll be in server baseline on next launch
    // For immediate UI accuracy, we can transfer them:
    // However, since we can't update server baseline without a server call,
    // we keep the points in local unsynced until next app launch.
    // The total remains correct either way.
    notifyListeners();
  }

  /// Mark local runs as synced and refresh the calculation.
  /// Called after server confirms today's points baseline.
  Future<void> markLocalRunsSynced() async {
    await _localStorage.markTodayRunsSynced();
    _localUnsyncedToday = 0;
    notifyListeners();
  }

  @Deprecated('Use setSeasonPoints instead')
  void setPoints(int points) {
    _userRepository.updateSeasonPoints(points);
    // notifyListeners() called via _onUserRepositoryChanged
  }

  @Deprecated('Use setServerTodayBaseline + refreshLocalUnsyncedPoints instead')
  void setTodayFlipPoints(int points) {
    _serverTodayBaseline = points;
    _localUnsyncedToday = 0;
    notifyListeners();
  }

  void resetForNewSeason() {
    _userRepository.updateSeasonPoints(0);
    _serverTodayBaseline = 0;
    _localUnsyncedToday = 0;
    // notifyListeners() called via _onUserRepositoryChanged
  }

  void resetTodayPoints() {
    _serverTodayBaseline = 0;
    _localUnsyncedToday = 0;
    notifyListeners();
  }

  static String formatPoints(int points) {
    if (points < 1000) return points.toString();
    final str = points.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  List<int> getDigits(int value, {int minDigits = 1}) {
    if (value == 0) return List.filled(minDigits, 0);

    final digits = <int>[];
    var remaining = value;
    while (remaining > 0) {
      digits.insert(0, remaining % 10);
      remaining ~/= 10;
    }

    while (digits.length < minDigits) {
      digits.insert(0, 0);
    }

    return digits;
  }
}
