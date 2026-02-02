import 'location_point.dart';
import 'team.dart';
import 'run_summary.dart';
import 'route_point.dart';

class RunSession {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  double distanceMeters;
  final List<LocationPoint> route;
  bool isActive;

  final Team teamAtRun;
  int hexesColored;
  final List<String> hexesPassed;

  String? currentHexId;
  double distanceInCurrentHex;

  /// Coefficient of Variation (null for runs < 1km)
  /// Measures pace consistency: lower = more stable
  final double? cv;

  RunSession({
    required this.id,
    required this.startTime,
    this.endTime,
    this.distanceMeters = 0,
    List<LocationPoint>? route,
    this.isActive = true,
    required this.teamAtRun,
    this.hexesColored = 0,
    List<String>? hexesPassed,
    this.currentHexId,
    this.distanceInCurrentHex = 0,
    this.cv,
  }) : route = route ?? [],
       hexesPassed = hexesPassed ?? [];

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  double get distanceKm => distanceMeters / 1000;

  double get paceMinPerKm {
    if (distanceMeters == 0) return 0;
    final km = distanceMeters / 1000;
    final minutes = duration.inSeconds / 60;
    return minutes / km;
  }

  bool get canCaptureHex => paceMinPerKm > 0 && paceMinPerKm < 8.0;

  /// Stability score (100 - CV, clamped 0-100)
  /// Higher = more consistent pace
  int? get stabilityScore {
    if (cv == null) return null;
    return (100 - cv!).round().clamp(0, 100);
  }

  /// Convert to RunSummary for "The Final Sync" upload
  ///
  /// [buffMultiplier] is the team-based buff multiplier.
  /// Default to 1 for new users or if buff system unavailable.
  RunSummary toSummary({int buffMultiplier = 1}) {
    return RunSummary(
      id: id,
      endTime: endTime ?? DateTime.now(),
      distanceKm: distanceKm,
      durationSeconds: duration.inSeconds,
      avgPaceMinPerKm: paceMinPerKm,
      hexesColored: hexesColored,
      teamAtRun: teamAtRun,
      hexPath: List.from(hexesPassed),
      buffMultiplier: buffMultiplier,
      cv: cv,
    );
  }

  CompressedRoute toCompressedRoute() {
    return CompressedRoute(
      runId: id,
      points: route.map((lp) => RoutePoint.fromLocationPoint(lp)).toList(),
    );
  }

  void complete() {
    endTime = DateTime.now();
    isActive = false;
  }

  void addPoint(LocationPoint point) {
    route.add(point);
  }

  void updateDistance(double meters) {
    distanceMeters = meters;
  }

  void recordFlip(String hexId) {
    hexesColored++;
    if (!hexesPassed.contains(hexId)) {
      hexesPassed.add(hexId);
    }
  }

  RunSession copyWith({
    double? distanceMeters,
    int? hexesColored,
    String? currentHexId,
    double? distanceInCurrentHex,
    double? cv,
  }) {
    return RunSession(
      id: id,
      startTime: startTime,
      endTime: endTime,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      route: route,
      isActive: isActive,
      teamAtRun: teamAtRun,
      hexesColored: hexesColored ?? this.hexesColored,
      hexesPassed: hexesPassed,
      currentHexId: currentHexId ?? this.currentHexId,
      distanceInCurrentHex: distanceInCurrentHex ?? this.distanceInCurrentHex,
      cv: cv ?? this.cv,
    );
  }

  @override
  String toString() =>
      'RunSession(id: $id, distance: ${distanceKm.toStringAsFixed(2)}km, '
      'flips: $hexesColored, active: $isActive)';
}
