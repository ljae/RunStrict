-- ============================================================
-- Season 2 Setup: "The 40-Day Journey" starts again
-- Date: 2026-02-11 (Feb 11, GMT+2)
-- ============================================================
-- This script:
-- 1. Updates app_config with Season 2 start date + season number
-- 2. Resets season_points for all users to 0
-- 3. Truncates hexes (territory reset - "The Void")
-- 4. Truncates daily_flips (fresh start)
-- 5. PRESERVES: run_history, user accounts, auth.users
-- ============================================================

-- 1. UPDATE APP_CONFIG: Season 2 configuration
-- Uses jsonb_set to add seasonNumber and startDate to existing season config
UPDATE app_config
SET config_data = jsonb_set(
  jsonb_set(
    config_data,
    '{season,seasonNumber}',
    '2'::jsonb
  ),
  '{season,startDate}',
  '"2026-02-11"'::jsonb
)
WHERE id = 1;

-- Verify the update
SELECT
  config_version,
  config_data->'season' as season_config,
  updated_at
FROM app_config
WHERE id = 1;

-- 2. RESET SEASON POINTS: All users start fresh
UPDATE public.users
SET season_points = 0;

-- 3. TRUNCATE HEXES: Territory reset (The Void)
TRUNCATE public.hexes;

-- 4. TRUNCATE DAILY FLIPS: Fresh daily tracking
TRUNCATE public.daily_flips;

-- 5. RESET USER AGGREGATE STATS for the new season
-- (These accumulate per-season, so reset them)
UPDATE public.users
SET
  total_distance_km = 0,
  avg_pace_min_per_km = NULL,
  avg_cv = NULL,
  total_runs = 0,
  cv_run_count = 0;

-- 6. VERIFY: Show summary
SELECT 'Season 2 Setup Complete' as status;

SELECT
  'users' as table_name,
  COUNT(*) as total_rows,
  COUNT(*) FILTER (WHERE season_points = 0) as zeroed_points,
  COUNT(*) FILTER (WHERE team = 'red') as red_count,
  COUNT(*) FILTER (WHERE team = 'blue') as blue_count,
  COUNT(*) FILTER (WHERE team = 'purple') as purple_count
FROM public.users;

SELECT
  'hexes' as table_name,
  COUNT(*) as total_rows
FROM public.hexes;

SELECT
  'run_history (preserved)' as table_name,
  COUNT(*) as total_rows
FROM public.run_history;

SELECT
  'app_config season' as check_name,
  config_data->'season'->>'seasonNumber' as season_number,
  config_data->'season'->>'startDate' as start_date,
  config_data->'season'->>'durationDays' as duration_days
FROM app_config
WHERE id = 1;
