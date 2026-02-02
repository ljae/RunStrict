-- RunStrict: Team-Based Buff System Migration
-- Run this in Supabase SQL Editor after previous migrations
-- Implements: Team-based buff matrix replacing crew multiplier system
-- 
-- New buff system based on:
-- - City dominance (team with most controlled hexes in H3 Res 6 area)
-- - All Range dominance (team with most controlled hexes server-wide)
-- - RED: Elite (top 20%) vs Common distinction
-- - BLUE: Union (all participants same buff)
-- - PURPLE: Participation rate tiers

-- ============================================================
-- 1. BUFF STATS TABLES
-- ============================================================

-- Store daily calculated buff data per city (H3 Res 6)
CREATE TABLE IF NOT EXISTS public.daily_buff_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stat_date DATE NOT NULL,
  city_hex TEXT NOT NULL, -- H3 Resolution 6 hex ID
  -- Team dominance (based on controlled hexes)
  dominant_team TEXT CHECK (dominant_team IN ('red', 'blue', 'purple')),
  red_hex_count INTEGER NOT NULL DEFAULT 0,
  blue_hex_count INTEGER NOT NULL DEFAULT 0,
  purple_hex_count INTEGER NOT NULL DEFAULT 0,
  -- RED Elite calculation (top 20% threshold by yesterday's flip points)
  red_elite_threshold_points INTEGER,
  -- PURPLE participation rate
  purple_total_users INTEGER NOT NULL DEFAULT 0,
  purple_active_users INTEGER NOT NULL DEFAULT 0,
  purple_participation_rate DOUBLE PRECISION,
  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(stat_date, city_hex)
);

