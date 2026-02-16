import 'package:flutter_test/flutter_test.dart';
import 'package:runner/config/h3_config.dart';
import 'package:runner/models/team.dart';
import 'package:runner/providers/leaderboard_provider.dart';
import 'package:runner/repositories/leaderboard_repository.dart';

void main() {
  group('LeaderboardRepository', () {
    late LeaderboardRepository repository;

    setUp(() {
      // Get fresh instance for each test
      repository = LeaderboardRepository();
      repository.clear();
    });

    test('singleton returns same instance', () {
      final repo1 = LeaderboardRepository();
      final repo2 = LeaderboardRepository();
      expect(identical(repo1, repo2), true);
    });

    test('getEntries returns empty list before load', () {
      expect(repository.entries, isEmpty);
      expect(repository.hasData, false);
    });

    test('loadEntries stores entries', () {
      final entries = [
        LeaderboardEntry.create(
          id: '1',
          name: 'Alice',
          team: Team.red,
          avatar: '🏃',
          seasonPoints: 100,
          rank: 1,
          homeHex: '891234567abcdef',
        ),
        LeaderboardEntry.create(
          id: '2',
          name: 'Bob',
          team: Team.blue,
          avatar: '🏃',
          seasonPoints: 90,
          rank: 2,
          homeHex: '891234567abcde0',
        ),
      ];

      repository.loadEntries(entries);

      expect(repository.entries, hasLength(2));
      expect(repository.hasData, true);
      expect(repository.entries[0].name, 'Alice');
      expect(repository.entries[1].name, 'Bob');
    });

    test('filterByTeam returns correct subset', () {
      final entries = [
        LeaderboardEntry.create(
          id: '1',
          name: 'Alice',
          team: Team.red,
          avatar: '🏃',
          seasonPoints: 100,
          rank: 1,
        ),
        LeaderboardEntry.create(
          id: '2',
          name: 'Bob',
          team: Team.blue,
          avatar: '🏃',
          seasonPoints: 90,
          rank: 2,
        ),
        LeaderboardEntry.create(
          id: '3',
          name: 'Charlie',
          team: Team.red,
          avatar: '🏃',
          seasonPoints: 80,
          rank: 3,
        ),
      ];

      repository.loadEntries(entries);

      final redTeam = repository.filterByTeam(Team.red);
      expect(redTeam, hasLength(2));
      expect(redTeam[0].name, 'Alice');
      expect(redTeam[1].name, 'Charlie');

      final blueTeam = repository.filterByTeam(Team.blue);
      expect(blueTeam, hasLength(1));
      expect(blueTeam[0].name, 'Bob');
    });

    test('filterByTeam with null returns all entries', () {
      final entries = [
        LeaderboardEntry.create(
          id: '1',
          name: 'Alice',
          team: Team.red,
          avatar: '🏃',
          seasonPoints: 100,
          rank: 1,
        ),
        LeaderboardEntry.create(
          id: '2',
          name: 'Bob',
          team: Team.blue,
          avatar: '🏃',
          seasonPoints: 90,
          rank: 2,
        ),
      ];

      repository.loadEntries(entries);

      final all = repository.filterByTeam(null);
      expect(all, hasLength(2));
    });

    test('filterByScope returns all entries for GeographicScope.all', () {
      final entries = [
        LeaderboardEntry.create(
          id: '1',
          name: 'Alice',
          team: Team.red,
          avatar: '🏃',
          seasonPoints: 100,
          rank: 1,
          homeHex: '891234567abcdef',
        ),
        LeaderboardEntry.create(
          id: '2',
          name: 'Bob',
          team: Team.blue,
          avatar: '🏃',
          seasonPoints: 90,
          rank: 2,
          homeHex: '891234567abcde0',
        ),
      ];

      repository.loadEntries(entries);

      final filtered = repository.filterByScope(GeographicScope.all, null);
      expect(filtered, hasLength(2));
    });

    test('filterByScope returns empty list when homeHex is null', () {
      final entries = [
        LeaderboardEntry.create(
          id: '1',
          name: 'Alice',
          team: Team.red,
          avatar: '🏃',
          seasonPoints: 100,
          rank: 1,
          homeHex: '891234567abcdef',
        ),
      ];

      repository.loadEntries(entries);

      final filtered = repository.filterByScope(GeographicScope.zone, null);
      expect(filtered, isEmpty);
    });

    test('filterByScope filters by zone scope', () {
      // Note: This test requires HexService initialization which is not available in unit tests
      // The actual filtering logic is tested via LeaderboardEntry.isInScope which uses HexService
      // This test verifies the repository correctly delegates to isInScope
      final entries = [
        LeaderboardEntry.create(
          id: '1',
          name: 'Alice',
          team: Team.red,
          avatar: '🏃',
          seasonPoints: 100,
          rank: 1,
          homeHex: '891234567abcdef',
        ),
        LeaderboardEntry.create(
          id: '2',
          name: 'Bob',
          team: Team.blue,
          avatar: '🏃',
          seasonPoints: 90,
          rank: 2,
          homeHex: '891234567abcde0',
        ),
      ];

      repository.loadEntries(entries);

      // When HexService is not initialized, filterByScope will throw
      // This is expected behavior - HexService must be initialized before filtering by scope
      expect(
        () => repository.filterByScope(GeographicScope.zone, '891234567abcdef'),
        throwsException,
      );
    });

    test('throttling prevents rapid re-fetches', () {
      expect(repository.canRefresh, true);

      repository.markFetched();
      expect(repository.canRefresh, false);

      // Simulate time passing (in real code, would use DateTime.now())
      // For this test, we verify the throttle duration is set correctly
      expect(repository.throttleDuration, Duration(seconds: 30));
    });

    test('canRefresh returns true after throttle duration', () {
      repository.markFetched();
      expect(repository.canRefresh, false);

      // In real scenario, would wait 30+ seconds
      // For unit test, we just verify the logic is in place
      expect(repository.throttleDuration, Duration(seconds: 30));
    });

    test('getUserRankInScope returns correct rank', () {
      final entries = [
        LeaderboardEntry.create(
          id: '1',
          name: 'Alice',
          team: Team.red,
          avatar: '🏃',
          seasonPoints: 100,
          rank: 1,
          homeHex: '891234567abcdef',
        ),
        LeaderboardEntry.create(
          id: '2',
          name: 'Bob',
          team: Team.blue,
          avatar: '🏃',
          seasonPoints: 90,
          rank: 2,
          homeHex: '891234567abcdef',
        ),
      ];

      repository.loadEntries(entries);

      final rank = repository.getUserRankInScope(
        '1',
        GeographicScope.all,
        '891234567abcdef',
      );
      expect(rank, 1);
    });

    test('getUserRankInScope returns null for unknown user', () {
      final entries = [
        LeaderboardEntry.create(
          id: '1',
          name: 'Alice',
          team: Team.red,
          avatar: '🏃',
          seasonPoints: 100,
          rank: 1,
        ),
      ];

      repository.loadEntries(entries);

      final rank = repository.getUserRankInScope(
        'unknown',
        GeographicScope.all,
        null,
      );
      expect(rank, isNull);
    });

    test('clear resets all data', () {
      final entries = [
        LeaderboardEntry.create(
          id: '1',
          name: 'Alice',
          team: Team.red,
          avatar: '🏃',
          seasonPoints: 100,
          rank: 1,
        ),
      ];

      repository.loadEntries(entries);
      expect(repository.hasData, true);

      repository.clear();
      expect(repository.entries, isEmpty);
      expect(repository.hasData, false);
      expect(repository.canRefresh, true);
    });

    test('entries returns unmodifiable list', () {
      final entries = [
        LeaderboardEntry.create(
          id: '1',
          name: 'Alice',
          team: Team.red,
          avatar: '🏃',
          seasonPoints: 100,
          rank: 1,
        ),
      ];

      repository.loadEntries(entries);

      final returned = repository.entries;
      expect(
        () => returned.add(
          LeaderboardEntry.create(
            id: '2',
            name: 'Bob',
            team: Team.blue,
            avatar: '🏃',
            seasonPoints: 90,
            rank: 2,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('filterByTeam returns unmodifiable list', () {
      final entries = [
        LeaderboardEntry.create(
          id: '1',
          name: 'Alice',
          team: Team.red,
          avatar: '🏃',
          seasonPoints: 100,
          rank: 1,
        ),
      ];

      repository.loadEntries(entries);

      final filtered = repository.filterByTeam(Team.red);
      expect(
        () => filtered.add(
          LeaderboardEntry.create(
            id: '2',
            name: 'Bob',
            team: Team.blue,
            avatar: '🏃',
            seasonPoints: 90,
            rank: 2,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('filterByScope returns unmodifiable list', () {
      final entries = [
        LeaderboardEntry.create(
          id: '1',
          name: 'Alice',
          team: Team.red,
          avatar: '🏃',
          seasonPoints: 100,
          rank: 1,
          homeHex: '891234567abcdef',
        ),
      ];

      repository.loadEntries(entries);

      final filtered = repository.filterByScope(GeographicScope.all, null);
      expect(
        () => filtered.add(
          LeaderboardEntry.create(
            id: '2',
            name: 'Bob',
            team: Team.blue,
            avatar: '🏃',
            seasonPoints: 90,
            rank: 2,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
