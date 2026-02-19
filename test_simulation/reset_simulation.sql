-- ============================================================
-- RunStrict: FULL Data Wipe + Reset
-- ============================================================
-- Wipes ALL season data. Preserves real user accounts only.
-- Usage: Paste into Supabase SQL Editor or run via psql
-- ============================================================

-- 1. Wipe ALL run history
DELETE FROM public.run_history;

-- 2. Wipe ALL daily buff stats
DELETE FROM public.daily_buff_stats;

-- 3. Wipe ALL daily range stats
DELETE FROM public.daily_all_range_stats;

-- 4. Wipe ALL hexes
DELETE FROM public.hexes;

-- 5. Wipe ALL hex snapshots
DELETE FROM public.hex_snapshot;

-- 6. Wipe ALL leaderboard snapshots
DELETE FROM public.season_leaderboard_snapshot;

-- 7. Delete simulation users
DELETE FROM public.users WHERE id::text LIKE 'aaaaaaaa-%';

-- 8. Delete simulation auth entries
DELETE FROM auth.users WHERE id::text LIKE 'aaaaaaaa-%';

-- 9. Reset real users' season data
UPDATE public.users SET
  season_points = 0,
  total_distance_km = 0,
  avg_pace_min_per_km = NULL,
  avg_cv = NULL,
  cv_run_count = 0,
  total_runs = 0,
  season_home_hex = NULL
WHERE id::text NOT LIKE 'aaaaaaaa-%';

-- ===== VERIFY (all should be 0 except real users) =====
SELECT 'Real users' as check_name, count(*) as count FROM public.users WHERE id::text NOT LIKE 'aaaaaaaa-%'
UNION ALL SELECT 'Sim users', count(*) FROM public.users WHERE id::text LIKE 'aaaaaaaa-%'
UNION ALL SELECT 'run_history', count(*) FROM public.run_history
UNION ALL SELECT 'hexes', count(*) FROM public.hexes
UNION ALL SELECT 'hex_snapshot', count(*) FROM public.hex_snapshot
UNION ALL SELECT 'daily_buff_stats', count(*) FROM public.daily_buff_stats
UNION ALL SELECT 'leaderboard_snapshot', count(*) FROM public.season_leaderboard_snapshot;
