import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/team.dart';
import '../models/user_model.dart';

/// UserRepository - Single source of truth for user data
///
/// Manages user state with persistence to local_user.json.
/// Plain data holder — notification handled by UserRepositoryNotifier (Riverpod).
///
/// Singleton pattern ensures only one instance exists.
class UserRepository {
  static const String _userFileName = 'local_user.json';

  // Singleton
  static final UserRepository _instance = UserRepository._internal();

  factory UserRepository() => _instance;

  UserRepository._internal();

  UserModel? _currentUser;

  // For testing: override the documents directory
  @visibleForTesting
  static Directory? testDirectory;

  // --- Getters ---

  /// Current user, or null if not initialized
  UserModel? get currentUser => _currentUser;

  /// Whether a user is currently set
  bool get hasUser => _currentUser != null;

  /// Current user's team, or null if no user
  Team? get userTeam => _currentUser?.team;

  /// Current user's season points, or 0 if no user
  int get seasonPoints => _currentUser?.seasonPoints ?? 0;

  // --- Mutations ---

  /// Set the current user
  Future<void> setUser(UserModel user) async {
    _currentUser = user;
  }

  /// Update season points
  void updateSeasonPoints(int points) {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(seasonPoints: points);
  }

  /// Defect to Purple team (Protocol of Chaos)
  /// Points are PRESERVED on defection
  void defectToPurple() {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.defectToPurple();
  }

  /// Clear current user
  void clear() {
    _currentUser = null;
  }

  // --- Persistence ---

  /// Get the local user file path
  Future<File> get _localUserFile async {
    final directory = testDirectory ?? await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_userFileName');
  }

  /// Save current user to disk (local_user.json)
  Future<void> saveToDisk() async {
    if (_currentUser == null) return;
    try {
      final file = await _localUserFile;
      await file.writeAsString(jsonEncode(_currentUser!.toJson()));
      debugPrint('UserRepository: Local user saved');
    } catch (e) {
      debugPrint('UserRepository: Failed to save local user - $e');
    }
  }

  /// Load user from disk (local_user.json)
  /// Returns null if file does not exist
  Future<void> loadFromDisk() async {
    try {
      final file = await _localUserFile;
      if (!await file.exists()) {
        _currentUser = null;
        return;
      }
      final contents = await file.readAsString();
      _currentUser = UserModel.fromJson(jsonDecode(contents));
      debugPrint('UserRepository: Local user loaded');
    } catch (e) {
      debugPrint('UserRepository: Failed to load local user - $e');
      _currentUser = null;
    }
  }

  /// Delete local user file (for logout/season reset)
  Future<void> deleteFromDisk() async {
    try {
      final file = await _localUserFile;
      if (await file.exists()) {
        await file.delete();
        debugPrint('UserRepository: Local user deleted');
      }
    } catch (e) {
      debugPrint('UserRepository: Failed to delete local user - $e');
    }
  }

  // --- Testing ---

  /// Reset singleton for testing purposes
  @visibleForTesting
  static void resetForTesting() {
    _instance._currentUser = null;
    testDirectory = null;
  }

  /// Set test directory for testing purposes
  @visibleForTesting
  static void setTestDirectory(Directory directory) {
    testDirectory = directory;
  }
}
