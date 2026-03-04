-- =============================================================================
-- handle_season_transition() — automatic season snapshot + reset at 21:55 UTC
-- =============================================================================
-- PURPOSE: Fires 5 minutes BEFORE the existing midnight crons (22:00 UTC).
--   Detects if TOMORROW (GMT+2) is a season boundary. If yes, runs reset_season()
--   which (1) snapshots the ending season's leaderboard, (2) wipes hexes and
--   season tables.
--
-- WHY 21:55 UTC (23:55 GMT+2), NOT 22:00 UTC:
--   The existing crons at 22:00 UTC run calculate_daily_buffs() and
--   build_daily_hex_snapshot(). build_daily_hex_snapshot() must see EMPTY hexes
--   so it creates a clean Day-1 snapshot for the new season. If reset_season()
--   ran at 22:00 simultaneously, a race condition could cause build_daily_hex_snapshot
--   to read stale S_N hex data before the wipe — producing a corrupt Day-1 baseline.
--   Running at 21:55 ensures hexes are already wiped when the 22:00 crons fire.
--
-- DETECTION: "Is tomorrow (GMT+2) a season boundary?"
--   days_elapsed_tomorrow = (today_gmt2 + 1) - first_season_start_date
--   If days_elapsed_tomorrow % durationDays == 0 → tomorrow starts a new season
--   → tonight we must run the transition.
--
-- EXAMPLE (S5→S6 boundary):
--   At 21:55 UTC on Mar 2 (= 23:55 GMT+2 on Mar 2, the last day of S5):
--   v_today        = Mar 2 (GMT+2)
--   v_tomorrow     = Mar 3
--   days_elapsed_tomorrow = Mar 3 - Feb 11 = 20
--   20 % 5 = 0 → TRIGGER
--   v_ending_season = 2 + (20/5) - 1 = 5  ← Season 5 ends tonight ✓
--   reset_season(5) → snapshot S5 → wipe hexes → reset season_points
--   At 22:00 UTC: build_daily_hex_snapshot() sees empty hexes → builds empty Day-1 snapshot ✓
--
-- GUARD: days_elapsed_tomorrow must be > 0 to prevent firing on Feb 11 itself
--   (Day 1 of the very first season should not be reset).
--
-- SETUP (run ONCE in Supabase SQL Editor after applying this migration):
--   SELECT cron.schedule(
--     'season-transition',
--     '55 21 * * *',
--     'SELECT handle_season_transition()'
--   );
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_season_transition()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_cfg                 JSONB;
  v_duration            INT;
  v_base_season         INT;
  v_start_date          DATE;
  v_today_gmt2          DATE;
  v_tomorrow_gmt2       DATE;
  v_days_elapsed_tomorrow INT;
  v_ending_season       INT;
  v_result              jsonb;
BEGIN
  -- Read season config with fallback defaults
  SELECT config_data->'season' INTO v_cfg FROM app_config LIMIT 1;
  v_duration    := COALESCE((v_cfg->>'durationDays')::INT,  5);
  v_base_season := COALESCE((v_cfg->>'seasonNumber')::INT,  2);
  v_start_date  := COALESCE((v_cfg->>'startDate')::DATE, '2026-02-11'::DATE);

  -- Current date in GMT+2 (runs at 23:55 GMT+2 when cron fires at 21:55 UTC)
  v_today_gmt2    := (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE;
  v_tomorrow_gmt2 := v_today_gmt2 + 1;

  -- How many days until tomorrow from the first season's start?
  v_days_elapsed_tomorrow := v_tomorrow_gmt2 - v_start_date;

  -- Guard: never fire on or before the first season start day
  -- Season boundary: tomorrow's days_elapsed is a positive multiple of durationDays
  IF v_days_elapsed_tomorrow > 0 AND v_days_elapsed_tomorrow % v_duration = 0 THEN
    -- Compute which season is ending tonight
    -- e.g. days_elapsed=20, duration=5 → 20/5=4 completed seasons after base(S2)
    --      S2+4-1 = S5 is ending
    v_ending_season := v_base_season + (v_days_elapsed_tomorrow / v_duration) - 1;

    -- reset_season() calls snapshot_season_leaderboard() first (date-bounded,
    -- safe to call before hexes are wiped), then wipes hexes + season fields.
    SELECT reset_season(v_ending_season) INTO v_result;

    RETURN v_result || jsonb_build_object(
      'trigger',      'season_end',
      'ending_season', v_ending_season,
      'fired_at_gmt2', v_today_gmt2::TEXT
    );
  END IF;

  -- Non-transition night: no action needed
  RETURN jsonb_build_object(
    'trigger',       'none',
    'today_gmt2',    v_today_gmt2::TEXT,
    'days_to_next_season', v_duration - (v_days_elapsed_tomorrow % v_duration)
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.handle_season_transition() TO service_role;

-- =============================================================================
-- pg_cron SETUP (run these statements ONCE in Supabase SQL Editor)
-- =============================================================================
-- NOTE: The existing two cron jobs REMAIN unchanged:
--   '0 22 * * *' → calculate_daily_buffs()
--   '0 22 * * *' → build_daily_hex_snapshot()
--
-- ADD this new job that fires 5 minutes earlier:
--   SELECT cron.schedule(
--     'season-transition',
--     '55 21 * * *',
--     'SELECT handle_season_transition()'
--   );
-- =============================================================================

NOTIFY pgrst, 'reload schema';
