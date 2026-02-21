import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../features/auth/providers/app_init_provider.dart';
import '../features/auth/providers/app_state_provider.dart';
import '../core/providers/user_repository_provider.dart';
import 'home_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/auth/screens/season_register_screen.dart';
import '../features/auth/screens/team_selection_screen.dart';
import '../features/team/screens/traitor_gate_screen.dart';
import '../theme/app_theme.dart';

/// A [Listenable] that notifies when any of the watched providers change.
/// Used by GoRouter's refreshListenable to re-evaluate redirects without
/// recreating the entire router (which would tear down all screen state).
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    // Listen to auth-relevant providers and notify GoRouter to re-evaluate redirect
    ref.listen(appStateProvider, (_, __) => notifyListeners());
    ref.listen(appInitProvider, (_, __) => notifyListeners());
    ref.listen(userRepositoryProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  ref.onDispose(() => refreshNotifier.dispose());

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final appState = ref.read(appStateProvider);
      final initState = ref.read(appInitProvider);
      final user = ref.read(userRepositoryProvider);
      final path = state.uri.path;

      // While initializing, stay on splash
      if (!appState.isInitialized) {
        return path == '/' ? null : '/';
      }

      // Guest mode: wait for location init, then allow /home
      if (appState.isGuest) {
        // Stay on splash while guest prefetch is in progress
        if (initState.isPrefetching) {
          return path == '/' ? null : '/';
        }
        if (path == '/' || path == '/login') return '/home';
        if (path == '/profile-register' || path == '/season-register') {
          return '/home';
        }
        return null;
      }

      // Prefetching state (authenticated with user, prefetch in progress)
      if (appState.isAuthenticated && user != null && initState.isPrefetching) {
        return path == '/' ? null : '/';
      }

      // Prefetch error state
      if (appState.isAuthenticated &&
          user != null &&
          initState.prefetchError != null) {
        return path == '/' ? null : '/';
      }

      // Not authenticated -> login
      if (!appState.isAuthenticated) {
        return path == '/login' ? null : '/login';
      }

      // No profile -> register
      if (!appState.hasProfile) {
        return path == '/profile-register' ? null : '/profile-register';
      }

      // No team -> season register
      if (!appState.hasTeamSelected) {
        return path == '/season-register' ? null : '/season-register';
      }

      // Fully onboarded but still on auth screens -> home
      if (path == '/' ||
          path == '/login' ||
          path == '/profile-register' ||
          path == '/season-register') {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/profile-register',
        builder: (context, state) => const ProfileScreen(isRegistration: true),
      ),
      GoRoute(
        path: '/season-register',
        builder: (context, state) => const SeasonRegisterScreen(),
      ),
      GoRoute(
        path: '/team-selection',
        builder: (context, state) => const TeamSelectionScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/traitor-gate',
        builder: (context, state) => const TraitorGateScreen(),
      ),
    ],
  );
});

/// Splash screen that triggers initialization and shows loading/error states.
/// Replaces the old _AppInitializer widget from main.dart.
class _SplashScreen extends HookConsumerWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initState = ref.watch(appInitProvider);

    // Trigger initialization once
    useEffect(() {
      Future.microtask(() {
        ref.read(appInitProvider.notifier).initialize();
      });
      return null;
    }, const []);

    // Show error screen if prefetch failed
    if (initState.prefetchError != null) {
      return _buildErrorScreen(context, ref, initState.prefetchError!);
    }

    // Default: loading
    final message =
        initState.isPrefetching ? 'Getting your location...' : 'Initializing...';
    return _buildLoadingScreen(message);
  }

  Widget _buildLoadingScreen(String message) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'RUN',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.electricBlue),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(
    BuildContext context,
    WidgetRef ref,
    String error,
  ) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'RUN',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 32),
              Icon(
                Icons.location_off,
                size: 48,
                color: AppTheme.athleticRed.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'Location Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'RunStrict needs your location to show nearby runners and territories.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ref.read(appInitProvider.notifier).initializePrefetch();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.electricBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Try Again'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  ref.read(appInitProvider.notifier).clearPrefetchError();
                },
                child: Text(
                  'Continue without location',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
