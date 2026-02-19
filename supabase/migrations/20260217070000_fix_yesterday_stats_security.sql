-- Fix: Add SECURITY DEFINER to get_user_yesterday_stats
-- RLS on run_history restricts SELECT to own rows only.
-- This RPC needs to read any user's yesterday stats (for team screen).
ALTER FUNCTION public.get_user_yesterday_stats(UUID, DATE) SECURITY DEFINER;
