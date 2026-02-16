-- Fix: Add SECURITY DEFINER to get_scoped_leaderboard
-- The DROP + CREATE lost the SECURITY DEFINER attribute, causing RLS to block reads
ALTER FUNCTION public.get_scoped_leaderboard(TEXT, INTEGER, INTEGER) SECURITY DEFINER;
