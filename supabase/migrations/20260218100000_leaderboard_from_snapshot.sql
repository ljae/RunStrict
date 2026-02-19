-- Fix get_leaderboard: read from season_leaderboard_snapshot (Snapshot Domain)
-- instead of live users table. Leaderboard is frozen at midnight,
-- not updated during the day as users run.

-- Step 1: Add missing columns to snapshot table
ALTER TABLE public.season_leaderboard_snapshot
  ADD COLUMN IF NOT EXISTS nationality TEXT;
ALTER TABLE public.season_leaderboard_snapshot
  ADD COLUMN IF NOT EXISTS total_runs INTEGER DEFAULT 0;
ALTER TABLE public.season_leaderboard_snapshot
  ADD COLUMN IF NOT EXISTS home_hex_end TEXT;

-- Step 2: Replace get_leaderboard to read from snapshot
DROP FUNCTION IF EXISTS public.get_leaderboard(INTEGER);

CREATE FUNCTION public.get_leaderboard(p_limit INTEGER DEFAULT 20)
RETURNS TABLE (
  id UUID, name TEXT, team TEXT, avatar TEXT,
  season_points INT, total_distance_km FLOAT8,
  avg_pace_min_per_km FLOAT8, avg_cv FLOAT8,
  home_hex TEXT, home_hex_end TEXT, manifesto TEXT,
  nationality TEXT, total_runs INT, rank BIGINT
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT
    s.user_id, s.name, s.team, s.avatar,
    s.season_points, s.total_distance_km,
    s.avg_pace_min_per_km, s.avg_cv,
    s.home_hex,
    COALESCE(s.home_hex_end, u.home_hex_end),
    s.manifesto,
    COALESCE(s.nationality, u.nationality),
    COALESCE(s.total_runs, u.total_runs),
    s.rank::BIGINT
  FROM public.season_leaderboard_snapshot s
  LEFT JOIN public.users u ON u.id = s.user_id
  WHERE s.season_number = (
    SELECT MAX(season_number) FROM public.season_leaderboard_snapshot
  )
  ORDER BY s.rank ASC
  LIMIT p_limit;
$fn$;

NOTIFY pgrst, 'reload schema';
