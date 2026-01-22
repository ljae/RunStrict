/// Daily running statistics model (Cold/Warm Data)
///
/// Stored in Firestore: dailyStats/{dateKey}/{userId}
/// Used for calculating user distance stats on-demand
///
/// OPTIMIZATION: avgPaceSeconds removed from storage - calculated on-demand
/// from totalDurationSeconds / totalDistanceKm. This saves ~8 bytes per day
/// per user across 280-day seasons.
class DailyRunningStat {
  final String userId;
  final String dateKey; // Format: 'YYYY-MM-DD'
  final double totalDistanceKm;
  final int totalDurationSeconds;
  final int flipCount;

  DailyRunningStat({
    required this.userId,
    required this.dateKey,
    this.totalDistanceKm = 0,
    this.totalDurationSeconds = 0,
    this.flipCount = 0,
  });

  /// Average pace in seconds per km (COMPUTED, not stored)
  /// Returns 0 if no distance recorded
  double get avgPaceSeconds =>
      totalDistanceKm > 0 ? totalDurationSeconds / totalDistanceKm : 0;

  /// Generate dateKey from DateTime
  static String dateKeyFromDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Parse dateKey to DateTime
  DateTime get date {
    final parts = dateKey.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Average pace in minutes per km
  double get avgPaceMinPerKm => avgPaceSeconds / 60;

  /// Format pace as string (e.g., "5:30")
  String get paceFormatted {
    final totalSeconds = avgPaceSeconds.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Duration as Duration object
  Duration get duration => Duration(seconds: totalDurationSeconds);

  /// Format duration as string (e.g., "45:30")
  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'dateKey': dateKey,
    'totalDistanceKm': totalDistanceKm,
    'totalDurationSeconds': totalDurationSeconds,
    'flipCount': flipCount,
  };

  factory DailyRunningStat.fromJson(Map<String, dynamic> json) =>
      DailyRunningStat(
        userId: json['userId'] as String,
        dateKey: json['dateKey'] as String,
        totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0,
        totalDurationSeconds:
            (json['totalDurationSeconds'] as num?)?.toInt() ?? 0,
        flipCount: (json['flipCount'] as num?)?.toInt() ?? 0,
      );

  /// Create from Firestore document
  factory DailyRunningStat.fromFirestore(
    String dateKey,
    String docId,
    Map<String, dynamic> data,
  ) {
    return DailyRunningStat(
      userId: data['userId'] as String? ?? docId,
      dateKey: dateKey,
      totalDistanceKm: (data['totalDistanceKm'] as num?)?.toDouble() ?? 0,
      totalDurationSeconds:
          (data['totalDurationSeconds'] as num?)?.toInt() ?? 0,
      flipCount: (data['flipCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Convert to Firestore document
  /// NOTE: avgPaceSeconds is NOT stored - it's computed on read
  Map<String, dynamic> toFirestore() => {
    'totalDistanceKm': totalDistanceKm,
    'totalDurationSeconds': totalDurationSeconds,
    'flipCount': flipCount,
  };

  DailyRunningStat copyWith({
    double? totalDistanceKm,
    int? totalDurationSeconds,
    int? flipCount,
  }) =>
      DailyRunningStat(
        userId: userId,
        dateKey: dateKey,
        totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
        totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
        flipCount: flipCount ?? this.flipCount,
      );

  /// Merge with another run's data
  /// NOTE: avgPaceSeconds is computed automatically from updated totals
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
      flipCount: flipCount + flips,
    );
  }
}
