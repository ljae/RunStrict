-- Make snapshot_season_leaderboard() idempotent by replacing the
-- "raise exception if exists" guard with a DELETE + re-INSERT pattern.
-- This allows the midnight cron to safely retry without manual cleanup.

CREATE OR REPLACE FUNCTION public.snapshot_season_leaderboard(p_season_number integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_count INT;
BEGIN
  -- Delete existing snapshot for this season (idempotent)
  DELETE FROM season_leaderboard_snapshot
  WHERE season_number = p_season_number;

  -- Insert ranked leaderboard data into snapshot
  INSERT INTO season_leaderboard_snapshot (
    season_number, rank, user_id, name, team, avatar, manifesto,
    season_points, total_distance_km, avg_pace_min_per_km, avg_cv, home_hex,
    home_hex_end, nationality, total_runs
  )
  SELECT
    p_season_number,
    ROW_NUMBER() OVER (
      ORDER BY COALESCE(SUM(rh.flip_points), 0) DESC, u.name ASC
    )::INT AS rank,
    u.id AS user_id,
    u.name,
    u.team,
    u.avatar,
    u.manifesto,
    COALESCE(SUM(rh.flip_points), 0)::INT AS season_points,
    ROUND(COALESCE(SUM(rh.distance_km), 0)::NUMERIC, 2)::FLOAT8 AS total_distance_km,
    ROUND(COALESCE(AVG(NULLIF(rh.avg_pace_min_per_km, 0)), 0)::NUMERIC, 2)::FLOAT8 AS avg_pace_min_per_km,
    ROUND(COALESCE(AVG(NULLIF(rh.cv, 0)), 0)::NUMERIC, 1)::FLOAT8 AS avg_cv,
    u.home_hex,
    u.home_hex_end,
    u.nationality,
    COALESCE(COUNT(rh.id), 0)::INT AS total_runs
  FROM users u
  LEFT JOIN run_history rh ON rh.user_id = u.id
  WHERE COALESCE(
    (SELECT SUM(rh2.flip_points) FROM run_history rh2 WHERE rh2.user_id = u.id), 0
  ) > 0
  GROUP BY u.id, u.name, u.team, u.avatar, u.manifesto, u.home_hex, u.home_hex_end, u.nationality
  ORDER BY season_points DESC, u.name ASC;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$function$;
