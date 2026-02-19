-- Fix buff calculation: use explicit district_hex (Res 6) instead of deriving from home_hex_end
-- Root cause: No H3 extension on Supabase, so server can't convert Res 8 → Res 6.
-- Solution: Client computes Res 6 parent, stores it in users.district_hex via finalize_run().

-- 1. Add district_hex column to users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS district_hex TEXT;

-- 2. Rewrite get_user_buff() to use users.district_hex
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
      'all_range_bonus', 0, 'reason', 'Default'
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
      'all_range_bonus', 0, 'reason', 'Default'
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
    IF v_buff_stats.red_elite_threshold_points > 0 THEN
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
    'reason', v_reason
  );
END;
$$;

-- 3. Rewrite get_team_rankings() to filter by district using users.district_hex
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

-- 4. Rewrite finalize_run() to accept and store p_district_hex
CREATE OR REPLACE FUNCTION public.finalize_run(
  p_user_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ,
  p_distance_km DOUBLE PRECISION,
  p_duration_seconds INTEGER,
  p_hex_path TEXT[],
  p_buff_multiplier INTEGER DEFAULT 1,
  p_cv DOUBLE PRECISION DEFAULT NULL,
  p_client_points INTEGER DEFAULT 0,
  p_home_region_flips INTEGER DEFAULT 0,
  p_hex_parents TEXT[] DEFAULT NULL,
  p_district_hex TEXT DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_hex_id TEXT;
  v_team TEXT;
  v_points INTEGER;
  v_max_allowed_points INTEGER;
  v_flip_count INTEGER;
  v_current_flipped_at TIMESTAMPTZ;
  v_parent_hex TEXT;
  v_idx INTEGER;
BEGIN
  -- Get user's team
  SELECT team INTO v_team FROM users WHERE id = p_user_id;

  -- [SECURITY] Cap validation: client points cannot exceed hex_path_length × buff_multiplier
  v_max_allowed_points := COALESCE(array_length(p_hex_path, 1), 0) * p_buff_multiplier;
  v_points := LEAST(p_client_points, v_max_allowed_points);
  v_flip_count := CASE WHEN p_buff_multiplier > 0 THEN v_points / p_buff_multiplier ELSE 0 END;

  IF p_client_points > v_max_allowed_points THEN
    RAISE WARNING 'Client claimed % points but max allowed is %. Capped.', p_client_points, v_max_allowed_points;
  END IF;

  -- Update live `hexes` table for buff/dominance calculations (NOT for flip points)
  -- hex_snapshot is immutable until midnight build
  IF p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0 THEN
    v_idx := 1;
    FOREACH v_hex_id IN ARRAY p_hex_path LOOP
      -- Get parent hex from provided array or calculate
      v_parent_hex := NULL;
      IF p_hex_parents IS NOT NULL AND v_idx <= array_length(p_hex_parents, 1) THEN
        v_parent_hex := p_hex_parents[v_idx];
      END IF;

      SELECT last_flipped_at INTO v_current_flipped_at FROM public.hexes WHERE id = v_hex_id;

      IF v_current_flipped_at IS NULL OR p_end_time > v_current_flipped_at THEN
        INSERT INTO public.hexes (id, last_runner_team, last_flipped_at, parent_hex)
        VALUES (v_hex_id, v_team, p_end_time, v_parent_hex)
        ON CONFLICT (id) DO UPDATE
        SET last_runner_team = v_team,
            last_flipped_at = p_end_time,
            parent_hex = COALESCE(v_parent_hex, hexes.parent_hex)
        WHERE hexes.last_flipped_at IS NULL OR hexes.last_flipped_at < p_end_time;
      END IF;
      v_idx := v_idx + 1;
    END LOOP;
  END IF;

  -- Award client-calculated points (cap-validated)
  UPDATE users SET
    season_points = season_points + v_points,
    home_hex_start = CASE WHEN array_length(p_hex_path, 1) > 0 THEN p_hex_path[1] ELSE home_hex_start END,
    home_hex_end = CASE WHEN array_length(p_hex_path, 1) > 0 THEN p_hex_path[array_length(p_hex_path, 1)] ELSE home_hex_end END,
    district_hex = COALESCE(p_district_hex, district_hex),
    total_distance_km = total_distance_km + p_distance_km,
    total_runs = total_runs + 1,
    avg_pace_min_per_km = CASE
      WHEN p_distance_km > 0 THEN
        (COALESCE(avg_pace_min_per_km, 0) * total_runs + (p_duration_seconds / 60.0) / p_distance_km) / (total_runs + 1)
      ELSE avg_pace_min_per_km
    END,
    avg_cv = CASE
      WHEN p_cv IS NOT NULL THEN
        (COALESCE(avg_cv, 0) * cv_run_count + p_cv) / (cv_run_count + 1)
      ELSE avg_cv
    END,
    cv_run_count = CASE WHEN p_cv IS NOT NULL THEN cv_run_count + 1 ELSE cv_run_count END
  WHERE id = p_user_id;

  -- Insert lightweight run history (PRESERVED across seasons)
  INSERT INTO run_history (
    user_id, run_date, start_time, end_time,
    distance_km, duration_seconds, avg_pace_min_per_km,
    flip_count, flip_points, team_at_run, cv
  ) VALUES (
    p_user_id, (p_end_time AT TIME ZONE 'Etc/GMT-2')::DATE, p_start_time, p_end_time,
    p_distance_km, p_duration_seconds,
    CASE WHEN p_distance_km > 0 THEN (p_duration_seconds / 60.0) / p_distance_km ELSE NULL END,
    v_flip_count, v_points, v_team, p_cv
  );

  -- Return summary
  RETURN jsonb_build_object(
    'flips', v_flip_count,
    'multiplier', p_buff_multiplier,
    'points_earned', v_points,
    'server_validated', true
  );
END;
$$ LANGUAGE plpgsql;

-- 5. Rewrite calculate_daily_buffs() to use users.district_hex
-- Note: This is the Edge Function cron job logic. The actual Edge Function
-- may need separate deployment, but this documents the correct SQL logic.
-- The key fix: use u.district_hex instead of substring(u.home_hex_end, 1, 10)
-- and use u.district_hex = v_city_hex instead of u.home_hex_end LIKE v_city_hex || '%'
