import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/team.dart';
import '../services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/purchases_service.dart';
import '../../../core/storage/local_storage.dart' as app_storage;
import '../../../core/providers/user_repository_provider.dart';
import '../../../core/providers/pro_provider.dart';
import 'app_init_provider.dart';

class AppState {
  final bool isInitialized;
  final bool isLoading;
  final bool isGuest;
  final String? error;
  final String? authUserId;
  final bool hasProfile;
  final bool hasTeamSelected;
  final double redPercentage;
  final double bluePercentage;

  const AppState({
    this.isInitialized = false,
    this.isLoading = false,
    this.isGuest = false,
    this.error,
    this.authUserId,
    this.hasProfile = false,
    this.hasTeamSelected = false,
    this.redPercentage = 48.0,
    this.bluePercentage = 52.0,
  });

  bool get isAuthenticated => authUserId != null;

  AppState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isGuest,
    String? Function()? error,
    String? Function()? authUserId,
    bool? hasProfile,
    bool? hasTeamSelected,
    double? redPercentage,
    double? bluePercentage,
  }) {
    return AppState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isGuest: isGuest ?? this.isGuest,
      error: error != null ? error() : this.error,
      authUserId: authUserId != null ? authUserId() : this.authUserId,
      hasProfile: hasProfile ?? this.hasProfile,
      hasTeamSelected: hasTeamSelected ?? this.hasTeamSelected,
      redPercentage: redPercentage ?? this.redPercentage,
      bluePercentage: bluePercentage ?? this.bluePercentage,
    );
  }
}

class AppStateNotifier extends Notifier<AppState> {
  final AuthService _authService = AuthService();

  @override
  AppState build() => const AppState();

  // Derived getters via UserRepository
  UserModel? get currentUser => ref.read(userRepositoryProvider);
  bool get hasUser => ref.read(userRepositoryProvider) != null;
  Team? get userTeam => ref.read(userRepositoryProvider)?.team;

  Future<void> initialize() async {
    if (state.isInitialized) return;

    state = state.copyWith(isLoading: true);

    try {
      final authUser = _authService.currentAuthUser;
      if (authUser != null) {
        final authUserId = authUser.id;
        final hasProfile = await _authService.hasProfile(authUserId);
        if (!hasProfile) {
          // Stale session with no profile row — sign out and start fresh
          debugPrint('AppStateNotifier: Stale session (no profile) — signing out');
          await _authService.signOut();
          await app_storage.LocalStorage().clearAllGuestData();
          state = state.copyWith(
            error: () => null,
            isInitialized: true,
            isLoading: false,
          );
          return;
        }
        bool hasTeamSelected = false;
        hasTeamSelected = await _authService.hasTeamSelected(authUserId);
        final user = await _authService.fetchUserProfile(authUserId);
        if (user != null) {
          await ref.read(userRepositoryProvider.notifier).setUser(user);
        }
        state = state.copyWith(
          authUserId: () => authUserId,
          hasProfile: true,
          hasTeamSelected: hasTeamSelected,
          error: () => null,
          isInitialized: true,
          isLoading: false,
        );

        // Sync RevenueCat identity + pro status
        await PurchasesService().login(authUserId);
        ref.read(proProvider.notifier).setProStatus(PurchasesService().isPro);

        debugPrint(
          'AppStateNotifier: Session restored '
          '(profile=true, team=$hasTeamSelected)',
        );
      } else {
        state = state.copyWith(
          error: () => null,
          isInitialized: true,
          isLoading: false,
        );
      }
    } catch (e) {
      debugPrint('AppStateNotifier: Failed to restore session - $e');
      state = state.copyWith(
        error: () => null,
        isInitialized: true,
        isLoading: false,
      );
    }
  }

  void setUser(UserModel user) {
    ref.read(userRepositoryProvider.notifier).setUser(user);
    state = state.copyWith(error: () => null);
  }

  // ── Guest Mode ─────────────────────────────────────────────

