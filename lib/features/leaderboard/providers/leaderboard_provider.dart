import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/h3_config.dart';
import '../../../data/models/team.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../core/services/hex_service.dart';
import '../../../core/services/prefetch_service.dart';
import '../../../core/services/supabase_service.dart';

/// Leaderboard entry wrapping a [UserModel] with a rank position.
///
/// Delegates all user fields to the underlying [UserModel], eliminating
/// 9 duplicated fields. Only adds `rank` (leaderboard-specific).
class LeaderboardEntry {
  final UserModel user;
  final int rank;

  /// Res 6 district hex from the server — used for province scope filtering.
  /// More reliable than computing cellToParent(home_hex) because seed home_hex
  /// values may not be valid H3 cells.
  final String? districtHex;

  const LeaderboardEntry({
    required this.user,
    required this.rank,
    this.districtHex,
  });

  /// Convenience constructor for creating entries directly (tests, fallbacks).
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
  String? get homeHexEnd => user.homeHexEnd;

  /// Get the province/territory name from homeHexEnd (visible to others).
  /// Returns null if no home hex end is set.
  String? get provinceName {
    final hex = homeHexEnd ?? homeHex;
    if (hex == null) return null;
    return HexService().getTerritoryName(hex);
  }

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
    return LeaderboardEntry(
      user: UserModel.fromRow(json),
      rank: rank,
      districtHex: json['district_hex'] as String?,
    );
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
    'district_hex': districtHex,
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
      districtHex: map['district_hex'] as String?,
    );
  }

  /// Check if this entry is in the same scope as a reference home hex.
  ///
  /// For province (ALL) scope, uses [districtHex] when available because
  /// it's a reliable Res 6 H3 cell. Computing cellToParent from [homeHex]
  /// can fail when home_hex was string-generated rather than H3-derived.
  bool isInScope(String? referenceHomeHex, GeographicScope scope, {
    String? referenceDistrictHex,
  }) {
    final hexService = HexService();

    // For ALL (province) scope, prefer district_hex → Res 5 parent
    if (scope == GeographicScope.all &&
        districtHex != null &&
        referenceDistrictHex != null) {
      final myParent = hexService.getParentHexId(districtHex!, H3Config.allResolution);
      final refParent = hexService.getParentHexId(referenceDistrictHex, H3Config.allResolution);
      return myParent == refParent;
    }

    // Fallback: use home_hex
    if (homeHex == null || referenceHomeHex == null) return false;
    final myParent = hexService.getScopeHexId(homeHex!, scope);
    final refParent = hexService.getScopeHexId(referenceHomeHex, scope);
    return myParent == refParent;
  }
}

class LeaderboardState {
  final List<LeaderboardEntry> entries;
  final bool isLoading;
  final String? error;
  final int? viewingSeason;

  const LeaderboardState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
    this.viewingSeason,
  });

  bool get isViewingHistorical => viewingSeason != null;
  bool get hasData => entries.isNotEmpty;

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    bool? isLoading,
    String? Function()? error,
    int? Function()? viewingSeason,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      viewingSeason: viewingSeason != null ? viewingSeason() : this.viewingSeason,
    );
  }
}

/// LeaderboardNotifier - manages leaderboard state via Riverpod.
class LeaderboardNotifier extends Notifier<LeaderboardState> {
  late final SupabaseService _supabaseService;
  late final PrefetchService _prefetchService;
  late final LeaderboardRepository _leaderboardRepository;

  @override
  LeaderboardState build() {
    _supabaseService = SupabaseService();
    _prefetchService = PrefetchService();
    _leaderboardRepository = LeaderboardRepository();
    return const LeaderboardState();
  }

  Future<void> fetchLeaderboard({
    int limit = 200,
    bool forceRefresh = false,
  }) async {
    if (state.isLoading) return;

    if (!forceRefresh && !_leaderboardRepository.canRefresh) {
      return;
    }

    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final result = await _supabaseService.getLeaderboard(limit: limit);

      final newEntries = result.asMap().entries.map((entry) {
        return LeaderboardEntry.fromJson(entry.value, entry.key + 1);
      }).toList();

      _leaderboardRepository.loadEntries(newEntries);
      _leaderboardRepository.markFetched();
      state = state.copyWith(
        entries: newEntries,
        error: () => null,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: () => e.toString(), isLoading: false);
      debugPrint('LeaderboardNotifier.fetchLeaderboard error: $e');
    }
  }

  List<LeaderboardEntry> filterByTeam(Team? team) {
    if (team == null) return state.entries;
    return state.entries.where((e) => e.team == team).toList();
  }

  List<LeaderboardEntry> filterByScope(GeographicScope scope) {
    final referenceHex = _prefetchService.homeHex;
    if (referenceHex == null) {
      debugPrint('LeaderboardNotifier: No active hex set, returning all entries');
      return state.entries;
    }

    final referenceDistrict = _prefetchService.homeHexCity;
    return state.entries
        .where((e) => e.isInScope(
              referenceHex,
              scope,
              referenceDistrictHex: referenceDistrict,
            ))
        .toList();
  }

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
    final index = state.entries.indexWhere((e) => e.id == userId);
    return index >= 0 ? index + 1 : null;
  }

  int? getUserRankInScope(String userId, GeographicScope scope) {
    final scopedEntries = filterByScope(scope);
    final index = scopedEntries.indexWhere((e) => e.id == userId);
    return index >= 0 ? index + 1 : null;
  }

  LeaderboardEntry? getUser(String userId) {
    try {
      return state.entries.firstWhere((e) => e.id == userId);
    } catch (_) {
      return null;
    }
  }

  void clear() {
    _leaderboardRepository.clear();
    state = state.copyWith(entries: [], error: () => null);
  }

  Future<void> refreshLeaderboard() async {
    await fetchLeaderboard(forceRefresh: true);
  }

  Future<void> fetchSeasonLeaderboard(int seasonNumber) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: () => null,
      viewingSeason: () => seasonNumber,
    );

    try {
      final result = await _supabaseService.getSeasonLeaderboard(seasonNumber);

      final newEntries = result.map((json) {
        final rank = (json['rank'] as num?)?.toInt() ?? 0;
        return LeaderboardEntry.fromJson(json, rank);
      }).toList();

      _leaderboardRepository.loadEntries(newEntries);
      state = state.copyWith(
        entries: newEntries,
        error: () => null,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: () => e.toString(), isLoading: false);
      debugPrint('LeaderboardNotifier.fetchSeasonLeaderboard error: $e');
    }
  }

  void clearHistorical() {
    state = state.copyWith(viewingSeason: () => null);
  }

  Future<void> fetchScopedSeasonLeaderboard(
    int seasonNumber, {
    String? parentHex,
    int limit = 50,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: () => null,
      viewingSeason: () => seasonNumber,
    );

    try {
      final result = await _supabaseService.getSeasonLeaderboard(
        seasonNumber,
        limit: limit,
      );

      final newEntries = result.map((json) {
        final rank = (json['rank'] as num?)?.toInt() ?? 0;
        return LeaderboardEntry.fromJson(json, rank);
      }).toList();

      _leaderboardRepository.loadEntries(newEntries);
      state = state.copyWith(
        entries: newEntries,
        error: () => null,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: () => e.toString(), isLoading: false);
      debugPrint('LeaderboardNotifier.fetchScopedSeasonLeaderboard error: $e');
    }
  }
}

final leaderboardProvider = NotifierProvider<LeaderboardNotifier, LeaderboardState>(
  LeaderboardNotifier.new,
);
