import 'team.dart';

/// User model for RunStrict
///
/// Distance stats (totalDistance, currentSeasonDistance) are calculated
/// on-demand from dailyStats/ collection to avoid data duplication.
class UserModel {
  final String id;
  final String name;
  final Team team;
  final String? crewId;
  final String avatar;
  final int seasonPoints; // Reset to 0 when joining Purple
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.team,
    this.crewId,
    this.avatar = '🏃',
    this.seasonPoints = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Check if user is a Purple Crew member (defector)
  bool get isPurple => team == Team.purple;

  /// Point multiplier based on team
  int get multiplier => team.multiplier;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'team': team.name,
    'crewId': crewId,
    'avatar': avatar,
    'seasonPoints': seasonPoints,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    name: json['name'] as String,
    team: Team.values.byName(json['team'] as String),
    crewId: json['crewId'] as String?,
    avatar: json['avatar'] as String? ?? '🏃',
    seasonPoints: (json['seasonPoints'] as num?)?.toInt() ?? 0,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );

  UserModel copyWith({
    String? name,
    Team? team,
    String? crewId,
    String? avatar,
    int? seasonPoints,
  }) => UserModel(
    id: id,
    name: name ?? this.name,
    team: team ?? this.team,
    crewId: crewId ?? this.crewId,
    avatar: avatar ?? this.avatar,
    seasonPoints: seasonPoints ?? this.seasonPoints,
    createdAt: createdAt,
  );

  /// Create a copy with Purple team and reset season points
  /// Used when user joins Purple Crew (The Traitor's Gate)
  UserModel defectToPurple() => UserModel(
    id: id,
    name: name,
    team: Team.purple,
    crewId: null, // Leave current crew
    avatar: avatar,
    seasonPoints: 0, // Reset to 0 (The Cost)
    createdAt: createdAt,
  );
}
