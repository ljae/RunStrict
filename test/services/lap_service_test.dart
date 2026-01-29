import 'package:flutter_test/flutter_test.dart';
import 'package:runner/models/lap_model.dart';
import 'package:runner/services/lap_service.dart';

void main() {
  group('LapService', () {
    group('calculateCV', () {
      test('returns null for empty list', () {
        final result = LapService.calculateCV([]);
        expect(result, isNull);
      });

      test('returns 0.0 for single lap (no variance possible)', () {
        final laps = [
          const LapModel(
            lapNumber: 1,
            distanceMeters: 1000,
            durationSeconds: 300, // 5:00 pace
            startTimestampMs: 0,
            endTimestampMs: 300000,
          ),
        ];
        final result = LapService.calculateCV(laps);
        expect(result, equals(0.0));
      });

      test('returns 0.0 for identical paces (no variance)', () {
        final laps = [
          const LapModel(
            lapNumber: 1,
            distanceMeters: 1000,
            durationSeconds: 300, // 5:00 pace
            startTimestampMs: 0,
            endTimestampMs: 300000,
          ),
          const LapModel(
            lapNumber: 2,
            distanceMeters: 1000,
            durationSeconds: 300, // 5:00 pace
            startTimestampMs: 300000,
            endTimestampMs: 600000,
          ),
          const LapModel(
            lapNumber: 3,
            distanceMeters: 1000,
            durationSeconds: 300, // 5:00 pace
            startTimestampMs: 600000,
            endTimestampMs: 900000,
          ),
        ];
        final result = LapService.calculateCV(laps);
        expect(result, equals(0.0));
      });

      test('calculates CV correctly for varied paces', () {
        // Paces: 300, 330, 270 sec/km (mean = 300)
        // Variance = ((0)^2 + (30)^2 + (-30)^2) / 2 = 1800 / 2 = 900
        // Stdev = 30
        // CV = (30 / 300) * 100 = 10%
        final laps = [
          const LapModel(
            lapNumber: 1,
            distanceMeters: 1000,
            durationSeconds: 300, // 5:00 pace
            startTimestampMs: 0,
            endTimestampMs: 300000,
          ),
          const LapModel(
            lapNumber: 2,
            distanceMeters: 1000,
            durationSeconds: 330, // 5:30 pace
            startTimestampMs: 300000,
            endTimestampMs: 630000,
          ),
          const LapModel(
            lapNumber: 3,
            distanceMeters: 1000,
            durationSeconds: 270, // 4:30 pace
            startTimestampMs: 630000,
            endTimestampMs: 900000,
          ),
        ];
        final result = LapService.calculateCV(laps);
        expect(result, isNotNull);
        expect(result!, closeTo(10.0, 0.01));
      });

      test('handles two laps with different paces', () {
        // Paces: 300, 360 sec/km (mean = 330)
        // Variance = ((30)^2 + (-30)^2) / 1 = 1800
        // Stdev = sqrt(1800) = 42.43
        // CV = (42.43 / 330) * 100 = 12.86%
        final laps = [
          const LapModel(
            lapNumber: 1,
            distanceMeters: 1000,
            durationSeconds: 300, // 5:00 pace
            startTimestampMs: 0,
            endTimestampMs: 300000,
          ),
          const LapModel(
            lapNumber: 2,
            distanceMeters: 1000,
            durationSeconds: 360, // 6:00 pace
            startTimestampMs: 300000,
            endTimestampMs: 660000,
          ),
        ];
        final result = LapService.calculateCV(laps);
        expect(result, isNotNull);
        expect(result!, closeTo(12.86, 0.1));
      });
    });

    group('calculateStabilityScore', () {
      test('returns null for null CV', () {
        final result = LapService.calculateStabilityScore(null);
        expect(result, isNull);
      });

      test('returns 100 for CV of 0', () {
        final result = LapService.calculateStabilityScore(0.0);
        expect(result, equals(100));
      });

      test('returns 90 for CV of 10', () {
        final result = LapService.calculateStabilityScore(10.0);
        expect(result, equals(90));
      });

      test('returns 0 for CV of 100 or higher', () {
        expect(LapService.calculateStabilityScore(100.0), equals(0));
        expect(LapService.calculateStabilityScore(150.0), equals(0));
      });

      test('clamps negative results to 0', () {
        final result = LapService.calculateStabilityScore(120.0);
        expect(result, equals(0));
      });

      test('rounds correctly', () {
        // CV of 7.4 -> 100 - 7.4 = 92.6 -> rounds to 93
        expect(LapService.calculateStabilityScore(7.4), equals(93));
        // CV of 7.6 -> 100 - 7.6 = 92.4 -> rounds to 92
        expect(LapService.calculateStabilityScore(7.6), equals(92));
      });
    });
  });
}
