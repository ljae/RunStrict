-- ============================================================================
-- HOME LOCATION CONSOLIDATION
-- ============================================================================
-- Problem: finalize_run overwrites district_hex on every run, causing wrong
-- buff calculation when users run in foreign provinces (e.g., Seoul -> Busan).
--
-- Solution:
-- 1. New RPC: update_home_location() - GPS-changeable home via Profile
-- 2. Fix finalize_run: stop overwriting home_hex, home_hex_end,
--    season_home_hex, district_hex
-- 3. Consolidate 4 home hex fields into 2:
--    - home_hex (Res 9): User's declared home, GPS-changeable
--    - district_hex (Res 6): Auto-derived from home_hex
-- ============================================================================

-- ============================================================================
-- STEP 1: New RPC — update_home_location
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_home_location(
  p_user_id UUID,
  p_home_hex TEXT,
  p_district_hex TEXT
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.users
  SET home_hex = p_home_hex,
      district_hex = p_district_hex
  WHERE id = p_user_id;

  RETURN jsonb_build_object(
    'home_hex', p_home_hex,
    'district_hex', p_district_hex,
    'updated', true
  );
END;
$$;

-- ============================================================================
-- STEP 2: Fix finalize_run — stop overwriting home fields
-- ============================================================================
-- Remove: home_hex, home_hex_end, season_home_hex, district_hex updates
-- Keep: season_points, total_distance_km, total_runs, avg_pace, avg_cv

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
  -- Use user's stored district_hex (from home declaration, not from run location)
  v_server_buff := public.get_user_buff(p_user_id, NULL);
  v_validated_multiplier := GREATEST((v_server_buff->>'multiplier')::INTEGER, 1);

  -- Use lower of client and server multiplier (anti-cheat)
  IF p_buff_multiplier < v_validated_multiplier THEN
    v_validated_multiplier := p_buff_multiplier;
  END IF;

  -- [SECURITY] Cap validation: client points <= hex_path_length x validated_multiplier
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

  -- Update user stats (NO home hex fields — those are set via update_home_location only)
  UPDATE public.users SET
    season_points = season_points + v_points,
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
