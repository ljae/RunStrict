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

  /// Home hex (FIRST hex of last run) - used for self's leaderboard scope
  final String? homeHexStart;

  /// Home hex (LAST hex of last run) - used for others' leaderboard scope
  final String? homeHexEnd;

  const UserModel({
    required this.id,
    required this.name,
    required this.team,
    this.avatar = '🏃',
    this.crewId,
    this.seasonPoints = 0,
    this.manifesto,
    this.originalAvatar,
    this.homeHexStart,
    this.homeHexEnd,
  });

  bool get isPurple => team == Team.purple;

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
    String? homeHexStart,
    String? homeHexEnd,
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
      homeHexStart: homeHexStart ?? this.homeHexStart,
      homeHexEnd: homeHexEnd ?? this.homeHexEnd,
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
      homeHexStart: homeHexStart,
      homeHexEnd: homeHexEnd,
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
    homeHexStart: row['home_hex_start'] as String?,
    homeHexEnd: row['home_hex_end'] as String?,
  );

  Map<String, dynamic> toRow() => {
    'name': name,
    'team': team.name,
    'avatar': avatar,
    'crew_id': crewId,
    'season_points': seasonPoints,
    'manifesto': manifesto,
    'original_avatar': originalAvatar,
    'home_hex_start': homeHexStart,
    'home_hex_end': homeHexEnd,
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
    'homeHexStart': homeHexStart,
    'homeHexEnd': homeHexEnd,
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
    homeHexStart: json['homeHexStart'] as String?,
    homeHexEnd: json['homeHexEnd'] as String?,
  );
}
