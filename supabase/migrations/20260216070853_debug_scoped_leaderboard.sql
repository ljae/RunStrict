-- Debug: minimal version without nationality/pace to isolate the issue
DROP FUNCTION IF EXISTS public.get_scoped_leaderboard(TEXT, INTEGER, INTEGER);

CREATE FUNCTION public.get_scoped_leaderboard(
  p_parent_hex TEXT,
  p_scope_resolution INTEGER,
  p_limit INTEGER DEFAULT 100
)
RETURNS SETOF jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT to_jsonb(sub) FROM (
    SELECT
      u.id AS user_id,
      u.name,
      u.avatar,
      u.team,
      u.season_points AS flip_points,
      u.total_distance_km,
      u.avg_pace_min_per_km,
      u.home_hex,
      u.manifesto,
      u.nationality,
      CASE WHEN u.avg_cv IS NOT NULL
        THEN (100 - u.avg_cv)::INTEGER
        ELSE NULL END AS stability_score
    FROM public.users u
    WHERE u.season_points > 0
      AND u.home_hex IS NOT NULL
    ORDER BY u.season_points DESC
    LIMIT p_limit
  ) sub;
END;
$$;

NOTIFY pgrst, 'reload schema';
