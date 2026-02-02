import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner/models/team.dart';
import 'package:runner/models/user_model.dart';
import 'package:runner/repositories/user_repository.dart';

void main() {
  group('UserRepository', () {
    late UserRepository repository;
    late Directory testDir;

    setUpAll(() {
      // Create a temporary directory for testing
      testDir = Directory.systemTemp.createTempSync('user_repo_test_');
    });

    setUp(() {
      // Reset singleton for each test
      UserRepository.resetForTesting();
      UserRepository.setTestDirectory(testDir);
      repository = UserRepository();
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

    test('singleton returns same instance', () {
      final repo1 = UserRepository();
      final repo2 = UserRepository();
      expect(identical(repo1, repo2), isTrue);
    });

    test('getUser returns null before initialization', () {
      expect(repository.currentUser, isNull);
      expect(repository.hasUser, isFalse);
    });

    test('setUser updates currentUser and notifies listeners', () async {
      final user = UserModel(
        id: 'user123',
        name: 'Test Runner',
        team: Team.red,
        seasonPoints: 100,
      );

      var notified = false;
      repository.addListener(() {
        notified = true;
      });

      await repository.setUser(user);

      expect(repository.currentUser, equals(user));
      expect(repository.hasUser, isTrue);
      expect(repository.userTeam, equals(Team.red));
      expect(repository.seasonPoints, equals(100));
      expect(notified, isTrue);
    });

    test('updateSeasonPoints modifies points and notifies listeners', () async {
      final user = UserModel(
        id: 'user123',
        name: 'Test Runner',
        team: Team.red,
        seasonPoints: 100,
      );
      await repository.setUser(user);

      var notified = false;
      repository.addListener(() {
        notified = true;
      });

      repository.updateSeasonPoints(150);

      expect(repository.seasonPoints, equals(150));
      expect(repository.currentUser?.seasonPoints, equals(150));
      expect(notified, isTrue);
    });

    test(
      'defectToPurple changes team to purple and preserves points',
      () async {
        final user = UserModel(
          id: 'user123',
          name: 'Test Runner',
          team: Team.red,
          seasonPoints: 250,
        );
        await repository.setUser(user);

        var notified = false;
        repository.addListener(() {
          notified = true;
        });

        repository.defectToPurple();

        expect(repository.userTeam, equals(Team.purple));
        expect(repository.seasonPoints, equals(250)); // Points preserved
        expect(repository.currentUser?.isPurple, isTrue);
        expect(notified, isTrue);
      },
    );

    test('saveToDisk persists user to local_user.json', () async {
      final user = UserModel(
        id: 'user123',
        name: 'Test Runner',
        team: Team.blue,
        seasonPoints: 500,
        avatar: '🏃',
        totalDistanceKm: 42.5,
      );
      await repository.setUser(user);

      await repository.saveToDisk();

      // Verify file was created and contains correct data
      final file = File('${testDir.path}/local_user.json');
      expect(await file.exists(), isTrue);

      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;

      expect(json['id'], equals('user123'));
      expect(json['name'], equals('Test Runner'));
      expect(json['team'], equals('blue'));
      expect(json['seasonPoints'], equals(500));
    });

    test('loadFromDisk restores user from local_user.json', () async {
      // Create a test file with user data
      final testUser = UserModel(
        id: 'user456',
        name: 'Loaded Runner',
        team: Team.purple,
        seasonPoints: 300,
        avatar: '🏃',
      );

      final file = File('${testDir.path}/local_user.json');
      await file.writeAsString(jsonEncode(testUser.toJson()));

      // Load from disk
      await repository.loadFromDisk();

      expect(repository.currentUser, isNotNull);
      expect(repository.currentUser?.id, equals('user456'));
      expect(repository.currentUser?.name, equals('Loaded Runner'));
      expect(repository.currentUser?.team, equals(Team.purple));
      expect(repository.seasonPoints, equals(300));
    });

    test('loadFromDisk returns null when file does not exist', () async {
      await repository.loadFromDisk();
      expect(repository.currentUser, isNull);
    });

    test('persistence roundtrip: save then load', () async {
      final originalUser = UserModel(
        id: 'user789',
        name: 'Roundtrip Runner',
        team: Team.red,
        seasonPoints: 750,
        avatar: '🏃',
        totalDistanceKm: 100.0,
        avgPaceMinPerKm: 6.5,
        totalRuns: 25,
      );

      // Save
      await repository.setUser(originalUser);
      await repository.saveToDisk();

      // Reset and load
      UserRepository.resetForTesting();
      UserRepository.setTestDirectory(testDir);
      final newRepository = UserRepository();
      await newRepository.loadFromDisk();

      expect(newRepository.currentUser?.id, equals('user789'));
      expect(newRepository.currentUser?.name, equals('Roundtrip Runner'));
      expect(newRepository.currentUser?.team, equals(Team.red));
      expect(newRepository.currentUser?.seasonPoints, equals(750));
      expect(newRepository.currentUser?.totalDistanceKm, equals(100.0));
      expect(newRepository.currentUser?.avgPaceMinPerKm, equals(6.5));
      expect(newRepository.currentUser?.totalRuns, equals(25));
    });

    test('clear removes currentUser and notifies listeners', () async {
      final user = UserModel(
        id: 'user123',
        name: 'Test Runner',
        team: Team.red,
      );
      await repository.setUser(user);
      expect(repository.hasUser, isTrue);

      var notified = false;
      repository.addListener(() {
        notified = true;
      });

      repository.clear();

      expect(repository.currentUser, isNull);
      expect(repository.hasUser, isFalse);
      expect(repository.seasonPoints, equals(0));
      expect(notified, isTrue);
    });

    test('multiple listeners are notified on state changes', () async {
      var notified1 = false;
      var notified2 = false;

      repository.addListener(() {
        notified1 = true;
      });
      repository.addListener(() {
        notified2 = true;
      });

      final user = UserModel(
        id: 'user123',
        name: 'Test Runner',
        team: Team.red,
      );
      await repository.setUser(user);

      expect(notified1, isTrue);
      expect(notified2, isTrue);
    });

    test('userTeam returns null when no user is set', () {
      expect(repository.userTeam, isNull);
    });

    test('seasonPoints returns 0 when no user is set', () {
      expect(repository.seasonPoints, equals(0));
    });
  });
}
