import 'dart:collection';
import 'dart:math' as math;
import '../../../data/models/location_point.dart';
import '../../../core/services/remote_config_service.dart';

/// GPS Anti-Spoofing Validation Result
class ValidationResult {
  final bool isValid;
  final String? rejectionReason;
  final double? calculatedSpeed;
  final double? calculatedDistance;
  final double? movingAvgPaceMinPerKm;

  const ValidationResult({
    required this.isValid,
    this.rejectionReason,
    this.calculatedSpeed,
    this.calculatedDistance,
    this.movingAvgPaceMinPerKm,
  });

  factory ValidationResult.valid({
    double? calculatedSpeed,
    double? calculatedDistance,
    double? movingAvgPaceMinPerKm,
  }) {
    return ValidationResult(
      isValid: true,
      calculatedSpeed: calculatedSpeed,
      calculatedDistance: calculatedDistance,
      movingAvgPaceMinPerKm: movingAvgPaceMinPerKm,
    );
  }

  factory ValidationResult.invalid(String reason) {
    return ValidationResult(isValid: false, rejectionReason: reason);
  }
}

/// Represents a distance-time sample for moving average calculation
class _PaceSample {
  final DateTime timestamp;
  final double distanceMeters;

  const _PaceSample({required this.timestamp, required this.distanceMeters});
}

/// GPS Anti-Spoofing Validator
///
/// Implements multiple layers of validation to detect GPS spoofing:
/// 1. Speed Filter: Max 25 km/h (6.94 m/s) for running
/// 2. Accuracy Filter: Reject low-quality GPS signals
/// 3. Trajectory Validation: Check for impossible jumps
/// 4. Time Validation: Check for timestamp anomalies
/// 5. Altitude Validation: Check for impossible altitude changes
class GpsValidator {
  // Configuration getters (read from RemoteConfigService)
  static double get maxSpeedMps =>
      RemoteConfigService().configSnapshot.gpsConfig.maxSpeedMps;
  static double get minSpeedMps =>
      RemoteConfigService().configSnapshot.gpsConfig.minSpeedMps;
  static double get maxAccuracyMeters =>
      RemoteConfigService().configSnapshot.gpsConfig.maxAccuracyMeters;
  static double get maxAltitudeChangeMps =>
      RemoteConfigService().configSnapshot.gpsConfig.maxAltitudeChangeMps;
  static double get minTimeBetweenPointsMs => RemoteConfigService()
      .configSnapshot
      .gpsConfig
      .minTimeBetweenPointsMs
      .toDouble();
  static double get maxJumpDistanceMeters =>
      RemoteConfigService().configSnapshot.gpsConfig.maxJumpDistanceMeters;
  static int get movingAvgWindowSeconds =>
      RemoteConfigService().configSnapshot.gpsConfig.movingAvgWindowSeconds;

  // Track suspicious activity
  int _consecutiveRejects = 0;
  int _totalRejects = 0;
  int _totalPoints = 0;
  DateTime? _lastValidTimestamp;

  // Moving average pace tracking
  final Queue<_PaceSample> _paceSamples = Queue<_PaceSample>();
  double _movingAvgPaceMinPerKm = double.infinity;

  /// Statistics getters
  int get consecutiveRejects => _consecutiveRejects;
  int get totalRejects => _totalRejects;
  int get totalPoints => _totalPoints;
  double get rejectRate =>
      _totalPoints > 0 ? _totalRejects / _totalPoints : 0.0;
  DateTime? get lastValidTimestamp => _lastValidTimestamp;

  /// Current moving average pace (min/km) over last 20 seconds.
  /// At 0.5Hz GPS polling, this provides ~10 samples for stable calculation.
  /// Returns infinity if not enough data.
  double get movingAvgPaceMinPerKm => _movingAvgPaceMinPerKm;

