import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/run.dart';
import '../storage/local_storage.dart';
import 'supabase_service.dart';

/// Retries failed "Final Sync" operations for runs stuck in 'pending' status.
///
/// Called on app launch and OnResume to ensure runs eventually sync to server.
/// Uses exponential backoff (30s → 2min → 10min → 1hr → 6hr) with max 10 retries.
/// Runs exceeding max retries are marked 'failed' (dead-lettered).
/// Requires hex_path and buff_multiplier to be stored in SQLite (DB v12+).
class SyncRetryService {
  static final SyncRetryService _instance = SyncRetryService._internal();
  factory SyncRetryService() => _instance;
  SyncRetryService._internal();

  final LocalStorage _localStorage = LocalStorage();
  final SupabaseService _supabaseService = SupabaseService();

  /// Max retries before a run is dead-lettered as 'failed'.
  static const int maxRetries = 10;

  /// Retry all eligible unsynced runs (respecting backoff schedule).
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

    final retryableMaps = await _localStorage.getRetryableRuns();
    if (retryableMaps.isEmpty) {
      debugPrint('SyncRetryService: No retryable runs');
      return 0;
    }

    debugPrint(
      'SyncRetryService: Found ${retryableMaps.length} retryable runs',
    );

    int totalSyncedPoints = 0;

    for (final map in retryableMaps) {
      final runId = map['id'] as String;
      final retryCount = (map['retry_count'] as num?)?.toInt() ?? 0;

      // Dead-letter runs that exceeded max retries
      if (retryCount >= maxRetries) {
        await _localStorage.markRunFailed(runId);
        debugPrint(
          'SyncRetryService: Dead-lettered $runId after $retryCount retries',
        );
        continue;
      }

      try {
        final run = Run.fromMap(map);

        debugPrint(
          'SyncRetryService: Retrying $runId '
          '(attempt ${retryCount + 1}/$maxRetries)',
        );

        // Skip runs with no hex captures (nothing to sync)
        if (run.hexPath.isEmpty) {
          await _localStorage.updateRunSyncStatus(run.id, 'synced');
          debugPrint('SyncRetryService: Marked $runId synced (no hexes)');
          continue;
        }

        final syncResult = await _supabaseService.finalizeRun(run);
        await _localStorage.updateRunSyncStatus(run.id, 'synced');
        // Use server-validated points (may be capped by anti-cheat)
        final serverPoints =
            (syncResult['points_earned'] as num?)?.toInt() ?? run.flipPoints;
        totalSyncedPoints += serverPoints;

        debugPrint(
          'SyncRetryService: Synced $runId '
          '(${run.hexPath.length} hexes, $serverPoints pts '
          '[client=${run.flipPoints}])',
        );
      } catch (e) {
        debugPrint(
          'SyncRetryService: Failed to sync $runId '
          '(attempt ${retryCount + 1}/$maxRetries) - $e',
        );
        await _localStorage.incrementRetryCount(runId);
      }
    }

    debugPrint(
      'SyncRetryService: Completed - synced $totalSyncedPoints points',
    );
    return totalSyncedPoints;
  }

  /// Get count of permanently failed (dead-lettered) runs.
  ///
  /// UI can use this to show a notification badge.
  Future<int> getFailedSyncCount() async {
    return _localStorage.getFailedRunCount(maxRetries: maxRetries);
  }
}
