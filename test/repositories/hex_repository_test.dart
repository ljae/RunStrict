import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:runner/data/models/team.dart';
import 'package:runner/features/map/providers/hex_data_provider.dart';
import 'package:runner/data/repositories/hex_repository.dart';
import 'package:runner/core/services/hex_service.dart';

void main() {
  setUpAll(() async {
    // Initialize HexService for all tests
    await HexService().initialize();
  });

  group('HexRepository', () {
    late HexRepository repository;

    setUp(() {
      // Create fresh instance for each test
      repository = HexRepository();
      repository.clearAll();
    });

    // Don't dispose singleton in tearDown - it breaks subsequent tests
    // tearDown(() {
    //   repository.dispose();
    // });

    group('LRU Cache Eviction', () {
      test('evicts oldest hex when max size exceeded', () {
        // Arrange: Create repository with small cache size for testing
        final repo = HexRepository.forTesting(maxCacheSize: 3);

        // Act: Add 4 hexes (exceeds max size of 3)
        repo.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
          {
            'id': 'hex2',
            'latitude': 37.1,
            'longitude': -122.1,
            'last_runner_team': 'blue',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
          {
            'id': 'hex3',
            'latitude': 37.2,
            'longitude': -122.2,
            'last_runner_team': 'purple',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
          {
            'id': 'hex4',
            'latitude': 37.3,
            'longitude': -122.3,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);

        // Assert: hex1 should be evicted (oldest), others remain
        expect(repo.getHex('hex1'), isNull);
        expect(repo.getHex('hex2'), isNotNull);
        expect(repo.getHex('hex3'), isNotNull);
        expect(repo.getHex('hex4'), isNotNull);
      });

      test('accessing hex moves it to end of LRU order', () {
        final repo = HexRepository.forTesting(maxCacheSize: 3);

        // Add 3 hexes
        repo.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
          {
            'id': 'hex2',
            'latitude': 37.1,
            'longitude': -122.1,
            'last_runner_team': 'blue',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
          {
            'id': 'hex3',
            'latitude': 37.2,
            'longitude': -122.2,
            'last_runner_team': 'purple',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);

        // Access hex1 (moves it to end)
        repo.getHex('hex1');

        // Add hex4 (should evict hex2, not hex1)
        repo.bulkLoadFromServer([
          {
            'id': 'hex4',
            'latitude': 37.3,
            'longitude': -122.3,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);

        expect(repo.getHex('hex1'), isNotNull);
        expect(repo.getHex('hex2'), isNull);
        expect(repo.getHex('hex3'), isNotNull);
        expect(repo.getHex('hex4'), isNotNull);
      });
    });

    group('updateHexColor', () {
      test('returns flipped when hex color changes', () {
        // Arrange
        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);

        // Act
        final result = repository.updateHexColor('hex1', Team.blue);

        // Assert
        expect(result, HexUpdateResult.flipped);
        expect(repository.getHex('hex1')?.lastRunnerTeam, Team.blue);
      });

      test('returns sameTeam when hex already has runner team', () {
        // Arrange
        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);

        // Act
        final result = repository.updateHexColor('hex1', Team.red);

        // Assert
        expect(result, HexUpdateResult.sameTeam);
        expect(repository.getHex('hex1')?.lastRunnerTeam, Team.red);
      });

      test(
        'returns alreadyCapturedSession on second capture in same session',
        () {
          // Arrange
          repository.bulkLoadFromServer([
            {
              'id': 'hex1',
              'latitude': 37.0,
              'longitude': -122.0,
              'last_runner_team': 'red',
              'last_flipped_at': '2026-02-02T00:00:00Z',
            },
          ]);

          // Act: First capture
          final result1 = repository.updateHexColor('hex1', Team.blue);
          // Second capture of same hex
          final result2 = repository.updateHexColor('hex1', Team.purple);

          // Assert
          expect(result1, HexUpdateResult.flipped);
          expect(result2, HexUpdateResult.alreadyCapturedSession);
          expect(repository.getHex('hex1')?.lastRunnerTeam, Team.blue);
        },
      );

      test('returns error when hex creation fails', () {
        // Act: Use an invalid hex ID that will fail to create
        const invalidHexId = 'invalid_hex_id';
        final result = repository.updateHexColor(invalidHexId, Team.red);

        // Assert: Should return error when hex creation fails
        expect(result, HexUpdateResult.error);
      });
    });

    group('bulkLoadFromServer', () {
      test('populates cache with server hexes', () {
        // Arrange
        final hexData = [
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
          {
            'id': 'hex2',
            'latitude': 37.1,
            'longitude': -122.1,
            'last_runner_team': 'blue',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ];

        // Act
        repository.bulkLoadFromServer(hexData);

        // Assert
        expect(repository.getHex('hex1'), isNotNull);
        expect(repository.getHex('hex1')?.lastRunnerTeam, Team.red);
        expect(repository.getHex('hex2'), isNotNull);
        expect(repository.getHex('hex2')?.lastRunnerTeam, Team.blue);
      });

      test('handles null last_runner_team (neutral hexes)', () {
        // Arrange
        final hexData = [
          {
            'id': 'hex_neutral',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': null,
            'last_flipped_at': null,
          },
        ];

        // Act
        repository.bulkLoadFromServer(hexData);

        // Assert
        final hex = repository.getHex('hex_neutral');
        expect(hex, isNotNull);
        expect(hex?.lastRunnerTeam, isNull);
        expect(hex?.isNeutral, true);
      });

      test('updates lastPrefetchTime', () {
        // Arrange
        final before = DateTime.now();

        // Act
        repository.bulkLoadFromServer([]);

        // Assert
        final after = DateTime.now();
        expect(repository.lastPrefetchTime, isNotNull);
        expect(
          repository.lastPrefetchTime!.isAfter(
            before.subtract(Duration(seconds: 1)),
          ),
          true,
        );
        expect(
          repository.lastPrefetchTime!.isBefore(
            after.add(Duration(seconds: 1)),
          ),
          true,
        );
      });
    });

    group('clearAll', () {
      test('resets all state including captured hexes', () {
        // Arrange
        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);
        repository.updateUserLocation(const LatLng(37.0, -122.0), 'hex1');
        repository.updateHexColor('hex1', Team.blue);

        // Act
        repository.clearAll();

        // Assert
        expect(repository.getHex('hex1'), isNull);
        expect(repository.userLocation, isNull);
        expect(repository.currentUserHexId, isNull);
      });

      test('clears captured hexes for new session', () {
        // Arrange
        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);
        repository.updateHexColor('hex1', Team.blue);

        // Act
        repository.clearCapturedHexes();

        // Assert: Can capture same hex again
        final result = repository.updateHexColor('hex1', Team.purple);
        expect(result, HexUpdateResult.flipped);
      });
    });

    group('Session Capture Tracking', () {
      test('prevents double-counting same hex in session', () {
        // Arrange
        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);

        // Act: Capture hex
        final result1 = repository.updateHexColor('hex1', Team.blue);
        // Try to capture again
        final result2 = repository.updateHexColor('hex1', Team.purple);

        // Assert
        expect(result1, HexUpdateResult.flipped);
        expect(result2, HexUpdateResult.alreadyCapturedSession);
      });

      test('allows re-capture after clearCapturedHexes', () {
        // Arrange
        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);

        // Act: Capture, clear, capture again
        repository.updateHexColor('hex1', Team.blue);
        repository.clearCapturedHexes();
        final result = repository.updateHexColor('hex1', Team.purple);

        // Assert
        expect(result, HexUpdateResult.flipped);
      });
    });

    group('User Location Updates', () {
      test('updates user location and hex ID', () {
        // Arrange
        const location = LatLng(37.0, -122.0);
        const hexId = 'hex1';

        // Act
        repository.updateUserLocation(location, hexId);

        // Assert
        expect(repository.userLocation, location);
        expect(repository.currentUserHexId, hexId);
      });

      test('clears user location', () {
        // Arrange
        repository.updateUserLocation(const LatLng(37.0, -122.0), 'hex1');

        // Act
        repository.clearUserLocation();

        // Assert
        expect(repository.userLocation, isNull);
        expect(repository.currentUserHexId, isNull);
      });

      test('location stream emits updates', () async {
        // Arrange
        const location = LatLng(37.0, -122.0);
        final stream = repository.locationStream;

        // Act & Assert
        final future = stream.first;
        repository.updateUserLocation(location, 'hex1');
        final emitted = await future;

        expect(emitted, location);
      });
    });

    group('Cache Stats', () {
      test('returns cache statistics', () {
        // Arrange
        repository.bulkLoadFromServer([
          {
            'id': 'hex1',
            'latitude': 37.0,
            'longitude': -122.0,
            'last_runner_team': 'red',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
          {
            'id': 'hex2',
            'latitude': 37.1,
            'longitude': -122.1,
            'last_runner_team': 'blue',
            'last_flipped_at': '2026-02-02T00:00:00Z',
          },
        ]);

        // Act
        final stats = repository.cacheStats;

        // Assert
        expect(stats['size'], 2);
        expect(stats['maxSize'], greaterThan(0));
        expect(stats.containsKey('hits'), true);
        expect(stats.containsKey('misses'), true);
      });
    });

    group('Singleton Pattern', () {
      test('returns same instance', () {
        // Arrange
        final repo1 = HexRepository();
        final repo2 = HexRepository();

        // Assert
        expect(identical(repo1, repo2), true);
      });
    });
  });
}
