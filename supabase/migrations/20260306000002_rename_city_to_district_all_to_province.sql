-- ============================================================================
-- RENAME: city → district, all → province (terminology cleanup)
-- ============================================================================
-- This migration renames terminology throughout the server-side functions
-- and schema to match the updated client-side naming conventions:
--   - GeographicScope.city → district
--   - GeographicScope.all  → province
--   - daily_buff_stats.city_hex column → district_hex
--   - JSON keys: all_range_bonus → province_range_bonus
--               city_hex → district_hex
--               red_runner_count_city → red_runner_count_district
--               cities_processed → districts_processed
-- ============================================================================

-- ============================================================================
-- STEP 1: Rename daily_buff_stats.city_hex → district_hex
-- ============================================================================

ALTER TABLE public.daily_buff_stats
  RENAME COLUMN city_hex TO district_hex;

-- ============================================================================
-- STEP 2: Rewrite finalize_run — rename p_hex_city_parents → p_hex_district_parents
-- ============================================================================

-- Drop the current 13-param version added in 20260306000001
DROP FUNCTION IF EXISTS public.finalize_run(
  UUID, TIMESTAMPTZ, TIMESTAMPTZ, DOUBLE PRECISION, INTEGER,
  TEXT[], INTEGER, DOUBLE PRECISION, INTEGER, INTEGER, TEXT[], TEXT, TEXT[]
);

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
  p_hex_parents TEXT[] DEFAULT NULL,       -- Res-5 province parent per hex
  p_district_hex TEXT DEFAULT NULL,        -- User's Res-6 district
  p_hex_district_parents TEXT[] DEFAULT NULL   -- Res-6 district parent per hex
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_team TEXT;
  v_hex_id TEXT;
  v_points INTEGER;
  v_max_allowed_points INTEGER;
  v_flip_count INTEGER;
  v_current_flipped_at TIMESTAMPTZ;
  v_parent_hex TEXT;
  v_district_parent_hex TEXT;
  v_idx INTEGER;
  v_run_history_id UUID;
  v_server_buff JSONB;
  v_validated_multiplier INTEGER;
