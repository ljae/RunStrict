import 'dart:math' as math;
import '../../../data/models/lap_model.dart';

/// Service for lap-based calculations and analysis
class LapService {
  /// Calculate CV (Coefficient of Variation) from lap paces
  ///
  /// CV = (standard deviation / mean) * 100
  ///
  /// Returns null if less than 2 laps (can't calculate variance).
  /// Returns 0.0 if all paces are identical (no variance).
  /// Returns 0.0 if single lap (no variance possible).
  static double? calculateCV(List<LapModel> laps) {
    // Edge case: empty list or single lap
    if (laps.isEmpty) return null;
    if (laps.length == 1) return 0.0;

    // Extract average pace for each lap
    final List<double> paces = laps.map((lap) => lap.avgPaceSecPerKm).toList();

    // Calculate mean
    final double mean = paces.reduce((a, b) => a + b) / paces.length;

    // Calculate sample standard deviation (n-1 denominator)
    final double sumSquaredDiffs = paces.fold<double>(
      0.0,
      (sum, pace) => sum + math.pow(pace - mean, 2),
    );

    final double variance = sumSquaredDiffs / (paces.length - 1);
    final double stdev = math.sqrt(variance);

    // Handle edge case: all identical paces
    if (mean == 0) return null;

    // CV = (stdev / mean) * 100
    return (stdev / mean) * 100;
  }

  /// Convert CV to Stability Score (higher = better)
  ///
  /// Returns max(0, 100 - cv).round() clamped to 0-100.
  /// Returns null if cv is null.
  static int? calculateStabilityScore(double? cv) {
    if (cv == null) return null;

    final int score = (100 - cv).round();
    return score.clamp(0, 100);
  }
}
