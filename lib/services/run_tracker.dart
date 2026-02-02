import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_point.dart';
import '../models/run_session.dart';
import '../models/team.dart';
import '../models/lap_model.dart';
import '../services/gps_validator.dart';
import '../services/hex_service.dart';
import '../services/running_score_service.dart';
import '../services/accelerometer_service.dart';
import '../services/lap_service.dart';
import 'remote_config_service.dart';

typedef HexCaptureCallback = bool Function(String hexId, Team runnerTeam);

/// Callback for tier change events
typedef TierChangeCallback =
    void Function(ImpactTier oldTier, ImpactTier newTier);

/// Result of stopping a run, including data for "The Final Sync"
class RunStopResult {
  final RunSession session;
  final List<String> capturedHexIds;
  final double? cv;
  final int? stabilityScore;
  final List<LapModel> laps;

  const RunStopResult({
    required this.session,
    required this.capturedHexIds,
    this.cv,
    this.stabilityScore,
    required this.laps,
  });
}

/// Service responsible for tracking runs, calculating distance,
/// and applying anti-spoofing.
///
/// Simple two-state lifecycle: start → stop.
class RunTracker {
  // Must match HexagonMap._fixedResolution (9) so captured hex IDs
  // correspond to rendered hex IDs on the map.
  static int get _hexResolution =>
      RemoteConfigService().configSnapshot.hexConfig.baseResolution;
  // Distance required to trigger a capture check within a hex
  static double get _captureCheckDistanceMeters =>
      RemoteConfigService().configSnapshot.hexConfig.captureCheckDistanceMeters;

  RunSession? _currentRun;
  LocationPoint? _lastValidPoint;
  StreamSubscription<LocationPoint>? _locationSubscription;

  // GPS validator for moving average pace (20-sec window at 0.5Hz polling)
  final GpsValidator _gpsValidator = GpsValidator();

  // Accelerometer service for anti-spoofing (singleton)
  final AccelerometerService _accelerometerService = AccelerometerService();

  // Hex scoring integration
  final HexService _hexService = HexService();
  HexCaptureCallback? _onHexCapture;
  TierChangeCallback? _onTierChange;
  Team? _runnerTeam;
  ImpactTier _currentTier = ImpactTier.starter;
  int _maxImpactTierIndex = 0;

  /// List of hex IDs captured during this run (for batch upload at "The Final Sync")
  final List<String> _capturedHexIds = [];

  /// List of completed laps (1km each) for CV calculation
  final List<LapModel> _completedLaps = [];

  /// Distance at which current lap started
  double _currentLapStartDistance = 0;

  /// Timestamp when current lap started (milliseconds)
  int? _currentLapStartTimestampMs;

  /// Get the current active run session
  RunSession? get currentRun => _currentRun;

  /// Get current impact tier
  ImpactTier get currentTier => _currentTier;

  /// Get the list of captured hex IDs (for batch upload)
  List<String> get capturedHexIds => List.unmodifiable(_capturedHexIds);

  /// Get list of completed laps (immutable)
  List<LapModel> get completedLaps => List.unmodifiable(_completedLaps);

  /// Get current 10-second moving average pace (min/km)
  double get movingAvgPaceMinPerKm => _gpsValidator.movingAvgPaceMinPerKm;

  /// Check if current pace is valid for hex capture (< 8:00 min/km)
  bool get canCaptureAtCurrentPace => _gpsValidator.canCaptureAtCurrentPace;

  /// Get current running score state
  RunningScoreState get scoreState => RunningScoreState(
    totalDistanceKm: (_currentRun?.distanceMeters ?? 0) / 1000,
    currentPaceMinPerKm: _currentRun?.paceMinPerKm ?? 7.0,
    currentHexId: _currentRun?.currentHexId,
    flipCount: _currentRun?.hexesColored ?? 0,
  );

  /// Set callbacks for hex scoring events
  void setCallbacks({
    HexCaptureCallback? onHexCapture,
    TierChangeCallback? onTierChange,
  }) {
    _onHexCapture = onHexCapture;
    _onTierChange = onTierChange;
  }

  /// Set runner context for scoring
  void setRunnerContext({required Team team}) {
    _runnerTeam = team;
  }

  /// Start a new run session
  Future<void> startNewRun(
    Stream<LocationPoint> locationStream,
    String runId, {
    Team? team,
  }) async {
    if (_currentRun != null) {
      throw StateError('A run is already in progress');
    }

    await _hexService.initialize();

    _runnerTeam = team;
    _currentTier = ImpactTier.starter;
    _maxImpactTierIndex = 0;
    _gpsValidator.reset();
    _capturedHexIds.clear();
    _completedLaps.clear();
    _currentLapStartDistance = 0;
    _currentLapStartTimestampMs = null;

    // Start accelerometer for anti-spoofing
    _accelerometerService.startListening();

    _currentRun = RunSession(
      id: runId,
      startTime: DateTime.now(),
      distanceMeters: 0,
      isActive: true,
      teamAtRun: team ?? Team.blue,
      hexesColored: 0,
    );

    _lastValidPoint = null;

    // Subscribe to location updates
    _locationSubscription = locationStream.listen(_onLocationUpdate);
  }

