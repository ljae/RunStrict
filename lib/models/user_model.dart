import 'team.dart';

class UserModel {
  final String id;
  final String name;
  final Team team;
  final String avatar;
  final String? crewId;
  final int seasonPoints;
  final String? manifesto;

  /// Original avatar preserved when joining crew (restored on leave)
  final String? originalAvatar;

  /// Home hex (Res 9) - set once on first GPS fix, used for scope filtering
  /// Parent cells derived on-demand via HexService.getScopeHexId()
  final String? homeHex;

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
    this.crewId,
    this.seasonPoints = 0,
    this.manifesto,
    this.originalAvatar,
    this.homeHex,
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
  /// Use [clearCrewId: true] to explicitly set crewId to null.
  /// Use [clearOriginalAvatar: true] to explicitly set originalAvatar to null.
  UserModel copyWith({
    String? name,
    Team? team,
    String? crewId,
    bool clearCrewId = false,
    String? avatar,
    int? seasonPoints,
    String? manifesto,
    String? originalAvatar,
    bool clearOriginalAvatar = false,
    String? homeHex,
    double? totalDistanceKm,
    double? avgPaceMinPerKm,
    double? avgCv,
    int? totalRuns,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      team: team ?? this.team,
      crewId: clearCrewId ? null : (crewId ?? this.crewId),
      avatar: avatar ?? this.avatar,
      seasonPoints: seasonPoints ?? this.seasonPoints,
      manifesto: manifesto ?? this.manifesto,
      originalAvatar: clearOriginalAvatar
          ? null
          : (originalAvatar ?? this.originalAvatar),
      homeHex: homeHex ?? this.homeHex,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      avgPaceMinPerKm: avgPaceMinPerKm ?? this.avgPaceMinPerKm,
      avgCv: avgCv ?? this.avgCv,
      totalRuns: totalRuns ?? this.totalRuns,
    );
  }

  /// Defect to Purple team (Protocol of Chaos).
  /// Requires: User must leave crew first (crewId == null).
  /// Resets season points to 0.
  UserModel defectToPurple() {
    assert(crewId == null, 'Must leave crew before defecting to Purple');
    return UserModel(
      id: id,
      name: name,
      team: Team.purple,
      crewId: null,
      avatar: avatar,
      seasonPoints: 0,
      manifesto: manifesto,
      originalAvatar: null, // Clear on defection
      homeHex: homeHex,
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
    crewId: row['crew_id'] as String?,
    seasonPoints: (row['season_points'] as num?)?.toInt() ?? 0,
    manifesto: row['manifesto'] as String?,
    originalAvatar: row['original_avatar'] as String?,
    homeHex: row['home_hex'] as String?,
    totalDistanceKm: (row['total_distance_km'] as num?)?.toDouble() ?? 0,
    avgPaceMinPerKm: (row['avg_pace_min_per_km'] as num?)?.toDouble(),
    avgCv: (row['avg_cv'] as num?)?.toDouble(),
    totalRuns: (row['total_runs'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toRow() => {
    'name': name,
    'team': team.name,
    'avatar': avatar,
    'crew_id': crewId,
    'season_points': seasonPoints,
    'manifesto': manifesto,
    'original_avatar': originalAvatar,
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
    'crewId': crewId,
    'seasonPoints': seasonPoints,
    'manifesto': manifesto,
    'originalAvatar': originalAvatar,
    'homeHex': homeHex,
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
    crewId: json['crewId'] as String?,
    seasonPoints: (json['seasonPoints'] as num?)?.toInt() ?? 0,
    manifesto: json['manifesto'] as String?,
    originalAvatar: json['originalAvatar'] as String?,
    homeHex: json['homeHex'] as String?,
    totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0,
    avgPaceMinPerKm: (json['avgPaceMinPerKm'] as num?)?.toDouble(),
    avgCv: (json['avgCv'] as num?)?.toDouble(),
    totalRuns: (json['totalRuns'] as num?)?.toInt() ?? 0,
  );
}
