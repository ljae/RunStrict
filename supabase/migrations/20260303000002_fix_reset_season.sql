-- =============================================================================
-- Fix reset_season() — proper SQL function with snapshot-before-reset ordering
-- =============================================================================
-- PROBLEM: reset_season() was never defined as a SQL function. Season transitions
--   were done manually via raw migration SQL, which:
--   (a) Deleted season_leaderboard_snapshot (destroying historical records)
--   (b) Did NOT call snapshot_season_leaderboard() first
--   (c) Reset ALL-TIME user fields (total_distance_km, avg_cv, etc.) — wrong
--
-- FIX:
--   1. Call snapshot_season_leaderboard(p_season_number) FIRST (now date-bounded)
--   2. Reset ONLY season-specific user fields (NEVER touch ALL-TIME aggregates)
--   3. Wipe season tables: hexes, hex_snapshot, daily_buff_stats,
--      daily_all_range_stats, daily_province_range_stats
--   4. NEVER delete: run_history, daily_stats, season_leaderboard_snapshot,
--      or user ALL-TIME fields
--
-- INVARIANT #7: ALL TIME stats = local SQLite only. Server aggregate fields
--   (total_distance_km etc.) are ALL-TIME — NEVER reset them.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.reset_season(p_season_number INT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_snapshot_count INT;
BEGIN
  -- ── Step 1: Freeze leaderboard snapshot (date-bounded, safe to call anytime) ──
  -- snapshot_season_leaderboard reads run_history with date bounds — does NOT
  -- depend on users.season_points, so it's correct regardless of call timing.
  SELECT snapshot_season_leaderboard(p_season_number) INTO v_snapshot_count;

  -- ── Step 2: Reset SEASON-ONLY user fields ──────────────────────────────────
  -- DO NOT touch ALL-TIME fields: total_distance_km, avg_pace_min_per_km,
  -- avg_cv, total_runs, cv_run_count, home_hex, home_hex_end, district_hex
  UPDATE public.users SET
    season_points   = 0,
    team            = NULL,
    season_home_hex = NULL;

  -- ── Step 3: Wipe season-specific tables ───────────────────────────────────
  -- hexes: live hex state (re-built as users run in the new season)
  DELETE FROM public.hexes;

  -- hex_snapshot: yesterday's baseline for flip counting
  -- (build_daily_hex_snapshot at 22:00 UTC will rebuild from empty hexes)
  DELETE FROM public.hex_snapshot;

  -- daily_buff_stats: per-district buff multipliers (calculated fresh by
  -- calculate_daily_buffs at 22:00 UTC)
  DELETE FROM public.daily_buff_stats;

  -- Province/all range stats: season-specific hex dominance aggregates
  DELETE FROM public.daily_all_range_stats;
  DELETE FROM public.daily_province_range_stats;

  -- DO NOT delete: run_history, daily_stats (preserved across seasons per AGENTS.md)
  -- DO NOT delete: season_leaderboard_snapshot (historical records for all seasons)

  RETURN jsonb_build_object(
    'season_ended',   p_season_number,
    'snapshot_count', v_snapshot_count,
    'reset_complete', true
  );
END;
$function$;

-- Only service_role can call reset_season (admin operation)
GRANT EXECUTE ON FUNCTION public.reset_season(INT) TO service_role;

NOTIFY pgrst, 'reload schema';
