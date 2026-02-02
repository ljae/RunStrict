-- RunStrict: Season Home Hex Migration
-- Run this in Supabase SQL Editor after 004_scoped_data_functions.sql
-- Implements: season_home_hex for leaderboard/multiplier anchoring

-- ============================================================
-- 1. SCHEMA UPDATE: Add season_home_hex column
-- ============================================================

-- Add season_home_hex column (Res 9 hex set once on first app launch of season)
-- Used for: MY LEAGUE leaderboard filtering, multiplier region boundary
-- Unlike home_hex which updates with location, season_home_hex is FIXED for the season
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS season_home_hex TEXT;

-- Migrate existing data: use current home_hex as initial season_home_hex
UPDATE public.users
SET season_home_hex = home_hex
WHERE season_home_hex IS NULL AND home_hex IS NOT NULL;

-- ============================================================
-- 2. SET_SEASON_HOME_HEX FUNCTION
-- ============================================================
-- Sets the user's season home hex on first app launch of a new season
-- Only updates if season_home_hex is currently NULL (new season detected on client)

CREATE OR REPLACE FUNCTION public.set_season_home_hex(
  p_user_id UUID,
  p_season_home_hex TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_season_home_hex TEXT;
BEGIN
  -- Get current season_home_hex
  SELECT season_home_hex INTO v_current_season_home_hex
  FROM public.users
  WHERE id = p_user_id;
  
  -- Only set if currently NULL (new season)
  IF v_current_season_home_hex IS NULL THEN
    UPDATE public.users
    SET season_home_hex = p_season_home_hex
    WHERE id = p_user_id;
    RETURN TRUE;
  END IF;
  
  RETURN FALSE;
END;
$$;

COMMENT ON FUNCTION public.set_season_home_hex IS 'Sets season home hex on first app launch of season. Only updates if NULL.';

-- ============================================================
-- 3. UPDATE APP_LAUNCH_SYNC TO INCLUDE SEASON_HOME_HEX
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

  -- Get user data (including season_home_hex)
  SELECT u.id, u.name, u.team, u.avatar, u.season_points, u.crew_id,
         u.home_hex, u.season_home_hex, u.home_hex_start, u.home_hex_end, u.manifesto,
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
  
  -- Get leaderboard (top users by season points, include season_home_hex for filtering)
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
      'season_home_hex', lb.season_home_hex,
      'rank', lb.rank
    ) ORDER BY lb.rank
  ), '[]'::JSONB)
  INTO v_leaderboard
  FROM (
    SELECT u.id, u.name, u.team, u.avatar, u.season_points,
           COALESCE(u.total_distance_km, 0) as total_distance_km,
           CASE WHEN u.avg_cv IS NOT NULL THEN (100 - u.avg_cv)::INTEGER ELSE NULL END as stability_score,
           u.home_hex,
           u.season_home_hex,
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
  
  -- Return combined response (includes season_home_hex)
  RETURN jsonb_build_object(
    'user_stats', jsonb_build_object(
      'id', v_user.id,
      'name', v_user.name,
      'team', v_user.team,
      'avatar', v_user.avatar,
      'season_points', v_user.season_points,
      'home_hex', v_user.home_hex,
      'season_home_hex', v_user.season_home_hex,
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
-- 4. UPDATE GET_SCOPED_LEADERBOARD TO INCLUDE SEASON_HOME_HEX
-- ============================================================

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
  season_home_hex TEXT,
  rank BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
  -- Return all users with points, ordered by season_points
  -- Client will filter by season_home_hex scope for MY LEAGUE
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
    u.season_home_hex,
    ROW_NUMBER() OVER (ORDER BY u.season_points DESC) AS rank
  FROM public.users u
  WHERE u.season_points > 0
  ORDER BY u.season_points DESC
  LIMIT p_limit;
END;
$$;

-- ============================================================
-- 5. UPDATE RESET_SEASON TO CLEAR SEASON_HOME_HEX
-- ============================================================
-- On D-Day reset, season_home_hex is cleared so it can be set again

CREATE OR REPLACE FUNCTION public.reset_season()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Wipe all hex colors
  TRUNCATE public.hexes;
  
  -- Reset all user season data (clear season_home_hex for new season)
  UPDATE public.users SET 
    season_points = 0,
    crew_id = NULL,
    team = NULL,
    total_distance_km = 0,
    avg_pace_min_per_km = NULL,
    avg_cv = NULL,
    total_runs = 0,
    season_home_hex = NULL;  -- Clear so it can be set on first launch of new season
    -- Note: home_hex is NOT reset (persists for map centering)
  
  -- Clear crews
  TRUNCATE public.crews CASCADE;
  
  -- Clear active runs
  TRUNCATE public.active_runs;
  
  -- Clear daily flips
  TRUNCATE public.daily_flips;
END;
$$;

COMMENT ON FUNCTION public.reset_season IS 'Resets all season data including season_home_hex. Called on D-Day.';
