import 'package:flutter/foundation.dart';
import '../config/h3_config.dart';
import '../models/team.dart';
import '../models/user_model.dart';
import '../repositories/leaderboard_repository.dart';
import '../services/hex_service.dart';
import '../services/prefetch_service.dart';
import '../services/supabase_service.dart';

/// Leaderboard entry wrapping a [UserModel] with a rank position.
///
/// Delegates all user fields to the underlying [UserModel], eliminating
/// 9 duplicated fields. Only adds `rank` (leaderboard-specific).
class LeaderboardEntry {
  final UserModel user;
  final int rank;

  const LeaderboardEntry({required this.user, required this.rank});

  /// Convenience constructor for creating entries directly (tests, fallbacks).
  /// Internally wraps fields in a [UserModel].
  factory LeaderboardEntry.create({
    required String id,
    required String name,
    required Team team,
    String avatar = '🏃',
    int seasonPoints = 0,
    required int rank,
    double totalDistanceKm = 0,
    double? avgPaceMinPerKm,
    double? avgCv,
    String? homeHex,
    String? manifesto,
  }) {
    return LeaderboardEntry(
      user: UserModel(
        id: id,
        name: name,
        team: team,
        avatar: avatar,
        seasonPoints: seasonPoints,
        sex: 'other',
        birthday: DateTime(2000, 1, 1),
        totalDistanceKm: totalDistanceKm,
        avgPaceMinPerKm: avgPaceMinPerKm,
        avgCv: avgCv,
        homeHex: homeHex,
        manifesto: manifesto,
      ),
      rank: rank,
    );
  }

  // Delegate getters to UserModel
  String get id => user.id;
  String get name => user.name;
  Team get team => user.team;
  String get avatar => user.avatar;
  int get seasonPoints => user.seasonPoints;
  double get totalDistanceKm => user.totalDistanceKm;
  double? get avgPaceMinPerKm => user.avgPaceMinPerKm;
  double? get avgCv => user.avgCv;
  String? get homeHex => user.homeHex;
  int? get stabilityScore => user.stabilityScore;
  String? get manifesto => user.manifesto;
  String? get nationality => user.nationality;

  /// Country code to flag emoji (e.g., 'KR' → '🇰🇷')
  String? get nationalityFlag {
    final code = nationality;
    if (code == null || code.length != 2) return null;
    final upper = code.toUpperCase();
    final flag = String.fromCharCodes(
      upper.codeUnits.map((c) => 0x1F1E6 - 0x41 + c),
    );
    return flag;
  }

