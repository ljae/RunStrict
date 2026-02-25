import 'package:flutter/foundation.dart';
import '../../data/models/app_config.dart';
import 'remote_config_service.dart';

/// Service to manage the recurring season cycle.
///
/// Seasons run for [seasonDurationDays] (configurable via RemoteConfig).
/// When a season's D-Day passes, the next season starts automatically.
/// Server timezone: GMT+2 (Israel Standard Time).
///
/// The config's `startDate` and `seasonNumber` define the first season.
/// Subsequent seasons are computed by advancing the start date by
/// [seasonDurationDays] for each completed season.
class SeasonService {
  /// Total duration of a season in days (read from RemoteConfigService)
  static int get seasonDurationDays =>
      RemoteConfigService().config.seasonConfig.durationDays;

  /// Server timezone offset (GMT+2) (read from RemoteConfigService)
  static int get serverTimezoneOffsetHours =>
      RemoteConfigService().config.seasonConfig.serverTimezoneOffsetHours;

  /// Current season number (auto-advances after each D-Day).
  final int seasonNumber;

  /// The start date of the current season.
  final DateTime seasonStartDate;

  /// Creates a SeasonService.
  ///
  /// If no [startDate] or [seasonNumber] is provided, computes the
  /// current season from [RemoteConfigService] config by rolling forward
  /// from the configured first season start date.
  factory SeasonService({DateTime? startDate, int? seasonNumber}) {
    if (startDate != null && seasonNumber != null) {
      return SeasonService._(
        seasonStartDate: startDate,
        seasonNumber: seasonNumber,
      );
    }
    final resolved = _resolveCurrentSeason();
    return SeasonService._(
      seasonStartDate: startDate ?? resolved.startDate,
      seasonNumber: seasonNumber ?? resolved.seasonNumber,
    );
  }

  SeasonService._({required this.seasonStartDate, required this.seasonNumber});

  /// Computes the current season by rolling forward from the config's
  /// initial start date. Each season lasts [seasonDurationDays].
  static ({DateTime startDate, int seasonNumber}) _resolveCurrentSeason() {
    final config = RemoteConfigService().config.seasonConfig;
    final duration = config.durationDays;
    final baseSeasonNumber = config.seasonNumber;

    final firstSeasonStart = _parseStartDate(config);

    final now = DateTime.now().toUtc();
    final elapsed = now.difference(firstSeasonStart).inDays;

    if (elapsed < 0) {
      // Before the first season starts
      return (startDate: firstSeasonStart, seasonNumber: baseSeasonNumber);
    }

    final completedSeasons = elapsed ~/ duration;
    final currentStart = firstSeasonStart.add(
      Duration(days: completedSeasons * duration),
    );
    final currentSeasonNumber = baseSeasonNumber + completedSeasons;

    return (startDate: currentStart, seasonNumber: currentSeasonNumber);
  }

  /// Parses the start date from config, falling back to default.
  static DateTime _parseStartDate(SeasonConfig config) {
    final startDateStr = config.startDate;

    if (startDateStr != null && startDateStr.isNotEmpty) {
      try {
        final parsed = DateTime.parse(startDateStr);
        return DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
        ).subtract(Duration(hours: config.serverTimezoneOffsetHours));
      } catch (e) {
        debugPrint('SeasonService: Failed to parse startDate: $e');
      }
    }

    return _defaultSeasonStart();
  }

  /// Default season start for development/testing.
  /// Season 1 starts January 1, 2026 (GMT+2).
  static DateTime _defaultSeasonStart() {
    return DateTime.utc(
      2026,
      1,
      1,
    ).subtract(Duration(hours: serverTimezoneOffsetHours));
  }

  /// The date when the season ends (D-Day).
  DateTime get seasonEndDate =>
      seasonStartDate.add(Duration(days: seasonDurationDays));

  /// Days remaining until D-Day (The Void).
  /// Returns 0 on D-Day, negative values after D-Day.
  int get daysRemaining {
    final now = DateTime.now();
    final difference = seasonEndDate.difference(now).inDays;
    return difference.clamp(-999, seasonDurationDays);
  }

  /// Current day of the season (1-40).
  /// Day 1 is the first day, last day is before D-Day.
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

  /// Whether Purple team is available for defection.
  /// Purple is available anytime during the season (no restriction).
  bool get isPurpleUnlocked => true;

  /// Whether it's currently D-Day (the final day).
  bool get isDDay => daysRemaining == 0;

  /// Whether the season has ended (past D-Day).
  bool get isSeasonEnded => daysRemaining < 0;

  /// Formatted display string for the countdown.
  /// Returns "D-40" through "D-1", then "D-DAY", then "VOID" if past.
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

  /// Season label (e.g., "S1", "S2").
  String get seasonLabel => 'S$seasonNumber';

  /// Current server time in GMT+2 as DateTime.
  DateTime get serverTime {
    final utc = DateTime.now().toUtc();
    return utc.add(Duration(hours: serverTimezoneOffsetHours));
  }

  /// Server time displayed as countdown minutes until midnight (daily reset).
  /// e.g., 14:32 GMT+2 → "-0568" (1440 - 872 = 568 minutes until reset).
  /// Counts DOWN to midnight like D-day counts down to season end.
  String get serverTimeDisplay {
    final time = serverTime;
    final minutesSinceMidnight = time.hour * 60 + time.minute;
    final minutesUntilReset = 1440 - minutesSinceMidnight;
    return '-${minutesUntilReset.toString().padLeft(4, '0')}';
  }

  @override
  String toString() {
    return 'SeasonService(season: $seasonNumber, start: $seasonStartDate, remaining: $daysRemaining days, urgency: ${(urgencyLevel * 100).toStringAsFixed(0)}%)';
  }
}
