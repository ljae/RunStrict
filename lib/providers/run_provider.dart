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
import '../services/supabase_service.dart';
import '../models/team.dart';
import '../providers/hex_data_provider.dart';
import '../services/hex_service.dart';

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
  PointsService? _pointsService;

  RunSession? _activeRun;
  List<RunSession> _runHistory = [];
  Map<String, dynamic>? _totalStats;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<LocationPoint>? _locationSubscription;

  /// Flag to show stop button immediately while GPS initializes
  bool _isStartingRun = false;

  /// Yesterday's crew count for multiplier (fetched on run start)
  int _yesterdayCrewCount = 1;

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
    PointsService? pointsService,
  }) : _locationService = locationService,
       _runTracker = runTracker,
       _storageService = storageService,
       _supabaseService = supabaseService ?? SupabaseService(),
       _pointsService = pointsService;

  /// Update the points service reference (for ProxyProvider)
  void updatePointsService(PointsService pointsService) {
    _pointsService = pointsService;
  }

  // Getters
  RunSession? get activeRun => _activeRun;
  List<RunSession> get runHistory => _runHistory;
  Map<String, dynamic>? get totalStats => _totalStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Returns true if run is active OR if we're in the process of starting
  /// This allows the UI to show stop button immediately while GPS initializes
  bool get isRunning =>
      _isStartingRun || (_activeRun != null && _activeRun!.isActive);

  // Timer state
  Timer? _tickTimer;
  Duration _duration = Duration.zero;
  bool _isMetric = true;

  bool get isMetric => _isMetric;
  Duration get duration => _duration;

  /// Current speed in km/h or mph
  double get currentSpeed {
    if (!isRunning) return 0.0;
    final paceMinPerKm = _activeRun?.paceMinPerKm ?? 0;
    if (paceMinPerKm <= 0 || paceMinPerKm.isInfinite) return 0.0;
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
  String get formattedPace {
    if (_activeRun == null) return '-:--';
    final pace = _activeRun!.paceMinPerKm;
    if (pace == 0 || pace.isInfinite || pace.isNaN) return '-:--';
    final m = pace.floor();
    final s = ((pace - m) * 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
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
      await loadRunHistory();
      await loadTotalStats();
      _setError(null);
    } catch (e) {
      _setError('Failed to initialize: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Set the crew multiplier for the next run.
  ///
  /// Call this before starting a run to apply the crew bonus.
  /// The multiplier is the number of crew members who ran yesterday.
  void setCrewMultiplier(int multiplier) {
    _yesterdayCrewCount = multiplier > 0 ? multiplier : 1;
    debugPrint('RunProvider: Crew multiplier set to $_yesterdayCrewCount');
  }

  /// Get the current crew multiplier
  int get crewMultiplier => _yesterdayCrewCount;

  /// Start a new run
  ///
  /// [team] - The team the runner belongs to
  /// [crewId] - Optional crew ID for multiplier lookup (if not already set)
  Future<void> startRun({required Team team, String? crewId}) async {
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
      // Now start GPS tracking (this may take a moment)
      await _locationService.startTracking();

      // Generate unique run ID
      final runId = const Uuid().v4();

      // Clear any captured hexes from previous runs
      HexDataProvider().clearCapturedHexes();

      // Set callbacks BEFORE starting the run
      _runTracker.setCallbacks(
        onHexCapture: _handleHexCapture,
        onTierChange: (oldTier, newTier) {
          notifyListeners();
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

      // Fetch crew multiplier in BACKGROUND (non-blocking)
      if (crewId != null && _yesterdayCrewCount == 1) {
        _fetchCrewMultiplierInBackground(crewId);
      }

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
      await _locationService.stopTracking();
      notifyListeners();
      rethrow;
    } catch (e) {
      _isStartingRun = false;
      _stopTimer();
      _setError('Failed to start run: $e');
      await _locationService.stopTracking();
      notifyListeners();
      rethrow;
    }
  }

  /// Fetches crew multiplier in background without blocking UI
  void _fetchCrewMultiplierInBackground(String crewId) {
    _supabaseService
        .getYesterdayCrewCount(crewId)
        .then((multiplier) {
          _yesterdayCrewCount = multiplier > 0 ? multiplier : 1;
          debugPrint(
            'RunProvider: Fetched crew multiplier: $_yesterdayCrewCount',
          );
          notifyListeners(); // Update UI with multiplier
        })
        .catchError((e) {
          debugPrint('RunProvider: Failed to fetch multiplier, using 1 - $e');
          _yesterdayCrewCount = 1;
        });
  }

  bool _handleHexCapture(String hexId, Team runnerTeam) {
    final result = HexDataProvider().updateHexColor(hexId, runnerTeam);
    debugPrint(
      'RunProvider._handleHexCapture: hexId=$hexId, result=$result, '
      'pointsService=${_pointsService != null ? "OK" : "NULL"}',
    );

    if (result == HexUpdateResult.flipped) {
      final oldPoints = _pointsService?.currentPoints ?? 0;
      _pointsService?.addRunPoints(1);
      final newPoints = _pointsService?.currentPoints ?? 0;
      debugPrint(
        'POINTS ADDED: $oldPoints -> $newPoints (pointsService=$_pointsService)',
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

    _setLoading(true);
    _setError(null);

    try {
      _stopTimer();
      final result = _runTracker.stopRun();
      await _locationService.stopTracking();

      // Cancel location stream subscription
      await _locationSubscription?.cancel();
      _locationSubscription = null;

      if (result != null) {
        // Set CV on the completed run (calculated at stop time)
        final completedRun = result.session.copyWith(cv: result.cv);
        final capturedHexIds = result.capturedHexIds;

        debugPrint(
          'RunProvider: Run completed - '
          'distance=${completedRun.distanceKm.toStringAsFixed(2)}km, '
          'flips=${completedRun.hexesColored}, '
          'stability=${completedRun.stabilityScore ?? "N/A"}, '
          'hexIds for sync: ${capturedHexIds.length}',
        );

        // Save to local database (includes CV for stability score)
        await _storageService.saveRun(completedRun);

        // === THE FINAL SYNC ===
        // Upload run summary with hex captures to server
        if (capturedHexIds.isNotEmpty) {
          try {
            final runSummary = completedRun.toSummary(
              yesterdayCrewCount: _yesterdayCrewCount,
            );
            final syncResult = await _supabaseService.finalizeRun(runSummary);
            debugPrint(
              'RunProvider: Final Sync completed - '
              'flips=${syncResult['flips']}, '
              'points=${syncResult['points_earned']}, '
              'multiplier=${syncResult['multiplier']}',
            );
          } catch (e) {
            // Log but don't fail - local data is already saved
            debugPrint('RunProvider: Final Sync failed - $e');
            // TODO: Queue for retry on next app launch
          }
        }

        // Refresh history and stats
        await loadRunHistory();
        await loadTotalStats();

        // Clear shared location when run ends
        HexDataProvider().clearUserLocation();

        _activeRun = null;
        _routeVersion = 0;
        notifyListeners();

        // Return captured hex IDs for caller reference
        return capturedHexIds;
      }

      // Clear shared location when run ends
      HexDataProvider().clearUserLocation();

      _activeRun = null;
      _routeVersion = 0;
      notifyListeners();
      return [];
    } catch (e) {
      _setError('Failed to stop run: $e');
      return [];
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
    _stopTimer();
    _locationSubscription?.cancel();
    _locationService.dispose();
    _runTracker.dispose();
    _storageService.close();
    _eventController.close();
    super.dispose();
  }
}
