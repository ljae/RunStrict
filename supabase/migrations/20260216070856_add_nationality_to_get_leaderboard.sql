-- Add nationality to get_leaderboard RPC output
-- Must DROP first because original has different return type
DROP FUNCTION IF EXISTS public.get_leaderboard(INTEGER);

CREATE FUNCTION public.get_leaderboard(p_limit INTEGER DEFAULT 20)
RETURNS SETOF jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT to_jsonb(sub) FROM (
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
      ROW_NUMBER() OVER (ORDER BY u.season_points DESC) AS rank
    FROM public.users u
    WHERE u.season_points > 0
    ORDER BY u.season_points DESC
    LIMIT p_limit
  ) sub;
$$;

NOTIFY pgrst, 'reload schema';
