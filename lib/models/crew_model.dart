import 'team.dart';
import '../services/remote_config_service.dart';

class CrewModel {
  final String id;
  final String name;
  final Team team;
  final List<String> memberIds;
  final String? pin;
  final String? representativeImage;
  final String? sponsorId;

  CrewModel({
    required this.id,
    required this.name,
    required this.team,
    this.memberIds = const [],
    this.pin,
    this.representativeImage,
    this.sponsorId,
  });

  bool get isPurple => team == Team.purple;
  int get maxMembers => isPurple
      ? RemoteConfigService().config.crewConfig.maxMembersPurple
      : RemoteConfigService().config.crewConfig.maxMembersRegular;
  String get leaderId => memberIds.isNotEmpty ? memberIds[0] : '';
  int get memberCount => memberIds.length;
  bool get canAcceptMembers => memberIds.length < maxMembers;

  CrewModel copyWith({
    String? name,
    List<String>? memberIds,
    String? pin,
    String? representativeImage,
    String? sponsorId,
  }) => CrewModel(
    id: id,
    name: name ?? this.name,
    team: team,
    memberIds: memberIds ?? this.memberIds,
    pin: pin ?? this.pin,
    representativeImage: representativeImage ?? this.representativeImage,
    sponsorId: sponsorId ?? this.sponsorId,
  );

  CrewModel addMember(String userId) {
    if (!canAcceptMembers) return this;
    if (memberIds.contains(userId)) return this;
    return copyWith(memberIds: [...memberIds, userId]);
  }

  CrewModel removeMember(String userId) {
    return copyWith(memberIds: memberIds.where((id) => id != userId).toList());
  }

  factory CrewModel.fromRow(Map<String, dynamic> row) => CrewModel(
    id: row['id'] as String,
    name: row['name'] as String,
    team: Team.values.byName(row['team'] as String),
    memberIds: List<String>.from(row['member_ids'] as List? ?? []),
    pin: row['pin'] as String?,
    representativeImage: row['representative_image'] as String?,
    sponsorId: row['sponsor_id'] as String?,
  );

  Map<String, dynamic> toRow() => {
    'name': name,
    'team': team.name,
    'member_ids': memberIds,
    'pin': pin,
    'representative_image': representativeImage,
    'sponsor_id': sponsorId,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'team': team.name,
    'memberIds': memberIds,
    'pin': pin,
    'representativeImage': representativeImage,
    'sponsorId': sponsorId,
  };

  factory CrewModel.fromJson(Map<String, dynamic> json) => CrewModel(
    id: json['id'] as String,
    name: json['name'] as String,
    team: Team.values.byName(json['team'] as String),
    memberIds: List<String>.from(json['memberIds'] as List? ?? []),
    pin: json['pin'] as String?,
    representativeImage: json['representativeImage'] as String?,
    sponsorId: json['sponsorId'] as String?,
  );
}
