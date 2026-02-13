import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  static const int _databaseVersion =
      13; // v13: distance_meters, drop redundant columns

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
        distance_meters REAL NOT NULL,
        durationSeconds INTEGER NOT NULL,
        hexesColored INTEGER NOT NULL DEFAULT 0,
        teamAtRun TEXT NOT NULL,
        hex_path TEXT DEFAULT '',
        buff_multiplier INTEGER DEFAULT 1,
        cv REAL,
        sync_status TEXT DEFAULT 'pending',
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

    // Run checkpoint table (crash recovery - saves state on each hex flip)
    await db.execute('''
      CREATE TABLE run_checkpoint (
        id TEXT PRIMARY KEY DEFAULT 'active',
        run_id TEXT NOT NULL,
        team_at_run TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        distance_meters REAL NOT NULL,
        hexes_colored INTEGER NOT NULL DEFAULT 0,
        captured_hex_ids TEXT NOT NULL DEFAULT '',
        buff_multiplier INTEGER NOT NULL DEFAULT 1,
        last_updated INTEGER NOT NULL
      )
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
    if (oldVersion < 11) {
      // v10 → v11: avgPaceSecPerKm and isPurpleRunner are no longer written by
      // Run.toMap(). The columns remain in the schema (SQLite cannot drop columns
      // on older Android versions) but new rows will use the DEFAULT values.
      // No DDL changes required — this migration is intentionally a no-op.
    }
    if (oldVersion < 12) {
      // v11 → v12: Add hex_path + buff_multiplier for sync retry,
      // and run_checkpoint table for crash recovery.
      try {
        await db.execute(
          "ALTER TABLE $_tableRuns ADD COLUMN hex_path TEXT DEFAULT ''",
        );
      } catch (e) {
        // Column may already exist
      }
      try {
        await db.execute(
          'ALTER TABLE $_tableRuns ADD COLUMN buff_multiplier INTEGER DEFAULT 1',
        );
      } catch (e) {
        // Column may already exist
      }
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS run_checkpoint (
            id TEXT PRIMARY KEY DEFAULT 'active',
            run_id TEXT NOT NULL,
            team_at_run TEXT NOT NULL,
            start_time INTEGER NOT NULL,
            distance_meters REAL NOT NULL,
            hexes_colored INTEGER NOT NULL DEFAULT 0,
            captured_hex_ids TEXT NOT NULL DEFAULT '',
            buff_multiplier INTEGER NOT NULL DEFAULT 1,
            last_updated INTEGER NOT NULL
          )
        ''');
      } catch (e) {
        // Table may already exist
      }
    }
    if (oldVersion < 13) {
      // v12 → v13: Normalize distance (km→m), drop redundant columns
      // (avgPaceSecPerKm, isPurpleRunner, flip_points).
      // SQLite cannot DROP COLUMN on older Android, so we recreate the table.
      try {
        await db.execute('ALTER TABLE $_tableRuns RENAME TO runs_old');
        await db.execute('''
          CREATE TABLE $_tableRuns (
            id TEXT PRIMARY KEY,
            startTime INTEGER NOT NULL,
            endTime INTEGER NOT NULL,
            distance_meters REAL NOT NULL,
            durationSeconds INTEGER NOT NULL,
            hexesColored INTEGER NOT NULL DEFAULT 0,
            teamAtRun TEXT NOT NULL,
            hex_path TEXT DEFAULT '',
            buff_multiplier INTEGER DEFAULT 1,
            cv REAL,
            sync_status TEXT DEFAULT 'pending',
            run_date TEXT
          )
        ''');
        await db.execute('''
          INSERT INTO $_tableRuns (id, startTime, endTime, distance_meters, durationSeconds, hexesColored, teamAtRun, hex_path, buff_multiplier, cv, sync_status, run_date)
          SELECT id, startTime, endTime, distanceKm * 1000, durationSeconds, hexesColored, teamAtRun, COALESCE(hex_path, ''), COALESCE(buff_multiplier, 1), cv, COALESCE(sync_status, 'pending'), run_date
          FROM runs_old
        ''');
        await db.execute('DROP TABLE runs_old');
        // Recreate index for sync date queries
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_runs_sync_date 
          ON $_tableRuns(sync_status, run_date)
        ''');
      } catch (e) {
        debugPrint('LocalStorage: v13 migration failed: $e');
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

    // Return as Run — skip corrupt rows instead of failing the entire load.
    // Routes are NOT loaded here (lazy loading)
    final runs = <Run>[];
    for (final map in runMaps) {
      try {
        runs.add(Run.fromMap(map));
      } catch (e, stackTrace) {
        debugPrint(
          'LocalStorage.getAllRuns: Skipping corrupt row '
          'id=${map['id']} - $e\n$stackTrace',
        );
      }
    }
    return runs;
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
        COALESCE(SUM(distance_meters), 0) as totalDistanceMeters,
        COALESCE(SUM(hexesColored), 0) as totalHexes
      FROM $_tableRuns
    ''');

    if (result.isEmpty) {
      return {'totalRuns': 0, 'totalDistance': 0.0, 'totalHexes': 0};
    }

    return {
      'totalRuns': result.first['totalRuns'] as int,
      'totalDistance': (result.first['totalDistanceMeters'] as num).toDouble(),
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
        COALESCE(SUM(distance_meters), 0) as totalDistanceMeters,
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
        'totalDistanceMeters': 0.0,
        'totalHexes': 0,
        'totalDuration': 0,
      };
    }

    return {
      'totalRuns': result.first['totalRuns'] as int,
      'totalDistanceMeters': (result.first['totalDistanceMeters'] as num)
          .toDouble(),
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
      SELECT COALESCE(SUM(hexesColored * buff_multiplier), 0) as total
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

  // ============ RUN CHECKPOINT (CRASH RECOVERY) ============

  /// Save a run checkpoint for crash recovery.
  /// Called on each hex flip to persist minimal run state.
  Future<void> saveRunCheckpoint(Map<String, dynamic> checkpoint) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    checkpoint['id'] = 'active';
    checkpoint['last_updated'] = DateTime.now().millisecondsSinceEpoch;

    await _database!.insert(
      'run_checkpoint',
      checkpoint,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get the active run checkpoint (if any).
  /// Returns null if no checkpoint exists.
  Future<Map<String, dynamic>?> getRunCheckpoint() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final results = await _database!.query(
      'run_checkpoint',
      where: 'id = ?',
      whereArgs: ['active'],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first;
  }

  /// Clear the active run checkpoint.
  /// Called after a run is successfully saved and synced.
  Future<void> clearRunCheckpoint() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    await _database!.delete(
      'run_checkpoint',
      where: 'id = ?',
      whereArgs: ['active'],
    );
  }

  /// Get aggregated stats for yesterday's runs (GMT+2 date).
  Future<Map<String, dynamic>?> getYesterdayRunStats() async {
    final db = _database;
    if (db == null) return null;

    final yesterday = Gmt2DateUtils.todayGmt2.subtract(const Duration(days: 1));
    final yesterdayStr = Gmt2DateUtils.toGmt2DateString(yesterday);

    // Note: avgPaceSecPerKm column is always 0 (deprecated since v11).
    // Compute pace from distance and duration instead.
    final results = await db.rawQuery(
      '''
      SELECT
        COUNT(*) as run_count,
        SUM(distance_meters) as total_distance_meters,
        SUM(durationSeconds) as total_duration_seconds,
        SUM(hexesColored) as total_flips,
        SUM(hexesColored * buff_multiplier) as total_flip_points,
        AVG(cv) as avg_cv
      FROM $_tableRuns
      WHERE run_date = ?
    ''',
      [yesterdayStr],
    );

    if (results.isEmpty) return null;
    final row = results.first;
    final runCount = (row['run_count'] as num?)?.toInt() ?? 0;
    if (runCount == 0) return null;

    final totalDistKm =
        ((row['total_distance_meters'] as num?)?.toDouble() ?? 0) / 1000;
    final totalDurSec =
        (row['total_duration_seconds'] as num?)?.toDouble() ?? 0;
    // Compute average pace (min/km) from aggregate distance and duration
    final avgPaceMinPerKm = (totalDistKm > 0 && totalDurSec > 0)
        ? (totalDurSec / 60.0) / totalDistKm
        : null;

    return {
      'run_count': runCount,
      'distance_km': totalDistKm,
      'flip_count': (row['total_flips'] as num?)?.toInt() ?? 0,
      'flip_points': (row['total_flip_points'] as num?)?.toInt() ?? 0,
      'avg_pace_min_per_km': avgPaceMinPerKm,
      'avg_cv': (row['avg_cv'] as num?)?.toDouble(),
      'date': yesterdayStr,
    };
  }

  // ============ TERRITORY SNAPSHOT ============

  /// Save territory dominance snapshot for a given date (GMT+2 date string).
  /// Stored in prefetch_meta as JSON for tomorrow's TeamScreen display.
  Future<void> saveTerritorySnapshot(
    String dateStr,
    Map<String, dynamic> data,
  ) async {
    final json = jsonEncode(data);
    await savePrefetchMeta('territory_$dateStr', json);
  }

  /// Get territory dominance snapshot for a given date (GMT+2 date string).
  /// Returns null if no snapshot exists for that date.
  Future<Map<String, dynamic>?> getTerritorySnapshot(String dateStr) async {
    final json = await getPrefetchMeta('territory_$dateStr');
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('LocalStorage: Failed to decode territory snapshot: $e');
      return null;
    }
  }

  /// Sum all flip_points from all local runs (for season points fallback).
  ///
  /// Used when appLaunchSync fails and we need to derive season points
  /// from local data instead of server.
  Future<int> sumAllFlipPoints() async {
    if (_database == null) return 0;

    final result = await _database!.rawQuery('''
      SELECT COALESCE(SUM(hexesColored * buff_multiplier), 0) as total
      FROM $_tableRuns
    ''');

    return (result.first['total'] as num?)?.toInt() ?? 0;
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
