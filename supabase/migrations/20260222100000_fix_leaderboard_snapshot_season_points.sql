-- Fix: Use users.season_points for leaderboard ranking instead of
-- SUM(run_history.flip_points) which includes data from previous seasons.
-- Also use users table aggregate fields directly (maintained by finalize_run()),
-- eliminating the run_history JOIN entirely for better performance.

CREATE OR REPLACE FUNCTION public.snapshot_season_leaderboard(p_season_number integer)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
AS $function$
DECLARE
  v_count INT;
BEGIN
  DELETE FROM season_leaderboard_snapshot
  WHERE season_number = p_season_number;

  INSERT INTO season_leaderboard_snapshot (
    season_number, rank, user_id, name, team, avatar, manifesto,
    season_points, total_distance_km, avg_pace_min_per_km, avg_cv,
    home_hex, home_hex_end, nationality, total_runs
  )
  SELECT
    p_season_number,
    ROW_NUMBER() OVER (
      ORDER BY u.season_points DESC, u.name ASC
    )::INT AS rank,
    u.id AS user_id,
    u.name,
    u.team,
    u.avatar,
    u.manifesto,
    u.season_points,
    ROUND(u.total_distance_km::NUMERIC, 2)::FLOAT8,
    ROUND(COALESCE(u.avg_pace_min_per_km, 0)::NUMERIC, 2)::FLOAT8,
    ROUND(COALESCE(u.avg_cv, 0)::NUMERIC, 1)::FLOAT8,
    u.home_hex,
    u.home_hex_end,
    u.nationality,
    u.total_runs
  FROM users u
  WHERE u.season_points > 0
  ORDER BY u.season_points DESC, u.name ASC;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$function$;
