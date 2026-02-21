import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/hex_repository.dart';
import '../../data/repositories/leaderboard_repository.dart';
import '../../features/auth/services/auth_service.dart';
import '../services/prefetch_service.dart';
import '../services/supabase_service.dart';
import '../services/sync_retry_service.dart';
import '../services/app_lifecycle_manager.dart';

/// Infrastructure singleton providers for DI + testability.
///
/// These wrap existing singletons so that Riverpod can inject them
/// into Notifiers. The underlying instances are still singletons
/// initialized in main() or via factory constructors.

final supabaseServiceProvider = Provider<SupabaseService>((ref) => SupabaseService());
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final prefetchServiceProvider = Provider<PrefetchService>((ref) => PrefetchService());
final syncRetryServiceProvider = Provider<SyncRetryService>((ref) => SyncRetryService());
final appLifecycleManagerProvider = Provider<AppLifecycleManager>((ref) => AppLifecycleManager());
final hexRepositoryProvider = Provider<HexRepository>((ref) => HexRepository());
final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) => LeaderboardRepository());
