import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/run.dart';
import '../../../data/models/location_point.dart';
import '../services/location_service.dart';
import '../services/run_tracker.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/hex_service.dart';
import '../../../core/services/app_lifecycle_manager.dart';
import '../../../core/providers/user_repository_provider.dart';
import '../services/voice_announcement_service.dart';
import '../../../data/models/team.dart';
import '../../../data/repositories/hex_repository.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/utils/gmt2_date_utils.dart';
import '../../auth/providers/app_state_provider.dart';
import '../../team/providers/buff_provider.dart';
import '../../map/providers/hex_data_provider.dart';
import '../../../core/providers/points_provider.dart';

enum RunEvent { pointEarned }

class RunState {
  final Run? activeRun;
  final List<Run> runHistory;
  final Map<String, dynamic>? totalStats;
  final bool isLoading;
  final String? error;
  final bool isStartingRun;
  final bool isStopping;
  final Duration duration;
  final bool isMetric;
  final int routeVersion;
  final LatLng? liveLocation;
  final double? liveHeading;

  const RunState({
    this.activeRun,
    this.runHistory = const [],
    this.totalStats,
    this.isLoading = false,
    this.error,
    this.isStartingRun = false,
    this.isStopping = false,
    this.duration = Duration.zero,
    this.isMetric = true,
    this.routeVersion = 0,
    this.liveLocation,
    this.liveHeading,
  });

  /// Returns true if run is active, starting, or stopping
  bool get isRunning =>
      isStartingRun || isStopping || (activeRun != null && activeRun!.isActive);

  RunState copyWith({
    Run? Function()? activeRun,
    List<Run>? runHistory,
    Map<String, dynamic>? Function()? totalStats,
    bool? isLoading,
    String? Function()? error,
    bool? isStartingRun,
    bool? isStopping,
    Duration? duration,
    bool? isMetric,
    int? routeVersion,
    LatLng? Function()? liveLocation,
    double? Function()? liveHeading,
  }) {
    return RunState(
      activeRun: activeRun != null ? activeRun() : this.activeRun,
      runHistory: runHistory ?? this.runHistory,
      totalStats: totalStats != null ? totalStats() : this.totalStats,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      isStartingRun: isStartingRun ?? this.isStartingRun,
      isStopping: isStopping ?? this.isStopping,
      duration: duration ?? this.duration,
      isMetric: isMetric ?? this.isMetric,
      routeVersion: routeVersion ?? this.routeVersion,
      liveLocation: liveLocation != null ? liveLocation() : this.liveLocation,
      liveHeading: liveHeading != null ? liveHeading() : this.liveHeading,
    );
  }
}

/// Provider for managing run state and coordinating services.
class RunNotifier extends Notifier<RunState> {
  late final LocationService _locationService;
  late final RunTracker _runTracker;
  late final StorageService _storageService;
  late final SupabaseService _supabaseService;

  StreamSubscription<LocationPoint>? _locationSubscription;
  Timer? _tickTimer;
  final _eventController = StreamController<RunEvent>.broadcast();

  Stream<RunEvent> get eventStream => _eventController.stream;

  @override
  RunState build() {
    _locationService = LocationService();
    _runTracker = RunTracker();
    _storageService = LocalStorage();
    _supabaseService = SupabaseService();

    ref.onDispose(() {
      _stopTimer();
      _locationSubscription?.cancel();
      _locationService.dispose();
      _runTracker.dispose();
      _storageService.close();
      _eventController.close();
    });

    return const RunState();
  }

  /// Returns true if run is active, starting, or stopping
  bool get isRunning =>
      state.isStartingRun || state.isStopping || (state.activeRun != null && state.activeRun!.isActive);

  // Getters for UI
  double get currentSpeed {
    if (!isRunning || state.activeRun == null) return 0.0;
    final distanceKm = state.activeRun!.distanceKm;
    final durationHours = state.duration.inSeconds / 3600.0;
    if (distanceKm <= 0 || durationHours <= 0) return 0.0;
    final speedKmh = distanceKm / durationHours;
    if (speedKmh.isInfinite || speedKmh.isNaN || speedKmh > 50) return 0.0;
    return state.isMetric ? speedKmh : speedKmh * 0.621371;
  }

  String get speedUnit => state.isMetric ? 'KM/H' : 'MPH';

