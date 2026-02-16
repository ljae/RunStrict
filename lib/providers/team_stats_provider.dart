import 'package:flutter/foundation.dart';
import '../models/team_stats.dart';
import '../services/buff_service.dart';
import '../services/hex_service.dart';
import '../services/supabase_service.dart';

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
      final results = await Future.wait([
        _supabase.getUserYesterdayStats(userId),
        _supabase.getTeamRankings(userId, cityHex: cityHex),
        _supabase.getHexDominance(cityHex: cityHex),
      ]);

      final yesterdayData = results[0];
      final rankingsData = results[1];
      final dominanceData = results[2];

      _yesterdayStats = YesterdayStats.fromJson(yesterdayData);
      _rankings = TeamRankings.fromJson(rankingsData);

      final dominanceFromServer = HexDominance.fromJson(dominanceData);
      if (cityHex != null && cityHex.length >= 10) {
        final hexService = HexService();
        final parentHex = '${cityHex.substring(0, 10)}fffff';
        _dominance = dominanceFromServer.copyWith(
          territoryName: hexService.getTerritoryName(parentHex),
          districtNumber: hexService.getCityNumber(parentHex),
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

    _buffComparison = TeamBuffComparison(
      breakdown: bd,
      redBuff: RedTeamBuff(
        eliteMultiplier: redEliteMultiplier,
        commonMultiplier: redCommonMultiplier,
        isElite: userTeam == 'red' ? userIsElite : false,
        activeMultiplier: userTeam == 'red'
            ? (userIsElite ? redEliteMultiplier : redCommonMultiplier)
            : redEliteMultiplier,
        redRunnerCountCity: _rankings!.redRunnerCountCity,
        eliteCutoffRank: _rankings!.eliteCutoffRank,
      ),
      blueUnionMultiplier: blueUnionMultiplier,
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
