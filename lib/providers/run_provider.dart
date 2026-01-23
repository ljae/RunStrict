import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../models/run_session.dart';
import '../models/location_point.dart';
import '../services/location_service.dart';
import '../services/run_tracker.dart';
import '../services/storage_service.dart';
import '../services/points_service.dart';
import '../models/team.dart';
import '../providers/hex_data_provider.dart';
import '../services/hex_service.dart';

/// Three distinct run states for the tracking system:
/// - [stopped]: No active run. Tracing/flipping disabled. Run saved to history.
/// - [running]: Active run. GPS tracing and hex flipping enabled.
/// - [paused]: Temporary stop. No tracing/flipping. App kill → auto-save.
enum RunState { stopped, running, paused }

/// Provider for managing run state and coordinating services
///
/// Data Flow Architecture (Optimized for Real-time Updates):
///
/// LocationService.locationStream
///   → RunTracker._onLocationUpdate (processes point, updates RunSession)
///   → RunProvider._locationSubscription (receives each point)
///   → RunProvider.notifyListeners() (triggers UI rebuild)
///   → RunningScreen rebuilds with new routeVersion
///   → RouteMap.didUpdateWidget detects routeVersion change
///   → Camera follows + Route line updates
///
/// Key Optimization: Use routeVersion counter instead of comparing list references
///
/// ## Run State Machine:
/// stopped → running (startRun)
/// running → paused (pauseRun)
/// paused → running (resumeRun)
/// running → stopped (stopRun) [saves to history]
/// paused → stopped (stopRun or app kill) [saves to history]
class RunProvider with ChangeNotifier, WidgetsBindingObserver {
  final LocationService _locationService;
  final RunTracker _runTracker;
  final StorageService _storageService;
  PointsService? _pointsService;

  RunSession? _activeRun;
  List<RunSession> _runHistory = [];
  Map<String, dynamic>? _totalStats;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<LocationPoint>? _locationSubscription;

  // Route version counter - increments on each new point for efficient change detection
  int _routeVersion = 0;

  RunProvider({
    required LocationService locationService,
    required RunTracker runTracker,
    required StorageService storageService,
    PointsService? pointsService,
  }) : _locationService = locationService,
       _runTracker = runTracker,
       _storageService = storageService,
       _pointsService = pointsService;

  /// Update the points service reference (for ProxyProvider)
  void updatePointsService(PointsService pointsService) {
    _pointsService = pointsService;
  }

  // Run state
  RunState _runState = RunState.stopped;

  // Getters
  RunSession? get activeRun => _activeRun;
  List<RunSession> get runHistory => _runHistory;
  Map<String, dynamic>? get totalStats => _totalStats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  RunState get runState => _runState;
  bool get isRunning => _runState == RunState.running;
  bool get isActive => _runState != RunState.stopped;
  bool get isPaused => _runState == RunState.paused;

  // New state for timer and units
  Timer? _tickTimer;
  Duration _duration = Duration.zero;
  bool _isMetric = true;

  bool get isMetric => _isMetric;
  Duration get duration => _duration;

