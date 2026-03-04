-- =============================================================================
-- Retroactive Season 5 Leaderboard Snapshot
-- =============================================================================
-- Season 5: run_date 2026-02-26 to 2026-03-02 (GMT+2)
--
-- WHY this cannot use snapshot_season_leaderboard():
--   The function reads u.season_points and u.team which are LIVE fields that
--   were reset to 0/NULL at the S5→S6 transition. Using it retroactively
--   would produce an empty/corrupt snapshot.
--
-- This script builds the S5 snapshot from run_history with date bounds and
-- resolves team from run_history.team_at_run (preserved across seasons).
--
-- SAFE TO RUN MULTIPLE TIMES (idempotent — DELETE + INSERT pattern).
-- =============================================================================

BEGIN;

-- Step 1: Remove any existing (potentially corrupt) S5 snapshot
DELETE FROM season_leaderboard_snapshot WHERE season_number = 5;

-- Step 2: Insert correct S5 snapshot
-- - Points:   SUM(run_history.flip_points) for S5 date range only
-- - Team:     Most recent team_at_run from run_history within S5 (users.team was reset)
-- - Stats:    SUM/AVG from run_history for S5 date range
-- - Filter:   Only users with at least 1 flip_point in S5
INSERT INTO season_leaderboard_snapshot (
  season_number,
  rank,
  user_id,
  name,
  team,
  avatar,
  manifesto,
  season_points,
  total_distance_km,
  avg_pace_min_per_km,
  avg_cv,
  home_hex,
  home_hex_end,
  nationality,
  total_runs
)
SELECT
  5 AS season_number,
  ROW_NUMBER() OVER (
    ORDER BY COALESCE(SUM(rh.flip_points), 0) DESC, u.name ASC
  )::INT AS rank,
  u.id AS user_id,
  u.name,
  -- Team: read from run_history since users.team was reset to NULL for S6
  (
    SELECT rh2.team_at_run
    FROM run_history rh2
    WHERE rh2.user_id = u.id
      AND rh2.run_date >= '2026-02-26'
      AND rh2.run_date <= '2026-03-02'
    ORDER BY rh2.end_time DESC
    LIMIT 1
  ) AS team,
  u.avatar,
  u.manifesto,
  COALESCE(SUM(rh.flip_points), 0)::INT AS season_points,
  ROUND(COALESCE(SUM(rh.distance_km), 0)::NUMERIC, 2)::FLOAT8 AS total_distance_km,
  ROUND(COALESCE(AVG(NULLIF(rh.avg_pace_min_per_km, 0)), 0)::NUMERIC, 2)::FLOAT8 AS avg_pace_min_per_km,
  ROUND(COALESCE(AVG(NULLIF(rh.cv, 0)), 0)::NUMERIC, 1)::FLOAT8 AS avg_cv,
  u.home_hex,
  u.home_hex_end,
  u.nationality,
  COALESCE(COUNT(rh.id), 0)::INT AS total_runs
FROM users u
LEFT JOIN run_history rh
  ON rh.user_id = u.id
  AND rh.run_date >= '2026-02-26'
  AND rh.run_date <= '2026-03-02'
WHERE COALESCE(
  (
    SELECT SUM(rh3.flip_points)
    FROM run_history rh3
    WHERE rh3.user_id = u.id
      AND rh3.run_date >= '2026-02-26'
      AND rh3.run_date <= '2026-03-02'
  ), 0
) > 0
GROUP BY
  u.id, u.name, u.avatar, u.manifesto,
  u.home_hex, u.home_hex_end, u.nationality
ORDER BY season_points DESC, u.name ASC;

COMMIT;

-- =============================================================================
-- Verification queries (run separately after COMMIT)
-- =============================================================================
-- SELECT COUNT(*), SUM(season_points)
-- FROM season_leaderboard_snapshot
-- WHERE season_number = 5;
--
-- SELECT rank, name, team, season_points, total_runs
-- FROM season_leaderboard_snapshot
-- WHERE season_number = 5
-- ORDER BY rank
-- LIMIT 10;
