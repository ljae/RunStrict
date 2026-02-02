import 'package:flutter/foundation.dart';

import '../config/h3_config.dart';
import '../models/team.dart';
import '../providers/leaderboard_provider.dart';

/// Repository consolidating leaderboard caches from PrefetchService and LeaderboardProvider.
///
/// Provides a single source of truth for leaderboard data with:
/// - Throttled refresh control (30s minimum between fetches)
/// - Team-based filtering
/// - Geographic scope filtering (ZONE, CITY, ALL)
/// - User rank lookup within scopes
/// - Unmodifiable list returns to prevent accidental mutations
class LeaderboardRepository extends ChangeNotifier {
  // Singleton
  static final LeaderboardRepository _instance =
      LeaderboardRepository._internal();

  factory LeaderboardRepository() => _instance;

  LeaderboardRepository._internal();

  List<LeaderboardEntry> _entries = [];
  DateTime? _lastFetchTime;

  static const _throttleDuration = Duration(seconds: 30);

  /// Get all leaderboard entries
  List<LeaderboardEntry> get entries => List.unmodifiable(_entries);

  /// Check if repository has loaded data
  bool get hasData => _entries.isNotEmpty;

  /// Check if enough time has passed to allow a refresh
  bool get canRefresh =>
      _lastFetchTime == null ||
      DateTime.now().difference(_lastFetchTime!) > _throttleDuration;

  /// Get the throttle duration (for testing)
  Duration get throttleDuration => _throttleDuration;

  /// Load entries into the repository
  ///
  /// Replaces existing entries with the provided list.
  void loadEntries(List<LeaderboardEntry> entries) {
    _entries = List.from(entries);
    notifyListeners();
  }

  /// Filter entries by team
  ///
  /// Returns entries matching the specified team.
  /// If [team] is null, returns all entries.
  List<LeaderboardEntry> filterByTeam(Team? team) {
    if (team == null) return entries;
    return List.unmodifiable(_entries.where((e) => e.team == team).toList());
  }

  /// Filter entries by geographic scope
  ///
  /// Returns entries whose home hex shares the same parent cell as the
  /// reference home hex at the specified scope level.
  ///
  /// For [GeographicScope.all], returns all entries (no geographic filter).
  /// If [homeHex] is null and scope is not ALL, returns empty list.
  List<LeaderboardEntry> filterByScope(GeographicScope scope, String? homeHex) {
    // All scope means no geographic filtering
    if (scope == GeographicScope.all) return entries;

    // Need a reference hex for other scopes
    if (homeHex == null) {
      return List.unmodifiable([]);
    }

    return List.unmodifiable(
      _entries.where((e) => e.isInScope(homeHex, scope)).toList(),
    );
  }

  /// Get user rank within a specific scope
  ///
  /// Returns the user's rank among entries filtered by the given scope.
  /// Returns null if user not found in scope.
  int? getUserRankInScope(
    String userId,
    GeographicScope scope,
    String? homeHex,
  ) {
    final scopedEntries = filterByScope(scope, homeHex);
    final index = scopedEntries.indexWhere((e) => e.id == userId);
    return index >= 0 ? index + 1 : null;
  }

  /// Mark that a fetch has occurred
  ///
  /// Updates the last fetch time to enable throttling.
  void markFetched() {
    _lastFetchTime = DateTime.now();
  }

  /// Clear all data
  ///
  /// Resets entries and fetch time, allowing immediate refresh.
  void clear() {
    _entries = [];
    _lastFetchTime = null;
    notifyListeners();
  }
}
