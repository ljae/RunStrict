-- Fix get_user_yesterday_stats: accept client-computed date for timezone safety
-- and align response field names with client model (YesterdayStats.fromJson).
CREATE OR REPLACE FUNCTION public.get_user_yesterday_stats(
  p_user_id UUID,
  p_date DATE DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql STABLE
AS $$
  SELECT jsonb_build_object(
    'has_data', COUNT(*) > 0,
    'date', COALESCE(p_date, (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE - INTERVAL '1 day')::TEXT,
    'run_count', COUNT(*),
    'distance_km', COALESCE(SUM(distance_km), 0),
    'duration_seconds', COALESCE(SUM(duration_seconds), 0),
    'flip_points', COALESCE(SUM(flip_points), 0),
    'avg_cv', AVG(cv)
  )
  FROM public.run_history
  WHERE user_id = p_user_id
    AND run_date = COALESCE(p_date, (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE - INTERVAL '1 day');
$$;
