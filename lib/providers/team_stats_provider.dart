import 'dart:math';
import 'package:flutter/foundation.dart';
import '../services/hex_service.dart';
import '../services/supabase_service.dart';

class YesterdayStats {
  final bool hasData;
  final double? distanceKm;
  final double? avgPaceMinPerKm;
  final int? flipCount;
  final int? flipPoints;
  final int? stabilityScore;
  final int runCount;
  final DateTime date;

  const YesterdayStats({
    required this.hasData,
    this.distanceKm,
    this.avgPaceMinPerKm,
    this.flipCount,
    this.flipPoints,
    this.stabilityScore,
    required this.runCount,
    required this.date,
  });

  factory YesterdayStats.fromJson(Map<String, dynamic> json) => YesterdayStats(
    hasData: json['has_data'] as bool? ?? false,
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
    avgPaceMinPerKm: (json['avg_pace_min_per_km'] as num?)?.toDouble(),
    flipCount: (json['flip_count'] as num?)?.toInt(),
    flipPoints: (json['flip_points'] as num?)?.toInt(),
    stabilityScore: (json['stability_score'] as num?)?.toInt(),
    runCount: (json['run_count'] as num?)?.toInt() ?? 0,
    date:
        DateTime.tryParse(json['date'] as String? ?? '') ??
        DateTime.now().subtract(const Duration(days: 1)),
  );

  factory YesterdayStats.empty() => YesterdayStats(
    hasData: false,
    runCount: 0,
    date: DateTime.now().subtract(const Duration(days: 1)),
  );
}

class RankingEntry {
  final String userId;
  final String name;
  final int yesterdayPoints;
  final int rank;

  const RankingEntry({
    required this.userId,
    required this.name,
    required this.yesterdayPoints,
    required this.rank,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) => RankingEntry(
    userId: json['user_id'] as String? ?? '',
    name: json['name'] as String? ?? 'Unknown',
    yesterdayPoints: (json['yesterday_points'] as num?)?.toInt() ?? 0,
    rank: (json['rank'] as num?)?.toInt() ?? 0,
  );
}

class TeamRankings {
  final String userTeam;
  final bool userIsElite;
  final int userYesterdayPoints;
  final int userRank;
  final int eliteThreshold;
  final String? cityHex;
  final List<RankingEntry> redEliteTop3;
  final List<RankingEntry> redCommonTop3;
  final List<RankingEntry> blueUnionTop3;

  const TeamRankings({
    required this.userTeam,
    required this.userIsElite,
    required this.userYesterdayPoints,
    required this.userRank,
    required this.eliteThreshold,
    this.cityHex,
    required this.redEliteTop3,
    required this.redCommonTop3,
    required this.blueUnionTop3,
  });