  double get displayDistance {
    final distKm = state.activeRun?.distanceKm ?? 0.0;
    return state.isMetric ? distKm : distKm * 0.621371;
  }

  String get distanceUnit => state.isMetric ? 'KM' : 'MI';

  void toggleUnit() {
    state = state.copyWith(isMetric: !state.isMetric);
  }

  GpsSignalQuality get signalQuality {
    return _locationService.isTracking
        ? GpsSignalQuality.excellent
        : GpsSignalQuality.none;
  }

  String get formattedTime {
    final h = state.duration.inHours.toString().padLeft(2, '0');
    final m = (state.duration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (state.duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get formattedPace {
    if (state.activeRun == null) return "-'--";
    final distanceKm = state.activeRun!.distanceKm;
    final durationMinutes = state.duration.inSeconds / 60.0;
    if (distanceKm <= 0 || durationMinutes <= 0) return "-'--";
    final pace = durationMinutes / distanceKm;
    if (pace.isInfinite || pace.isNaN || pace > 99) return "-'--";
    final m = pace.floor();
    final s = ((pace - m) * 60).round();
    return "$m'${s.toString().padLeft(2, '0')}";
  }

  double get distance => state.activeRun?.distanceKm ?? 0.0;
  List<LocationPoint> get routePoints => state.activeRun?.route ?? [];
  int get routeVersion => state.routeVersion;
  LatLng? get liveLocation => state.liveLocation;
  double? get liveHeading => state.liveHeading;

  int get buffMultiplier => ref.read(buffProvider).effectiveMultiplier;

  /// Initialize the provider and load data
  Future<void> doInitialize() async {
    state = state.copyWith(isLoading: true);
    try {
      await _storageService.initialize();
      await _recoverFromCheckpoint();
      await _loadRunHistory();
      await _loadTotalStats();
      state = state.copyWith(error: () => null, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: () => 'Failed to initialize: $e', isLoading: false);
    }
  }

  Future<void> _recoverFromCheckpoint() async {
    final storage = _storageService;
    if (storage is! LocalStorage) return;

    final localStorage = storage;
    final checkpoint = await localStorage.getRunCheckpoint();
    if (checkpoint == null) return;

    debugPrint('RunNotifier: Recovering run from checkpoint');

    try {
      final runId = checkpoint['run_id'] as String;
      final teamName = checkpoint['team_at_run'] as String;
      final startTimeMs = checkpoint['start_time'] as int;
      final distanceMeters = (checkpoint['distance_meters'] as num).toDouble();
      final hexesColored = (checkpoint['hexes_colored'] as num).toInt();
      final capturedStr = checkpoint['captured_hex_ids'] as String;
      final buffMult = (checkpoint['buff_multiplier'] as num?)?.toInt() ?? 1;
      final configSnapshot = checkpoint['config_snapshot'] as String?;

      if (configSnapshot != null) {
        debugPrint('RunNotifier: Checkpoint has config_snapshot (${configSnapshot.length} chars)');
      }

      final hexPath = capturedStr.isNotEmpty
          ? capturedStr.split(',')
          : <String>[];

      final startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
      final endTime = DateTime.fromMillisecondsSinceEpoch(
        checkpoint['last_updated'] as int,
      );
      final durationSeconds = endTime.difference(startTime).inSeconds;

      final recoveredRun = Run(
        id: runId,
        startTime: startTime,
        endTime: endTime,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        hexesColored: hexesColored,
        teamAtRun: Team.values.byName(teamName),
        hexPath: hexPath,
        buffMultiplier: buffMult,
        syncStatus: 'pending',
      );

      final flipPoints = hexesColored * buffMult;

      await localStorage.saveRunWithSyncTracking(
        recoveredRun,
        flipPoints: flipPoints,
      );

      debugPrint(
        'RunNotifier: Recovered run $runId '
        '(${hexPath.length} hexes, ${distanceMeters.toStringAsFixed(0)}m)',
      );

      await localStorage.clearRunCheckpoint();
    } catch (e) {
      debugPrint('RunNotifier: Failed to recover from checkpoint - $e');
      await localStorage.clearRunCheckpoint();
    }
  }

  /// Start a new run
  Future<void> startRun({required Team team}) async {
    if (isRunning) {
      throw StateError('A run is already in progress');
    }

    state = state.copyWith(
      error: () => null,
      isStartingRun: true,
      duration: Duration.zero,
    );
    _startTimer();

    try {
      await VoiceAnnouncementService().initialize();

      ref.read(buffProvider.notifier).freezeForRun();

      await _locationService.startTracking();

      final runId = const Uuid().v4();

      ref.read(hexDataProvider.notifier).clearCapturedHexes();

      final localDb = _storageService is LocalStorage ? _storageService as LocalStorage : null;
      _runTracker.setCallbacks(
        onHexCapture: _handleHexCapture,
        onTierChange: (oldTier, newTier) {
          state = state.copyWith(routeVersion: state.routeVersion + 1);
        },
        onCheckpoint: localDb != null
            ? (checkpoint) {
                checkpoint['buff_multiplier'] = ref.read(buffProvider).effectiveMultiplier;
                localDb.saveRunCheckpoint(checkpoint);
              }
            : null,
        onLapCompleted: (lapNumber, paceSecPerKm) {
          VoiceAnnouncementService().announceKilometer(lapNumber, paceSecPerKm);
        },
      );

      _runTracker.startNewRun(
        _locationService.locationStream,
        runId,
        team: team,
      );

      state = state.copyWith(
        activeRun: () => _runTracker.currentRun,
        isStartingRun: false,
      );

      VoiceAnnouncementService().announceRunStart();

      _locationSubscription = _locationService.locationStream.listen((point) {
        final location = LatLng(point.latitude, point.longitude);
        final hexId = HexService().getHexId(location, 9);
        ref.read(hexDataProvider.notifier).updateUserLocation(location, hexId);

        final currentRun = _runTracker.currentRun;
        final newLength = currentRun?.route.length ?? 0;
        final oldLength = state.activeRun?.route.length ?? 0;
        // Extract GPS heading (sensor-fused by Geolocator)
        // heading == -1 or 0 means unavailable on some platforms
        final gpsHeading = (point.heading != null && point.heading! > 0)
            ? point.heading
            : null;
        if (newLength > oldLength) {
          // Route grew — trigger full redraw (route line + hexes)
          state = state.copyWith(
            activeRun: () => currentRun,
            liveLocation: () => location,
            liveHeading: () => gpsHeading,
            routeVersion: state.routeVersion + 1,
          );
        } else {
          // No new route point — update live location + heading only
          state = state.copyWith(
            activeRun: () => currentRun,
            liveLocation: () => location,
            liveHeading: () => gpsHeading,
          );
        }
      });
    } on LocationPermissionException {
      _stopTimer();
      ref.read(buffProvider.notifier).unfreezeAfterRun();
      await _locationService.stopTracking();
      state = state.copyWith(isStartingRun: false);
      rethrow;
    } catch (e) {
      _stopTimer();
      ref.read(buffProvider.notifier).unfreezeAfterRun();
      await _locationService.stopTracking();
      state = state.copyWith(
        isStartingRun: false,
        error: () => 'Failed to start run: $e',
      );
      rethrow;
    }
  }

  bool _handleHexCapture(String hexId, Team runnerTeam) {
    final hexNotifier = ref.read(hexDataProvider.notifier);
    final result = hexNotifier.updateHexColor(hexId, runnerTeam);

    if (result == HexUpdateResult.sameTeam) {
      VoiceAnnouncementService().announceFlipFailed();
    }

    if (result == HexUpdateResult.flipped) {
      VoiceAnnouncementService().announceFlip();

      final effectiveMultiplier = ref.read(buffProvider).effectiveMultiplier;
      ref.read(pointsProvider.notifier).addRunPoints(effectiveMultiplier);

      debugPrint(
        'POINTS ADDED: hexId=$hexId, '
        'effectiveMultiplier=$effectiveMultiplier',
      );
      _eventController.add(RunEvent.pointEarned);
      return true;
    }

    return false;
  }

  void _startTimer() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        duration: state.duration + const Duration(seconds: 1),
      );
    });
  }

  void _stopTimer() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  /// Stop the current run and save to history
  Future<List<String>> stopRun() async {
    if (!isRunning) return [];

    state = state.copyWith(isStopping: true, isLoading: true, error: () => null);

    try {
      _stopTimer();
      final result = _runTracker.stopRun();
      await _locationService.stopTracking();

      await _locationSubscription?.cancel();
      _locationSubscription = null;

      await VoiceAnnouncementService().dispose();

      final effectiveMultiplier = ref.read(buffProvider).effectiveMultiplier;
      ref.read(buffProvider.notifier).unfreezeAfterRun();

      if (result != null) {
        final capturedHexIds = result.capturedHexIds;

        final completedRun = result.session.copyWith(
          cv: result.cv,
          durationSeconds: state.duration.inSeconds,
          hexPath: capturedHexIds,
          hexParents: result.capturedHexParents,
          buffMultiplier: effectiveMultiplier,
          runDate: Gmt2DateUtils.toGmt2DateString(DateTime.now()),
        );

        final flipPoints = completedRun.hexesColored * effectiveMultiplier;

        debugPrint(
          'RunNotifier: Run completed - '
          'distance=${completedRun.distanceKm.toStringAsFixed(2)}km, '
          'flips=${completedRun.hexesColored}, '
          'flipPoints=$flipPoints (multiplier=$effectiveMultiplier), '
          'stability=${completedRun.stabilityScore ?? "N/A"}, '
          'hexIds for sync: ${capturedHexIds.length}',
        );

        final storageService = _storageService;
        if (storageService is LocalStorage) {
          try {
            await storageService.saveRunWithSyncTracking(
              completedRun,
              flipPoints: flipPoints,
              cv: result.cv,
            );
          } catch (e) {
            debugPrint(
              'RunNotifier: saveRunWithSyncTracking failed ($e), '
              'attempting fallback saveRun',
            );
            try {
              await _storageService.saveRun(completedRun);
            } catch (e2) {
              debugPrint('RunNotifier: Fallback saveRun also failed: $e2');
            }
          }
        } else {
          await _storageService.saveRun(completedRun);
        }

        await _loadRunHistory();
        await _loadTotalStats();

        // === GUEST MODE: Skip server sync ===
        final isGuest = ref.read(appStateProvider).isGuest;
        if (isGuest) {
          debugPrint('RunNotifier: Guest mode - skipping Final Sync');
          if (storageService is LocalStorage) {
            await storageService.updateRunSyncStatus(completedRun.id, 'synced');
            await storageService.clearRunCheckpoint();
          }
          await ref.read(hexDataProvider.notifier).loadTodayRoutes();
          ref.read(hexDataProvider.notifier).clearUserLocation();
          state = state.copyWith(activeRun: () => null, liveLocation: () => null, routeVersion: 0);
          await AppLifecycleManager().onRunCompleted();
          return capturedHexIds;
        }

        // === THE FINAL SYNC ===
        bool syncSucceeded = false;

        final connectivityResults = await Connectivity().checkConnectivity();
        final hasNetwork = !connectivityResults.contains(ConnectivityResult.none);

        if (hasNetwork && capturedHexIds.isNotEmpty) {
          try {
            final syncResult = await _supabaseService.finalizeRun(completedRun);
            debugPrint(
              'RunNotifier: Final Sync completed - '
              'flips=${syncResult['flips']}, '
              'points=${syncResult['points_earned']}, '
              'multiplier=${syncResult['multiplier']}',
            );
            syncSucceeded = true;
          } catch (e) {
            debugPrint('RunNotifier: Final Sync failed - $e');
          }
        } else if (!hasNetwork && capturedHexIds.isNotEmpty) {
          debugPrint(
            'RunNotifier: No network - skipping Final Sync '
            '(${capturedHexIds.length} hexes pending)',
          );
        } else {
          syncSucceeded = true;
        }

        if (syncSucceeded && storageService is LocalStorage) {
          await storageService.updateRunSyncStatus(completedRun.id, 'synced');
          ref.read(pointsProvider.notifier).onRunSynced(flipPoints);
        }

        // Update ALL TIME aggregates from completed run (mirrors finalize_run server-side).
        // Done regardless of sync success — the run happened locally.
        final userRepoNotifier = ref.read(userRepositoryProvider.notifier);
        userRepoNotifier.updateAfterRun(
          distanceKm: completedRun.distanceKm,
          durationSeconds: completedRun.durationSeconds,
          cv: completedRun.cv,
        );
        await userRepoNotifier.saveToDisk();

        if (storageService is LocalStorage) {
          await storageService.clearRunCheckpoint();
        }

        // Reload today's routes so the just-completed run persists on the map
        await ref.read(hexDataProvider.notifier).loadTodayRoutes();

        ref.read(hexDataProvider.notifier).clearUserLocation();

        state = state.copyWith(
          activeRun: () => null,
          liveLocation: () => null,
          routeVersion: 0,
        );

        await AppLifecycleManager().onRunCompleted();

        return capturedHexIds;
      }

      // Reload today's routes for runs with no result
      await ref.read(hexDataProvider.notifier).loadTodayRoutes();

      ref.read(hexDataProvider.notifier).clearUserLocation();

      state = state.copyWith(
        activeRun: () => null,
        routeVersion: 0,
      );

      await AppLifecycleManager().onRunCompleted();

      return [];
    } catch (e) {
      state = state.copyWith(error: () => 'Failed to stop run: $e');
      return [];
    } finally {
      await _loadRunHistory();
      await _loadTotalStats();
      state = state.copyWith(isStopping: false, isLoading: false);
    }
  }

  Future<void> _loadRunHistory() async {
    try {
      var runs = await _storageService.getAllRuns();

      if (runs.isEmpty) {
        await _backfillFromServer();
        runs = await _storageService.getAllRuns();
      }

      debugPrint(
        'RunNotifier.loadRunHistory: Loaded ${runs.length} runs'
        '${runs.isNotEmpty ? " (latest: ${runs.first.id.substring(0, 8)}..., "
                  "${runs.first.distanceKm.toStringAsFixed(2)}km, "
                  "${runs.first.hexesColored} flips)" : ""}',
      );
      state = state.copyWith(runHistory: runs);
    } catch (e) {
      debugPrint('RunNotifier.loadRunHistory FAILED: $e');
      state = state.copyWith(error: () => 'Failed to load run history: $e');
    }
  }

  Future<void> loadRunHistory() => _loadRunHistory();

  Future<void> _backfillFromServer() async {
    try {
      final userId = _supabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      final rows = await _supabaseService.fetchRunHistory(userId);
      if (rows.isEmpty) return;

      debugPrint('RunNotifier._backfillFromServer: Found ${rows.length} runs on server, importing...');

      for (final row in rows) {
        final flipCount = (row['flip_count'] as num?)?.toInt() ?? 0;
        final flipPoints = (row['flip_points'] as num?)?.toInt() ?? 0;
        // run_history doesn't store buff_multiplier — derive from flip_points/flip_count
        final derivedBuff = (flipCount > 0) ? (flipPoints / flipCount).round().clamp(1, 10) : 1;

        final run = Run(
          id: row['id'] as String,
          startTime: DateTime.parse(row['start_time'] as String),
          endTime: row['end_time'] != null
              ? DateTime.parse(row['end_time'] as String)
              : null,
          distanceMeters: ((row['distance_km'] as num?)?.toDouble() ?? 0) * 1000,
          durationSeconds: (row['duration_seconds'] as num?)?.toInt() ?? 0,
          hexesColored: flipCount,
          teamAtRun: Team.values.byName(row['team_at_run'] as String? ?? 'red'),
          buffMultiplier: derivedBuff,
          cv: (row['cv'] as num?)?.toDouble(),
          syncStatus: 'synced',
          runDate: row['run_date']?.toString(),
        );
        await _storageService.saveRun(run);
      }

      debugPrint('RunNotifier._backfillFromServer: Imported ${rows.length} runs');
    } catch (e) {
      debugPrint('RunNotifier._backfillFromServer FAILED: $e');
    }
  }

  Future<void> _loadTotalStats() async {
    try {
      final stats = await _storageService.getTotalStats();
      state = state.copyWith(totalStats: () => stats);
    } catch (e) {
      state = state.copyWith(error: () => 'Failed to load stats: $e');
    }
  }

  Future<void> loadTotalStats() => _loadTotalStats();

  Future<void> deleteRun(String runId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _storageService.deleteRun(runId);
      await _loadRunHistory();
      await _loadTotalStats();
      state = state.copyWith(error: () => null, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: () => 'Failed to delete run: $e', isLoading: false);
    }
  }
}

final runProvider = NotifierProvider<RunNotifier, RunState>(
  RunNotifier.new,
);
