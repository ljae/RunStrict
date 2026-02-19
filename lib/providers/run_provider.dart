import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../models/run.dart';
import '../models/location_point.dart';
import '../services/location_service.dart';
import '../services/run_tracker.dart';
import '../services/storage_service.dart';
import '../services/points_service.dart';
import '../services/supabase_service.dart';
import '../services/buff_service.dart';
import '../models/team.dart';
import '../providers/hex_data_provider.dart';
import '../services/hex_service.dart';
import '../services/app_lifecycle_manager.dart';
import '../services/voice_announcement_service.dart';
import '../storage/local_storage.dart';
import '../utils/gmt2_date_utils.dart';

enum RunEvent { pointEarned }

/// Provider for managing run state and coordinating services.
///
/// Two states only:
/// - Ready: No active run. Waiting for user to start.
/// - Running: Active run with GPS tracking, distance, and hex flipping.
///
/// Data Flow:
/// LocationService.locationStream
///   → RunTracker._onLocationUpdate (distance + hex capture)
///   → RunProvider._locationSubscription (UI sync)
///   → notifyListeners() → UI rebuild
class RunProvider with ChangeNotifier {
  final LocationService _locationService;
  final RunTracker _runTracker;
  final StorageService _storageService;
  final SupabaseService _supabaseService;
  final BuffService _buffService;
  PointsService? _pointsService;

  Run? _activeRun;
  List<Run> _runHistory = [];
  Map<String, dynamic>? _totalStats;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<LocationPoint>? _locationSubscription;

  /// Flag to show stop button immediately while GPS initializes
  bool _isStartingRun = false;

  /// Flag to prevent app resume from racing with stopRun
  bool _isStopping = false;

  /// Buff multiplier for runs (from BuffService)

  // Event stream for transient UI feedback
  final _eventController = StreamController<RunEvent>.broadcast();
  Stream<RunEvent> get eventStream => _eventController.stream;

  // Route version counter - increments on each new point
  int _routeVersion = 0;

  RunProvider({
    required LocationService locationService,
    required RunTracker runTracker,
    required StorageService storageService,
    SupabaseService? supabaseService,
    BuffService? buffService,
    PointsService? pointsService,
  }) : _locationService = locationService,
       _runTracker = runTracker,
       _storageService = storageService,
       _supabaseService = supabaseService ?? SupabaseService(),
       _buffService = buffService ?? BuffService(),
       _pointsService = pointsService;

  /// Update the points service reference (for ProxyProvider)
  void updatePointsService(PointsService pointsService) {
    _pointsService = pointsService;
  }

  // Getters
  Run? get activeRun => _activeRun;
  List<Run> get runHistory => _runHistory;
  Map<String, dynamic>? get totalStats => _totalStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Returns true if run is active, starting, or stopping (Final Sync in progress).
  /// Prevents app resume from racing with stopRun and overwriting points.
  bool get isRunning =>
      _isStartingRun || _isStopping || (_activeRun != null && _activeRun!.isActive);

  // Timer state
  Timer? _tickTimer;
  Duration _duration = Duration.zero;
  bool _isMetric = true;

  bool get isMetric => _isMetric;
  Duration get duration => _duration;

  /// Current speed in km/h or mph
  ///
  /// During active run: calculates from UI timer (_duration) and distance
  /// After run completion: uses the stored pace from Run model
  double get currentSpeed {
    if (!isRunning || _activeRun == null) return 0.0;

    // Calculate pace from real-time data during active run
    final distanceKm = _activeRun!.distanceKm;
    final durationHours = _duration.inSeconds / 3600.0;

    if (distanceKm <= 0 || durationHours <= 0) return 0.0;

    final speedKmh = distanceKm / durationHours; // km/h
    if (speedKmh.isInfinite || speedKmh.isNaN || speedKmh > 50) return 0.0;

    return _isMetric ? speedKmh : speedKmh * 0.621371;
  }

