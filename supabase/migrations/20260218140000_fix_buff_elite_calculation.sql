-- Fix get_user_buff() elite calculation:
--   1. Use GMT+2 timezone for yesterday (matching get_team_rankings)
--   2. SUM flip_points per user before ranking (was ranking individual rows)
--   3. Both bugs caused RED elite detection to always fail

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
  v_elite_cutoff_rank INTEGER;
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

  -- Yesterday in server timezone (GMT+2) - MUST match get_team_rankings()
  v_yesterday := (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE - INTERVAL '1 day';

  -- Try daily_buff_stats for precomputed data
  BEGIN
    SELECT * INTO v_buff_stats
    FROM public.daily_buff_stats
    WHERE city_hex = v_user.district_hex
      AND stat_date = CURRENT_DATE
    LIMIT 1;
  EXCEPTION WHEN undefined_column THEN
    v_buff_stats := NULL;
  END;

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
  BEGIN
    SELECT * INTO v_province_stats
    FROM public.daily_province_range_stats
    WHERE date = CURRENT_DATE;
  EXCEPTION WHEN undefined_table THEN
    v_province_stats := NULL;
  END;

  IF v_province_stats IS NOT NULL THEN
    v_province_win := (v_province_stats.leading_team = v_user.team);
  ELSE
    v_province_win := false;
  END IF;

  IF v_user.team = 'red' THEN
    -- RED: Check elite status from run_history (always compute, don't rely on daily_buff_stats)
    v_is_elite := false;

    -- Count distinct RED runners who ran yesterday in this district
    SELECT COUNT(DISTINCT rh.user_id) INTO v_red_runner_count
    FROM public.run_history rh
    JOIN public.users u ON u.id = rh.user_id
    WHERE u.team = 'red'
      AND u.district_hex = v_user.district_hex
      AND rh.run_date = v_yesterday;

    IF v_red_runner_count > 0 THEN
      -- Elite cutoff = top 20% (at least 1)
      v_elite_cutoff_rank := GREATEST(1, (v_red_runner_count * 0.2)::INTEGER);

      -- Get elite threshold: SUM flip_points per user, then find cutoff rank
      SELECT COALESCE(sub.total_points, 0) INTO v_elite_threshold
      FROM (
        SELECT
          rh.user_id,
          SUM(rh.flip_points) AS total_points,
          ROW_NUMBER() OVER (ORDER BY SUM(rh.flip_points) DESC) AS rn
        FROM public.run_history rh
        JOIN public.users u ON u.id = rh.user_id
        WHERE u.team = 'red'
          AND u.district_hex = v_user.district_hex
          AND rh.run_date = v_yesterday
        GROUP BY rh.user_id
      ) sub
      WHERE sub.rn = v_elite_cutoff_rank;

      v_elite_threshold := COALESCE(v_elite_threshold, 0);

      -- Get user's yesterday total points (SUM across all runs)
      SELECT COALESCE(SUM(rh.flip_points), 0) INTO v_user_yesterday_points
      FROM public.run_history rh
      WHERE rh.user_id = p_user_id
        AND rh.run_date = v_yesterday;

      v_is_elite := (v_user_yesterday_points >= v_elite_threshold AND v_user_yesterday_points > 0);
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
    IF v_buff_stats IS NOT NULL AND v_buff_stats.purple_participation_rate IS NOT NULL THEN
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
