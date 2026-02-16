class DailyRunningStat {
  final String userId;
  final String dateKey;
  final double totalDistanceKm;
  final int totalDurationSeconds;
  final int flipPoints;

  DailyRunningStat({
    required this.userId,
    required this.dateKey,
    this.totalDistanceKm = 0,
    this.totalDurationSeconds = 0,
    this.flipPoints = 0,
  });

  /// Average pace derived from distance and duration (min/km).
  /// Returns 0 if no valid data.
  double get avgPaceMinPerKm {
    if (totalDistanceKm <= 0 || totalDurationSeconds <= 0) return 0;
    return (totalDurationSeconds / 60.0) / totalDistanceKm;
  }

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
        flipPoints: (row['flip_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toRow() => {
    'user_id': userId,
    'date_key': dateKey,
    'total_distance_km': totalDistanceKm,
    'total_duration_seconds': totalDurationSeconds,
    'flip_count': flipPoints,
  };

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'dateKey': dateKey,
    'totalDistanceKm': totalDistanceKm,
    'totalDurationSeconds': totalDurationSeconds,
    'flipPoints': flipPoints,
  };

  factory DailyRunningStat.fromJson(Map<String, dynamic> json) =>
      DailyRunningStat(
        userId: json['userId'] as String,
        dateKey: json['dateKey'] as String,
        totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0,
        totalDurationSeconds:
            (json['totalDurationSeconds'] as num?)?.toInt() ?? 0,
        flipPoints: (json['flipPoints'] as num?)?.toInt() ?? 0,
      );

  DailyRunningStat copyWith({
    double? totalDistanceKm,
    int? totalDurationSeconds,
    int? flipPoints,
  }) => DailyRunningStat(
    userId: userId,
    dateKey: dateKey,
    totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
    totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
    flipPoints: flipPoints ?? this.flipPoints,
  );

  DailyRunningStat addRun({
    required double distanceKm,
    required int durationSeconds,
    required int flips,
  }) {
    return DailyRunningStat(
      userId: userId,
      dateKey: dateKey,
      totalDistanceKm: totalDistanceKm + distanceKm,
      totalDurationSeconds: totalDurationSeconds + durationSeconds,
      flipPoints: flipPoints + flips,
    );
  }
}
