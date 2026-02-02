-- RunStrict: Remove total_runs from RPC Responses Migration
-- Run this in Supabase SQL Editor after 006_region_aware_multiplier.sql

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
    ROW_NUMBER() OVER (ORDER BY u.season_points DESC)::INTEGER as rank
  FROM public.users u
  WHERE u.season_points > 0
  ORDER BY u.season_points DESC
  LIMIT p_limit;
$$;
