-- Function 1: Freeze current leaderboard into snapshot table
CREATE OR REPLACE FUNCTION snapshot_season_leaderboard(p_season_number INT)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INT;
BEGIN
  -- Prevent duplicate snapshots
  IF EXISTS (
    SELECT 1 FROM season_leaderboard_snapshot
    WHERE season_number = p_season_number
    LIMIT 1
  ) THEN
    RAISE EXCEPTION 'Snapshot for season % already exists', p_season_number;
  END IF;

  -- Insert ranked leaderboard data into snapshot
  INSERT INTO season_leaderboard_snapshot (
    season_number, rank, user_id, name, team, avatar, manifesto,
    season_points, total_distance_km, avg_pace_min_per_km, avg_cv, home_hex
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
    u.home_hex
  FROM users u
  LEFT JOIN run_history rh ON rh.user_id = u.id
  WHERE COALESCE(
    (SELECT SUM(rh2.flip_points) FROM run_history rh2 WHERE rh2.user_id = u.id), 0
  ) > 0
  GROUP BY u.id, u.name, u.team, u.avatar, u.manifesto, u.home_hex
  ORDER BY season_points DESC, u.name ASC;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Function 2: Read historical leaderboard from snapshot
CREATE OR REPLACE FUNCTION get_season_leaderboard(
  p_season_number INT,
  p_limit INT DEFAULT 200
)
RETURNS TABLE (
  rank INT,
  id UUID,
  name TEXT,
  team TEXT,
  avatar TEXT,
  manifesto TEXT,
  season_points INT,
  total_distance_km FLOAT8,
  avg_pace_min_per_km FLOAT8,
  avg_cv FLOAT8,
  home_hex TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.rank,
    s.user_id AS id,
    s.name,
    s.team,
    s.avatar,
    s.manifesto,
    s.season_points,
    s.total_distance_km,
    s.avg_pace_min_per_km,
    s.avg_cv,
    s.home_hex
  FROM season_leaderboard_snapshot s
  WHERE s.season_number = p_season_number
  ORDER BY s.rank ASC
  LIMIT p_limit;
END;
$$;
