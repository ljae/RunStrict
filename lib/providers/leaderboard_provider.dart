import 'package:flutter/foundation.dart';
import '../models/team.dart';
import '../services/supabase_service.dart';

class LeaderboardEntry {
  final String id;
  final String name;
  final Team team;
  final String avatar;
  final int seasonPoints;
  final int rank;
  final String? crewId;

  const LeaderboardEntry({
    required this.id,
    required this.name,
    required this.team,
    required this.avatar,
    required this.seasonPoints,
    required this.rank,
    this.crewId,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json, int rank) {
    return LeaderboardEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      team: Team.values.byName(json['team'] as String),
      avatar: json['avatar'] as String? ?? '🏃',
      seasonPoints: (json['season_points'] as num?)?.toInt() ?? 0,
      rank: rank,
      crewId: json['crew_id'] as String?,
    );
  }
}

class LeaderboardProvider with ChangeNotifier {
  final SupabaseService _supabaseService;

  List<LeaderboardEntry> _entries = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetch;

  LeaderboardProvider({SupabaseService? supabaseService})
    : _supabaseService = supabaseService ?? SupabaseService();

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

  int? getUserRank(String userId) {
    final index = _entries.indexWhere((e) => e.id == userId);
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
