-- Fix: My League province filtering was broken because seed home_hex values
-- are string-constructed (not valid H3 cells). The H3 library computes wrong
-- Res 5 parents from them, causing cross-province leakage.
--
-- Solution: Return district_hex (Res 6, always valid) from get_leaderboard.
-- Client uses district_hex → cellToParent(res=5) for province filtering.

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
    SELECT
      r.user_id,
      COALESCE(SUM(r.flip_points), 0)::INT AS today_fp
    FROM run_history r
    WHERE r.created_at >= (
      date_trunc('day', now() AT TIME ZONE 'UTC' + interval '2 hours')
      - interval '2 hours'
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

-- Fix seed home_hex_end: was 14 chars, should be 15
UPDATE public.users
SET home_hex_end = home_hex_end || 'f'
WHERE LENGTH(home_hex_end) = 14
  AND id::text LIKE 'dddddddd-%';

NOTIFY pgrst, 'reload schema';
