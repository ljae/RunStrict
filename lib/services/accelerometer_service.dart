import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'gps_validator.dart';
import 'remote_config_service.dart';

/// Service for managing accelerometer sensor subscription and validation.
///
/// Provides anti-spoofing by detecting if the device is actually moving
/// when GPS reports movement. Uses [AccelerometerValidator] from gps_validator.dart.
///
/// Battery Optimization:
/// - Polling at 5Hz (200ms) balances detection accuracy with power efficiency
/// - At 0.5Hz GPS polling, this provides ~10 samples per GPS point
/// - 2-second sample window for variance calculation
/// - 5-second freshness threshold for graceful fallback
///
/// Platform Notes:
/// - iOS Simulator: No hardware accelerometer, will always fall back to GPS-only
/// - Real devices: Requires no special permissions for basic accelerometer access
///
/// Usage:
/// 1. Call [startListening] when a run starts
/// 2. Check [isDeviceMoving] or [validateGpsMovement] during hex capture
/// 3. Call [stopListening] when the run ends
class AccelerometerService {
  // Singleton pattern
  static final AccelerometerService _instance =
      AccelerometerService._internal();
  factory AccelerometerService() => _instance;
  AccelerometerService._internal();

  // Battery-optimized polling rate: 5Hz provides ~10 samples per 2-second GPS interval
  // This is sufficient for variance calculation while minimizing battery drain
  static Duration get _samplingPeriod => Duration(
    milliseconds: RemoteConfigService()
        .configSnapshot
        .timingConfig
        .accelerometerSamplingPeriodMs,
  );

  // Timeout for detecting if accelerometer is working (no events after this = likely simulator)
  static const Duration _noDataWarningTimeout = Duration(seconds: 5);

  final AccelerometerValidator _validator = AccelerometerValidator();
  StreamSubscription<AccelerometerEvent>? _subscription;
  Timer? _noDataWarningTimer;
  bool _isListening = false;
  int _eventCount = 0; // Track events for debugging
  bool _noDataWarningShown = false;

  /// Whether the service is currently listening to accelerometer events
  bool get isListening => _isListening;

  /// Whether the device appears to be physically moving based on accelerometer data.
  /// Returns false if no recent data is available.
  bool get isDeviceMoving => _validator.hasRecentData() && _validator.isMoving;

  /// Whether we have recent accelerometer data (within last 5 seconds)
  bool get hasRecentData => _validator.hasRecentData();

  /// Current variance in accelerometer readings (higher = more movement)
  double get variance => _validator.variance;

  /// Average magnitude of accelerometer readings (should be ~9.8 m/s^2 at rest)
  double get avgMagnitude => _validator.avgMagnitude;

  /// Start listening to accelerometer events.
  ///
  /// Safe to call multiple times - will only start once.
  /// Uses 5Hz polling (200ms) for battery optimization while maintaining
  /// sufficient samples for movement variance calculation.
  void startListening() {
    if (_isListening) {
      debugPrint('AccelerometerService: Already listening');
      return;
    }

    _validator.reset();
    _eventCount = 0;

    try {
      _subscription =
          accelerometerEventStream(
            samplingPeriod: _samplingPeriod, // 5 Hz for battery optimization
          ).listen(
            _onAccelerometerEvent,
            onError: (error) {
              // Sensor may not be available (e.g., iOS Simulator, missing hardware)
              debugPrint('AccelerometerService: Sensor error - $error');
              debugPrint(
                'AccelerometerService: Anti-spoofing will use GPS-only validation',
              );
            },
            cancelOnError: false, // Keep listening even if one error occurs
          );
      _isListening = true;
      _noDataWarningShown = false;
      debugPrint(
        'AccelerometerService: Started listening at ${1000 ~/ _samplingPeriod.inMilliseconds}Hz',
      );

      // Start a timer to warn if no accelerometer events are received
      // This helps identify iOS Simulator or devices without accelerometer
      _noDataWarningTimer?.cancel();
      _noDataWarningTimer = Timer(_noDataWarningTimeout, () {
        if (_eventCount == 0 && !_noDataWarningShown) {
          _noDataWarningShown = true;
          debugPrint(
            'AccelerometerService: WARNING - No accelerometer events received after '
            '${_noDataWarningTimeout.inSeconds}s. '
            'Likely running on iOS Simulator or device without accelerometer. '
            'GPS-only validation will be used (anti-spoofing disabled).',
          );
        }
      });
    } catch (e) {
      debugPrint('AccelerometerService: Failed to start - $e');
      debugPrint(
        'AccelerometerService: Anti-spoofing will use GPS-only validation',
      );
    }
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    _eventCount++;
    _validator.addSample(event.x, event.y, event.z);

    // Log first event to confirm accelerometer is working
    if (_eventCount == 1) {
      // Cancel the no-data warning timer since we got data
      _noDataWarningTimer?.cancel();
      _noDataWarningTimer = null;
      debugPrint(
        'AccelerometerService: First event received - accelerometer active',
      );
    }
    // Periodic status every 100 events (~20 seconds at 5Hz)
    if (_eventCount % 100 == 0) {
      debugPrint(
        'AccelerometerService: $_eventCount events, '
        'variance=${_validator.variance.toStringAsFixed(2)}, '
        'moving=${_validator.isMoving}',
      );
    }
  }

  /// Stop listening to accelerometer events.
  ///
  /// Safe to call multiple times.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _noDataWarningTimer?.cancel();
    _noDataWarningTimer = null;
    _isListening = false;
    _noDataWarningShown = false;
    _validator.reset();
    debugPrint(
      'AccelerometerService: Stopped listening (received $_eventCount events)',
    );
  }

  /// Validate GPS movement against accelerometer data.
  ///
  /// Returns a [ValidationResult] indicating whether the GPS movement
  /// is consistent with physical device movement.
  ///
  /// If no recent accelerometer data is available, returns valid (graceful fallback).
  ///
  /// [gpsDistanceMeters] - Distance reported by GPS
  /// [timeSeconds] - Time interval for the distance
  ValidationResult validateGpsMovement(
    double gpsDistanceMeters,
    double timeSeconds,
  ) {
    if (!_validator.hasRecentData()) {
      // No accelerometer data - gracefully allow GPS point
      // Only log once per session to avoid spam (warning timer handles the main notification)
      return ValidationResult.valid();
    }

    return _validator.validateGpsMovement(gpsDistanceMeters, timeSeconds);
  }

  /// Clean up resources
  void dispose() {
    stopListening();
  }
}
