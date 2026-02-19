-- Fix get_team_rankings() to include red_runner_count_city and elite_cutoff_rank
-- These fields are expected by TeamRankings.fromJson() in the Flutter client
CREATE OR REPLACE FUNCTION public.get_team_rankings(
  p_user_id UUID,
  p_city_hex TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_city_hex TEXT;
  v_red_runner_count INTEGER;
  v_result jsonb;
BEGIN
  -- Use provided city_hex or look up user's district_hex
  IF p_city_hex IS NOT NULL THEN
    v_city_hex := p_city_hex;
  ELSE
    SELECT district_hex INTO v_city_hex FROM public.users WHERE id = p_user_id;
  END IF;

  -- Count RED runners in district (for elite cutoff display)
  SELECT COUNT(*) INTO v_red_runner_count
  FROM public.users u
  WHERE u.team = 'red' AND u.season_points > 0
    AND (v_city_hex IS NULL OR u.district_hex = v_city_hex);

  -- District-scoped rankings
  SELECT jsonb_build_object(
    'red_points', COALESCE(SUM(CASE WHEN u.team = 'red' THEN u.season_points ELSE 0 END), 0),
    'blue_points', COALESCE(SUM(CASE WHEN u.team = 'blue' THEN u.season_points ELSE 0 END), 0),
    'purple_points', COALESCE(SUM(CASE WHEN u.team = 'purple' THEN u.season_points ELSE 0 END), 0),
    'red_runners', COUNT(CASE WHEN u.team = 'red' THEN 1 END),
    'blue_runners', COUNT(CASE WHEN u.team = 'blue' THEN 1 END),
    'purple_runners', COUNT(CASE WHEN u.team = 'purple' THEN 1 END),
    'red_runner_count_city', v_red_runner_count,
    'elite_cutoff_rank', GREATEST(1, (v_red_runner_count * 0.2)::INTEGER)
  ) INTO v_result
  FROM public.users u
  WHERE u.season_points > 0
    AND (v_city_hex IS NULL OR u.district_hex = v_city_hex);

  RETURN COALESCE(v_result, jsonb_build_object(
    'red_points', 0, 'blue_points', 0, 'purple_points', 0,
    'red_runners', 0, 'blue_runners', 0, 'purple_runners', 0,
    'red_runner_count_city', 0, 'elite_cutoff_rank', 0
  ));
END;
$$;
