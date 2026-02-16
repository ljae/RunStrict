-- Scoped season leaderboard RPC for historical season browsing.
-- Returns ranked users from season_leaderboard_snapshot.
-- When p_parent_hex is provided, filters to users whose home_hex
-- shares the same H3 parent (province-level filtering done client-side
-- for now since snapshot is small ≤200 entries).
CREATE OR REPLACE FUNCTION get_season_scoped_leaderboard(
  p_season_number INT,
  p_parent_hex TEXT DEFAULT NULL,
  p_limit INT DEFAULT 50
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
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.rank::INT,
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
