import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_point.dart';
import '../models/run_session.dart';
import '../models/team.dart';
import '../services/hex_service.dart';
import '../services/running_score_service.dart';

typedef HexCaptureCallback = bool Function(String hexId, Team runnerTeam);

/// Callback for tier change events
typedef TierChangeCallback =
    void Function(ImpactTier oldTier, ImpactTier newTier);

/// Service responsible for tracking runs, calculating distance,
/// and applying anti-spoofing.
///
/// Simple two-state lifecycle: start → stop.
class RunTracker {
  // Debug mode for simulator testing - set to true to allow higher speeds
  static const bool _debugMode = true;
  static const double _maxSpeedKmh = _debugMode
      ? 100.0
      : 25.0; // Anti-spoofing: max speed
  static const double _maxTeleportMeters = _debugMode
      ? 5000.0
      : 1000.0; // Anti-spoofing: max jump

  // Must match HexagonMap._fixedResolution (9) so captured hex IDs
  // correspond to rendered hex IDs on the map.
  static const int _hexResolution = 9;
  // Distance required to trigger a capture check within a hex
  static const double _captureCheckDistanceMeters = 20.0;

  RunSession? _currentRun;
  LocationPoint? _lastValidPoint;
  StreamSubscription<LocationPoint>? _locationSubscription;

  // Hex scoring integration
  final HexService _hexService = HexService();
  HexCaptureCallback? _onHexCapture;
  TierChangeCallback? _onTierChange;
  Team? _runnerTeam;
  int _crewMembersCoRunning = 1;
  ImpactTier _currentTier = ImpactTier.starter;
  int _maxImpactTierIndex = 0;

  /// Get the current active run session
  RunSession? get currentRun => _currentRun;

  /// Get current impact tier
  ImpactTier get currentTier => _currentTier;

  /// Get current running score state
  RunningScoreState get scoreState => RunningScoreState(
    totalDistanceKm: (_currentRun?.distanceMeters ?? 0) / 1000,
    currentPaceMinPerKm: _currentRun?.paceMinPerKm ?? 7.0,
    crewMembersRunning: _crewMembersCoRunning,
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
  void setRunnerContext({required Team team, int crewMembersCoRunning = 1}) {
    _runnerTeam = team;
    _crewMembersCoRunning = crewMembersCoRunning;
  }

  /// Start a new run session
  Future<void> startNewRun(
    Stream<LocationPoint> locationStream,
    String runId, {
    Team? team,
    int crewMembersCoRunning = 1,
  }) async {
    if (_currentRun != null) {
      throw StateError('A run is already in progress');
    }

    await _hexService.initialize();

    _runnerTeam = team;
    _crewMembersCoRunning = crewMembersCoRunning;
    _currentTier = ImpactTier.starter;
    _maxImpactTierIndex = 0;

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

    // First point - record it and attempt to capture starting hex
    if (_lastValidPoint == null) {
      _lastValidPoint = point;
      _currentRun!.addPoint(point);
      _currentRun!.currentHexId = currentHexId;
      _currentRun!.distanceInCurrentHex = 0;

      // Attempt to capture the starting hex
      if (_runnerTeam != null) {
        debugPrint(
          'First point: attempting capture of starting hex $currentHexId',
        );
        bool flipped = _onHexCapture?.call(currentHexId, _runnerTeam!) ?? false;

        if (flipped) {
          _currentRun!.recordFlip(currentHexId);
          debugPrint(
            'STARTING HEX CAPTURED! hexId=$currentHexId, '
            'Total flips: ${_currentRun!.hexesColored}',
          );
        }
      }
      return;
    }

    // Anti-spoofing checks
    if (!_isValidPoint(point, _lastValidPoint!)) {
      // ignore: avoid_print
      print('Invalid point detected (anti-spoofing): $point');
      return;
    }

    // Calculate distance from last valid point
    final distanceMeters = _calculateDistance(_lastValidPoint!, point);

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

    if (previousHexId != currentHexId) {
      // Transitioning to a new hex - attempt capture on entry
      debugPrint('Hex transition: $previousHexId -> $currentHexId');

      if (_runnerTeam != null) {
        final pace = _currentRun!.paceMinPerKm;
        final canCapture = RunningScoreService.canCapture(pace);
        debugPrint(
          'Hex ENTRY capture check: hexId=$currentHexId, '
          'pace=${pace.toStringAsFixed(1)}, canCapture=$canCapture',
        );

        if (canCapture) {
          bool flipped =
              _onHexCapture?.call(currentHexId, _runnerTeam!) ?? false;

          if (flipped) {
            _currentRun!.recordFlip(currentHexId);
            debugPrint(
              'HEX FLIPPED ON ENTRY! '
              'Total flips: ${_currentRun!.hexesColored}',
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
        final pace = _currentRun!.paceMinPerKm;
        final canCapture = RunningScoreService.canCapture(pace);

        if (canCapture) {
          bool flipped =
              _onHexCapture?.call(currentHexId, _runnerTeam!) ?? false;

          if (flipped) {
            _currentRun!.recordFlip(currentHexId);
            debugPrint(
              'HEX FLIPPED ON STAY! '
              'Total flips: ${_currentRun!.hexesColored}',
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

    _lastValidPoint = point;
  }

  /// Anti-spoofing: Validate if a location point is legitimate
  bool _isValidPoint(LocationPoint current, LocationPoint last) {
    // Skip anti-spoofing checks in debug mode for simulator testing
    if (_debugMode) return true;

    // Check 1: Speed filter
    final timeDiffSeconds = current.timestamp
        .difference(last.timestamp)
        .inSeconds;
    if (timeDiffSeconds == 0) return false;

    final distanceMeters = _calculateDistance(last, current);
    final speedKmh = (distanceMeters / timeDiffSeconds) * 3.6;

    if (speedKmh > _maxSpeedKmh) {
      // ignore: avoid_print
      print('Speed too high: ${speedKmh.toStringAsFixed(2)} km/h');
      return false;
    }

    // Check 2: Teleport detection
    if (distanceMeters > _maxTeleportMeters) {
      // ignore: avoid_print
      print('Teleport detected: ${distanceMeters.toStringAsFixed(2)}m');
      return false;
    }

    return true;
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

  /// Stop the current run session
  RunSession? stopRun() {
    if (_currentRun == null) return null;

    // Complete the run
    _currentRun!.complete();
    _currentRun!.distanceInCurrentHex = 0;

    final completedRun = _currentRun;

    _locationSubscription?.cancel();
    _locationSubscription = null;
    _currentRun = null;
    _lastValidPoint = null;
    _currentTier = ImpactTier.starter;
    _maxImpactTierIndex = 0;

    return completedRun;
  }

  /// Clean up resources
  void dispose() {
    _locationSubscription?.cancel();
  }
}
