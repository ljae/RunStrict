-- ============================================================
-- RunStrict: Reset Simulation Data
-- ============================================================
-- Clears ALL season data to prepare for a fresh day-by-day simulation.
-- Preserves: real user accounts (non aaaaaaaa-* prefix)
--            real user run_history
--
-- Usage: Paste into Supabase SQL Editor and execute before starting simulation
-- https://supabase.com/dashboard/project/vhooaslzkmbnzmzwiium/sql
-- ============================================================

BEGIN;

-- 1. Delete simulation user run_history
DELETE FROM public.run_history
WHERE user_id IN (SELECT id FROM public.users WHERE id::text LIKE 'aaaaaaaa-%');

-- 2. Delete simulation users
DELETE FROM public.users WHERE id::text LIKE 'aaaaaaaa-%';

-- 2b. Delete simulation auth entries
DELETE FROM auth.users WHERE id::text LIKE 'aaaaaaaa-%';

-- 3. Wipe ALL hex colors (hexes are season-scoped, no ownership to preserve)
TRUNCATE public.hexes;

-- 4. Clear daily flips
TRUNCATE public.daily_flips;

-- 5. Clear active runs
TRUNCATE public.active_runs;

-- 6. Reset real users' season data (if any exist) but keep their accounts
UPDATE public.users SET
  season_points = 0,
  total_distance_km = 0,
  avg_pace_min_per_km = NULL,
  avg_cv = NULL,
  total_runs = 0,
  season_home_hex = NULL
WHERE id::text NOT LIKE 'aaaaaaaa-%';

COMMIT;

-- Verify cleanup
SELECT 'Users remaining' as check_name, count(*) as count FROM public.users
UNION ALL
SELECT 'Sim users remaining', count(*) FROM public.users WHERE id::text LIKE 'aaaaaaaa-%'
UNION ALL
SELECT 'Hexes remaining', count(*) FROM public.hexes
UNION ALL
SELECT 'Run history (sim)', count(*) FROM public.run_history WHERE user_id IN (SELECT id FROM public.users WHERE id::text LIKE 'aaaaaaaa-%')
UNION ALL
SELECT 'Run history (real)', count(*) FROM public.run_history WHERE user_id NOT IN (SELECT id FROM public.users WHERE id::text LIKE 'aaaaaaaa-%');
