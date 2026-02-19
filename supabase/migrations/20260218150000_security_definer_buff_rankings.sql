-- Make RPC functions SECURITY DEFINER so they bypass RLS.
-- These functions need to read ALL users' run_history and users tables
-- to compute rankings and elite status across the district, not just
-- the calling user's own rows.

-- get_user_buff: needs to count all RED runners in district, rank them
ALTER FUNCTION public.get_user_buff(uuid) SECURITY DEFINER;

-- get_team_rankings: needs to rank all RED runners in district
ALTER FUNCTION public.get_team_rankings(uuid, text) SECURITY DEFINER;

-- app_launch_sync: delegates to get_user_buff internally
ALTER FUNCTION public.app_launch_sync(uuid) SECURITY DEFINER;
