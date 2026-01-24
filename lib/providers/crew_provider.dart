import 'package:flutter/foundation.dart';
import '../models/crew_model.dart';
import '../models/team.dart';
import '../models/user_model.dart';

class CrewMemberInfo {
  final String id;
  final String name;
  final String avatar;
  final int flipCount;
  final Team team;
  final bool isRunning;

  const CrewMemberInfo({
    required this.id,
    required this.name,
    required this.avatar,
    this.flipCount = 0,
    required this.team,
    this.isRunning = false,
  });
}

class CrewProvider with ChangeNotifier {
  CrewModel? _myCrew;
  List<CrewMemberInfo> _myCrewMembers = [];
  List<CrewModel> _availableCrews = [];
  bool _isLoading = false;

  CrewModel? get myCrew => _myCrew;
  List<CrewMemberInfo> get myCrewMembers => List.unmodifiable(_myCrewMembers);
  List<CrewModel> get availableCrews => List.unmodifiable(_availableCrews);
  bool get isLoading => _isLoading;
  bool get hasCrew => _myCrew != null;

  void setMyCrew(CrewModel crew) {
    _myCrew = crew;
    notifyListeners();
  }

  void setMyCrewMembers(List<CrewMemberInfo> members) {
    _myCrewMembers = members;
    notifyListeners();
  }

  Future<void> createCrew(String name, Team team, UserModel user) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    final newCrew = CrewModel(
      id: 'crew_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      team: team,
      memberIds: [user.id],
    );

    _myCrew = newCrew;
    _myCrewMembers = [
      CrewMemberInfo(
        id: user.id,
        name: user.name,
        avatar: user.avatar,
        team: user.team,
      ),
    ];

    _isLoading = false;
    notifyListeners();
  }

  Future<void> joinCrew(String crewId, UserModel user) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    try {
      final crew = _availableCrews.firstWhere((c) => c.id == crewId);
      _myCrew = crew.addMember(user.id);
      final mockMembers = _generateMockMembers(
        crew.team,
        count: crew.memberIds.length,
      );
      _myCrewMembers = [
        ...mockMembers,
        CrewMemberInfo(
          id: user.id,
          name: user.name,
          avatar: user.avatar,
          team: user.team,
        ),
      ]..sort((a, b) => b.flipCount.compareTo(a.flipCount));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error joining crew: $e');
    }
  }

  Future<void> fetchAvailableCrews(Team team) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));

    _availableCrews = [
      CrewModel(
        id: 'crew_join_1',
        name: team == Team.red ? '불꽃러너스' : '파란물결',
        team: team,
        memberIds: List.generate(8, (i) => 'm$i'),
      ),
      CrewModel(
        id: 'crew_join_2',
        name: team == Team.red ? '레드스톰' : '블루오션',
        team: team,
        memberIds: List.generate(5, (i) => 'm$i'),
      ),
      CrewModel(
        id: 'crew_join_3',
        name: team == Team.red ? '강남레드' : '마포블루',
        team: team,
        memberIds: List.generate(11, (i) => 'm$i'),
      ),
    ];

    _isLoading = false;
    notifyListeners();
  }

  void loadMockData(Team userTeam, {bool hasCrew = true}) {
    _isLoading = true;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (hasCrew) {
        _myCrew = CrewModel(
          id: 'crew_${userTeam.name}',
          name: userTeam == Team.red ? '새벽질주단' : '한강러너스',
          team: userTeam,
          memberIds: List.generate(12, (i) => 'member_$i'),
        );
        _myCrewMembers = _generateMockMembers(userTeam);
      } else {
        _myCrew = null;
        fetchAvailableCrews(userTeam);
      }

      _isLoading = false;
      notifyListeners();
    });
  }

  List<CrewMemberInfo> _generateMockMembers(Team team, {int count = 12}) {
    final names = [
      '새벽러너',
      '한강달리미',
      '런닝맨',
      '마라토너',
      '조깅왕',
      '페이스메이커',
      '러닝크루',
      '스피드스타',
      '건강러너',
      '아침조깅',
      '러닝메이트',
      '트랙스타',
      '질주본능',
      '오버페이스',
      '쿨다운',
      '웜업',
    ];
    final avatars = [
      '🏃',
      '🏃‍♀️',
      '🎯',
      '⚡',
      '👟',
      '🎖️',
      '🌟',
      '💨',
      '💪',
      '🌅',
      '🤝',
      '🏆',
      '🔥',
      '💧',
      '⏱️',
      '👣',
    ];

    final safeCount = count.clamp(0, names.length);

    return List.generate(
      safeCount,
      (i) => CrewMemberInfo(
        id: 'member_$i',
        name: names[i],
        avatar: avatars[i],
        flipCount: (5 + i * 2) % 20,
        team: team,
      ),
    )..sort((a, b) => b.flipCount.compareTo(a.flipCount));
  }
}
