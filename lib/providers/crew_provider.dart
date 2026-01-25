import 'package:flutter/foundation.dart';
import '../models/crew_model.dart';
import '../models/team.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';

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

  factory CrewMemberInfo.fromRow(Map<String, dynamic> row) {
    return CrewMemberInfo(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Runner',
      avatar: row['avatar'] as String? ?? '🏃',
      flipCount: (row['season_points'] as num?)?.toInt() ?? 0,
      team: Team.values.byName(row['team'] as String? ?? 'red'),
      isRunning: row['is_running'] as bool? ?? false,
    );
  }
}

/// Crew provider for managing crew state.
///
/// Connects to Supabase for real-time crew data.
/// Falls back to mock data if Supabase operations fail (MVP/offline mode).
class CrewProvider with ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();

  CrewModel? _myCrew;
  List<CrewMemberInfo> _myCrewMembers = [];
  List<CrewModel> _availableCrews = [];
  bool _isLoading = false;
  String? _error;

  // Whether to use mock data (for MVP/testing without real Supabase)
  bool _useMockData = true;

  CrewModel? get myCrew => _myCrew;
  List<CrewMemberInfo> get myCrewMembers => List.unmodifiable(_myCrewMembers);
  List<CrewModel> get availableCrews => List.unmodifiable(_availableCrews);
  bool get isLoading => _isLoading;
  bool get hasCrew => _myCrew != null;
  String? get error => _error;

  void setMyCrew(CrewModel crew) {
    _myCrew = crew;
    notifyListeners();
  }

  void setMyCrewMembers(List<CrewMemberInfo> members) {
    _myCrewMembers = members;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Enable or disable mock data mode
  void setMockMode(bool useMock) {
    _useMockData = useMock;
  }

  /// Create a new crew
  Future<bool> createCrew({
    required String name,
    required Team team,
    required UserModel user,
    String? pin,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_useMockData) {
        await Future.delayed(const Duration(seconds: 1));
        final newCrew = CrewModel(
          id: 'crew_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          team: team,
          memberIds: [user.id],
          pin: pin,
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
      } else {
        final crewData = await _supabase.createCrew(
          name: name,
          team: team.name,
          userId: user.id,
          pin: pin,
        );
        _myCrew = CrewModel.fromRow(crewData);
        _myCrewMembers = [
          CrewMemberInfo(
            id: user.id,
            name: user.name,
            avatar: user.avatar,
            team: user.team,
          ),
        ];
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error creating crew: $e');
      _error = 'Failed to create crew: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Join an existing crew
  ///
  /// [pin] is required if the crew has a PIN set.
  Future<bool> joinCrew({
    required String crewId,
    required UserModel user,
    String? pin,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_useMockData) {
        await Future.delayed(const Duration(seconds: 1));
        final crew = _availableCrews.firstWhere(
          (c) => c.id == crewId,
          orElse: () => throw Exception('Crew not found'),
        );

        // Verify PIN if crew has one
        if (crew.pin != null && crew.pin!.isNotEmpty) {
          if (pin == null || pin != crew.pin) {
            throw Exception('Invalid PIN');
          }
        }

        _myCrew = crew.addMember(user.id);
        _myCrewMembers = [
          ..._generateMockMembers(crew.team, count: crew.memberIds.length),
          CrewMemberInfo(
            id: user.id,
            name: user.name,
            avatar: user.avatar,
            team: user.team,
          ),
        ]..sort((a, b) => b.flipCount.compareTo(a.flipCount));
      } else {
        final crewData = await _supabase.joinCrew(
          crewId: crewId,
          userId: user.id,
          pin: pin,
        );
        _myCrew = CrewModel.fromRow(crewData);

        // Fetch crew members
        final membersData = await _supabase.fetchCrewMembers(crewId);
        _myCrewMembers = membersData.map(CrewMemberInfo.fromRow).toList();
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error joining crew: $e');
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Leave the current crew
  Future<bool> leaveCrew(UserModel user) async {
    if (_myCrew == null) return true;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (!_useMockData) {
        await _supabase.leaveCrew(crewId: _myCrew!.id, userId: user.id);
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _myCrew = null;
      _myCrewMembers = [];

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error leaving crew: $e');
      _error = 'Failed to leave crew: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Fetch available crews for a team
  Future<void> fetchAvailableCrews(Team team) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_useMockData) {
        await Future.delayed(const Duration(milliseconds: 800));
        _availableCrews = _generateMockCrews(team);
      } else {
        final crewsData = await _supabase.fetchCrewsByTeam(team.name);
        _availableCrews = crewsData
            .map((data) => CrewModel.fromRow(data))
            .where((crew) => crew.canAcceptMembers) // Only show joinable crews
            .toList();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching crews: $e');
      _error = 'Failed to load crews';
      // Fall back to mock data on error
      _availableCrews = _generateMockCrews(team);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh crew members (for real-time updates)
  Future<void> refreshCrewMembers() async {
    if (_myCrew == null) return;

    try {
      if (_useMockData) {
        // Mock: just regenerate
        _myCrewMembers = _generateMockMembers(
          _myCrew!.team,
          count: _myCrew!.memberCount,
        );
      } else {
        final membersData = await _supabase.fetchCrewMembers(_myCrew!.id);
        _myCrewMembers = membersData.map(CrewMemberInfo.fromRow).toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing crew members: $e');
    }
  }

  /// Load user's current crew (if they have one)
  Future<void> loadUserCrew(String crewId) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_useMockData) {
        await Future.delayed(const Duration(milliseconds: 500));
        // Generate mock crew
        _myCrew = CrewModel(
          id: crewId,
          name: '새벽질주단',
          team: Team.red,
          memberIds: List.generate(8, (i) => 'member_$i'),
        );
        _myCrewMembers = _generateMockMembers(_myCrew!.team, count: 8);
      } else {
        final crewData = await _supabase.getCrewById(crewId);
        if (crewData != null) {
          _myCrew = CrewModel.fromRow(crewData);
          final membersData = await _supabase.fetchCrewMembers(crewId);
          _myCrewMembers = membersData.map(CrewMemberInfo.fromRow).toList();
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading crew: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load mock data (for testing/MVP)
  void loadMockData(Team userTeam, {bool hasCrew = true}) {
    _isLoading = true;
    _useMockData = true;
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

  // ---------------------------------------------------------------------------
  // MOCK DATA GENERATORS (for MVP/testing)
  // ---------------------------------------------------------------------------

  List<CrewModel> _generateMockCrews(Team team) {
    return [
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
        pin: '1234', // This crew has a PIN
      ),
      CrewModel(
        id: 'crew_join_3',
        name: team == Team.red ? '강남레드' : '마포블루',
        team: team,
        memberIds: List.generate(11, (i) => 'm$i'),
      ),
    ];
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
        isRunning: i < 3, // First 3 members are "running"
      ),
    )..sort((a, b) => b.flipCount.compareTo(a.flipCount));
  }
}
