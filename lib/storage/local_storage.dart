import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/run_session.dart';
import '../models/run_summary.dart';
import '../models/location_point.dart';
import '../models/lap_model.dart';
import '../services/storage_service.dart';

/// SQLite implementation of StorageService for local data persistence
///
/// Stores:
/// - RunSummary in 'runs' table (lightweight, for history)
/// - CompressedRoute in 'routes' table (cold storage, lazy loaded)
/// - LapModel in 'laps' table (per-km lap data for CV calculation)
/// - SyncQueue in 'sync_queue' table (failed syncs for offline retry)
///
/// Note: daily_flips table removed - no daily flip limit per spec.
class LocalStorage implements StorageService {
  static const String _databaseName = 'run_strict.db';
  static const int _databaseVersion = 8; // Bumped for sync_queue table

  static const String _tableRuns = 'runs';
  static const String _tableRoutes = 'routes';
  static const String _tableLaps = 'laps';
  static const String _tableHexCache = 'hex_cache';
  static const String _tableLeaderboardCache = 'leaderboard_cache';
  static const String _tablePrefetchMeta = 'prefetch_meta';
  static const String _tableSyncQueue = 'sync_queue';

  Database? _database;

  @override
  Future<void> initialize() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Runs table (stores RunSummary - lightweight)
    await db.execute('''
      CREATE TABLE $_tableRuns (
        id TEXT PRIMARY KEY,
        startTime INTEGER NOT NULL,
        endTime INTEGER NOT NULL,
        distanceKm REAL NOT NULL,
        durationSeconds INTEGER NOT NULL,
        avgPaceSecPerKm REAL NOT NULL,
        hexesColored INTEGER NOT NULL DEFAULT 0,
        teamAtRun TEXT NOT NULL,
        isPurpleRunner INTEGER NOT NULL DEFAULT 0,
        cv REAL
      )
    ''');

    // Routes table (stores CompressedRoute - cold storage)
    await db.execute('''
      CREATE TABLE $_tableRoutes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        runId TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        timestampMs INTEGER NOT NULL,
        FOREIGN KEY (runId) REFERENCES $_tableRuns (id) ON DELETE CASCADE
      )
    ''');

    // Laps table (stores per-km lap data for CV calculation)
    await db.execute('''
      CREATE TABLE $_tableLaps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        runId TEXT NOT NULL,
        lapNumber INTEGER NOT NULL,
        distanceMeters REAL NOT NULL,
        durationSeconds REAL NOT NULL,
        startTimestampMs INTEGER NOT NULL,
        endTimestampMs INTEGER NOT NULL,
        FOREIGN KEY (runId) REFERENCES $_tableRuns (id) ON DELETE CASCADE
      )
    ''');

    // Index for faster route queries
    await db.execute('''
      CREATE INDEX idx_routes_runId ON $_tableRoutes(runId)
    ''');

    // Index for faster lap queries
    await db.execute('''
      CREATE INDEX idx_laps_runId ON $_tableLaps(runId)
    ''');

    // Hex cache table (prefetched hex colors)
    await db.execute('''
      CREATE TABLE $_tableHexCache (
        hex_id TEXT PRIMARY KEY,
        last_runner_team TEXT,
        last_updated INTEGER
      )
    ''');

    // Leaderboard cache table (prefetched rankings)
    await db.execute('''
      CREATE TABLE $_tableLeaderboardCache (
        user_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        avatar TEXT NOT NULL,
        team TEXT NOT NULL,
        flip_points INTEGER NOT NULL DEFAULT 0,
        total_distance_km REAL NOT NULL DEFAULT 0,
        stability_score INTEGER,
        home_hex TEXT
      )
    ''');

