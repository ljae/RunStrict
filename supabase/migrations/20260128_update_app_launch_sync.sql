CREATE OR REPLACE FUNCTION app_launch_sync(
  p_user_id UUID DEFAULT NULL,
  p_viewport_bounds JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
  v_user_data JSONB;
  v_yesterday_count INT;
  v_hexes JSONB;
  v_config JSONB;
BEGIN
  -- Get user data if user_id provided
  IF p_user_id IS NOT NULL THEN
    SELECT jsonb_build_object(
      'id', id,
      'name', name,
      'team', team,
      'season_points', season_points,
      'crew_id', crew_id
    ) INTO v_user_data
    FROM users
    WHERE id = p_user_id;
  END IF;

  -- Get yesterday's crew activity count (for multiplier calculation)
  IF p_user_id IS NOT NULL THEN
    SELECT COUNT(DISTINCT user_id) INTO v_yesterday_count
    FROM daily_running_stats
    WHERE crew_id = (SELECT crew_id FROM users WHERE id = p_user_id)
      AND date = CURRENT_DATE - INTERVAL '1 day'
      AND distance_meters > 0;
  ELSE
    v_yesterday_count := 0;
  END IF;

  -- Get hexes in viewport (if bounds provided)
  IF p_viewport_bounds IS NOT NULL THEN
    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'hex_id', hex_id,
        'last_runner_team', last_runner_team
      )
    ), '[]'::jsonb) INTO v_hexes
    FROM hexes
    WHERE ST_Intersects(
      ST_MakeEnvelope(
        (p_viewport_bounds->>'min_lng')::float,
        (p_viewport_bounds->>'min_lat')::float,
        (p_viewport_bounds->>'max_lng')::float,
        (p_viewport_bounds->>'max_lat')::float,
        4326
      ),
      location
    );
  ELSE
    v_hexes := '[]'::jsonb;
  END IF;

  -- Get app config (single row table)
  SELECT jsonb_build_object(
    'version', config_version,
    'data', config_data
  ) INTO v_config
  FROM app_config
  WHERE id = 1;

  -- If no config exists, return null (app will use defaults)
  IF v_config IS NULL THEN
    v_config := NULL;
  END IF;

  -- Build result object
  v_result := jsonb_build_object(
    'user', v_user_data,
    'yesterday_crew_count', COALESCE(v_yesterday_count, 0),
    'hexes_in_viewport', v_hexes,
    'app_config', v_config
  );

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION app_launch_sync IS 'Fetches user profile, yesterday crew activity, viewport hexes, and app config in one call.';
