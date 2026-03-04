-- =============================================================================
-- Fix get_season_leaderboard() — read from season_leaderboard_snapshot
-- =============================================================================
-- PROBLEM: get_season_leaderboard(p_season_number) completely ignored
--   p_season_number and always returned current LIVE users data. Navigating
--   to a past season via < > arrows always showed the current season's data.
--
-- FIX: Query season_leaderboard_snapshot WHERE season_number = p_season_number.
--   Returns the same JSON shape as get_leaderboard() so LeaderboardEntry.fromJson
--   and UserModel.fromRow parse without changes.
--
-- JSON SHAPE NOTES:
--   - user_id aliased to 'id' (UserModel.fromRow reads 'id')
--   - rank included (provider reads json['rank'] directly: line 338 of provider)
--   - district_hex returned as NULL (snapshot table lacks this column;
--     LeaderboardEntry.fromJson reads it as String? — null is safe, province
--     filtering falls back to homeHex)
--   - RETURNS TABLE(...) is compatible with Dart's
--     List<Map<String,dynamic>>.from(result as List) via PostgREST serialization
-- =============================================================================

DROP FUNCTION IF EXISTS public.get_season_leaderboard(INTEGER, INTEGER);

CREATE FUNCTION public.get_season_leaderboard(
  p_season_number INTEGER,
  p_limit         INTEGER DEFAULT 200
)
RETURNS TABLE (
  id                  UUID,
  name                TEXT,
  team                TEXT,
  avatar              TEXT,
  season_points       INT,
  total_distance_km   FLOAT8,
  avg_pace_min_per_km FLOAT8,
  avg_cv              FLOAT8,
  home_hex            TEXT,
  home_hex_end        TEXT,
  manifesto           TEXT,
  nationality         TEXT,
  total_runs          INT,
  rank                BIGINT,
  district_hex        TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    s.user_id            AS id,
    s.name,
    s.team,
    s.avatar,
    s.season_points,
    s.total_distance_km,
    s.avg_pace_min_per_km,
    s.avg_cv,
    s.home_hex,
    s.home_hex_end,
    s.manifesto,
    s.nationality,
    s.total_runs,
    s.rank::BIGINT       AS rank,
    NULL::TEXT           AS district_hex
  FROM public.season_leaderboard_snapshot s
  WHERE s.season_number = p_season_number
  ORDER BY s.rank ASC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_season_leaderboard(INTEGER, INTEGER)
  TO authenticated, anon;

NOTIFY pgrst, 'reload schema';