-- Store all-range (server-wide) dominance
CREATE TABLE IF NOT EXISTS public.daily_all_range_stats (
  stat_date DATE PRIMARY KEY,
  dominant_team TEXT CHECK (dominant_team IN ('red', 'blue', 'purple')),
  red_hex_count INTEGER NOT NULL DEFAULT 0,
  blue_hex_count INTEGER NOT NULL DEFAULT 0,
  purple_hex_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_daily_buff_stats_date ON public.daily_buff_stats(stat_date);
CREATE INDEX IF NOT EXISTS idx_daily_buff_stats_city ON public.daily_buff_stats(city_hex);

-- Enable RLS
ALTER TABLE public.daily_buff_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_all_range_stats ENABLE ROW LEVEL SECURITY;

-- Read-only for authenticated users
CREATE POLICY "daily_buff_stats_select" ON public.daily_buff_stats
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "daily_all_range_stats_select" ON public.daily_all_range_stats
  FOR SELECT TO authenticated
  USING (true);

-- ============================================================
-- 2. CALCULATE_DAILY_BUFFS FUNCTION
-- ============================================================
-- Runs at midnight, calculates buff stats for the previous day
-- Called by pg_cron scheduler at 00:05 GMT+2

CREATE OR REPLACE FUNCTION public.calculate_daily_buffs()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_today DATE := CURRENT_DATE;
  v_yesterday DATE := CURRENT_DATE - INTERVAL '1 day';
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
  -- Delete any existing stats for today (idempotent)
  DELETE FROM public.daily_buff_stats WHERE stat_date = v_today;
  DELETE FROM public.daily_all_range_stats WHERE stat_date = v_today;

  -- Step 1: Calculate server-wide (All Range) hex counts
  SELECT 
    COALESCE(SUM(CASE WHEN h.last_runner_team = 'red' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN h.last_runner_team = 'blue' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN h.last_runner_team = 'purple' THEN 1 ELSE 0 END), 0)
  INTO v_all_range_red, v_all_range_blue, v_all_range_purple
  FROM public.hexes h
  WHERE h.last_runner_team IS NOT NULL;

  -- Determine All Range dominant team
  v_dominant := CASE
    WHEN v_all_range_red >= v_all_range_blue AND v_all_range_red >= v_all_range_purple THEN 'red'
    WHEN v_all_range_blue >= v_all_range_red AND v_all_range_blue >= v_all_range_purple THEN 'blue'
    ELSE 'purple'
  END;

  -- Insert All Range stats
  INSERT INTO public.daily_all_range_stats (
    stat_date, dominant_team, red_hex_count, blue_hex_count, purple_hex_count
  ) VALUES (
    v_today, v_dominant, v_all_range_red, v_all_range_blue, v_all_range_purple
  );

  -- Step 2: Process each city (Res 6 hex) that has users
  -- Get distinct cities from user home_hex_end (Resolution 6 parent)
  FOR v_city_hex IN
    SELECT DISTINCT 
      CASE 
        WHEN u.home_hex_end IS NOT NULL AND length(u.home_hex_end) > 0 
        THEN substring(u.home_hex_end from 1 for 10) -- Approximate Res 6 (first 10 chars)
        ELSE NULL 
      END as city
    FROM public.users u
    WHERE u.team IS NOT NULL
      AND u.home_hex_end IS NOT NULL
  LOOP
    IF v_city_hex IS NULL THEN
      CONTINUE;
    END IF;

    -- Count hexes per team in this city
    -- Note: For proper H3 implementation, use h3_cell_to_parent(hex_id, 6)
    -- This simplified version uses prefix matching
    SELECT 
      COALESCE(SUM(CASE WHEN h.last_runner_team = 'red' THEN 1 ELSE 0 END), 0) as red_count,
      COALESCE(SUM(CASE WHEN h.last_runner_team = 'blue' THEN 1 ELSE 0 END), 0) as blue_count,
      COALESCE(SUM(CASE WHEN h.last_runner_team = 'purple' THEN 1 ELSE 0 END), 0) as purple_count
    INTO v_hex_counts
    FROM public.hexes h
    WHERE h.last_runner_team IS NOT NULL
      AND h.id LIKE v_city_hex || '%';

    -- Determine city dominant team
    v_dominant := CASE
      WHEN v_hex_counts.red_count >= v_hex_counts.blue_count 
        AND v_hex_counts.red_count >= v_hex_counts.purple_count THEN 'red'
      WHEN v_hex_counts.blue_count >= v_hex_counts.red_count 
        AND v_hex_counts.blue_count >= v_hex_counts.purple_count THEN 'blue'
      ELSE 'purple'
    END;

    -- Calculate RED Elite threshold (top 20% flip points from yesterday in this city)
    SELECT COALESCE(
      PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY rh.flip_points),
      0
    )::INTEGER
    INTO v_elite_threshold
    FROM public.run_history rh
    JOIN public.users u ON rh.user_id = u.id
    WHERE rh.run_date = v_yesterday
      AND u.team = 'red'
      AND u.home_hex_end LIKE v_city_hex || '%';

    -- Calculate PURPLE participation rate
    SELECT COUNT(*) INTO v_purple_total
    FROM public.users u
    WHERE u.team = 'purple'
      AND u.home_hex_end LIKE v_city_hex || '%';

    SELECT COUNT(DISTINCT rh.user_id) INTO v_purple_active
    FROM public.run_history rh
    JOIN public.users u ON rh.user_id = u.id
    WHERE rh.run_date = v_yesterday
      AND u.team = 'purple'
      AND u.home_hex_end LIKE v_city_hex || '%';

    -- Insert city buff stats
    INSERT INTO public.daily_buff_stats (
      stat_date,
      city_hex,
      dominant_team,
      red_hex_count,
      blue_hex_count,
      purple_hex_count,
      red_elite_threshold_points,
      purple_total_users,
      purple_active_users,
      purple_participation_rate
    ) VALUES (
      v_today,
      v_city_hex,
      v_dominant,
      v_hex_counts.red_count,
      v_hex_counts.blue_count,
      v_hex_counts.purple_count,
      v_elite_threshold,
      v_purple_total,
      v_purple_active,
      CASE WHEN v_purple_total > 0 
        THEN v_purple_active::DOUBLE PRECISION / v_purple_total 
        ELSE 0 
      END
    );

    v_cities_processed := v_cities_processed + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'stat_date', v_today,
    'cities_processed', v_cities_processed,
    'all_range_dominant', (SELECT dominant_team FROM public.daily_all_range_stats WHERE stat_date = v_today)
  );
END;
$$;

-- ============================================================
-- 3. GET_USER_BUFF FUNCTION
-- ============================================================
-- Returns user's current buff multiplier with breakdown
-- Called on app launch and run start

