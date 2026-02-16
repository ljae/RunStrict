-- Minimal test function
CREATE OR REPLACE FUNCTION public.test_leaderboard_count()
RETURNS jsonb
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'total_users', (SELECT count(*) FROM public.users),
    'with_points', (SELECT count(*) FROM public.users WHERE season_points > 0),
    'with_home', (SELECT count(*) FROM public.users WHERE home_hex IS NOT NULL),
    'both', (SELECT count(*) FROM public.users WHERE season_points > 0 AND home_hex IS NOT NULL)
  );
$$;

NOTIFY pgrst, 'reload schema';
