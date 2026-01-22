import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_point.dart';
import '../services/gps_validator.dart';

enum RunningState { idle, running, paused, completed }

/// GPS Signal Quality
enum GpsSignalQuality { none, poor, fair, good, excellent }

class RunningProvider with ChangeNotifier {
  RunningState _state = RunningState.idle;
  double _distance = 0.0;
  int _duration = 0; // in seconds
  double _pace = 0.0; // min/km
  final List<LocationPoint> _routePoints = [];
  LocationPoint? _lastValidPoint;
  Timer? _timer;
  StreamSubscription<Position>? _positionStreamSubscription;

  // GPS Validation
  final GpsValidator _gpsValidator = GpsValidator();
  GpsSignalQuality _signalQuality = GpsSignalQuality.none;
  String? _lastValidationError;
  bool _isSpoofingDetected = false;

  // Current position for map centering
  LocationPoint? _currentPosition;

  bool _isMetric = true; // true = km, km/h; false = mi, mph

  // Getters
  RunningState get state => _state;
  double get distance => _distance; // Always in km internally
  int get duration => _duration;
  double get pace => _pace; // min/km
  bool get isMetric => _isMetric;

  List<LocationPoint> get routePoints => List.unmodifiable(_routePoints);
  int get calories => (_distance * 65).round(); // ~65 cal/km estimate
  bool get isRunning => _state == RunningState.running;
  bool get isPaused => _state == RunningState.paused;
  bool get isActive =>
      _state == RunningState.running || _state == RunningState.paused;
  GpsSignalQuality get signalQuality => _signalQuality;
  String? get lastValidationError => _lastValidationError;
  bool get isSpoofingDetected => _isSpoofingDetected;
  LocationPoint? get currentPosition => _currentPosition;
  int get validPointsCount => _routePoints.where((p) => p.isValid).length;
  int get rejectedPointsCount => _gpsValidator.totalRejects;

  // Formatted Getters
  double get displayDistance {
    return _isMetric ? _distance : _distance * 0.621371;
  }

  String get distanceUnit => _isMetric ? 'KM' : 'MI';

  double get currentSpeed {
    // Distance (km) per hour
    // _pace is min/km. Speed = 60 / pace
    if (_pace <= 0 || _pace.isInfinite || _pace.isNaN) return 0.0;
    double speedKmh = 60 / _pace;
    return _isMetric ? speedKmh : speedKmh * 0.621371;
  }

  String get speedUnit => _isMetric ? 'KM/H' : 'MPH';

  String get formattedTime {
    final hours = _duration ~/ 3600;
    final minutes = (_duration % 3600) ~/ 60;
    final seconds = _duration % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Deprecated: Moving to Speed
  String get formattedPace {
    if (_pace <= 0 || _pace.isInfinite || _pace.isNaN) {
      return "--'--\"";
    }
    final minutes = _pace.floor();
    final seconds = ((_pace - minutes) * 60).round();
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
  }

  void toggleUnit() {
    _isMetric = !_isMetric;
    notifyListeners();
  }

  /// Start a new run session
  Future<void> startRun() async {
    // Check and request location permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Enable in Settings.',
      );
    }

    // Reset state
    _state = RunningState.running;
    _distance = 0.0;
    _duration = 0;
    _pace = 0.0;
    _routePoints.clear();
    _lastValidPoint = null;
    _currentPosition = null;
    _lastValidationError = null;
    _isSpoofingDetected = false;
    _gpsValidator.reset();

    // Start duration timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _duration++;
      _updatePace();
      notifyListeners();
    });

    // High accuracy GPS settings for running
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5, // Update every 5 meters for better route accuracy
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _handlePositionUpdate(position);
          },
          onError: (error) {
            _signalQuality = GpsSignalQuality.none;
            _lastValidationError = 'GPS error: $error';
            notifyListeners();
          },
        );

    notifyListeners();
  }

  /// Handle incoming GPS position update
  void _handlePositionUpdate(Position position) {
    // Update signal quality based on accuracy
    _updateSignalQuality(position.accuracy);

    // Create location point from position
    final point = LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
      speed: position.speed,
      altitude: position.altitude,
      heading: position.heading,
    );

    // Always update current position for map display
    _currentPosition = point;

    // Validate the point against anti-spoofing rules
    final validationResult = _gpsValidator.validate(_lastValidPoint, point);

    if (!validationResult.isValid) {
      // Point rejected - log but don't add to route
      _lastValidationError = validationResult.rejectionReason;
      _isSpoofingDetected = _gpsValidator.isLikelySpoofing();

      // Add as invalid point for debugging (optional)
      _routePoints.add(point.copyWith(isValid: false));
      notifyListeners();
      return;
    }

    // Valid point - add to route and update distance
    _lastValidationError = null;

    final validPoint = point.copyWith(isValid: true);
    _routePoints.add(validPoint);

    // Calculate distance from trajectory validation result
    if (_lastValidPoint != null &&
        validationResult.calculatedDistance != null) {
      _distance += validationResult.calculatedDistance! / 1000; // Convert to km
      _updatePace();
    }

    _lastValidPoint = validPoint;
    _isSpoofingDetected = _gpsValidator.isLikelySpoofing();
    notifyListeners();
  }

  /// Update GPS signal quality indicator
  void _updateSignalQuality(double accuracy) {
    if (accuracy <= 5) {
      _signalQuality = GpsSignalQuality.excellent;
    } else if (accuracy <= 10) {
      _signalQuality = GpsSignalQuality.good;
    } else if (accuracy <= 25) {
      _signalQuality = GpsSignalQuality.fair;
    } else if (accuracy <= 50) {
      _signalQuality = GpsSignalQuality.poor;
    } else {
      _signalQuality = GpsSignalQuality.none;
    }
  }

  /// Update pace calculation
  void _updatePace() {
    if (_duration > 0 && _distance > 0) {
      _pace = (_duration / 60) / _distance; // min/km
    }
  }

  /// Pause the current run
  void pauseRun() {
    if (_state == RunningState.running) {
      _state = RunningState.paused;
      _timer?.cancel(); // Stop the timer
      _positionStreamSubscription?.pause(); // Stop GPS updates
      notifyListeners();
    }
  }

  /// Resume a paused run
  void resumeRun() {
    if (_state == RunningState.paused) {
      _state = RunningState.running;

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _duration++;
        _updatePace();
        notifyListeners();
      });

      _positionStreamSubscription?.resume();
      notifyListeners();
    }
  }

  /// Stop and complete the current run
  Future<void> stopRun() async {
    _state = RunningState.completed;
    _timer?.cancel();
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    notifyListeners();

    // Reset after a short delay
    await Future.delayed(const Duration(milliseconds: 500));
    _reset();
  }

  /// Reset all run data
  void _reset() {
    _state = RunningState.idle;
    _distance = 0.0;
    _duration = 0;
    _pace = 0.0;
    _routePoints.clear();
    _lastValidPoint = null;
    _currentPosition = null;
    _signalQuality = GpsSignalQuality.none;
    _lastValidationError = null;
    _isSpoofingDetected = false;
    _gpsValidator.reset();
    notifyListeners();
  }

  /// Get current location one-time (for initial map position)
  Future<LocationPoint?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      return LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
        accuracy: position.accuracy,
        speed: position.speed,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }
}
