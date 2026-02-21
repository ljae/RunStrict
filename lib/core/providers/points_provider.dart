import 'dart:math' show max;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/local_storage.dart';
import 'user_repository_provider.dart';

class PointsState {
  final int serverTodayBaseline;
  final int localUnsyncedToday;

  const PointsState({
    this.serverTodayBaseline = 0,
    this.localUnsyncedToday = 0,
  });

  int get todayFlipPoints => serverTodayBaseline + localUnsyncedToday;

  PointsState copyWith({
    int? serverTodayBaseline,
    int? localUnsyncedToday,
  }) {
    return PointsState(
      serverTodayBaseline: serverTodayBaseline ?? this.serverTodayBaseline,
      localUnsyncedToday: localUnsyncedToday ?? this.localUnsyncedToday,
    );
  }
}

/// Manages flip points with hybrid calculation for today's points.
///
/// Season points delegate to UserRepositoryNotifier (single source of truth).
/// Today's flip points = server baseline + local unsynced runs
class PointsNotifier extends Notifier<PointsState> {
  late final LocalStorage _localStorage;

  @override
  PointsState build() {
    _localStorage = LocalStorage();
    return const PointsState();
  }

  /// Season points from UserRepository
  int get seasonPoints {
    final userRepo = ref.read(userRepositoryProvider.notifier);
    return userRepo.seasonPoints;
  }

  /// Total season points for header display.
  /// = server season total + local unsynced today
  int get totalSeasonPoints => seasonPoints + state.localUnsyncedToday;

  /// Today's flip points using hybrid calculation.
  int get todayFlipPoints => state.todayFlipPoints;

  /// Add points from a run (updates local unsynced today).
  void addRunPoints(int points) {
    state = state.copyWith(
      localUnsyncedToday: state.localUnsyncedToday + points,
    );
  }

  void setSeasonPoints(int points) {
    ref.read(userRepositoryProvider.notifier).updateSeasonPoints(points);
  }

  void setServerTodayBaseline(int points) {
    state = state.copyWith(serverTodayBaseline: points);
  }

  Future<void> refreshLocalUnsyncedPoints() async {
    try {
      final unsynced = await _localStorage.sumUnsyncedTodayPoints();
      state = state.copyWith(localUnsyncedToday: unsynced);
    } catch (e) {
      debugPrint('PointsNotifier: Failed to refresh local unsynced points - $e');
    }
  }

  Future<void> refreshFromLocalTotal() async {
    try {
      final localTotal = await _localStorage.sumAllTodayPoints();
      final localUnsynced = await _localStorage.sumUnsyncedTodayPoints();
      state = PointsState(
        serverTodayBaseline: localTotal - localUnsynced,
        localUnsyncedToday: localUnsynced,
      );
    } catch (e) {
      debugPrint('PointsNotifier: Failed to refresh from local total - $e');
    }
  }

  /// Called after a successful Final Sync.
  void onRunSynced(int syncedPoints) {
    // Update seasonPoints FIRST so that when PointsState change fires,
    // totalSeasonPoints (= seasonPoints + localUnsyncedToday) is already
    // correct. Otherwise the widget sees a transient dip then a jump,
    // causing an unwanted flip animation.
    final currentSeason = seasonPoints;
    ref.read(userRepositoryProvider.notifier).updateSeasonPoints(
      currentSeason + syncedPoints,
    );

    final newBaseline = state.serverTodayBaseline + syncedPoints;
    final newUnsynced = max(0, state.localUnsyncedToday - syncedPoints);
    state = PointsState(
      serverTodayBaseline: newBaseline,
      localUnsyncedToday: newUnsynced,
    );
  }

  Future<void> markLocalRunsSynced() async {
    await _localStorage.markTodayRunsSynced();
    state = state.copyWith(localUnsyncedToday: 0);
  }

  void resetForNewSeason() {
    ref.read(userRepositoryProvider.notifier).updateSeasonPoints(0);
    state = const PointsState();
  }

  void resetTodayPoints() {
    state = const PointsState();
  }

  static String formatPoints(int points) {
    if (points < 1000) return points.toString();
    final str = points.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  List<int> getDigits(int value, {int minDigits = 1}) {
    if (value == 0) return List.filled(minDigits, 0);

    final digits = <int>[];
    var remaining = value;
    while (remaining > 0) {
      digits.insert(0, remaining % 10);
      remaining ~/= 10;
    }

    while (digits.length < minDigits) {
      digits.insert(0, 0);
    }

    return digits;
  }
}

final pointsProvider = NotifierProvider<PointsNotifier, PointsState>(
  PointsNotifier.new,
);
