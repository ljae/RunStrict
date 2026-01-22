import 'team.dart';

/// Crew model for RunStrict
///
/// Stats (weeklyDistance, hexesClaimed, wins, losses) are calculated
/// on-demand from runs/ and dailyStats/ collections.
///
/// Max 12 members per crew. Only Top 4 members split the pool (Winner-Takes-All).
class CrewModel {
  final String id;
  final String name;
  final Team team;
  final List<String> memberIds; // Max 12 (Red/Blue) or 24 (Purple)
  final DateTime createdAt;

  // Max members depends on team type
  int get maxMembers => team == Team.purple ? 24 : 12;
  static const int topWinners = 4;

  CrewModel({
    required this.id,
    required this.name,
    required this.team,
    this.memberIds = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Number of members
  int get memberCount => memberIds.length;

  /// Check if this is a Purple Crew
  bool get isPurple => team == Team.purple;

  /// Point multiplier (Purple: 2x, Red/Blue: 1x)
  int get multiplier => team.multiplier;

  /// Check if crew can accept more members
  bool get canAcceptMembers => memberIds.length < maxMembers;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'team': team.name,
    'memberIds': memberIds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CrewModel.fromJson(Map<String, dynamic> json) => CrewModel(
    id: json['id'] as String,
    name: json['name'] as String,
    team: Team.values.byName(json['team'] as String),
    memberIds: List<String>.from(json['memberIds'] as List? ?? []),
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );

  CrewModel copyWith({
    String? name,
    List<String>? memberIds,
  }) => CrewModel(
    id: id,
    name: name ?? this.name,
    team: team,
    memberIds: memberIds ?? this.memberIds,
    createdAt: createdAt,
  );

  /// Add a member to the crew
  CrewModel addMember(String userId) {
    if (!canAcceptMembers) return this;
    if (memberIds.contains(userId)) return this;
    return copyWith(memberIds: [...memberIds, userId]);
  }

  /// Remove a member from the crew
  CrewModel removeMember(String userId) {
    return copyWith(memberIds: memberIds.where((id) => id != userId).toList());
  }
}

/// Crew member display model
/// Used for UI display with calculated stats
class CrewMember {
  final String id;
  final String name;
  final String avatar;
  final double distance;
  final int flipCount;
  final Team team;

  CrewMember({
    required this.id,
    required this.name,
    required this.avatar,
    required this.distance,
    this.flipCount = 0,
    required this.team,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'distance': distance,
    'flipCount': flipCount,
    'team': team.name,
  };

  factory CrewMember.fromJson(Map<String, dynamic> json) => CrewMember(
    id: json['id'] as String,
    name: json['name'] as String,
    avatar: json['avatar'] as String,
    distance: (json['distance'] as num).toDouble(),
    flipCount: (json['flipCount'] as num?)?.toInt() ?? 0,
    team: Team.values.byName(json['team'] as String),
  );
}
