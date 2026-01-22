import '../models/location_point.dart';

/// GPS Anti-Spoofing Validation Result
class ValidationResult {
  final bool isValid;
  final String? rejectionReason;
  final double? calculatedSpeed;
  final double? calculatedDistance;

  const ValidationResult({
    required this.isValid,
    this.rejectionReason,
    this.calculatedSpeed,
    this.calculatedDistance,
  });

  factory ValidationResult.valid({
    double? calculatedSpeed,
    double? calculatedDistance,
  }) {
    return ValidationResult(
      isValid: true,
      calculatedSpeed: calculatedSpeed,
      calculatedDistance: calculatedDistance,
    );
  }

  factory ValidationResult.invalid(String reason) {
    return ValidationResult(isValid: false, rejectionReason: reason);
  }
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
  // Configuration constants
  static const double maxSpeedMps = 6.94; // 25 km/h in m/s (fast sprint pace)
  static const double minSpeedMps = 0.3; // Below this, consider stationary
  static const double maxAccuracyMeters = 50.0; // Reject if accuracy > 50m
  static const double maxAltitudeChangeMps = 5.0; // Max vertical speed
  static const double minTimeBetweenPointsMs =
      500; // At least 0.5s between points
  static const double maxJumpDistanceMeters = 100; // Max jump in single update

  // Track suspicious activity
  int _consecutiveRejects = 0;
  int _totalRejects = 0;
  int _totalPoints = 0;
  DateTime? _lastValidTimestamp;

  /// Statistics getters
  int get consecutiveRejects => _consecutiveRejects;
  int get totalRejects => _totalRejects;
  int get totalPoints => _totalPoints;
  double get rejectRate =>
      _totalPoints > 0 ? _totalRejects / _totalPoints : 0.0;

  /// Reset validation state (call when starting new run)
  void reset() {
    _consecutiveRejects = 0;
    _totalRejects = 0;
    _totalPoints = 0;
    _lastValidTimestamp = null;
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

    return ValidationResult.valid(
      calculatedSpeed: calculatedSpeed,
      calculatedDistance: distance,
    );
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
    return 'GPS validation: ${_totalPoints - _totalRejects}/${_totalPoints} points valid';
  }
}
