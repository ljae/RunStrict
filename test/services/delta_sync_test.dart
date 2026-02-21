import 'package:flutter_test/flutter_test.dart';
import 'package:runner/data/models/team.dart';
import 'package:runner/data/repositories/hex_repository.dart';
import 'package:runner/core/services/hex_service.dart';

void main() {
  setUpAll(() async {
    await HexService().initialize();
  });

  group('Delta Sync - HexRepository', () {
    late HexRepository repository;

    setUp(() {
      repository = HexRepository();
      repository.clearAll();
    });

    group('lastPrefetchTime tracking', () {
      test('starts as null', () {
        expect(repository.lastPrefetchTime, isNull);
      });

      test('setLastPrefetchTime updates the value', () {
        final now = DateTime.now();
        repository.setLastPrefetchTime(now);

        expect(repository.lastPrefetchTime, equals(now));
      });

      test('bulkLoadFromServer updates lastPrefetchTime', () {
        final before = DateTime.now();

        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);

        final after = DateTime.now();

        expect(repository.lastPrefetchTime, isNotNull);
        expect(
          repository.lastPrefetchTime!.isAfter(
            before.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(
          repository.lastPrefetchTime!.isBefore(
            after.add(const Duration(seconds: 1)),
          ),
          isTrue,
        );
      });

      test('mergeFromServer updates lastPrefetchTime', () {
        final before = DateTime.now();

        repository.mergeFromServer([
          {
            'hex_id': 'hex1',
            'last_runner_team': 'blue',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);

        final after = DateTime.now();

        expect(repository.lastPrefetchTime, isNotNull);
        expect(
          repository.lastPrefetchTime!.isAfter(
            before.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(
          repository.lastPrefetchTime!.isBefore(
            after.add(const Duration(seconds: 1)),
          ),
          isTrue,
        );
      });

      test('clearAll resets lastPrefetchTime to null', () {
        repository.setLastPrefetchTime(DateTime.now());
        expect(repository.lastPrefetchTime, isNotNull);

        repository.clearAll();

        expect(repository.lastPrefetchTime, isNull);
      });
    });

    group('mergeFromServer (delta updates)', () {
      test('updates existing hex with new team', () {
        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-01T00:00:00Z',
          },
        ]);

        expect(repository.getHex('hex1')?.lastRunnerTeam, Team.red);

        repository.mergeFromServer([
          {
            'hex_id': 'hex1',
            'last_runner_team': 'blue',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);

        expect(repository.getHex('hex1')?.lastRunnerTeam, Team.blue);
      });

      test('adds new hex if not in cache', () {
        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-01T00:00:00Z',
          },
        ]);

        expect(repository.getHex('hex2'), isNull);

        repository.mergeFromServer([
          {
            'hex_id': 'hex2',
            'last_runner_team': 'purple',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);

        expect(repository.getHex('hex2'), isNull);
      });

      test('preserves team when delta has null (copyWith behavior)', () {
        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-01T00:00:00Z',
          },
        ]);

        repository.mergeFromServer([
          {'hex_id': 'hex1', 'last_runner_team': null, 'last_flipped_at': null},
        ]);

        expect(repository.getHex('hex1')?.lastRunnerTeam, Team.red);
        expect(repository.getHex('hex1')?.isNeutral, isFalse);
      });

      test('preserves existing hexes not in delta', () {
        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-01T00:00:00Z',
          },
          {
            'id': 'hex2',
            'latitude': 37.1,
            'longitude': -122.1,
            'last_runner_team': 'blue',
            'last_flipped_at': '2026-02-01T00:00:00Z',
          },
        ]);

        repository.mergeFromServer([
          {
            'hex_id': 'hex1',
            'last_runner_team': 'purple',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);

        expect(repository.getHex('hex1')?.lastRunnerTeam, Team.purple);
        expect(repository.getHex('hex2')?.lastRunnerTeam, Team.blue);
      });

      test('handles empty delta gracefully', () {
        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-01T00:00:00Z',
          },
        ]);

        repository.mergeFromServer([]);

        expect(repository.getHex('hex1')?.lastRunnerTeam, Team.red);
      });
    });

    group('bulkLoadFromServer (full sync)', () {
      test('clears session state but keeps hexes', () {
        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-01T00:00:00Z',
          },
        ]);

        repository.updateHexColor('hex1', Team.blue);

        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'purple',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);

        expect(repository.getHex('hex1')?.lastRunnerTeam, Team.purple);
      });

      test('handles malformed data gracefully', () {
        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-01T00:00:00Z',
          },
          {'invalid': 'data'},
        ]);

        expect(repository.getHex('hex1'), isNotNull);
      });
    });
  });

  group('Delta Sync - Integration scenarios', () {
    late HexRepository repository;

    setUp(() {
      repository = HexRepository();
      repository.clearAll();
    });

    test('first sync uses full download pattern', () {
      expect(repository.lastPrefetchTime, isNull);

      repository.bulkLoadFromServer([
        {
          'id': 'hex1',
          'latitude': 37.0,
          'longitude': -122.0,
          'last_runner_team': 'red',
          'last_flipped_at': '2026-02-01T00:00:00Z',
        },
        {
          'id': 'hex2',
          'latitude': 37.1,
          'longitude': -122.1,
          'last_runner_team': 'blue',
          'last_flipped_at': '2026-02-01T00:00:00Z',
        },
      ]);

      expect(repository.lastPrefetchTime, isNotNull);
      expect(repository.getHex('hex1'), isNotNull);
      expect(repository.getHex('hex2'), isNotNull);
    });

    test('subsequent sync uses delta pattern', () {
      repository.bulkLoadFromServer([
        {
          'id': 'hex1',
          'latitude': 37.0,
          'longitude': -122.0,
          'last_runner_team': 'red',
          'last_flipped_at': '2026-02-01T00:00:00Z',
        },
        {
          'id': 'hex2',
          'latitude': 37.1,
          'longitude': -122.1,
          'last_runner_team': 'blue',
          'last_flipped_at': '2026-02-01T00:00:00Z',
        },
      ]);

      final firstPrefetchTime = repository.lastPrefetchTime;
      expect(firstPrefetchTime, isNotNull);

      repository.mergeFromServer([
        {
          'hex_id': 'hex1',
          'last_runner_team': 'purple',
          'last_flipped_at': '2026-02-02T00:00:00Z',
        },
      ]);

      expect(repository.getHex('hex1')?.lastRunnerTeam, Team.purple);
      expect(repository.getHex('hex2')?.lastRunnerTeam, Team.blue);
      expect(repository.lastPrefetchTime!.isAfter(firstPrefetchTime!), isTrue);
    });

    test('session captures are independent of sync', () {
      repository.bulkLoadFromServer([
        {
          'id': 'hex1',
          'latitude': 37.0,
          'longitude': -122.0,
          'last_runner_team': 'red',
          'last_flipped_at': '2026-02-01T00:00:00Z',
        },
      ]);

      final result1 = repository.updateHexColor('hex1', Team.blue);
      expect(result1, HexUpdateResult.flipped);

      repository.mergeFromServer([
        {
          'hex_id': 'hex1',
          'last_runner_team': 'purple',
          'last_flipped_at': '2026-02-02T00:00:00Z',
        },
      ]);

      final result2 = repository.updateHexColor('hex1', Team.red);
      expect(result2, HexUpdateResult.alreadyCapturedSession);
    });
  });
}