  /// Check if current moving average pace is valid for hex capture.
  /// Must be < 8:00 min/km as per spec §2.4.2.
  static double get maxCapturePaceMinPerKm =>
      RemoteConfigService().configSnapshot.gpsConfig.maxCapturePaceMinPerKm;
  bool get canCaptureAtCurrentPace =>
      _movingAvgPaceMinPerKm < maxCapturePaceMinPerKm;

  /// Reset validation state (call when starting new run)
  void reset() {
    _consecutiveRejects = 0;
    _totalRejects = 0;
    _totalPoints = 0;
    _lastValidTimestamp = null;
    _paceSamples.clear();
    _movingAvgPaceMinPerKm = double.infinity;
  }

  /// Check if GPS signal quality is acceptable
  ValidationResult validateAccuracy(LocationPoint point) {
    final accuracy = point.accuracy;
    if (accuracy == null) {
      // No accuracy info - accept but note it
      return ValidationResult.valid();
    }

    if (accuracy > maxAccuracyMeters) {
      return ValidationResult.invalid(
        'Poor GPS accuracy: ${accuracy.toStringAsFixed(1)}m > ${maxAccuracyMeters}m',
      );
    }

    return ValidationResult.valid();
  }

  /// Check if reported speed is within running limits
  ValidationResult validateReportedSpeed(LocationPoint point) {
    final speed = point.speed;
    if (speed == null) {
      return ValidationResult.valid();
    }

    // Speed is already in m/s from geolocator
    if (speed > maxSpeedMps) {
      return ValidationResult.invalid(
        'Speed too high: ${(speed * 3.6).toStringAsFixed(1)} km/h > ${(maxSpeedMps * 3.6).toStringAsFixed(1)} km/h',
      );
    }

    return ValidationResult.valid(calculatedSpeed: speed);
  }

  /// Validate trajectory between two consecutive points
  ValidationResult validateTrajectory(
    LocationPoint previous,
    LocationPoint current,
  ) {
    // Calculate distance
    final distance = previous.distanceTo(current);

    // Calculate time difference
    final timeDiff = previous.timeDifferenceSeconds(current);

    // Check for timestamp anomalies
    if (timeDiff <= 0) {
      return ValidationResult.invalid(
        'Invalid timestamp: time went backwards or stopped',
      );
    }

    if (timeDiff * 1000 < minTimeBetweenPointsMs) {
      return ValidationResult.invalid(
        'Points too close in time: ${timeDiff.toStringAsFixed(2)}s',
      );
    }

    // Check for impossible jump
    if (distance > maxJumpDistanceMeters && timeDiff < 10) {
      return ValidationResult.invalid(
        'Impossible jump: ${distance.toStringAsFixed(1)}m in ${timeDiff.toStringAsFixed(1)}s',
      );
    }

    // Calculate actual speed from trajectory
    final calculatedSpeed = distance / timeDiff;

    if (calculatedSpeed > maxSpeedMps) {
      return ValidationResult.invalid(
        'Calculated speed too high: ${(calculatedSpeed * 3.6).toStringAsFixed(1)} km/h',
      );
    }

    // Check altitude change if available
    if (previous.altitude != null && current.altitude != null) {
      final altitudeChange = (current.altitude! - previous.altitude!).abs();
      final verticalSpeed = altitudeChange / timeDiff;

      if (verticalSpeed > maxAltitudeChangeMps) {
        return ValidationResult.invalid(
          'Impossible altitude change: ${altitudeChange.toStringAsFixed(1)}m in ${timeDiff.toStringAsFixed(1)}s',
        );
      }
    }

    // Update moving average pace
    _updateMovingAvgPace(current.timestamp, distance);

    return ValidationResult.valid(
      calculatedSpeed: calculatedSpeed,
      calculatedDistance: distance,
      movingAvgPaceMinPerKm: _movingAvgPaceMinPerKm,
    );
  }

