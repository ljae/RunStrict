import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/team.dart';

/// Authentication service for Supabase Auth.
///
/// Handles user registration, sign in, sign out, and session management.
/// Creates corresponding user profile in `users` table on sign up.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  /// Current Supabase auth user (null if not logged in)
  User? get currentAuthUser => _client.auth.currentUser;

  /// Whether user is currently authenticated
  bool get isAuthenticated => currentAuthUser != null;

  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign up a new user with email and password.
  ///
  /// Creates both Supabase Auth user and profile in `users` table.
  /// Returns the created [UserModel] on success.
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String username,
    required Team team,
  }) async {
    // 1. Create auth user
    final authResponse = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final authUser = authResponse.user;
    if (authUser == null) {
      throw AuthException('Sign up failed: No user returned');
    }

    // 2. Create user profile in users table
    final userModel = UserModel(
      id: authUser.id,
      name: username,
      team: team,
      seasonPoints: 0,
    );

    await _client.from('users').insert({
      'id': authUser.id,
      ...userModel.toRow(),
    });

    debugPrint('AuthService: User signed up - ${authUser.id}');
    return userModel;
  }

  /// Sign in existing user with email and password.
  ///
  /// Fetches user profile from `users` table.
  /// Returns [UserModel] on success.
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final authResponse = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final authUser = authResponse.user;
    if (authUser == null) {
      throw AuthException('Sign in failed: No user returned');
    }

    // Fetch user profile
    final userModel = await fetchUserProfile(authUser.id);
    if (userModel == null) {
      throw AuthException('Sign in failed: User profile not found');
    }

    debugPrint('AuthService: User signed in - ${authUser.id}');
    return userModel;
  }

  /// Sign in anonymously (for quick onboarding).
  ///
  /// Creates anonymous auth user and profile in `users` table.
  /// User can later link email/password to convert to permanent account.
  Future<UserModel> signInAnonymously({
    required String username,
    required Team team,
  }) async {
    final authResponse = await _client.auth.signInAnonymously();

    final authUser = authResponse.user;
    if (authUser == null) {
      throw AuthException('Anonymous sign in failed: No user returned');
    }

    // Create user profile
    final userModel = UserModel(
      id: authUser.id,
      name: username,
      team: team,
      seasonPoints: 0,
    );

    await _client.from('users').insert({
      'id': authUser.id,
      ...userModel.toRow(),
    });

    debugPrint('AuthService: Anonymous user created - ${authUser.id}');
    return userModel;
  }

  /// Fetch user profile from `users` table.
  Future<UserModel?> fetchUserProfile(String userId) async {
    final result = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (result == null) return null;
    return UserModel.fromRow(result);
  }

  /// Update user profile in `users` table.
  Future<void> updateUserProfile(UserModel user) async {
    await _client.from('users').update(user.toRow()).eq('id', user.id);
  }

  /// Sign out current user.
  Future<void> signOut() async {
    await _client.auth.signOut();
    debugPrint('AuthService: User signed out');
  }

  /// Try to restore session from stored credentials.
  ///
  /// Returns [UserModel] if session was restored, null otherwise.
  Future<UserModel?> restoreSession() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      debugPrint('AuthService: No session to restore');
      return null;
    }

    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      debugPrint('AuthService: Session exists but no user');
      return null;
    }

    // Fetch user profile
    final userModel = await fetchUserProfile(authUser.id);
    if (userModel == null) {
      debugPrint('AuthService: Session restored but profile not found');
      return null;
    }

    debugPrint('AuthService: Session restored - ${authUser.id}');
    return userModel;
  }

  /// Delete current user account (GDPR compliance).
  ///
  /// This requires server-side Edge Function to delete auth user.
  /// For now, just deletes user profile and signs out.
  Future<void> deleteAccount() async {
    final userId = currentAuthUser?.id;
    if (userId == null) return;

    // Delete user profile
    await _client.from('users').delete().eq('id', userId);

    // Sign out
    await signOut();

    debugPrint('AuthService: Account deleted - $userId');
  }
}
