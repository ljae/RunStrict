-- RunStrict: Team Stats RPC Functions (Fixed)
-- Fixes:
-- 1. Timezone: CURRENT_DATE → (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE
-- 2. get_team_rankings: adds red_runner_count_city + elite_cutoff_rank, drops broken LIKE filter
-- 3. get_hex_dominance: snapshot-based (hex_snapshot + daily_buff_stats), not live hexes
--
-- Functions:
-- - get_user_yesterday_stats(p_user_id UUID) - Yesterday's run stats
-- - get_team_rankings(p_user_id UUID, p_city_hex TEXT) - Team rankings by group
-- - get_hex_dominance(p_city_hex TEXT) - Hex counts for ALL Range and City Range

-- ============================================================
-- 1. GET_USER_YESTERDAY_STATS FUNCTION (timezone fix)
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_user_yesterday_stats(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_yesterday DATE := (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE - INTERVAL '1 day';
  v_stats RECORD;
  v_cv DOUBLE PRECISION;
  v_stability_score INTEGER;
BEGIN
  SELECT
    COALESCE(SUM(rh.distance_km), 0) as total_distance_km,
    CASE
      WHEN SUM(rh.distance_km) > 0
      THEN SUM(rh.duration_seconds / 60.0) / SUM(rh.distance_km)
      ELSE NULL
    END as avg_pace_min_per_km,
    COALESCE(SUM(rh.flip_count), 0) as total_flips,
    COALESCE(SUM(rh.flip_points), 0) as total_points,
    COUNT(*) as run_count
  INTO v_stats
  FROM public.run_history rh
  WHERE rh.user_id = p_user_id
    AND rh.run_date = v_yesterday;

  IF v_stats.run_count = 0 OR v_stats.total_distance_km = 0 THEN
    RETURN jsonb_build_object(
      'has_data', false,
      'distance_km', NULL,
      'avg_pace_min_per_km', NULL,
      'flip_count', NULL,
      'flip_points', NULL,
      'stability_score', NULL,
      'run_count', 0,
      'date', v_yesterday
    );
  END IF;

  SELECT AVG(rh.cv)
  INTO v_cv
  FROM public.run_history rh
  WHERE rh.user_id = p_user_id
    AND rh.run_date = v_yesterday
    AND rh.cv IS NOT NULL;

  IF v_cv IS NOT NULL THEN
    v_stability_score := GREATEST(0, LEAST(100, (100 - v_cv)::INTEGER));
  ELSE
    v_stability_score := NULL;
  END IF;

  RETURN jsonb_build_object(
    'has_data', true,
    'distance_km', ROUND(v_stats.total_distance_km::NUMERIC, 2),
    'avg_pace_min_per_km', ROUND(v_stats.avg_pace_min_per_km::NUMERIC, 2),
    'flip_count', v_stats.total_flips,
    'flip_points', v_stats.total_points,
    'stability_score', v_stability_score,
    'run_count', v_stats.run_count,
    'date', v_yesterday
  );
END;
$$;

-- ============================================================
-- 2. GET_TEAM_RANKINGS FUNCTION (timezone fix + missing fields + no broken LIKE)
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_team_rankings(
  p_user_id UUID,
  p_city_hex TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_city_hex TEXT;
  v_yesterday DATE := (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE - INTERVAL '1 day';
  v_elite_threshold INTEGER;
  v_user_yesterday_points INTEGER;
  v_user_is_elite BOOLEAN := FALSE;
  v_user_rank INTEGER;
  v_red_elite_top3 JSONB;
  v_red_common_top3 JSONB;
  v_blue_union_top3 JSONB;
  v_red_runner_count INTEGER;
  v_top20_cutoff INTEGER;
BEGIN
  -- Get user info
  SELECT u.id, u.team, u.home_hex_end, u.name
  INTO v_user
  FROM public.users u
  WHERE u.id = p_user_id;

  IF v_user.id IS NULL THEN
    RETURN jsonb_build_object('error', 'User not found');
  END IF;

  -- Determine city hex
  IF p_city_hex IS NOT NULL THEN
    v_city_hex := p_city_hex;
  ELSIF v_user.home_hex_end IS NOT NULL AND length(v_user.home_hex_end) > 0 THEN
    v_city_hex := substring(v_user.home_hex_end from 1 for 10);
  ELSE
    v_city_hex := NULL;
  END IF;

  -- Calculate elite threshold LIVE from run_history
  -- Count all red runners who ran yesterday (no city filter — H3 prefix matching is broken)
  SELECT COUNT(DISTINCT u.id)
  INTO v_red_runner_count
  FROM public.users u
  JOIN public.run_history rh ON rh.user_id = u.id
  WHERE u.team = 'red'
    AND rh.run_date = v_yesterday;

  -- Top 20% cutoff rank
  v_top20_cutoff := GREATEST(1, CEIL(v_red_runner_count * 0.2));

  -- Get the points threshold at the top-20% boundary
  SELECT COALESCE(sub.points, 0)
  INTO v_elite_threshold
  FROM (
    SELECT SUM(rh.flip_points) as points,
           ROW_NUMBER() OVER (ORDER BY SUM(rh.flip_points) DESC) as rn
    FROM public.users u
    JOIN public.run_history rh ON rh.user_id = u.id
    WHERE u.team = 'red'
      AND rh.run_date = v_yesterday
    GROUP BY u.id
    ORDER BY SUM(rh.flip_points) DESC
    LIMIT v_top20_cutoff
  ) sub
  ORDER BY sub.points ASC
  LIMIT 1;

  v_elite_threshold := COALESCE(v_elite_threshold, 0);

  -- Get user's yesterday flip points
  SELECT COALESCE(SUM(rh.flip_points), 0)
  INTO v_user_yesterday_points
  FROM public.run_history rh
  WHERE rh.user_id = p_user_id
    AND rh.run_date = v_yesterday;

  v_user_is_elite := (v_user_yesterday_points >= v_elite_threshold AND v_user_yesterday_points > 0 AND v_elite_threshold > 0);

  -- RED Elite top 3
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'user_id', ranked.user_id,
      'name', ranked.name,
      'yesterday_points', ranked.yesterday_points,
      'rank', ranked.rank
    ) ORDER BY ranked.rank
  ), '[]'::JSONB)
  INTO v_red_elite_top3
  FROM (
    SELECT
      u.id as user_id,
      u.name,
      SUM(rh.flip_points) as yesterday_points,
      ROW_NUMBER() OVER (ORDER BY SUM(rh.flip_points) DESC) as rank
    FROM public.users u
    JOIN public.run_history rh ON rh.user_id = u.id
    WHERE u.team = 'red'
      AND rh.run_date = v_yesterday
    GROUP BY u.id, u.name
    HAVING SUM(rh.flip_points) >= v_elite_threshold AND SUM(rh.flip_points) > 0 AND v_elite_threshold > 0
    ORDER BY SUM(rh.flip_points) DESC
    LIMIT 3
  ) ranked;

  -- RED Common top 3
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'user_id', ranked.user_id,
      'name', ranked.name,
      'yesterday_points', ranked.yesterday_points,
      'rank', ranked.rank
    ) ORDER BY ranked.rank
  ), '[]'::JSONB)
  INTO v_red_common_top3
  FROM (
    SELECT
      u.id as user_id,
      u.name,
      COALESCE(SUM(rh.flip_points), 0) as yesterday_points,
      ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(rh.flip_points), 0) DESC) as rank
    FROM public.users u
    LEFT JOIN public.run_history rh ON rh.user_id = u.id AND rh.run_date = v_yesterday
    WHERE u.team = 'red'
    GROUP BY u.id, u.name
    HAVING COALESCE(SUM(rh.flip_points), 0) < v_elite_threshold OR v_elite_threshold = 0
    ORDER BY COALESCE(SUM(rh.flip_points), 0) DESC
    LIMIT 3
  ) ranked;

  -- BLUE Union top 3
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'user_id', ranked.user_id,
      'name', ranked.name,
      'yesterday_points', ranked.yesterday_points,
      'rank', ranked.rank
    ) ORDER BY ranked.rank
  ), '[]'::JSONB)
  INTO v_blue_union_top3
  FROM (
    SELECT
      u.id as user_id,
      u.name,
      COALESCE(SUM(rh.flip_points), 0) as yesterday_points,
      ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(rh.flip_points), 0) DESC) as rank
    FROM public.users u
    LEFT JOIN public.run_history rh ON rh.user_id = u.id AND rh.run_date = v_yesterday
    WHERE u.team = 'blue'
    GROUP BY u.id, u.name
    ORDER BY COALESCE(SUM(rh.flip_points), 0) DESC
    LIMIT 3
  ) ranked;

  -- Calculate user's rank within their group
  IF v_user.team = 'red' THEN
    IF v_user_is_elite THEN
      SELECT COUNT(*) + 1
      INTO v_user_rank
      FROM (
        SELECT u.id
        FROM public.run_history rh
        JOIN public.users u ON u.id = rh.user_id
        WHERE u.team = 'red'
          AND rh.run_date = v_yesterday
        GROUP BY u.id
        HAVING SUM(rh.flip_points) > v_user_yesterday_points
          AND SUM(rh.flip_points) >= v_elite_threshold
      ) sub;
    ELSE
      SELECT COUNT(*) + 1
      INTO v_user_rank
      FROM public.users u
      LEFT JOIN (
        SELECT user_id, SUM(flip_points) as points
        FROM public.run_history
        WHERE run_date = v_yesterday
        GROUP BY user_id
      ) rh ON rh.user_id = u.id
      WHERE u.team = 'red'
        AND (COALESCE(rh.points, 0) < v_elite_threshold OR v_elite_threshold = 0)
        AND COALESCE(rh.points, 0) > v_user_yesterday_points;
    END IF;
  ELSIF v_user.team = 'blue' THEN
    SELECT COUNT(*) + 1
    INTO v_user_rank
    FROM public.users u
    LEFT JOIN (
      SELECT user_id, SUM(flip_points) as points
      FROM public.run_history
      WHERE run_date = v_yesterday
      GROUP BY user_id
    ) rh ON rh.user_id = u.id
    WHERE u.team = 'blue'
      AND COALESCE(rh.points, 0) > v_user_yesterday_points;
  ELSE
    v_user_rank := NULL;
  END IF;

  RETURN jsonb_build_object(
    'user_team', v_user.team,
    'user_is_elite', v_user_is_elite,
    'user_yesterday_points', v_user_yesterday_points,
    'user_rank', COALESCE(v_user_rank, 1),
    'elite_threshold', v_elite_threshold,
    'city_hex', v_city_hex,
    'red_elite_top3', v_red_elite_top3,
    'red_common_top3', v_red_common_top3,
    'blue_union_top3', v_blue_union_top3,
    'red_runner_count_city', v_red_runner_count,
    'elite_cutoff_rank', v_top20_cutoff
  );