BEGIN
  -- Get user's team
  SELECT team INTO v_team FROM public.users WHERE id = p_user_id;

  IF v_team IS NULL THEN
    RAISE EXCEPTION 'User not found or has no team assigned';
  END IF;

  -- Server-side buff validation: client cannot claim higher than server allows
  v_server_buff := public.get_user_buff(p_user_id, p_district_hex);
  v_validated_multiplier := GREATEST((v_server_buff->>'multiplier')::INTEGER, 1);

  -- Use lower of client and server multiplier (anti-cheat)
  IF p_buff_multiplier < v_validated_multiplier THEN
    v_validated_multiplier := p_buff_multiplier;
  END IF;

  -- [SECURITY] Cap validation: client points ≤ hex_path_length × validated_multiplier
  v_max_allowed_points := COALESCE(array_length(p_hex_path, 1), 0) * v_validated_multiplier;
  v_points := LEAST(COALESCE(p_client_points, 0), v_max_allowed_points);
  v_flip_count := CASE
    WHEN v_validated_multiplier > 0 THEN v_points / v_validated_multiplier
    ELSE 0
  END;

  IF p_client_points > v_max_allowed_points THEN
    RAISE WARNING 'Client claimed % points but max allowed is %. Capped.',
      p_client_points, v_max_allowed_points;
  END IF;

  -- Update live hexes table (for buff/dominance calculations only)
  -- hex_snapshot is immutable until midnight build
  IF p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0 THEN
    v_idx := 1;
    FOREACH v_hex_id IN ARRAY p_hex_path LOOP
      v_parent_hex := NULL;
      v_district_parent_hex := NULL;

      IF p_hex_parents IS NOT NULL AND v_idx <= array_length(p_hex_parents, 1) THEN
        v_parent_hex := p_hex_parents[v_idx];
      END IF;

      -- Populate district_hex (Res-6) from p_hex_district_parents if provided
      IF p_hex_district_parents IS NOT NULL AND v_idx <= array_length(p_hex_district_parents, 1) THEN
        v_district_parent_hex := p_hex_district_parents[v_idx];
      END IF;

      SELECT last_flipped_at INTO v_current_flipped_at
      FROM public.hexes WHERE id = v_hex_id;

      IF v_current_flipped_at IS NULL OR p_end_time > v_current_flipped_at THEN
        INSERT INTO public.hexes (id, last_runner_team, last_flipped_at, parent_hex, district_hex)
        VALUES (v_hex_id, v_team, p_end_time, v_parent_hex, v_district_parent_hex)
        ON CONFLICT (id) DO UPDATE
        SET last_runner_team = v_team,
            last_flipped_at = p_end_time,
            parent_hex = COALESCE(EXCLUDED.parent_hex, public.hexes.parent_hex),
            district_hex = COALESCE(EXCLUDED.district_hex, public.hexes.district_hex)
        WHERE public.hexes.last_flipped_at IS NULL
           OR public.hexes.last_flipped_at < p_end_time;
      END IF;

      v_idx := v_idx + 1;
    END LOOP;
  END IF;

  -- Update user stats (season_points, distance, pace, cv, home hexes, district)
  UPDATE public.users SET
    season_points = season_points + v_points,
    home_hex = CASE
      WHEN home_hex IS NULL AND p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0
      THEN p_hex_path[1]
      ELSE home_hex
    END,
    home_hex_end = CASE
      WHEN p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0
      THEN p_hex_path[array_length(p_hex_path, 1)]
      ELSE home_hex_end
    END,
    season_home_hex = CASE
      WHEN season_home_hex IS NULL AND p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0
      THEN p_hex_path[1]
      ELSE season_home_hex
    END,
    district_hex = COALESCE(p_district_hex, district_hex),
    total_distance_km = total_distance_km + p_distance_km,
    total_runs = total_runs + 1,
    avg_pace_min_per_km = CASE
      WHEN p_distance_km > 0 THEN
        (COALESCE(avg_pace_min_per_km, 0) * total_runs
         + (p_duration_seconds / 60.0) / p_distance_km)
        / (total_runs + 1)
      ELSE avg_pace_min_per_km
    END,
    avg_cv = CASE
      WHEN p_cv IS NOT NULL THEN
        (COALESCE(avg_cv, 0) * cv_run_count + p_cv) / (cv_run_count + 1)
      ELSE avg_cv
    END,
    cv_run_count = CASE
      WHEN p_cv IS NOT NULL THEN cv_run_count + 1
      ELSE cv_run_count
    END
  WHERE id = p_user_id;

  -- Insert run history (preserved across seasons)
  INSERT INTO public.run_history (
    user_id, run_date, start_time, end_time,
    distance_km, duration_seconds, avg_pace_min_per_km,
    flip_count, flip_points, team_at_run, cv
  ) VALUES (
    p_user_id,
    (p_end_time AT TIME ZONE 'Etc/GMT-2')::DATE,
    p_start_time, p_end_time,
    p_distance_km, p_duration_seconds,
    CASE WHEN p_distance_km > 0
      THEN (p_duration_seconds / 60.0) / p_distance_km
      ELSE NULL
    END,
    v_flip_count, v_points, v_team, p_cv
  )
  RETURNING id INTO v_run_history_id;

  RETURN jsonb_build_object(
    'run_id', v_run_history_id,
    'flips', v_flip_count,
    'hex_count', COALESCE(array_length(p_hex_path, 1), 0),
    'multiplier', v_validated_multiplier,
    'points_earned', v_points,
    'server_validated', TRUE,
    'total_season_points', (SELECT season_points FROM public.users WHERE id = p_user_id)
  );
END;
$$;

