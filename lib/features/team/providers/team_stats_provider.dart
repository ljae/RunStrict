import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/team_stats.dart';
import '../../../core/services/hex_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/gmt2_date_utils.dart';
import 'buff_provider.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../../../data/repositories/hex_repository.dart';

export '../../../data/models/team_stats.dart';

class TeamStatsState {
  final YesterdayStats? yesterdayStats;
  final TeamRankings? rankings;
  final HexDominance? dominance;
  final TeamBuffComparison? buffComparison;
  final PurpleParticipation? purpleParticipation;
  final bool isLoading;
  final String? error;

  const TeamStatsState({
    this.yesterdayStats,
    this.rankings,
    this.dominance,
    this.buffComparison,
    this.purpleParticipation,
    this.isLoading = false,
    this.error,
  });

  bool get hasData =>
      yesterdayStats != null || rankings != null || dominance != null;

  TeamStatsState copyWith({
    YesterdayStats? Function()? yesterdayStats,
    TeamRankings? Function()? rankings,
    HexDominance? Function()? dominance,
    TeamBuffComparison? Function()? buffComparison,
    PurpleParticipation? Function()? purpleParticipation,
    bool? isLoading,
    String? Function()? error,
  }) {
    return TeamStatsState(
      yesterdayStats: yesterdayStats != null ? yesterdayStats() : this.yesterdayStats,
      rankings: rankings != null ? rankings() : this.rankings,
      dominance: dominance != null ? dominance() : this.dominance,
      buffComparison: buffComparison != null ? buffComparison() : this.buffComparison,
      purpleParticipation: purpleParticipation != null ? purpleParticipation() : this.purpleParticipation,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
    );
  }
}

class TeamStatsNotifier extends Notifier<TeamStatsState> {
  @override
  TeamStatsState build() => const TeamStatsState();

