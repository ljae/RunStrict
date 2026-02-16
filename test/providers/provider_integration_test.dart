import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner/models/team.dart';
import 'package:runner/models/user_model.dart';
import 'package:runner/providers/app_state_provider.dart';
import 'package:runner/providers/leaderboard_provider.dart';
import 'package:runner/repositories/leaderboard_repository.dart';
import 'package:runner/repositories/user_repository.dart';
import 'package:runner/services/points_service.dart';

void main() {
  group('Provider-Repository Integration Tests', () {
    late Directory testDir;

    setUpAll(() {
      // Create a temporary directory for testing
      testDir = Directory.systemTemp.createTempSync(
        'provider_integration_test_',
      );
    });

    setUp(() {
      // Reset singletons for each test
      UserRepository.resetForTesting();
      UserRepository.setTestDirectory(testDir);
      LeaderboardRepository().clear();
    });

    tearDown(() async {
      // Clean up test files
      final file = File('${testDir.path}/local_user.json');
      if (await file.exists()) {
        await file.delete();
      }
    });

    tearDownAll(() {
      // Clean up test directory
      if (testDir.existsSync()) {
        testDir.deleteSync(recursive: true);
      }
    });

    group('AppStateProvider-UserRepository consistency', () {
      test(
        'AppStateProvider.currentUser returns UserRepository data',
        () async {
          final userRepo = UserRepository();
          final appState = AppStateProvider();

          // Initially both should be null
          expect(appState.currentUser, isNull);
          expect(userRepo.currentUser, isNull);

          // Set user through repository
          final user = UserModel(
            id: 'user123',
            name: 'Test Runner',
            team: Team.red,
            sex: 'other',
            birthday: DateTime(2000, 1, 1),
            seasonPoints: 100,
          );
          await userRepo.setUser(user);

          // AppStateProvider should reflect the same user
          expect(appState.currentUser, isNotNull);
          expect(appState.currentUser?.id, equals('user123'));
          expect(appState.currentUser?.name, equals('Test Runner'));
          expect(appState.currentUser?.team, equals(Team.red));
          expect(appState.currentUser?.seasonPoints, equals(100));
        },
      );

      test('AppStateProvider.setUser updates UserRepository', () async {
        final userRepo = UserRepository();
        final appState = AppStateProvider();

        final user = UserModel(
          id: 'user456',
          name: 'Provider User',
          team: Team.blue,
          sex: 'other',
          birthday: DateTime(2000, 1, 1),
          seasonPoints: 200,
        );

        // Set user through AppStateProvider
        appState.setUser(user);

        // UserRepository should have the same user
        expect(userRepo.currentUser, isNotNull);
        expect(userRepo.currentUser?.id, equals('user456'));
        expect(userRepo.currentUser?.name, equals('Provider User'));
        expect(userRepo.currentUser?.team, equals(Team.blue));
        expect(userRepo.seasonPoints, equals(200));
      });

      test('AppStateProvider receives UserRepository notifications', () async {
        final userRepo = UserRepository();
        final appState = AppStateProvider();

        var notificationCount = 0;
        appState.addListener(() {
          notificationCount++;
        });

        // Change user through repository
        final user = UserModel(
          id: 'user789',
          name: 'Notified User',
          team: Team.purple,
          sex: 'other',
          birthday: DateTime(2000, 1, 1),
          seasonPoints: 300,
        );
        await userRepo.setUser(user);

        // AppStateProvider should have received notification
        expect(notificationCount, greaterThan(0));
        expect(appState.currentUser?.id, equals('user789'));
      });
    });

    group('PointsService-UserRepository consistency', () {
      test(
        'PointsService.seasonPoints reflects UserRepository value',
        () async {
          final userRepo = UserRepository();
          final pointsService = PointsService();

          // Set user with initial points
          final user = UserModel(
            id: 'user123',
            name: 'Points User',
            team: Team.red,
            sex: 'other',
            birthday: DateTime(2000, 1, 1),
            seasonPoints: 500,
          );
          await userRepo.setUser(user);

          // PointsService should reflect the same season points
          expect(pointsService.seasonPoints, equals(500));
        },
      );

      test(
        'UserRepository.updateSeasonPoints updates PointsService.seasonPoints',
        () async {
          final userRepo = UserRepository();
          final pointsService = PointsService();

          // Set initial user
          final user = UserModel(
            id: 'user123',
            name: 'Points User',
            team: Team.red,
            sex: 'other',
            birthday: DateTime(2000, 1, 1),
            seasonPoints: 100,
          );
          await userRepo.setUser(user);
          expect(pointsService.seasonPoints, equals(100));

          // Update points through repository
          userRepo.updateSeasonPoints(250);

          // PointsService should reflect the change
          expect(pointsService.seasonPoints, equals(250));
        },
      );

      test('PointsService.addRunPoints updates UserRepository', () async {
        final userRepo = UserRepository();
        final pointsService = PointsService();

        // Set initial user
        final user = UserModel(
          id: 'user123',
          name: 'Run User',
          team: Team.blue,
          sex: 'other',
          birthday: DateTime(2000, 1, 1),
          seasonPoints: 1000,
        );
        await userRepo.setUser(user);

        // Add points through PointsService
        pointsService.addRunPoints(50);

        // UserRepository should reflect the updated points
        expect(userRepo.seasonPoints, equals(1050));
        expect(pointsService.seasonPoints, equals(1050));
      });

      test('PointsService.setSeasonPoints updates UserRepository', () async {
        final userRepo = UserRepository();
        final pointsService = PointsService();

        // Set initial user
        final user = UserModel(
          id: 'user123',
          name: 'Season User',
          team: Team.red,
          sex: 'other',
          birthday: DateTime(2000, 1, 1),
          seasonPoints: 100,
        );
        await userRepo.setUser(user);

        // Set points through PointsService
        pointsService.setSeasonPoints(999);

        // UserRepository should reflect the updated points
        expect(userRepo.seasonPoints, equals(999));
        expect(pointsService.seasonPoints, equals(999));
      });

      test('PointsService receives UserRepository notifications', () async {
        final userRepo = UserRepository();
        final pointsService = PointsService();

        // Set initial user
        final user = UserModel(
          id: 'user123',
          name: 'Notified User',
          team: Team.red,
          sex: 'other',
          birthday: DateTime(2000, 1, 1),
          seasonPoints: 100,
        );
        await userRepo.setUser(user);

        var notificationCount = 0;
        pointsService.addListener(() {
          notificationCount++;
        });

        // Update through repository
        userRepo.updateSeasonPoints(500);

        // PointsService should have received notification
        expect(notificationCount, greaterThan(0));
        expect(pointsService.seasonPoints, equals(500));
      });
    });

    group('LeaderboardProvider-LeaderboardRepository consistency', () {
      test(
        'LeaderboardProvider.entries returns LeaderboardRepository data',
        () {
          final leaderboardRepo = LeaderboardRepository();
          final leaderboardProvider = LeaderboardProvider();

          // Initially both should be empty
          expect(leaderboardProvider.entries, isEmpty);
          expect(leaderboardRepo.entries, isEmpty);

          // Load entries through repository
          final entries = [
            LeaderboardEntry.create(
              id: '1',
              name: 'Alice',
              team: Team.red,
              avatar: '',
              seasonPoints: 100,
              rank: 1,
            ),
            LeaderboardEntry.create(
              id: '2',
              name: 'Bob',
              team: Team.blue,
              avatar: '',
              seasonPoints: 90,
              rank: 2,
            ),
          ];
          leaderboardRepo.loadEntries(entries);

          // LeaderboardProvider should reflect the same entries
          expect(leaderboardProvider.entries, hasLength(2));
          expect(leaderboardProvider.entries[0].name, equals('Alice'));
          expect(leaderboardProvider.entries[1].name, equals('Bob'));
        },
      );

      test(
        'LeaderboardProvider receives LeaderboardRepository notifications',
        () {
          final leaderboardRepo = LeaderboardRepository();
          final leaderboardProvider = LeaderboardProvider();

          var notificationCount = 0;
          leaderboardProvider.addListener(() {
            notificationCount++;
          });

          // Load entries through repository
          final entries = [
            LeaderboardEntry.create(
              id: '1',
              name: 'Notified Entry',
              team: Team.purple,
              avatar: '',
              seasonPoints: 50,
              rank: 1,
            ),
          ];
          leaderboardRepo.loadEntries(entries);

          // LeaderboardProvider should have received notification
          expect(notificationCount, greaterThan(0));
          expect(leaderboardProvider.entries, hasLength(1));
        },
      );

      test('LeaderboardProvider.clear delegates to LeaderboardRepository', () {
        final leaderboardRepo = LeaderboardRepository();
        final leaderboardProvider = LeaderboardProvider();

        // Load entries
        final entries = [
          LeaderboardEntry.create(
            id: '1',
            name: 'Clear Entry',
            team: Team.red,
            avatar: '',
            seasonPoints: 100,
            rank: 1,
          ),
        ];
        leaderboardRepo.loadEntries(entries);
        expect(leaderboardProvider.entries, hasLength(1));

        // Clear through provider
        leaderboardProvider.clear();

        // Both should be empty
        expect(leaderboardProvider.entries, isEmpty);
        expect(leaderboardRepo.entries, isEmpty);
      });

      test('LeaderboardProvider.filterByTeam uses repository data', () {
        final leaderboardRepo = LeaderboardRepository();
        final leaderboardProvider = LeaderboardProvider();

        // Load mixed team entries
        final entries = [
          LeaderboardEntry.create(
            id: '1',
            name: 'Red1',
            team: Team.red,
            avatar: '',
            seasonPoints: 100,
            rank: 1,
          ),
          LeaderboardEntry.create(
            id: '2',
            name: 'Blue1',
            team: Team.blue,
            avatar: '',
            seasonPoints: 90,
            rank: 2,
          ),
          LeaderboardEntry.create(
            id: '3',
            name: 'Red2',
            team: Team.red,
            avatar: '',
            seasonPoints: 80,
            rank: 3,
          ),
        ];
        leaderboardRepo.loadEntries(entries);

        // Filter through provider
        final redTeam = leaderboardProvider.filterByTeam(Team.red);
        expect(redTeam, hasLength(2));
        expect(redTeam.every((e) => e.team == Team.red), isTrue);
      });
    });

    group('Cross-provider consistency', () {
      test(
        'AppStateProvider and PointsService stay in sync via UserRepository',
        () async {
          final userRepo = UserRepository();
          final appState = AppStateProvider();
          final pointsService = PointsService();

          // Set initial user
          final user = UserModel(
            id: 'syncUser',
            name: 'Sync Test',
            team: Team.red,
            sex: 'other',
            birthday: DateTime(2000, 1, 1),
            seasonPoints: 100,
          );
          appState.setUser(user);

          // All should reflect 100 points
          expect(appState.currentUser?.seasonPoints, equals(100));
          expect(pointsService.seasonPoints, equals(100));
          expect(userRepo.seasonPoints, equals(100));

          // Update via PointsService
          pointsService.addRunPoints(25);

          // All should reflect 125 points
          expect(appState.currentUser?.seasonPoints, equals(125));
          expect(pointsService.seasonPoints, equals(125));
          expect(userRepo.seasonPoints, equals(125));

          // Update via AppStateProvider
          appState.updateSeasonPoints(
            75,
          ); // Adds 75 to current (125 + 75 = 200)

          // All should reflect 200 points
          expect(appState.currentUser?.seasonPoints, equals(200));
          expect(pointsService.seasonPoints, equals(200));
          expect(userRepo.seasonPoints, equals(200));
        },
      );
    });
  });
}