-- ============================================================================
-- STEP 3: Rewrite get_user_buff
--   - WHERE city_hex = v_district_hex → WHERE district_hex = v_district_hex
--   - JSON key 'all_range_bonus' → 'province_range_bonus'
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_buff(
  p_user_id UUID,
  p_district_hex TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_district_hex TEXT;
  v_buff_stats RECORD;
  v_is_elite BOOLEAN := false;
  v_district_win BOOLEAN := false;
  v_province_win BOOLEAN := false;
  v_multiplier INTEGER := 1;
  v_base_buff INTEGER := 1;
  v_district_bonus INTEGER := 0;
  v_province_bonus INTEGER := 0;
  v_reason TEXT := 'Default';
  v_today_gmt2 DATE;
  v_yesterday DATE;
  v_red_runner_count INTEGER;
  v_elite_cutoff_rank INTEGER;
  v_elite_threshold INTEGER := 0;
  v_user_yesterday_points INTEGER := 0;
  v_province_leading_team TEXT;
BEGIN
  -- Consistent GMT+2 dates (must match calculate_daily_buffs and get_team_rankings)
  v_today_gmt2 := (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE;
  v_yesterday := v_today_gmt2 - INTERVAL '1 day';

  -- Get user info
  SELECT team, district_hex INTO v_user
  FROM public.users WHERE id = p_user_id;

  -- Use client-provided district_hex as fallback
  v_district_hex := COALESCE(v_user.district_hex, p_district_hex);

  IF v_user IS NULL OR v_district_hex IS NULL THEN
    RETURN jsonb_build_object(
      'multiplier', 1, 'base_buff', 1,
      'province_range_bonus', 0, 'district_bonus', 0, 'province_bonus', 0,
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

  -- ----------------------------------------------------------------
  -- District Win: from daily_buff_stats (precomputed) or live hexes
  -- ----------------------------------------------------------------
  SELECT * INTO v_buff_stats
  FROM public.daily_buff_stats
  WHERE district_hex = v_district_hex
    AND stat_date = v_today_gmt2
  LIMIT 1;

  IF v_buff_stats IS NOT NULL THEN
    v_district_win := (v_buff_stats.dominant_team = v_user.team);
  ELSE
    -- Fallback: compute from live hexes table.
    -- Query by district_hex (Res-6) column (correct Res-6 filter)
    SELECT (
      CASE v_user.team
        WHEN 'red' THEN COUNT(CASE WHEN last_runner_team = 'red' THEN 1 END)
        WHEN 'blue' THEN COUNT(CASE WHEN last_runner_team = 'blue' THEN 1 END)
        WHEN 'purple' THEN COUNT(CASE WHEN last_runner_team = 'purple' THEN 1 END)
        ELSE 0
      END >
      GREATEST(
        CASE WHEN v_user.team != 'red' THEN COUNT(CASE WHEN last_runner_team = 'red' THEN 1 END) ELSE 0 END,
        CASE WHEN v_user.team != 'blue' THEN COUNT(CASE WHEN last_runner_team = 'blue' THEN 1 END) ELSE 0 END,
        CASE WHEN v_user.team != 'purple' THEN COUNT(CASE WHEN last_runner_team = 'purple' THEN 1 END) ELSE 0 END
      )
    ) INTO v_district_win
    FROM public.hexes
    WHERE district_hex = v_district_hex;
  END IF;

  -- ----------------------------------------------------------------
  -- Province Win: from daily_province_range_stats or daily_all_range_stats
  -- Per §2.3.4: Purple gets NO province bonus
  -- ----------------------------------------------------------------
  IF v_user.team != 'purple' THEN
    -- Try province stats first (has leading_team)
    SELECT leading_team INTO v_province_leading_team
    FROM public.daily_province_range_stats
    WHERE date = v_today_gmt2
    LIMIT 1;

    IF v_province_leading_team IS NOT NULL THEN
      v_province_win := (v_province_leading_team = v_user.team);
    ELSE
      -- Fallback: compute from daily_all_range_stats
      SELECT dominant_team INTO v_province_leading_team
      FROM public.daily_all_range_stats
      WHERE stat_date = v_today_gmt2
      LIMIT 1;

      v_province_win := (v_province_leading_team IS NOT NULL
                         AND v_province_leading_team = v_user.team);
    END IF;
  END IF;

  -- ----------------------------------------------------------------
  -- Team-specific buff calculation
  -- ----------------------------------------------------------------
  IF v_user.team = 'red' THEN
    -- RED: Elite = top 20% by yesterday's flip_points in district
    v_is_elite := false;

    SELECT COUNT(DISTINCT rh.user_id) INTO v_red_runner_count
    FROM public.run_history rh
    JOIN public.users u ON u.id = rh.user_id
    WHERE u.team = 'red'
      AND (v_district_hex IS NULL OR u.district_hex = v_district_hex)
      AND rh.run_date = v_yesterday;

    IF v_red_runner_count > 0 THEN
      v_elite_cutoff_rank := GREATEST(1, (v_red_runner_count * 0.2)::INTEGER);

      -- Elite threshold: points at the cutoff rank
      SELECT COALESCE(sub.total_points, 0) INTO v_elite_threshold
      FROM (
        SELECT
          rh.user_id,
          SUM(rh.flip_points) AS total_points,
          ROW_NUMBER() OVER (ORDER BY SUM(rh.flip_points) DESC) AS rn
        FROM public.run_history rh
        JOIN public.users u ON u.id = rh.user_id
        WHERE u.team = 'red'
          AND (v_district_hex IS NULL OR u.district_hex = v_district_hex)
          AND rh.run_date = v_yesterday
        GROUP BY rh.user_id
      ) sub
      WHERE sub.rn = v_elite_cutoff_rank;

      v_elite_threshold := COALESCE(v_elite_threshold, 0);

      -- User's yesterday total points
      SELECT COALESCE(SUM(rh.flip_points), 0) INTO v_user_yesterday_points
      FROM public.run_history rh
      WHERE rh.user_id = p_user_id
        AND rh.run_date = v_yesterday;

      v_is_elite := (v_user_yesterday_points >= v_elite_threshold
                     AND v_user_yesterday_points > 0);
    END IF;

    -- RED buff matrix (per DEVELOPMENT_SPEC §2.3.2):
    -- Elite base=2x, +1 district win, +1 province win → max 4x
    -- Common base=1x, +0 district win, +1 province win → max 2x
    v_base_buff := CASE WHEN v_is_elite THEN 2 ELSE 1 END;
    v_district_bonus := CASE
      WHEN v_is_elite AND v_district_win THEN 1
      ELSE 0
    END;
    v_province_bonus := CASE WHEN v_province_win THEN 1 ELSE 0 END;
    v_multiplier := v_base_buff + v_district_bonus + v_province_bonus;
    v_reason := CASE WHEN v_is_elite THEN 'Elite' ELSE 'Common' END;

  ELSIF v_user.team = 'blue' THEN
    -- BLUE buff matrix (per DEVELOPMENT_SPEC §2.3.3):
    -- Base=1x, +1 district win, +1 province win → max 3x
    v_base_buff := 1;
    v_district_bonus := CASE WHEN v_district_win THEN 1 ELSE 0 END;
    v_province_bonus := CASE WHEN v_province_win THEN 1 ELSE 0 END;
    v_multiplier := v_base_buff + v_district_bonus + v_province_bonus;
    v_reason := 'Union';

  ELSIF v_user.team = 'purple' THEN
    -- PURPLE buff (per DEVELOPMENT_SPEC §2.3.4):
    -- Participation rate: ≥60%→3x, ≥30%→2x, <30%→1x
    -- NO province bonus
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
    'province_range_bonus', v_province_bonus,
    'district_bonus', v_district_bonus,
    'province_bonus', v_province_bonus,
    'reason', v_reason,
    'team', v_user.team,
    'district_hex', v_district_hex,
    'is_elite', v_is_elite,
    'has_district_win', v_district_win,
    'has_province_win', v_province_win,
    'elite_threshold', COALESCE(v_elite_threshold, 0),
    'yesterday_points', COALESCE(v_user_yesterday_points, 0)
  );
END;
$$;

-- ============================================================================
-- STEP 4: Rewrite calculate_daily_buffs
--   - v_city_hex → v_district_hex
--   - v_all_range_* → v_province_range_*
--   - v_cities_processed → v_districts_processed
--   - INSERT district_hex (renamed column)
--   - JSON key 'cities_processed' → 'districts_processed'
-- ============================================================================

CREATE OR REPLACE FUNCTION public.calculate_daily_buffs()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_today_gmt2 DATE;
  v_yesterday DATE;
  v_district_hex TEXT;
  v_hex_counts RECORD;
  v_dominant TEXT;
  v_elite_threshold INTEGER;
  v_purple_total INTEGER;
  v_purple_active INTEGER;
  v_province_range_red INTEGER := 0;
  v_province_range_blue INTEGER := 0;
  v_province_range_purple INTEGER := 0;
  v_districts_processed INTEGER := 0;
BEGIN
  -- Consistent GMT+2 date
  v_today_gmt2 := (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE;
  v_yesterday := v_today_gmt2 - INTERVAL '1 day';

  -- Delete existing stats for today (idempotent)
  DELETE FROM public.daily_buff_stats WHERE stat_date = v_today_gmt2;
  DELETE FROM public.daily_all_range_stats WHERE stat_date = v_today_gmt2;

  -- Step 1: Server-wide (Province) hex counts — no resolution issue here (no district filter)
  SELECT
    COALESCE(SUM(CASE WHEN h.last_runner_team = 'red' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN h.last_runner_team = 'blue' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN h.last_runner_team = 'purple' THEN 1 ELSE 0 END), 0)
  INTO v_province_range_red, v_province_range_blue, v_province_range_purple
  FROM public.hexes h
  WHERE h.last_runner_team IS NOT NULL;

  v_dominant := CASE
    WHEN v_province_range_red >= v_province_range_blue
      AND v_province_range_red >= v_province_range_purple THEN 'red'
    WHEN v_province_range_blue >= v_province_range_red
      AND v_province_range_blue >= v_province_range_purple THEN 'blue'
    ELSE 'purple'
  END;

  INSERT INTO public.daily_all_range_stats (
    stat_date, dominant_team, red_hex_count, blue_hex_count, purple_hex_count
  ) VALUES (
    v_today_gmt2, v_dominant, v_province_range_red, v_province_range_blue, v_province_range_purple
  );

  -- Update province stats
  DELETE FROM public.daily_province_range_stats WHERE date = v_today_gmt2;
  INSERT INTO public.daily_province_range_stats (
    date, leading_team, red_hex_count, blue_hex_count
  ) VALUES (
    v_today_gmt2, v_dominant, v_province_range_red, v_province_range_blue
  );

  -- Step 2: Per-district (Res 6) buff stats
  -- Use district_hex from users table (set by finalize_run from client H3)
  FOR v_district_hex IN
    SELECT DISTINCT u.district_hex
    FROM public.users u
    WHERE u.team IS NOT NULL
      AND u.district_hex IS NOT NULL
  LOOP
    -- Query hexes by district_hex (Res-6) column for correct Res-6 filter
    SELECT
      COALESCE(SUM(CASE WHEN h.last_runner_team = 'red' THEN 1 ELSE 0 END), 0) AS red_count,
      COALESCE(SUM(CASE WHEN h.last_runner_team = 'blue' THEN 1 ELSE 0 END), 0) AS blue_count,
      COALESCE(SUM(CASE WHEN h.last_runner_team = 'purple' THEN 1 ELSE 0 END), 0) AS purple_count
    INTO v_hex_counts
    FROM public.hexes h
    WHERE h.last_runner_team IS NOT NULL
      AND h.district_hex = v_district_hex;

    -- District dominant team
    v_dominant := CASE
      WHEN v_hex_counts.red_count >= v_hex_counts.blue_count
        AND v_hex_counts.red_count >= v_hex_counts.purple_count THEN 'red'
      WHEN v_hex_counts.blue_count >= v_hex_counts.red_count
        AND v_hex_counts.blue_count >= v_hex_counts.purple_count THEN 'blue'
      ELSE 'purple'
    END;

    -- RED Elite threshold: top 20% flip_points from yesterday in district
    SELECT COALESCE(
      PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY sub.total_points),
      0
    )::INTEGER
    INTO v_elite_threshold
    FROM (
      SELECT SUM(rh.flip_points) AS total_points
      FROM public.run_history rh
      JOIN public.users u ON rh.user_id = u.id
      WHERE rh.run_date = v_yesterday
        AND u.team = 'red'
        AND u.district_hex = v_district_hex
      GROUP BY rh.user_id
    ) sub;

    -- PURPLE participation rate in district
    SELECT COUNT(*) INTO v_purple_total
    FROM public.users u
    WHERE u.team = 'purple'
      AND u.district_hex = v_district_hex;

    SELECT COUNT(DISTINCT rh.user_id) INTO v_purple_active
    FROM public.run_history rh
    JOIN public.users u ON rh.user_id = u.id
    WHERE rh.run_date = v_yesterday
      AND u.team = 'purple'
      AND u.district_hex = v_district_hex;

    INSERT INTO public.daily_buff_stats (
      stat_date, district_hex, dominant_team,
      red_hex_count, blue_hex_count, purple_hex_count,
      red_elite_threshold_points,
      purple_total_users, purple_active_users, purple_participation_rate
    ) VALUES (
      v_today_gmt2, v_district_hex, v_dominant,
      v_hex_counts.red_count, v_hex_counts.blue_count, v_hex_counts.purple_count,
      v_elite_threshold,
      v_purple_total, v_purple_active,
      CASE WHEN v_purple_total > 0
        THEN v_purple_active::DOUBLE PRECISION / v_purple_total
        ELSE 0
      END
    );

    v_districts_processed := v_districts_processed + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'stat_date', v_today_gmt2,
    'districts_processed', v_districts_processed,
    'province_range_dominant', v_dominant
  );
END;
$$;

-- ============================================================================
-- STEP 5: Rewrite get_team_rankings
--   - p_city_hex → p_district_hex
--   - v_city_hex → v_district_hex
--   - JSON key 'city_hex' → 'district_hex'
--   - JSON key 'red_runner_count_city' → 'red_runner_count_district'
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_team_rankings(
  p_user_id UUID,
  p_district_hex TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_user RECORD;
  v_district_hex TEXT;
  v_yesterday DATE;
  v_red_runner_count INTEGER := 0;
  v_elite_cutoff_rank INTEGER := 0;
  v_elite_threshold INTEGER := 0;
  v_user_yesterday_points INTEGER := 0;
  v_user_rank INTEGER := 0;
  v_user_is_elite BOOLEAN := false;
  v_elite_top3 jsonb := '[]'::jsonb;
BEGIN
  -- Get user info
  SELECT team, district_hex INTO v_user
  FROM public.users WHERE id = p_user_id;

  -- Use provided district_hex or user's district_hex
  v_district_hex := COALESCE(p_district_hex, v_user.district_hex);

  -- Yesterday in server timezone (GMT+2)
  v_yesterday := (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE - INTERVAL '1 day';

  -- Count RED runners who ran yesterday in this district
  SELECT COUNT(DISTINCT rh.user_id) INTO v_red_runner_count
  FROM public.run_history rh
  JOIN public.users u ON u.id = rh.user_id
  WHERE u.team = 'red'
    AND rh.run_date = v_yesterday
    AND (v_district_hex IS NULL OR u.district_hex = v_district_hex);

  -- Elite cutoff = top 20% (at least 1)
  v_elite_cutoff_rank := GREATEST(1, (v_red_runner_count * 0.2)::INTEGER);

  IF v_red_runner_count > 0 THEN
    -- Build ranked list of RED runners by yesterday's total flip_points in district
    -- Then extract elite threshold, user rank, and top 3

    -- Get elite threshold (the flip_points at the cutoff rank)
    SELECT COALESCE(sub.total_points, 0) INTO v_elite_threshold
    FROM (
      SELECT
        rh.user_id,
        SUM(rh.flip_points) AS total_points,
        ROW_NUMBER() OVER (ORDER BY SUM(rh.flip_points) DESC) AS rn
      FROM public.run_history rh
      JOIN public.users u ON u.id = rh.user_id
      WHERE u.team = 'red'
        AND rh.run_date = v_yesterday
        AND (v_district_hex IS NULL OR u.district_hex = v_district_hex)
      GROUP BY rh.user_id
    ) sub
    WHERE sub.rn = v_elite_cutoff_rank;

    v_elite_threshold := COALESCE(v_elite_threshold, 0);

    -- Get user's yesterday points and rank
    SELECT sub.total_points, sub.rn INTO v_user_yesterday_points, v_user_rank
    FROM (
      SELECT
        rh.user_id,
        SUM(rh.flip_points) AS total_points,
        ROW_NUMBER() OVER (ORDER BY SUM(rh.flip_points) DESC) AS rn
      FROM public.run_history rh
      JOIN public.users u ON u.id = rh.user_id
      WHERE u.team = 'red'
        AND rh.run_date = v_yesterday
        AND (v_district_hex IS NULL OR u.district_hex = v_district_hex)
      GROUP BY rh.user_id
    ) sub
    WHERE sub.user_id = p_user_id;

    v_user_yesterday_points := COALESCE(v_user_yesterday_points, 0);
    v_user_rank := COALESCE(v_user_rank, 0);

    -- User is elite if they have points >= threshold AND actually ran
    v_user_is_elite := (v_user_yesterday_points >= v_elite_threshold
                        AND v_user_yesterday_points > 0
                        AND v_user_rank > 0);

    -- Build elite top 3 (runners at or above elite threshold)
    SELECT COALESCE(jsonb_agg(row_to_json(sub)::jsonb), '[]'::jsonb)
    INTO v_elite_top3
    FROM (
      SELECT
        rh.user_id,
        u.name,
        SUM(rh.flip_points)::INTEGER AS yesterday_points,
        ROW_NUMBER() OVER (ORDER BY SUM(rh.flip_points) DESC)::INTEGER AS rank
      FROM public.run_history rh
      JOIN public.users u ON u.id = rh.user_id
      WHERE u.team = 'red'
        AND rh.run_date = v_yesterday
        AND (v_district_hex IS NULL OR u.district_hex = v_district_hex)
      GROUP BY rh.user_id, u.name
      HAVING SUM(rh.flip_points) >= v_elite_threshold
      ORDER BY SUM(rh.flip_points) DESC
      LIMIT 3
    ) sub;
  END IF;

  RETURN jsonb_build_object(
    'user_team', COALESCE(v_user.team, ''),
    'user_is_elite', v_user_is_elite,
    'user_yesterday_points', v_user_yesterday_points,
    'user_rank', CASE WHEN v_user_rank > 0 THEN v_user_rank ELSE 0 END,
    'elite_threshold', v_elite_threshold,
    'district_hex', v_district_hex,
    'red_elite_top3', v_elite_top3,
    'red_runner_count_district', v_red_runner_count,
    'elite_cutoff_rank', v_elite_cutoff_rank
  );
END;
$$;
