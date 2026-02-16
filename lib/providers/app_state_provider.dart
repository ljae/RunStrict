import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/team.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';

class AppStateProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserRepository _userRepository = UserRepository();

  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  String? _authUserId;
  bool _hasProfile = false;
  bool _hasTeamSelected = false;

  UserModel? get currentUser => _userRepository.currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasUser => _userRepository.hasUser;
  bool get isInitialized => _isInitialized;
  Team? get userTeam => _userRepository.userTeam;

  bool get isAuthenticated => _authUserId != null;
  bool get hasProfile => _hasProfile;
  bool get hasTeamSelected => _hasTeamSelected;
  String? get authUserId => _authUserId;

  double _redPercentage = 48.0;
  double _bluePercentage = 52.0;

  double get redPercentage => _redPercentage;
  double get bluePercentage => _bluePercentage;

  AppStateProvider() {
    _userRepository.addListener(_onUserRepositoryChanged);
  }

  void _onUserRepositoryChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _userRepository.removeListener(_onUserRepositoryChanged);
    super.dispose();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      final authUser = _authService.currentAuthUser;
      if (authUser != null) {
        _authUserId = authUser.id;
        _hasProfile = await _authService.hasProfile(authUser.id);
        if (_hasProfile) {
          _hasTeamSelected = await _authService.hasTeamSelected(authUser.id);
          final user = await _authService.fetchUserProfile(authUser.id);
          if (user != null) {
            await _userRepository.setUser(user);
          }
        }
        debugPrint(
          'AppStateProvider: Session restored '
          '(profile=$_hasProfile, team=$_hasTeamSelected)',
        );
      }
      _error = null;
    } catch (e) {
      debugPrint('AppStateProvider: Failed to restore session - $e');
      _error = null;
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  void setUser(UserModel user) {
    _userRepository.setUser(user);
    _error = null;
  }

  // ── Auth Methods ────────────────────────────────────────────

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _authUserId = await _authService.signUpWithEmail(
        email: email,
        password: password,
      );
      _hasProfile = await _authService.hasProfile(_authUserId!);
      if (_hasProfile) {
        _hasTeamSelected = await _authService.hasTeamSelected(_authUserId!);
        final user = await _authService.fetchUserProfile(_authUserId!);
        if (user != null) {
          await _userRepository.setUser(user);
        }
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('AppStateProvider: Sign up failed - $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _authUserId = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      _hasProfile = await _authService.hasProfile(_authUserId!);
      if (_hasProfile) {
        _hasTeamSelected = await _authService.hasTeamSelected(_authUserId!);
        final user = await _authService.fetchUserProfile(_authUserId!);
        if (user != null) {
          await _userRepository.setUser(user);
        }
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('AppStateProvider: Sign in failed - $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithApple() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _authUserId = await _authService.signInWithApple();
      _hasProfile = await _authService.hasProfile(_authUserId!);
      if (_hasProfile) {
        _hasTeamSelected = await _authService.hasTeamSelected(_authUserId!);
        final user = await _authService.fetchUserProfile(_authUserId!);
        if (user != null) {
          await _userRepository.setUser(user);
        }
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('AppStateProvider: Apple sign in failed - $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _authUserId = await _authService.signInWithGoogle();
      _hasProfile = await _authService.hasProfile(_authUserId!);
      if (_hasProfile) {
        _hasTeamSelected = await _authService.hasTeamSelected(_authUserId!);
        final user = await _authService.fetchUserProfile(_authUserId!);
        if (user != null) {
          await _userRepository.setUser(user);
        }
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('AppStateProvider: Google sign in failed - $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Profile & Team ──────────────────────────────────────────

  Future<void> completeProfileRegistration({
    required String username,
    required String sex,
    required DateTime birthday,
    String? nationality,
    String? manifesto,
  }) async {
    if (_authUserId == null) {
      throw StateError('Must authenticate before creating profile');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.createUserProfile(
        userId: _authUserId!,
        username: username,
        sex: sex,
        birthday: birthday,
        nationality: nationality,
        manifesto: manifesto,
      );
      await _userRepository.setUser(user);
      await _userRepository.saveToDisk();
      _hasProfile = true;
      _error = null;
      debugPrint('AppStateProvider: Profile created - $_authUserId');
    } catch (e) {
      _error = e.toString();
      debugPrint('AppStateProvider: Profile creation failed - $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectTeam(Team team) async {
    if (_authUserId == null) {
      throw StateError('Must authenticate before selecting team');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.updateTeam(_authUserId!, team);
      final updatedUser = _userRepository.currentUser?.copyWith(team: team);
      if (updatedUser != null) {
        await _userRepository.setUser(updatedUser);
        await _userRepository.saveToDisk();
      }
      _hasTeamSelected = true;
      _error = null;
      debugPrint('AppStateProvider: Team selected ${team.name} - $_authUserId');
    } catch (e) {
      _error = e.toString();
      debugPrint('AppStateProvider: Team selection failed - $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateTerritoryBalance(double red, double blue) {
    _redPercentage = red;
    _bluePercentage = blue;
    notifyListeners();
  }

  void updateSeasonPoints(int additionalPoints) {
    if (_userRepository.currentUser != null) {
      final newPoints = _userRepository.seasonPoints + additionalPoints;
      _userRepository.updateSeasonPoints(newPoints);
      _userRepository.saveToDisk();
    }
  }

  void defectToPurple() {
    if (_userRepository.currentUser != null &&
        _userRepository.userTeam != Team.purple) {
      _userRepository.defectToPurple();
    }
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      await _userRepository.deleteFromDisk();
      _userRepository.clear();
      _authUserId = null;
      _hasProfile = false;
      _hasTeamSelected = false;
      _error = null;
    } catch (e) {
      debugPrint('AppStateProvider: Sign out failed - $e');
      _userRepository.clear();
      _authUserId = null;
      _hasProfile = false;
      _hasTeamSelected = false;
      _error = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUserProfile() async {
    if (_userRepository.currentUser == null) return;

    try {
      final user = await _authService.fetchUserProfile(
        _userRepository.currentUser!.id,
      );
      if (user != null) {
        await _userRepository.setUser(user);
      }
    } catch (e) {
      debugPrint('AppStateProvider: Failed to refresh profile - $e');
    }
  }

  Future<void> saveUserProfile() async {
    if (_userRepository.currentUser == null) return;

    try {
      await _authService.updateUserProfile(_userRepository.currentUser!);
    } catch (e) {
      debugPrint('AppStateProvider: Failed to save profile - $e');
      rethrow;
    }
  }
}
