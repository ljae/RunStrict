-- RunStrict: Remove Deprecated Crew System Migration
-- Run this in Supabase SQL Editor after 009_team_stats.sql
-- Implements: Complete removal of crew-based system (replaced by team-based buff in 008)
--
-- This migration:
-- 1. Drops foreign key constraints referencing crews
-- 2. Removes crew_id column from users and active_runs
-- 3. Drops deprecated crew-related RPC functions
-- 4. Drops the crews table
-- 5. Updates get_leaderboard to remove crew_id from response

-- ============================================================
-- 1. DROP FOREIGN KEY CONSTRAINTS
-- ============================================================

-- Drop crew_id FK from users table
ALTER TABLE public.users 
DROP CONSTRAINT IF EXISTS users_crew_id_fkey;

-- Drop crew_id FK from active_runs table
ALTER TABLE public.active_runs 
DROP CONSTRAINT IF EXISTS active_runs_crew_id_fkey;

-- ============================================================
-- 2. DROP CREW_ID COLUMNS
-- ============================================================

-- Drop crew_id column from users (no longer used)
ALTER TABLE public.users 
DROP COLUMN IF EXISTS crew_id;

-- Drop crew_id column from active_runs (deprecated table, keeping for backward compat)
ALTER TABLE public.active_runs 
DROP COLUMN IF EXISTS crew_id;

-- Drop indexes on crew_id
DROP INDEX IF EXISTS idx_users_crew_id;
DROP INDEX IF EXISTS idx_active_runs_crew_id;

-- ============================================================
-- 3. DROP DEPRECATED CREW-RELATED FUNCTIONS
-- ============================================================

-- Drop get_crew_multiplier (replaced by get_user_buff)
DROP FUNCTION IF EXISTS public.get_crew_multiplier(UUID);

-- Drop calculate_yesterday_checkins (replaced by get_user_buff)
DROP FUNCTION IF EXISTS public.calculate_yesterday_checkins(UUID);

-- Drop get_user_multiplier (replaced by get_user_buff)
DROP FUNCTION IF EXISTS public.get_user_multiplier(UUID);

-- ============================================================
-- 4. DROP CREWS TABLE
-- ============================================================

-- Drop RLS policies first
DROP POLICY IF EXISTS crews_select ON public.crews;
DROP POLICY IF EXISTS crews_insert ON public.crews;
DROP POLICY IF EXISTS crews_update ON public.crews;

-- Drop the crews table
DROP TABLE IF EXISTS public.crews;

-- ============================================================
-- 5. UPDATE GET_LEADERBOARD TO REMOVE CREW_ID
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_leaderboard(p_limit INTEGER DEFAULT 20)
RETURNS TABLE(
  id UUID,
  name TEXT,
  team TEXT,
  avatar TEXT,
  season_points INTEGER,
  total_distance_km DOUBLE PRECISION,
  avg_pace_min_per_km DOUBLE PRECISION,
  avg_cv DOUBLE PRECISION,
  home_hex TEXT
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
    u.total_distance_km,
    u.avg_pace_min_per_km,
    u.avg_cv,
    u.home_hex_end as home_hex
  FROM public.users u
  WHERE u.season_points > 0
  ORDER BY u.season_points DESC
  LIMIT p_limit;
$$;

-- ============================================================
-- 6. TABLE DOCUMENTATION
-- ============================================================

COMMENT ON TABLE public.users IS 
  'User profiles. crew_id removed in 010_remove_crew_system.sql (replaced by team-based buff system)';

COMMENT ON TABLE public.active_runs IS 
  'Active run tracking (deprecated - kept for backward compatibility). crew_id removed in 010_remove_crew_system.sql';
