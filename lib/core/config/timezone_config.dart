import '../services/remote_config_service.dart';

/// Timezone Architecture Control Panel for RunStrict
///
/// ## The Two-Domain Rule (NEVER VIOLATE)
///
/// Every timezone-sensitive operation in RunStrict belongs to exactly one of
/// two domains. Mixing them produces silent, hard-to-reproduce bugs where
/// users' stats, points, or daily resets appear on the wrong day.
///
/// ─────────────────────────────────────────────────────────────────────────
/// DOMAIN A — Server / Game Domain  →  GMT+2 (configurable via SeasonConfig)
/// ─────────────────────────────────────────────────────────────────────────
///
/// Data that ALL runners share must use the server timezone so that daily
/// resets, buff calculations, hex snapshots, and leaderboard rankings are
/// consistent across every device and time zone.
///
/// Canonical sources (ALWAYS use one of these for Domain A):
///   • Gmt2DateUtils.todayGmt2          — current date in GMT+2 (DateTime)
///   • Gmt2DateUtils.todayGmt2String    — current date in GMT+2 ("YYYY-MM-DD")
///   • Gmt2DateUtils.toGmt2DateString() — convert any DateTime to GMT+2 date
///   • SeasonService.serverTime         — full DateTime in GMT+2 (for countdowns)
///   • TimezoneConfig.serverOffsetHours — the raw offset integer (this file)
///
/// Aligned operations (MUST use GMT+2):
///
///   Function / Location                         Source
///   ──────────────────────────────────────────  ─────────────────────────
///   Daily buff "yesterday" calc                 Gmt2DateUtils.todayGmt2.subtract(1d)
///     TeamStatsProvider (team_stats_provider.dart)
///     TeamStatsModel (team_stats.dart)
///
///   Hex snapshot date selection                 Gmt2DateUtils.todayGmt2String
///     PrefetchService (prefetch_service.dart)
///     HexRepository  (hex_repository.dart)
///
///   run_date derivation (SQLite + Supabase)     Gmt2DateUtils.toGmt2DateString()
///     RunProvider.finalizeRun (run_provider.dart)
///     LocalStorage.saveRun   (local_storage.dart)
///
///   Today's points filtering                    Gmt2DateUtils.todayGmt2String
///     PointsService (points_service.dart)
///     LocalStorage.sumUnsyncedTodayPoints / sumAllTodayPoints
///
///   Local overlay filtering                     Gmt2DateUtils.todayGmt2String
///     HexRepository._localOverlayHexes cleanup (hex_repository.dart)
///
///   Season countdown, daysRemaining, seasonDay  SeasonService.serverTime
///     SeasonService (season_service.dart)
///
///   Midnight timer scheduling                   SeasonService.serverTime
///     AppLifecycleManager (app_lifecycle_manager.dart)
///
///   Season countdown widget display             SeasonService.serverTime
///     SeasonCountdownWidget (season_countdown_widget.dart)
///
///   Leaderboard snapshot selection (server)     CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2'
///     Supabase RPC: get_leaderboard, build_daily_hex_snapshot
///
///   Buff calculation (server)                   CURRENT_DATE in 'Etc/GMT-2'
///     Supabase RPC: calculate_daily_buffs, get_user_buff
///
/// ─────────────────────────────────────────────────────────────────────────
/// DOMAIN B — Local / Private Domain  →  Device Local Time
/// ─────────────────────────────────────────────────────────────────────────
///
/// Data that belongs only to one user's personal running history uses device
/// local time so that the calendar and stats reflect the runner's lived
/// experience (e.g. a run at 11pm shows as that day, not the next).
///
/// Canonical sources (ALWAYS use one of these for Domain B):
///   • DateTime.now()                            — current local time
///   • DateTime.fromMillisecondsSinceEpoch(ms)   — epoch → local time
///   • Run.startTime / Run.endTime (UTC epoch)   — stored as UTC, displayed local
///
/// Aligned operations (MUST use local time):
///
///   Function / Location                         Source
///   ──────────────────────────────────────────  ─────────────────────────
///   Run start/end time storage                  DateTime.now().millisecondsSinceEpoch
///     Run.complete() (run.dart)
///     RunProvider (run_provider.dart)
///
///   Run history display (default)               .toLocal()
///     RunHistoryScreen (run_history_screen.dart)
///     RunCalendar (run_calendar.dart)
///
///   Calendar day grouping (default)             _convertTime(run.startTime)
///     RunCalendar._runsByDate (run_calendar.dart)
///     NOTE: respects toggle — uses local unless GMT+2 selected
///
///   GPS polling intervals                       DateTime.now()
///     LocationService, RunTracker
///
///   Cache TTL / throttle timestamps             DateTime.now()
///     PrefetchService._lastPrefetchTime
///     HexRepository._lastPrefetchTime
///     LeaderboardRepository._lastFetchTime
///
///   Accelerometer / animation timestamps        DateTime.now()
///     AccelerometerService, SmoothCameraController
///
///   Season elapsed-days math (UTC-to-UTC)       DateTime.now().toUtc()
///     SeasonService._resolveCurrentSeason()
///     NOTE: pure duration math — UTC is correct here, NOT serverTime
///
/// ─────────────────────────────────────────────────────────────────────────
/// DOMAIN C — User-Toggleable (Private history → Server time on demand)
/// ─────────────────────────────────────────────────────────────────────────
///
/// The user can switch their personal history display between local and GMT+2.
/// This only affects DISPLAY — it never changes how data is stored or scored.
///
/// Controlled by:  TimezonePreferenceService (DisplayTimezone.local | .gmt2)
/// Toggle UI:      RunHistoryScreen._buildTimezoneToggle()
/// Affected:       RunCalendar day-grouping, RunHistoryScreen date ranges
///
/// When GMT+2 is selected:
///   • RunHistoryScreen._convertToDisplayTimezone() adds serverOffsetHours
///   • RunCalendar._runsByDate groups by _convertTime(run.startTime)
///   • RunHistoryScreen._now returns Gmt2DateUtils.todayGmt2
///
/// ─────────────────────────────────────────────────────────────────────────
/// CONFIGURATION
/// ─────────────────────────────────────────────────────────────────────────
///
/// Server timezone offset is controlled via the Supabase `app_config` table:
///   seasonConfig.serverTimezoneOffsetHours  (default: 2)
///
/// ⚠️  CRITICAL CONSTRAINT — SQL IS HARDCODED:
///   ALL Supabase RPC functions independently hardcode 'Etc/GMT-2' in SQL:
///     • calculate_daily_buffs(), get_user_buff()     → AT TIME ZONE 'Etc/GMT-2'
///     • build_daily_hex_snapshot()                   → AT TIME ZONE 'Etc/GMT-2'
///     • get_leaderboard(), finalize_run()            → AT TIME ZONE 'Etc/GMT-2'
///     • handle_season_transition(), app_launch_sync() → AT TIME ZONE 'Etc/GMT-2'
///
///   Changing serverTimezoneOffsetHours in app_config DOES NOT change SQL behavior.
///   The client-side Domain A sources (Gmt2DateUtils, SeasonService) will shift,
///   but the server will still compute dates using GMT+2.
///
///   This means: serverTimezoneOffsetHours is CLIENT-SIDE ONLY.
///
/// To change the server timezone (e.g. from GMT+2 to GMT+3):
///   1. Update `app_config` row: seasonConfig.serverTimezoneOffsetHours = 3
///   2. REQUIRED: Update ALL Supabase RPCs: 'Etc/GMT-2' → 'Etc/GMT-3'
///      (search migrations for "AT TIME ZONE 'Etc/GMT" to find all occurrences)
///   3. Both steps are required — skipping step 2 causes date drift silently.
///
class TimezoneConfig {
  TimezoneConfig._();

