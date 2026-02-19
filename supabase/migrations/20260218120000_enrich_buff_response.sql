-- Enrich get_user_buff() to return full buff breakdown fields
-- and update app_launch_sync() to delegate to get_user_buff()
-- so both paths return the same shape for BuffBreakdown.fromJson()

-- =============================================================================
-- get_user_buff: Enriched response with breakdown fields
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_user_buff(p_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_user RECORD;
  v_buff_stats RECORD;
  v_province_stats RECORD;
  v_is_elite BOOLEAN := false;
  v_district_win BOOLEAN := false;
  v_province_win BOOLEAN := false;
  v_multiplier INTEGER := 1;
  v_base_buff INTEGER := 1;
  v_district_bonus INTEGER := 0;
  v_province_bonus INTEGER := 0;
  v_reason TEXT := 'Default';
  v_yesterday DATE;
  v_red_runner_count INTEGER;
  v_elite_threshold INTEGER := 0;
  v_user_yesterday_points INTEGER := 0;
BEGIN
  -- Get user info
  SELECT team, district_hex INTO v_user
  FROM public.users WHERE id = p_user_id;

  IF v_user IS NULL OR v_user.district_hex IS NULL THEN
    RETURN jsonb_build_object(
      'multiplier', 1, 'base_buff', 1,
      'all_range_bonus', 0, 'district_bonus', 0, 'province_bonus', 0,
      'reason', 'Default',
      'team', COALESCE(v_user.team, ''),
      'district_hex', NULL,
      'is_elite', false,
      'has_district_win', false,
      'has_province_win', false,
      'elite_threshold', 0,
      'yesterday_points', 0
    );
  END IF;

  v_yesterday := CURRENT_DATE - INTERVAL '1 day';

  -- Get daily buff stats for user's district
  SELECT * INTO v_buff_stats
  FROM public.daily_buff_stats
  WHERE city_hex = v_user.district_hex
    AND stat_date = CURRENT_DATE
  LIMIT 1;

  -- Check district win from daily_buff_stats or live hexes
  IF v_buff_stats IS NOT NULL THEN
    v_district_win := (v_buff_stats.dominant_team = v_user.team);
  ELSE
    -- Fallback: compute from live hexes table
    SELECT (
      CASE v_user.team
        WHEN 'red' THEN COUNT(CASE WHEN last_runner_team = 'red' THEN 1 END)
        WHEN 'blue' THEN COUNT(CASE WHEN last_runner_team = 'blue' THEN 1 END)
        ELSE 0
      END >
      GREATEST(
        CASE WHEN v_user.team != 'red' THEN COUNT(CASE WHEN last_runner_team = 'red' THEN 1 END) ELSE 0 END,
        CASE WHEN v_user.team != 'blue' THEN COUNT(CASE WHEN last_runner_team = 'blue' THEN 1 END) ELSE 0 END,
        CASE WHEN v_user.team != 'purple' THEN COUNT(CASE WHEN last_runner_team = 'purple' THEN 1 END) ELSE 0 END
      )
    ) INTO v_district_win
    FROM public.hexes
    WHERE parent_hex = v_user.district_hex;
  END IF;

  -- Check province win
  SELECT * INTO v_province_stats
  FROM public.daily_province_range_stats
  WHERE date = CURRENT_DATE;

  IF v_province_stats IS NOT NULL THEN
    v_province_win := (v_province_stats.leading_team = v_user.team);
  ELSE
    v_province_win := false;
  END IF;

  IF v_user.team = 'red' THEN
    -- RED: Check elite status
    v_is_elite := false;

    IF v_buff_stats IS NOT NULL AND v_buff_stats.red_elite_threshold_points IS NOT NULL THEN
      v_elite_threshold := v_buff_stats.red_elite_threshold_points;
      -- Get user's yesterday points
      SELECT COALESCE(SUM(rh.flip_points), 0) INTO v_user_yesterday_points
      FROM public.run_history rh
      WHERE rh.user_id = p_user_id
        AND rh.run_date = v_yesterday;

      v_is_elite := (v_user_yesterday_points >= v_elite_threshold AND v_user_yesterday_points > 0);
    ELSE
      -- Fallback: compute elite threshold directly from run_history
      SELECT COUNT(DISTINCT rh.user_id) INTO v_red_runner_count
      FROM public.run_history rh
      JOIN public.users u ON u.id = rh.user_id
      WHERE u.team = 'red'
        AND u.district_hex = v_user.district_hex
        AND rh.run_date = v_yesterday;

      IF v_red_runner_count > 0 THEN
        SELECT COALESCE(flip_points, 0) INTO v_elite_threshold
        FROM (
          SELECT rh.flip_points,
                 ROW_NUMBER() OVER (ORDER BY rh.flip_points DESC) AS rn
          FROM public.run_history rh
          JOIN public.users u ON u.id = rh.user_id
          WHERE u.team = 'red'
            AND u.district_hex = v_user.district_hex
            AND rh.run_date = v_yesterday
        ) ranked
        WHERE rn = GREATEST(1, (v_red_runner_count * 0.2)::INTEGER);

        v_elite_threshold := COALESCE(v_elite_threshold, 0);

        SELECT COALESCE(SUM(rh.flip_points), 0) INTO v_user_yesterday_points
        FROM public.run_history rh
        WHERE rh.user_id = p_user_id
          AND rh.run_date = v_yesterday;

        v_is_elite := (v_user_yesterday_points >= v_elite_threshold AND v_user_yesterday_points > 0);
      END IF;
    END IF;

    -- RED buff calculation with breakdown
    v_base_buff := CASE WHEN v_is_elite THEN 2 ELSE 1 END;
    v_district_bonus := CASE
      WHEN v_is_elite AND v_district_win THEN 1
      ELSE 0
    END;
    v_province_bonus := CASE
      WHEN v_province_win THEN 1
      ELSE 0
    END;
    v_multiplier := v_base_buff + v_district_bonus + v_province_bonus;
    v_reason := CASE WHEN v_is_elite THEN 'Elite' ELSE 'Common' END;

  ELSIF v_user.team = 'blue' THEN
    -- BLUE buff calculation with breakdown
    v_base_buff := 1;
    v_district_bonus := CASE WHEN v_district_win THEN 1 ELSE 0 END;
    v_province_bonus := CASE WHEN v_province_win THEN 1 ELSE 0 END;
    v_multiplier := v_base_buff + v_district_bonus + v_province_bonus;
    v_reason := 'Union';

  ELSIF v_user.team = 'purple' THEN
    IF v_buff_stats IS NOT NULL THEN
      IF v_buff_stats.purple_participation_rate >= 0.6 THEN
        v_base_buff := 3;
      ELSIF v_buff_stats.purple_participation_rate >= 0.3 THEN
        v_base_buff := 2;
      ELSE
        v_base_buff := 1;
      END IF;
    ELSE
      v_base_buff := 1;
    END IF;
    v_multiplier := v_base_buff;
    v_reason := 'Participation';
  END IF;

  RETURN jsonb_build_object(
    'multiplier', v_multiplier,
    'base_buff', v_base_buff,
    'all_range_bonus', v_province_bonus,
    'district_bonus', v_district_bonus,
    'province_bonus', v_province_bonus,
    'reason', v_reason,
    'team', v_user.team,
    'district_hex', v_user.district_hex,
    'is_elite', v_is_elite,
    'has_district_win', v_district_win,
    'has_province_win', v_province_win,
    'elite_threshold', COALESCE(v_elite_threshold, 0),
    'yesterday_points', COALESCE(v_user_yesterday_points, 0)
  );
END;
$$;

-- =============================================================================
-- app_launch_sync: Now delegates buff to get_user_buff() for consistent shape
-- =============================================================================
CREATE OR REPLACE FUNCTION public.app_launch_sync(p_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_user_stats jsonb;
  v_user_buff jsonb;
BEGIN
  -- Get user stats
  SELECT jsonb_build_object(
    'season_points', u.season_points,
    'home_hex', u.home_hex,
    'home_hex_end', u.home_hex_end,
    'season_home_hex', u.season_home_hex,
    'total_distance_km', u.total_distance_km,
    'avg_pace_min_per_km', u.avg_pace_min_per_km,
    'avg_cv', u.avg_cv,
    'total_runs', u.total_runs
  ) INTO v_user_stats
  FROM public.users u
  WHERE u.id = p_user_id;

  -- Delegate to get_user_buff() for consistent buff shape
  v_user_buff := public.get_user_buff(p_user_id);

  RETURN jsonb_build_object(
    'user_stats', COALESCE(v_user_stats, '{}'::jsonb),
    'user_buff', COALESCE(v_user_buff, jsonb_build_object('multiplier', 1))
  );
END;
$$;
