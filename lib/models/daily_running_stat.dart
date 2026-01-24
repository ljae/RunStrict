class DailyRunningStat {
  final String userId;
  final String dateKey;
  final double totalDistanceKm;
  final int totalDurationSeconds;
  final double avgPaceMinPerKm;
  final int flipCount;

  DailyRunningStat({
    required this.userId,
    required this.dateKey,
    this.totalDistanceKm = 0,
    this.totalDurationSeconds = 0,
    this.avgPaceMinPerKm = 0,
    this.flipCount = 0,
  });

  static String dateKeyFromDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime get date {
    final parts = dateKey.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  Duration get duration => Duration(seconds: totalDurationSeconds);

  String get paceFormatted {
    final totalSeconds = (avgPaceMinPerKm * 60).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory DailyRunningStat.fromRow(Map<String, dynamic> row) =>
      DailyRunningStat(
        userId: row['user_id'] as String,
        dateKey: row['date_key'] as String,
        totalDistanceKm: (row['total_distance_km'] as num?)?.toDouble() ?? 0,
        totalDurationSeconds:
            (row['total_duration_seconds'] as num?)?.toInt() ?? 0,
        avgPaceMinPerKm: (row['avg_pace_min_per_km'] as num?)?.toDouble() ?? 0,
        flipCount: (row['flip_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toRow() => {
    'user_id': userId,
    'date_key': dateKey,
    'total_distance_km': totalDistanceKm,
    'total_duration_seconds': totalDurationSeconds,
    'avg_pace_min_per_km': avgPaceMinPerKm,
    'flip_count': flipCount,
  };

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'dateKey': dateKey,
    'totalDistanceKm': totalDistanceKm,
    'totalDurationSeconds': totalDurationSeconds,
    'avgPaceMinPerKm': avgPaceMinPerKm,
    'flipCount': flipCount,
  };

  factory DailyRunningStat.fromJson(Map<String, dynamic> json) =>
      DailyRunningStat(
        userId: json['userId'] as String,
        dateKey: json['dateKey'] as String,
        totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0,
        totalDurationSeconds:
            (json['totalDurationSeconds'] as num?)?.toInt() ?? 0,
        avgPaceMinPerKm: (json['avgPaceMinPerKm'] as num?)?.toDouble() ?? 0,
        flipCount: (json['flipCount'] as num?)?.toInt() ?? 0,
      );

  DailyRunningStat copyWith({
    double? totalDistanceKm,
    int? totalDurationSeconds,
    double? avgPaceMinPerKm,
    int? flipCount,
  }) => DailyRunningStat(
    userId: userId,
    dateKey: dateKey,
    totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
    totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
    avgPaceMinPerKm: avgPaceMinPerKm ?? this.avgPaceMinPerKm,
    flipCount: flipCount ?? this.flipCount,
  );

  DailyRunningStat addRun({
    required double distanceKm,
    required int durationSeconds,
    required double paceMinPerKm,
    required int flips,
  }) {
    final newDistance = totalDistanceKm + distanceKm;
    final newDuration = totalDurationSeconds + durationSeconds;
    final newPace = newDistance > 0 ? (newDuration / 60) / newDistance : 0.0;
    return DailyRunningStat(
      userId: userId,
      dateKey: dateKey,
      totalDistanceKm: newDistance,
      totalDurationSeconds: newDuration,
      avgPaceMinPerKm: newPace,
      flipCount: flipCount + flips,
    );
  }
}
