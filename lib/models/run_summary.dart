import 'team.dart';

class RunSummary {
  final String id;
  final DateTime endTime;
  final double distanceKm;
  final int durationSeconds;
  final double avgPaceMinPerKm;
  final int hexesColored;
  final Team teamAtRun;
  final List<String> hexPath;
  final int buffMultiplier;
  final double? cv;

  const RunSummary({
    required this.id,
    required this.endTime,
    required this.distanceKm,
    required this.durationSeconds,
    required this.avgPaceMinPerKm,
    required this.hexesColored,
    required this.teamAtRun,
    this.hexPath = const [],
    this.buffMultiplier = 1,
    this.cv,
  });

  Duration get duration => Duration(seconds: durationSeconds);

  /// Derived start time (for server sync)
  DateTime get startTime =>
      endTime.subtract(Duration(seconds: durationSeconds));

  int get flipPoints => hexesColored * buffMultiplier;

  /// Stability score (100 - CV, clamped 0-100)
  /// Higher = more consistent pace
  int? get stabilityScore {
    if (cv == null) return null;
    return (100 - cv!).round().clamp(0, 100);
  }

  /// For local SQLite storage (milliseconds epoch)
  /// Note: Must match LocalStorage table schema columns
  Map<String, dynamic> toMap() => {
    'id': id,
    'startTime': endTime
        .subtract(Duration(seconds: durationSeconds))
        .millisecondsSinceEpoch,
    'endTime': endTime.millisecondsSinceEpoch,
    'distanceKm': distanceKm,
    'durationSeconds': durationSeconds,
    'avgPaceSecPerKm':
        avgPaceMinPerKm * 60, // Convert min/km to sec/km for storage
    'hexesColored': hexesColored,
    'teamAtRun': teamAtRun.name,
    'isPurpleRunner': teamAtRun == Team.purple ? 1 : 0,
    'cv': cv,
  };

  factory RunSummary.fromMap(Map<String, dynamic> map) => RunSummary(
    id: map['id'] as String,
    endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int),
    distanceKm: (map['distanceKm'] as num).toDouble(),
    durationSeconds: (map['durationSeconds'] as num).toInt(),
    avgPaceMinPerKm:
        (map['avgPaceSecPerKm'] as num).toDouble() /
        60, // Convert sec/km back to min/km
    hexesColored: (map['hexesColored'] as num?)?.toInt() ?? 0,
    teamAtRun: Team.values.byName(map['teamAtRun'] as String),
    hexPath: const [],
    buffMultiplier: 1,
    cv: (map['cv'] as num?)?.toDouble(),
  );

  /// From Supabase row (snake_case)
  factory RunSummary.fromRow(Map<String, dynamic> row) => RunSummary(
    id: row['id'] as String,
    endTime: DateTime.parse(row['end_time'] as String),
    distanceKm: (row['distance_meters'] as num).toDouble() / 1000,
    durationSeconds: (row['duration_seconds'] as num?)?.toInt() ?? 0,
    avgPaceMinPerKm: (row['avg_pace_min_per_km'] as num?)?.toDouble() ?? 0,
    hexesColored: (row['hexes_colored'] as num?)?.toInt() ?? 0,
    teamAtRun: Team.values.byName(row['team_at_run'] as String),
    hexPath: List<String>.from(row['hex_path'] as List? ?? []),
    buffMultiplier: (row['buff_multiplier'] as num?)?.toInt() ?? 1,
    cv: (row['cv'] as num?)?.toDouble(),
  );

  /// To Supabase row (snake_case) for finalize_run RPC
  Map<String, dynamic> toRow() => {
    'end_time': endTime.toIso8601String(),
    'distance_meters': distanceKm * 1000,
    'duration_seconds': durationSeconds,
    'avg_pace_min_per_km': avgPaceMinPerKm,
    'hexes_colored': hexesColored,
    'team_at_run': teamAtRun.name,
    'hex_path': hexPath,
    'buff_multiplier': buffMultiplier,
    'cv': cv,
  };
}
