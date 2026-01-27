import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'gps_validator.dart';

/// Service for managing accelerometer sensor subscription and validation.
///
/// Provides anti-spoofing by detecting if the device is actually moving
/// when GPS reports movement. Uses [AccelerometerValidator] from gps_validator.dart.
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

  final AccelerometerValidator _validator = AccelerometerValidator();
  StreamSubscription<AccelerometerEvent>? _subscription;
  bool _isListening = false;

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
  void startListening() {
    if (_isListening) {
      debugPrint('AccelerometerService: Already listening');
      return;
    }

    _validator.reset();

    try {
      _subscription =
          accelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 100), // 10 Hz
          ).listen(
            _onAccelerometerEvent,
            onError: (error) {
              debugPrint('AccelerometerService error: $error');
            },
          );
      _isListening = true;
      debugPrint('AccelerometerService: Started listening');
    } catch (e) {
      debugPrint('AccelerometerService: Failed to start - $e');
    }
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    _validator.addSample(event.x, event.y, event.z);
  }

  /// Stop listening to accelerometer events.
  ///
  /// Safe to call multiple times.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    _validator.reset();
    debugPrint('AccelerometerService: Stopped listening');
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
      debugPrint('AccelerometerService: No recent data, allowing GPS point');
      return ValidationResult.valid();
    }

    return _validator.validateGpsMovement(gpsDistanceMeters, timeSeconds);
  }

  /// Clean up resources
  void dispose() {
    stopListening();
  }
}