  /// Server timezone offset in hours from UTC.
  ///
  /// Default: 2 (GMT+2, Israel Standard Time).
  /// Configured server-side via SeasonConfig.serverTimezoneOffsetHours
  /// in the Supabase app_config table.
  ///
  /// ⚠️  CLIENT-SIDE ONLY: Does NOT affect SQL timezone in Supabase RPCs.
  ///    SQL functions hardcode 'Etc/GMT-2' independently.
  ///    See the CONFIGURATION section above for full change procedure.
  ///
  /// ALL Domain A operations use this offset.
  static int get serverOffsetHours =>
      RemoteConfigService().config.seasonConfig.serverTimezoneOffsetHours;

  /// Human-readable label for the server timezone (e.g. "GMT+2").
  ///
  /// Use in UI toggles and help text.
  static String get serverTimezoneLabel {
    final h = serverOffsetHours;
    return h >= 0 ? 'GMT+$h' : 'GMT$h';
  }

  /// Returns true if the device's current UTC offset matches the server offset.
  ///
  /// When true, local time == server time and the timezone toggle has no
  /// visible effect on the user's history display.
  static bool get deviceMatchesServerTimezone {
    final deviceOffsetHours = DateTime.now().timeZoneOffset.inHours;
    return deviceOffsetHours == serverOffsetHours;
  }
}
