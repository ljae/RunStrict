import 'package:flutter_test/flutter_test.dart';
import 'package:runner/models/lap_model.dart';

void main() {
  group('LapModel', () {
    test('calculates avgPaceSecPerKm correctly', () {
      const lap = LapModel(
        lapNumber: 1,
        distanceMeters: 1000, // 1km
        durationSeconds: 300, // 5 minutes
        startTimestampMs: 0,
        endTimestampMs: 300000,
      );

      // 300 seconds for 1km = 300 sec/km
      expect(lap.avgPaceSecPerKm, equals(300.0));
    });

    test('calculates avgPaceSecPerKm for partial lap', () {
      const lap = LapModel(
        lapNumber: 1,
        distanceMeters: 500, // 0.5km
        durationSeconds: 150, // 2.5 minutes
        startTimestampMs: 0,
        endTimestampMs: 150000,
      );

      // 150 seconds for 0.5km = 300 sec/km
      expect(lap.avgPaceSecPerKm, equals(300.0));
    });

    group('toMap/fromMap', () {
      test('serializes and deserializes correctly', () {
        const original = LapModel(
          lapNumber: 3,
          distanceMeters: 1000.5,
          durationSeconds: 312.5,
          startTimestampMs: 1000000,
          endTimestampMs: 1312500,
        );

        final map = original.toMap();
        final restored = LapModel.fromMap(map);

        expect(restored.lapNumber, equals(original.lapNumber));
        expect(restored.distanceMeters, equals(original.distanceMeters));
        expect(restored.durationSeconds, equals(original.durationSeconds));
        expect(restored.startTimestampMs, equals(original.startTimestampMs));
        expect(restored.endTimestampMs, equals(original.endTimestampMs));
      });

      test('toMap produces expected keys', () {
        const lap = LapModel(
          lapNumber: 1,
          distanceMeters: 1000,
          durationSeconds: 300,
          startTimestampMs: 0,
          endTimestampMs: 300000,
        );

        final map = lap.toMap();

        expect(map.containsKey('lap_number'), isTrue);
        expect(map.containsKey('distance_meters'), isTrue);
        expect(map.containsKey('duration_seconds'), isTrue);
        expect(map.containsKey('start_timestamp_ms'), isTrue);
        expect(map.containsKey('end_timestamp_ms'), isTrue);
        expect(map['lap_number'], equals(1));
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        const original = LapModel(
          lapNumber: 1,
          distanceMeters: 1000,
          durationSeconds: 300,
          startTimestampMs: 0,
          endTimestampMs: 300000,
        );

        final modified = original.copyWith(lapNumber: 2, durationSeconds: 350);

        expect(modified.lapNumber, equals(2));
        expect(modified.durationSeconds, equals(350));
        expect(modified.distanceMeters, equals(original.distanceMeters));
        expect(modified.startTimestampMs, equals(original.startTimestampMs));
        expect(modified.endTimestampMs, equals(original.endTimestampMs));
      });

      test('preserves all fields when no changes specified', () {
        const original = LapModel(
          lapNumber: 5,
          distanceMeters: 1500,
          durationSeconds: 450,
          startTimestampMs: 1000,
          endTimestampMs: 451000,
        );

        final copy = original.copyWith();

        expect(copy.lapNumber, equals(original.lapNumber));
        expect(copy.distanceMeters, equals(original.distanceMeters));
        expect(copy.durationSeconds, equals(original.durationSeconds));
        expect(copy.startTimestampMs, equals(original.startTimestampMs));
        expect(copy.endTimestampMs, equals(original.endTimestampMs));
      });
    });

    test('toString produces readable output', () {
      const lap = LapModel(
        lapNumber: 1,
        distanceMeters: 1000,
        durationSeconds: 300,
        startTimestampMs: 0,
        endTimestampMs: 300000,
      );

      final str = lap.toString();

      expect(str, contains('lap: 1'));
      expect(str, contains('distance: 1000'));
      expect(str, contains('duration: 300'));
      expect(str, contains('pace:'));
    });
  });
}
