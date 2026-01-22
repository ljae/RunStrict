import 'dart:math' as math;
import '../models/location_point.dart';

/// Optimized route data management for scalability.
///
/// Key optimizations:
/// 1. Ring buffer for memory-efficient route storage
/// 2. Point decimation for rendering large routes
/// 3. Douglas-Peucker simplification for display
///
/// Performance targets:
/// - P95 latency: < 16ms for 60fps rendering
/// - Memory: O(maxPoints) fixed ceiling
/// - CPU: O(n) for simplification where n = visible points
class RouteOptimizer {
  // Configuration constants
  static const int defaultMaxPoints = 5000; // ~1-2 hours of running data
  static const int renderMaxPoints = 500; // Max points for smooth map rendering
  static const double minDistanceMeters =
      2.0; // Minimum distance between points
  static const double simplificationTolerance = 0.00001; // ~1 meter in degrees

  /// Fixed-size ring buffer for route points.
  /// When full, oldest points are automatically evicted.
  final List<LocationPoint> _buffer;
  final int maxPoints;
  int _head = 0; // Next write position
  int _count = 0; // Actual number of points

  RouteOptimizer({this.maxPoints = defaultMaxPoints})
    : _buffer = List.filled(maxPoints, _dummyPoint);

  static final LocationPoint _dummyPoint = LocationPoint(
    latitude: 0,
    longitude: 0,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    isValid: false,
  );

  /// Number of points currently stored
  int get length => _count;

  /// Check if buffer is empty
  bool get isEmpty => _count == 0;

  /// Check if buffer is at capacity
  bool get isFull => _count >= maxPoints;

  /// Add a new point to the buffer.
  /// Returns true if point was added (passes distance filter).
  bool addPoint(LocationPoint point) {
    if (!point.isValid) return false;

    // Distance filter: skip if too close to last point
    if (_count > 0) {
      final lastPoint = _getPoint(_count - 1);
      final distance = _haversineDistance(
        lastPoint.latitude,
        lastPoint.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < minDistanceMeters) {
        return false; // Skip - too close
      }
    }

    // Add to ring buffer
    _buffer[_head] = point;
    _head = (_head + 1) % maxPoints;
    if (_count < maxPoints) {
      _count++;
    }
    return true;
  }

  /// Get point at logical index (0 = oldest, count-1 = newest)
  LocationPoint _getPoint(int logicalIndex) {
    if (logicalIndex < 0 || logicalIndex >= _count) {
      throw RangeError.index(logicalIndex, this, 'logicalIndex');
    }
    final physicalIndex = _count < maxPoints
        ? logicalIndex
        : (_head + logicalIndex) % maxPoints;
    return _buffer[physicalIndex];
  }

  /// Get all points as a list (for compatibility)
  List<LocationPoint> get allPoints {
    if (_count == 0) return [];
    final result = <LocationPoint>[];
    for (int i = 0; i < _count; i++) {
      result.add(_getPoint(i));
    }
    return result;
  }

  /// Get the most recent point
  LocationPoint? get lastPoint => _count > 0 ? _getPoint(_count - 1) : null;

  /// Get the first (oldest) point
  LocationPoint? get firstPoint => _count > 0 ? _getPoint(0) : null;

  /// Get optimized points for map rendering.
  /// Uses uniform sampling + Douglas-Peucker for smooth curves.
  List<LocationPoint> getOptimizedForRendering({
    int maxPoints = renderMaxPoints,
  }) {
    if (_count <= maxPoints) {
      return allPoints;
    }

    // Step 1: Uniform downsampling to reduce point count
    final sampled = _uniformSample(
      maxPoints * 2,
    ); // 2x for Douglas-Peucker input

    // Step 2: Douglas-Peucker simplification for smooth curves
    return _douglasPeucker(sampled, simplificationTolerance, maxPoints);
  }