  /// Format pace as "X'XX" (e.g., "5'30")
  String get formattedPace {
    if (avgPaceMinPerKm == null ||
        avgPaceMinPerKm!.isInfinite ||
        avgPaceMinPerKm!.isNaN ||
        avgPaceMinPerKm == 0) {
      return "-'--";
    }
    final min = avgPaceMinPerKm!.floor();
    final sec = ((avgPaceMinPerKm! - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}";
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json, int rank) {
    return LeaderboardEntry(user: UserModel.fromRow(json), rank: rank);
  }

  /// Serialize to cache map format (for SQLite leaderboard_cache table)
  Map<String, dynamic> toCacheMap() => {
    'user_id': id,
    'name': name,
    'avatar': avatar,
    'team': team.name,
    'flip_points': seasonPoints,
    'total_distance_km': totalDistanceKm,
    'avg_pace_min_per_km': avgPaceMinPerKm,
    'stability_score': stabilityScore,
    'home_hex': homeHex,
    'manifesto': manifesto,
    'nationality': nationality,
  };

  /// Deserialize from cache map format (SQLite leaderboard_cache table)
  factory LeaderboardEntry.fromCacheMap(Map<String, dynamic> map) {
    final stabilityScore = (map['stability_score'] as num?)?.toInt();
    return LeaderboardEntry(
      user: UserModel(
        id: map['user_id'] as String,
        name: map['name'] as String,
        team: Team.values.byName(map['team'] as String),
        avatar: map['avatar'] as String? ?? '🏃',
        sex: 'other',
        birthday: DateTime(2000, 1, 1),
        seasonPoints: (map['flip_points'] as num?)?.toInt() ?? 0,
        totalDistanceKm: (map['total_distance_km'] as num?)?.toDouble() ?? 0,
        avgPaceMinPerKm: (map['avg_pace_min_per_km'] as num?)?.toDouble(),
        avgCv: stabilityScore != null
            ? (100 - stabilityScore).toDouble()
            : null,
        homeHex: map['home_hex'] as String?,
        manifesto: map['manifesto'] as String?,
        nationality: map['nationality'] as String?,
      ),
      rank: 0,
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

/// LeaderboardProvider - Thin wrapper around LeaderboardRepository for Provider pattern.
///
/// Delegates leaderboard state to LeaderboardRepository (single source of truth).
/// Manages UI concerns: loading state, error handling, Supabase fetching.
class LeaderboardProvider with ChangeNotifier {
  final SupabaseService _supabaseService;
  final PrefetchService _prefetchService;
  final LeaderboardRepository _leaderboardRepository = LeaderboardRepository();

  bool _isLoading = false;
  String? _error;
  int? _viewingSeason;
  bool get isViewingHistorical => _viewingSeason != null;
  int? get viewingSeason => _viewingSeason;

  LeaderboardProvider({
    SupabaseService? supabaseService,
    PrefetchService? prefetchService,
  }) : _supabaseService = supabaseService ?? SupabaseService(),
       _prefetchService = prefetchService ?? PrefetchService() {
    // Listen to LeaderboardRepository changes and forward notifications
    _leaderboardRepository.addListener(_onRepositoryChanged);
  }

  void _onRepositoryChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _leaderboardRepository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  /// Entries from LeaderboardRepository (single source of truth)
  List<LeaderboardEntry> get entries => _leaderboardRepository.entries;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _leaderboardRepository.hasData;

  Future<void> fetchLeaderboard({
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    if (_isLoading) return;

    // Use repository's throttle check
    if (!forceRefresh && !_leaderboardRepository.canRefresh) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _supabaseService.getLeaderboard(limit: limit);

      final newEntries = result.asMap().entries.map((entry) {
        return LeaderboardEntry.fromJson(entry.value, entry.key + 1);
      }).toList();

      // Store in repository (single source of truth)
      _leaderboardRepository.loadEntries(newEntries);
      _leaderboardRepository.markFetched();
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
    if (team == null) return entries;
    return entries.where((e) => e.team == team).toList();
  }

  /// Filter entries by geographic scope using home hex anchoring.
  ///
  /// Returns entries whose home hex shares the same parent cell as the
  /// current user's home hex at the specified scope level.
  ///
  /// For [GeographicScope.all], returns all entries (no geographic filter).
  List<LeaderboardEntry> filterByScope(GeographicScope scope) {
    // All scope means no geographic filtering
    if (scope == GeographicScope.all) return entries;

    // Server data always uses home hex (Snapshot Domain)
    final referenceHex = _prefetchService.homeHex;
    if (referenceHex == null) {
      debugPrint(
        'LeaderboardProvider: No active hex set, returning all entries',
      );
      return entries;
    }

    return entries.where((e) => e.isInScope(referenceHex, scope)).toList();
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
    final index = entries.indexWhere((e) => e.id == userId);
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
      return entries.firstWhere((e) => e.id == userId);
    } catch (_) {
      return null;
    }
  }

  void clear() {
    _leaderboardRepository.clear();
    _error = null;
    // notifyListeners() called via _onRepositoryChanged
  }

  Future<void> refreshLeaderboard() async {
    await fetchLeaderboard(forceRefresh: true);
  }

  Future<void> fetchSeasonLeaderboard(int seasonNumber) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _viewingSeason = seasonNumber;
    notifyListeners();

    try {
      final result = await _supabaseService.getSeasonLeaderboard(seasonNumber);

      final newEntries = result.map((json) {
        final rank = (json['rank'] as num?)?.toInt() ?? 0;
        return LeaderboardEntry.fromJson(json, rank);
      }).toList();

      _leaderboardRepository.loadEntries(newEntries);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('LeaderboardProvider.fetchSeasonLeaderboard error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearHistorical() {
    _viewingSeason = null;
    notifyListeners();
  }

  /// Fetch scoped season leaderboard from snapshot.
  ///
  /// Uses client-side province filtering via [filterByScope] after fetching
  /// the full snapshot. The snapshot is small (≤200 entries) so this is efficient.
  Future<void> fetchScopedSeasonLeaderboard(
    int seasonNumber, {
    String? parentHex,
    int limit = 50,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _viewingSeason = seasonNumber;
    notifyListeners();

    try {
      // Use existing get_season_leaderboard RPC (fetches full snapshot).
      // Province filtering is done client-side via filterByScope().
      final result = await _supabaseService.getSeasonLeaderboard(
        seasonNumber,
        limit: limit,
      );

      final newEntries = result.map((json) {
        final rank = (json['rank'] as num?)?.toInt() ?? 0;
        return LeaderboardEntry.fromJson(json, rank);
      }).toList();

      _leaderboardRepository.loadEntries(newEntries);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('LeaderboardProvider.fetchScopedSeasonLeaderboard error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
