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

  RunSummary toSummary() {
    return RunSummary(
      id: id,
      date: startTime,
      distanceKm: distanceKm,
      durationSeconds: duration.inSeconds,
      avgPaceMinPerKm: paceMinPerKm,
      hexesColored: hexesColored,
      teamAtRun: teamAtRun,
      hexPath: List.from(hexesPassed),
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
    );
  }

  @override
  String toString() =>
      'RunSession(id: $id, distance: ${distanceKm.toStringAsFixed(2)}km, '
      'flips: $hexesColored, active: $isActive)';
}
