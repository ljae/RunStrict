-- Fix: app_launch_sync - app_config MUST be returned on ALL paths
-- Including the early return when p_user_id is null or user not found.
-- RemoteConfigService calls this during main() before auth may be ready.

CREATE OR REPLACE FUNCTION public.app_launch_sync(
  p_user_id UUID,
  p_viewport_min_lng DOUBLE PRECISION DEFAULT NULL,
  p_viewport_min_lat DOUBLE PRECISION DEFAULT NULL,
  p_viewport_max_lng DOUBLE PRECISION DEFAULT NULL,
  p_viewport_max_lat DOUBLE PRECISION DEFAULT NULL,
  p_leaderboard_limit INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_hex_map JSONB := '[]'::JSONB;
  v_leaderboard JSONB := '[]'::JSONB;
  v_today_flip_points INTEGER := 0;
  v_today_gmt2 DATE;
  v_app_config JSONB := NULL;
BEGIN
  v_today_gmt2 := (NOW() AT TIME ZONE 'UTC' + INTERVAL '2 hours')::DATE;

  SELECT jsonb_build_object(
    'version', ac.config_version,
    'data', ac.config_data
  )
  INTO v_app_config
  FROM public.app_config ac
  WHERE ac.id = 1;

  SELECT u.id, u.name, u.team, u.avatar, u.season_points,
         u.home_hex_start, u.home_hex_end, u.manifesto,
         u.total_distance_km, u.avg_pace_min_per_km, u.avg_cv, u.total_runs,
         u.home_hex, u.season_home_hex
  INTO v_user
  FROM public.users u
  WHERE u.id = p_user_id;

  IF v_user IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'User not found',
      'user_stats', NULL,
      'app_config', v_app_config
    );
  END IF;

  SELECT COALESCE(SUM(rh.flip_points), 0)
  INTO v_today_flip_points
  FROM public.run_history rh
  WHERE rh.user_id = p_user_id
    AND rh.run_date = v_today_gmt2;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', lb.id,
      'name', lb.name,
      'team', lb.team,
      'avatar', lb.avatar,
      'season_points', lb.season_points,
      'rank', lb.rank
    ) ORDER BY lb.rank
  ), '[]'::JSONB)
  INTO v_leaderboard
  FROM (
    SELECT u.id, u.name, u.team, u.avatar, u.season_points,
           ROW_NUMBER() OVER (ORDER BY u.season_points DESC) as rank
    FROM public.users u
    WHERE u.season_points > 0
    ORDER BY u.season_points DESC
    LIMIT p_leaderboard_limit
  ) lb;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', h.id,
      'team', h.last_runner_team
    )
  ), '[]'::JSONB)
  INTO v_hex_map
  FROM public.hexes h
  WHERE h.last_runner_team IS NOT NULL;

  RETURN jsonb_build_object(
    'user_stats', jsonb_build_object(
      'id', v_user.id,
      'name', v_user.name,
      'team', v_user.team,
      'avatar', v_user.avatar,
      'season_points', v_user.season_points,
      'home_hex_start', v_user.home_hex_start,
      'home_hex_end', v_user.home_hex_end,
      'manifesto', v_user.manifesto,
      'total_distance_km', v_user.total_distance_km,
      'avg_pace_min_per_km', v_user.avg_pace_min_per_km,
      'avg_cv', v_user.avg_cv,
      'total_runs', v_user.total_runs,
      'home_hex', v_user.home_hex,
      'season_home_hex', v_user.season_home_hex
    ),
    'today_flip_points', v_today_flip_points,
    'app_config', v_app_config,
    'hex_map', v_hex_map,
    'leaderboard', v_leaderboard,
    'server_time', now(),
    'server_date_gmt2', v_today_gmt2
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_launch_sync(UUID, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_launch_sync(UUID, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER) TO anon;

-- Verify: both null-user and real-user paths return app_config
SELECT 'null user' as test,
  (app_launch_sync(NULL))->'app_config'->'data'->'season' as season_config;

SELECT 'real user' as test,
  (app_launch_sync(
    (SELECT id FROM public.users WHERE name IS NOT NULL LIMIT 1)
  ))->'app_config'->'data'->'season' as season_config;
