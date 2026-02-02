-- RunStrict: Add today_flip_points to app_launch_sync
-- All day boundaries use GMT+2 (server timezone) for consistency
--
-- Data Engineering Principle:
-- "Today" is defined by GMT+2 midnight, not user's local timezone.
-- This ensures all users see the same day boundary regardless of location.

-- ============================================================
-- 1. UPDATE APP_LAUNCH_SYNC TO INCLUDE TODAY'S FLIP POINTS
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
  v_user_buff JSONB;
  v_hex_map JSONB := '[]'::JSONB;
  v_leaderboard JSONB := '[]'::JSONB;
  v_today_flip_points INTEGER := 0;
  v_server_timezone_offset INTEGER := 2;
  v_today_gmt2 DATE;
BEGIN
  -- Calculate "today" in GMT+2 timezone
  -- NOW() AT TIME ZONE 'UTC' + 2 hours = GMT+2 time
  v_today_gmt2 := (NOW() AT TIME ZONE 'UTC' + INTERVAL '2 hours')::DATE;

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
  
  -- Get user buff
  v_user_buff := public.get_user_buff(p_user_id);
  
  -- Get TODAY's flip points (based on GMT+2 day boundary)
  SELECT COALESCE(SUM(rh.flip_points), 0)
  INTO v_today_flip_points
  FROM public.run_history rh
  WHERE rh.user_id = p_user_id
    AND rh.run_date = v_today_gmt2;
  
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
  
  -- Return combined response with today_flip_points
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
    'today_flip_points', v_today_flip_points,
    'hex_map', v_hex_map,
    'leaderboard', v_leaderboard,
    'server_time', now(),
    'server_date_gmt2', v_today_gmt2
  );
END;
$$;

COMMENT ON FUNCTION public.app_launch_sync IS 
'Fetches user profile, buff, today flip points (GMT+2), hex map, and leaderboard.
today_flip_points: Points earned today based on GMT+2 day boundary.
server_date_gmt2: Current date in GMT+2 timezone for client reference.';
