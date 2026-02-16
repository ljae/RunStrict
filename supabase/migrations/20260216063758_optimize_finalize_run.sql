-- Optimize finalize_run(): Replace per-hex loop with single UNNEST batch
--
-- Before: FOREACH hex IN ARRAY -> SELECT + INSERT per hex (60 queries for 30 hexes)
-- After:  Single UNNEST batch INSERT...ON CONFLICT (1 query for any number of hexes)

CREATE OR REPLACE FUNCTION public.finalize_run(
  p_user_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ,
  p_distance_km DOUBLE PRECISION,
  p_duration_seconds INTEGER,
  p_hex_path TEXT[],
  p_buff_multiplier INTEGER DEFAULT 1,
  p_cv DOUBLE PRECISION DEFAULT NULL,
  p_client_points INTEGER DEFAULT 0,
  p_home_region_flips INTEGER DEFAULT 0,
  p_hex_parents TEXT[] DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_team TEXT;
  v_points INTEGER;
  v_max_allowed_points INTEGER;
  v_flip_count INTEGER;
BEGIN
  -- Get user's team
  SELECT team INTO v_team FROM public.users WHERE id = p_user_id;

  -- [SECURITY] Cap validation: client points <= hex_path_length * buff_multiplier
  v_max_allowed_points := COALESCE(array_length(p_hex_path, 1), 0) * p_buff_multiplier;
  v_points := LEAST(p_client_points, v_max_allowed_points);
  v_flip_count := CASE WHEN p_buff_multiplier > 0
    THEN v_points / p_buff_multiplier ELSE 0 END;

  IF p_client_points > v_max_allowed_points THEN
    RAISE WARNING 'finalize_run: Client claimed % points but max is %. Capped.',
      p_client_points, v_max_allowed_points;
  END IF;

  -- =========================================================================
  -- BATCH update live hexes (replaces per-hex loop with single UNNEST query)
  -- Conflict resolution: later end_time wins
  -- =========================================================================
  IF p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0 THEN
    INSERT INTO public.hexes (id, last_runner_team, last_flipped_at, parent_hex)
    SELECT
      h.hex_id,
      v_team,
      p_end_time,
      CASE
        WHEN p_hex_parents IS NOT NULL AND h.idx <= array_length(p_hex_parents, 1)
        THEN p_hex_parents[h.idx]
        ELSE NULL
      END
    FROM UNNEST(p_hex_path) WITH ORDINALITY AS h(hex_id, idx)
    ON CONFLICT (id) DO UPDATE
    SET last_runner_team = EXCLUDED.last_runner_team,
        last_flipped_at = EXCLUDED.last_flipped_at,
        parent_hex = COALESCE(EXCLUDED.parent_hex, hexes.parent_hex)
    WHERE hexes.last_flipped_at IS NULL
       OR hexes.last_flipped_at < EXCLUDED.last_flipped_at;
  END IF;

  -- =========================================================================
  -- Award cap-validated points & update user aggregates
  -- =========================================================================
  UPDATE public.users SET
    season_points = season_points + v_points,
    home_hex = CASE
      WHEN array_length(p_hex_path, 1) > 0 THEN p_hex_path[1]
      ELSE home_hex END,
    home_hex_end = CASE
      WHEN array_length(p_hex_path, 1) > 0 THEN p_hex_path[array_length(p_hex_path, 1)]
      ELSE home_hex_end END,
    total_distance_km = total_distance_km + p_distance_km,
    total_runs = total_runs + 1,
    avg_pace_min_per_km = CASE
      WHEN p_distance_km > 0 THEN
        (COALESCE(avg_pace_min_per_km, 0) * total_runs
         + (p_duration_seconds / 60.0) / p_distance_km) / (total_runs + 1)
      ELSE avg_pace_min_per_km
    END,
    avg_cv = CASE
      WHEN p_cv IS NOT NULL THEN
        (COALESCE(avg_cv, 0) * cv_run_count + p_cv) / (cv_run_count + 1)
      ELSE avg_cv
    END,
    cv_run_count = CASE
      WHEN p_cv IS NOT NULL THEN cv_run_count + 1
      ELSE cv_run_count END
  WHERE id = p_user_id;

  -- =========================================================================
  -- Insert lightweight run history (PRESERVED across seasons)
  -- =========================================================================
  INSERT INTO public.run_history (
    user_id, run_date, start_time, end_time,
    distance_km, duration_seconds, avg_pace_min_per_km,
    flip_count, flip_points, team_at_run, cv
  ) VALUES (
    p_user_id,
    (p_end_time AT TIME ZONE 'Etc/GMT-2')::DATE,
    p_start_time, p_end_time,
    p_distance_km, p_duration_seconds,
    CASE WHEN p_distance_km > 0
      THEN (p_duration_seconds / 60.0) / p_distance_km
      ELSE NULL END,
    v_flip_count, v_points, v_team, p_cv
  );

  -- Return summary
  RETURN jsonb_build_object(
    'flips', v_flip_count,
    'multiplier', p_buff_multiplier,
    'points_earned', v_points,
    'server_validated', true
  );
END;
$$;
