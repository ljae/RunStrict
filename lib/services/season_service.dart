/// Service to manage the 280-day season cycle.
///
/// The season runs for exactly 280 days (gestation period metaphor).
/// On D-Day (day 0), all territories and scores are reset (The Void).
class SeasonService {
  /// Total duration of a season in days
  static const int seasonDurationDays = 280;

  /// The start date of the current season.
  /// In production, this would come from Firestore or remote config.
  final DateTime seasonStartDate;

  SeasonService({DateTime? startDate})
      : seasonStartDate = startDate ?? _defaultSeasonStart();

  /// Default season start for development/testing.
  /// Set to a date that gives us time to test various D-day states.
  static DateTime _defaultSeasonStart() {
    // For development: start 280 days from now (D-280)
    // Change this to test different D-day states
    return DateTime.now();
  }

  /// The date when the season ends (D-Day).
  DateTime get seasonEndDate =>
      seasonStartDate.add(const Duration(days: seasonDurationDays));

  /// Days remaining until D-Day (The Void).
  /// Returns 0 on D-Day, negative values after D-Day.
  int get daysRemaining {
    final now = DateTime.now();
    final difference = seasonEndDate.difference(now).inDays;
    return difference.clamp(-999, seasonDurationDays);
  }

  /// Current day of the season (1-280).
  /// Day 1 is the first day, Day 280 is the last day before D-Day.
  int get currentSeasonDay {
    final now = DateTime.now();
    final daysPassed = now.difference(seasonStartDate).inDays;
    return (daysPassed + 1).clamp(1, seasonDurationDays + 1);
  }

  /// Progress through the season as a value from 0.0 to 1.0.
  double get seasonProgress {
    return (currentSeasonDay / seasonDurationDays).clamp(0.0, 1.0);
  }

  /// Urgency level from 0.0 (calm, start of season) to 1.0 (D-Day).
  /// Used to determine visual intensity of countdown.
  double get urgencyLevel {
    final remaining = daysRemaining;

    if (remaining <= 0) return 1.0; // D-Day or past
    if (remaining >= 140) return 0.0; // First half: calm
    if (remaining >= 30) {
      // Days 140-30: gradual increase (0.0 to 0.5)
      return (140 - remaining) / 220; // 0.0 to 0.5
    }
    if (remaining >= 7) {
      // Days 30-7: moderate urgency (0.5 to 0.8)
      return 0.5 + (30 - remaining) / 46; // 0.5 to 0.8
    }
    // Final week: high urgency (0.8 to 1.0)
    return 0.8 + (7 - remaining) / 35; // 0.8 to 1.0
  }

  /// Whether the current time is past the halfway point (D-140).
  /// Purple Crew unlocks at this point.
  bool get isPurpleUnlocked => daysRemaining <= 140;

  /// Whether it's currently D-Day (the final day).
  bool get isDDay => daysRemaining == 0;

  /// Whether the season has ended (past D-Day).
  bool get isSeasonEnded => daysRemaining < 0;

  /// Formatted display string for the countdown.
  /// Returns "D-280" through "D-1", then "D-DAY", then "VOID" if past.
  String get displayString {
    final remaining = daysRemaining;

    if (remaining < 0) return 'VOID';
    if (remaining == 0) return 'D-DAY';
    return 'D-$remaining';
  }

  /// Short formatted string (just the number or special state).
  String get shortDisplayString {
    final remaining = daysRemaining;

    if (remaining < 0) return '∅';
    if (remaining == 0) return '!';
    return '$remaining';
  }

  @override
  String toString() {
    return 'SeasonService(start: $seasonStartDate, remaining: $daysRemaining days, urgency: ${(urgencyLevel * 100).toStringAsFixed(0)}%)';
  }
}
