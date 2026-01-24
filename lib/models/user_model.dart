import 'team.dart';

class UserModel {
  final String id;
  final String name;
  final Team team;
  final String avatar;
  final String? crewId;
  final int seasonPoints;
  final String? manifesto;

  const UserModel({
    required this.id,
    required this.name,
    required this.team,
    this.avatar = '🏃',
    this.crewId,
    this.seasonPoints = 0,
    this.manifesto,
  });

  bool get isPurple => team == Team.purple;

  UserModel copyWith({
    String? name,
    Team? team,
    String? crewId,
    String? avatar,
    int? seasonPoints,
    String? manifesto,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      team: team ?? this.team,
      crewId: crewId ?? this.crewId,
      avatar: avatar ?? this.avatar,
      seasonPoints: seasonPoints ?? this.seasonPoints,
      manifesto: manifesto ?? this.manifesto,
    );
  }

  UserModel defectToPurple() => UserModel(
    id: id,
    name: name,
    team: Team.purple,
    crewId: null,
    avatar: avatar,
    seasonPoints: 0,
    manifesto: manifesto,
  );

  factory UserModel.fromRow(Map<String, dynamic> row) => UserModel(
    id: row['id'] as String,
    name: row['name'] as String,
    team: Team.values.byName(row['team'] as String),
    avatar: row['avatar'] as String? ?? '🏃',
    crewId: row['crew_id'] as String?,
    seasonPoints: (row['season_points'] as num?)?.toInt() ?? 0,
    manifesto: row['manifesto'] as String?,
  );

  Map<String, dynamic> toRow() => {
    'name': name,
    'team': team.name,
    'avatar': avatar,
    'crew_id': crewId,
    'season_points': seasonPoints,
    'manifesto': manifesto,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'team': team.name,
    'avatar': avatar,
    'crewId': crewId,
    'seasonPoints': seasonPoints,
    'manifesto': manifesto,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    name: json['name'] as String,
    team: Team.values.byName(json['team'] as String),
    avatar: json['avatar'] as String? ?? '🏃',
    crewId: json['crewId'] as String?,
    seasonPoints: (json['seasonPoints'] as num?)?.toInt() ?? 0,
    manifesto: json['manifesto'] as String?,
  );
}
