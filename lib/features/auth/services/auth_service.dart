import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/team.dart';
import '../../../data/models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentAuthUser => _client.auth.currentUser;
  bool get isAuthenticated => currentAuthUser != null;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

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
    final completer = Completer<String>();
    late final StreamSubscription<AuthState> sub;

    sub = _client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn &&
          data.session?.user != null) {
        sub.cancel();
        if (!completer.isCompleted) {
          completer.complete(data.session!.user.id);
        }
      }
    });

    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.neondialactic.neonRunner://login-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );

    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        sub.cancel();
        throw AuthException('Google Sign-In timed out');
      },
    );
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

    // Retry insert to handle OAuth auth.users propagation delay.
    // The FK constraint (users.id → auth.users.id) can fail if the
    // auth row hasn't fully propagated when the signedIn event fires.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _client.from('users').insert(row);
        break;
      } on PostgrestException catch (e) {
        if (e.code == '23503' && attempt < 2) {
          debugPrint('AuthService: FK not ready, retrying (${attempt + 1}/3)');
          await Future.delayed(Duration(seconds: attempt + 1));
          continue;
        }
        rethrow;
      }
    }

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
