-- Migration: 013_delta_sync_hexes.sql
-- Description: Add RPC function for delta sync of hexes
-- This allows clients to fetch only hexes modified since their last prefetch,
-- reducing bandwidth usage significantly.

-- Drop existing function if it exists (to handle signature change)
DROP FUNCTION IF EXISTS get_hexes_delta(TEXT, TIMESTAMPTZ);

-- RPC that returns hexes, optionally filtered by modification time
-- Used by PrefetchService for both full download (NULL) and delta sync
CREATE OR REPLACE FUNCTION get_hexes_delta(
  p_parent_hex TEXT,
  p_since_time TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
  hex_id TEXT,
  last_runner_team TEXT,
  last_flipped_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_since_time IS NULL THEN
    -- Full download (first time or fallback)
    RETURN QUERY
    SELECT h.hex_id, h.last_runner_team, h.last_flipped_at
    FROM hexes h
    WHERE h.parent_hex = p_parent_hex;
  ELSE
    -- Delta: only hexes changed since last sync
    RETURN QUERY
    SELECT h.hex_id, h.last_runner_team, h.last_flipped_at
    FROM hexes h
    WHERE h.parent_hex = p_parent_hex
      AND h.last_flipped_at > p_since_time;
  END IF;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_hexes_delta(TEXT, TIMESTAMPTZ) TO authenticated;

COMMENT ON FUNCTION get_hexes_delta IS 
  'Returns hexes for delta sync. Pass NULL for p_since_time to get all hexes (full download).
   Pass a timestamp to get only hexes modified since that time (delta sync).
   Reduces bandwidth by only fetching changed hexes instead of all ~3,800 hexes.';
