-- =============================================================================
-- Fix get_leaderboard() — use run_date instead of created_at for today filter
-- =============================================================================
-- PROBLEM: The today_points CTE filtered on run_history.created_at (the row
--   insertion timestamp), not run_history.run_date (the GMT+2 date the run
--   occurred on). This caused two subtle bugs:
--
--   1. Delayed syncs: If a run from today syncs the next day, created_at is
--      tomorrow but run_date is today. The next day's leaderboard would
--      incorrectly subtract points from yesterday's run.
--
--   2. Cross-day sync: A run done at 23:59 GMT+2 that syncs at 00:01 GMT+2
--      the next day has created_at on the new day, causing the leaderboard
--      to miscategorize which day's points are "today vs yesterday".
--
-- FIX: Replace the created_at >= midnight_gmt2 expression with
--   run_date = current_date_gmt2. This is semantically correct — run_date IS
--   the GMT+2 date of the run, set server-side by finalize_run().
--
-- NOTE: run_date is set by finalize_run() as:
--   (p_end_time AT TIME ZONE 'Etc/GMT-2')::DATE
--   It's deterministic, timezone-correct, and what all other server logic uses.
-- =============================================================================

DROP FUNCTION IF EXISTS public.get_leaderboard(INTEGER);

CREATE FUNCTION public.get_leaderboard(p_limit INTEGER DEFAULT 200)
RETURNS TABLE (
  id UUID, name TEXT, team TEXT, avatar TEXT,
  season_points INT, total_distance_km FLOAT8,
  avg_pace_min_per_km FLOAT8, avg_cv FLOAT8,
  home_hex TEXT, home_hex_end TEXT, manifesto TEXT,
  nationality TEXT, total_runs INT, rank BIGINT,
  district_hex TEXT
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
  WITH today_points AS (
    -- Subtract today's runs (run_date = GMT+2 today) from season_points
    -- so the leaderboard shows "as of yesterday midnight" — not live today.
    -- Using run_date (not created_at) ensures delayed syncs land in the
    -- correct day bucket, matching finalize_run()'s date derivation.
    SELECT
      r.user_id,
      COALESCE(SUM(r.flip_points), 0)::INT AS today_fp
    FROM run_history r
    WHERE r.run_date = (NOW() AT TIME ZONE 'Etc/GMT-2')::DATE
    GROUP BY r.user_id
  )
  SELECT
    u.id, u.name, u.team, u.avatar,
    (u.season_points - COALESCE(tp.today_fp, 0))::INT AS season_points,
    u.total_distance_km,
    u.avg_pace_min_per_km, u.avg_cv,
    u.home_hex, u.home_hex_end,
    u.manifesto, u.nationality, u.total_runs,
    ROW_NUMBER() OVER (
      ORDER BY (u.season_points - COALESCE(tp.today_fp, 0)) DESC, u.name ASC
    ),
    u.district_hex
  FROM public.users u
  LEFT JOIN today_points tp ON tp.user_id = u.id
  WHERE (u.season_points - COALESCE(tp.today_fp, 0)) > 0
    AND u.team IS NOT NULL
  ORDER BY (u.season_points - COALESCE(tp.today_fp, 0)) DESC, u.name ASC
  LIMIT p_limit;
$fn$;

GRANT EXECUTE ON FUNCTION public.get_leaderboard(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(INTEGER) TO anon;

NOTIFY pgrst, 'reload schema';
