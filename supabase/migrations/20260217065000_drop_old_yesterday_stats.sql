-- Drop the old 1-param overload that conflicts with the new 2-param version
DROP FUNCTION IF EXISTS public.get_user_yesterday_stats(UUID);
