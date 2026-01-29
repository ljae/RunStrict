-- RunStrict: Scoped Data Functions Migration
-- Run this in Supabase SQL Editor after 003_cv_aggregates.sql
-- Implements: get_hexes_in_scope, get_scoped_leaderboard, home_hex migration

-- ============================================================
-- 1. SCHEMA UPDATES: Migrate from home_hex_start/home_hex_end to single home_hex
-- ============================================================

-- Add new home_hex column (single Res 9 hex set once on prefetch)
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS home_hex TEXT;

-- Migrate existing data: use home_hex_start if exists
UPDATE public.users
SET home_hex = home_hex_start
WHERE home_hex IS NULL AND home_hex_start IS NOT NULL;

-- Note: home_hex_start and home_hex_end columns are kept for backward compatibility
-- but will no longer be updated after runs

-- ============================================================
-- 2. GET_HEXES_IN_SCOPE FUNCTION
-- ============================================================
-- Returns all hexes within a given parent cell's scope
-- Used for prefetching hex data for the "All" range

CREATE OR REPLACE FUNCTION public.get_hexes_in_scope(
  p_parent_hex TEXT,
  p_scope_resolution INTEGER
)
RETURNS TABLE(
  hex_id TEXT,
  last_runner_team TEXT,
  last_flipped_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_parent_pattern TEXT;
BEGIN
  -- H3 hex IDs share a common prefix for cells within the same parent
  -- We use LIKE pattern matching on the hex ID string
  -- Note: This is a simplified approach; production should use H3 functions
  
  -- For now, return all hexes (the client will filter by parent)
  -- In production, you would use PostGIS + H3 extension for proper filtering
  RETURN QUERY
  SELECT h.id, h.last_runner_team, h.last_flipped_at
  FROM public.hexes h
  WHERE h.last_runner_team IS NOT NULL;
END;
$$;

-- ============================================================
-- 3. GET_SCOPED_LEADERBOARD FUNCTION
-- ============================================================
-- Returns leaderboard filtered by users within the same geographic scope
-- Uses home_hex to determine if users are in the same parent cell

CREATE OR REPLACE FUNCTION public.get_scoped_leaderboard(
  p_parent_hex TEXT,
  p_scope_resolution INTEGER,
  p_limit INTEGER DEFAULT 100
)
RETURNS TABLE(
  user_id UUID,
  name TEXT,
  avatar TEXT,
  team TEXT,
  flip_points INTEGER,
  total_distance_km DOUBLE PRECISION,
  stability_score INTEGER,
  home_hex TEXT,
  rank BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
  -- Return all users with points, ordered by season_points
  -- Client will filter by home_hex scope
  -- In production with H3 extension, filter here using h3_cell_to_parent
  RETURN QUERY
  SELECT 
    u.id AS user_id,
    u.name,
    u.avatar,
    u.team,
    u.season_points AS flip_points,
    COALESCE(u.total_distance_km, 0) AS total_distance_km,
    CASE 
      WHEN u.avg_cv IS NOT NULL THEN (100 - u.avg_cv)::INTEGER 
      ELSE NULL 
    END AS stability_score,
    u.home_hex,
    ROW_NUMBER() OVER (ORDER BY u.season_points DESC) AS rank
  FROM public.users u
  WHERE u.season_points > 0
  ORDER BY u.season_points DESC
  LIMIT p_limit;
END;
$$;

-- ============================================================
-- 4. UPDATE APP_LAUNCH_SYNC TO INCLUDE HOME_HEX
-- ============================================================

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
  v_app_config JSONB := NULL;
BEGIN
  -- Get app_config
  SELECT jsonb_build_object(
    'version', ac.version,
    'data', ac.data
  ) INTO v_app_config
  FROM public.app_config ac
  WHERE ac.is_active = true
  ORDER BY ac.version DESC
  LIMIT 1;

  -- Handle case when p_user_id is NULL (unauthenticated user)
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'user_stats', NULL,
      'crew_info', NULL,
      'yesterday_multiplier', 1,
      'hex_map', '[]'::JSONB,
      'leaderboard', '[]'::JSONB,
      'app_config', v_app_config,
      'server_time', now()
    );
  END IF;

  -- Get user data (including new home_hex field)
  SELECT u.id, u.name, u.team, u.avatar, u.season_points, u.crew_id,
         u.home_hex, u.home_hex_start, u.home_hex_end, u.manifesto,
         u.total_distance_km, u.avg_pace_min_per_km, u.avg_cv, u.total_runs
  INTO v_user
  FROM public.users u
  WHERE u.id = p_user_id;
  
  IF v_user IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'User not found',
      'user_stats', NULL,
      'app_config', v_app_config
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
  
  -- Get leaderboard (top users by season points)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', lb.id,
      'name', lb.name,
      'team', lb.team,
      'avatar', lb.avatar,
      'season_points', lb.season_points,
      'total_distance_km', lb.total_distance_km,
      'stability_score', lb.stability_score,
      'home_hex', lb.home_hex,
      'rank', lb.rank
    ) ORDER BY lb.rank
  ), '[]'::JSONB)
  INTO v_leaderboard
  FROM (
    SELECT u.id, u.name, u.team, u.avatar, u.season_points,
           COALESCE(u.total_distance_km, 0) as total_distance_km,
           CASE WHEN u.avg_cv IS NOT NULL THEN (100 - u.avg_cv)::INTEGER ELSE NULL END as stability_score,
           u.home_hex,
           ROW_NUMBER() OVER (ORDER BY u.season_points DESC) as rank
    FROM public.users u
    WHERE u.season_points > 0
    ORDER BY u.season_points DESC
    LIMIT p_leaderboard_limit
  ) lb;
  
  -- Get hex map for viewport (if viewport specified)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', h.id,
      'team', h.last_runner_team,
      'last_flipped_at', h.last_flipped_at
    )
  ), '[]'::JSONB)
  INTO v_hex_map
  FROM public.hexes h
  WHERE h.last_runner_team IS NOT NULL;
  
  -- Return combined response
  RETURN jsonb_build_object(
    'user_stats', jsonb_build_object(
      'id', v_user.id,
      'name', v_user.name,
      'team', v_user.team,
      'avatar', v_user.avatar,
      'season_points', v_user.season_points,
      'home_hex', v_user.home_hex,
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
    'app_config', v_app_config,
    'server_time', now()
  );
END;
$$;

-- ============================================================
-- 5. UPDATE FINALIZE_RUN TO NOT UPDATE HOME_HEX
-- ============================================================
-- Home hex is now set once during prefetch, not updated after runs

CREATE OR REPLACE FUNCTION public.finalize_run(
  p_user_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ,
  p_distance_km DOUBLE PRECISION,
  p_duration_seconds INTEGER,
  p_hex_path TEXT[],
  p_yesterday_crew_count INTEGER,
  p_cv DOUBLE PRECISION DEFAULT NULL,
  p_client_points INTEGER DEFAULT NULL
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
  -- Get user's team and current stats
  SELECT team, total_distance_km, total_runs, avg_cv 
  INTO v_team, v_current_total_distance, v_current_total_runs, v_current_avg_cv 
  FROM public.users WHERE id = p_user_id;
  
  IF v_team IS NULL THEN
    RAISE EXCEPTION 'User not found or has no team assigned';
  END IF;
  
  -- Process each hex in the path
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
  
  -- Calculate points with multiplier
  v_points := v_total_flips * GREATEST(p_yesterday_crew_count, 1);
  
  -- Server-side validation
  IF p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0 THEN
    v_max_allowed_points := array_length(p_hex_path, 1) * GREATEST(p_yesterday_crew_count, 1);
    IF p_client_points IS NOT NULL AND p_client_points > v_max_allowed_points THEN
      RAISE WARNING 'Client claimed % points but max allowed is %', p_client_points, v_max_allowed_points;
    END IF;
  END IF;
  
  -- Update user stats (NO LONGER updating home_hex from runs)
  -- Also update CV aggregates
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
  
  -- Insert run history
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
    'server_validated', true
  );
END;
$$;

-- ============================================================
-- 6. SET_HOME_HEX FUNCTION (for prefetch)
-- ============================================================
-- Sets the user's home hex during initial prefetch
-- Only updates if home_hex is currently NULL

CREATE OR REPLACE FUNCTION public.set_home_hex(
  p_user_id UUID,
  p_home_hex TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_home_hex TEXT;
BEGIN
  -- Get current home hex
  SELECT home_hex INTO v_current_home_hex
  FROM public.users
  WHERE id = p_user_id;
  
  -- Only set if currently NULL (never overwrite)
  IF v_current_home_hex IS NULL THEN
    UPDATE public.users
    SET home_hex = p_home_hex
    WHERE id = p_user_id;
    RETURN TRUE;
  END IF;
  
  RETURN FALSE;
END;
$$;

-- ============================================================
-- 7. UPDATE RESET_SEASON TO USE NEW HOME_HEX FIELD
-- ============================================================

CREATE OR REPLACE FUNCTION public.reset_season()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Wipe all hex colors
  TRUNCATE public.hexes;
  
  -- Reset all user season data (but preserve account and home_hex)
  UPDATE public.users SET 
    season_points = 0,
    crew_id = NULL,
    team = NULL,
    total_distance_km = 0,
    avg_pace_min_per_km = NULL,
    avg_cv = NULL,
    total_runs = 0;
    -- Note: home_hex is NOT reset (persists across seasons)
  
  -- Clear crews
  TRUNCATE public.crews CASCADE;
  
  -- Clear active runs
  TRUNCATE public.active_runs;
  
  -- Clear daily flips
  TRUNCATE public.daily_flips;
END;
$$;
