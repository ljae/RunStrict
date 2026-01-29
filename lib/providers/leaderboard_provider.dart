import 'package:flutter/foundation.dart';
import '../config/h3_config.dart';
import '../models/team.dart';
import '../services/hex_service.dart';
import '../services/prefetch_service.dart';
import '../services/supabase_service.dart';

class LeaderboardEntry {
  final String id;
  final String name;
  final Team team;
  final String avatar;
  final int seasonPoints;
  final int rank;
  final String? crewId;

  /// Total distance run in season (km)
  final double totalDistanceKm;

  /// Average pace across all runs (min/km)
  final double? avgPaceMinPerKm;

  /// Average CV (Coefficient of Variation) - measures pace consistency
  final double? avgCv;

  /// User's home hex (Res 9) for scope filtering
  final String? homeHex;

  const LeaderboardEntry({
    required this.id,
    required this.name,
    required this.team,
    required this.avatar,
    required this.seasonPoints,
    required this.rank,
    this.crewId,
    this.totalDistanceKm = 0,
    this.avgPaceMinPerKm,
    this.avgCv,
    this.homeHex,
  });

  /// Stability score from average CV (higher = better)
  /// Returns clamped 0-100 value, null if no CV data
  int? get stabilityScore {
    if (avgCv == null) return null;
    return (100 - avgCv!).round().clamp(0, 100);
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json, int rank) {
    return LeaderboardEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      team: Team.values.byName(json['team'] as String),
      avatar: json['avatar'] as String? ?? '🏃',
      seasonPoints: (json['season_points'] as num?)?.toInt() ?? 0,
      rank: rank,
      crewId: json['crew_id'] as String?,
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0,
      avgPaceMinPerKm: (json['avg_pace_min_per_km'] as num?)?.toDouble(),
      avgCv: (json['avg_cv'] as num?)?.toDouble(),
      homeHex: json['home_hex'] as String?,
    );
  }

  /// Check if this entry is in the same scope as a reference home hex
  bool isInScope(String? referenceHomeHex, GeographicScope scope) {
    if (homeHex == null || referenceHomeHex == null) return false;
    final hexService = HexService();
    final myParent = hexService.getScopeHexId(homeHex!, scope);
    final refParent = hexService.getScopeHexId(referenceHomeHex, scope);
    return myParent == refParent;
  }
}

class LeaderboardProvider with ChangeNotifier {
  final SupabaseService _supabaseService;
  final PrefetchService _prefetchService;

  List<LeaderboardEntry> _entries = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetch;

  LeaderboardProvider({
    SupabaseService? supabaseService,
    PrefetchService? prefetchService,
  }) : _supabaseService = supabaseService ?? SupabaseService(),
       _prefetchService = prefetchService ?? PrefetchService();

  List<LeaderboardEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _entries.isNotEmpty;

  Future<void> fetchLeaderboard({
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    if (_isLoading) return;

    final now = DateTime.now();
    if (!forceRefresh &&
        _lastFetch != null &&
        now.difference(_lastFetch!).inSeconds < 30) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _supabaseService.getLeaderboard(limit: limit);

      _entries = result.asMap().entries.map((entry) {
        return LeaderboardEntry.fromJson(entry.value, entry.key + 1);
      }).toList();

      _lastFetch = now;
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('LeaderboardProvider.fetchLeaderboard error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<LeaderboardEntry> filterByTeam(Team? team) {
    if (team == null) return _entries;
    return _entries.where((e) => e.team == team).toList();
  }

  /// Filter entries by geographic scope using home hex anchoring.
  ///
  /// Returns entries whose home hex shares the same parent cell as the
  /// current user's home hex at the specified scope level.
  ///
  /// For [GeographicScope.all], returns all entries (no geographic filter).
  List<LeaderboardEntry> filterByScope(GeographicScope scope) {
    // All scope means no geographic filtering
    if (scope == GeographicScope.all) return _entries;

    final homeHex = _prefetchService.homeHex;
    if (homeHex == null) {
      debugPrint('LeaderboardProvider: No home hex set, returning all entries');
      return _entries;
    }

    return _entries.where((e) => e.isInScope(homeHex, scope)).toList();
  }

  /// Filter entries by both team and scope.
  ///
  /// Combines team filter and geographic scope filter.
  List<LeaderboardEntry> filterByTeamAndScope(
    Team? team,
    GeographicScope scope,
  ) {
    var filtered = filterByScope(scope);
    if (team != null) {
      filtered = filtered.where((e) => e.team == team).toList();
    }
    return filtered;
  }

  int? getUserRank(String userId) {
    final index = _entries.indexWhere((e) => e.id == userId);
    return index >= 0 ? index + 1 : null;
  }

  /// Get user rank within a specific scope.
  ///
  /// Returns the user's rank among entries filtered by the given scope.
  int? getUserRankInScope(String userId, GeographicScope scope) {
    final scopedEntries = filterByScope(scope);
    final index = scopedEntries.indexWhere((e) => e.id == userId);
    return index >= 0 ? index + 1 : null;
  }

  LeaderboardEntry? getUser(String userId) {
    try {
      return _entries.firstWhere((e) => e.id == userId);
    } catch (_) {
      return null;
    }
  }

  void clear() {
    _entries = [];
    _lastFetch = null;
    _error = null;
    notifyListeners();
  }

  /// Refresh leaderboard data (force fetch, bypasses cache).
  ///
  /// Called on app resume to ensure fresh data.
  Future<void> refreshLeaderboard() async {
    await fetchLeaderboard(forceRefresh: true);
  }
}
