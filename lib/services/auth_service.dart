import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/auth_config.dart';
import '../models/team.dart';
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentAuthUser => _client.auth.currentUser;
  bool get isAuthenticated => currentAuthUser != null;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Email Auth ──────────────────────────────────────────────

  Future<String> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    // Supabase returns a user object even for duplicate sign-ups,
    // but without a valid session. If session is null, the user
    // already exists — fall back to signIn.
    if (response.session == null) {
      debugPrint(
        'AuthService: No session after signUp, falling back to signIn',
      );
      return signInWithEmail(email: email, password: password);
    }

    final authUser = response.user;
    if (authUser == null) {
      throw AuthException('Sign up failed: No user returned');
    }

    debugPrint('AuthService: Email sign up - ${authUser.id}');
    return authUser.id;
  }

  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final authUser = response.user;
    if (authUser == null) {
      throw AuthException('Sign in failed: No user returned');
    }

    debugPrint('AuthService: Email sign in - ${authUser.id}');
    return authUser.id;
  }

  // ── Social Auth ─────────────────────────────────────────────

  Future<String> signInWithApple() async {
    final rawNonce = _client.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw AuthException('Apple Sign-In failed: No identity token');
    }

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    final authUser = response.user;
    if (authUser == null) {
      throw AuthException('Apple Sign-In failed: No user returned');
    }

    debugPrint('AuthService: Apple sign in - ${authUser.id}');
    return authUser.id;
  }

  Future<String> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      clientId: AuthConfig.googleIosClientId,
      serverClientId: AuthConfig.googleWebClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw AuthException('Google Sign-In cancelled');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw AuthException('Google Sign-In failed: No ID token');
    }

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );

    final authUser = response.user;
    if (authUser == null) {
      throw AuthException('Google Sign-In failed: No user returned');
    }

    debugPrint('AuthService: Google sign in - ${authUser.id}');
    return authUser.id;
  }

  // ── Profile Management ──────────────────────────────────────

  Future<bool> hasProfile(String userId) async {
    final result = await _client
        .from('users')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    return result != null;
  }

  Future<bool> hasTeamSelected(String userId) async {
    final result = await _client
        .from('users')
        .select('team')
        .eq('id', userId)
        .maybeSingle();
    if (result == null) return false;
    return result['team'] != null;
  }

  Future<bool> checkUsernameAvailable(String username) async {
    final result = await _client
        .from('users')
        .select('id')
        .ilike('name', username)
        .maybeSingle();
    return result == null;
  }

  Future<UserModel> createUserProfile({
    required String userId,
    required String username,
    required String sex,
    required DateTime birthday,
    String? nationality,
    String? manifesto,
  }) async {
    final row = <String, dynamic>{
      'id': userId,
      'name': username,
      'sex': sex,
      'birthday': birthday.toIso8601String().substring(0, 10),
      'nationality': nationality,
    };
    if (manifesto != null) row['manifesto'] = manifesto;

    await _client.from('users').insert(row);

    final userModel = UserModel(
      id: userId,
      name: username,
      team: Team.red,
      sex: sex,
      birthday: birthday,
      nationality: nationality,
      manifesto: manifesto,
    );

    debugPrint('AuthService: Profile created - $userId');
    return userModel;
  }

  Future<void> updateTeam(String userId, Team team) async {
    await _client.from('users').update({'team': team.name}).eq('id', userId);
    debugPrint('AuthService: Team updated to ${team.name} - $userId');
  }

  Future<UserModel?> fetchUserProfile(String userId) async {
    final result = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (result == null) return null;
    return UserModel.fromRow(result);
  }

  Future<void> updateUserProfile(UserModel user) async {
    await _client.from('users').update(user.toRow()).eq('id', user.id);
  }

  // ── Session ─────────────────────────────────────────────────

  Future<void> signOut() async {
    await _client.auth.signOut();
    debugPrint('AuthService: User signed out');
  }

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

    final userModel = await fetchUserProfile(authUser.id);
    if (userModel == null) {
      debugPrint('AuthService: Session restored but profile not found');
      return null;
    }

    debugPrint('AuthService: Session restored - ${authUser.id}');
    return userModel;
  }

  Future<void> deleteAccount() async {
    final userId = currentAuthUser?.id;
    if (userId == null) return;

    await _client.from('users').delete().eq('id', userId);
    await signOut();

    debugPrint('AuthService: Account deleted - $userId');
  }
}
