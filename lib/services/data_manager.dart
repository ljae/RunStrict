import 'package:flutter/foundation.dart';
import '../models/run_summary.dart';
import '../models/route_point.dart';
import '../models/daily_running_stat.dart';

/// Centralized data manager for Hot/Cold data separation.
///
/// HOT DATA (Season-scoped):
/// - Hex colors, season points, crew memberships
/// - Reset on D-Day
///
/// COLD DATA (Permanent):
/// - Run summaries, daily stats, archived routes
/// - Never deleted
///
/// This service handles:
/// - Pagination for history queries
/// - Lazy loading for route data
/// - Season reset protocol
/// - Memory-efficient caching
abstract class DataManager {
  /// Initialize data manager
  Future<void> initialize();

  /// Close connections
  Future<void> close();

  // ============ RUN HISTORY (COLD) ============

  /// Save completed run summary (without route)
  Future<void> saveRunSummary(RunSummary summary);

  /// Get paginated run history
  /// [limit] - max items per page
  /// [offset] - skip this many items
  Future<List<RunSummary>> getRunHistory({int limit = 20, int offset = 0});

  /// Get run count (for pagination UI)
  Future<int> getRunCount();

  /// Get runs for a specific date range
  Future<List<RunSummary>> getRunsInRange(DateTime start, DateTime end);

  // ============ ROUTE ARCHIVE (COLD) ============

  /// Save route to cold storage (called after run completes)
  Future<void> saveRoute(String runId, CompressedRoute route);

  /// Load route on-demand (lazy loading for detail view)
  Future<CompressedRoute?> loadRoute(String runId);

  /// Check if route exists
  Future<bool> hasRoute(String runId);

  // ============ DAILY STATS (WARM) ============

  /// Update daily stats after a run
  Future<void> updateDailyStat(DailyRunningStat stat);

  /// Get daily stats for a date range
  Future<List<DailyRunningStat>> getDailyStats({
    required DateTime start,
    required DateTime end,
  });

  /// Get aggregated stats for current season
  Future<SeasonAggregate> getSeasonAggregate(DateTime seasonStart);

  // ============ SEASON MANAGEMENT ============

  /// Reset season data (D-Day protocol)
  /// Archives current season data before clearing
  Future<void> resetSeason({
    required String seasonId,
    required DateTime newSeasonStart,
  });

  /// Archive current hex data before reset
  Future<void> archiveHexData(String seasonId);

  /// Clear all hex colors (The Void)
  Future<void> clearHexData();
}

/// Aggregated stats for a season
class SeasonAggregate {
  final double totalDistanceKm;
  final int totalDurationSeconds;
  final int totalFlipCount;
  final int totalRuns;
  final double avgPaceSecPerKm;

  const SeasonAggregate({
    this.totalDistanceKm = 0,
    this.totalDurationSeconds = 0,
    this.totalFlipCount = 0,
    this.totalRuns = 0,
    this.avgPaceSecPerKm = 0,
  });

  factory SeasonAggregate.fromDailyStats(List<DailyRunningStat> stats) {
    if (stats.isEmpty) return const SeasonAggregate();

    double totalDist = 0;
    int totalDur = 0;
    int totalFlips = 0;

    for (final stat in stats) {
      totalDist += stat.totalDistanceKm;
      totalDur += stat.totalDurationSeconds;
      totalFlips += stat.flipCount;
    }

    final avgPace = totalDist > 0 ? totalDur / totalDist : 0;

    return SeasonAggregate(
      totalDistanceKm: totalDist,
      totalDurationSeconds: totalDur,
      totalFlipCount: totalFlips,
      totalRuns: stats.length,
      avgPaceSecPerKm: avgPace.toDouble(),
    );
  }
}

/// In-memory implementation for MVP/testing
class InMemoryDataManager implements DataManager {
  final List<RunSummary> _runSummaries = [];
  final Map<String, CompressedRoute> _routes = {};
  final Map<String, DailyRunningStat> _dailyStats = {};
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    _initialized = true;
    debugPrint('DataManager: Initialized (in-memory)');
  }

  @override
  Future<void> close() async {
    _initialized = false;
  }

  @override
  Future<void> saveRunSummary(RunSummary summary) async {
    _checkInitialized();
    // Insert at beginning (newest first)
    _runSummaries.insert(0, summary);
    debugPrint('DataManager: Saved run summary ${summary.id}');
  }

  @override
  Future<List<RunSummary>> getRunHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    _checkInitialized();
    if (offset >= _runSummaries.length) return [];
    final end = (offset + limit).clamp(0, _runSummaries.length);
    return _runSummaries.sublist(offset, end);
  }

  @override
  Future<int> getRunCount() async {
    _checkInitialized();
    return _runSummaries.length;
  }

  @override
  Future<List<RunSummary>> getRunsInRange(DateTime start, DateTime end) async {
    _checkInitialized();
    return _runSummaries
        .where(
          (r) =>
              r.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
              r.date.isBefore(end.add(const Duration(seconds: 1))),
        )
        .toList();
  }

  @override
  Future<void> saveRoute(String runId, CompressedRoute route) async {
    _checkInitialized();
    _routes[runId] = route;
    debugPrint(
      'DataManager: Saved route for $runId (${route.points.length} points, ${route.sizeKb.toStringAsFixed(1)}KB)',
    );
  }

  @override
  Future<CompressedRoute?> loadRoute(String runId) async {
    _checkInitialized();
    return _routes[runId];
  }

  @override
  Future<bool> hasRoute(String runId) async {
    _checkInitialized();
    return _routes.containsKey(runId);
  }

  @override
  Future<void> updateDailyStat(DailyRunningStat stat) async {
    _checkInitialized();
    final key = '${stat.dateKey}_${stat.userId}';
    _dailyStats[key] = stat;
  }

  @override
  Future<List<DailyRunningStat>> getDailyStats({
    required DateTime start,
    required DateTime end,
  }) async {
    _checkInitialized();
    return _dailyStats.values.where((stat) {
      final date = stat.date;
      return date.isAfter(start.subtract(const Duration(days: 1))) &&
          date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  @override
  Future<SeasonAggregate> getSeasonAggregate(DateTime seasonStart) async {
    _checkInitialized();
    final stats = await getDailyStats(start: seasonStart, end: DateTime.now());
    return SeasonAggregate.fromDailyStats(stats);
  }

  @override
  Future<void> resetSeason({
    required String seasonId,
    required DateTime newSeasonStart,
  }) async {
    _checkInitialized();
    debugPrint('DataManager: Resetting season $seasonId');
    // In production: archive to Firestore/S3 before clearing
    await archiveHexData(seasonId);
    await clearHexData();
  }

  @override
  Future<void> archiveHexData(String seasonId) async {
    _checkInitialized();
    debugPrint('DataManager: Archived hex data for season $seasonId');
    // In production: copy hexes/ to seasonArchive/{seasonId}/hexes/
  }

  @override
  Future<void> clearHexData() async {
    _checkInitialized();
    debugPrint('DataManager: Cleared hex data (The Void)');
    // In production: batch delete all documents in hexes/
  }

  void _checkInitialized() {
    if (!_initialized) {
      _initialized = true; // Auto-init for convenience
    }
  }
}
