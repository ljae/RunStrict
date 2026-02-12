import 'dart:math';
import 'package:flutter/foundation.dart';
import '../config/h3_config.dart';
import '../storage/local_storage.dart';
import '../models/team.dart';
import '../services/hex_service.dart';
import '../services/prefetch_service.dart';

/// Generates dummy run history for testing and demo purposes.
///
/// Creates ~1,460 runs spanning 4 years (2022-2025) with:
/// - Distance: 5-10km (normal distribution, mean 7km)
/// - Pace: 5:00-7:00 min/km
/// - CV: 5-25 (realistic consistency range)
/// - Team: 50/50 red/blue alternating by day
///
/// WARNING: Only use in debug/development mode!
class DummyDataGenerator {
  static final Random _random = Random(42); // Fixed seed for reproducibility

  /// Generate and insert dummy runs into local storage.
  ///
  /// Creates 4 years of run history (2022-01-01 to 2025-12-31).
  /// Skips insertion if runs already exist to avoid duplicates.
  static Future<int> insertDummyRuns(LocalStorage storage) async {
    if (!kDebugMode) {
      debugPrint('DummyDataGenerator: Skipping - not in debug mode');
      return 0;
    }

    // Check if data already exists
    final existingRuns = await storage.getAllRuns();
    if (existingRuns.isNotEmpty) {
      debugPrint(
        'DummyDataGenerator: Skipping - ${existingRuns.length} runs already exist',
      );
      return 0;
    }

    debugPrint('DummyDataGenerator: Generating 4 years of dummy data...');

    int insertedCount = 0;
    final startDate = DateTime(2022, 1, 1);
    final endDate = DateTime(2025, 12, 31);

    DateTime currentDate = startDate;
    while (!currentDate.isAfter(endDate)) {
      final run = _generateRunForDate(currentDate, insertedCount);
      await _insertRun(storage, run);
      insertedCount++;
      currentDate = currentDate.add(const Duration(days: 1));
    }

    debugPrint('DummyDataGenerator: Inserted $insertedCount dummy runs');
    return insertedCount;
  }

  /// Generate a single run for a specific date.
  static Map<String, dynamic> _generateRunForDate(DateTime date, int dayIndex) {
    // Distance: 5-10km, normally distributed around 7km
    final distanceKm = _normalRandom(7.0, 1.5).clamp(5.0, 10.0);

    // Pace: 5:00-7:00 min/km (300-420 sec/km)
    final avgPaceSecPerKm = _normalRandom(360.0, 30.0).clamp(300.0, 420.0);

    // Duration calculated from distance and pace
    final durationSeconds = (distanceKm * avgPaceSecPerKm).round();

    // CV: 5-25 (lower = more consistent)
    final cv = _normalRandom(15.0, 5.0).clamp(5.0, 25.0);

    // Hexes colored: approximate based on hex size (~174m edge-to-edge)
    // Roughly distance_meters / 174
    final hexesColored = (distanceKm * 1000 / 174).round();

    // Team: alternate 50/50 by day index
    final team = dayIndex % 2 == 0 ? Team.red : Team.blue;

    // Run time: 6:00-8:00 AM with some variation
    final hourOffset = _random.nextInt(3); // 0, 1, or 2 hours
    final minuteOffset = _random.nextInt(60);
    final startTime = DateTime(
      date.year,
      date.month,
      date.day,
      6 + hourOffset,
      minuteOffset,
    );
    final endTime = startTime.add(Duration(seconds: durationSeconds));

    return {
      'id':
          'dummy_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}',
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'distanceMeters': distanceKm * 1000, // Convert km to meters
      'durationSeconds': durationSeconds,
      'hexesColored': hexesColored,
      'hexesPassed': hexesColored, // Same as colored for dummy data
      'teamAtRun': team.name,
      'buffMultiplier': 1,
      'cv': cv,
      'syncStatus': 'synced',
    };
  }

  /// Insert a run directly into the database.
  static Future<void> _insertRun(
    LocalStorage storage,
    Map<String, dynamic> run,
  ) async {
    // Access the database through the exposed getter
    final db = storage.database;
    if (db == null) {
      throw StateError('Database not initialized');
    }

    await db.insert('runs', run);
  }

  /// Generate a normally distributed random number.
  static double _normalRandom(double mean, double stdDev) {
    // Box-Muller transform for normal distribution
    final u1 = _random.nextDouble();
    final u2 = _random.nextDouble();
    final z = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
    return mean + z * stdDev;
  }

