/// Represents a single lap during a run
class LapModel {
  final int lapNumber; // which lap (1, 2, 3...)
  final double distanceMeters; // should be 1000.0 for complete laps
  final double durationSeconds; // time to complete this lap
  final int startTimestampMs; // when lap started
  final int endTimestampMs; // when lap ended

  const LapModel({
    required this.lapNumber,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startTimestampMs,
    required this.endTimestampMs,
  });

  /// Derived getter: average pace in seconds per kilometer
  double get avgPaceSecPerKm => durationSeconds / (distanceMeters / 1000);

  /// Convert LapModel to Map for SQLite serialization
  Map<String, dynamic> toMap() {
    return {
      'lap_number': lapNumber,
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'start_timestamp_ms': startTimestampMs,
      'end_timestamp_ms': endTimestampMs,
    };
  }

  /// Create LapModel from Map (SQLite deserialization)
  factory LapModel.fromMap(Map<String, dynamic> map) {
    return LapModel(
      lapNumber: map['lap_number'] as int,
      distanceMeters: map['distance_meters'] as double,
      durationSeconds: map['duration_seconds'] as double,
      startTimestampMs: map['start_timestamp_ms'] as int,
      endTimestampMs: map['end_timestamp_ms'] as int,
    );
  }

  /// Create a copy with modified fields
  LapModel copyWith({
    int? lapNumber,
    double? distanceMeters,
    double? durationSeconds,
    int? startTimestampMs,
    int? endTimestampMs,
  }) {
    return LapModel(
      lapNumber: lapNumber ?? this.lapNumber,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startTimestampMs: startTimestampMs ?? this.startTimestampMs,
      endTimestampMs: endTimestampMs ?? this.endTimestampMs,
    );
  }

  @override
  String toString() {
    return 'LapModel(lap: $lapNumber, distance: $distanceMeters m, '
        'duration: $durationSeconds s, pace: ${avgPaceSecPerKm.toStringAsFixed(2)} sec/km)';
  }
}
