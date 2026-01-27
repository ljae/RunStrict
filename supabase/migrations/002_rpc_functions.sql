-- RunStrict: RPC Functions Migration
-- Run this in Supabase SQL Editor after 001_initial_schema.sql
-- Implements: finalize_run, app_launch_sync, calculate_yesterday_checkins

-- ============================================================
-- 1. SCHEMA UPDATES (add missing columns)
-- ============================================================

-- Add last_flipped_at to hexes for conflict resolution
ALTER TABLE public.hexes 
ADD COLUMN IF NOT EXISTS last_flipped_at TIMESTAMPTZ;

-- Add home hex columns to users
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS home_hex_start TEXT,
ADD COLUMN IF NOT EXISTS home_hex_end TEXT;

-- Create run_history table (preserved across seasons, 5-year retention)
CREATE TABLE IF NOT EXISTS public.run_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  run_date DATE NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  distance_km DOUBLE PRECISION NOT NULL,
  duration_seconds INTEGER NOT NULL,
  avg_pace_min_per_km DOUBLE PRECISION,
  flip_count INTEGER NOT NULL DEFAULT 0,
  flip_points INTEGER NOT NULL DEFAULT 0,
  team_at_run TEXT NOT NULL CHECK (team_at_run IN ('red', 'blue', 'purple')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.run_history ENABLE ROW LEVEL SECURITY;

-- Users can read their own run history
CREATE POLICY "run_history_select" ON public.run_history
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Users can insert their own run history (via RPC only)
CREATE POLICY "run_history_insert" ON public.run_history
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Index for efficient queries
CREATE INDEX IF NOT EXISTS idx_run_history_user_date ON public.run_history(user_id, run_date DESC);

-- ============================================================
-- 2. CALCULATE_YESTERDAY_CHECKINS FUNCTION
-- ============================================================
-- Returns count of distinct users who completed a run yesterday
-- Used for crew multiplier calculation

CREATE OR REPLACE FUNCTION public.calculate_yesterday_checkins(p_crew_id UUID)
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(COUNT(DISTINCT rh.user_id)::INTEGER, 0)
  FROM public.run_history rh
  JOIN public.users u ON rh.user_id = u.id
  WHERE u.crew_id = p_crew_id
    AND rh.run_date = (CURRENT_DATE - INTERVAL '1 day')::DATE;
$$;

-- ============================================================
-- 3. FINALIZE_RUN FUNCTION ("The Final Sync")
-- ============================================================
-- Batch processes hex flips and awards points at run completion
-- Implements conflict resolution: later run_endTime wins

CREATE OR REPLACE FUNCTION public.finalize_run(
  p_user_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ,
  p_distance_km DOUBLE PRECISION,
  p_duration_seconds INTEGER,
  p_hex_path TEXT[],
  p_yesterday_crew_count INTEGER,
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
  
  -- Award points to user and update home hex (only if hex_path is not empty)
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
  
  -- Insert lightweight run history (PRESERVED across seasons)
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
    'multiplier', GREATEST(p_yesterday_crew_count, 1),
    'points_earned', v_points,
    'server_validated', true
  );
END;
$$;

-- ============================================================
-- 4. APP_LAUNCH_SYNC FUNCTION (Pre-patch)
-- ============================================================
-- Combined endpoint for all app launch data
-- Returns: hex_map, leaderboard, crew_info, user_stats, yesterday_multiplier

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
  -- Get user data
  SELECT u.id, u.name, u.team, u.avatar, u.season_points, u.crew_id,
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
  
  -- Return combined response
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
    'crew_info', v_crew_info,
    'yesterday_multiplier', v_yesterday_multiplier,
    'hex_map', v_hex_map,
    'leaderboard', v_leaderboard,
    'server_time', now()
  );
END;
$$;

-- ============================================================
-- 5. HELPER FUNCTIONS
-- ============================================================

-- Get user's current multiplier (convenience function)
CREATE OR REPLACE FUNCTION public.get_user_multiplier(p_user_id UUID)
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT CASE 
    WHEN u.crew_id IS NULL THEN 1
    ELSE GREATEST(public.calculate_yesterday_checkins(u.crew_id), 1)
  END
  FROM public.users u
  WHERE u.id = p_user_id;
$$;

-- Get run history for a user (paginated)
CREATE OR REPLACE FUNCTION public.get_run_history(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
  id UUID,
  run_date DATE,
  start_time TIMESTAMPTZ,
  end_time TIMESTAMPTZ,
  distance_km DOUBLE PRECISION,
  duration_seconds INTEGER,
  avg_pace_min_per_km DOUBLE PRECISION,
  flip_count INTEGER,
  flip_points INTEGER,
  team_at_run TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT rh.id, rh.run_date, rh.start_time, rh.end_time,
         rh.distance_km, rh.duration_seconds, rh.avg_pace_min_per_km,
         rh.flip_count, rh.flip_points, rh.team_at_run
  FROM public.run_history rh
  WHERE rh.user_id = p_user_id
  ORDER BY rh.end_time DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

-- ============================================================
-- 6. UPDATED SEASON RESET (preserves run_history)
-- ============================================================

CREATE OR REPLACE FUNCTION public.reset_season()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Wipe all hex colors
  TRUNCATE public.hexes;
  
  -- Reset all user season data (but preserve account)
  UPDATE public.users SET 
    season_points = 0,
    crew_id = NULL,
    team = NULL,  -- Forces re-selection on next launch
    home_hex_start = NULL,
    home_hex_end = NULL;
  
  -- Clear crews (season-only data)
  TRUNCATE public.crews CASCADE;
  
  -- Clear active runs
  TRUNCATE public.active_runs;
  
  -- Clear daily flips
  TRUNCATE public.daily_flips;
  
  -- NOTE: run_history is NOT truncated (preserved across seasons, 5-year retention)
END;
$$;
