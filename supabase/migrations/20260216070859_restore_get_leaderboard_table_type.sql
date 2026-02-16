-- Restore get_leaderboard with TABLE return type (matching original)
-- but add nationality column. Other RPCs (app_launch_sync) depend on
-- the TABLE return type to reference columns like lb.id.
DROP FUNCTION IF EXISTS public.get_leaderboard(INTEGER);

CREATE FUNCTION public.get_leaderboard(p_limit INTEGER DEFAULT 20)
RETURNS TABLE (
  id UUID,
  name TEXT,
  team TEXT,
  avatar TEXT,
  season_points INT,
  total_distance_km FLOAT8,
  avg_pace_min_per_km FLOAT8,
  avg_cv FLOAT8,
  home_hex TEXT,
  home_hex_end TEXT,
  manifesto TEXT,
  nationality TEXT,
  total_runs INT,
  rank BIGINT
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    u.id,
    u.name,
    u.team,
    u.avatar,
    u.season_points,
    u.total_distance_km,
    u.avg_pace_min_per_km,
    u.avg_cv,
    u.home_hex,
    u.home_hex_end,
    u.manifesto,
    u.nationality,
    u.total_runs,
    ROW_NUMBER() OVER (ORDER BY u.season_points DESC)
  FROM public.users u
  WHERE u.season_points > 0
  ORDER BY u.season_points DESC
  LIMIT p_limit;
$$;

NOTIFY pgrst, 'reload schema';
