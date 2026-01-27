import 'team.dart';

/// RunHistoryModel - Lightweight history for calendar/list display
///
/// Survives season reset (5-year retention).
/// Does NOT contain hex_path (heavy data) - that's in RunSummary/runs table.
/// Used for:
/// - Calendar grid in RunHistoryScreen
/// - Run history list
/// - Personal stats aggregation
class RunHistoryModel {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;
  final double distanceKm;
  final int durationSeconds;
  final double avgPaceMinPerKm;
  final int flipCount;
  final int flipPoints;
  final Team teamAtRun;

  const RunHistoryModel({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.distanceKm,
    required this.durationSeconds,
    required this.avgPaceMinPerKm,
    required this.flipCount,
    required this.flipPoints,
    required this.teamAtRun,
  });

  Duration get duration => Duration(seconds: durationSeconds);

  /// The date this run occurred (based on startTime, date portion only)
  DateTime get runDate =>
      DateTime(startTime.year, startTime.month, startTime.day);

  /// Format pace as "X:XX min/km"
  String get paceFormatted {
    final mins = avgPaceMinPerKm.floor();
    final secs = ((avgPaceMinPerKm - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  /// Format duration as "HH:MM:SS" or "MM:SS"
  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Date key for calendar grouping (YYYY-MM-DD)
  String get dateKey =>
      '${endTime.year}-${endTime.month.toString().padLeft(2, '0')}-${endTime.day.toString().padLeft(2, '0')}';

  /// From Supabase row (snake_case)
  factory RunHistoryModel.fromRow(Map<String, dynamic> row) => RunHistoryModel(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    startTime: DateTime.parse(row['start_time'] as String),
    endTime: DateTime.parse(row['end_time'] as String),
    distanceKm: (row['distance_km'] as num).toDouble(),
    durationSeconds: (row['duration_seconds'] as num).toInt(),
    avgPaceMinPerKm: (row['avg_pace_min_per_km'] as num?)?.toDouble() ?? 0,
    flipCount: (row['flip_count'] as num?)?.toInt() ?? 0,
    flipPoints: (row['flip_points'] as num?)?.toInt() ?? 0,
    teamAtRun: Team.values.byName(row['team_at_run'] as String),
  );

  Map<String, dynamic> toRow() => {
    'user_id': userId,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
    'distance_km': distanceKm,
    'duration_seconds': durationSeconds,
    'avg_pace_min_per_km': avgPaceMinPerKm,
    'flip_count': flipCount,
    'flip_points': flipPoints,
    'team_at_run': teamAtRun.name,
  };

  /// For local SQLite storage
  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'startTime': startTime.millisecondsSinceEpoch,
    'endTime': endTime.millisecondsSinceEpoch,
    'distanceKm': distanceKm,
    'durationSeconds': durationSeconds,
    'avgPaceMinPerKm': avgPaceMinPerKm,
    'flipCount': flipCount,
    'flipPoints': flipPoints,
    'teamAtRun': teamAtRun.name,
  };

  factory RunHistoryModel.fromMap(Map<String, dynamic> map) => RunHistoryModel(
    id: map['id'] as String,
    userId: map['userId'] as String,
    startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
    endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int),
    distanceKm: (map['distanceKm'] as num).toDouble(),
    durationSeconds: (map['durationSeconds'] as num).toInt(),
    avgPaceMinPerKm: (map['avgPaceMinPerKm'] as num).toDouble(),
    flipCount: (map['flipCount'] as num).toInt(),
    flipPoints: (map['flipPoints'] as num).toInt(),
    teamAtRun: Team.values.byName(map['teamAtRun'] as String),
  );
}