  factory TeamRankings.fromJson(Map<String, dynamic> json) {
    List<RankingEntry> parseEntries(dynamic data) {
      if (data == null || data is! List) return [];
      return data
          .map((e) => RankingEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return TeamRankings(
      userTeam: json['user_team'] as String? ?? '',
      userIsElite: json['user_is_elite'] as bool? ?? false,
      userYesterdayPoints:
          (json['user_yesterday_points'] as num?)?.toInt() ?? 0,
      userRank: (json['user_rank'] as num?)?.toInt() ?? 1,
      eliteThreshold: (json['elite_threshold'] as num?)?.toInt() ?? 0,
      cityHex: json['city_hex'] as String?,
      redEliteTop3: parseEntries(json['red_elite_top3']),
      redCommonTop3: parseEntries(json['red_common_top3']),
      blueUnionTop3: parseEntries(json['blue_union_top3']),
    );
  }

  factory TeamRankings.empty() => const TeamRankings(
    userTeam: '',
    userIsElite: false,
    userYesterdayPoints: 0,
    userRank: 1,
    eliteThreshold: 0,
    redEliteTop3: [],
    redCommonTop3: [],
    blueUnionTop3: [],
  );
}

class HexDominanceScope {
  final String? dominantTeam;
  final int redHexCount;
  final int blueHexCount;
  final int purpleHexCount;
  final int total;

  const HexDominanceScope({
    this.dominantTeam,
    required this.redHexCount,
    required this.blueHexCount,
    required this.purpleHexCount,
    required this.total,
  });

  factory HexDominanceScope.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const HexDominanceScope(
        redHexCount: 0,
        blueHexCount: 0,
        purpleHexCount: 0,
        total: 0,
      );
    }
    return HexDominanceScope(
      dominantTeam: json['dominant_team'] as String?,
      redHexCount: (json['red_hex_count'] as num?)?.toInt() ?? 0,
      blueHexCount: (json['blue_hex_count'] as num?)?.toInt() ?? 0,
      purpleHexCount: (json['purple_hex_count'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  double getPercentage(String team) {
    if (total == 0) return 0;
    switch (team) {
      case 'red':
        return redHexCount / total;
      case 'blue':
        return blueHexCount / total;
      case 'purple':
        return purpleHexCount / total;
      default:
        return 0;
    }
  }
}

class HexDominance {
  final HexDominanceScope allRange;
  final HexDominanceScope? cityRange;

  /// User-friendly territory name (e.g., "Amber Ridge", "Crystal Vale")
  final String? territoryName;

  /// City/District number within territory (1-7)
  final int? districtNumber;

  const HexDominance({
    required this.allRange,
    this.cityRange,
    this.territoryName,
    this.districtNumber,
  });

  factory HexDominance.fromJson(Map<String, dynamic> json) => HexDominance(
    allRange: HexDominanceScope.fromJson(
      json['all_range'] as Map<String, dynamic>?,
    ),
    cityRange: json['city_range'] != null
        ? HexDominanceScope.fromJson(json['city_range'] as Map<String, dynamic>)
        : null,
    territoryName: json['territory_name'] as String?,
    districtNumber: (json['district_number'] as num?)?.toInt(),
  );

  factory HexDominance.empty() => const HexDominance(
    allRange: HexDominanceScope(
      redHexCount: 0,
      blueHexCount: 0,
      purpleHexCount: 0,
      total: 0,
    ),
  );

  /// Copy with updated territory naming fields
  HexDominance copyWith({
    HexDominanceScope? allRange,
    HexDominanceScope? cityRange,
    String? territoryName,
    int? districtNumber,
  }) {
    return HexDominance(
      allRange: allRange ?? this.allRange,
      cityRange: cityRange ?? this.cityRange,
      territoryName: territoryName ?? this.territoryName,
      districtNumber: districtNumber ?? this.districtNumber,
    );
  }
}

/// Red team current buff status
class RedTeamBuff {
  final int eliteMultiplier; // Current elite multiplier (e.g., 3)
  final int commonMultiplier; // Always 1
  final bool isElite; // Is the user (or hypothetical) in elite tier?
  final int activeMultiplier; // The actual base multiplier being used
  final int redRunnerCountCity; // Total RED runners in city range
  final int eliteCutoffRank; // Rank cutoff for elite (top 20%)

  const RedTeamBuff({
    required this.eliteMultiplier,
    this.commonMultiplier = 1,
    required this.isElite,
    required this.activeMultiplier,
    required this.redRunnerCountCity,
    required this.eliteCutoffRank,
  });
}

/// Blue team current buff status
class BlueTeamBuff {
  final int unionMultiplier; // Current union multiplier (e.g., 2)

  const BlueTeamBuff({required this.unionMultiplier});
}

/// Purple team participation stats
class PurpleParticipation {
  final int runnersRanYesterday;
  final int totalPurpleInCity;
  final double participationRate; // 0.0 to 1.0

  const PurpleParticipation({
    required this.runnersRanYesterday,
    required this.totalPurpleInCity,
    required this.participationRate,
  });

  factory PurpleParticipation.empty() => const PurpleParticipation(
    runnersRanYesterday: 0,
    totalPurpleInCity: 0,
    participationRate: 0.0,
  );

  int get participationPercent => (participationRate * 100).round();
}

/// Buff comparison data for Red vs Blue teams - CURRENT STATUS ONLY
class TeamBuffComparison {
  // Current buff status for each team
  final RedTeamBuff redBuff;
  final BlueTeamBuff blueBuff;
  // Bonuses (apply to user only)
  final int allRangeBonus;
  final int cityLeaderBonus; // 0 or 1
  // User info
  final String userTeam; // 'red', 'blue', or 'purple'
  // Final calculated multiplier for user
  final int userTotalMultiplier;

  const TeamBuffComparison({
    required this.redBuff,
    required this.blueBuff,
    required this.allRangeBonus,
    required this.cityLeaderBonus,
    required this.userTeam,
    required this.userTotalMultiplier,
  });
}

class TeamStatsProvider with ChangeNotifier {
  final SupabaseService _supabaseService;

  YesterdayStats? _yesterdayStats;
  TeamRankings? _rankings;
  HexDominance? _dominance;
  TeamBuffComparison? _buffComparison;
  PurpleParticipation? _purpleParticipation;
  bool _isLoading = false;
  String? _error;

  TeamStatsProvider({SupabaseService? supabaseService})
    : _supabaseService = supabaseService ?? SupabaseService();

  YesterdayStats? get yesterdayStats => _yesterdayStats;
  TeamRankings? get rankings => _rankings;
  HexDominance? get dominance => _dominance;
  TeamBuffComparison? get buffComparison => _buffComparison;
  PurpleParticipation? get purpleParticipation => _purpleParticipation;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData =>
      _yesterdayStats != null || _rankings != null || _dominance != null;

  /// Check if a string is a valid UUID format
  bool _isValidUuid(String id) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(id);
  }

  /// Generate realistic dummy data for debug/local mode
  void _loadDummyData() {
    final random = Random();

    // Yesterday's stats - realistic running data
    _yesterdayStats = YesterdayStats(
      hasData: true,
      distanceKm: 5.2 + random.nextDouble() * 3, // 5.2-8.2 km
      avgPaceMinPerKm: 5.5 + random.nextDouble() * 1.5, // 5:30-7:00 /km
      flipCount: 8 + random.nextInt(12), // 8-20 flips
      flipPoints: 24 + random.nextInt(36), // 24-60 points
      stabilityScore: 65 + random.nextInt(30), // 65-95%
      runCount: 1 + random.nextInt(2), // 1-2 runs
      date: DateTime.now().subtract(const Duration(days: 1)),
    );

    // Generate dummy neighbor rankings
    final dummyRedElite = [
      RankingEntry(
        userId: 'u1',
        name: 'FlameRunner_01',
        yesterdayPoints: 156,
        rank: 1,
      ),
      RankingEntry(
        userId: 'u2',
        name: 'BlazeKing',
        yesterdayPoints: 132,
        rank: 2,
      ),
      RankingEntry(
        userId: 'u3',
        name: 'RedStorm',
        yesterdayPoints: 118,
        rank: 3,
      ),
    ];
    final dummyRedCommon = [
      RankingEntry(
        userId: 'u4',
        name: 'FireWalker',
        yesterdayPoints: 45,
        rank: 1,
      ),
      RankingEntry(
        userId: 'u5',
        name: 'EmberPath',
        yesterdayPoints: 38,
        rank: 2,
      ),
      RankingEntry(
        userId: 'u6',
        name: 'ScarletRun',
        yesterdayPoints: 27,
        rank: 3,
      ),
    ];
    final dummyBlueUnion = [
      RankingEntry(
        userId: 'u7',
        name: 'WaveRider_X',
        yesterdayPoints: 142,
        rank: 1,
      ),
      RankingEntry(
        userId: 'u8',
        name: 'OceanPace',
        yesterdayPoints: 128,
        rank: 2,
      ),
      RankingEntry(
        userId: 'u9',
        name: 'TidalForce',
        yesterdayPoints: 95,
        rank: 3,
      ),
    ];

    _rankings = TeamRankings(
      userTeam: 'red', // Default to red for dummy
      userIsElite: random.nextBool(),
      userYesterdayPoints: 45 + random.nextInt(80),
      userRank: 2 + random.nextInt(5), // Rank 2-6
      eliteThreshold: 100,
      cityHex: '8628308fff',
      redEliteTop3: dummyRedElite,
      redCommonTop3: dummyRedCommon,
      blueUnionTop3: dummyBlueUnion,
    );

    // Use correct hex totals based on H3 hierarchy
    // ALL range (Res 5 → Res 9): 2,401 hexes
    // CITY range (Res 6 → Res 9): 343 hexes
    const allRangeTotal = 2401;
    const cityTotal = 343;

    // Generate realistic distribution (sum must equal total)
    final allRed = (allRangeTotal * (0.35 + random.nextDouble() * 0.15))
        .round();
    final allBlue = (allRangeTotal * (0.30 + random.nextDouble() * 0.15))
        .round();
    final allPurple = allRangeTotal - allRed - allBlue;

    final cityRed = (cityTotal * (0.38 + random.nextDouble() * 0.12)).round();
    final cityBlue = (cityTotal * (0.32 + random.nextDouble() * 0.12)).round();
    final cityPurple = cityTotal - cityRed - cityBlue;

    // Generate user-friendly territory name
    final territoryName = HexService.generateRandomTerritoryName(
      random.nextInt(1600), // 40 adj × 40 nouns = 1600 combinations
    );

    _dominance = HexDominance(
      allRange: HexDominanceScope(
        dominantTeam: allRed > allBlue ? 'red' : 'blue',
        redHexCount: allRed,
        blueHexCount: allBlue,
        purpleHexCount: allPurple,
        total: allRangeTotal,
      ),
      cityRange: HexDominanceScope(
        dominantTeam: cityRed > cityBlue ? 'red' : 'blue',
        redHexCount: cityRed,
        blueHexCount: cityBlue,
        purpleHexCount: cityPurple,
        total: cityTotal,
      ),
      territoryName: territoryName,
      districtNumber: 1 + random.nextInt(7), // 1-7
    );

    // Buff comparison - Calculate using NEW rules:
    // RED Elite: Base 2x, +1 for district, +1 for province = max 4x
    // RED Common: Base 1x, +0 for district, +1 for province = max 2x
    // BLUE Union: Base 1x, +1 for district, +1 for province = max 3x
    final userIsElite = random.nextBool();
    final redWinsDistrict = cityRed > cityBlue;
    final redWinsProvince = allRed > allBlue;
    final blueWinsDistrict = cityBlue > cityRed;
    final blueWinsProvince = allBlue > allRed;

    // Calculate RED multipliers
    int redEliteMultiplier = 2; // Base
    if (redWinsDistrict) redEliteMultiplier += 1;
    if (redWinsProvince) redEliteMultiplier += 1;

    int redCommonMultiplier = 1; // Base
    // Common does NOT get district bonus
    if (redWinsProvince) redCommonMultiplier += 1;

    // Calculate BLUE multiplier
    int blueUnionMultiplier = 1; // Base
    if (blueWinsDistrict) blueUnionMultiplier += 1;
    if (blueWinsProvince) blueUnionMultiplier += 1;

    // For UI breakdown display
    final allRangeBonus = redWinsProvince ? 1 : 0;
    final cityLeaderBonus = (userIsElite && redWinsDistrict) ? 1 : 0;

    // Red runner stats for city
    final redRunnerCountCity = 45 + random.nextInt(30); // 45-75 runners
    final eliteCutoffRank = (redRunnerCountCity * 0.2).ceil(); // Top 20%

    // Calculate user's total multiplier (assuming red team for dummy)
    final userTotal = userIsElite ? redEliteMultiplier : redCommonMultiplier;

    _buffComparison = TeamBuffComparison(
      redBuff: RedTeamBuff(
        eliteMultiplier: redEliteMultiplier,
        commonMultiplier: redCommonMultiplier,
        isElite: userIsElite,
        activeMultiplier: userIsElite
            ? redEliteMultiplier
            : redCommonMultiplier,
        redRunnerCountCity: redRunnerCountCity,
        eliteCutoffRank: eliteCutoffRank,
      ),
      blueBuff: BlueTeamBuff(unionMultiplier: blueUnionMultiplier),
      allRangeBonus: allRangeBonus,
      cityLeaderBonus: cityLeaderBonus,
      userTeam: 'red', // Default to red for dummy data
      userTotalMultiplier: userTotal,
    );

    // Purple participation data (for CHAOS team buff display)
    final totalPurpleInCity = 20 + random.nextInt(30); // 20-50 purple runners
    final runnersRanYesterday =
        (totalPurpleInCity * (0.4 + random.nextDouble() * 0.4))
            .round(); // 40-80%
    _purpleParticipation = PurpleParticipation(
      runnersRanYesterday: runnersRanYesterday,
      totalPurpleInCity: totalPurpleInCity,
      participationRate: totalPurpleInCity > 0
          ? runnersRanYesterday / totalPurpleInCity
          : 0.0,
    );
  }

  Future<void> loadTeamData(String userId, {String? cityHex}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    // For local/debug mode with non-UUID user IDs, use mock data
    if (!_isValidUuid(userId)) {
      debugPrint(
        'TeamStatsProvider: Using mock data for non-UUID user: $userId',
      );
      _loadDummyData();
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final results = await Future.wait([
        _supabaseService.getUserYesterdayStats(userId),
        _supabaseService.getTeamRankings(userId, cityHex: cityHex),
        _supabaseService.getHexDominance(cityHex: cityHex),
      ]);

      _yesterdayStats = YesterdayStats.fromJson(results[0]);
      _rankings = TeamRankings.fromJson(results[1]);
      _dominance = HexDominance.fromJson(results[2]);

      // Calculate buff comparison from real data
      _calculateBuffComparison();

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('TeamStatsProvider.loadTeamData error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calculate buff comparison from loaded real data
  ///
  /// Buff calculation rules (from DEVELOPMENT_SPEC.md):
  ///
  /// RED FLAME:
  /// | Scenario              | Elite (Top 20%) | Common |
  /// |-----------------------|-----------------|--------|
  /// | Normal (no wins)      | 2x              | 1x     |
  /// | District win only     | 3x              | 1x     |
  /// | Province win only     | 3x              | 2x     |
  /// | District + Province   | 4x              | 2x     |
  ///
  /// BLUE WAVE:
  /// | Scenario              | Union |
  /// |-----------------------|-------|
  /// | Normal (no wins)      | 1x    |
  /// | District win only     | 2x    |
  /// | Province win only     | 2x    |
  /// | District + Province   | 3x    |
  ///
  /// PURPLE:
  /// | Participation Rate | Multiplier |
  /// |-------------------|------------|
  /// | ≥67%              | 3x         |
  /// | 34-66%            | 2x         |
  /// | <34%              | 1x         |
  void _calculateBuffComparison() {
    if (_rankings == null || _dominance == null) return;

    final userTeam = _rankings!.userTeam;
    final userIsElite = _rankings!.userIsElite;

    // Calculate territory dominance
    final allRange = _dominance!.allRange;
    final cityRange = _dominance!.cityRange;

    // Determine which team is winning each territory
    final redWinsProvince = allRange.redHexCount > allRange.blueHexCount;
    final blueWinsProvince = allRange.blueHexCount > allRange.redHexCount;
    final redWinsDistrict =
        cityRange != null && cityRange.redHexCount > cityRange.blueHexCount;
    final blueWinsDistrict =
        cityRange != null && cityRange.blueHexCount > cityRange.redHexCount;

    // Calculate multipliers based on NEW rules:
    // RED Elite: Base 2x, +1 for district, +1 for province = max 4x
    // RED Common: Base 1x, +0 for district, +1 for province = max 2x
    // BLUE Union: Base 1x, +1 for district, +1 for province = max 3x

    // RED Elite multiplier (for display)
    int redEliteMultiplier = 2; // Base
    if (redWinsDistrict) redEliteMultiplier += 1;
    if (redWinsProvince) redEliteMultiplier += 1;

    // RED Common multiplier (for display)
    int redCommonMultiplier = 1; // Base
    // Common does NOT get district bonus
    if (redWinsProvince) redCommonMultiplier += 1;

    // BLUE Union multiplier (for display)
    int blueUnionMultiplier = 1; // Base
    if (blueWinsDistrict) blueUnionMultiplier += 1;
    if (blueWinsProvince) blueUnionMultiplier += 1;

    // Province bonus for user (for UI breakdown display)
    int allRangeBonus = 0;
    if ((userTeam == 'red' && redWinsProvince) ||
        (userTeam == 'blue' && blueWinsProvince)) {
      allRangeBonus = 1;
    }

    // District bonus for user (for UI breakdown display)
    int cityLeaderBonus = 0;
    if (userTeam == 'red' && userIsElite && redWinsDistrict) {
      // RED Elite gets district bonus
      cityLeaderBonus = 1;
    } else if (userTeam == 'blue' && blueWinsDistrict) {
      // BLUE gets district bonus
      cityLeaderBonus = 1;
    }
    // Note: RED Common does NOT get district bonus

    // Calculate red runner count and elite cutoff from rankings data
    final redRunnerCountCity = (_rankings!.eliteThreshold > 0)
        ? (_rankings!.eliteThreshold * 5).clamp(20, 200)
        : 50;
    final eliteCutoffRank = (redRunnerCountCity * 0.2).ceil();

    // Calculate user's total multiplier
    int userTotalMultiplier;
    if (userTeam == 'red') {
      userTotalMultiplier = userIsElite
          ? redEliteMultiplier
          : redCommonMultiplier;
    } else if (userTeam == 'blue') {
      userTotalMultiplier = blueUnionMultiplier;
    } else {
      // Purple team - participation-based (calculated separately)
      userTotalMultiplier = 1;
    }

    _buffComparison = TeamBuffComparison(
      redBuff: RedTeamBuff(
        eliteMultiplier: redEliteMultiplier,
        commonMultiplier: redCommonMultiplier,
        isElite: userTeam == 'red' ? userIsElite : false,
        activeMultiplier: userTeam == 'red'
            ? (userIsElite ? redEliteMultiplier : redCommonMultiplier)
            : redEliteMultiplier,
        redRunnerCountCity: redRunnerCountCity,
        eliteCutoffRank: eliteCutoffRank,
      ),
      blueBuff: BlueTeamBuff(unionMultiplier: blueUnionMultiplier),
      allRangeBonus: allRangeBonus,
      cityLeaderBonus: cityLeaderBonus,
      userTeam: userTeam,
      userTotalMultiplier: userTotalMultiplier,
    );

    // For purple team, calculate participation stats
    if (userTeam == 'purple' && cityRange != null) {
      final totalPurple = cityRange.purpleHexCount;
      _purpleParticipation = PurpleParticipation(
        runnersRanYesterday: 0, // Would need separate RPC for actual data
        totalPurpleInCity: totalPurple,
        participationRate: 0.0,
      );
    }
  }

  Future<void> refresh(String userId, {String? cityHex}) async {
    await loadTeamData(userId, cityHex: cityHex);
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
