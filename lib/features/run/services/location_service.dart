import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../data/models/location_point.dart';
import '../../../core/services/remote_config_service.dart';

/// GPS Signal Quality
enum GpsSignalQuality { none, poor, fair, good, excellent }

/// Result of permission request
class PermissionResult {
  final bool granted;
  final String message;
  final bool canOpenSettings;

  PermissionResult({
    required this.granted,
    required this.message,
    this.canOpenSettings = false,
  });
}

/// Exception thrown when location permission is not granted
class LocationPermissionException implements Exception {
  final String message;
  final bool canOpenSettings;

  LocationPermissionException(this.message, {this.canOpenSettings = false});

  @override
  String toString() => message;
}

/// Service responsible for GPS tracking and location permissions
class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  Timer? _pollingTimer;
  final StreamController<LocationPoint> _locationController =
      StreamController<LocationPoint>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  /// Stream of location updates
  Stream<LocationPoint> get locationStream => _locationController.stream;

  /// Stream of GPS error messages for consumers to observe
  Stream<String> get errorStream => _errorController.stream;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  /// Polling rate in Hz (fixed: 0.5 = every 2 seconds)
  /// Fixed rate for battery optimization and consistent behavior.
  static double get _fixedPollingRateHz =>
      RemoteConfigService().configSnapshot.gpsConfig.pollingRateHz;
  double get pollingRateHz => _fixedPollingRateHz;

  /// Check and request location permissions
  Future<PermissionResult> requestPermissions() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return PermissionResult(
        granted: false,
        message:
            'Location Services are DISABLED on this device. Please enable them in Settings > Privacy.',
      );
    }

    // Check current permission status
    PermissionStatus currentStatus = await Permission.location.status;

    // If permanently denied, guide user to settings
    if (currentStatus.isPermanentlyDenied) {
      return PermissionResult(
        granted: false,
        message:
            'Permission Error: Status is "permanentlyDenied". Tap Open Settings.',
        canOpenSettings: true,
      );
    }

    // Request location permission
    PermissionStatus permission = await Permission.location.request();

    if (permission.isDenied) {
      return PermissionResult(
        granted: false,
        message: 'Permission Error: User denied permission (Status: denied).',
      );
    }

    if (permission.isPermanentlyDenied) {
      return PermissionResult(
        granted: false,
        message:
            'Permission Error: System blocked permission (Status: permanentlyDenied). Tap Open Settings.',
        canOpenSettings: true,
      );
    }

    // Request background location permission for iOS (optional, non-blocking).
    // Using unawaited to avoid blocking startTracking() with a system dialog
    // that appears mid-countdown and makes the app appear halted.
    if (permission.isGranted) {
      unawaited(Permission.locationAlways.request());
    }

    return PermissionResult(
      granted: permission.isGranted,
      message: permission.isGranted
          ? 'Permission granted'
          : 'Permission denied',
    );
  }

  /// Build platform-specific location settings.
  /// Android: uses a foreground service with a persistent notification so GPS
  /// keeps working when the screen is off — no ACCESS_BACKGROUND_LOCATION needed.
  /// iOS: uses fitness activity type for better accuracy during runs.
  LocationSettings _buildLocationSettings({int? distanceFilterMeters}) {
    final accuracy = LocationAccuracy.high;
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: accuracy,
        intervalDuration: Duration(
          milliseconds: (1000 / _fixedPollingRateHz).round(),
        ),
        distanceFilter: distanceFilterMeters ?? 0,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Run in Progress',
          notificationText: 'Runstrict is tracking your route',
          enableWakeLock: true,
          notificationChannelName: 'RunStrict Location Tracking',
        ),
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: accuracy,
        activityType: ActivityType.fitness,
        distanceFilter: distanceFilterMeters ?? 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilterMeters ?? 0,
    );
  }

  /// Start tracking GPS location.
  /// On Android, launches a foreground service with a persistent notification
  /// so GPS continues when the screen is off.
  Future<void> startTracking() async {
    if (_isTracking) return;

    final permissionResult = await requestPermissions();
    if (!permissionResult.granted) {
      throw LocationPermissionException(
        permissionResult.message,
        canOpenSettings: permissionResult.canOpenSettings,
      );
    }

    _isTracking = true;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
    ).listen(
      (Position position) {
        if (!_isTracking) return;
        _locationController.add(LocationPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: position.timestamp,
          accuracy: position.accuracy,
          speed: position.speed,
          altitude: position.altitude,
          heading: position.heading,
        ));
      },
      onError: (error) {
        debugPrint('LocationService: GPS stream error - $error');
        _errorController.add('GPS signal lost: $error');
      },
    );
  }

  /// Start tracking with distance-based updates.
  Future<void> startTrackingDistanceBased({
    int distanceFilterMeters = 5,
  }) async {
    if (_isTracking) return;

    final permissionResult = await requestPermissions();
    if (!permissionResult.granted) {
      throw LocationPermissionException(
        permissionResult.message,
        canOpenSettings: permissionResult.canOpenSettings,
      );
    }

    _isTracking = true;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(
        distanceFilterMeters: distanceFilterMeters,
      ),
    ).listen(
      (Position position) {
        _locationController.add(LocationPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: position.timestamp,
          accuracy: position.accuracy,
          speed: position.speed,
          altitude: position.altitude,
          heading: position.heading,
        ));
      },
      onError: (error) {
        debugPrint('LocationService: Distance-based tracking error - $error');
        _errorController.add('GPS signal lost: $error');
      },
    );
  }

  /// Stop tracking GPS location and stop the foreground service (Android).
  Future<void> stopTracking() async {
    if (!_isTracking) return;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
  }

  /// Get current location (one-time request)
  Future<LocationPoint?> getCurrentLocation() async {
    final permissionResult = await requestPermissions();
    if (!permissionResult.granted) return null;

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
        altitude: position.altitude,
        heading: position.heading,
      );
    } catch (e) {
      // Log error for debugging
      // TODO: Replace with proper logging in production
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  /// Clean up resources
  void dispose() {
    _pollingTimer?.cancel();
    _positionSubscription?.cancel();
    _errorController.close();
    _locationController.close();
  }
}
