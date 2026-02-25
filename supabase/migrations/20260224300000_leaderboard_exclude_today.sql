-- Fix: get_leaderboard should reflect data through yesterday (midnight GMT+2),
-- not include today's live points.
--
-- Approach: Subtract each user's today-only flip_points (from run_history)
-- from their season_points. Users whose adjusted points = 0 are excluded.
-- "Today" is defined as >= midnight GMT+2 (server timezone).

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
  WITH today_points AS (
    -- Sum flip_points from runs created today (midnight GMT+2 onwards)
    SELECT
      r.user_id,
      COALESCE(SUM(r.flip_points), 0)::INT AS today_fp
    FROM run_history r
    WHERE r.created_at >= (
      date_trunc('day', now() AT TIME ZONE 'UTC' + interval '2 hours')
      - interval '2 hours'  -- convert midnight GMT+2 back to UTC
    )
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
    )
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
