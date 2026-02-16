/// Team statistics models extracted from TeamStatsProvider.
///
/// These display models support the Team Screen UI and buff comparison.
import '../services/buff_service.dart';

class YesterdayStats {
  final bool hasData;
  final double? distanceKm;
  final double? avgPaceMinPerKm;
  final int? flipPoints;
  final int? stabilityScore;
  final int runCount;
  final DateTime date;

  const YesterdayStats({
    required this.hasData,
    this.distanceKm,
    this.avgPaceMinPerKm,
    this.flipPoints,
    this.stabilityScore,
    required this.runCount,
    required this.date,
  });

  factory YesterdayStats.fromJson(Map<String, dynamic> json) => YesterdayStats(
    hasData: json['has_data'] as bool? ?? false,
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
    avgPaceMinPerKm: (json['avg_pace_min_per_km'] as num?)?.toDouble(),
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
  final int redRunnerCountCity;
  final int eliteCutoffRank;

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
    this.redRunnerCountCity = 0,
    this.eliteCutoffRank = 0,
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
      redRunnerCountCity: (json['red_runner_count_city'] as num?)?.toInt() ?? 0,
      eliteCutoffRank: (json['elite_cutoff_rank'] as num?)?.toInt() ?? 0,
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
  final int redHexCount;
  final int blueHexCount;
  final int purpleHexCount;

  const HexDominanceScope({
    required this.redHexCount,
    required this.blueHexCount,
    required this.purpleHexCount,
  });

  /// Total hex count (derived from component counts).
  int get total => redHexCount + blueHexCount + purpleHexCount;

  /// Dominant team (derived from max count). Null if tied.
  String? get dominantTeam {
    if (redHexCount > blueHexCount && redHexCount > purpleHexCount) {
      return 'red';
    }
    if (blueHexCount > redHexCount && blueHexCount > purpleHexCount) {
      return 'blue';
    }
    if (purpleHexCount > redHexCount && purpleHexCount > blueHexCount) {
      return 'purple';
    }
    return null;
  }

  factory HexDominanceScope.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const HexDominanceScope(
        redHexCount: 0,
        blueHexCount: 0,
        purpleHexCount: 0,
      );
    }
    return HexDominanceScope(
      redHexCount: (json['red_hex_count'] as num?)?.toInt() ?? 0,
      blueHexCount: (json['blue_hex_count'] as num?)?.toInt() ?? 0,
      purpleHexCount: (json['purple_hex_count'] as num?)?.toInt() ?? 0,
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

/// Buff comparison data for Red vs Blue teams - CURRENT STATUS ONLY.
///
/// Wraps [BuffBreakdown] (server-authoritative) and adds display-only
/// comparison fields ([redBuff], [blueUnionMultiplier]).
/// Eliminates 5 previously duplicated fields by delegating to breakdown.
class TeamBuffComparison {
  /// Server-authoritative buff breakdown for the current user.
  final BuffBreakdown breakdown;
  // Display-only comparison data
  final RedTeamBuff redBuff;
  final int blueUnionMultiplier;

  const TeamBuffComparison({
    required this.breakdown,
    required this.redBuff,
    required this.blueUnionMultiplier,
  });

  // Delegate to BuffBreakdown (eliminates duplicate fields)
  int get allRangeBonus => breakdown.allRangeBonus;
  int get cityLeaderBonus => breakdown.isCityLeader ? 1 : 0;
  String get userTeam => breakdown.team;
  int get userTotalMultiplier => breakdown.multiplier;
}