  String get speedUnit => _isMetric ? 'KM/H' : 'MPH';

  double get displayDistance {
    final distKm = _activeRun?.distanceKm ?? 0.0;
    return _isMetric ? distKm : distKm * 0.621371;
  }

  String get distanceUnit => _isMetric ? 'KM' : 'MI';

  void toggleUnit() {
    _isMetric = !_isMetric;
    notifyListeners();
  }

  /// GPS signal quality
  GpsSignalQuality get signalQuality {
    return _locationService.isTracking
        ? GpsSignalQuality.excellent
        : GpsSignalQuality.none;
  }

  /// Formatted time duration
  String get formattedTime {
    final h = _duration.inHours.toString().padLeft(2, '0');
    final m = (_duration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Formatted pace
  ///
  /// During active run: calculates from UI timer (_duration) and distance
  /// After run completion: uses the stored durationSeconds in Run model
  String get formattedPace {
    if (_activeRun == null) return "-'--";

    // Calculate pace from real-time data during active run
    final distanceKm = _activeRun!.distanceKm;
    final durationMinutes = _duration.inSeconds / 60.0;

    if (distanceKm <= 0 || durationMinutes <= 0) return "-'--";

    final pace = durationMinutes / distanceKm; // min/km
    if (pace.isInfinite || pace.isNaN || pace > 99) return "-'--";

    final m = pace.floor();
    final s = ((pace - m) * 60).round();
    return "$m'${s.toString().padLeft(2, '0')}";
  }

  /// Distance in km
  double get distance => _activeRun?.distanceKm ?? 0.0;

  /// Route points for map
  List<LocationPoint> get routePoints => _activeRun?.route ?? [];

  /// Route version for efficient change detection
  int get routeVersion => _routeVersion;

  /// Initialize the provider and load data
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _storageService.initialize();
      await _recoverFromCheckpoint();
      await loadRunHistory();
      await loadTotalStats();
      _setError(null);
    } catch (e) {
      _setError('Failed to initialize: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Recover a partial run from checkpoint (crash recovery).
  ///
  /// If the app crashed during a run, the checkpoint contains enough
  /// data to save the run locally and attempt sync.
  Future<void> _recoverFromCheckpoint() async {
    final storage = _storageService;
    if (storage is! LocalStorage) return;

    final localStorage = storage;
    final checkpoint = await localStorage.getRunCheckpoint();
    if (checkpoint == null) return;

    debugPrint('RunProvider: Recovering run from checkpoint');

    try {
      final runId = checkpoint['run_id'] as String;
      final teamName = checkpoint['team_at_run'] as String;
      final startTimeMs = checkpoint['start_time'] as int;
      final distanceMeters = (checkpoint['distance_meters'] as num).toDouble();
      final hexesColored = (checkpoint['hexes_colored'] as num).toInt();
      final capturedStr = checkpoint['captured_hex_ids'] as String;
      final buffMult = (checkpoint['buff_multiplier'] as num?)?.toInt() ?? 1;

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
        'RunProvider: Recovered run $runId '
        '(${hexPath.length} hexes, ${distanceMeters.toStringAsFixed(0)}m)',
      );

      // Clear checkpoint after successful save
      await localStorage.clearRunCheckpoint();
    } catch (e) {
      debugPrint('RunProvider: Failed to recover from checkpoint - $e');
      // Clear corrupt checkpoint
      await localStorage.clearRunCheckpoint();
    }
  }

  /// Get the current buff multiplier from BuffService
  int get buffMultiplier => _buffService.getEffectiveMultiplier();

  /// Start a new run
  ///
  /// [team] - The team the runner belongs to
  Future<void> startRun({required Team team}) async {
    if (isRunning) {
      throw StateError('A run is already in progress');
    }

    _setError(null);

    // IMMEDIATELY show stop button - before any async work
    _isStartingRun = true;
    _duration = Duration.zero;
    _startTimer();
    notifyListeners();

    try {
      // Initialize voice announcements
      await VoiceAnnouncementService().initialize();

      // Freeze buff multiplier for this run
      _buffService.freezeForRun();

      // Now start GPS tracking (this may take a moment)
      await _locationService.startTracking();

      // Generate unique run ID
      final runId = const Uuid().v4();

      // Clear any captured hexes from previous runs
      HexDataProvider().clearCapturedHexes();

      // Set callbacks BEFORE starting the run
      final localDb = _storageService is LocalStorage ? _storageService : null;
      _runTracker.setCallbacks(
        onHexCapture: _handleHexCapture,
        onTierChange: (oldTier, newTier) {
          notifyListeners();
        },
        onCheckpoint: localDb != null
            ? (checkpoint) {
                checkpoint['buff_multiplier'] = _buffService
                    .getEffectiveMultiplier();
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

      // Create initial run session - now fully running
      _activeRun = _runTracker.currentRun;
      _isStartingRun = false; // No longer "starting", now actually running
      notifyListeners();

      // Announce run start
      VoiceAnnouncementService().announceRunStart();

      // Listen to location updates for UI sync
      _locationSubscription = _locationService.locationStream.listen((point) {
        _activeRun = _runTracker.currentRun;

        // Increment route version for efficient change detection
        _routeVersion++;

        // Update shared location in HexDataProvider
        final location = LatLng(point.latitude, point.longitude);
        final hexId = HexService().getHexId(location, 9);
        HexDataProvider().updateUserLocation(location, hexId);

        notifyListeners();
      });
    } on LocationPermissionException {
      _isStartingRun = false;
      _stopTimer();
      _buffService.unfreezeAfterRun();
      await _locationService.stopTracking();
      notifyListeners();
      rethrow;
    } catch (e) {
      _isStartingRun = false;
      _stopTimer();
      _buffService.unfreezeAfterRun();
      _setError('Failed to start run: $e');
      await _locationService.stopTracking();
      notifyListeners();
      rethrow;
    }
  }

  bool _handleHexCapture(String hexId, Team runnerTeam) {
    final result = HexDataProvider().updateHexColor(hexId, runnerTeam);
    debugPrint(
      'RunProvider._handleHexCapture: hexId=$hexId, result=$result, '
      'pointsService=${_pointsService != null ? "OK" : "NULL"}',
    );

    if (result == HexUpdateResult.sameTeam) {
      VoiceAnnouncementService().announceFlipFailed();
    }

    if (result == HexUpdateResult.flipped) {
      VoiceAnnouncementService().announceFlip();
      final oldPoints = _pointsService?.todayFlipPoints ?? 0;

      // Use buff multiplier from BuffService (frozen at run start)
      final effectiveMultiplier = _buffService.getEffectiveMultiplier();
      final pointsToAdd = effectiveMultiplier;

      _pointsService?.addRunPoints(pointsToAdd);
      final newPoints = _pointsService?.todayFlipPoints ?? 0;
      debugPrint(
        'POINTS ADDED: $oldPoints -> $newPoints (hexId=$hexId, '
        'effectiveMultiplier=$effectiveMultiplier, pointsService=$_pointsService)',
      );
      _eventController.add(RunEvent.pointEarned);
      notifyListeners();
      return true;
    }

    return false;
  }

  void _startTimer() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _duration += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _stopTimer() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  /// Stop the current run and save to history
  ///
  /// Returns the list of captured hex IDs for "The Final Sync" batch upload.
  Future<List<String>> stopRun() async {
    if (!isRunning) return [];

    _isStopping = true;
    _setLoading(true);
    _setError(null);

    try {
      _stopTimer();
      final result = _runTracker.stopRun();
      await _locationService.stopTracking();

      // Cancel location stream subscription
      await _locationSubscription?.cancel();
      _locationSubscription = null;

      // Stop voice announcements
      await VoiceAnnouncementService().dispose();

      // Read frozen multiplier BEFORE unfreezing (must match run's buff)
      final effectiveMultiplier = _buffService.getEffectiveMultiplier();
      _buffService.unfreezeAfterRun();

      if (result != null) {
        final capturedHexIds = result.capturedHexIds;

        // Set CV, duration, hexPath, and buffMultiplier on the completed run
        // Duration comes from the UI timer (_duration), which accurately tracks elapsed time
        // hexPath must be set here because RunTracker stores captures in capturedHexIds,
        // not in Run.hexPath. buffMultiplier must be set for correct local flipPoints.
        final completedRun = result.session.copyWith(
          cv: result.cv,
          durationSeconds: _duration.inSeconds,
          hexPath: capturedHexIds,
          hexParents: result.capturedHexParents,
          buffMultiplier: effectiveMultiplier,
          runDate: Gmt2DateUtils.toGmt2DateString(DateTime.now()),
        );

        // Calculate flip points for this run (hexes × multiplier)
        final flipPoints = completedRun.hexesColored * effectiveMultiplier;

        debugPrint(
          'RunProvider: Run completed - '
          'distance=${completedRun.distanceKm.toStringAsFixed(2)}km, '
          'flips=${completedRun.hexesColored}, '
          'flipPoints=$flipPoints (multiplier=$effectiveMultiplier), '
          'stability=${completedRun.stabilityScore ?? "N/A"}, '
          'hexIds for sync: ${capturedHexIds.length}',
        );

        // Save to local database with sync tracking for today's flip points
        // Uses saveRunWithSyncTracking if storage is LocalStorage
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
              'RunProvider: saveRunWithSyncTracking failed ($e), '
              'attempting fallback saveRun',
            );
            try {
              await _storageService.saveRun(completedRun);
            } catch (e2) {
              debugPrint('RunProvider: Fallback saveRun also failed: $e2');
            }
          }
        } else {
          await _storageService.saveRun(completedRun);
        }

        // Refresh history IMMEDIATELY after save, before the slow network sync.
        // This ensures _runHistory has the new run if the user switches to
        // RunHistoryScreen while the Final Sync is still in progress.
        await loadRunHistory();
        await loadTotalStats();

        // === THE FINAL SYNC ===
        // Upload run with hex captures to server
        bool syncSucceeded = false;

        // Check network connectivity before attempting sync
        final connectivityResults = await Connectivity().checkConnectivity();
        final hasNetwork = !connectivityResults.contains(
          ConnectivityResult.none,
        );

        if (hasNetwork && capturedHexIds.isNotEmpty) {
          try {
            final syncResult = await _supabaseService.finalizeRun(completedRun);
            debugPrint(
              'RunProvider: Final Sync completed - '
              'flips=${syncResult['flips']}, '
              'points=${syncResult['points_earned']}, '
              'multiplier=${syncResult['multiplier']}',
            );
            syncSucceeded = true;
          } catch (e) {
            // Log but don't fail - local data is already saved
            debugPrint('RunProvider: Final Sync failed - $e');
            // Run remains 'pending' in local DB for retry on next app launch
          }
        } else if (!hasNetwork && capturedHexIds.isNotEmpty) {
          // No network - skip sync, will be retried by SyncRetryService
          debugPrint(
            'RunProvider: No network - skipping Final Sync '
            '(${capturedHexIds.length} hexes pending)',
          );
        } else {
          // No hex captures = nothing to sync, mark as synced
          syncSucceeded = true;
        }

        // Update sync status if Final Sync succeeded
        if (syncSucceeded && storageService is LocalStorage) {
          await storageService.updateRunSyncStatus(completedRun.id, 'synced');
          // Notify points service that sync completed (for potential UI update)
          _pointsService?.onRunSynced(flipPoints);
        }

        // Clear checkpoint after successful save (crash recovery no longer needed)
        if (storageService is LocalStorage) {
          await storageService.clearRunCheckpoint();
        }

        // Clear shared location when run ends
        HexDataProvider().clearUserLocation();

        _activeRun = null;
        _routeVersion = 0;
        notifyListeners();

        // Notify lifecycle manager that run completed (triggers deferred midnight refresh if needed)
        await AppLifecycleManager().onRunCompleted();

        // Return captured hex IDs for caller reference
        return capturedHexIds;
      }

      // Clear shared location when run ends
      HexDataProvider().clearUserLocation();

      _activeRun = null;
      _routeVersion = 0;
      notifyListeners();

      // Notify lifecycle manager that run completed (triggers deferred midnight refresh if needed)
      await AppLifecycleManager().onRunCompleted();

      return [];
    } catch (e) {
      _setError('Failed to stop run: $e');
      return [];
    } finally {
      // Always refresh history and stats, even if errors occurred during save/sync.
      // This ensures the run history screen shows the latest data.
      await loadRunHistory();
      await loadTotalStats();
      _isStopping = false;
      _setLoading(false);
    }
  }

  /// Load run history from storage.
  /// If local is empty and user is logged in, backfill from Supabase run_history.
  Future<void> loadRunHistory() async {
    try {
      _runHistory = await _storageService.getAllRuns();

      // One-time backfill: if local is empty, pull from Supabase
      if (_runHistory.isEmpty) {
        await _backfillFromServer();
      }

      debugPrint(
        'RunProvider.loadRunHistory: Loaded ${_runHistory.length} runs'
        '${_runHistory.isNotEmpty ? " (latest: ${_runHistory.first.id.substring(0, 8)}..., "
                  "${_runHistory.first.distanceKm.toStringAsFixed(2)}km, "
                  "${_runHistory.first.hexesColored} flips)" : ""}',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('RunProvider.loadRunHistory FAILED: $e');
      _setError('Failed to load run history: $e');
    }
  }

  /// Backfill local SQLite from Supabase run_history when local is empty.
  Future<void> _backfillFromServer() async {
    try {
      final userId = _supabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      final rows = await _supabaseService.fetchRunHistory(userId);
      if (rows.isEmpty) return;

      debugPrint('RunProvider._backfillFromServer: Found ${rows.length} runs on server, importing...');

      for (final row in rows) {
        final run = Run(
          id: row['id'] as String,
          startTime: DateTime.parse(row['start_time'] as String),
          endTime: row['end_time'] != null
              ? DateTime.parse(row['end_time'] as String)
              : null,
          distanceMeters: ((row['distance_km'] as num?)?.toDouble() ?? 0) * 1000,
          durationSeconds: (row['duration_seconds'] as num?)?.toInt() ?? 0,
          hexesColored: (row['flip_count'] as num?)?.toInt() ?? 0,
          teamAtRun: Team.values.byName(row['team_at_run'] as String? ?? 'red'),
          buffMultiplier: (row['buff_multiplier'] as num?)?.toInt() ?? 1,
          cv: (row['cv'] as num?)?.toDouble(),
          syncStatus: 'synced',
          runDate: row['run_date']?.toString(),
        );
        await _storageService.saveRun(run);
      }

      // Reload from local after backfill
      _runHistory = await _storageService.getAllRuns();
      debugPrint('RunProvider._backfillFromServer: Imported ${rows.length} runs');
    } catch (e) {
      debugPrint('RunProvider._backfillFromServer FAILED: $e');
      // Non-fatal — local history just stays empty
    }
  }

  /// Load total statistics
  Future<void> loadTotalStats() async {
    try {
      _totalStats = await _storageService.getTotalStats();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load stats: $e');
    }
  }

  /// Delete a run from history
  Future<void> deleteRun(String runId) async {
    _setLoading(true);
    try {
      await _storageService.deleteRun(runId);
      await loadRunHistory();
      await loadTotalStats();
      _setError(null);
    } catch (e) {
      _setError('Failed to delete run: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    if (error != null) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _locationSubscription?.cancel();
    _locationService.dispose();
    _runTracker.dispose();
    _storageService.close();
    _eventController.close();
    super.dispose();
  }
}
