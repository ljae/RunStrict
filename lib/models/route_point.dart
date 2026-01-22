/// Minimal route point for Cold Storage.
/// Only stores essential data to reconstruct the route.
///
/// Full LocationPoint is used during active runs,
/// but this compact format is used for archival.
class RoutePoint {
  final double lat;
  final double lng;
  final int timestampMs; // Milliseconds since epoch (compact)

  const RoutePoint({
    required this.lat,
    required this.lng,
    required this.timestampMs,
  });

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(timestampMs);

  /// Compact binary-friendly serialization (for batch storage)
  /// Format: [lat, lng, timestampMs] - 24 bytes total
  List<double> toCompact() => [lat, lng, timestampMs.toDouble()];

  factory RoutePoint.fromCompact(List<dynamic> data) => RoutePoint(
        lat: (data[0] as num).toDouble(),
        lng: (data[1] as num).toDouble(),
        timestampMs: (data[2] as num).toInt(),
      );

  /// JSON serialization (for debugging/fallback)
  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'ts': timestampMs,
      };

  factory RoutePoint.fromJson(Map<String, dynamic> json) => RoutePoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        timestampMs: (json['ts'] as num).toInt(),
      );

  /// Create from full LocationPoint (at run completion)
  factory RoutePoint.fromLocationPoint(dynamic locationPoint) {
    // locationPoint is LocationPoint from location_point.dart
    return RoutePoint(
      lat: locationPoint.latitude as double,
      lng: locationPoint.longitude as double,
      timestampMs: (locationPoint.timestamp as DateTime).millisecondsSinceEpoch,
    );
  }
}

/// Compressed route data for Cold Storage.
/// Stores a run's entire route in a compact format.
class CompressedRoute {
  final String runId;
  final List<RoutePoint> points;
  final int totalBytes;

  CompressedRoute({
    required this.runId,
    required this.points,
  }) : totalBytes = points.length * 24; // Approximate size

  /// Convert all points to compact format for storage
  List<List<double>> toCompactList() =>
      points.map((p) => p.toCompact()).toList();

  factory CompressedRoute.fromCompactList(
    String runId,
    List<dynamic> data,
  ) =>
      CompressedRoute(
        runId: runId,
        points: data.map((d) => RoutePoint.fromCompact(d as List)).toList(),
      );

  /// Estimate storage size in KB
  double get sizeKb => totalBytes / 1024;
}
