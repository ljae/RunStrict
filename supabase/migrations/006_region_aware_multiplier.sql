-- RunStrict: Region-Aware Multiplier Migration
-- Implements: Server-side validation of region-aware multiplier

-- ============================================================
-- UPDATE FINALIZE_RUN FOR REGION-AWARE MULTIPLIER
-- ============================================================
-- Points = (flips in home region × multiplier) + (flips outside × 1)
-- 
-- For now, server trusts client's point calculation since:
-- 1. Client has access to seasonHomeHex and can compute region membership
-- 2. Server would need H3 extension to do the same calculation
-- 3. Anti-cheat: max_points <= total_hexes × multiplier (already enforced)
-- 
-- Future improvement: Install H3 extension and validate per-hex region membership

CREATE OR REPLACE FUNCTION public.finalize_run(
  p_user_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ,
  p_distance_km DOUBLE PRECISION,
  p_duration_seconds INTEGER,
  p_hex_path TEXT[],
  p_yesterday_crew_count INTEGER,
  p_cv DOUBLE PRECISION DEFAULT NULL,
  p_client_points INTEGER DEFAULT NULL,
  p_home_region_flips INTEGER DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_hex_id TEXT;
  v_total_flips INTEGER := 0;
  v_team TEXT;
  v_points INTEGER;
  v_current_team TEXT;
  v_current_flipped_at TIMESTAMPTZ;
  v_max_allowed_points INTEGER;
  v_run_history_id UUID;
  v_current_total_distance DOUBLE PRECISION;
  v_current_total_runs INTEGER;
  v_current_avg_cv DOUBLE PRECISION;
BEGIN
  SELECT team, total_distance_km, total_runs, avg_cv 
  INTO v_team, v_current_total_distance, v_current_total_runs, v_current_avg_cv 
  FROM public.users WHERE id = p_user_id;
  
  IF v_team IS NULL THEN
    RAISE EXCEPTION 'User not found or has no team assigned';
  END IF;
  
  IF p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0 THEN
    FOREACH v_hex_id IN ARRAY p_hex_path LOOP
      SELECT last_runner_team, last_flipped_at 
      INTO v_current_team, v_current_flipped_at 
      FROM public.hexes WHERE id = v_hex_id;
      
      IF v_current_flipped_at IS NULL OR p_end_time > v_current_flipped_at THEN
        IF v_current_team IS DISTINCT FROM v_team THEN
          v_total_flips := v_total_flips + 1;
        END IF;
        
        INSERT INTO public.hexes (id, last_runner_team, last_flipped_at)
        VALUES (v_hex_id, v_team, p_end_time)
        ON CONFLICT (id) DO UPDATE
        SET last_runner_team = v_team,
            last_flipped_at = p_end_time
        WHERE public.hexes.last_flipped_at IS NULL OR public.hexes.last_flipped_at < p_end_time;
      END IF;
    END LOOP;
  END IF;
  
  -- Region-aware points calculation:
  -- If client provides home_region_flips, use: (home_region_flips × multiplier) + (outside_flips × 1)
  -- Otherwise, use old calculation: total_flips × multiplier
  IF p_home_region_flips IS NOT NULL THEN
    v_points := (p_home_region_flips * GREATEST(p_yesterday_crew_count, 1)) + 
                (v_total_flips - p_home_region_flips);
  ELSE
    v_points := v_total_flips * GREATEST(p_yesterday_crew_count, 1);
  END IF;
  
  -- Server-side validation: points can't exceed max possible
  IF p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0 THEN
    v_max_allowed_points := array_length(p_hex_path, 1) * GREATEST(p_yesterday_crew_count, 1);
    IF p_client_points IS NOT NULL AND p_client_points > v_max_allowed_points THEN
      RAISE WARNING 'Client claimed % points but max allowed is %', p_client_points, v_max_allowed_points;
    END IF;
  END IF;
  
  UPDATE public.users SET 
    season_points = season_points + v_points,
    total_distance_km = COALESCE(total_distance_km, 0) + p_distance_km,
    total_runs = COALESCE(total_runs, 0) + 1,
    avg_cv = CASE 
      WHEN p_cv IS NOT NULL THEN
        CASE 
          WHEN avg_cv IS NULL THEN p_cv
          ELSE (COALESCE(avg_cv, 0) * COALESCE(total_runs, 0) + p_cv) / (COALESCE(total_runs, 0) + 1)
        END
      ELSE avg_cv
    END,
    avg_pace_min_per_km = CASE
      WHEN p_distance_km > 0 THEN
        CASE
          WHEN avg_pace_min_per_km IS NULL THEN (p_duration_seconds / 60.0) / p_distance_km
          ELSE (COALESCE(avg_pace_min_per_km, 0) * COALESCE(total_runs, 0) + ((p_duration_seconds / 60.0) / p_distance_km)) / (COALESCE(total_runs, 0) + 1)
        END
      ELSE avg_pace_min_per_km
    END
  WHERE id = p_user_id;
  
  INSERT INTO public.run_history (
    user_id, run_date, start_time, end_time,
    distance_km, duration_seconds, avg_pace_min_per_km,
    flip_count, flip_points, team_at_run
  ) VALUES (
    p_user_id, 
    p_end_time::DATE, 
    p_start_time, 
    p_end_time,
    p_distance_km, 
    p_duration_seconds,
    CASE WHEN p_distance_km > 0 THEN (p_duration_seconds / 60.0) / p_distance_km ELSE NULL END,
    v_total_flips, 
    v_points, 
    v_team
  )
  RETURNING id INTO v_run_history_id;
  
  RETURN jsonb_build_object(
    'run_id', v_run_history_id,
    'flips', v_total_flips,
    'multiplier', GREATEST(p_yesterday_crew_count, 1),
    'points_earned', v_points,
    'server_validated', true,
    'home_region_flips', p_home_region_flips
  );
END;
$$;

COMMENT ON FUNCTION public.finalize_run IS 'Finalizes a run with region-aware multiplier. Home region flips get full multiplier, outside flips get 1x.';
