import 'dart:math' as math;

/// Represents a single GPS location point captured during a run
class LocationPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy; // GPS accuracy in meters (optional)
  final double? speed; // Speed in m/s (optional)
  final double? altitude; // Altitude in meters (optional)
  final double? heading; // Heading in degrees (optional)
  final bool isValid; // Whether this point passed anti-spoofing checks

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.speed,
    this.altitude,
    this.heading,
    this.isValid = true,
  });

  /// Create LocationPoint from JSON
  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
      accuracy: json['accuracy'] as double?,
      speed: json['speed'] as double?,
      altitude: json['altitude'] as double?,
      heading: json['heading'] as double?,
      isValid: json['isValid'] as bool? ?? true,
    );
  }

  /// Convert LocationPoint to JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
      'speed': speed,
      'altitude': altitude,
      'heading': heading,
      'isValid': isValid,
    };
  }

  /// Calculate distance to another point using Haversine formula (in meters)
  double distanceTo(LocationPoint other) {
    const double earthRadius = 6371000; // meters

    final double lat1Rad = latitude * math.pi / 180;
    final double lat2Rad = other.latitude * math.pi / 180;
    final double deltaLat = (other.latitude - latitude) * math.pi / 180;
    final double deltaLng = (other.longitude - longitude) * math.pi / 180;

    final double a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calculate time difference to another point in seconds
  double timeDifferenceSeconds(LocationPoint other) {
    return other.timestamp.difference(timestamp).inMilliseconds / 1000.0;
  }

  /// Calculate speed between two points (m/s)
  double calculateSpeedTo(LocationPoint other) {
    final double distance = distanceTo(other);
    final double time = timeDifferenceSeconds(other).abs();
    if (time == 0) return 0;
    return distance / time;
  }

  /// Create a copy with modified fields
  LocationPoint copyWith({
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    double? accuracy,
    double? speed,
    double? altitude,
    double? heading,
    bool? isValid,
  }) {
    return LocationPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      altitude: altitude ?? this.altitude,
      heading: heading ?? this.heading,
      isValid: isValid ?? this.isValid,
    );
  }

  @override
  String toString() {
    return 'LocationPoint(lat: $latitude, lng: $longitude, '
        'time: $timestamp, valid: $isValid)';
  }
}