  /// Generate hex colors for the ALL range around a home hex.
  ///
  /// Colors 99% of hexes with red/blue/purple, leaves 1% unclaimed.
  /// Distribution: ~45% red, ~45% blue, ~9% purple, ~1% unclaimed
  /// Uses Res 5 parent to get ~2,401 child hexes at Res 9.
  ///
  /// [homeHex] - The user's home hex at Res 9
  /// [unclaimedPercent] - Percentage of hexes to leave unclaimed (default 1%)
  static Future<int> generateHexColors(
    LocalStorage storage,
    String homeHex, {
    double unclaimedPercent = 1.0,
    bool forceRegenerate = false,
  }) async {
    if (!kDebugMode) {
      debugPrint('DummyDataGenerator: Skipping hex colors - not in debug mode');
      return 0;
    }

    // Check if hex data already exists (skip unless forced)
    if (!forceRegenerate) {
      final existingHexes = await storage.getHexCache();
      if (existingHexes.isNotEmpty) {
        debugPrint(
          'DummyDataGenerator: Skipping hex colors - ${existingHexes.length} hexes already exist',
        );
        // Still load existing data into PrefetchService
        PrefetchService().loadDummyHexData(existingHexes);
        return existingHexes.length;
      }
    }

    // Clear existing hex cache when force regenerating
    if (forceRegenerate) {
      await storage.clearHexCache();
      debugPrint('DummyDataGenerator: Cleared existing hex cache');
    }

    final hexService = HexService();

    // Get ALL scope parent (Res 5) and expand to all children at Res 9
    final allParent = hexService.getParentHexId(
      homeHex,
      H3Config.allResolution,
    );
    final allHexIds = hexService.getAllChildrenAtResolution(
      allParent,
      H3Config.baseResolution,
    );

    debugPrint(
      'DummyDataGenerator: Generating colors for ${allHexIds.length} hexes...',
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    final hexData = <Map<String, dynamic>>[];
    final totalHexes = allHexIds.length;

    // Distribution: 1% unclaimed, 9% purple, 45% red, 45% blue
    final unclaimedCount = (totalHexes * unclaimedPercent / 100).round();
    final purpleCount = (totalHexes * 9 / 100).round();

    // Shuffle to randomize distribution
    final shuffledHexIds = List<String>.from(allHexIds)..shuffle(_random);

    for (int i = 0; i < shuffledHexIds.length; i++) {
      final hexId = shuffledHexIds[i];

      Team? team;
      if (i < unclaimedCount) {
        // First ~1% are unclaimed
        team = null;
      } else if (i < unclaimedCount + purpleCount) {
        // Next ~9% are purple
        team = Team.purple;
      } else {
        // Remaining ~90% are red or blue (50/50)
        team = _random.nextBool() ? Team.red : Team.blue;
      }

      hexData.add({
        'hex_id': hexId,
        'last_runner_team': team?.name,
        'last_updated': now,
      });
    }

    // Save to local storage (for persistence)
    await storage.saveHexCache(hexData);

    // Also load directly into PrefetchService memory cache
    PrefetchService().loadDummyHexData(hexData);

    final redCount = hexData
        .where((h) => h['last_runner_team'] == 'red')
        .length;
    final blueCount = hexData
        .where((h) => h['last_runner_team'] == 'blue')
        .length;
    final purpleCountActual = hexData
        .where((h) => h['last_runner_team'] == 'purple')
        .length;
    final nullCount = hexData
        .where((h) => h['last_runner_team'] == null)
        .length;

    debugPrint(
      'DummyDataGenerator: Generated ${hexData.length} hexes - '
      'Red: $redCount, Blue: $blueCount, Purple: $purpleCountActual, '
      'Unclaimed: $nullCount',
    );

    return hexData.length;
  }

  /// Generate all dummy data (runs + hex colors).
  ///
  /// Convenience method that runs both generators.
  static Future<Map<String, int>> generateAllDummyData(
    LocalStorage storage,
    String homeHex, {
    double unclaimedPercent = 3.0,
  }) async {
    final runsCount = await insertDummyRuns(storage);
    final hexCount = await generateHexColors(
      storage,
      homeHex,
      unclaimedPercent: unclaimedPercent,
    );

    return {'runs': runsCount, 'hexes': hexCount};
  }
}
