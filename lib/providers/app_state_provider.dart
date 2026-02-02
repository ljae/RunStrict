import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_model.dart';
import '../models/team.dart';
import '../services/auth_service.dart';

class AppStateProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  static const String _userFileName = 'local_user.json';

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasUser => _currentUser != null;
  bool get isInitialized => _isInitialized;
  Team? get userTeam => _currentUser?.team;

  /// Whether current user is linked to Supabase auth
  bool get isLinkedToAuth => _authService.isAuthenticated;

  // Territory balance
  double _redPercentage = 48.0;
  double _bluePercentage = 52.0;

  double get redPercentage => _redPercentage;
  double get bluePercentage => _bluePercentage;

  // --- Local User Persistence ---

  Future<File> get _localUserFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_userFileName');
  }

  Future<void> _saveLocalUser() async {
    if (_currentUser == null) return;
    try {
      final file = await _localUserFile;
      await file.writeAsString(jsonEncode(_currentUser!.toJson()));
      debugPrint('AppStateProvider: Local user saved');
    } catch (e) {
      debugPrint('AppStateProvider: Failed to save local user - $e');
    }
  }

  Future<UserModel?> _loadLocalUser() async {
    try {
      final file = await _localUserFile;
      if (!await file.exists()) return null;
      final contents = await file.readAsString();
      return UserModel.fromJson(jsonDecode(contents));
    } catch (e) {
      debugPrint('AppStateProvider: Failed to load local user - $e');
      return null;
    }
  }

  Future<void> _deleteLocalUser() async {
    try {
      final file = await _localUserFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('AppStateProvider: Failed to delete local user - $e');
    }
  }

  /// Initialize app state - try to restore previous session
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      // First try Supabase session (for linked accounts)
      final authUser = await _authService.restoreSession();
      if (authUser != null) {
        _currentUser = authUser;
        debugPrint(
          'AppStateProvider: Auth session restored for ${authUser.name}',
        );
      } else {
        // Fall back to local user (for unlinked accounts)
        final localUser = await _loadLocalUser();
        if (localUser != null) {
          _currentUser = localUser;
          debugPrint(
            'AppStateProvider: Local user restored for ${localUser.name}',
          );
        }
      }
      _error = null;
    } catch (e) {
      debugPrint('AppStateProvider: Failed to restore session - $e');
      _error = null; // Don't show error for failed restore
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  void setUser(UserModel user) {
    _currentUser = user;
    _error = null;
    notifyListeners();
  }

  /// Sign up new user with email/password (for future use)
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required Team team,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.signUp(
        email: email,
        password: password,
        username: username,
        team: team,
      );
      _currentUser = user;
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

  /// Sign in existing user with email/password (for future use)
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.signIn(email: email, password: password);
      _currentUser = user;
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

  /// Quick onboarding - creates local user (no auth required for MVP)
  ///
  /// User can optionally link email later to persist across devices.
  Future<void> selectTeam(Team team, String username) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Create local-only user for MVP (no Supabase auth required)
      // User ID is a UUID that will be used if they later sign up
      final localId = DateTime.now().millisecondsSinceEpoch.toString();
      _currentUser = UserModel(
        id: localId,
        name: username,
        team: team,
        seasonPoints: 0,
      );

      // Persist locally
      await _saveLocalUser();

      _error = null;
      debugPrint('AppStateProvider: Local user created - $localId');
    } catch (e) {
      _error = e.toString();
      debugPrint('AppStateProvider: Failed to create local user - $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Link email/password to current local account (converts to permanent)
  ///
  /// This creates a Supabase auth account and syncs the user profile.
  Future<void> linkEmailToAccount({
    required String email,
    required String password,
  }) async {
    if (_currentUser == null) {
      throw StateError('No user to link');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.signUp(
        email: email,
        password: password,
        username: _currentUser!.name,
        team: _currentUser!.team,
      );

      // Update local user with server ID
      _currentUser = user.copyWith(seasonPoints: _currentUser!.seasonPoints);
      _error = null;
      debugPrint('AppStateProvider: Account linked - ${user.id}');
    } catch (e) {
      _error = e.toString();
      debugPrint('AppStateProvider: Failed to link account - $e');
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

  /// Update user's season points
  void updateSeasonPoints(int additionalPoints) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        seasonPoints: _currentUser!.seasonPoints + additionalPoints,
      );
      _saveLocalUser(); // Persist change
      notifyListeners();
    }
  }

  /// Join Purple Team (The Traitor's Gate)
  /// Points are PRESERVED on defection.
  void defectToPurple() {
    if (_currentUser != null && _currentUser!.team != Team.purple) {
      _currentUser = _currentUser!.defectToPurple();
      notifyListeners();
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

  /// Sign out current user
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Sign out from Supabase if linked
      if (_authService.isAuthenticated) {
        await _authService.signOut();
      }

      // Delete local user file
      await _deleteLocalUser();

      _currentUser = null;
      _error = null;
    } catch (e) {
      debugPrint('AppStateProvider: Sign out failed - $e');
      // Still clear local state even if remote fails
      _currentUser = null;
      _error = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh user profile from server
  Future<void> refreshUserProfile() async {
    if (_currentUser == null) return;

    try {
      final user = await _authService.fetchUserProfile(_currentUser!.id);
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AppStateProvider: Failed to refresh profile - $e');
    }
  }

  /// Update user profile on server
  Future<void> saveUserProfile() async {
    if (_currentUser == null) return;

    try {
      await _authService.updateUserProfile(_currentUser!);
    } catch (e) {
      debugPrint('AppStateProvider: Failed to save profile - $e');
      rethrow;
    }
  }
}