CREATE OR REPLACE FUNCTION public.get_user_buff(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_city_hex TEXT;
  v_city_stats RECORD;
  v_all_range RECORD;
  v_yesterday DATE := CURRENT_DATE - INTERVAL '1 day';
  v_today DATE := CURRENT_DATE;
  v_yesterday_points INTEGER;
  v_base_buff INTEGER := 1;
  v_all_range_bonus INTEGER := 0;
  v_is_city_leader BOOLEAN := FALSE;
  v_is_elite BOOLEAN := FALSE;
  v_reason TEXT := 'Default';
BEGIN
  -- Get user info
  SELECT u.id, u.team, u.home_hex_end
  INTO v_user
  FROM public.users u
  WHERE u.id = p_user_id;

  IF v_user.id IS NULL OR v_user.team IS NULL THEN
    RETURN jsonb_build_object(
      'multiplier', 1,
      'base_buff', 1,
      'all_range_bonus', 0,
      'reason', 'User not found or no team'
    );
  END IF;

  -- Derive user's city (Res 6 parent - simplified: first 10 chars)
  IF v_user.home_hex_end IS NOT NULL AND length(v_user.home_hex_end) > 0 THEN
    v_city_hex := substring(v_user.home_hex_end from 1 for 10);
  ELSE
    v_city_hex := NULL;
  END IF;

  -- Get city buff stats for today
  SELECT * INTO v_city_stats
  FROM public.daily_buff_stats
  WHERE stat_date = v_today
    AND city_hex = v_city_hex;

  -- Get All Range stats for today
  SELECT * INTO v_all_range
  FROM public.daily_all_range_stats
  WHERE stat_date = v_today;

  -- Check if user's team is city leader
  IF v_city_stats IS NOT NULL THEN
    v_is_city_leader := (v_city_stats.dominant_team = v_user.team);
  END IF;

  -- Calculate buff based on team
  CASE v_user.team
    WHEN 'red' THEN
      -- Get user's yesterday flip points to determine Elite status
      SELECT COALESCE(SUM(rh.flip_points), 0)
      INTO v_yesterday_points
      FROM public.run_history rh
      WHERE rh.user_id = p_user_id
        AND rh.run_date = v_yesterday;

      -- Check if Elite (top 20%)
      v_is_elite := (v_yesterday_points >= COALESCE(v_city_stats.red_elite_threshold_points, 0) 
                     AND v_yesterday_points > 0);

      IF v_is_elite THEN
        IF v_is_city_leader THEN
          v_base_buff := 3;
          v_reason := 'RED Elite, City Leader';
        ELSE
          v_base_buff := 2;
          v_reason := 'RED Elite, Non-Leader';
        END IF;
      ELSE
        v_base_buff := 1;
        IF v_is_city_leader THEN
          v_reason := 'RED Common, City Leader';
        ELSE
          v_reason := 'RED Common, Non-Leader';
        END IF;
      END IF;

      -- All Range bonus for RED
      IF v_all_range IS NOT NULL AND v_all_range.dominant_team = 'red' THEN
        v_all_range_bonus := 1;
        v_reason := v_reason || ' +All Range';
      END IF;

    WHEN 'blue' THEN
      IF v_is_city_leader THEN
        v_base_buff := 2;
        v_reason := 'BLUE Union, City Leader';
      ELSE
        v_base_buff := 1;
        v_reason := 'BLUE Union, Non-Leader';
      END IF;

      -- All Range bonus for BLUE
      IF v_all_range IS NOT NULL AND v_all_range.dominant_team = 'blue' THEN
        v_all_range_bonus := 1;
        v_reason := v_reason || ' +All Range';
      END IF;

    WHEN 'purple' THEN
      -- Purple uses participation rate tiers (no All Range bonus)
      IF v_city_stats IS NOT NULL AND v_city_stats.purple_participation_rate IS NOT NULL THEN
        IF v_city_stats.purple_participation_rate >= 0.60 THEN
          v_base_buff := 3;
          v_reason := 'PURPLE High Tier (≥60%)';
        ELSIF v_city_stats.purple_participation_rate >= 0.30 THEN
          v_base_buff := 2;
          v_reason := 'PURPLE Mid Tier (30-60%)';
        ELSE
          v_base_buff := 1;
          v_reason := 'PURPLE Low Tier (<30%)';
        END IF;
      ELSE
        v_base_buff := 1;
        v_reason := 'PURPLE (no city stats)';
      END IF;
      -- Purple does NOT get All Range bonus
      v_all_range_bonus := 0;

    ELSE
      v_base_buff := 1;
      v_reason := 'Unknown team';
  END CASE;

  RETURN jsonb_build_object(
    'multiplier', v_base_buff + v_all_range_bonus,
    'base_buff', v_base_buff,
    'all_range_bonus', v_all_range_bonus,
    'reason', v_reason,
    'team', v_user.team,
    'city_hex', v_city_hex,
    'is_city_leader', v_is_city_leader,
    'is_elite', v_is_elite
  );
END;
$$;

-- ============================================================
-- 4. UPDATE APP_LAUNCH_SYNC TO INCLUDE BUFF
-- ============================================================
-- Add user_buff to the app_launch_sync response

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
  v_user_buff JSONB;
  v_hex_map JSONB := '[]'::JSONB;
  v_leaderboard JSONB := '[]'::JSONB;
BEGIN
  -- Get user data
  SELECT u.id, u.name, u.team, u.avatar, u.season_points,
         u.home_hex_start, u.home_hex_end, u.manifesto
  INTO v_user
  FROM public.users u
  WHERE u.id = p_user_id;
  
  IF v_user IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'User not found',
      'user_stats', NULL
    );
  END IF;
  
  -- Get user buff (replaces yesterday_multiplier)
  v_user_buff := public.get_user_buff(p_user_id);
  
  -- Get leaderboard (top users by season points)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', lb.id,
      'name', lb.name,
      'team', lb.team,
      'avatar', lb.avatar,
      'season_points', lb.season_points,
      'rank', lb.rank
    ) ORDER BY lb.rank
  ), '[]'::JSONB)
  INTO v_leaderboard
  FROM (
    SELECT u.id, u.name, u.team, u.avatar, u.season_points,
           ROW_NUMBER() OVER (ORDER BY u.season_points DESC) as rank
    FROM public.users u
    WHERE u.season_points > 0
    ORDER BY u.season_points DESC
    LIMIT p_leaderboard_limit
  ) lb;
  
  -- Get hex map (all non-neutral hexes)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', h.id,
      'team', h.last_runner_team
    )
  ), '[]'::JSONB)
  INTO v_hex_map
  FROM public.hexes h
  WHERE h.last_runner_team IS NOT NULL;
  
  -- Return combined response (crew_info removed, user_buff added)
  RETURN jsonb_build_object(
    'user_stats', jsonb_build_object(
      'id', v_user.id,
      'name', v_user.name,
      'team', v_user.team,
      'avatar', v_user.avatar,
      'season_points', v_user.season_points,
      'home_hex_start', v_user.home_hex_start,
      'home_hex_end', v_user.home_hex_end,
      'manifesto', v_user.manifesto
    ),
    'user_buff', v_user_buff,
    'hex_map', v_hex_map,
    'leaderboard', v_leaderboard,
    'server_time', now()
  );
