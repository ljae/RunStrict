-- =============================================================================
-- Fix snapshot_season_leaderboard() — date-bounded via run_history
-- =============================================================================
-- PROBLEM: Previous version read users.season_points + users.team directly.
--   These are LIVE fields reset to 0/NULL on season transition. Calling the old
--   function after a reset produced an empty or corrupt snapshot.
--
-- FIX: Compute season date bounds from app_config and read from run_history
--   with explicit run_date filters. Uses team_at_run (preserved across seasons)
--   instead of users.team (reset). Safe to call at any time — retroactively,
--   on-time, or late.
--
-- INVARIANT: season_start = startDate + (season_number - baseSeasonNumber) * durationDays
--            snapshot only includes users with flip_points > 0 in that date range
-- =============================================================================

CREATE OR REPLACE FUNCTION public.snapshot_season_leaderboard(p_season_number INT)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_cfg          JSONB;
  v_duration     INT;
  v_base_season  INT;
  v_start_date   DATE;
  v_season_start DATE;
  v_season_end   DATE;  -- exclusive upper bound (run_date < v_season_end)
  v_count        INT;
BEGIN
  -- Read season config from app_config with hardcoded fallbacks
  SELECT config_data->'season' INTO v_cfg FROM app_config LIMIT 1;
  v_duration    := COALESCE((v_cfg->>'durationDays')::INT,  5);
  v_base_season := COALESCE((v_cfg->>'seasonNumber')::INT,  2);
  v_start_date  := COALESCE((v_cfg->>'startDate')::DATE, '2026-02-11'::DATE);

  -- Compute GMT+2 date range for the requested season
  -- Example: S5 = start_date + (5-2)*5 = Feb11 + 15 = Feb26, end = Mar3 (exclusive)
  v_season_start := v_start_date + ((p_season_number - v_base_season) * v_duration);
  v_season_end   := v_season_start + v_duration;

  -- Idempotent: remove any existing snapshot for this season
  DELETE FROM season_leaderboard_snapshot WHERE season_number = p_season_number;

  -- Insert ranked snapshot from run_history (date-bounded, season-isolated)
  -- Team: from most recent run in this season (team_at_run survives resets)
  -- Fallback: current users.team (handles edge case of no runs with team data)
  INSERT INTO season_leaderboard_snapshot (
    season_number, rank, user_id, name, team, avatar, manifesto,
    season_points, total_distance_km, avg_pace_min_per_km, avg_cv,
    home_hex, home_hex_end, nationality, total_runs
  )
  SELECT
    p_season_number,
    ROW_NUMBER() OVER (
      ORDER BY COALESCE(SUM(rh.flip_points), 0) DESC, u.name ASC
    )::INT AS rank,
    u.id AS user_id,
    u.name,
    COALESCE(
      (SELECT rh2.team_at_run
       FROM run_history rh2
       WHERE rh2.user_id = u.id
         AND rh2.run_date >= v_season_start
         AND rh2.run_date < v_season_end
       ORDER BY rh2.end_time DESC
       LIMIT 1),
      u.team
    ) AS team,
    u.avatar,
    u.manifesto,
    COALESCE(SUM(rh.flip_points), 0)::INT AS season_points,
    ROUND(COALESCE(SUM(rh.distance_km), 0)::NUMERIC, 2)::FLOAT8 AS total_distance_km,
    ROUND(COALESCE(AVG(NULLIF(rh.avg_pace_min_per_km, 0)), 0)::NUMERIC, 2)::FLOAT8
      AS avg_pace_min_per_km,
    ROUND(COALESCE(AVG(NULLIF(rh.cv, 0)), 0)::NUMERIC, 1)::FLOAT8 AS avg_cv,
    u.home_hex,
    u.home_hex_end,
    u.nationality,
    COALESCE(COUNT(rh.id), 0)::INT AS total_runs
  FROM users u
  LEFT JOIN run_history rh
    ON rh.user_id = u.id
    AND rh.run_date >= v_season_start
    AND rh.run_date < v_season_end
  WHERE COALESCE(
    (SELECT SUM(rh3.flip_points)
     FROM run_history rh3
     WHERE rh3.user_id = u.id
       AND rh3.run_date >= v_season_start
       AND rh3.run_date < v_season_end), 0
  ) > 0
  GROUP BY u.id, u.name, u.avatar, u.manifesto,
           u.home_hex, u.home_hex_end, u.nationality, u.team
  ORDER BY season_points DESC, u.name ASC;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.snapshot_season_leaderboard(INT)
  TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