  /// Update the 20-second moving average pace.
  ///
  /// Adds a new sample and removes samples older than 20 seconds.
  /// At 0.5Hz GPS polling, this provides ~10 samples for stable pace calculation.
  void _updateMovingAvgPace(DateTime timestamp, double distanceMeters) {
    // Add new sample
    _paceSamples.addLast(
      _PaceSample(timestamp: timestamp, distanceMeters: distanceMeters),
    );

    // Remove samples older than the window
    final cutoff = timestamp.subtract(
      Duration(seconds: movingAvgWindowSeconds),
    );
    while (_paceSamples.isNotEmpty &&
        _paceSamples.first.timestamp.isBefore(cutoff)) {
      _paceSamples.removeFirst();
    }

    // Calculate moving average pace
    if (_paceSamples.length < 2) {
      _movingAvgPaceMinPerKm = double.infinity;
      return;
    }

    // Sum distance in window
    double totalDistance = 0;
    for (final sample in _paceSamples) {
      totalDistance += sample.distanceMeters;
    }

    // Calculate time span in window
    final windowDurationSeconds =
        _paceSamples.last.timestamp
            .difference(_paceSamples.first.timestamp)
            .inMilliseconds /
        1000.0;

    if (windowDurationSeconds <= 0 || totalDistance <= 0) {
      _movingAvgPaceMinPerKm = double.infinity;
      return;
    }

    // Speed in m/s
    final speedMps = totalDistance / windowDurationSeconds;

    // Convert to min/km: pace = 1000 / (speed * 60) = 1000 / (speed_mps * 60)
    // Or pace_min_per_km = (1 / speed_km_per_min) = 1 / (speed_mps * 60 / 1000)
    // = 1000 / (speed_mps * 60) = 16.667 / speed_mps
    if (speedMps > 0) {
      _movingAvgPaceMinPerKm = (1000 / 60) / speedMps;
    } else {
      _movingAvgPaceMinPerKm = double.infinity;
    }
  }

  /// Full validation of a new point against the previous point
  ValidationResult validate(LocationPoint? previous, LocationPoint current) {
    _totalPoints++;

    // 1. Check accuracy
    final accuracyResult = validateAccuracy(current);
    if (!accuracyResult.isValid) {
      _recordReject();
      return accuracyResult;
    }

    // 2. Check reported speed
    final speedResult = validateReportedSpeed(current);
    if (!speedResult.isValid) {
      _recordReject();
      return speedResult;
    }

    // 3. If we have a previous point, validate trajectory
    if (previous != null) {
      final trajectoryResult = validateTrajectory(previous, current);
      if (!trajectoryResult.isValid) {
        _recordReject();
        return trajectoryResult;
      }

      _recordValid(current.timestamp);
      return trajectoryResult;
    }

    // First point - accept it
    _recordValid(current.timestamp);
    return ValidationResult.valid();
  }

  void _recordReject() {
    _consecutiveRejects++;
    _totalRejects++;
  }

  void _recordValid(DateTime timestamp) {
    _consecutiveRejects = 0;
    _lastValidTimestamp = timestamp;
  }

  /// Check if spoofing is likely based on rejection patterns
  bool isLikelySpoofing() {
    // If more than 5 consecutive rejects, likely spoofing
    if (_consecutiveRejects >= 5) return true;

    // If more than 30% of points rejected, suspicious
    if (_totalPoints > 10 && rejectRate > 0.3) return true;

    return false;
  }

  /// Get a summary message for the current state
  String getSummary() {
    if (isLikelySpoofing()) {
      return 'Warning: Possible GPS spoofing detected';
    }
    return 'GPS validation: ${_totalPoints - _totalRejects}/$_totalPoints points valid';
  }
}

/// 1D Kalman Filter for smoothing GPS coordinate components.
class _KalmanFilter1D {
  double _estimate;
  double _errorEstimate;
  final double _processNoise;
  final double _measurementNoise;