  /// Handle incoming location updates
  void _onLocationUpdate(LocationPoint point) {
    if (_currentRun == null) return;

    // Get current hex for this point
    final currentHexId = _hexService.getHexId(
      LatLng(point.latitude, point.longitude),
      _hexResolution,
    );

    // First point - record it (no capture until we have moving avg pace)
    if (_lastValidPoint == null) {
      _lastValidPoint = point;
      _currentRun!.addPoint(point);
      _currentRun!.currentHexId = currentHexId;
      _currentRun!.distanceInCurrentHex = 0;

      // Initialize validator with first point (no pace data yet)
      _gpsValidator.validate(null, point);

      debugPrint(
        'First point recorded: hexId=$currentHexId (awaiting pace data)',
      );
      return;
    }

    // Validate point using GpsValidator (includes moving avg pace calculation)
    final validationResult = _gpsValidator.validate(_lastValidPoint, point);

    if (!validationResult.isValid) {
      debugPrint(
        'Invalid point (anti-spoofing): ${validationResult.rejectionReason}',
      );
      return;
    }

    // Get calculated distance from validator or compute it
    final distanceMeters =
        validationResult.calculatedDistance ??
        _calculateDistance(_lastValidPoint!, point);

    // Calculate time difference for accelerometer validation
    final timeDiffSeconds =
        point.timestamp.difference(_lastValidPoint!.timestamp).inMilliseconds /
        1000.0;

    // Validate against accelerometer (anti-spoofing layer 2)
    // Only reject if we have accelerometer data AND GPS shows significant movement
    if (timeDiffSeconds > 0 && distanceMeters > 5) {
      final accelResult = _accelerometerService.validateGpsMovement(
        distanceMeters,
        timeDiffSeconds,
      );
      if (!accelResult.isValid) {
        debugPrint(
          'Invalid point (accelerometer): ${accelResult.rejectionReason}',
        );
        return;
      }
    }

    // Update run session
    final newTotalDistance = _currentRun!.distanceMeters + distanceMeters;

    // Check for tier change
    final oldTier = _currentTier;
    final newTier = RunningScoreService.getTier(newTotalDistance / 1000);
    if (newTier != oldTier) {
      _currentTier = newTier;
      _onTierChange?.call(oldTier, newTier);
    }

    // Track max tier reached
    _maxImpactTierIndex = max(
      _maxImpactTierIndex,
      ImpactTier.values.indexOf(newTier),
    );

    // Handle hex transition
    final previousHexId = _currentRun!.currentHexId;

    // Use 20-second moving average pace for capture validation (spec §2.4.2)
    // 20-sec window provides ~10 samples at 0.5Hz GPS polling for stable calculation
    final movingAvgPace = _gpsValidator.movingAvgPaceMinPerKm;
    final canCapture = _gpsValidator.canCaptureAtCurrentPace;

    if (previousHexId != currentHexId) {
      // Transitioning to a new hex - attempt capture on entry
      debugPrint('Hex transition: $previousHexId -> $currentHexId');

      if (_runnerTeam != null) {
        debugPrint(
          'Hex ENTRY capture check: hexId=$currentHexId, '
          'movingAvgPace=${movingAvgPace.toStringAsFixed(1)} min/km, '
          'canCapture=$canCapture',
        );

        if (canCapture) {
          bool flipped =
              _onHexCapture?.call(currentHexId, _runnerTeam!) ?? false;

          if (flipped) {
            _currentRun!.recordFlip(currentHexId);
            _capturedHexIds.add(currentHexId); // Batch for The Final Sync
            debugPrint(
              'HEX FLIPPED ON ENTRY! '
              'Total flips: ${_currentRun!.hexesColored}, '
              'Batch size: ${_capturedHexIds.length}',
            );
          }
        }
      }

      // Reset distance for the new hex
      _currentRun!.distanceInCurrentHex = distanceMeters;
    } else {
      // Still in the same hex, accumulate distance
      _currentRun!.distanceInCurrentHex += distanceMeters;

      // Check for capture every 20m while staying in the same hex
      if (_runnerTeam != null &&
          _currentRun!.distanceInCurrentHex >= _captureCheckDistanceMeters) {
        if (canCapture) {
          bool flipped =
              _onHexCapture?.call(currentHexId, _runnerTeam!) ?? false;

          if (flipped) {
            _currentRun!.recordFlip(currentHexId);
            _capturedHexIds.add(currentHexId); // Batch for The Final Sync
            debugPrint(
              'HEX FLIPPED ON STAY! '
              'Total flips: ${_currentRun!.hexesColored}, '
              'Batch size: ${_capturedHexIds.length}',
            );
          }

          // Reset distance to avoid spamming capture calls
          _currentRun!.distanceInCurrentHex = 0;
        }
      }
    }

    // Update run state
    _currentRun!.updateDistance(newTotalDistance);
    _currentRun!.addPoint(point);
    _currentRun!.currentHexId = currentHexId;

    // LAP TRACKING: Check if we've crossed a 1km boundary
    _checkLapCompletion(
      newTotalDistance,
      point.timestamp.millisecondsSinceEpoch,
    );

    _lastValidPoint = point;
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(LocationPoint start, LocationPoint end) {
    const earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(end.latitude - start.latitude);
    final dLon = _degreesToRadians(end.longitude - start.longitude);

    final lat1Rad = _degreesToRadians(start.latitude);
    final lat2Rad = _degreesToRadians(end.latitude);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1Rad) * cos(lat2Rad);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    final distanceKm = earthRadiusKm * c;
    return distanceKm * 1000; // Convert to meters
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Check if a lap (1km) has been completed and record it
  void _checkLapCompletion(
    double currentTotalDistance,
    int currentTimestampMs,
  ) {
    // Initialize lap start time on first call
    if (_currentLapStartTimestampMs == null) {
      _currentLapStartTimestampMs = currentTimestampMs;
      _currentLapStartDistance = 0;
      return;
    }

    // Check if we've completed 1km since lap start
    final distanceInLap = currentTotalDistance - _currentLapStartDistance;

    if (distanceInLap >= 1000.0) {
      // Calculate lap duration
      final lapDurationMs = currentTimestampMs - _currentLapStartTimestampMs!;
      final lapDurationSeconds = lapDurationMs / 1000.0;

      // Create lap record
      final lap = LapModel(
        lapNumber: _completedLaps.length + 1,
        distanceMeters: 1000.0, // Fixed at exactly 1km per spec
        durationSeconds: lapDurationSeconds,
        startTimestampMs: _currentLapStartTimestampMs!,
        endTimestampMs: currentTimestampMs,
      );

      _completedLaps.add(lap);

      debugPrint(
        'LAP ${lap.lapNumber} COMPLETED: '
        'pace=${lap.avgPaceSecPerKm.toStringAsFixed(1)} sec/km, '
        'duration=${lapDurationSeconds.toStringAsFixed(1)}s',
      );

      // Reset for next lap - start from current position
      _currentLapStartDistance = currentTotalDistance;
      _currentLapStartTimestampMs = currentTimestampMs;
    }
  }

  /// Stop the current run session and return data for "The Final Sync"
  ///
  /// Returns [RunStopResult] containing:
  /// - [session]: The completed run session
  /// - [capturedHexIds]: List of hex IDs captured during this run (for batch upload)
  RunStopResult? stopRun() {
    if (_currentRun == null) return null;

    // Complete the run
    _currentRun!.complete();
    _currentRun!.distanceInCurrentHex = 0;

    final completedRun = _currentRun!;
    final hexIds = List<String>.from(_capturedHexIds);

    // Calculate CV from completed laps
    final laps = List<LapModel>.from(_completedLaps);
    final cv = LapService.calculateCV(laps);
    final stabilityScore = LapService.calculateStabilityScore(cv);

    debugPrint(
      'Run CV: ${cv?.toStringAsFixed(2) ?? "N/A"}, '
      'Stability: ${stabilityScore ?? "N/A"}, '
      'Laps: ${laps.length}',
    );

    debugPrint(
      'Run stopped. Total flips: ${completedRun.hexesColored}, '
      'Hex IDs for Final Sync: ${hexIds.length}',
    );

    // Reset state
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _currentRun = null;
    _lastValidPoint = null;
    _currentTier = ImpactTier.starter;
    _maxImpactTierIndex = 0;
    _gpsValidator.reset();
    _capturedHexIds.clear();
    _completedLaps.clear();
    _currentLapStartDistance = 0;
    _currentLapStartTimestampMs = null;

    // Stop accelerometer
    _accelerometerService.stopListening();

    return RunStopResult(
      session: completedRun,
      capturedHexIds: hexIds,
      cv: cv,
      stabilityScore: stabilityScore,
      laps: laps,
    );
  }

  /// Clean up resources
  void dispose() {
    _locationSubscription?.cancel();
  }
}
