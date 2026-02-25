import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/team_stats.dart';
import '../../../core/services/hex_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/gmt2_date_utils.dart';
import 'buff_provider.dart';

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
    String? cityHex,
    String? provinceHex,
    String? userTeam,
    String? userName,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final supabase = SupabaseService();
      final serverYesterday = Gmt2DateUtils.todayGmt2.subtract(const Duration(days: 1));
      final yesterdayStr =
          '${serverYesterday.year}-${serverYesterday.month.toString().padLeft(2, '0')}-${serverYesterday.day.toString().padLeft(2, '0')}';

      final results = await Future.wait([
        supabase.getUserYesterdayStats(userId, date: yesterdayStr),
        supabase.getTeamRankings(userId, cityHex: cityHex),
        supabase.getHexDominance(parentHex: provinceHex),
      ]);

      final yesterdayData = results[0];
      final rankingsData = results[1];
      final dominanceData = results[2];

      final yesterdayStats = YesterdayStats.fromJson(yesterdayData);
      final rankings = TeamRankings.fromJson(rankingsData);

      var dominance = HexDominance.fromJson(dominanceData);
      if (cityHex != null && cityHex.isNotEmpty) {
        final hexService = HexService();
        dominance = dominance.copyWith(
          territoryName: hexService.getTerritoryName(cityHex),
          districtNumber: hexService.getCityNumber(cityHex),
        );
      }

      final buffComparison = _calculateBuffComparison(rankings, dominance);
      PurpleParticipation? purpleParticipation;

      final cityRangeData = dominance.cityRange;
      if (userTeam == 'purple' && cityRangeData != null) {
        final totalPurple = cityRangeData.purpleHexCount;
        purpleParticipation = PurpleParticipation(
          runnersRanYesterday: 0,
          totalPurpleInCity: totalPurple,
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

    final districtDominant = dominance.cityRange?.dominantTeam;
    final provinceDominant = dominance.allRange.dominantTeam;

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
        redRunnerCountCity: rankings.redRunnerCountCity,
        eliteCutoffRank: rankings.eliteCutoffRank,
      ),
      blueUnionMultiplier: userTeam == 'blue'
          ? serverMultiplier
          : blueUnionMultiplier,
    );
  }

  Future<void> refresh(
    String userId, {
    String? cityHex,
    String? provinceHex,
    String? userTeam,
    String? userName,
  }) async {
    await loadTeamData(
      userId,
      cityHex: cityHex,
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