  /// Extract email ID prefix from SNS-authenticated user's email.
  /// e.g. "john.doe@gmail.com" → "john.doe"
  String? get snsEmailPrefix {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null || !email.contains('@')) return null;
    return email.split('@').first;
  }

  /// Enter guest mode (anonymous, local-only, one-day pass).
  /// Creates a local-only UserModel with the chosen team.
  void joinAsGuest(Team team) {
    final guestUser = UserModel(
      id: 'guest',
      name: 'Guest',
      team: team,
      sex: 'other',
      birthday: DateTime(2000, 1, 1),
    );
    ref.read(userRepositoryProvider.notifier).setUser(guestUser);

    state = state.copyWith(
      isGuest: true,
      isInitialized: true,
      isLoading: false,
      error: () => null,
    );
    debugPrint('AppStateNotifier: Joined as guest (team=${team.displayName})');
  }

  /// End guest session — resets state to trigger redirect to /login.
  void endGuestSession() {
    state = const AppState();
    debugPrint('AppStateNotifier: Guest session ended');
  }

  // ── Auth Methods ────────────────────────────────────────────

  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final authUserId = await _authService.signInWithApple();
      final hasProfile = await _authService.hasProfile(authUserId);
      bool hasTeamSelected = false;
      if (hasProfile) {
        hasTeamSelected = await _authService.hasTeamSelected(authUserId);
        final user = await _authService.fetchUserProfile(authUserId);
        if (user != null) {
          await ref.read(userRepositoryProvider.notifier).setUser(user);
        }
      }
      state = state.copyWith(
        authUserId: () => authUserId,
        hasProfile: hasProfile,
        hasTeamSelected: hasTeamSelected,
        error: () => null,
        isLoading: false,
      );

      // Sync RevenueCat identity + pro status
      await PurchasesService().login(authUserId);
      ref.read(proProvider.notifier).setProStatus(PurchasesService().isPro);
    } catch (e) {
      state = state.copyWith(error: () => e.toString(), isLoading: false);
      debugPrint('AppStateNotifier: Apple sign in failed - $e');
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final authUserId = await _authService.signInWithGoogle();
      final hasProfile = await _authService.hasProfile(authUserId);
      bool hasTeamSelected = false;
      if (hasProfile) {
        hasTeamSelected = await _authService.hasTeamSelected(authUserId);
        final user = await _authService.fetchUserProfile(authUserId);
        if (user != null) {
          await ref.read(userRepositoryProvider.notifier).setUser(user);
        }
      }
      state = state.copyWith(
        authUserId: () => authUserId,
        hasProfile: hasProfile,
        hasTeamSelected: hasTeamSelected,
        error: () => null,
        isLoading: false,
      );

      // Sync RevenueCat identity + pro status
      await PurchasesService().login(authUserId);
      ref.read(proProvider.notifier).setProStatus(PurchasesService().isPro);
    } catch (e) {
      state = state.copyWith(error: () => e.toString(), isLoading: false);
      debugPrint('AppStateNotifier: Google sign in failed - $e');
      rethrow;
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
    if (state.authUserId == null) {
      throw StateError('Must authenticate before creating profile');
    }

    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final user = await _authService.createUserProfile(
        userId: state.authUserId!,
        username: username,
        sex: sex,
        birthday: birthday,
        nationality: nationality,
        manifesto: manifesto,
      );
      final userRepo = ref.read(userRepositoryProvider.notifier);
      await userRepo.setUser(user);
      await userRepo.saveToDisk();
      state = state.copyWith(
        hasProfile: true,
        error: () => null,
        isLoading: false,
      );
      debugPrint('AppStateNotifier: Profile created - ${state.authUserId}');
    } catch (e) {
      state = state.copyWith(error: () => e.toString(), isLoading: false);
      debugPrint('AppStateNotifier: Profile creation failed - $e');
      rethrow;
    }
  }

  Future<void> selectTeam(Team team) async {
    if (state.authUserId == null) {
      throw StateError('Must authenticate before selecting team');
    }

    state = state.copyWith(isLoading: true, error: () => null);

    try {
      await _authService.updateTeam(state.authUserId!, team);
      final userRepo = ref.read(userRepositoryProvider.notifier);
      final currentUser = ref.read(userRepositoryProvider);
      final updatedUser = currentUser?.copyWith(team: team);
      if (updatedUser != null) {
        await userRepo.setUser(updatedUser);
        await userRepo.saveToDisk();
      }
      state = state.copyWith(
        hasTeamSelected: true,
        error: () => null,
        isLoading: false,
      );
      debugPrint('AppStateNotifier: Team selected ${team.name} - ${state.authUserId}');

      // Trigger prefetch to set home_hex + district_hex for new users
      ref.read(appInitProvider.notifier).initializePrefetch();
    } catch (e) {
      state = state.copyWith(error: () => e.toString(), isLoading: false);
      debugPrint('AppStateNotifier: Team selection failed - $e');
      rethrow;
    }
  }

  void updateTerritoryBalance(double red, double blue) {
    state = state.copyWith(redPercentage: red, bluePercentage: blue);
  }

  void updateSeasonPoints(int additionalPoints) {
    final userRepo = ref.read(userRepositoryProvider.notifier);
    final currentUser = ref.read(userRepositoryProvider);
    if (currentUser != null) {
      final newPoints = userRepo.seasonPoints + additionalPoints;
      userRepo.updateSeasonPoints(newPoints);
      userRepo.saveToDisk();
    }
  }

  Future<void> defectToPurple() async {
    final currentUser = ref.read(userRepositoryProvider);
    if (currentUser == null || currentUser.team == Team.purple) return;

    final userRepo = ref.read(userRepositoryProvider.notifier);

    // 1. Update in-memory state
    userRepo.defectToPurple();

    // 2. Persist locally (survives app restart)
    await userRepo.saveToDisk();

    // 3. Sync to server
    try {
      await SupabaseService().updateUserTeam(currentUser.id, 'purple');
      debugPrint('AppState: Purple defection synced to server');
    } catch (e) {
      debugPrint('AppState: Purple defection server sync failed: $e');
      // Local save succeeded — server sync will be retried on next app launch
    }
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setError(String? error) {
    state = state.copyWith(error: () => error);
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      await _authService.signOut();
      await PurchasesService().logout();
      ref.read(proProvider.notifier).setProStatus(false);
      await app_storage.LocalStorage().clearAllGuestData();
      final userRepo = ref.read(userRepositoryProvider.notifier);
      await userRepo.deleteFromDisk();
      userRepo.clear();
      state = state.copyWith(
        authUserId: () => null,
        hasProfile: false,
        hasTeamSelected: false,
        error: () => null,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('AppStateNotifier: Sign out failed - $e');
      final userRepo = ref.read(userRepositoryProvider.notifier);
      userRepo.clear();
      state = state.copyWith(
        authUserId: () => null,
        hasProfile: false,
        hasTeamSelected: false,
        error: () => null,
        isLoading: false,
      );
    }
  }

  Future<void> refreshUserProfile() async {
    final currentUser = ref.read(userRepositoryProvider);
    if (currentUser == null) return;

    try {
      final user = await _authService.fetchUserProfile(currentUser.id);
      if (user != null) {
        await ref.read(userRepositoryProvider.notifier).setUser(user);
      }
    } catch (e) {
      debugPrint('AppStateNotifier: Failed to refresh profile - $e');
    }
  }

  Future<void> saveUserProfile() async {
    final currentUser = ref.read(userRepositoryProvider);
    if (currentUser == null) return;

    try {
      await _authService.updateUserProfile(currentUser);
    } catch (e) {
      debugPrint('AppStateNotifier: Failed to save profile - $e');
      rethrow;
    }
  }
}

final appStateProvider = NotifierProvider<AppStateNotifier, AppState>(
  AppStateNotifier.new,
);
