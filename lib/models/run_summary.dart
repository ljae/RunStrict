import 'team.dart';

/// Lightweight run summary for history display.
/// Does NOT contain route data - routes are stored separately in Cold Storage.
///
/// This is what gets stored in SQLite/Firestore for quick history loading.
/// Full route data is lazy-loaded only when user views run details.
class RunSummary {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final double distanceKm;
  final int durationSeconds;
  final double avgPaceSecPerKm;
  final int hexesColored; // Flip count
  final Team teamAtRun;
  final bool isPurpleRunner;

  // Derived from hexesColored and isPurpleRunner
  int get pointsEarned => hexesColored * (isPurpleRunner ? 2 : 1);

  // Derived from durationSeconds
  Duration get duration => Duration(seconds: durationSeconds);

  // Derived from avgPaceSecPerKm
  double get avgPaceMinPerKm => avgPaceSecPerKm / 60;

  const RunSummary({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.distanceKm,
    required this.durationSeconds,
    required this.avgPaceSecPerKm,
    required this.hexesColored,
    required this.teamAtRun,
    this.isPurpleRunner = false,
  });

  /// Create from a completed run (at end of run)
  factory RunSummary.fromRun({
    required String id,
    required DateTime startTime,
    required DateTime endTime,
    required double distanceMeters,
    required int hexesColored,
    required Team teamAtRun,
    required bool isPurpleRunner,
  }) {
    final durationSeconds = endTime.difference(startTime).inSeconds;
    final distanceKm = distanceMeters / 1000;
    final avgPaceSecPerKm = distanceKm > 0 ? durationSeconds / distanceKm : 0.0;

    return RunSummary(
      id: id,
      startTime: startTime,
      endTime: endTime,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      avgPaceSecPerKm: avgPaceSecPerKm,
      hexesColored: hexesColored,
      teamAtRun: teamAtRun,
      isPurpleRunner: isPurpleRunner,
    );
  }

  /// SQLite serialization (minimal)
  Map<String, dynamic> toMap() => {
    'id': id,
    'startTime': startTime.millisecondsSinceEpoch,
    'endTime': endTime.millisecondsSinceEpoch,
    'distanceKm': distanceKm,
    'durationSeconds': durationSeconds,
    'avgPaceSecPerKm': avgPaceSecPerKm,
    'hexesColored': hexesColored,
    'teamAtRun': teamAtRun.name,
    'isPurpleRunner': isPurpleRunner ? 1 : 0,
  };

  factory RunSummary.fromMap(Map<String, dynamic> map) => RunSummary(
    id: map['id'] as String,
    startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
    endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int),
    distanceKm: (map['distanceKm'] as num).toDouble(),
    durationSeconds: (map['durationSeconds'] as num).toInt(),
    avgPaceSecPerKm: (map['avgPaceSecPerKm'] as num).toDouble(),
    hexesColored: (map['hexesColored'] as num).toInt(),
    teamAtRun: Team.values.byName(map['teamAtRun'] as String),
    isPurpleRunner: (map['isPurpleRunner'] as int) == 1,
  );

  /// Firestore serialization
  Map<String, dynamic> toFirestore() => {
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'distanceKm': distanceKm,
    'durationSeconds': durationSeconds,
    'avgPaceSecPerKm': avgPaceSecPerKm,
    'hexesColored': hexesColored,
    'teamAtRun': teamAtRun.name,
    'isPurpleRunner': isPurpleRunner,
  };

  factory RunSummary.fromFirestore(String id, Map<String, dynamic> data) =>
      RunSummary(
        id: id,
        startTime: DateTime.parse(data['startTime'] as String),
        endTime: DateTime.parse(data['endTime'] as String),
        distanceKm: (data['distanceKm'] as num).toDouble(),
        durationSeconds: (data['durationSeconds'] as num).toInt(),
        avgPaceSecPerKm: (data['avgPaceSecPerKm'] as num).toDouble(),
        hexesColored: (data['hexesColored'] as num).toInt(),
        teamAtRun: Team.values.byName(data['teamAtRun'] as String),
        isPurpleRunner: data['isPurpleRunner'] as bool? ?? false,
      );
}
