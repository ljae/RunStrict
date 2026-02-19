import 'package:flutter/foundation.dart';
import '../models/team_stats.dart';
import '../services/buff_service.dart';
import '../services/hex_service.dart';
import '../services/supabase_service.dart';
import '../utils/gmt2_date_utils.dart';

export '../models/team_stats.dart';

class TeamStatsProvider with ChangeNotifier {
  YesterdayStats? _yesterdayStats;
  TeamRankings? _rankings;
  HexDominance? _dominance;
  TeamBuffComparison? _buffComparison;
  PurpleParticipation? _purpleParticipation;
  bool _isLoading = false;
  String? _error;

  final _supabase = SupabaseService();

  TeamStatsProvider();

  YesterdayStats? get yesterdayStats => _yesterdayStats;
  TeamRankings? get rankings => _rankings;
  HexDominance? get dominance => _dominance;
  TeamBuffComparison? get buffComparison => _buffComparison;
  PurpleParticipation? get purpleParticipation => _purpleParticipation;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData =>
      _yesterdayStats != null || _rankings != null || _dominance != null;

  Future<void> loadTeamData(
    String userId, {
    String? cityHex,
    String? userTeam,
    String? userName,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Compute yesterday in server timezone (GMT+2) to avoid local/server mismatch
      final serverYesterday = Gmt2DateUtils.todayGmt2.subtract(const Duration(days: 1));
      final yesterdayStr =
          '${serverYesterday.year}-${serverYesterday.month.toString().padLeft(2, '0')}-${serverYesterday.day.toString().padLeft(2, '0')}';

      final results = await Future.wait([
        _supabase.getUserYesterdayStats(userId, date: yesterdayStr),
        _supabase.getTeamRankings(userId, cityHex: cityHex),
        _supabase.getHexDominance(cityHex: cityHex),
      ]);

      final yesterdayData = results[0];
      final rankingsData = results[1];
      final dominanceData = results[2];

      _yesterdayStats = YesterdayStats.fromJson(yesterdayData);
      _rankings = TeamRankings.fromJson(rankingsData);

      final dominanceFromServer = HexDominance.fromJson(dominanceData);
      if (cityHex != null && cityHex.isNotEmpty) {
        final hexService = HexService();
        _dominance = dominanceFromServer.copyWith(
          territoryName: hexService.getTerritoryName(cityHex),
          districtNumber: hexService.getCityNumber(cityHex),
        );
      } else {
        _dominance = dominanceFromServer;
      }

      _calculateBuffComparison();

      _error = null;
    } catch (e) {
      debugPrint('TeamStatsProvider.loadTeamData error: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _calculateBuffComparison() {
    if (_rankings == null || _dominance == null) return;

    final buffService = BuffService();
    final bd = buffService.breakdown;
    final userTeam = _rankings!.userTeam;
    final userIsElite = bd.isElite;

    // Determine territory wins from server dominance data (midnight snapshot).
    // A team wins a scope only if it has strictly more hexes than all others.
    // Ties = no winner (null dominantTeam).
    final districtDominant = _dominance!.cityRange?.dominantTeam;
    final provinceDominant = _dominance!.allRange.dominantTeam;

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

    // For the user's team, use server-authoritative multiplier (bd.multiplier)
    // to avoid mismatch between YOUR BUFF and BUFF COMPARISON display.
    // Locally-computed values are theoretical; server value is actual.
    final serverMultiplier = bd.multiplier;

    _buffComparison = TeamBuffComparison(
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
        redRunnerCountCity: _rankings!.redRunnerCountCity,
        eliteCutoffRank: _rankings!.eliteCutoffRank,
      ),
      blueUnionMultiplier: userTeam == 'blue'
          ? serverMultiplier
          : blueUnionMultiplier,
    );

    // For purple team, calculate participation stats
    final cityRangeData = _dominance!.cityRange;
    if (userTeam == 'purple' && cityRangeData != null) {
      final totalPurple = cityRangeData.purpleHexCount;
      _purpleParticipation = PurpleParticipation(
        runnersRanYesterday: 0,
        totalPurpleInCity: totalPurple,
        participationRate: 0.0,
      );
    }
  }

  Future<void> refresh(
    String userId, {
    String? cityHex,
    String? userTeam,
    String? userName,
  }) async {
    await loadTeamData(
      userId,
      cityHex: cityHex,
      userTeam: userTeam,
      userName: userName,
    );
  }

  void clear() {
    _yesterdayStats = null;
    _rankings = null;
    _dominance = null;
    _buffComparison = null;
    _purpleParticipation = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
