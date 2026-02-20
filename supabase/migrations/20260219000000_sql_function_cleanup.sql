-- ============================================================================
-- COMPREHENSIVE SQL FUNCTION CLEANUP
-- ============================================================================
-- Audit findings and fixes:
--
-- 1. app_launch_sync: 3 conflicting overloads → consolidate to 1
--    - V1 (6-param): Dead code, references unused viewport params, does
--      expensive self-heal + hex dump, references home_hex_start
--    - V2 (1-param): Doesn't pass district_hex → buff always 1x
--    - V3 (2-param): Correct but V2 intercepts uuid-only calls
--    FIX: Drop V1 and V2, keep V3
--
-- 2. finalize_run: 2 conflicting overloads → consolidate to 1
--    - V1 (11-param): Has SECURITY DEFINER + server buff validation but
--      no district_hex param
--    - V2 (12-param): Has district_hex but MISSING SECURITY DEFINER,
--      MISSING server buff validation, MISSING home_hex/season_home_hex
--    FIX: Drop V1, rewrite V2 with all security features
--
-- 3. get_user_buff: Date mismatch
--    - Used CURRENT_DATE (UTC) for daily_buff_stats lookup
--    - But calculate_daily_buffs writes stat_date in GMT+2
--    - After 22:00 UTC, lookup fails silently for 2 hours daily
--    FIX: Use GMT+2 date consistently
--
-- 4. get_user_buff: Province win check
--    - Had EXCEPTION handler for undefined_table (unnecessary)
--    - daily_province_range_stats uses 'date' column
--    FIX: Use GMT+2 date, remove unnecessary exception handler
--
-- 5. calculate_daily_buffs: Unreliable H3 approximation
--    - Used substring(home_hex_end, 1, 10) as Res 6 parent (wrong)
--    - H3 IDs are not simple string prefixes
--    FIX: Use users.district_hex (set by finalize_run from client H3)
--
-- 6. RED province bonus logic: DEVELOPMENT_SPEC says Common gets +1x
--    for province win, but get_user_buff already implements this correctly
--    (v_province_bonus applies to both Elite and Common). Verified OK.
-- ============================================================================

-- ============================================================================
-- STEP 1: Drop stale app_launch_sync overloads
-- ============================================================================

-- V1: 6-param version (dead code from early development)
DROP FUNCTION IF EXISTS public.app_launch_sync(
  UUID, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER
);

-- V2: 1-param version (superseded by 2-param with district_hex)
DROP FUNCTION IF EXISTS public.app_launch_sync(UUID);

