import 'location_point.dart';
import 'team.dart';
import 'run_summary.dart';
import 'route_point.dart';

/// Active running session with real-time tracking data.
///
/// IMPORTANT: This class is for ACTIVE runs only.
/// After completion, use RunSummary for storage/history.
///
/// Memory optimization:
/// - Route points are kept in memory during run
/// - On completion: route → CompressedRoute (Cold Storage)
/// - On completion: stats → RunSummary (Hot Storage)
class RunSession {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  double distanceMeters;
  final List<LocationPoint> route; // In-memory during run only
  bool isActive;

  // Team context
  final Team teamAtRun;
  final bool isPurpleRunner;

  // Flip tracking
  int hexesColored; // Live flip count

  // Transient state (not persisted)
  String? currentHexId;
  double distanceInCurrentHex;

  RunSession({
    required this.id,
    required this.startTime,
    this.endTime,
    this.distanceMeters = 0,
    List<LocationPoint>? route,
    this.isActive = true,
    required this.teamAtRun,
    this.isPurpleRunner = false,
    this.hexesColored = 0,
    this.currentHexId,
    this.distanceInCurrentHex = 0,
  }) : route = route ?? [];

  /// Duration of the run
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Average pace in minutes per kilometer
  double get averagePaceMinPerKm {
    if (distanceMeters == 0) return 0;
    final km = distanceMeters / 1000;
    final minutes = duration.inSeconds / 60;
    return minutes / km;
  }

  /// Average pace in seconds (for storage)
  double get avgPaceSeconds {
    if (distanceMeters == 0) return 0;
    final km = distanceMeters / 1000;
    return duration.inSeconds / km;
  }

  /// Average speed in km/h
  double get averageSpeedKmh {
    if (duration.inSeconds == 0) return 0;
    final hours = duration.inSeconds / 3600;
    final km = distanceMeters / 1000;
    return km / hours;
  }

  /// Distance in kilometers
  double get distanceKm => distanceMeters / 1000;

  /// Check if runner can capture hex (pace < 8:00 min/km)
  bool get canCaptureHex =>
      averagePaceMinPerKm < 8.0 && averagePaceMinPerKm > 0;

  /// Points earned (flip count * multiplier)
  int get pointsEarned {
    final multiplier = isPurpleRunner ? 2 : 1;
    return hexesColored * multiplier;
  }

  // ============ COMPLETION HELPERS ============

  /// Convert to lightweight RunSummary for storage (call at run end)
  RunSummary toSummary() {
    return RunSummary.fromRun(
      id: id,
      startTime: startTime,
      endTime: endTime ?? DateTime.now(),
      distanceMeters: distanceMeters,
      hexesColored: hexesColored,
      teamAtRun: teamAtRun,
      isPurpleRunner: isPurpleRunner,
    );
  }

  /// Convert route to compressed format for Cold Storage
  CompressedRoute toCompressedRoute() {
    return CompressedRoute(
      runId: id,
      points: route.map((lp) => RoutePoint.fromLocationPoint(lp)).toList(),
    );
  }

  /// Mark run as completed
  void complete() {
    endTime = DateTime.now();
    isActive = false;
  }

  /// Create a copy with updated values (for immutable state updates)
  RunSession copyWith({
    double? distanceMeters,
    int? hexesColored,
    String? currentHexId,
    double? distanceInCurrentHex,
  }) {
    return RunSession(
      id: id,
      startTime: startTime,
      endTime: endTime,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      route: route,
      isActive: isActive,
      teamAtRun: teamAtRun,
      isPurpleRunner: isPurpleRunner,
      hexesColored: hexesColored ?? this.hexesColored,
      currentHexId: currentHexId ?? this.currentHexId,
      distanceInCurrentHex: distanceInCurrentHex ?? this.distanceInCurrentHex,
    );
  }

  /// Add a location point to the route
  void addPoint(LocationPoint point) {
    route.add(point);
  }

  /// Update distance (called during active tracking)
  void updateDistance(double meters) {
    distanceMeters = meters;
  }

  /// Increment flip count
  void recordFlip() {
    hexesColored++;
  }

  @override
  String toString() =>
      'RunSession(id: $id, distance: ${distanceKm.toStringAsFixed(2)}km, '
      'flips: $hexesColored, active: $isActive)';
}