END;
$$;

-- ============================================================
-- 5. UPDATE FINALIZE_RUN FOR BUFF VALIDATION
-- ============================================================
-- Replace p_yesterday_crew_count with p_buff_multiplier
-- Validates multiplier against get_user_buff()

CREATE OR REPLACE FUNCTION public.finalize_run(
  p_user_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ,
  p_distance_km DOUBLE PRECISION,
  p_duration_seconds INTEGER,
  p_hex_path TEXT[],
  p_buff_multiplier INTEGER DEFAULT 1,
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
  v_server_buff JSONB;
  v_validated_multiplier INTEGER;
BEGIN
  -- Get user's team
  SELECT team INTO v_team FROM public.users WHERE id = p_user_id;
  
  IF v_team IS NULL THEN
    RAISE EXCEPTION 'User not found or has no team assigned';
  END IF;
  
  -- Server-side buff validation
  v_server_buff := public.get_user_buff(p_user_id);
  v_validated_multiplier := GREATEST((v_server_buff->>'multiplier')::INTEGER, 1);
  
  -- Use server-validated multiplier (ignore client if higher)
  IF p_buff_multiplier > v_validated_multiplier THEN
    RAISE WARNING 'Client claimed multiplier % but server calculated %. Using server value.',
      p_buff_multiplier, v_validated_multiplier;
  END IF;
  
  -- Process each hex in the path
  IF p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0 THEN
    FOREACH v_hex_id IN ARRAY p_hex_path LOOP
      -- Check current hex color and timestamp
      SELECT last_runner_team, last_flipped_at 
      INTO v_current_team, v_current_flipped_at 
      FROM public.hexes WHERE id = v_hex_id;
      
      -- Only update if this run ended LATER than the existing flip
      IF v_current_flipped_at IS NULL OR p_end_time > v_current_flipped_at THEN
        -- Count as flip if color changes (or hex is new/neutral)
        IF v_current_team IS DISTINCT FROM v_team THEN
          v_total_flips := v_total_flips + 1;
        END IF;
        
        -- Update hex color with timestamp
        INSERT INTO public.hexes (id, last_runner_team, last_flipped_at)
        VALUES (v_hex_id, v_team, p_end_time)
        ON CONFLICT (id) DO UPDATE
        SET last_runner_team = v_team,
            last_flipped_at = p_end_time
        WHERE public.hexes.last_flipped_at IS NULL OR public.hexes.last_flipped_at < p_end_time;
      END IF;
    END LOOP;
  END IF;
  
  -- Calculate points with validated multiplier
  v_points := v_total_flips * v_validated_multiplier;
  
  -- Security validation
  IF p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0 THEN
    v_max_allowed_points := array_length(p_hex_path, 1) * v_validated_multiplier;
    IF p_client_points IS NOT NULL AND p_client_points > v_max_allowed_points THEN
      RAISE WARNING 'Client claimed % points but max allowed is %', p_client_points, v_max_allowed_points;
    END IF;
  END IF;
  
  -- Award points and update home hex
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
  
  -- Return summary
  RETURN jsonb_build_object(
    'run_id', v_run_history_id,
    'flips', v_total_flips,
    'multiplier', v_validated_multiplier,
    'points_earned', v_points,
    'buff_breakdown', v_server_buff,
    'server_validated', true
  );
END;
$$;

-- ============================================================
-- 6. UPDATE RESET_SEASON TO HANDLE NEW TABLES
-- ============================================================

CREATE OR REPLACE FUNCTION public.reset_season()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Wipe all hex colors
  TRUNCATE public.hexes;
  
  -- Reset all user season data
  UPDATE public.users SET 
    season_points = 0,
    team = NULL,  -- Forces re-selection
    home_hex_start = NULL,
    home_hex_end = NULL;
  
  -- Clear daily flips
  TRUNCATE public.daily_flips;
  
  -- Clear active runs (deprecated but kept)
  TRUNCATE public.active_runs;
  
  -- Clear buff stats (start fresh for new season)
  TRUNCATE public.daily_buff_stats;
  TRUNCATE public.daily_all_range_stats;
  
  -- NOTE: run_history is NOT truncated (preserved across seasons)
  -- NOTE: crews table removed from reset (crew system deprecated)
END;
$$;

-- ============================================================
-- 7. DEPRECATE CREW-RELATED FUNCTIONS
-- ============================================================
-- Mark as deprecated but don't delete (backward compatibility)

COMMENT ON FUNCTION public.calculate_yesterday_checkins(UUID) IS 
  'DEPRECATED: Replaced by get_user_buff() in 008_buff_system.sql';

COMMENT ON FUNCTION public.get_crew_multiplier(UUID) IS 
  'DEPRECATED: Replaced by get_user_buff() in 008_buff_system.sql';

COMMENT ON FUNCTION public.get_user_multiplier(UUID) IS 
  'DEPRECATED: Replaced by get_user_buff() in 008_buff_system.sql';

-- ============================================================
-- 8. SCHEDULE DAILY CALCULATION (pg_cron)
-- ============================================================
-- NOTE: pg_cron must be enabled in Supabase Dashboard > Database > Extensions
-- Schedule daily calculation at 00:05 GMT+2 (server timezone)

-- Uncomment after enabling pg_cron extension:
-- SELECT cron.schedule(
--   'calculate_daily_buffs',
--   '5 0 * * *',
--   $$SELECT public.calculate_daily_buffs()$$
-- );

-- ============================================================
-- 9. INITIAL DATA POPULATION
-- ============================================================
-- Run calculate_daily_buffs() once to populate initial stats

SELECT public.calculate_daily_buffs();
