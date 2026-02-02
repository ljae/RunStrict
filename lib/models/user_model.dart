import 'team.dart';

class UserModel {
  final String id;
  final String name;
  final Team team;
  final String avatar;
  final int seasonPoints;
  final String? manifesto;

  /// Home hex (Res 9) - set once on first GPS fix, used for scope filtering
  /// Parent cells derived on-demand via HexService.getScopeHexId()
  final String? homeHex;

  /// Season home hex (Res 9) - set once on first app launch of season
  /// Used for leaderboard MY LEAGUE filtering and multiplier region
  final String? seasonHomeHex;

  /// Total distance run in season (km)
  final double totalDistanceKm;

  /// Average pace across all runs (min/km, null if no runs)
  final double? avgPaceMinPerKm;

  /// Average Coefficient of Variation (null if no CV data)
  /// Measures overall pace consistency
  final double? avgCv;

  /// Total number of runs completed
  final int totalRuns;

  const UserModel({
    required this.id,
    required this.name,
    required this.team,
    this.avatar = '🏃',
    this.seasonPoints = 0,
    this.manifesto,
    this.homeHex,
    this.seasonHomeHex,
    this.totalDistanceKm = 0,
    this.avgPaceMinPerKm,
    this.avgCv,
    this.totalRuns = 0,
  });

  bool get isPurple => team == Team.purple;

  /// Stability score from average CV (higher = better)
  /// Returns clamped 0-100 value, null if no CV data
  int? get stabilityScore {
    if (avgCv == null) return null;
    return (100 - avgCv!).round().clamp(0, 100);
  }

  /// Copy with optional field updates.
  ///
  /// Use [clearSeasonHomeHex: true] to explicitly set seasonHomeHex to null.
  UserModel copyWith({
    String? name,
    Team? team,
    String? avatar,
    int? seasonPoints,
    String? manifesto,
    String? homeHex,
    String? seasonHomeHex,
    bool clearSeasonHomeHex = false,
    double? totalDistanceKm,
    double? avgPaceMinPerKm,
    double? avgCv,
    int? totalRuns,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      team: team ?? this.team,
      avatar: avatar ?? this.avatar,
      seasonPoints: seasonPoints ?? this.seasonPoints,
      manifesto: manifesto ?? this.manifesto,
      homeHex: homeHex ?? this.homeHex,
      seasonHomeHex: clearSeasonHomeHex
          ? null
          : (seasonHomeHex ?? this.seasonHomeHex),
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      avgPaceMinPerKm: avgPaceMinPerKm ?? this.avgPaceMinPerKm,
      avgCv: avgCv ?? this.avgCv,
      totalRuns: totalRuns ?? this.totalRuns,
    );
  }

  /// Defect to Purple team (Protocol of Chaos).
  /// Points are PRESERVED on defection.
  UserModel defectToPurple() {
    return UserModel(
      id: id,
      name: name,
      team: Team.purple,
      avatar: avatar,
      seasonPoints: seasonPoints, // Points PRESERVED
      manifesto: manifesto,
      homeHex: homeHex,
      seasonHomeHex: seasonHomeHex,
      totalDistanceKm: totalDistanceKm,
      avgPaceMinPerKm: avgPaceMinPerKm,
      avgCv: avgCv,
      totalRuns: totalRuns,
    );
  }

  factory UserModel.fromRow(Map<String, dynamic> row) => UserModel(
    id: row['id'] as String,
    name: row['name'] as String,
    team: Team.values.byName(row['team'] as String),
    avatar: row['avatar'] as String? ?? '🏃',
    seasonPoints: (row['season_points'] as num?)?.toInt() ?? 0,
    manifesto: row['manifesto'] as String?,
    homeHex: row['home_hex'] as String?,
    seasonHomeHex: row['season_home_hex'] as String?,
    totalDistanceKm: (row['total_distance_km'] as num?)?.toDouble() ?? 0,
    avgPaceMinPerKm: (row['avg_pace_min_per_km'] as num?)?.toDouble(),
    avgCv: (row['avg_cv'] as num?)?.toDouble(),
    totalRuns: (row['total_runs'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toRow() => {
    'name': name,
    'team': team.name,
    'avatar': avatar,
    'season_points': seasonPoints,
    'manifesto': manifesto,
    'home_hex': homeHex,
    'season_home_hex': seasonHomeHex,
    'total_distance_km': totalDistanceKm,
    'avg_pace_min_per_km': avgPaceMinPerKm,
    'avg_cv': avgCv,
    'total_runs': totalRuns,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'team': team.name,
    'avatar': avatar,
    'seasonPoints': seasonPoints,
    'manifesto': manifesto,
    'homeHex': homeHex,
    'seasonHomeHex': seasonHomeHex,
    'totalDistanceKm': totalDistanceKm,
    'avgPaceMinPerKm': avgPaceMinPerKm,
    'avgCv': avgCv,
    'totalRuns': totalRuns,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    name: json['name'] as String,
    team: Team.values.byName(json['team'] as String),
    avatar: json['avatar'] as String? ?? '🏃',
    seasonPoints: (json['seasonPoints'] as num?)?.toInt() ?? 0,
    manifesto: json['manifesto'] as String?,
    homeHex: json['homeHex'] as String?,
    seasonHomeHex: json['seasonHomeHex'] as String?,
    totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0,
    avgPaceMinPerKm: (json['avgPaceMinPerKm'] as num?)?.toDouble(),
    avgCv: (json['avgCv'] as num?)?.toDouble(),
    totalRuns: (json['totalRuns'] as num?)?.toInt() ?? 0,
  );
}
