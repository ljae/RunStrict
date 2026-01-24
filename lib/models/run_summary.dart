import 'team.dart';

class RunSummary {
  final String id;
  final DateTime date;
  final double distanceKm;
  final int durationSeconds;
  final double avgPaceMinPerKm;
  final int hexesColored;
  final Team teamAtRun;
  final List<String> hexPath;

  const RunSummary({
    required this.id,
    required this.date,
    required this.distanceKm,
    required this.durationSeconds,
    required this.avgPaceMinPerKm,
    required this.hexesColored,
    required this.teamAtRun,
    this.hexPath = const [],
  });

  Duration get duration => Duration(seconds: durationSeconds);

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.millisecondsSinceEpoch,
    'distanceKm': distanceKm,
    'durationSeconds': durationSeconds,
    'avgPaceMinPerKm': avgPaceMinPerKm,
    'hexesColored': hexesColored,
    'teamAtRun': teamAtRun.name,
    'hexPath': hexPath.join(','),
  };

  factory RunSummary.fromMap(Map<String, dynamic> map) => RunSummary(
    id: map['id'] as String,
    date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
    distanceKm: (map['distanceKm'] as num).toDouble(),
    durationSeconds: (map['durationSeconds'] as num).toInt(),
    avgPaceMinPerKm: (map['avgPaceMinPerKm'] as num).toDouble(),
    hexesColored: (map['hexesColored'] as num).toInt(),
    teamAtRun: Team.values.byName(map['teamAtRun'] as String),
    hexPath:
        (map['hexPath'] as String?)
            ?.split(',')
            .where((s) => s.isNotEmpty)
            .toList() ??
        [],
  );

  factory RunSummary.fromRow(Map<String, dynamic> row) => RunSummary(
    id: row['id'] as String,
    date: DateTime.parse(row['start_time'] as String),
    distanceKm: (row['distance_meters'] as num).toDouble() / 1000,
    durationSeconds: _durationFromTimes(
      row['start_time'] as String,
      row['end_time'] as String?,
    ),
    avgPaceMinPerKm: (row['avg_pace_min_per_km'] as num?)?.toDouble() ?? 0,
    hexesColored: (row['hexes_colored'] as num?)?.toInt() ?? 0,
    teamAtRun: Team.values.byName(row['team_at_run'] as String),
    hexPath: List<String>.from(row['hex_path'] as List? ?? []),
  );

  Map<String, dynamic> toRow() => {
    'start_time': date.toIso8601String(),
    'distance_meters': distanceKm * 1000,
    'avg_pace_min_per_km': avgPaceMinPerKm,
    'hexes_colored': hexesColored,
    'team_at_run': teamAtRun.name,
    'hex_path': hexPath,
  };

  static int _durationFromTimes(String start, String? end) {
    if (end == null) return 0;
    final startDt = DateTime.parse(start);
    final endDt = DateTime.parse(end);
    return endDt.difference(startDt).inSeconds;
  }
}