    // Prefetch metadata table (home hex and timestamps)
    await db.execute('''
      CREATE TABLE $_tablePrefetchMeta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Sync queue table (for offline retry of failed "Final Sync" operations)
    await db.execute('''
      CREATE TABLE $_tableSyncQueue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        run_id TEXT NOT NULL UNIQUE,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Index for efficient retry queries
    await db.execute('''
      CREATE INDEX idx_sync_queue_created ON $_tableSyncQueue(created_at ASC)
    ''');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate from v1 to v2: add new columns
      try {
        await db.execute(
          'ALTER TABLE $_tableRuns ADD COLUMN hexesColored INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE $_tableRuns ADD COLUMN teamAtRun TEXT NOT NULL DEFAULT "blue"',
        );
        await db.execute(
          'ALTER TABLE $_tableRuns ADD COLUMN isPurpleRunner INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE $_tableRuns ADD COLUMN durationSeconds INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE $_tableRuns ADD COLUMN avgPaceSecPerKm REAL NOT NULL DEFAULT 0',
        );
      } catch (e) {
        // Columns may already exist
      }
    }
    if (oldVersion < 3) {
      // Migrate from v2 to v3: add pauseCount column
      try {
        await db.execute(
          'ALTER TABLE $_tableRuns ADD COLUMN '
          'pauseCount INTEGER NOT NULL DEFAULT 0',
        );
      } catch (e) {
        // Column may already exist
      }
    }
    if (oldVersion < 5) {
      // Migrate from v4 to v5: drop daily_flips table (no longer needed)
      try {
        await db.execute('DROP TABLE IF EXISTS daily_flips');
        await db.execute('DROP INDEX IF EXISTS idx_daily_flips_user_date');
      } catch (e) {
        // Table may not exist
      }
    }
    if (oldVersion < 6) {
      // Migrate from v5 to v6: add CV column and laps table
      try {
        // Add cv column to runs table
        await db.execute('ALTER TABLE $_tableRuns ADD COLUMN cv REAL');
      } catch (e) {
        // Column may already exist
      }
      try {
        // Create laps table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_tableLaps (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            runId TEXT NOT NULL,
            lapNumber INTEGER NOT NULL,
            distanceMeters REAL NOT NULL,
            durationSeconds REAL NOT NULL,
            startTimestampMs INTEGER NOT NULL,
            endTimestampMs INTEGER NOT NULL,
            FOREIGN KEY (runId) REFERENCES $_tableRuns (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_laps_runId ON $_tableLaps(runId)
        ''');
      } catch (e) {
        // Table may already exist
      }
    }
    if (oldVersion < 7) {
      // Migrate from v6 to v7: add prefetch cache tables
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_tableHexCache (
            hex_id TEXT PRIMARY KEY,
            last_runner_team TEXT,
            last_updated INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_tableLeaderboardCache (
            user_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            avatar TEXT NOT NULL,
            team TEXT NOT NULL,
            flip_points INTEGER NOT NULL DEFAULT 0,
            total_distance_km REAL NOT NULL DEFAULT 0,
            stability_score INTEGER,
            home_hex TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_tablePrefetchMeta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      } catch (e) {
        // Tables may already exist
      }
    }
    if (oldVersion < 8) {
      // Migrate from v7 to v8: add sync_queue table for offline retry
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_tableSyncQueue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            run_id TEXT NOT NULL UNIQUE,
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
          )
        ''');
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_sync_queue_created 
          ON $_tableSyncQueue(created_at ASC)
        ''');
      } catch (e) {
        // Table may already exist
      }
    }
  }

  @override
  Future<void> saveRun(RunSession run) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    // Convert to summary for storage
    final summary = run.toSummary();

    await _database!.transaction((txn) async {
      // Insert run summary
      await txn.insert(
        _tableRuns,
        summary.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Insert route points (cold storage)
      for (final point in run.route) {
        await txn.insert(_tableRoutes, {
          'runId': run.id,
          'lat': point.latitude,
          'lng': point.longitude,
          'timestampMs': point.timestamp.millisecondsSinceEpoch,
        });
      }
    });
  }

  /// Save a completed run with lap data for CV calculation
  ///
  /// Stores run summary (including CV), route points, and individual lap data.
  /// Use this instead of [saveRun] when lap data is available.
  Future<void> saveRunWithLaps(
    RunSession run,
    List<LapModel> laps, {
    double? cv,
  }) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    // Convert to summary and add CV
    final summaryMap = run.toSummary().toMap();
    summaryMap['cv'] = cv;

    await _database!.transaction((txn) async {
      // Insert run summary with CV
      await txn.insert(
        _tableRuns,
        summaryMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Insert route points (cold storage)
      for (final point in run.route) {
        await txn.insert(_tableRoutes, {
          'runId': run.id,
          'lat': point.latitude,
          'lng': point.longitude,
          'timestampMs': point.timestamp.millisecondsSinceEpoch,
        });
      }

      // Insert lap data
      for (final lap in laps) {
        await txn.insert(_tableLaps, {'runId': run.id, ...lap.toMap()});
      }
    });
  }

  /// Get laps for a specific run
  Future<List<LapModel>> getLapsForRun(String runId) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final List<Map<String, dynamic>> lapMaps = await _database!.query(
      _tableLaps,
      where: 'runId = ?',
      whereArgs: [runId],
      orderBy: 'lapNumber ASC',
    );

    return lapMaps.map((map) {
      return LapModel(
        lapNumber: map['lapNumber'] as int,
        distanceMeters: (map['distanceMeters'] as num).toDouble(),
        durationSeconds: (map['durationSeconds'] as num).toDouble(),
        startTimestampMs: map['startTimestampMs'] as int,
        endTimestampMs: map['endTimestampMs'] as int,
      );
    }).toList();
  }

  /// Get run summary by ID (includes CV)
  Future<RunSummary?> getRunSummaryById(String id) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final List<Map<String, dynamic>> runMaps = await _database!.query(
      _tableRuns,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (runMaps.isEmpty) return null;
    return RunSummary.fromMap(runMaps.first);
  }

  @override
  Future<List<RunSession>> getAllRuns() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final List<Map<String, dynamic>> runMaps = await _database!.query(
      _tableRuns,
      orderBy: 'startTime DESC',
    );

    // Return as RunSession for backward compatibility
    // Routes are NOT loaded here (lazy loading)
    // Note: Using endTime as startTime approximation for display purposes
    return runMaps.map((map) {
      final summary = RunSummary.fromMap(map);
      return RunSession(
        id: summary.id,
        startTime: summary.endTime.subtract(
          Duration(seconds: summary.durationSeconds),
        ),
        endTime: summary.endTime,
        distanceMeters: summary.distanceKm * 1000,
        isActive: false,
        teamAtRun: summary.teamAtRun,
        hexesColored: summary.hexesColored,
        cv: summary.cv,
      );
    }).toList();
  }

  @override
  Future<RunSession?> getRunById(String id) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final List<Map<String, dynamic>> runMaps = await _database!.query(
      _tableRuns,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (runMaps.isEmpty) return null;

    final summary = RunSummary.fromMap(runMaps.first);
    final route = await _getRouteForRun(id);

    return RunSession(
      id: summary.id,
      startTime: summary.endTime.subtract(
        Duration(seconds: summary.durationSeconds),
      ),
      endTime: summary.endTime,
      distanceMeters: summary.distanceKm * 1000,
      route: route,
      isActive: false,
      teamAtRun: summary.teamAtRun,
      hexesColored: summary.hexesColored,
      cv: summary.cv,
    );
  }

  /// Get route points for a specific run (lazy loading)
  Future<List<LocationPoint>> _getRouteForRun(String runId) async {
    final List<Map<String, dynamic>> routeMaps = await _database!.query(
      _tableRoutes,
      where: 'runId = ?',
      whereArgs: [runId],
      orderBy: 'timestampMs ASC',
    );

    return routeMaps.map((map) {
      return LocationPoint(
        latitude: map['lat'] as double,
        longitude: map['lng'] as double,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          map['timestampMs'] as int,
        ),
      );
    }).toList();
  }

  @override
  Future<void> deleteRun(String id) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    await _database!.delete(_tableRuns, where: 'id = ?', whereArgs: [id]);
    // Routes are automatically deleted due to CASCADE
  }

  @override
  Future<Map<String, dynamic>> getTotalStats() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final result = await _database!.rawQuery('''
      SELECT
        COUNT(*) as totalRuns,
        COALESCE(SUM(distanceKm), 0) as totalDistanceKm,
        COALESCE(SUM(hexesColored), 0) as totalHexes
      FROM $_tableRuns
    ''');

    if (result.isEmpty) {
      return {'totalRuns': 0, 'totalDistance': 0.0, 'totalHexes': 0};
    }

    return {
      'totalRuns': result.first['totalRuns'] as int,
      'totalDistance':
          (result.first['totalDistanceKm'] as num).toDouble() * 1000,
      'totalHexes': result.first['totalHexes'] as int,
    };
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  // ============ SEASON MANAGEMENT ============

  /// Clear all season-related data (D-Day reset)
  /// Keeps run history but clears season points
  Future<void> clearSeasonData() async {
    // Run history is preserved (Cold Data)
    // Season points are managed in UserModel/Firestore
  }

  /// Get total stats for a specific season period
  Future<Map<String, dynamic>> getSeasonStats({
    required DateTime seasonStart,
    required DateTime seasonEnd,
  }) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final startMs = seasonStart.millisecondsSinceEpoch;
    final endMs = seasonEnd.millisecondsSinceEpoch;

    final result = await _database!.rawQuery(
      '''
      SELECT
        COUNT(*) as totalRuns,
        COALESCE(SUM(distanceKm), 0) as totalDistanceKm,
        COALESCE(SUM(hexesColored), 0) as totalHexes,
        COALESCE(SUM(durationSeconds), 0) as totalDuration
      FROM $_tableRuns
      WHERE startTime >= ? AND startTime <= ?
    ''',
      [startMs, endMs],
    );

    if (result.isEmpty) {
      return {
        'totalRuns': 0,
        'totalDistanceKm': 0.0,
        'totalHexes': 0,
        'totalDuration': 0,
      };
    }

    return {
      'totalRuns': result.first['totalRuns'] as int,
      'totalDistanceKm': (result.first['totalDistanceKm'] as num).toDouble(),
      'totalHexes': result.first['totalHexes'] as int,
      'totalDuration': result.first['totalDuration'] as int,
    };
  }

  // ============ PREFETCH CACHE METHODS ============

  /// Save cached hexes (bulk insert/replace)
  Future<void> saveHexCache(List<Map<String, dynamic>> hexes) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    await _database!.transaction((txn) async {
      // Clear existing cache
      await txn.delete(_tableHexCache);

      // Insert new hexes
      for (final hex in hexes) {
        await txn.insert(
          _tableHexCache,
          hex,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Get all cached hexes
  Future<List<Map<String, dynamic>>> getHexCache() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    return await _database!.query(_tableHexCache);
  }

  /// Update a single hex in cache
  Future<void> updateCachedHex(Map<String, dynamic> hex) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    await _database!.insert(
      _tableHexCache,
      hex,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Save cached leaderboard entries (bulk insert/replace)
  Future<void> saveLeaderboardCache(List<Map<String, dynamic>> entries) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    await _database!.transaction((txn) async {
      // Clear existing cache
      await txn.delete(_tableLeaderboardCache);

      // Insert new entries
      for (final entry in entries) {
        await txn.insert(
          _tableLeaderboardCache,
          entry,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Get all cached leaderboard entries
  Future<List<Map<String, dynamic>>> getLeaderboardCache() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    return await _database!.query(
      _tableLeaderboardCache,
      orderBy: 'flip_points DESC',
    );
  }

  /// Save prefetch metadata (key-value)
  Future<void> savePrefetchMeta(String key, String value) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    await _database!.insert(_tablePrefetchMeta, {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get prefetch metadata by key
  Future<String?> getPrefetchMeta(String key) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final result = await _database!.query(
      _tablePrefetchMeta,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  /// Get home hex from prefetch metadata
  Future<String?> getHomeHex() async {
    return await getPrefetchMeta('home_hex');
  }

  /// Save home hex to prefetch metadata
  Future<void> saveHomeHex(String homeHex) async {
    await savePrefetchMeta('home_hex', homeHex);
  }

  /// Clear all prefetch cache data
  Future<void> clearPrefetchCache() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    await _database!.transaction((txn) async {
      await txn.delete(_tableHexCache);
      await txn.delete(_tableLeaderboardCache);
      // Note: Don't clear prefetch_meta (home_hex should persist)
    });
  }

  // ============ SYNC QUEUE METHODS (Offline Retry) ============

  /// Queue a failed sync operation for retry.
  ///
  /// [runId] - Unique run ID (prevents duplicate queue entries)
  /// [payload] - JSON string of RunSummary data to sync
  /// [error] - Optional error message from the failed attempt
  Future<void> queueSync(String runId, String payload, {String? error}) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    await _database!.insert(_tableSyncQueue, {
      'run_id': runId,
      'payload': payload,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'retry_count': 0,
      'last_error': error,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get all pending sync operations (oldest first).
  ///
  /// Returns list of maps with: run_id, payload, created_at, retry_count, last_error
  Future<List<Map<String, dynamic>>> getPendingSyncs() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    return await _database!.query(_tableSyncQueue, orderBy: 'created_at ASC');
  }

  /// Get count of pending sync operations.
  Future<int> getPendingSyncCount() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableSyncQueue',
    );
    return result.first['count'] as int? ?? 0;
  }

  /// Update retry count and error for a sync operation.
  Future<void> updateSyncRetry(
    String runId,
    int retryCount,
    String? error,
  ) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    await _database!.update(
      _tableSyncQueue,
      {'retry_count': retryCount, 'last_error': error},
      where: 'run_id = ?',
      whereArgs: [runId],
    );
  }

  /// Remove a sync operation from the queue (after successful sync).
  Future<void> removeSyncFromQueue(String runId) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    await _database!.delete(
      _tableSyncQueue,
      where: 'run_id = ?',
      whereArgs: [runId],
    );
  }

  /// Remove old sync entries that have exceeded max retries.
  ///
  /// [maxRetries] - Maximum retry attempts before discarding (default: 5)
  /// [maxAge] - Maximum age in days before discarding (default: 7)
  Future<int> cleanupSyncQueue({int maxRetries = 5, int maxAge = 7}) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final cutoffTime = DateTime.now()
        .subtract(Duration(days: maxAge))
        .millisecondsSinceEpoch;

    final deleted = await _database!.delete(
      _tableSyncQueue,
      where: 'retry_count >= ? OR created_at < ?',
      whereArgs: [maxRetries, cutoffTime],
    );

    return deleted;
  }
}
