-- =============================================================================
-- Immediate S6 Fix — One-time script to repair the S5→S6 transition
-- =============================================================================
-- BACKGROUND:
--   reset_season() was never defined or called at the S5→S6 boundary (2026-03-03).
--   As a result:
--     • users.season_points still holds S5 values → get_leaderboard() returns S5 data
--       labeled as "Season 6"
--     • season_leaderboard_snapshot has no rows for season_number = 5
--     • hexes/hex_snapshot/daily_buff_stats still contain S5 state
--
-- WHAT THIS SCRIPT DOES (in a single transaction):
--   Step 1: Snapshot S5 leaderboard from run_history (date-bounded, retroactive-safe)
--           REQUIRES migration 20260303000001 to be deployed first.
--   Step 2: Save genuine S6 Day-1 activity (run_date >= '2026-03-03') so it
--           isn't lost when we zero season_points in Step 3.
--   Step 3: Reset season-only user fields (NEVER touch ALL-TIME aggregates).
--   Step 4: Restore genuine S6 Day-1 points from the temp table.
--   Step 5: Wipe season tables (hexes, hex_snapshot, daily_buff_stats,
--            daily_all_range_stats, daily_province_range_stats).
--   Step 6: Verify — print counts so you can confirm correctness before committing.
--
-- SAFETY INVARIANTS (per AGENTS.md and error-fix-history.md):
--   • NEVER touch ALL-TIME fields: total_distance_km, avg_pace_min_per_km,
--     avg_cv, total_runs, cv_run_count, home_hex, home_hex_end, district_hex
--   • NEVER delete: run_history, runs, daily_stats, season_leaderboard_snapshot
--   • snapshot_season_leaderboard(5) is date-bounded — safe to call after reset
--
-- PRE-REQUISITES: Deploy ALL 4 migrations (20260303000001–20260303000004) first.
--
-- HOW TO RUN: Paste into Supabase SQL Editor and execute. Review the output
--   row at the end before confirming the data looks correct.
-- =============================================================================

BEGIN;

-- ── Step 1: Snapshot S5 Leaderboard ─────────────────────────────────────────
-- snapshot_season_leaderboard(5) reads run_history with date bounds
-- (S5 = 2026-02-26 to 2026-03-02 inclusive). Safe retroactively.
-- Migration 20260303000001 must be deployed or this will use the old unsafe version.
SELECT snapshot_season_leaderboard(5);

-- ── Step 2: Save genuine S6 Day-1 activity before zeroing season_points ─────
-- S6 started on 2026-03-03 (GMT+2). Any run_history rows with run_date >= '2026-03-03'
-- belong to S6 and must survive the reset.
CREATE TEMP TABLE s6_restore AS
  SELECT
    rh.user_id,
    COALESCE(SUM(rh.flip_points), 0)::INT AS s6_points,
    -- Most recent team_at_run for this user in S6 (team survives season resets)
    (
      SELECT rh2.team_at_run
      FROM run_history rh2
      WHERE rh2.user_id = rh.user_id
        AND rh2.run_date >= '2026-03-03'
        AND rh2.team_at_run IS NOT NULL
      ORDER BY rh2.end_time DESC
      LIMIT 1
    ) AS s6_team
  FROM run_history rh
  WHERE rh.run_date >= '2026-03-03'
  GROUP BY rh.user_id;

-- ── Step 3: Reset season-only user fields ───────────────────────────────────
-- DO NOT touch ALL-TIME fields: total_distance_km, avg_pace_min_per_km,
-- avg_cv, total_runs, cv_run_count, home_hex, home_hex_end, district_hex
UPDATE public.users
SET
  season_points   = 0,
  team            = NULL,
  season_home_hex = NULL;

-- ── Step 4: Restore genuine S6 Day-1 points ─────────────────────────────────
-- Users who ran on 2026-03-03 should keep those points and their team assignment.
UPDATE public.users u
SET
  season_points = s.s6_points,
  team          = s.s6_team
FROM s6_restore s
WHERE s.user_id = u.id
  AND s.s6_points > 0;

-- ── Step 5: Wipe season-specific tables ─────────────────────────────────────
-- hexes: live territory state (re-built as users run in S6)
DELETE FROM public.hexes;

-- hex_snapshot: yesterday's baseline for flip counting
-- (build_daily_hex_snapshot at 22:00 UTC will rebuild from empty hexes)
DELETE FROM public.hex_snapshot;

-- daily_buff_stats: per-district buff multipliers
-- (calculate_daily_buffs at 22:00 UTC will recalculate for S6)
DELETE FROM public.daily_buff_stats;

-- Province/all range stats: season-specific hex dominance aggregates
DELETE FROM public.daily_all_range_stats;
DELETE FROM public.daily_province_range_stats;

-- DO NOT delete: run_history, runs, daily_stats (preserved per AGENTS.md)
-- DO NOT delete: season_leaderboard_snapshot (archive of all seasons)

COMMIT;

-- =============================================================================
-- Verification — run these SELECT queries to confirm correctness
-- =============================================================================

-- Expected: S5 snapshot should have runners with points > 0
SELECT
  'S5 snapshot'        AS check,
  COUNT(*)             AS row_count,
  SUM(season_points)   AS total_pts,
  MAX(season_points)   AS top_score
FROM public.season_leaderboard_snapshot
WHERE season_number = 5;

-- Expected: S6 live users — only users who ran on 2026-03-03 should have points > 0
SELECT
  'S6 live (users with points)' AS check,
  COUNT(*) FILTER (WHERE season_points > 0) AS users_with_pts,
  SUM(season_points)            AS total_s6_pts,
  COUNT(*) FILTER (WHERE team IS NOT NULL) AS users_with_team
FROM public.users;

-- Expected: season tables should be empty
SELECT 'hexes'                    AS tbl, COUNT(*) AS rows FROM public.hexes
UNION ALL
SELECT 'hex_snapshot',             COUNT(*) FROM public.hex_snapshot
UNION ALL
SELECT 'daily_buff_stats',         COUNT(*) FROM public.daily_buff_stats
UNION ALL
SELECT 'daily_all_range_stats',    COUNT(*) FROM public.daily_all_range_stats
UNION ALL
SELECT 'daily_province_range_stats', COUNT(*) FROM public.daily_province_range_stats;

-- Expected: run_history preserved
SELECT 'run_history (total)'      AS check, COUNT(*) AS rows FROM public.run_history
UNION ALL
SELECT 'run_history (S5)',          COUNT(*) FROM public.run_history
  WHERE run_date >= '2026-02-26' AND run_date < '2026-03-03'
UNION ALL
SELECT 'run_history (S6 Day-1)',    COUNT(*) FROM public.run_history
  WHERE run_date >= '2026-03-03';

-- Top 5 S5 snapshot (should match who was on leaderboard during S5)
SELECT rank, name, team, season_points
FROM public.season_leaderboard_snapshot
WHERE season_number = 5
ORDER BY rank
LIMIT 5;
