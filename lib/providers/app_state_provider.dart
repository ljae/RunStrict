import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/team.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';

/// AppStateProvider - Thin wrapper around UserRepository for Provider pattern.
///
/// Delegates user state to UserRepository (single source of truth).
/// Manages UI concerns: loading state, error handling, auth service integration.
class AppStateProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserRepository _userRepository = UserRepository();

  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  /// Current user from UserRepository (single source of truth)
  UserModel? get currentUser => _userRepository.currentUser;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasUser => _userRepository.hasUser;
  bool get isInitialized => _isInitialized;
  Team? get userTeam => _userRepository.userTeam;

  /// Whether current user is linked to Supabase auth
  bool get isLinkedToAuth => _authService.isAuthenticated;

  // Territory balance
  double _redPercentage = 48.0;
  double _bluePercentage = 52.0;

  double get redPercentage => _redPercentage;
  double get bluePercentage => _bluePercentage;

  AppStateProvider() {
    // Listen to UserRepository changes and forward notifications
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

  /// Initialize app state - try to restore previous session
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      // First try Supabase session (for linked accounts)
      final authUser = await _authService.restoreSession();
      if (authUser != null) {
        await _userRepository.setUser(authUser);
        debugPrint(
          'AppStateProvider: Auth session restored for ${authUser.name}',
        );
      } else {
        // Fall back to local user (for unlinked accounts)
        await _userRepository.loadFromDisk();
        if (_userRepository.currentUser != null) {
          debugPrint(
            'AppStateProvider: Local user restored for ${_userRepository.currentUser!.name}',
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
    _userRepository.setUser(user);
    _error = null;
    // notifyListeners() called via _onUserRepositoryChanged
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
      await _userRepository.setUser(user);
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
      await _userRepository.setUser(user);
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
      final localId = const Uuid().v4();
      final user = UserModel(
        id: localId,
        name: username,
        team: team,
        seasonPoints: 0,
      );

      await _userRepository.setUser(user);
      // Persist locally
      await _userRepository.saveToDisk();

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
    if (_userRepository.currentUser == null) {
      throw StateError('No user to link');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.signUp(
        email: email,
        password: password,
        username: _userRepository.currentUser!.name,
        team: _userRepository.currentUser!.team,
      );

      // Update local user with server ID
      await _userRepository.setUser(
        user.copyWith(seasonPoints: _userRepository.seasonPoints),
      );
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
    if (_userRepository.currentUser != null) {
      final newPoints = _userRepository.seasonPoints + additionalPoints;
      _userRepository.updateSeasonPoints(newPoints);
      _userRepository.saveToDisk(); // Persist change
      // notifyListeners() called via _onUserRepositoryChanged
    }
  }

  /// Join Purple Team (The Traitor's Gate)
  /// Points are PRESERVED on defection.
  void defectToPurple() {
    if (_userRepository.currentUser != null &&
        _userRepository.userTeam != Team.purple) {
      _userRepository.defectToPurple();
      // notifyListeners() called via _onUserRepositoryChanged
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
      await _userRepository.deleteFromDisk();

      _userRepository.clear();
      _error = null;
    } catch (e) {
      debugPrint('AppStateProvider: Sign out failed - $e');
      // Still clear local state even if remote fails
      _userRepository.clear();
      _error = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh user profile from server
  Future<void> refreshUserProfile() async {
    if (_userRepository.currentUser == null) return;

    try {
      final user = await _authService.fetchUserProfile(
        _userRepository.currentUser!.id,
      );
      if (user != null) {
        await _userRepository.setUser(user);
        // notifyListeners() called via _onUserRepositoryChanged
      }
    } catch (e) {
      debugPrint('AppStateProvider: Failed to refresh profile - $e');
    }
  }

  /// Update user profile on server
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
