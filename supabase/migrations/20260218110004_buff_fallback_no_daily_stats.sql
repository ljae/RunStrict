-- Fix get_user_buff() to compute elite status directly from run_history
-- when daily_buff_stats is empty (cron hasn't run yet).
-- Fallback: if user ran yesterday in their district, compute elite from run_history.
CREATE OR REPLACE FUNCTION public.get_user_buff(p_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_user RECORD;
  v_buff_stats RECORD;
  v_is_elite BOOLEAN := false;
  v_district_win BOOLEAN := false;
  v_province_win BOOLEAN := false;
  v_multiplier INTEGER := 1;
  v_reason TEXT := 'Default';
  v_yesterday DATE;
  v_red_runner_count INTEGER;
  v_elite_threshold INTEGER;
  v_user_yesterday_points INTEGER;
BEGIN
  -- Get user info
  SELECT team, district_hex INTO v_user
  FROM public.users WHERE id = p_user_id;

  IF v_user IS NULL OR v_user.district_hex IS NULL THEN
    RETURN jsonb_build_object(
      'multiplier', 1, 'base_buff', 1,
      'all_range_bonus', 0, 'reason', 'Default',
      'is_elite', false
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
  SELECT (leading_team = v_user.team) INTO v_province_win
  FROM public.daily_province_range_stats
  WHERE date = CURRENT_DATE;
  v_province_win := COALESCE(v_province_win, false);

  IF v_user.team = 'red' THEN
    -- RED: Check elite status
    v_is_elite := false;

    IF v_buff_stats IS NOT NULL AND v_buff_stats.red_elite_threshold_points IS NOT NULL THEN
      -- Use precomputed threshold from daily_buff_stats
      SELECT EXISTS(
        SELECT 1 FROM public.run_history rh
        WHERE rh.user_id = p_user_id
          AND rh.run_date = v_yesterday
          AND rh.flip_points >= v_buff_stats.red_elite_threshold_points
      ) INTO v_is_elite;
    ELSE
      -- Fallback: compute elite threshold directly from run_history
      -- Count RED runners in same district who ran yesterday
      SELECT COUNT(DISTINCT rh.user_id) INTO v_red_runner_count
      FROM public.run_history rh
      JOIN public.users u ON u.id = rh.user_id
      WHERE u.team = 'red'
        AND u.district_hex = v_user.district_hex
        AND rh.run_date = v_yesterday;

      IF v_red_runner_count > 0 THEN
        -- Elite threshold = top 20% flip_points among RED runners in district yesterday
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

        -- Check if user's yesterday points meet threshold
        SELECT COALESCE(SUM(rh.flip_points), 0) INTO v_user_yesterday_points
        FROM public.run_history rh
        WHERE rh.user_id = p_user_id
          AND rh.run_date = v_yesterday;

        v_is_elite := (v_user_yesterday_points >= v_elite_threshold AND v_user_yesterday_points > 0);
      END IF;
    END IF;

    IF v_district_win AND v_province_win THEN
      v_multiplier := CASE WHEN v_is_elite THEN 4 ELSE 2 END;
    ELSIF v_province_win THEN
      v_multiplier := CASE WHEN v_is_elite THEN 3 ELSE 2 END;
    ELSIF v_district_win THEN
      v_multiplier := CASE WHEN v_is_elite THEN 3 ELSE 1 END;
    ELSE
      v_multiplier := CASE WHEN v_is_elite THEN 2 ELSE 1 END;
    END IF;

    v_reason := CASE WHEN v_is_elite THEN 'Elite' ELSE 'Common' END;

  ELSIF v_user.team = 'blue' THEN
    -- BLUE: Union buff
    IF v_district_win AND v_province_win THEN
      v_multiplier := 3;
    ELSIF v_district_win OR v_province_win THEN
      v_multiplier := 2;
    ELSE
      v_multiplier := 1;
    END IF;
    v_reason := 'Union';

  ELSIF v_user.team = 'purple' THEN
    -- PURPLE: Participation rate
    IF v_buff_stats IS NOT NULL THEN
      IF v_buff_stats.purple_participation_rate >= 0.6 THEN
        v_multiplier := 3;
      ELSIF v_buff_stats.purple_participation_rate >= 0.3 THEN
        v_multiplier := 2;
      ELSE
        v_multiplier := 1;
      END IF;
    END IF;
    v_reason := 'Participation';
  END IF;

  RETURN jsonb_build_object(
    'multiplier', v_multiplier,
    'base_buff', v_multiplier,
    'all_range_bonus', 0,
    'reason', v_reason,
    'is_elite', v_is_elite
  );
END;
$$;
