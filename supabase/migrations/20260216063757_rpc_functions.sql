-- RPC function definitions for RunStrict
-- Source of truth for all server-side functions called from the Dart client.
-- Verify against production: compare signatures and logic with dashboard.

-- =============================================================================
-- app_launch_sync: Pre-patch data on app launch
-- Called by: SupabaseService.appLaunchSync()
-- =============================================================================
CREATE OR REPLACE FUNCTION public.app_launch_sync(p_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_user_stats jsonb;
  v_user_buff jsonb;
BEGIN
  -- Get user stats
  SELECT jsonb_build_object(
    'season_points', u.season_points,
    'home_hex', u.home_hex,
    'home_hex_end', u.home_hex_end,
    'season_home_hex', u.season_home_hex,
    'total_distance_km', u.total_distance_km,
    'avg_pace_min_per_km', u.avg_pace_min_per_km,
    'avg_cv', u.avg_cv,
    'total_runs', u.total_runs
  ) INTO v_user_stats
  FROM public.users u
  WHERE u.id = p_user_id;

  -- Get today's buff
  SELECT jsonb_build_object(
    'multiplier', COALESCE(b.buff_multiplier, 1),
    'is_elite', COALESCE(b.is_elite, false),
    'is_district_leader', COALESCE(b.is_district_leader, false),
    'has_province_range', COALESCE(b.has_province_range, false)
  ) INTO v_user_buff
  FROM public.daily_buff_stats b
  WHERE b.user_id = p_user_id AND b.date = CURRENT_DATE;

  RETURN jsonb_build_object(
    'user_stats', COALESCE(v_user_stats, '{}'::jsonb),
    'user_buff', COALESCE(v_user_buff, jsonb_build_object('multiplier', 1))
  );
END;
$$;

-- =============================================================================
-- get_user_buff: Get user's current buff multiplier
-- Called by: SupabaseService.getUserBuff()
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_user_buff(p_user_id UUID)
RETURNS jsonb
LANGUAGE sql STABLE
AS $$
  SELECT jsonb_build_object(
    'multiplier', COALESCE(buff_multiplier, 1),
    'base_buff', COALESCE(buff_multiplier, 1),
    'all_range_bonus', 0,
    'reason', CASE
      WHEN buff_multiplier IS NULL THEN 'Default'
      WHEN is_elite THEN 'Elite'
      WHEN is_district_leader THEN 'District Leader'
      WHEN has_province_range THEN 'Province Range'
      ELSE 'Base'
    END
  )
  FROM public.daily_buff_stats
  WHERE user_id = p_user_id AND date = CURRENT_DATE
  LIMIT 1;
$$;

-- =============================================================================
-- get_leaderboard: Global rankings by season points
-- Called by: SupabaseService.getLeaderboard()
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_leaderboard(p_limit INTEGER DEFAULT 20)
RETURNS SETOF jsonb
LANGUAGE sql STABLE
AS $$
  SELECT to_jsonb(sub) FROM (
    SELECT
      u.id,
      u.name,
      u.team,
      u.avatar,
      u.season_points,
      u.total_distance_km,
      u.avg_pace_min_per_km,
      u.avg_cv,
      u.home_hex,
      u.home_hex_end,
      u.manifesto,
      u.total_runs,
      ROW_NUMBER() OVER (ORDER BY u.season_points DESC) AS rank
    FROM public.users u
    WHERE u.season_points > 0
    ORDER BY u.season_points DESC
    LIMIT p_limit
  ) sub;
$$;

-- =============================================================================
-- get_scoped_leaderboard: Province-scoped rankings
-- Called by: PrefetchService._downloadLeaderboardData()
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_scoped_leaderboard(
  p_parent_hex TEXT,
  p_scope_resolution INTEGER,
  p_limit INTEGER DEFAULT 100
)
RETURNS SETOF jsonb
LANGUAGE sql STABLE
AS $$
  SELECT to_jsonb(sub) FROM (
    SELECT
      u.id AS user_id,
      u.name,
      u.avatar,
      u.team,
      u.season_points AS flip_points,
      u.total_distance_km,
      u.avg_pace_min_per_km,
      u.home_hex,
      u.manifesto,
      u.nationality,
      CASE WHEN u.avg_cv IS NOT NULL
        THEN (100 - u.avg_cv)::INTEGER
        ELSE NULL END AS stability_score
    FROM public.users u
    WHERE u.season_points > 0
      AND u.home_hex IS NOT NULL
    ORDER BY u.season_points DESC
    LIMIT p_limit
  ) sub;
$$;

-- =============================================================================
-- get_season_leaderboard: Historical season rankings
-- Called by: SupabaseService.getSeasonLeaderboard()
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_season_leaderboard(
  p_season_number INTEGER,
  p_limit INTEGER DEFAULT 200
)
RETURNS SETOF jsonb
LANGUAGE sql STABLE
AS $$
  -- Note: Implementation depends on how season history is stored.
  -- Placeholder returns current season data.
  SELECT to_jsonb(sub) FROM (
    SELECT
      u.id,
      u.name,
      u.team,
      u.avatar,
      u.season_points,
      u.total_distance_km,
      u.avg_pace_min_per_km,
      u.avg_cv,
      u.home_hex,
      u.manifesto,
      u.total_runs,
      ROW_NUMBER() OVER (ORDER BY u.season_points DESC) AS rank
    FROM public.users u
    WHERE u.season_points > 0
    ORDER BY u.season_points DESC
    LIMIT p_limit
  ) sub;
$$;

-- =============================================================================
-- get_hex_snapshot: Download daily hex snapshot for prefetch
-- Called by: SupabaseService.getHexSnapshot()
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_hex_snapshot(
  p_parent_hex TEXT,
  p_snapshot_date DATE DEFAULT NULL
)
RETURNS SETOF jsonb
LANGUAGE sql STABLE
AS $$
  SELECT to_jsonb(sub) FROM (
    SELECT
      hs.hex_id,
      hs.last_runner_team,
      hs.last_run_end_time
    FROM public.hex_snapshot hs
    WHERE hs.parent_hex = p_parent_hex
      AND hs.snapshot_date = COALESCE(p_snapshot_date, CURRENT_DATE)
  ) sub;
$$;

-- =============================================================================
-- get_hexes_delta: Delta sync for hex changes since a timestamp
-- Called by: SupabaseService.getHexesDelta()
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_hexes_delta(
  p_parent_hex TEXT,
  p_since_time TIMESTAMPTZ DEFAULT NULL
)
RETURNS SETOF jsonb
LANGUAGE sql STABLE
AS $$
  SELECT to_jsonb(sub) FROM (
    SELECT
      h.id AS hex_id,
      h.last_runner_team,
      h.last_flipped_at
    FROM public.hexes h
    WHERE h.parent_hex = p_parent_hex
      AND (p_since_time IS NULL OR h.last_flipped_at > p_since_time)
  ) sub;
$$;

-- =============================================================================
-- get_user_yesterday_stats: Yesterday's run stats for a user
-- Called by: SupabaseService.getUserYesterdayStats()
-- Accepts optional p_date (client-computed GMT+2 yesterday) for timezone safety.
-- Falls back to server-computed yesterday if not provided.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_user_yesterday_stats(
  p_user_id UUID,
  p_date DATE DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql STABLE
AS $$
  SELECT jsonb_build_object(
    'has_data', COUNT(*) > 0,
    'date', COALESCE(p_date, (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE - INTERVAL '1 day')::TEXT,
    'run_count', COUNT(*),
    'distance_km', COALESCE(SUM(distance_km), 0),
    'duration_seconds', COALESCE(SUM(duration_seconds), 0),
    'flip_points', COALESCE(SUM(flip_points), 0),
    'avg_cv', AVG(cv)
  )
  FROM public.run_history
  WHERE user_id = p_user_id
    AND run_date = COALESCE(p_date, (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE - INTERVAL '1 day');
$$;

-- =============================================================================
-- get_team_rankings: Team rankings with district/province context
-- Called by: SupabaseService.getTeamRankings()
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_team_rankings(
  p_user_id UUID,
  p_city_hex TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql STABLE
AS $$
  SELECT jsonb_build_object(
    'red_points', COALESCE(SUM(CASE WHEN team = 'red' THEN season_points ELSE 0 END), 0),
    'blue_points', COALESCE(SUM(CASE WHEN team = 'blue' THEN season_points ELSE 0 END), 0),
    'purple_points', COALESCE(SUM(CASE WHEN team = 'purple' THEN season_points ELSE 0 END), 0),
    'red_runners', COUNT(CASE WHEN team = 'red' THEN 1 END),
    'blue_runners', COUNT(CASE WHEN team = 'blue' THEN 1 END),
    'purple_runners', COUNT(CASE WHEN team = 'purple' THEN 1 END)
  )
  FROM public.users
  WHERE season_points > 0;
$$;

-- =============================================================================
-- get_hex_dominance: Hex count per team
-- Called by: SupabaseService.getHexDominance()
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_hex_dominance(
  p_city_hex TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql STABLE
AS $$
  SELECT jsonb_build_object(
    'red_hexes', COUNT(CASE WHEN last_runner_team = 'red' THEN 1 END),
    'blue_hexes', COUNT(CASE WHEN last_runner_team = 'blue' THEN 1 END),
    'purple_hexes', COUNT(CASE WHEN last_runner_team = 'purple' THEN 1 END),
    'total_hexes', COUNT(*)
  )
  FROM public.hexes
  WHERE p_city_hex IS NULL OR parent_hex = p_city_hex;
$$;

-- =============================================================================
-- Edge Functions (cron jobs, not RPC - documented for reference)
-- =============================================================================

-- build_daily_hex_snapshot(): Runs daily at midnight GMT+2
--   Copies current hexes table state into hex_snapshot for the next day.
--   INSERT INTO hex_snapshot (hex_id, last_runner_team, snapshot_date, last_run_end_time, parent_hex)
--   SELECT id, last_runner_team, CURRENT_DATE + 1, last_flipped_at, parent_hex
--   FROM hexes WHERE last_runner_team IS NOT NULL;

-- calculate_daily_buffs(): Runs daily at midnight GMT+2
--   Computes buff_multiplier for all active users based on team rules:
--   - RED FLAME: Elite (top 20%) + district/province win bonuses
--   - BLUE WAVE: Union bonuses for district/province wins
--   - PURPLE CHAOS: Participation rate thresholds (30%/60%)
--   INSERT INTO daily_buff_stats (user_id, date, buff_multiplier, ...)
