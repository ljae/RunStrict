-- Fix get_team_rankings() to return complete data:
--   1. Query run_history for yesterday's flip_points per user in district
--   2. Rank RED runners to build elite top 3 list
--   3. Determine current user's rank and elite status
--   4. Return elite threshold and user's yesterday points
-- Also removes red_common_top3 and blue_union_top3 (unused by client).

CREATE OR REPLACE FUNCTION public.get_team_rankings(
  p_user_id UUID,
  p_city_hex TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_user RECORD;
  v_city_hex TEXT;
  v_yesterday DATE;
  v_red_runner_count INTEGER := 0;
  v_elite_cutoff_rank INTEGER := 0;
  v_elite_threshold INTEGER := 0;
  v_user_yesterday_points INTEGER := 0;
  v_user_rank INTEGER := 0;
  v_user_is_elite BOOLEAN := false;
  v_elite_top3 jsonb := '[]'::jsonb;
BEGIN
  -- Get user info
  SELECT team, district_hex INTO v_user
  FROM public.users WHERE id = p_user_id;

  -- Use provided city_hex or user's district_hex
  v_city_hex := COALESCE(p_city_hex, v_user.district_hex);

  -- Yesterday in server timezone (GMT+2)
  v_yesterday := (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE - INTERVAL '1 day';

  -- Count RED runners who ran yesterday in this district
  SELECT COUNT(DISTINCT rh.user_id) INTO v_red_runner_count
  FROM public.run_history rh
  JOIN public.users u ON u.id = rh.user_id
  WHERE u.team = 'red'
    AND rh.run_date = v_yesterday
    AND (v_city_hex IS NULL OR u.district_hex = v_city_hex);

  -- Elite cutoff = top 20% (at least 1)
  v_elite_cutoff_rank := GREATEST(1, (v_red_runner_count * 0.2)::INTEGER);

  IF v_red_runner_count > 0 THEN
    -- Build ranked list of RED runners by yesterday's total flip_points in district
    -- Then extract elite threshold, user rank, and top 3

    -- Get elite threshold (the flip_points at the cutoff rank)
    SELECT COALESCE(sub.total_points, 0) INTO v_elite_threshold
    FROM (
      SELECT
        rh.user_id,
        SUM(rh.flip_points) AS total_points,
        ROW_NUMBER() OVER (ORDER BY SUM(rh.flip_points) DESC) AS rn
      FROM public.run_history rh
      JOIN public.users u ON u.id = rh.user_id
      WHERE u.team = 'red'
        AND rh.run_date = v_yesterday
        AND (v_city_hex IS NULL OR u.district_hex = v_city_hex)
      GROUP BY rh.user_id
    ) sub
    WHERE sub.rn = v_elite_cutoff_rank;

    v_elite_threshold := COALESCE(v_elite_threshold, 0);

    -- Get user's yesterday points and rank
    SELECT sub.total_points, sub.rn INTO v_user_yesterday_points, v_user_rank
    FROM (
      SELECT
        rh.user_id,
        SUM(rh.flip_points) AS total_points,
        ROW_NUMBER() OVER (ORDER BY SUM(rh.flip_points) DESC) AS rn
      FROM public.run_history rh
      JOIN public.users u ON u.id = rh.user_id
      WHERE u.team = 'red'
        AND rh.run_date = v_yesterday
        AND (v_city_hex IS NULL OR u.district_hex = v_city_hex)
      GROUP BY rh.user_id
    ) sub
    WHERE sub.user_id = p_user_id;

    v_user_yesterday_points := COALESCE(v_user_yesterday_points, 0);
    v_user_rank := COALESCE(v_user_rank, 0);

    -- User is elite if they have points >= threshold AND actually ran
    v_user_is_elite := (v_user_yesterday_points >= v_elite_threshold
                        AND v_user_yesterday_points > 0
                        AND v_user_rank > 0);

    -- Build elite top 3 (runners at or above elite threshold)
    SELECT COALESCE(jsonb_agg(row_to_json(sub)::jsonb), '[]'::jsonb)
    INTO v_elite_top3
    FROM (
      SELECT
        rh.user_id,
        u.name,
        SUM(rh.flip_points)::INTEGER AS yesterday_points,
        ROW_NUMBER() OVER (ORDER BY SUM(rh.flip_points) DESC)::INTEGER AS rank
      FROM public.run_history rh
      JOIN public.users u ON u.id = rh.user_id
      WHERE u.team = 'red'
        AND rh.run_date = v_yesterday
        AND (v_city_hex IS NULL OR u.district_hex = v_city_hex)
      GROUP BY rh.user_id, u.name
      HAVING SUM(rh.flip_points) >= v_elite_threshold
      ORDER BY SUM(rh.flip_points) DESC
      LIMIT 3
    ) sub;
  END IF;

  RETURN jsonb_build_object(
    'user_team', COALESCE(v_user.team, ''),
    'user_is_elite', v_user_is_elite,
    'user_yesterday_points', v_user_yesterday_points,
    'user_rank', CASE WHEN v_user_rank > 0 THEN v_user_rank ELSE 0 END,
    'elite_threshold', v_elite_threshold,
    'city_hex', v_city_hex,
    'red_elite_top3', v_elite_top3,
    'red_runner_count_city', v_red_runner_count,
    'elite_cutoff_rank', v_elite_cutoff_rank
  );
END;
$$;
