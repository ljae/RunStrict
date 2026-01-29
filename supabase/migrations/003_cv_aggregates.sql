-- RunStrict: CV Aggregates Migration
-- Run this in Supabase SQL Editor after 002_rpc_functions.sql
-- Adds CV tracking and user aggregate statistics

-- ============================================================
-- 1. SCHEMA UPDATES (add CV aggregate columns to users)
-- ============================================================

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS total_distance_km DOUBLE PRECISION DEFAULT 0;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS avg_pace_min_per_km DOUBLE PRECISION;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS avg_cv DOUBLE PRECISION;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS total_runs INTEGER DEFAULT 0;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS cv_run_count INTEGER DEFAULT 0;

-- ============================================================
-- 2. ADD CV COLUMN TO RUN_HISTORY
-- ============================================================

ALTER TABLE public.run_history 
ADD COLUMN IF NOT EXISTS cv DOUBLE PRECISION;

-- ============================================================
-- 3. UPDATE FINALIZE_RUN FUNCTION
-- ============================================================
-- Now accepts p_cv parameter and updates user aggregates
-- Uses incremental average formulas to avoid recalculation

CREATE OR REPLACE FUNCTION public.finalize_run(
  p_user_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ,
  p_distance_km DOUBLE PRECISION,
  p_duration_seconds INTEGER,
  p_hex_path TEXT[],
  p_yesterday_crew_count INTEGER,
  p_client_points INTEGER DEFAULT NULL,
  p_cv DOUBLE PRECISION DEFAULT NULL
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
  v_new_total_runs INTEGER;
  v_new_cv_run_count INTEGER;
BEGIN
  -- Get user's team
  SELECT team INTO v_team FROM public.users WHERE id = p_user_id;
  
  IF v_team IS NULL THEN
    RAISE EXCEPTION 'User not found or has no team assigned';
  END IF;
  
  -- Process each hex in the path (NO daily limit - all flips count)
  IF p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0 THEN
    FOREACH v_hex_id IN ARRAY p_hex_path LOOP
      -- Check current hex color and timestamp
      SELECT last_runner_team, last_flipped_at 
      INTO v_current_team, v_current_flipped_at 
      FROM public.hexes WHERE id = v_hex_id;
      
      -- Only update if this run ended LATER than the existing flip
      -- This prevents offline abusing (submitting old runs)
      IF v_current_flipped_at IS NULL OR p_end_time > v_current_flipped_at THEN
        -- Count as flip if color changes (or hex is new/neutral)
        IF v_current_team IS DISTINCT FROM v_team THEN
          v_total_flips := v_total_flips + 1;
        END IF;
        
        -- Update hex color with timestamp (conflict resolution: later run_endTime wins)
        INSERT INTO public.hexes (id, last_runner_team, last_flipped_at)
        VALUES (v_hex_id, v_team, p_end_time)
        ON CONFLICT (id) DO UPDATE
        SET last_runner_team = v_team,
            last_flipped_at = p_end_time
        WHERE public.hexes.last_flipped_at IS NULL OR public.hexes.last_flipped_at < p_end_time;
      END IF;
    END LOOP;
  END IF;
  
  -- Calculate points with multiplier
  v_points := v_total_flips * GREATEST(p_yesterday_crew_count, 1);
  
  -- [SECURITY] Server-side validation: points cannot exceed hex_count × multiplier
  IF p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0 THEN
    v_max_allowed_points := array_length(p_hex_path, 1) * GREATEST(p_yesterday_crew_count, 1);
    IF p_client_points IS NOT NULL AND p_client_points > v_max_allowed_points THEN
      -- Client claimed more points than possible - log warning and use server-calculated
      RAISE WARNING 'Client claimed % points but max allowed is %', p_client_points, v_max_allowed_points;
    END IF;
  END IF;
  
  -- Update user aggregates with incremental formulas
  -- Get current total_runs before update
  SELECT total_runs INTO v_new_total_runs FROM public.users WHERE id = p_user_id;
  v_new_total_runs := COALESCE(v_new_total_runs, 0) + 1;
  
  -- Get current cv_run_count before update
  SELECT cv_run_count INTO v_new_cv_run_count FROM public.users WHERE id = p_user_id;
  v_new_cv_run_count := COALESCE(v_new_cv_run_count, 0);
  
  -- If p_cv is not NULL, increment cv_run_count
  IF p_cv IS NOT NULL THEN
    v_new_cv_run_count := v_new_cv_run_count + 1;
  END IF;
  
  -- Update user with aggregates
  UPDATE public.users SET 
    season_points = season_points + v_points,
    home_hex_start = CASE 
      WHEN p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0 
      THEN p_hex_path[1] 
      ELSE home_hex_start 
    END,
    home_hex_end = CASE 
      WHEN p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0 
      THEN p_hex_path[array_length(p_hex_path, 1)] 
      ELSE home_hex_end 
    END,
    -- Incremental update: total_distance_km
    total_distance_km = total_distance_km + p_distance_km,
    -- Incremental update: total_runs
    total_runs = v_new_total_runs,
    -- Incremental update: avg_pace_min_per_km using formula: new_avg = old_avg + (new_value - old_avg) / new_count
    avg_pace_min_per_km = CASE 
      WHEN p_distance_km > 0 THEN
        COALESCE(avg_pace_min_per_km, 0) + 
        (((p_duration_seconds / 60.0) / p_distance_km) - COALESCE(avg_pace_min_per_km, 0)) / v_new_total_runs
      ELSE avg_pace_min_per_km
    END,
    -- Incremental update: avg_cv (only if p_cv is not NULL)
    avg_cv = CASE 
      WHEN p_cv IS NOT NULL THEN
        (COALESCE(avg_cv, 0) * (v_new_cv_run_count - 1) + p_cv) / v_new_cv_run_count
      ELSE avg_cv
    END,
    -- Track cv_run_count
    cv_run_count = v_new_cv_run_count
  WHERE id = p_user_id;
  
  -- Insert lightweight run history (PRESERVED across seasons)
  INSERT INTO public.run_history (
    user_id, run_date, start_time, end_time,
    distance_km, duration_seconds, avg_pace_min_per_km,
    flip_count, flip_points, team_at_run, cv
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
    v_team,
    p_cv
  )
  RETURNING id INTO v_run_history_id;
  
  -- Return summary
  RETURN jsonb_build_object(
    'run_id', v_run_history_id,
    'flips', v_total_flips,
    'multiplier', GREATEST(p_yesterday_crew_count, 1),
    'points_earned', v_points,
    'server_validated', true
  );
END;
$$;

-- ============================================================
-- 4. UPDATE GET_LEADERBOARD FUNCTION
-- ============================================================
-- Now returns CV aggregate columns

CREATE OR REPLACE FUNCTION public.get_leaderboard(p_limit INTEGER DEFAULT 20)
RETURNS TABLE(
  id UUID,
  name TEXT,
  team TEXT,
  avatar TEXT,
  season_points INTEGER,
  crew_id UUID,
  total_distance_km DOUBLE PRECISION,
  avg_pace_min_per_km DOUBLE PRECISION,
  avg_cv DOUBLE PRECISION,
  total_runs INTEGER,
  rank INTEGER
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT 
    u.id, 
    u.name, 
    u.team, 
    u.avatar, 
    u.season_points, 
    u.crew_id,
    u.total_distance_km,
    u.avg_pace_min_per_km,
    u.avg_cv,
    u.total_runs,
    ROW_NUMBER() OVER (ORDER BY u.season_points DESC)::INTEGER as rank
  FROM public.users u
  WHERE u.season_points > 0
  ORDER BY u.season_points DESC
  LIMIT p_limit;
$$;

-- ============================================================
-- 5. UPDATE APP_LAUNCH_SYNC FUNCTION
-- ============================================================
-- Include new user aggregate fields in response

CREATE OR REPLACE FUNCTION public.app_launch_sync(
  p_user_id UUID,
  p_viewport_min_lng DOUBLE PRECISION DEFAULT NULL,
  p_viewport_min_lat DOUBLE PRECISION DEFAULT NULL,
  p_viewport_max_lng DOUBLE PRECISION DEFAULT NULL,
  p_viewport_max_lat DOUBLE PRECISION DEFAULT NULL,
  p_leaderboard_limit INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_crew RECORD;
  v_yesterday_multiplier INTEGER := 1;
  v_hex_map JSONB := '[]'::JSONB;
  v_leaderboard JSONB := '[]'::JSONB;
  v_crew_info JSONB := NULL;
  v_crew_members JSONB := '[]'::JSONB;
BEGIN
  -- Get user data (including new aggregate columns)
  SELECT u.id, u.name, u.team, u.avatar, u.season_points, u.crew_id,
         u.home_hex_start, u.home_hex_end, u.manifesto,
         u.total_distance_km, u.avg_pace_min_per_km, u.avg_cv, u.total_runs
  INTO v_user
  FROM public.users u
  WHERE u.id = p_user_id;
  
  IF v_user IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'User not found',
      'user_stats', NULL
    );
  END IF;
  
  -- Get crew info and yesterday's multiplier
  IF v_user.crew_id IS NOT NULL THEN
    SELECT c.id, c.name, c.team, c.member_ids, c.representative_image, c.pin
    INTO v_crew
    FROM public.crews c
    WHERE c.id = v_user.crew_id;
    
    IF v_crew IS NOT NULL THEN
      -- Calculate yesterday's check-in count for multiplier
      v_yesterday_multiplier := public.calculate_yesterday_checkins(v_user.crew_id);
      IF v_yesterday_multiplier < 1 THEN
        v_yesterday_multiplier := 1;
      END IF;
      
      -- Get crew member details
      SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'name', m.name,
          'avatar', m.avatar,
          'season_points', m.season_points
        )
      ), '[]'::JSONB)
      INTO v_crew_members
      FROM public.users m
      WHERE m.crew_id = v_crew.id;
      
      v_crew_info := jsonb_build_object(
        'id', v_crew.id,
        'name', v_crew.name,
        'team', v_crew.team,
        'image', v_crew.representative_image,
        'member_count', jsonb_array_length(v_crew.member_ids),
        'members', v_crew_members
      );
    END IF;
  END IF;
  
  -- Get leaderboard (top users by season points with new columns)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', lb.id,
      'name', lb.name,
      'team', lb.team,
      'avatar', lb.avatar,
      'season_points', lb.season_points,
      'total_distance_km', lb.total_distance_km,
      'avg_pace_min_per_km', lb.avg_pace_min_per_km,
      'avg_cv', lb.avg_cv,
      'total_runs', lb.total_runs,
      'rank', lb.rank
    ) ORDER BY lb.rank
  ), '[]'::JSONB)
  INTO v_leaderboard
  FROM (
    SELECT u.id, u.name, u.team, u.avatar, u.season_points,
           u.total_distance_km, u.avg_pace_min_per_km, u.avg_cv, u.total_runs,
           ROW_NUMBER() OVER (ORDER BY u.season_points DESC) as rank
    FROM public.users u
    WHERE u.season_points > 0
    ORDER BY u.season_points DESC
    LIMIT p_leaderboard_limit
  ) lb;
  
  -- Get hex map for viewport (if viewport specified)
  -- NOTE: For MVP, we return ALL hexes. In production, filter by H3 bounds.
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', h.id,
      'team', h.last_runner_team
    )
  ), '[]'::JSONB)
  INTO v_hex_map
  FROM public.hexes h
  WHERE h.last_runner_team IS NOT NULL;
  
  -- Return combined response (with new aggregate fields)
  RETURN jsonb_build_object(
    'user_stats', jsonb_build_object(
      'id', v_user.id,
      'name', v_user.name,
      'team', v_user.team,
      'avatar', v_user.avatar,
      'season_points', v_user.season_points,
      'home_hex_start', v_user.home_hex_start,
      'home_hex_end', v_user.home_hex_end,
      'manifesto', v_user.manifesto,
      'total_distance_km', v_user.total_distance_km,
      'avg_pace_min_per_km', v_user.avg_pace_min_per_km,
      'avg_cv', v_user.avg_cv,
      'total_runs', v_user.total_runs
    ),
    'crew_info', v_crew_info,
    'yesterday_multiplier', v_yesterday_multiplier,
    'hex_map', v_hex_map,
    'leaderboard', v_leaderboard,
    'server_time', now()
  );
END;
$$;

-- ============================================================
-- 6. INDEXES FOR PERFORMANCE
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_users_total_distance ON public.users(total_distance_km DESC);
CREATE INDEX IF NOT EXISTS idx_users_avg_pace ON public.users(avg_pace_min_per_km);
CREATE INDEX IF NOT EXISTS idx_users_avg_cv ON public.users(avg_cv);
CREATE INDEX IF NOT EXISTS idx_run_history_cv ON public.run_history(cv) WHERE cv IS NOT NULL;
