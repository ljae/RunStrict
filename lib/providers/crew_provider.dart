import 'package:flutter/foundation.dart';
import '../models/crew_model.dart';
import '../models/team.dart';
import '../models/user_model.dart';

/// Provider for crew management
///
/// Stats (weeklyDistance, hexesClaimed, wins, losses) are calculated
/// on-demand from runs/ and dailyStats/ collections - not stored locally.
class CrewProvider with ChangeNotifier {
  CrewModel? _myCrew;
  List<CrewMember> _myCrewMembers = [];
  List<CrewModel> _availableCrews = [];
  bool _isLoading = false;

  CrewModel? get myCrew => _myCrew;
  List<CrewMember> get myCrewMembers => List.unmodifiable(_myCrewMembers);
  List<CrewModel> get availableCrews => List.unmodifiable(_availableCrews);
  bool get isLoading => _isLoading;
  bool get hasCrew => _myCrew != null;

  void setMyCrew(CrewModel crew) {
    _myCrew = crew;
    notifyListeners();
  }

  void setMyCrewMembers(List<CrewMember> members) {
    _myCrewMembers = members;
    notifyListeners();
  }

  Future<void> createCrew(String name, Team team, UserModel user) async {
    _isLoading = true;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    final newCrew = CrewModel(
      id: 'crew_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      team: team,
      memberIds: [user.id],
      createdAt: DateTime.now(),
    );

    _myCrew = newCrew;
    _myCrewMembers = [
      CrewMember(
        id: user.id,
        name: user.name,
        avatar: user.avatar,
        distance: 0, // Calculated from dailyStats on-demand
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

      // Update crew with new member
      _myCrew = crew.addMember(user.id);

      // In a real app, we'd fetch actual members with their stats
      final mockMembers = _generateMockMembers(
        crew.team,
        count: crew.memberIds.length,
      );
      _myCrewMembers = [
        ...mockMembers,
        CrewMember(
          id: user.id,
          name: user.name,
          avatar: user.avatar,
          distance: 0, // Calculated from dailyStats on-demand
          team: user.team,
        ),
      ]..sort((a, b) => b.distance.compareTo(a.distance));

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

  // Mock data for demonstration
  void loadMockData(Team userTeam, {bool hasCrew = true}) {
    _isLoading = true;
    notifyListeners();

    // Simulate loading delay
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
        fetchAvailableCrews(userTeam); // Load suggestions
      }

      _isLoading = false;
      notifyListeners();
    });
  }

  List<CrewMember> _generateMockMembers(Team team, {int count = 12}) {
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

    // Ensure we don't go out of bounds
    final safeCount = count.clamp(0, names.length);

    return List.generate(
      safeCount,
      (i) => CrewMember(
        id: 'member_$i',
        name: names[i],
        avatar: avatars[i],
        distance: (10 + (i * 2.5)) % 50, // Pseudo-random distance
        flipCount: (5 + i * 2) % 20, // Mock flip count
        team: team,
      ),
    )..sort((a, b) => b.flipCount.compareTo(a.flipCount)); // Sort by flip count
  }
}