  Future<void> loadTeamData(
    String userId, {
    String? districtHex,
    String? provinceHex,
    String? userTeam,
    String? userName,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final supabase = SupabaseService();

      // On Season Day 1, yesterday was the previous season's last day.
      // Skip yesterday stats AND rankings to avoid stale cross-season data.
      // Server RPCs also have season boundary checks (belt + suspenders).
      final isDay1 = ref.read(seasonServiceProvider).isFirstDay;

      final serverYesterday = Gmt2DateUtils.todayGmt2.subtract(const Duration(days: 1));
      final yesterdayStr =
          '${serverYesterday.year}-${serverYesterday.month.toString().padLeft(2, '0')}-${serverYesterday.day.toString().padLeft(2, '0')}';

      final results = await Future.wait([
        if (!isDay1)
          supabase.getUserYesterdayStats(userId, date: yesterdayStr)
        else
          Future.value(<String, dynamic>{'has_data': false}),
        // Rankings always fetched — server RPC handles season boundary internally.
        // On Day 1, yesterday may be previous season's last day; the RPC returns
        // empty [] if v_yesterday < current_season_start (server-side guard).
        supabase.getTeamRankings(userId, districtHex: districtHex),

      ]);

      final yesterdayData = results[0];
      final rankingsData = results[1];

      final yesterdayStats = YesterdayStats.fromJson(yesterdayData);
      final rankings = TeamRankings.fromJson(rankingsData);
      debugPrint(
        'TeamStatsNotifier: districtHex=$districtHex | elite=${rankings.redEliteTop3.length} | '
        'threshold=${rankings.eliteThreshold} | count=${rankings.redRunnerCountDistrict}',
      );

      // Compute dominance from locally-downloaded hex data (HexRepository).
      // The Supabase RPC returns wrong JSON structure (flat keys vs nested),
      // and hexes table has no district_hex column for city-range filtering.
      // HexRepository already has the full snapshot downloaded on app launch.
      final localDominance = HexRepository().computeHexDominance(
        homeHexProvince: provinceHex ?? '',
        homeHexDistrict: districtHex,
        includeLocalOverlay: false, // Territory = snapshot-only (yesterday's state)
      );
      final provinceRangeMap = localDominance['provinceRange']!;
      final districtRangeMap = localDominance['districtRange']!;
      final hasDistrictData = districtHex != null && districtHex.isNotEmpty;
      var dominance = HexDominance(
        provinceRange: HexDominanceScope(
          redHexCount: provinceRangeMap['red'] ?? 0,
          blueHexCount: provinceRangeMap['blue'] ?? 0,
          purpleHexCount: provinceRangeMap['purple'] ?? 0,
        ),
        districtRange: hasDistrictData
            ? HexDominanceScope(
                redHexCount: districtRangeMap['red'] ?? 0,
                blueHexCount: districtRangeMap['blue'] ?? 0,
                purpleHexCount: districtRangeMap['purple'] ?? 0,
              )
            : null,
      );
      if (districtHex != null && districtHex.isNotEmpty) {
        final hexService = HexService();
        dominance = dominance.copyWith(
          territoryName: hexService.getTerritoryName(districtHex),
          districtNumber: hexService.getDistrictNumber(districtHex),
        );
      }

      final buffComparison = _calculateBuffComparison(rankings, dominance);
      PurpleParticipation? purpleParticipation;

      final districtRangeData = dominance.districtRange;
      if (userTeam == 'purple' && districtRangeData != null) {
        final totalPurple = districtRangeData.purpleHexCount;
        purpleParticipation = PurpleParticipation(
          runnersRanYesterday: 0,
          totalPurpleInDistrict: totalPurple,
          participationRate: 0.0,
        );
      }

      state = TeamStatsState(
        yesterdayStats: yesterdayStats,
        rankings: rankings,
        dominance: dominance,
        buffComparison: buffComparison,
        purpleParticipation: purpleParticipation,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('TeamStatsNotifier.loadTeamData error: $e');
      state = state.copyWith(error: () => e.toString(), isLoading: false);
    }
  }

  TeamBuffComparison? _calculateBuffComparison(
    TeamRankings rankings,
    HexDominance dominance,
  ) {
    final buffState = ref.read(buffProvider);
    final bd = buffState.breakdown;
    final userTeam = rankings.userTeam;
    final userIsElite = bd.isElite;

    final districtDominant = dominance.districtRange?.dominantTeam;
    final provinceDominant = dominance.provinceRange.dominantTeam;

    final redDistrictWin = districtDominant == 'red';
    final redProvinceWin = provinceDominant == 'red';
    final blueDistrictWin = districtDominant == 'blue';
    final blueProvinceWin = provinceDominant == 'blue';

    int redEliteMultiplier = 2;
    if (redDistrictWin) redEliteMultiplier += 1;
    if (redProvinceWin) redEliteMultiplier += 1;

    int redCommonMultiplier = 1;
    if (redProvinceWin) redCommonMultiplier += 1;

    int blueUnionMultiplier = 1;
    if (blueDistrictWin) blueUnionMultiplier += 1;
    if (blueProvinceWin) blueUnionMultiplier += 1;

    final serverMultiplier = bd.multiplier;

    return TeamBuffComparison(
      breakdown: bd,
      redBuff: RedTeamBuff(
        eliteMultiplier: userTeam == 'red' && userIsElite
            ? serverMultiplier
            : redEliteMultiplier,
        commonMultiplier: userTeam == 'red' && !userIsElite
            ? serverMultiplier
            : redCommonMultiplier,
        isElite: userTeam == 'red' ? userIsElite : false,
        activeMultiplier: userTeam == 'red'
            ? serverMultiplier
            : redEliteMultiplier,
        redRunnerCountDistrict: rankings.redRunnerCountDistrict,
        eliteCutoffRank: rankings.eliteCutoffRank,
      ),
      blueUnionMultiplier: userTeam == 'blue'
          ? serverMultiplier
          : blueUnionMultiplier,
    );
  }

  Future<void> refresh(
    String userId, {
    String? districtHex,
    String? provinceHex,
    String? userTeam,
    String? userName,
  }) async {
    await loadTeamData(
      userId,
      districtHex: districtHex,
      provinceHex: provinceHex,
      userTeam: userTeam,
      userName: userName,
    );
  }

  void clear() {
    state = const TeamStatsState();
  }
}

final teamStatsProvider = NotifierProvider<TeamStatsNotifier, TeamStatsState>(
  TeamStatsNotifier.new,
);
