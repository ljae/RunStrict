import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/run.dart';
import '../models/location_point.dart';
import '../models/lap_model.dart';
import '../services/storage_service.dart';
import '../utils/gmt2_date_utils.dart';

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
  // Singleton pattern
  static final LocalStorage _instance = LocalStorage._internal();
  factory LocalStorage() => _instance;
  LocalStorage._internal();

  static const String _databaseName = 'run_strict.db';
  static const int _databaseVersion = 10; // Bumped to drop sync_queue table

  static const String _tableRuns = 'runs';
  static const String _tableRoutes = 'routes';
  static const String _tableLaps = 'laps';
  static const String _tableHexCache = 'hex_cache';
  static const String _tableLeaderboardCache = 'leaderboard_cache';
  static const String _tablePrefetchMeta = 'prefetch_meta';
  static const String _tableSyncQueue = 'sync_queue';

  Database? _database;

  /// Expose database for testing and utilities (debug only)
  Database? get database => _database;

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
        cv REAL,
        sync_status TEXT DEFAULT 'pending',
        flip_points INTEGER DEFAULT 0,
        run_date TEXT
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
    if (oldVersion < 9) {
      // Migrate from v8 to v9: add sync tracking columns for today flip points
      try {
        await db.execute(
          'ALTER TABLE $_tableRuns ADD COLUMN sync_status TEXT DEFAULT \'pending\'',
        );
      } catch (e) {
        // Column may already exist
      }
      try {
        await db.execute(
          'ALTER TABLE $_tableRuns ADD COLUMN flip_points INTEGER DEFAULT 0',
        );
      } catch (e) {
        // Column may already exist
      }
      try {
        await db.execute('ALTER TABLE $_tableRuns ADD COLUMN run_date TEXT');
      } catch (e) {
        // Column may already exist
      }
      // Create index for efficient unsynced today points query
      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_runs_sync_date 
          ON $_tableRuns(sync_status, run_date)
        ''');
      } catch (e) {
        // Index may already exist
      }
    }
    if (oldVersion < 10) {
      // Migrate from v9 to v10: drop sync_queue table (superseded by runs.sync_status)
      try {
        await db.execute('DROP TABLE IF EXISTS sync_queue');
      } catch (e) {
        // Table may not exist
      }
    }
  }

  @override
  Future<void> saveRun(Run run) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    await _database!.transaction((txn) async {
      // Insert run
      await txn.insert(
        _tableRuns,
        run.toMap(),
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
  /// Stores run (including CV), route points, and individual lap data.
  /// Use this instead of [saveRun] when lap data is available.
  Future<void> saveRunWithLaps(
    Run run,
    List<LapModel> laps, {
    double? cv,
  }) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    // Create run map with CV
    final runMap = run.toMap();
    runMap['cv'] = cv;

    await _database!.transaction((txn) async {
      // Insert run with CV
      await txn.insert(
        _tableRuns,
        runMap,
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

  /// Get run by ID (includes CV)
  Future<Run?> getRunById(String id) async {
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
    return Run.fromMap(runMaps.first);
  }

  @override
  Future<List<Run>> getAllRuns() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final List<Map<String, dynamic>> runMaps = await _database!.query(
      _tableRuns,
      orderBy: 'startTime DESC',
    );

    // Return as Run
    // Routes are NOT loaded here (lazy loading)
    return runMaps.map((map) {
      return Run.fromMap(map);
    }).toList();
  }

  Future<Run?> getRunSummaryById(String id) async {
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

    final run = Run.fromMap(runMaps.first);
    final route = await _getRouteForRun(id);

    return run.copyWith(route: route);
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

  /// Clear all cached hexes
  Future<void> clearHexCache() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    await _database!.delete(_tableHexCache);
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

  // ============ TODAY FLIP POINTS TRACKING ============

  /// Save a run with sync tracking information for today's flip points.
  ///
  /// [run] - The completed run session
  /// [flipPoints] - Points earned in this run (hexes × multiplier)
  /// [laps] - Optional lap data for CV calculation
  /// [cv] - Optional CV value (calculated from laps)
  Future<void> saveRunWithSyncTracking(
    Run run, {
    required int flipPoints,
    List<LapModel>? laps,
    double? cv,
  }) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    // Calculate run_date in GMT+2
    final runDate = Gmt2DateUtils.toGmt2DateString(
      run.endTime ?? DateTime.now(),
    );

    // Create run map with tracking fields
    final runMap = run.toMap();
    runMap['cv'] = cv;
    runMap['sync_status'] = 'pending';
    runMap['flip_points'] = flipPoints;
    runMap['run_date'] = runDate;

    await _database!.transaction((txn) async {
      // Insert run with sync tracking
      await txn.insert(
        _tableRuns,
        runMap,
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

      // Insert lap data if provided
      if (laps != null) {
        for (final lap in laps) {
          await txn.insert(_tableLaps, {'runId': run.id, ...lap.toMap()});
        }
      }
    });
  }

  /// Sum flip points from unsynced runs that occurred today (GMT+2).
  ///
  /// Used for hybrid calculation: server_baseline + local_unsynced_today
  Future<int> sumUnsyncedTodayPoints() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final today = Gmt2DateUtils.todayGmt2String;
    final result = await _database!.rawQuery(
      '''
      SELECT COALESCE(SUM(flip_points), 0) as total
      FROM $_tableRuns
      WHERE sync_status = 'pending'
        AND run_date = ?
    ''',
      [today],
    );

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  /// Update sync status for a run after successful server sync.
  ///
  /// [runId] - The run ID to update
  /// [status] - New status: 'synced', 'failed', or 'pending'
  Future<void> updateRunSyncStatus(String runId, String status) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    await _database!.update(
      _tableRuns,
      {'sync_status': status},
      where: 'id = ?',
      whereArgs: [runId],
    );
  }

  /// Get all unsynced runs for retry on app launch.
  Future<List<Map<String, dynamic>>> getUnsyncedRuns() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    return await _database!.query(
      _tableRuns,
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'endTime ASC',
    );
  }

  /// Mark all runs from today as synced (after server confirms baseline).
  ///
  /// Called when server provides today_flip_points baseline,
  /// indicating those runs are already counted server-side.
  Future<void> markTodayRunsSynced() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final today = Gmt2DateUtils.todayGmt2String;
    await _database!.update(
      _tableRuns,
      {'sync_status': 'synced'},
      where: 'run_date = ? AND sync_status = ?',
      whereArgs: [today, 'pending'],
    );
  }
}