  _KalmanFilter1D({
    required double initialEstimate,
    required double initialError,
    required double processNoise,
    required double measurementNoise,
  }) : _estimate = initialEstimate,
       _errorEstimate = initialError,
       _processNoise = processNoise,
       _measurementNoise = measurementNoise;

  double get estimate => _estimate;
  double get errorEstimate => _errorEstimate;

  double update(double measurement) {
    final prediction = _estimate;
    final predictionError = _errorEstimate + _processNoise;

    final kalmanGain = predictionError / (predictionError + _measurementNoise);
    _estimate = prediction + kalmanGain * (measurement - prediction);
    _errorEstimate = (1 - kalmanGain) * predictionError;

    return _estimate;
  }

  void reset(double estimate, double error) {
    _estimate = estimate;
    _errorEstimate = error;
  }
}

/// GPS Kalman Filter for smoothing latitude/longitude coordinates.
/// Reduces noise from GPS sensor while preserving actual movement.
class GpsKalmanFilter {
  _KalmanFilter1D? _latFilter;
  _KalmanFilter1D? _lngFilter;
  _KalmanFilter1D? _altFilter;

  final double _processNoise;
  final double _measurementNoise;
  final double _initialError;

  DateTime? _lastTimestamp;
  double? _lastLat;
  double? _lastLng;

  GpsKalmanFilter({
    double processNoise = 0.00001,
    double measurementNoise = 0.0001,
    double initialError = 0.001,
  }) : _processNoise = processNoise,
       _measurementNoise = measurementNoise,
       _initialError = initialError;

  bool get isInitialized => _latFilter != null;

  void reset() {
    _latFilter = null;
    _lngFilter = null;
    _altFilter = null;
    _lastTimestamp = null;
    _lastLat = null;
    _lastLng = null;
  }

  LocationPoint filter(LocationPoint point) {
    if (_latFilter == null) {
      _latFilter = _KalmanFilter1D(
        initialEstimate: point.latitude,
        initialError: _initialError,
        processNoise: _processNoise,
        measurementNoise: _measurementNoise,
      );
      _lngFilter = _KalmanFilter1D(
        initialEstimate: point.longitude,
        initialError: _initialError,
        processNoise: _processNoise,
        measurementNoise: _measurementNoise,
      );
      if (point.altitude != null) {
        _altFilter = _KalmanFilter1D(
          initialEstimate: point.altitude!,
          initialError: 10.0,
          processNoise: 0.1,
          measurementNoise: 5.0,
        );
      }
      _lastTimestamp = point.timestamp;
      _lastLat = point.latitude;
      _lastLng = point.longitude;
      return point;
    }

    final timeDelta = _lastTimestamp != null
        ? point.timestamp.difference(_lastTimestamp!).inMilliseconds / 1000.0
        : 1.0;

    double adaptedMeasurementNoise = _measurementNoise;
    if (point.accuracy != null && point.accuracy! > 0) {
      adaptedMeasurementNoise = _measurementNoise * (point.accuracy! / 10.0);
    }

    final tempLatFilter = _KalmanFilter1D(
      initialEstimate: _latFilter!.estimate,
      initialError: _latFilter!.errorEstimate,
      processNoise: _processNoise * timeDelta,
      measurementNoise: adaptedMeasurementNoise,
    );
    final tempLngFilter = _KalmanFilter1D(
      initialEstimate: _lngFilter!.estimate,
      initialError: _lngFilter!.errorEstimate,
      processNoise: _processNoise * timeDelta,
      measurementNoise: adaptedMeasurementNoise,
    );

    final filteredLat = tempLatFilter.update(point.latitude);
    final filteredLng = tempLngFilter.update(point.longitude);

    _latFilter = tempLatFilter;
    _lngFilter = tempLngFilter;

    double? filteredAlt;
    if (point.altitude != null && _altFilter != null) {
      filteredAlt = _altFilter!.update(point.altitude!);
    }

    _lastTimestamp = point.timestamp;
    _lastLat = filteredLat;
    _lastLng = filteredLng;

    return LocationPoint(
      latitude: filteredLat,
      longitude: filteredLng,
      altitude: filteredAlt ?? point.altitude,
      accuracy: point.accuracy,
      speed: point.speed,
      heading: point.heading,
      timestamp: point.timestamp,
    );
  }