-- ============================================================================
-- STEP 2: Clean app_launch_sync (single version)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.app_launch_sync(
  p_user_id UUID,
  p_district_hex TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_user_stats jsonb;
  v_user_buff jsonb;
BEGIN
  -- Get user stats from users table
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

  -- Delegate buff calculation (passes district_hex for NULL-district users)
  v_user_buff := public.get_user_buff(p_user_id, p_district_hex);

  RETURN jsonb_build_object(
    'user_stats', COALESCE(v_user_stats, '{}'::jsonb),
    'user_buff', COALESCE(v_user_buff, jsonb_build_object('multiplier', 1))
  );
END;
$$;

-- ============================================================================
-- STEP 3: Drop stale finalize_run overload
-- ============================================================================

-- V1: 11-param version (no district_hex, old security model)
DROP FUNCTION IF EXISTS public.finalize_run(
  UUID, TIMESTAMPTZ, TIMESTAMPTZ, DOUBLE PRECISION, INTEGER,
  TEXT[], INTEGER, DOUBLE PRECISION, INTEGER, INTEGER, TEXT[]
);

-- ============================================================================
-- STEP 4: Clean finalize_run (single version with all security features)
-- ============================================================================

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
      IF p_hex_parents IS NOT NULL AND v_idx <= array_length(p_hex_parents, 1) THEN
        v_parent_hex := p_hex_parents[v_idx];
      END IF;

      SELECT last_flipped_at INTO v_current_flipped_at
      FROM public.hexes WHERE id = v_hex_id;

      IF v_current_flipped_at IS NULL OR p_end_time > v_current_flipped_at THEN
        INSERT INTO public.hexes (id, last_runner_team, last_flipped_at, parent_hex)
        VALUES (v_hex_id, v_team, p_end_time, v_parent_hex)
        ON CONFLICT (id) DO UPDATE
        SET last_runner_team = v_team,
            last_flipped_at = p_end_time,
            parent_hex = COALESCE(EXCLUDED.parent_hex, public.hexes.parent_hex)
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
-- STEP 5: Fix get_user_buff (date consistency + cleanup)
-- ============================================================================

-- Drop old 1-param overload if it still exists
DROP FUNCTION IF EXISTS public.get_user_buff(UUID);

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

  -- ----------------------------------------------------------------
  -- District Win: from daily_buff_stats (precomputed) or live hexes
  -- ----------------------------------------------------------------
  SELECT * INTO v_buff_stats
  FROM public.daily_buff_stats
  WHERE city_hex = v_district_hex
    AND stat_date = v_today_gmt2  -- FIX: was CURRENT_DATE (UTC mismatch)
  LIMIT 1;

  IF v_buff_stats IS NOT NULL THEN
    v_district_win := (v_buff_stats.dominant_team = v_user.team);
  ELSE
    -- Fallback: compute from live hexes table
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
    WHERE parent_hex = v_district_hex;
  END IF;

  -- ----------------------------------------------------------------
  -- Province Win: from daily_province_range_stats or daily_all_range_stats
  -- Per §2.3.4: Purple gets NO province bonus
  -- ----------------------------------------------------------------
  IF v_user.team != 'purple' THEN
    -- Try province stats first (has leading_team)
    SELECT leading_team INTO v_province_leading_team
    FROM public.daily_province_range_stats
    WHERE date = v_today_gmt2  -- FIX: was CURRENT_DATE (UTC mismatch)
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
    'all_range_bonus', v_province_bonus,
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
-- STEP 6: Fix calculate_daily_buffs (use district_hex, not substring hack)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.calculate_daily_buffs()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_today_gmt2 DATE;
  v_yesterday DATE;
  v_city_hex TEXT;
  v_hex_counts RECORD;
  v_dominant TEXT;
  v_elite_threshold INTEGER;
  v_purple_total INTEGER;
  v_purple_active INTEGER;
  v_all_range_red INTEGER := 0;
  v_all_range_blue INTEGER := 0;
  v_all_range_purple INTEGER := 0;
  v_cities_processed INTEGER := 0;
BEGIN
  -- Consistent GMT+2 date
  v_today_gmt2 := (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE;
  v_yesterday := v_today_gmt2 - INTERVAL '1 day';

  -- Delete existing stats for today (idempotent)
  DELETE FROM public.daily_buff_stats WHERE stat_date = v_today_gmt2;
  DELETE FROM public.daily_all_range_stats WHERE stat_date = v_today_gmt2;

  -- Step 1: Server-wide (Province) hex counts
  SELECT
    COALESCE(SUM(CASE WHEN h.last_runner_team = 'red' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN h.last_runner_team = 'blue' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN h.last_runner_team = 'purple' THEN 1 ELSE 0 END), 0)
  INTO v_all_range_red, v_all_range_blue, v_all_range_purple
  FROM public.hexes h
  WHERE h.last_runner_team IS NOT NULL;

  v_dominant := CASE
    WHEN v_all_range_red >= v_all_range_blue
      AND v_all_range_red >= v_all_range_purple THEN 'red'
    WHEN v_all_range_blue >= v_all_range_red
      AND v_all_range_blue >= v_all_range_purple THEN 'blue'
    ELSE 'purple'
  END;

  INSERT INTO public.daily_all_range_stats (
    stat_date, dominant_team, red_hex_count, blue_hex_count, purple_hex_count
  ) VALUES (
    v_today_gmt2, v_dominant, v_all_range_red, v_all_range_blue, v_all_range_purple
  );

  -- Update province stats
  DELETE FROM public.daily_province_range_stats WHERE date = v_today_gmt2;
  INSERT INTO public.daily_province_range_stats (
    date, leading_team, red_hex_count, blue_hex_count
  ) VALUES (
    v_today_gmt2, v_dominant, v_all_range_red, v_all_range_blue
  );

  -- Step 2: Per-district (Res 6) buff stats
  -- Use district_hex from users table (set by finalize_run from client H3)
  FOR v_city_hex IN
    SELECT DISTINCT u.district_hex
    FROM public.users u
    WHERE u.team IS NOT NULL
      AND u.district_hex IS NOT NULL
  LOOP
    -- Count hexes per team in this district
    SELECT
      COALESCE(SUM(CASE WHEN h.last_runner_team = 'red' THEN 1 ELSE 0 END), 0) AS red_count,
      COALESCE(SUM(CASE WHEN h.last_runner_team = 'blue' THEN 1 ELSE 0 END), 0) AS blue_count,
      COALESCE(SUM(CASE WHEN h.last_runner_team = 'purple' THEN 1 ELSE 0 END), 0) AS purple_count
    INTO v_hex_counts
    FROM public.hexes h
    WHERE h.last_runner_team IS NOT NULL
      AND h.parent_hex = v_city_hex;

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
        AND u.district_hex = v_city_hex
      GROUP BY rh.user_id
    ) sub;

    -- PURPLE participation rate in district
    SELECT COUNT(*) INTO v_purple_total
    FROM public.users u
    WHERE u.team = 'purple'
      AND u.district_hex = v_city_hex;

    SELECT COUNT(DISTINCT rh.user_id) INTO v_purple_active
    FROM public.run_history rh
    JOIN public.users u ON rh.user_id = u.id
    WHERE rh.run_date = v_yesterday
      AND u.team = 'purple'
      AND u.district_hex = v_city_hex;

    INSERT INTO public.daily_buff_stats (
      stat_date, city_hex, dominant_team,
      red_hex_count, blue_hex_count, purple_hex_count,
      red_elite_threshold_points,
      purple_total_users, purple_active_users, purple_participation_rate
    ) VALUES (
      v_today_gmt2, v_city_hex, v_dominant,
      v_hex_counts.red_count, v_hex_counts.blue_count, v_hex_counts.purple_count,
      v_elite_threshold,
      v_purple_total, v_purple_active,
      CASE WHEN v_purple_total > 0
        THEN v_purple_active::DOUBLE PRECISION / v_purple_total
        ELSE 0
      END
    );

    v_cities_processed := v_cities_processed + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'stat_date', v_today_gmt2,
    'cities_processed', v_cities_processed,
    'all_range_dominant', v_dominant
  );
END;
$$;
