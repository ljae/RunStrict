import 'package:flutter_test/flutter_test.dart';
import 'package:runner/models/run.dart';
import 'package:runner/models/team.dart';
import 'package:runner/models/location_point.dart';

void main() {
  group('Run Model', () {
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(minutes: 30));
    final endTime = now;

    group('Computed Getters', () {
      test('distanceKm converts meters correctly', () {
        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000, // 5km
          durationSeconds: 1800, // 30 min
          hexesColored: 10,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 2,
          cv: null,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        expect(run.distanceKm, equals(5.0));
      });

      test('avgPaceMinPerKm calculates correctly', () {
        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000, // 5km
          durationSeconds: 1800, // 30 min = 6 min/km
          hexesColored: 10,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 2,
          cv: null,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        expect(run.avgPaceMinPerKm, closeTo(6.0, 0.01));
      });

      test('avgPaceMinPerKm returns 0 for zero distance', () {
        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 0,
          durationSeconds: 1800,
          hexesColored: 0,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 1,
          cv: null,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        expect(run.avgPaceMinPerKm, equals(0.0));
      });

      test('avgPaceMinPerKm returns 0 for zero duration', () {
        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 0,
          hexesColored: 10,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 1,
          cv: null,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        expect(run.avgPaceMinPerKm, equals(0.0));
      });

      test('stabilityScore calculates from CV correctly', () {
        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 10,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 2,
          cv: 15.5, // CV = 15.5 → stability = 100 - 15.5 = 84.5 → 85
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        expect(run.stabilityScore, equals(85));
      });

      test('stabilityScore clamps to 0-100 range', () {
        final run1 = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 10,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 2,
          cv: 150.0, // CV > 100 → stability would be negative
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        expect(run1.stabilityScore, equals(0)); // Clamped to 0

        final run2 = Run(
          id: 'run2',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 10,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 2,
          cv: 0.0, // CV = 0 → stability = 100
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        expect(run2.stabilityScore, equals(100)); // Clamped to 100
      });

      test('stabilityScore returns null when CV is null', () {
        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 10,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 2,
          cv: null,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        expect(run.stabilityScore, isNull);
      });

      test('flipPoints calculates hexesColored × buffMultiplier', () {
        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 12,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 3,
          cv: null,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        expect(run.flipPoints, equals(36)); // 12 * 3
      });

      test('flipPoints returns 0 when hexesColored is 0', () {
        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 0,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 3,
          cv: null,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        expect(run.flipPoints, equals(0));
      });
    });

    group('toMap/fromMap Serialization (SQLite Format)', () {
      // Note: toMap/fromMap are for SQLite local storage.
      // SQLite schema stores: distance_meters, sync_status (not syncStatus)
      // Transient fields (hexPath, route, hexesPassed, currentHexId, etc.) are NOT stored.
      test('roundtrip preserves stored fields', () {
        final original = Run(
          id: 'run123',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 10,
          teamAtRun: Team.blue,
          hexPath: const ['hex1', 'hex2', 'hex3'], // NOT stored in SQLite
          buffMultiplier: 2, // NOT stored in SQLite (restored as default 1)
          cv: 12.5,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const ['hex1', 'hex2'],
          currentHexId: 'hex3',
          distanceInCurrentHex: 150.0,
          isActive: false,
        );

        final map = original.toMap();
        final restored = Run.fromMap(map);

        // Stored fields should be preserved
        expect(restored.id, equals(original.id));
        // DateTime loses microsecond precision in millisecond conversion
        expect(
          restored.startTime.millisecondsSinceEpoch,
          equals(original.startTime.millisecondsSinceEpoch),
        );
        expect(
          restored.endTime?.millisecondsSinceEpoch,
          equals(original.endTime?.millisecondsSinceEpoch),
        );
        expect(restored.distanceMeters, equals(original.distanceMeters));
        expect(restored.durationSeconds, equals(original.durationSeconds));
        expect(restored.hexesColored, equals(original.hexesColored));
        expect(restored.teamAtRun, equals(original.teamAtRun));
        expect(restored.cv, equals(original.cv));
        expect(restored.syncStatus, equals(original.syncStatus));

        // Now stored in SQLite (DB v12+)
        expect(restored.hexPath, equals(const ['hex1', 'hex2', 'hex3']));
        expect(restored.buffMultiplier, equals(2));

        // Transient fields get defaults after restore
        expect(restored.route, equals(const [])); // Transient
        expect(restored.hexesPassed, equals(const [])); // Transient
        expect(restored.currentHexId, isNull); // Transient
        expect(restored.distanceInCurrentHex, equals(0)); // Transient
        expect(restored.isActive, equals(false)); // Transient
      });

      test('toMap produces expected SQLite schema keys', () {
        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 10,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 1,
          cv: null,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        final map = run.toMap();

        // SQLite schema keys (see local_storage.dart)
        expect(map.containsKey('id'), isTrue);
        expect(map.containsKey('startTime'), isTrue);
        expect(map.containsKey('endTime'), isTrue);
        expect(map.containsKey('distance_meters'), isTrue);
        expect(map.containsKey('durationSeconds'), isTrue);
        expect(map.containsKey('hexesColored'), isTrue);
        expect(map.containsKey('teamAtRun'), isTrue);
        expect(map.containsKey('cv'), isTrue);
        expect(map.containsKey('sync_status'), isTrue); // NOT syncStatus

        // Removed in v13
        expect(map.containsKey('flip_points'), isFalse);
        expect(map.containsKey('avgPaceSecPerKm'), isFalse);
        expect(map.containsKey('distanceKm'), isFalse);

        // Legacy fields removed from toMap()
        expect(map.containsKey('isPurpleRunner'), isFalse);

        // Now stored in SQLite (DB v12+ for sync retry)
        expect(map.containsKey('hex_path'), isTrue);
        expect(map.containsKey('buff_multiplier'), isTrue);

        // NOT stored in SQLite
        expect(map.containsKey('distanceMeters'), isFalse);
        expect(map.containsKey('syncStatus'), isFalse);
      });

      test('handles null CV in roundtrip', () {
        final original = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 500, // < 1km
          durationSeconds: 300,
          hexesColored: 2,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 1,
          cv: null,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        final map = original.toMap();
        final restored = Run.fromMap(map);

        expect(restored.cv, isNull);
      });
    });

    group('toRow/fromRow Serialization (Server Format)', () {
      test('roundtrip preserves all fields', () {
        final original = Run(
          id: 'run123',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 10,
          teamAtRun: Team.purple,
          hexPath: const ['hex1', 'hex2', 'hex3'],
          buffMultiplier: 2,
          cv: 12.5,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        final row = original.toRow();
        // Add id to row for fromRow (toRow doesn't include id)
        row['id'] = original.id;
        final restored = Run.fromRow(row);

        expect(restored.id, equals(original.id));
        expect(restored.endTime, equals(original.endTime));
        expect(restored.distanceMeters, equals(original.distanceMeters));
        expect(restored.durationSeconds, equals(original.durationSeconds));
        expect(restored.hexesColored, equals(original.hexesColored));
        expect(restored.teamAtRun, equals(original.teamAtRun));
        expect(restored.hexPath, equals(original.hexPath));
        expect(restored.buffMultiplier, equals(original.buffMultiplier));
        expect(restored.cv, equals(original.cv));
      });

      test('toRow uses snake_case keys for Supabase', () {
        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 10,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 1,
          cv: null,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        final row = run.toRow();

        expect(row.containsKey('end_time'), isTrue);
        expect(row.containsKey('distance_meters'), isTrue);
        expect(row.containsKey('duration_seconds'), isTrue);
        expect(row.containsKey('avg_pace_min_per_km'), isTrue);
        expect(row.containsKey('hexes_colored'), isTrue);
        expect(row.containsKey('team_at_run'), isTrue);
        expect(row.containsKey('hex_path'), isTrue);
        expect(row.containsKey('buff_multiplier'), isTrue);
        expect(row.containsKey('cv'), isTrue);
      });

      test('toRow format matches RunSummary.toRow() structure', () {
        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 10,
          teamAtRun: Team.red,
          hexPath: const ['hex1', 'hex2'],
          buffMultiplier: 2,
          cv: 15.0,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        final row = run.toRow();

        // Verify format matches RunSummary expectations
        expect(row['end_time'], isA<String>()); // ISO8601
        expect(row['distance_meters'], isA<double>());
        expect(row['duration_seconds'], isA<int>());
        expect(row['avg_pace_min_per_km'], isA<double>());
        expect(row['hexes_colored'], isA<int>());
        expect(row['team_at_run'], isA<String>());
        expect(row['hex_path'], isA<List>());
        expect(row['buff_multiplier'], isA<int>());
      });

      test('handles empty hexPath in toRow', () {
        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 1000,
          durationSeconds: 600,
          hexesColored: 0,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 1,
          cv: null,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        final row = run.toRow();
        expect(row['hex_path'], equals([]));
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        final original = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 10,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 2,
          cv: null,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        final modified = original.copyWith(
          distanceMeters: 6000,
          hexesColored: 12,
          syncStatus: 'pending',
        );

        expect(modified.distanceMeters, equals(6000));
        expect(modified.hexesColored, equals(12));
        expect(modified.syncStatus, equals('pending'));
        expect(modified.id, equals(original.id)); // Unchanged
        expect(modified.teamAtRun, equals(original.teamAtRun)); // Unchanged
      });

      test('preserves all fields when no changes specified', () {
        final original = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 10,
          teamAtRun: Team.blue,
          hexPath: const ['hex1'],
          buffMultiplier: 3,
          cv: 20.0,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: 'hex1',
          distanceInCurrentHex: 100.0,
          isActive: true,
        );

        final copy = original.copyWith();

        expect(copy.id, equals(original.id));
        expect(copy.startTime, equals(original.startTime));
        expect(copy.endTime, equals(original.endTime));
        expect(copy.distanceMeters, equals(original.distanceMeters));
        expect(copy.durationSeconds, equals(original.durationSeconds));
        expect(copy.hexesColored, equals(original.hexesColored));
        expect(copy.teamAtRun, equals(original.teamAtRun));
        expect(copy.hexPath, equals(original.hexPath));
        expect(copy.buffMultiplier, equals(original.buffMultiplier));
        expect(copy.cv, equals(original.cv));
        expect(copy.syncStatus, equals(original.syncStatus));
        expect(copy.currentHexId, equals(original.currentHexId));
        expect(
          copy.distanceInCurrentHex,
          equals(original.distanceInCurrentHex),
        );
        expect(copy.isActive, equals(original.isActive));
      });

      test('can update CV to null', () {
        final original = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 10,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 1,
          cv: 15.0,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        // Use a sentinel value to explicitly set CV to null
        final modified = original.copyWith(cv: null);

        expect(modified.cv, isNull);
        expect(modified.id, equals(original.id));
      });

      test('can update CV to a new value', () {
        final original = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 10,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 1,
          cv: 15.0,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        final modified = original.copyWith(cv: 20.0);

        expect(modified.cv, equals(20.0));
        expect(modified.id, equals(original.id));
      });
    });

    group('Edge Cases', () {
      test('handles zero distance run', () {
        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 0,
          durationSeconds: 300,
          hexesColored: 0,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 1,
          cv: null,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        expect(run.distanceKm, equals(0.0));
        expect(run.avgPaceMinPerKm, equals(0.0));
        expect(run.flipPoints, equals(0));
      });

      test('handles very short run (< 1km)', () {
        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 500,
          durationSeconds: 300,
          hexesColored: 1,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 1,
          cv: null, // No CV for runs < 1km
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        expect(run.distanceKm, equals(0.5));
        expect(run.stabilityScore, isNull);
      });

      test('handles active run with transient fields', () {
        final route = [
          LocationPoint(
            latitude: 37.0,
            longitude: -122.0,
            timestamp: startTime,
          ),
        ];

        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: null, // Still active
          distanceMeters: 1000,
          durationSeconds: 600,
          hexesColored: 2,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 1,
          cv: null,
          syncStatus: 'pending',
          route: route,
          hexesPassed: const ['hex1', 'hex2'],
          currentHexId: 'hex2',
          distanceInCurrentHex: 150.0,
          isActive: true,
        );

        expect(run.isActive, isTrue);
        expect(run.endTime, isNull);
        expect(run.route, isNotEmpty);
        expect(run.hexesPassed, isNotEmpty);
      });

      test('handles all teams', () {
        for (final team in Team.values) {
          final run = Run(
            id: 'run1',
            startTime: startTime,
            endTime: endTime,
            distanceMeters: 5000,
            durationSeconds: 1800,
            hexesColored: 10,
            teamAtRun: team,
            hexPath: const [],
            buffMultiplier: 1,
            cv: null,
            syncStatus: 'synced',
            route: const [],
            hexesPassed: const [],
            currentHexId: null,
            distanceInCurrentHex: 0,
            isActive: false,
          );

          expect(run.teamAtRun, equals(team));
          final row = run.toRow();
          expect(row['team_at_run'], equals(team.name));
        }
      });
    });

    group('toString', () {
      test('produces readable output', () {
        final run = Run(
          id: 'run1',
          startTime: startTime,
          endTime: endTime,
          distanceMeters: 5000,
          durationSeconds: 1800,
          hexesColored: 10,
          teamAtRun: Team.red,
          hexPath: const [],
          buffMultiplier: 2,
          cv: 15.0,
          syncStatus: 'synced',
          route: const [],
          hexesPassed: const [],
          currentHexId: null,
          distanceInCurrentHex: 0,
          isActive: false,
        );

        final str = run.toString();

        expect(str, contains('run1'));
        expect(str, contains('5.00km'));
        expect(str, contains('10'));
        expect(str, contains('red'));
      });
    });
  });
}
