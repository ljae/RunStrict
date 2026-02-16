-- Cleanup test function
DROP FUNCTION IF EXISTS public.test_leaderboard_count();
NOTIFY pgrst, 'reload schema';
