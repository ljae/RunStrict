import 'team.dart';

class UserModel {
  final String id;
  final String name;
  final Team team;
  final String avatar;
  final int seasonPoints;
  final String? manifesto;

  final String sex;
  final DateTime birthday;
  final String? nationality;

  final String? homeHex;
  final String? homeHexEnd;
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
    required this.sex,
    required this.birthday,
    this.nationality,
    this.homeHex,
    this.homeHexEnd,
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

  /// Merge current user with server stats from `appLaunchSync`.
  ///
  /// Cannot use `copyWith` because null in `stats` means "no data through
  /// yesterday" (must clear), whereas `copyWith` null means "keep old".
  factory UserModel.mergeWithServerStats(
    UserModel existing,
    Map<String, dynamic> stats,
    int seasonPoints,
  ) {
    return UserModel(
      id: existing.id,
      name: existing.name,
      team: existing.team,
      avatar: existing.avatar,
      seasonPoints: seasonPoints,
      manifesto: existing.manifesto,
      sex: existing.sex,
      birthday: existing.birthday,
      nationality: existing.nationality,
      homeHex: stats['home_hex'] as String?,
      homeHexEnd: stats['home_hex_end'] as String?,
      seasonHomeHex: stats['season_home_hex'] as String?,
      totalDistanceKm: (stats['total_distance_km'] as num?)?.toDouble() ?? 0,
      avgPaceMinPerKm: (stats['avg_pace_min_per_km'] as num?)?.toDouble(),
      avgCv: (stats['avg_cv'] as num?)?.toDouble(),
      totalRuns: (stats['total_runs'] as num?)?.toInt() ?? 0,
    );
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
    String? sex,
    DateTime? birthday,
    String? nationality,
    String? homeHex,
    String? homeHexEnd,
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
      sex: sex ?? this.sex,
      birthday: birthday ?? this.birthday,
      nationality: nationality ?? this.nationality,
      homeHex: homeHex ?? this.homeHex,
      homeHexEnd: homeHexEnd ?? this.homeHexEnd,
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
      seasonPoints: seasonPoints,
      manifesto: manifesto,
      sex: sex,
      birthday: birthday,
      nationality: nationality,
      homeHex: homeHex,
      homeHexEnd: homeHexEnd,
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
    team: row['team'] != null
        ? Team.values.byName(row['team'] as String)
        : Team.red,
    avatar: row['avatar'] as String? ?? '🏃',
    seasonPoints: (row['season_points'] as num?)?.toInt() ?? 0,
    manifesto: row['manifesto'] as String?,
    sex: row['sex'] as String? ?? 'other',
    birthday: row['birthday'] != null
        ? DateTime.parse(row['birthday'] as String)
        : DateTime(2000, 1, 1),
    nationality: row['nationality'] as String?,
    homeHex: row['home_hex'] as String?,
    homeHexEnd: row['home_hex_end'] as String?,
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
    'sex': sex,
    'birthday': birthday.toIso8601String().substring(0, 10),
    'nationality': nationality,
    'home_hex': homeHex,
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
    'sex': sex,
    'birthday': birthday.toIso8601String(),
    'nationality': nationality,
    'homeHex': homeHex,
    'homeHexEnd': homeHexEnd,
    'seasonHomeHex': seasonHomeHex,
    'totalDistanceKm': totalDistanceKm,
    'avgPaceMinPerKm': avgPaceMinPerKm,
    'avgCv': avgCv,
    'totalRuns': totalRuns,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    name: json['name'] as String,
    team: json['team'] != null
        ? Team.values.byName(json['team'] as String)
        : Team.red,
    avatar: json['avatar'] as String? ?? '🏃',
    seasonPoints: (json['seasonPoints'] as num?)?.toInt() ?? 0,
    manifesto: json['manifesto'] as String?,
    sex: json['sex'] as String? ?? 'other',
    birthday: json['birthday'] != null
        ? DateTime.parse(json['birthday'] as String)
        : DateTime(2000, 1, 1),
    nationality: json['nationality'] as String?,
    homeHex: json['homeHex'] as String?,
    homeHexEnd: json['homeHexEnd'] as String?,
    seasonHomeHex: json['seasonHomeHex'] as String?,
    totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0,
    avgPaceMinPerKm: (json['avgPaceMinPerKm'] as num?)?.toDouble(),
    avgCv: (json['avgCv'] as num?)?.toDouble(),
    totalRuns: (json['totalRuns'] as num?)?.toInt() ?? 0,
  );
}