  double distanceFromLast(LocationPoint point) {
    if (_lastLat == null || _lastLng == null) return 0;

    const double earthRadius = 6371000;
    final dLat = _toRadians(point.latitude - _lastLat!);
    final dLng = _toRadians(point.longitude - _lastLng!);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(_lastLat!)) *
            math.cos(_toRadians(point.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}

/// Accelerometer-based motion validator for anti-spoofing.
/// Validates that GPS movement correlates with actual device motion.
class AccelerometerValidator {
  final Queue<_AccelSample> _samples = Queue<_AccelSample>();
  static const int _sampleWindowMs = 2000;
  static const double _minMovementThreshold = 0.5;
  static const double _maxStationaryVariance = 0.3;

  double _variance = 0;
  double _avgMagnitude = 0;
  bool _isMoving = false;
  DateTime? _lastUpdate;

  bool get isMoving => _isMoving;
  double get variance => _variance;
  double get avgMagnitude => _avgMagnitude;

  void reset() {
    _samples.clear();
    _variance = 0;
    _avgMagnitude = 0;
    _isMoving = false;
    _lastUpdate = null;
  }

  void addSample(double x, double y, double z) {
    final now = DateTime.now();
    final magnitude = math.sqrt(x * x + y * y + z * z);

    _samples.addLast(
      _AccelSample(timestamp: now, x: x, y: y, z: z, magnitude: magnitude),
    );

    final cutoff = now.subtract(const Duration(milliseconds: _sampleWindowMs));
    while (_samples.isNotEmpty && _samples.first.timestamp.isBefore(cutoff)) {
      _samples.removeFirst();
    }

    _updateStats();
    _lastUpdate = now;
  }

  void _updateStats() {
    if (_samples.length < 5) {
      _variance = 0;
      _avgMagnitude = 9.8;
      _isMoving = false;
      return;
    }

    double sumMag = 0;
    for (final s in _samples) {
      sumMag += s.magnitude;
    }
    _avgMagnitude = sumMag / _samples.length;

    double sumSquaredDiff = 0;
    for (final s in _samples) {
      final diff = s.magnitude - _avgMagnitude;
      sumSquaredDiff += diff * diff;
    }
    _variance = sumSquaredDiff / _samples.length;

    _isMoving = _variance > _minMovementThreshold;
  }

  ValidationResult validateGpsMovement(
    double gpsDistanceMeters,
    double timeSeconds,
  ) {
    if (_samples.length < 5) {
      return ValidationResult.valid();
    }

    final gpsSpeed = gpsDistanceMeters / timeSeconds;
    final gpsSpeedKmh = gpsSpeed * 3.6;

    if (gpsSpeedKmh > 5 && !_isMoving && _variance < _maxStationaryVariance) {
      return ValidationResult.invalid(
        'GPS shows ${gpsSpeedKmh.toStringAsFixed(1)} km/h but device appears stationary',
      );
    }

    if (gpsSpeedKmh < 1 && _isMoving && _variance > _minMovementThreshold * 2) {
      return ValidationResult.valid();
    }

    return ValidationResult.valid();
  }

  bool hasRecentData() {
    if (_lastUpdate == null) return false;
    return DateTime.now().difference(_lastUpdate!).inSeconds < 5;
  }
}

class _AccelSample {
  final DateTime timestamp;
  final double x;
  final double y;
  final double z;
  final double magnitude;

  const _AccelSample({
    required this.timestamp,
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
  });
}