END;
$$;

-- ============================================================
-- 3. GET_HEX_DOMINANCE FUNCTION (snapshot-based)
-- ============================================================
-- Province: from hex_snapshot (latest snapshot_date)
-- District: from daily_buff_stats (latest stat_date)

CREATE OR REPLACE FUNCTION public.get_hex_dominance(p_city_hex TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_all_red INTEGER;
  v_all_blue INTEGER;
  v_all_purple INTEGER;
  v_all_total INTEGER;
  v_city_red INTEGER;
  v_city_blue INTEGER;
  v_city_purple INTEGER;
  v_city_total INTEGER;
  v_latest_snapshot_date DATE;
  v_latest_buff_date DATE;
BEGIN
  -- ALL Range: province-level from daily_all_range_stats (latest date)
  SELECT stat_date INTO v_latest_snapshot_date
  FROM public.daily_all_range_stats
  ORDER BY stat_date DESC
  LIMIT 1;

  IF v_latest_snapshot_date IS NOT NULL THEN
    SELECT
      COALESCE(red_hex_count, 0),
      COALESCE(blue_hex_count, 0),
      COALESCE(purple_hex_count, 0)
    INTO v_all_red, v_all_blue, v_all_purple
    FROM public.daily_all_range_stats
    WHERE stat_date = v_latest_snapshot_date;
  ELSE
    -- Fallback: count from hex_snapshot (latest snapshot_date)
    SELECT MAX(snapshot_date) INTO v_latest_snapshot_date
    FROM public.hex_snapshot;

    IF v_latest_snapshot_date IS NOT NULL THEN
      SELECT
        COALESCE(SUM(CASE WHEN hs.last_runner_team = 'red' THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN hs.last_runner_team = 'blue' THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN hs.last_runner_team = 'purple' THEN 1 ELSE 0 END), 0)
      INTO v_all_red, v_all_blue, v_all_purple
      FROM public.hex_snapshot hs
      WHERE hs.snapshot_date = v_latest_snapshot_date
        AND hs.last_runner_team IS NOT NULL;
    ELSE
      v_all_red := 0;
      v_all_blue := 0;
      v_all_purple := 0;
    END IF;
  END IF;

  v_all_total := v_all_red + v_all_blue + v_all_purple;

  -- CITY Range: from daily_buff_stats (latest stat_date for this city_hex)
  IF p_city_hex IS NOT NULL THEN
    SELECT MAX(stat_date) INTO v_latest_buff_date
    FROM public.daily_buff_stats
    WHERE city_hex = p_city_hex;

    IF v_latest_buff_date IS NOT NULL THEN
      SELECT
        COALESCE(red_hex_count, 0),
        COALESCE(blue_hex_count, 0),
        COALESCE(purple_hex_count, 0)
      INTO v_city_red, v_city_blue, v_city_purple
      FROM public.daily_buff_stats
      WHERE city_hex = p_city_hex
        AND stat_date = v_latest_buff_date;
    ELSE
      v_city_red := 0;
      v_city_blue := 0;
      v_city_purple := 0;
    END IF;

    v_city_total := v_city_red + v_city_blue + v_city_purple;
  END IF;

  RETURN jsonb_build_object(
    'all_range', jsonb_build_object(
      'red_hex_count', v_all_red,
      'blue_hex_count', v_all_blue,
      'purple_hex_count', v_all_purple,
      'total', v_all_total
    ),
    'city_range', CASE
      WHEN p_city_hex IS NOT NULL THEN jsonb_build_object(
        'city_hex', p_city_hex,
        'red_hex_count', v_city_red,
        'blue_hex_count', v_city_blue,
        'purple_hex_count', v_city_purple,
        'total', v_city_total
      )
      ELSE NULL
    END
  );
END;
$$;

-- ============================================================
-- 4. ADD INDEXES FOR PERFORMANCE
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_run_history_user_date
ON public.run_history(user_id, run_date);

CREATE INDEX IF NOT EXISTS idx_users_team_home_hex
ON public.users(team, home_hex_end);

-- ============================================================
-- 5. GRANT EXECUTE PERMISSIONS
-- ============================================================

GRANT EXECUTE ON FUNCTION public.get_user_yesterday_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_team_rankings(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_hex_dominance(TEXT) TO authenticated;

-- Also grant to anon for testing (simulation users aren't authenticated)
GRANT EXECUTE ON FUNCTION public.get_user_yesterday_stats(UUID) TO anon;
GRANT EXECUTE ON FUNCTION public.get_team_rankings(UUID, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.get_hex_dominance(TEXT) TO anon;
