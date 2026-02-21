import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/run.dart';
import '../storage/local_storage.dart';
import 'supabase_service.dart';

/// Retries failed "Final Sync" operations for runs stuck in 'pending' status.
///
/// Called on app launch and OnResume to ensure runs eventually sync to server.
/// Requires hex_path and buff_multiplier to be stored in SQLite (DB v12+).
class SyncRetryService {
  static final SyncRetryService _instance = SyncRetryService._internal();
  factory SyncRetryService() => _instance;
  SyncRetryService._internal();

  final LocalStorage _localStorage = LocalStorage();
  final SupabaseService _supabaseService = SupabaseService();

  /// Retry all unsynced runs.
  ///
  /// Returns the total flip points successfully synced (for PointsService).
  Future<int> retryUnsyncedRuns() async {
    // Check network connectivity first
    final connectivityResults = await Connectivity().checkConnectivity();
    final hasNetwork = !connectivityResults.contains(ConnectivityResult.none);
    if (!hasNetwork) {
      debugPrint('SyncRetryService: No network - skipping retry');
      return 0;
    }

    final unsyncedMaps = await _localStorage.getUnsyncedRuns();
    if (unsyncedMaps.isEmpty) {
      debugPrint('SyncRetryService: No unsynced runs');
      return 0;
    }

    debugPrint(
      'SyncRetryService: Found ${unsyncedMaps.length} unsynced runs',
    );

    int totalSyncedPoints = 0;

    for (final map in unsyncedMaps) {
      try {
        final run = Run.fromMap(map);

        // Skip runs with no hex captures (nothing to sync)
        if (run.hexPath.isEmpty) {
          await _localStorage.updateRunSyncStatus(run.id, 'synced');
          debugPrint('SyncRetryService: Marked ${run.id} synced (no hexes)');
          continue;
        }

        await _supabaseService.finalizeRun(run);
        await _localStorage.updateRunSyncStatus(run.id, 'synced');
        totalSyncedPoints += run.flipPoints;

        debugPrint(
          'SyncRetryService: Synced ${run.id} '
          '(${run.hexPath.length} hexes, ${run.flipPoints} points)',
        );
      } catch (e) {
        debugPrint(
          'SyncRetryService: Failed to sync ${map['id']} - $e',
        );
        // Leave as 'pending' for next retry
      }
    }

    debugPrint(
      'SyncRetryService: Completed - synced $totalSyncedPoints points',
    );
    return totalSyncedPoints;
  }
}
