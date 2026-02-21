import 'dart:math' show max;

import 'package:flutter/foundation.dart';
import '../../data/repositories/user_repository.dart';
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
class PointsService {
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
  }

  /// Season points from UserRepository (server snapshot at last sync)
  int get seasonPoints => _userRepository.seasonPoints;

  /// Total season points for header display.
  /// = server season total + local unsynced today (points server doesn't know about yet)
  int get totalSeasonPoints => _userRepository.seasonPoints + _localUnsyncedToday;

  /// Today's flip points using hybrid calculation.
  /// = server baseline (synced runs) + local unsynced runs
  int get todayFlipPoints => _serverTodayBaseline + _localUnsyncedToday;

  @Deprecated('Use totalSeasonPoints for header display')
  int get currentPoints => todayFlipPoints;

  /// Add points from a run (updates local unsynced today).
  /// Called during active runs when hexes are flipped.
  ///
  /// Does NOT update seasonPoints directly. Instead, totalSeasonPoints
  /// (= seasonPoints + _localUnsyncedToday) reflects the true total.
  /// seasonPoints is updated when the run syncs (onRunSynced) or on next
  /// app launch sync.
  void addRunPoints(int points) {
    _localUnsyncedToday += points;

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

  }

  /// Refresh local unsynced points from database.
  /// Call this on app launch and after sync operations.
  Future<void> refreshLocalUnsyncedPoints() async {
    try {
      _localUnsyncedToday = await _localStorage.sumUnsyncedTodayPoints();
  
    } catch (e) {
      debugPrint('PointsService: Failed to refresh local unsynced points - $e');
    }
  }

  /// Refresh today's points from local SQLite (all runs, synced + unsynced).
  ///
  /// Preserves the split between synced baseline and unsynced local points
  /// so that totalSeasonPoints (seasonPoints + _localUnsyncedToday) remains
  /// accurate for header display.
  Future<void> refreshFromLocalTotal() async {
    try {
      final localTotal = await _localStorage.sumAllTodayPoints();
      final localUnsynced = await _localStorage.sumUnsyncedTodayPoints();
      _serverTodayBaseline = localTotal - localUnsynced;
      _localUnsyncedToday = localUnsynced;
  
    } catch (e) {
      debugPrint('PointsService: Failed to refresh from local total - $e');
    }
  }

  /// Called after a successful Final Sync.
  /// The synced run's points move from local unsynced to server baseline,
  /// and seasonPoints is updated since the server accepted these points.
  void onRunSynced(int syncedPoints) {
    _serverTodayBaseline += syncedPoints;
    // Decrement local unsynced BEFORE updating seasonPoints to avoid
    // transient spike (updateSeasonPoints triggers notifyListeners via
    // UserRepository, and totalSeasonPoints = seasonPoints + _localUnsyncedToday).
    _localUnsyncedToday = max(0, _localUnsyncedToday - syncedPoints);
    // Server accepted these points via finalize_run, update local season total.
    // Note: seasonPoints getter reads from UserRepository, so we capture the
    // current value before updating.
    final currentSeason = seasonPoints;
    _userRepository.updateSeasonPoints(currentSeason + syncedPoints);

  }

  /// Mark local runs as synced and refresh the calculation.
  /// Called after server confirms today's points baseline.
  Future<void> markLocalRunsSynced() async {
    await _localStorage.markTodayRunsSynced();
    _localUnsyncedToday = 0;

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