  /// Get current Speed in km/h or mph
  /// Calculated from recent data (e.g. RunTracker should ideally provide instantaneous speed)
  /// For now, we can calculate average speed or use instantaneous speed if available from tracker
  double get currentSpeed {
    // If paused or not running, speed is 0
    if (!isRunning) return 0.0;

    // Prefer instantaneous speed from tracker if possible, or calculate from pace
    // _activeRun might update every location update.
    // If we use average pace:
    final paceMinPerKm = _activeRun?.averagePaceMinPerKm ?? 0;
    if (paceMinPerKm <= 0 || paceMinPerKm.isInfinite) return 0.0;

    // Speed (km/h) = 60 / pace (min/km)
    final speedKmh = 60 / paceMinPerKm;

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

  /// Get current GPS signal quality
  GpsSignalQuality get signalQuality {
    // In a real app, this would check accuracy from _locationService
    // For now, return excellent if tracking
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
  String get formattedPace {
    if (_activeRun == null) return '-:--';
    final pace = _activeRun!.averagePaceMinPerKm;
    if (pace == 0 || pace.isInfinite || pace.isNaN) return '-:--';
    final m = pace.floor();
    final s = ((pace - m) * 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Formatted distance
  double get distance => _activeRun?.distanceKm ?? 0.0;

  /// Route points for map
  List<LocationPoint> get routePoints => _activeRun?.route ?? [];

  /// Route version - use this to detect route changes efficiently
  /// Increments every time a new point is added
  int get routeVersion => _routeVersion;

  /// Initialize the provider and load data.
  /// Registers app lifecycle observer for auto-saving paused runs.
  Future<void> initialize() async {
    // Register lifecycle observer to auto-save paused runs on app kill
    WidgetsBinding.instance.addObserver(this);

    _setLoading(true);
    try {
      await _storageService.initialize();
      await loadRunHistory();
      await loadTotalStats();
      _setError(null);
    } catch (e) {
      _setError('Failed to initialize: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// App lifecycle handler.
  /// If the app goes to background (paused/detached) while run is PAUSED,
  /// auto-stop and save the run to prevent data loss on app kill.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Auto-save paused runs when app is backgrounded/killed
      if (_runState == RunState.paused) {
        debugPrint(
          'RunProvider: App lifecycle=$state while run PAUSED - auto-stopping',
        );
        stopRun();
      }
    }
  }

  /// Start a new run
  Future<void> startRun({
    required Team team,
    bool isPurpleRunner = false,
  }) async {
    if (isRunning) {
      throw StateError('A run is already in progress');
    }

    _setLoading(true);
    _setError(null);

    try {
      // Request permissions and start location tracking
      await _locationService.startTracking();

      // Generate unique run ID
      final runId = const Uuid().v4();

      // Clear any captured hexes from previous runs
      HexDataProvider().clearCapturedHexes();

      // CRITICAL: Set callbacks BEFORE starting the run to avoid race condition
      // where location points arrive before callbacks are registered
      _runTracker.setCallbacks(
        onHexCapture: _handleHexCapture,
        onTierChange: (oldTier, newTier) {
          // Can notify UI for celebration
          notifyListeners();
        },
      );

      // Start run tracking (this subscribes to location stream)
      _runTracker.startNewRun(
        _locationService.locationStream,
        runId,
        team: team,
        isPurpleRunner: isPurpleRunner,
      );

      // Start timer and set state to running
      _duration = Duration.zero;
      _runState = RunState.running;
      _startTimer();

      // Create initial run session
      _activeRun = _runTracker.currentRun;

      // Notify listeners immediately so UI can respond
      notifyListeners();

      // Listen to location updates to refresh UI and sync location across screens.
      // CRITICAL: Only process updates when in RUNNING state.
      // When PAUSED: ignore updates (no tracing, no flipping, no route version increment).
      // When STOPPED: subscription is cancelled entirely.
      _locationSubscription = _locationService.locationStream.listen((point) {
        // Guard: skip processing if not actively running
        if (_runState != RunState.running) return;

        _activeRun = _runTracker.currentRun;

        // INCREMENT ROUTE VERSION - This is the key for efficient change detection!
        // RouteMap uses this to detect when route has changed without comparing list references
        _routeVersion++;

        // Update shared location in HexDataProvider for syncing across screens
        final location = LatLng(point.latitude, point.longitude);
        final hexId = HexService().getHexId(
          location,
          9,
        ); // Resolution 9 for neighborhood
        HexDataProvider().updateUserLocation(location, hexId);

        notifyListeners();
      });
    } on LocationPermissionException {
      // Rethrow specific permission exceptions to be handled by UI
      await _locationService.stopTracking();
      rethrow;
    } catch (e) {
      _setError('Failed to start run: $e');
      await _locationService.stopTracking();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  bool _handleHexCapture(String hexId, Team runnerTeam, bool isPurpleRunner) {
    // Update the hex data provider with the runner's color
    // Returns true if the color actually changed (flipped)
    final colorChanged = HexDataProvider().updateHexColor(
      hexId,
      runnerTeam,
      isPurpleRunner: isPurpleRunner,
    );
    if (colorChanged) {
      debugPrint('RunProvider: Hex $hexId was flipped!');

      // Add flip point to PointsService
      // Purple runners get 2x multiplier
      final pointsToAdd = isPurpleRunner ? 2 : 1;
      _pointsService?.addRunPoints(pointsToAdd);
      debugPrint(
        'RunProvider: Added $pointsToAdd flip point(s). Total: ${_pointsService?.currentPoints}',
      );

      notifyListeners(); // Update UI to show new map state
    }
    return colorChanged;
  }

  /// Pause the current run.
  /// Stops tracing and flipping. Timer stops. Location updates are ignored.
  /// If app is killed while paused, run is auto-saved to history.
  void pauseRun() {
    if (isRunning) {
      _runState = RunState.paused;
      _stopTimer();
      _activeRun?.recordPause();
      _runTracker.pauseTracking();
      notifyListeners();
    }
  }

  /// Resume the current run from paused state.
  /// Re-enables tracing and flipping. First GPS point after resume is used
  /// as new anchor (no ghost distance from pause gap).
  void resumeRun() {
    if (isPaused) {
      _runState = RunState.running;
      _startTimer();
      _runTracker.resumeTracking();
      notifyListeners();
    }
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

  /// Stop the current run and save to history.
  /// Can be called from both RUNNING and PAUSED states.
  /// Records distance and flip count in running history.
  Future<void> stopRun() async {
    if (!isActive) return; // Can stop from running OR paused state

    _setLoading(true);
    _setError(null);

    try {
      // Stop tracking and set state
      _runState = RunState.stopped;
      _stopTimer();
      final completedRun = _runTracker.stopRun();
      await _locationService.stopTracking();

      // Cancel location stream subscription
      await _locationSubscription?.cancel();
      _locationSubscription = null;

      if (completedRun != null) {
        debugPrint(
          'RunProvider: Run completed - distance=${completedRun.distanceKm.toStringAsFixed(2)}km, '
          'flips=${completedRun.hexesColored}',
        );

        // Save to database (stores distance and flips)
        await _storageService.saveRun(completedRun);

        // Refresh history and stats
        await loadRunHistory();
        await loadTotalStats();
      }

      // Clear shared location when run ends
      HexDataProvider().clearUserLocation();

      _activeRun = null;
      _routeVersion = 0; // Reset route version for next run
      notifyListeners();
    } catch (e) {
      _setError('Failed to stop run: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load run history from storage
  Future<void> loadRunHistory() async {
    try {
      _runHistory = await _storageService.getAllRuns();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load run history: $e');
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
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    _locationSubscription?.cancel();
    _locationService.dispose();
    _runTracker.dispose();
    _storageService.close();
    super.dispose();
  }
}
