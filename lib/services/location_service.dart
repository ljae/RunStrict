import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/location_point.dart';

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
  final StreamController<LocationPoint> _locationController =
      StreamController<LocationPoint>.broadcast();

  /// Stream of location updates
  Stream<LocationPoint> get locationStream => _locationController.stream;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

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

    // Request background location permission for iOS (optional, won't block)
    if (permission.isGranted) {
      await Permission.locationAlways.request();
    }

    return PermissionResult(
      granted: permission.isGranted,
      message: permission.isGranted
          ? 'Permission granted'
          : 'Permission denied',
    );
  }

  /// Start tracking GPS location
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

    // Configure location settings for high accuracy
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    // Subscribe to position stream
    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            final locationPoint = LocationPoint(
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: position.timestamp,
              accuracy: position.accuracy,
              speed: position.speed,
              altitude: position.altitude,
              heading: position.heading,
            );
            _locationController.add(locationPoint);
          },
          onError: (error) {
            // Log error for debugging
            // TODO: Replace with proper logging in production
            // ignore: avoid_print
            print('Location error: $error');
          },
        );
  }

  /// Stop tracking GPS location
  Future<void> stopTracking() async {
    if (!_isTracking) return;

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
      // ignore: avoid_print
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Clean up resources
  void dispose() {
    _positionSubscription?.cancel();
    _locationController.close();
  }
}
