-- Fix: get_leaderboard reads LIVE users table for current season
-- instead of stale season_leaderboard_snapshot.
--
-- Root cause: The snapshot cron (snapshot_season_leaderboard) was never
-- scheduled, so the snapshot only contained seed data. Real users never
-- appeared in the snapshot → leaderboard showed 0 points.
--
-- Design decision: For the ACTIVE season, read directly from users table
-- (updated in real-time by finalize_run). Snapshot remains for historical
-- season viewing via get_season_leaderboard().
--
-- Also increases default limit from 20 to 200 to cover all active users.

DROP FUNCTION IF EXISTS public.get_leaderboard(INTEGER);

CREATE FUNCTION public.get_leaderboard(p_limit INTEGER DEFAULT 200)
RETURNS TABLE (
  id UUID, name TEXT, team TEXT, avatar TEXT,
  season_points INT, total_distance_km FLOAT8,
  avg_pace_min_per_km FLOAT8, avg_cv FLOAT8,
  home_hex TEXT, home_hex_end TEXT, manifesto TEXT,
  nationality TEXT, total_runs INT, rank BIGINT
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT
    u.id, u.name, u.team, u.avatar,
    u.season_points, u.total_distance_km,
    u.avg_pace_min_per_km, u.avg_cv,
    u.home_hex, u.home_hex_end,
    u.manifesto, u.nationality, u.total_runs,
    ROW_NUMBER() OVER (ORDER BY u.season_points DESC, u.name ASC)
  FROM public.users u
  WHERE u.season_points > 0
    AND u.team IS NOT NULL
  ORDER BY u.season_points DESC, u.name ASC
  LIMIT p_limit;
$fn$;

GRANT EXECUTE ON FUNCTION public.get_leaderboard(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(INTEGER) TO anon;

NOTIFY pgrst, 'reload schema';
