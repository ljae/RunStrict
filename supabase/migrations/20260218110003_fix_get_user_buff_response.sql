-- Fix get_user_buff() to include is_elite in response
-- The Flutter client's BuffBreakdown.fromJson() reads is_elite to determine
-- elite status for the BUFF COMPARISON display on TeamScreen
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

  -- Get daily buff stats for user's district
  SELECT * INTO v_buff_stats
  FROM public.daily_buff_stats
  WHERE city_hex = v_user.district_hex
    AND stat_date = CURRENT_DATE
  LIMIT 1;

  IF v_buff_stats IS NULL THEN
    RETURN jsonb_build_object(
      'multiplier', 1, 'base_buff', 1,
      'all_range_bonus', 0, 'reason', 'Default',
      'is_elite', false
    );
  END IF;

  -- Check district win
  v_district_win := (v_buff_stats.dominant_team = v_user.team);

  -- Check province win
  SELECT (leading_team = v_user.team) INTO v_province_win
  FROM public.daily_province_range_stats
  WHERE date = CURRENT_DATE;
  v_province_win := COALESCE(v_province_win, false);

  IF v_user.team = 'red' THEN
    -- RED: Check elite status (top 20% by yesterday's flip_points in same district)
    v_is_elite := false;
    IF v_buff_stats.red_elite_threshold_points IS NOT NULL THEN
      SELECT EXISTS(
        SELECT 1 FROM public.run_history rh
        JOIN public.users u ON u.id = rh.user_id
        WHERE rh.user_id = p_user_id
          AND u.district_hex = v_user.district_hex
          AND rh.run_date = CURRENT_DATE - INTERVAL '1 day'
          AND rh.flip_points >= v_buff_stats.red_elite_threshold_points
      ) INTO v_is_elite;
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
    IF v_buff_stats.purple_participation_rate >= 0.6 THEN
      v_multiplier := 3;
    ELSIF v_buff_stats.purple_participation_rate >= 0.3 THEN
      v_multiplier := 2;
    ELSE
      v_multiplier := 1;
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
