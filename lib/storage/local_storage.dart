import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/run_session.dart';
import '../models/run_summary.dart';
import '../models/location_point.dart';
import '../services/storage_service.dart';

/// SQLite implementation of StorageService for local data persistence
///
/// Stores:
/// - RunSummary in 'runs' table (lightweight, for history)
/// - CompressedRoute in 'routes' table (cold storage, lazy loaded)
/// - DailyFlips in 'daily_flips' table (daily hex flip dedup tracking)
class LocalStorage implements StorageService {
  static const String _databaseName = 'run_strict.db';
  static const int _databaseVersion = 4;

  static const String _tableRuns = 'runs';
  static const String _tableRoutes = 'routes';
  static const String _tableDailyFlips = 'daily_flips';

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
        isPurpleRunner INTEGER NOT NULL DEFAULT 0
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

    // Index for faster route queries
    await db.execute('''
      CREATE INDEX idx_routes_runId ON $_tableRoutes(runId)
    ''');

    // Daily flips table (tracks which hexes user flipped each day)
    await db.execute('''
      CREATE TABLE $_tableDailyFlips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        dateKey TEXT NOT NULL,
        hexId TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        UNIQUE(userId, dateKey, hexId)
      )
    ''');

    // Index for faster daily flip queries
    await db.execute('''
      CREATE INDEX idx_daily_flips_user_date ON $_tableDailyFlips(userId, dateKey)
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
    if (oldVersion < 4) {
      // Migrate from v3 to v4: add daily_flips table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_tableDailyFlips (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            dateKey TEXT NOT NULL,
            hexId TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            UNIQUE(userId, dateKey, hexId)
          )
        ''');
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_daily_flips_user_date 
          ON $_tableDailyFlips(userId, dateKey)
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
    return runMaps.map((map) {
      final summary = RunSummary.fromMap(map);
      return RunSession(
        id: summary.id,
        startTime: summary.date,
        distanceMeters: summary.distanceKm * 1000,
        isActive: false,
        teamAtRun: summary.teamAtRun,
        hexesColored: summary.hexesColored,
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
      startTime: summary.date,
      distanceMeters: summary.distanceKm * 1000,
      route: route,
      isActive: false,
      teamAtRun: summary.teamAtRun,
      hexesColored: summary.hexesColored,
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

  // ============ DAILY FLIP DEDUP ============

  /// Record a hex flip for the given date
  ///
  /// Uses INSERT OR IGNORE to handle duplicates gracefully.
  Future<void> recordDailyFlip({
    required String userId,
    required String hexId,
    required String dateKey,
  }) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    await _database!.insert(_tableDailyFlips, {
      'userId': userId,
      'dateKey': dateKey,
      'hexId': hexId,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Get all hex IDs flipped by a user on a specific date
  Future<Set<String>> getDailyFlips({
    required String userId,
    required String dateKey,
  }) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final results = await _database!.query(
      _tableDailyFlips,
      columns: ['hexId'],
      where: 'userId = ? AND dateKey = ?',
      whereArgs: [userId, dateKey],
    );

    return results.map((row) => row['hexId'] as String).toSet();
  }

  /// Check if a user has already flipped a specific hex today
  Future<bool> hasFlippedToday({
    required String userId,
    required String hexId,
    required String dateKey,
  }) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final result = await _database!.query(
      _tableDailyFlips,
      where: 'userId = ? AND dateKey = ? AND hexId = ?',
      whereArgs: [userId, dateKey, hexId],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  /// Clear ALL daily flip records (for testing/debugging)
  Future<int> clearAllDailyFlips() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final deletedCount = await _database!.delete(_tableDailyFlips);
    return deletedCount;
  }

  /// Clean up old daily flip records (keep only last N days)
  ///
  /// Call this periodically to prevent database bloat.
  Future<int> cleanupOldDailyFlips({int keepDays = 2}) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    final cutoffMs = cutoffDate.millisecondsSinceEpoch;

    final deletedCount = await _database!.delete(
      _tableDailyFlips,
      where: 'createdAt < ?',
      whereArgs: [cutoffMs],
    );

    return deletedCount;
  }

  // ============ COOLDOWN-BASED FLIP TRACKING ============

  /// Record a hex flip with timestamp (for cooldown tracking)
  Future<void> recordFlipWithTimestamp({
    required String userId,
    required String hexId,
    required DateTime timestamp,
  }) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    // Use REPLACE to update timestamp if hex already exists
    await _database!.insert(_tableDailyFlips, {
      'userId': userId,
      'dateKey': 'cooldown', // Placeholder for cooldown-based tracking
      'hexId': hexId,
      'createdAt': timestamp.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get recent flips within cooldown period
  /// Returns map of hexId -> timestamp for flips within maxAge
  Future<Map<String, DateTime>> getRecentFlips({
    required String userId,
    required Duration maxAge,
  }) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final cutoffMs = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;

    final results = await _database!.query(
      _tableDailyFlips,
      columns: ['hexId', 'createdAt'],
      where: 'userId = ? AND createdAt >= ?',
      whereArgs: [userId, cutoffMs],
    );

    final Map<String, DateTime> flips = {};
    for (final row in results) {
      final hexId = row['hexId'] as String;
      final createdAt = row['createdAt'] as int;
      flips[hexId] = DateTime.fromMillisecondsSinceEpoch(createdAt);
    }
    return flips;
  }

  /// Clean up flip records older than maxAge
  Future<int> cleanupOldFlips({required Duration maxAge}) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final cutoffMs = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;

    final deletedCount = await _database!.delete(
      _tableDailyFlips,
      where: 'createdAt < ?',
      whereArgs: [cutoffMs],
    );

    return deletedCount;
  }

  /// Get count of unique hexes flipped today
  Future<int> getTodayFlipCount({
    required String userId,
    required String dateKey,
  }) async {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    final result = await _database!.rawQuery(
      '''
      SELECT COUNT(DISTINCT hexId) as count
      FROM $_tableDailyFlips
      WHERE userId = ? AND dateKey = ?
      ''',
      [userId, dateKey],
    );

    return (result.first['count'] as int?) ?? 0;
  }
}