  /// Get the last N points (for recent path rendering)
  List<LocationPoint> getRecentPoints(int n) {
    if (n >= _count) return allPoints;
    final result = <LocationPoint>[];
    final start = _count - n;
    for (int i = start; i < _count; i++) {
      result.add(_getPoint(i));
    }
    return result;
  }

  /// Uniform sampling - pick every nth point
  List<LocationPoint> _uniformSample(int targetCount) {
    if (_count <= targetCount) return allPoints;

    final result = <LocationPoint>[];
    final step = _count / targetCount;

    for (int i = 0; i < targetCount - 1; i++) {
      final index = (i * step).floor();
      result.add(_getPoint(index));
    }

    // Always include the last point
    result.add(_getPoint(_count - 1));
    return result;
  }

  /// Douglas-Peucker line simplification algorithm.
  /// Preserves shape while reducing point count.
  List<LocationPoint> _douglasPeucker(
    List<LocationPoint> points,
    double epsilon,
    int maxPoints,
  ) {
    if (points.length <= 2) return points;

    // Find the point with the maximum perpendicular distance
    double maxDistance = 0;
    int maxIndex = 0;

    final first = points.first;
    final last = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final distance = _perpendicularDistance(points[i], first, last);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    // If max distance is greater than epsilon, recursively simplify
    if (maxDistance > epsilon && points.length > maxPoints) {
      // Recursive simplification
      final left = _douglasPeucker(
        points.sublist(0, maxIndex + 1),
        epsilon,
        maxPoints ~/ 2,
      );
      final right = _douglasPeucker(
        points.sublist(maxIndex),
        epsilon,
        maxPoints ~/ 2,
      );

      // Combine results (excluding duplicate middle point)
      return [...left.sublist(0, left.length - 1), ...right];
    }

    // If under epsilon or under maxPoints, use uniform sampling
    if (points.length > maxPoints) {
      return _uniformSampleList(points, maxPoints);
    }
    return points;
  }

  /// Uniform sample from an existing list
  List<LocationPoint> _uniformSampleList(
    List<LocationPoint> points,
    int targetCount,
  ) {
    if (points.length <= targetCount) return points;

    final result = <LocationPoint>[];
    final step = points.length / targetCount;

    for (int i = 0; i < targetCount - 1; i++) {
      final index = (i * step).floor();
      result.add(points[index]);
    }
    result.add(points.last);
    return result;
  }

  /// Calculate perpendicular distance from point to line segment
  double _perpendicularDistance(
    LocationPoint point,
    LocationPoint lineStart,
    LocationPoint lineEnd,
  ) {
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    if (dx == 0 && dy == 0) {
      // Line is a point
      return _haversineDistance(
        point.latitude,
        point.longitude,
        lineStart.latitude,
        lineStart.longitude,
      );
    }

    // Calculate perpendicular distance using cross product
    final numerator =
        ((dy * point.longitude) -
                (dx * point.latitude) +
                (lineEnd.longitude * lineStart.latitude) -
                (lineEnd.latitude * lineStart.longitude))
            .abs();
    final denominator = math.sqrt(dx * dx + dy * dy);

    return numerator / denominator;
  }

  /// Haversine distance in meters
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // meters
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLon = (lon2 - lon1) * (math.pi / 180);
    final lat1Rad = lat1 * (math.pi / 180);
    final lat2Rad = lat2 * (math.pi / 180);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) *
            math.sin(dLon / 2) *
            math.cos(lat1Rad) *
            math.cos(lat2Rad);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Clear all points
  void clear() {
    _head = 0;
    _count = 0;
  }

  /// Calculate total distance of route in meters
  double get totalDistanceMeters {
    if (_count < 2) return 0;

    double total = 0;
    for (int i = 1; i < _count; i++) {
      final prev = _getPoint(i - 1);
      final curr = _getPoint(i);
      total += _haversineDistance(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );
    }
    return total;
  }

  @override
  String toString() => 'RouteOptimizer(points: $_count/$maxPoints)';
}
