-- ============================================================
-- RunStrict: Seed Dummy Data (4 Days: Feb 11-14, 2026)
-- ============================================================
-- Purpose: Populate realistic run history for manual testing
-- Season: Feb 11 - Mar 22, 2026 (40 days)
-- User: niche (ff09fc1d-7f75-42da-9279-13a379c0c407, team: red)
-- Area: H3 parent 85283473fffffff (Cupertino/Apple Park area)
--
-- After running this script, open the app to see:
-- - 4 days of run history in calendar
-- - Leaderboard with accumulated flip points
-- - Buff calculated from prior day performance
-- - Hex snapshot with colored hexes
-- - Season record with pace, distance, CV
--
-- Today (Feb 15) will have no dummy runs — your real runs count.
-- ============================================================

-- ============================================================
-- STEP 0: CLEAN EXISTING DATA
-- ============================================================
-- Clean in reverse dependency order

-- Delete all run history
DELETE FROM public.run_history WHERE user_id = 'ff09fc1d-7f75-42da-9279-13a379c0c407';

-- Delete all hex snapshots
DELETE FROM public.hex_snapshot;

-- Delete all hexes
DELETE FROM public.hexes;

-- Delete all buff stats
DELETE FROM public.daily_buff_stats;
DELETE FROM public.daily_all_range_stats;

-- Reset user aggregates
UPDATE public.users SET
  season_points = 0,
  total_distance_km = 0,
  total_runs = 0,
  avg_pace_min_per_km = NULL,
  avg_cv = NULL,
  cv_run_count = 0,
  home_hex_start = NULL,
  home_hex_end = NULL
WHERE id = 'ff09fc1d-7f75-42da-9279-13a379c0c407';

-- ============================================================
-- STEP 1: DAY 1 — Feb 11 (Season Start)
-- ============================================================
-- Morning run: 3.2km, 17 min, 7 hexes captured, 5 flipped
-- Evening run: 2.1km, 12 min, 5 hexes captured, 4 flipped
-- Buff: 1x (first day, no prior data)
-- Total day points: (5 + 4) * 1 = 9

-- Run 1: Morning run (07:30 - 07:47 local = 05:30 - 05:47 UTC)
INSERT INTO public.run_history (
  user_id, run_date, start_time, end_time,
  distance_km, duration_seconds, avg_pace_min_per_km,
  flip_count, flip_points, team_at_run, cv
) VALUES (
  'ff09fc1d-7f75-42da-9279-13a379c0c407',
  '2026-02-11',
  '2026-02-11 05:30:00+00',
  '2026-02-11 05:47:00+00',
  3.2, 1020, 5.31,
  5, 5, 'red', 8.2
);

-- Run 2: Evening run (18:00 - 18:12 local = 16:00 - 16:12 UTC)
INSERT INTO public.run_history (
  user_id, run_date, start_time, end_time,
  distance_km, duration_seconds, avg_pace_min_per_km,
  flip_count, flip_points, team_at_run, cv
) VALUES (
  'ff09fc1d-7f75-42da-9279-13a379c0c407',
  '2026-02-11',
  '2026-02-11 16:00:00+00',
  '2026-02-11 16:12:00+00',
  2.1, 720, 5.71,
  4, 4, 'red', 12.5
);

-- Hexes captured on Day 1 (12 unique hexes total)
INSERT INTO public.hexes (id, last_runner_team, last_flipped_at, parent_hex) VALUES
  ('89283472a93ffff', 'red', '2026-02-11 16:12:00+00', '85283473fffffff'),
  ('89283472a97ffff', 'red', '2026-02-11 16:12:00+00', '85283473fffffff'),
  ('89283472a9bffff', 'red', '2026-02-11 05:47:00+00', '85283473fffffff'),
  ('89283472a83ffff', 'red', '2026-02-11 05:47:00+00', '85283473fffffff'),
  ('89283472a87ffff', 'red', '2026-02-11 05:47:00+00', '85283473fffffff'),
  ('89283472e2bffff', 'red', '2026-02-11 16:12:00+00', '85283473fffffff'),
  ('89283472e2fffff', 'red', '2026-02-11 16:12:00+00', '85283473fffffff'),
  ('89283472e67ffff', 'red', '2026-02-11 05:47:00+00', '85283473fffffff'),
  ('89283472e63ffff', 'red', '2026-02-11 05:47:00+00', '85283473fffffff'),
  ('89283472e6fffff', 'red', '2026-02-11 16:12:00+00', '85283473fffffff'),
  ('89283472e73ffff', 'red', '2026-02-11 16:12:00+00', '85283473fffffff'),
  ('89283472e77ffff', 'red', '2026-02-11 16:12:00+00', '85283473fffffff')
ON CONFLICT (id) DO UPDATE SET
  last_runner_team = EXCLUDED.last_runner_team,
  last_flipped_at = EXCLUDED.last_flipped_at,
  parent_hex = EXCLUDED.parent_hex;

-- Build hex snapshot for Feb 12 (captures from Feb 11)
INSERT INTO public.hex_snapshot (hex_id, last_runner_team, snapshot_date, last_run_end_time, parent_hex)
SELECT id, last_runner_team, '2026-02-12', last_flipped_at, parent_hex
FROM public.hexes WHERE last_runner_team IS NOT NULL
ON CONFLICT (hex_id, snapshot_date) DO NOTHING;

-- Also create Feb 11 snapshot (baseline — shows state at season start)
INSERT INTO public.hex_snapshot (hex_id, last_runner_team, snapshot_date, last_run_end_time, parent_hex)
SELECT id, last_runner_team, '2026-02-11', last_flipped_at, parent_hex
FROM public.hexes WHERE last_runner_team IS NOT NULL
ON CONFLICT (hex_id, snapshot_date) DO NOTHING;

-- Buff stats for Feb 12 (based on Feb 11 performance)
INSERT INTO public.daily_all_range_stats (stat_date, dominant_team, red_hex_count, blue_hex_count, purple_hex_count)
VALUES ('2026-02-12', 'red', 12, 0, 0);

INSERT INTO public.daily_buff_stats (
  stat_date, city_hex, dominant_team,
  red_hex_count, blue_hex_count, purple_hex_count,
  red_elite_threshold_points, purple_total_users, purple_active_users, purple_participation_rate
) VALUES (
  '2026-02-12', '8528347303', 'red',
  12, 0, 0,
  9, 0, 0, 0
);

-- Update user after Day 1
UPDATE public.users SET
  season_points = 9,
  total_distance_km = 5.3,
  total_runs = 2,
  avg_pace_min_per_km = 5.47,
  avg_cv = 10.35,
  cv_run_count = 2,
  home_hex_start = '89283472a93ffff',
  home_hex_end = '89283472a93ffff'
WHERE id = 'ff09fc1d-7f75-42da-9279-13a379c0c407';


-- ============================================================
-- STEP 2: DAY 2 — Feb 12
-- ============================================================
-- One longer run: 5.8km, 29 min, 14 hexes captured, 8 new flips
-- Buff: 2x (elite, district win from yesterday) → 8 * 2 = 16 pts
-- Cumulative: 9 + 16 = 25 pts

INSERT INTO public.run_history (
  user_id, run_date, start_time, end_time,
  distance_km, duration_seconds, avg_pace_min_per_km,
  flip_count, flip_points, team_at_run, cv
) VALUES (
  'ff09fc1d-7f75-42da-9279-13a379c0c407',
  '2026-02-12',
  '2026-02-12 06:00:00+00',
  '2026-02-12 06:29:00+00',
  5.8, 1740, 5.0,
  8, 16, 'red', 6.3
);

-- Add more hexes (expanding territory)
INSERT INTO public.hexes (id, last_runner_team, last_flipped_at, parent_hex) VALUES
  ('89283472a8bffff', 'red', '2026-02-12 06:29:00+00', '85283473fffffff'),
  ('89283472a8fffff', 'red', '2026-02-12 06:29:00+00', '85283473fffffff'),
  ('89283472ad7ffff', 'red', '2026-02-12 06:29:00+00', '85283473fffffff'),
  ('89283472ad3ffff', 'red', '2026-02-12 06:29:00+00', '85283473fffffff'),
  ('89283472ac3ffff', 'red', '2026-02-12 06:29:00+00', '85283473fffffff'),
  ('89283472ac7ffff', 'red', '2026-02-12 06:29:00+00', '85283473fffffff'),
  ('89283472e23ffff', 'red', '2026-02-12 06:29:00+00', '85283473fffffff'),
  ('89283472e27ffff', 'red', '2026-02-12 06:29:00+00', '85283473fffffff')
ON CONFLICT (id) DO UPDATE SET
  last_runner_team = EXCLUDED.last_runner_team,
  last_flipped_at = EXCLUDED.last_flipped_at,
  parent_hex = EXCLUDED.parent_hex;

-- Build hex snapshot for Feb 13
INSERT INTO public.hex_snapshot (hex_id, last_runner_team, snapshot_date, last_run_end_time, parent_hex)
SELECT id, last_runner_team, '2026-02-13', last_flipped_at, parent_hex
FROM public.hexes WHERE last_runner_team IS NOT NULL
ON CONFLICT (hex_id, snapshot_date) DO NOTHING;

-- Buff stats for Feb 13
INSERT INTO public.daily_all_range_stats (stat_date, dominant_team, red_hex_count, blue_hex_count, purple_hex_count)
VALUES ('2026-02-13', 'red', 20, 0, 0);

INSERT INTO public.daily_buff_stats (
  stat_date, city_hex, dominant_team,
  red_hex_count, blue_hex_count, purple_hex_count,
  red_elite_threshold_points, purple_total_users, purple_active_users, purple_participation_rate
) VALUES (
  '2026-02-13', '8528347303', 'red',
  20, 0, 0,
  16, 0, 0, 0
);

-- Update user after Day 2
UPDATE public.users SET
  season_points = 25,
  total_distance_km = 11.1,
  total_runs = 3,
  avg_pace_min_per_km = 5.17,
  avg_cv = 9.0,
  cv_run_count = 3
WHERE id = 'ff09fc1d-7f75-42da-9279-13a379c0c407';


-- ============================================================
-- STEP 3: DAY 3 — Feb 13
-- ============================================================
-- Two runs: 4.5km + 3.0km = 7.5km total
-- Run 1: 4.5km, 22 min, 10 hexes, 6 flips
-- Run 2: 3.0km, 16 min, 7 hexes, 5 flips
-- Buff: 2x (elite + district) → (6 + 5) * 2 = 22 pts
-- Cumulative: 25 + 22 = 47 pts

INSERT INTO public.run_history (
  user_id, run_date, start_time, end_time,
  distance_km, duration_seconds, avg_pace_min_per_km,
  flip_count, flip_points, team_at_run, cv
) VALUES (
  'ff09fc1d-7f75-42da-9279-13a379c0c407',
  '2026-02-13',
  '2026-02-13 05:45:00+00',
  '2026-02-13 06:07:00+00',
  4.5, 1320, 4.89,
  6, 12, 'red', 5.1
);

INSERT INTO public.run_history (
  user_id, run_date, start_time, end_time,
  distance_km, duration_seconds, avg_pace_min_per_km,
  flip_count, flip_points, team_at_run, cv
) VALUES (
  'ff09fc1d-7f75-42da-9279-13a379c0c407',
  '2026-02-13',
  '2026-02-13 16:30:00+00',
  '2026-02-13 16:46:00+00',
  3.0, 960, 5.33,
  5, 10, 'red', 9.8
);

-- Add even more hexes (territory grows)
INSERT INTO public.hexes (id, last_runner_team, last_flipped_at, parent_hex) VALUES
  ('89283472acbffff', 'red', '2026-02-13 06:07:00+00', '85283473fffffff'),
  ('89283472acfffff', 'red', '2026-02-13 06:07:00+00', '85283473fffffff'),
  ('89283472a13ffff', 'red', '2026-02-13 06:07:00+00', '85283473fffffff'),
  ('89283472a17ffff', 'red', '2026-02-13 06:07:00+00', '85283473fffffff'),
  ('89283472abbffff', 'red', '2026-02-13 16:46:00+00', '85283473fffffff'),
  ('89283472ab3ffff', 'red', '2026-02-13 16:46:00+00', '85283473fffffff'),
  ('89283472e37ffff', 'red', '2026-02-13 16:46:00+00', '85283473fffffff'),
  ('89283472e33ffff', 'red', '2026-02-13 16:46:00+00', '85283473fffffff'),
  ('89283472e3bffff', 'red', '2026-02-13 06:07:00+00', '85283473fffffff'),
  ('89283472e0fffff', 'red', '2026-02-13 06:07:00+00', '85283473fffffff'),
  ('89283472e7bffff', 'red', '2026-02-13 16:46:00+00', '85283473fffffff')
ON CONFLICT (id) DO UPDATE SET
  last_runner_team = EXCLUDED.last_runner_team,
  last_flipped_at = EXCLUDED.last_flipped_at,
  parent_hex = EXCLUDED.parent_hex;

-- Build hex snapshot for Feb 14
INSERT INTO public.hex_snapshot (hex_id, last_runner_team, snapshot_date, last_run_end_time, parent_hex)
SELECT id, last_runner_team, '2026-02-14', last_flipped_at, parent_hex
FROM public.hexes WHERE last_runner_team IS NOT NULL
ON CONFLICT (hex_id, snapshot_date) DO NOTHING;

-- Buff stats for Feb 14
INSERT INTO public.daily_all_range_stats (stat_date, dominant_team, red_hex_count, blue_hex_count, purple_hex_count)
VALUES ('2026-02-14', 'red', 31, 0, 0);

INSERT INTO public.daily_buff_stats (
  stat_date, city_hex, dominant_team,
  red_hex_count, blue_hex_count, purple_hex_count,
  red_elite_threshold_points, purple_total_users, purple_active_users, purple_participation_rate
) VALUES (
  '2026-02-14', '8528347303', 'red',
  31, 0, 0,
  22, 0, 0, 0
);

-- Update user after Day 3
UPDATE public.users SET
  season_points = 47,
  total_distance_km = 18.6,
  total_runs = 5,
  avg_pace_min_per_km = 5.1,
  avg_cv = 8.38,
  cv_run_count = 5
WHERE id = 'ff09fc1d-7f75-42da-9279-13a379c0c407';


-- ============================================================
-- STEP 4: DAY 4 — Feb 14 (Yesterday)
-- ============================================================
-- Big run day: 8.2km, 40 min, 18 hexes, 10 flips
-- Buff: 2x (elite + district) → 10 * 2 = 20 pts
-- Cumulative: 47 + 20 = 67 pts

INSERT INTO public.run_history (
  user_id, run_date, start_time, end_time,
  distance_km, duration_seconds, avg_pace_min_per_km,
  flip_count, flip_points, team_at_run, cv
) VALUES (
  'ff09fc1d-7f75-42da-9279-13a379c0c407',
  '2026-02-14',
  '2026-02-14 05:30:00+00',
  '2026-02-14 06:10:00+00',
  8.2, 2400, 4.88,
  10, 20, 'red', 4.2
);

-- More hexes (biggest territory day)
INSERT INTO public.hexes (id, last_runner_team, last_flipped_at, parent_hex) VALUES
  ('89283472e6bffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('8928347284bffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('8928347284fffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('89283472843ffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('89283472853ffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('8928347285bffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('892834728cbffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('892834728cfffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('892834728c3ffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('892834728dbffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('89283472e07ffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('89283472e03ffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('89283472e0bffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('89283472e47ffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('89283472e4fffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('89283472adbffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('89283472a1bffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff'),
  ('89283472a03ffff', 'red', '2026-02-14 06:10:00+00', '85283473fffffff')
ON CONFLICT (id) DO UPDATE SET
  last_runner_team = EXCLUDED.last_runner_team,
  last_flipped_at = EXCLUDED.last_flipped_at,
  parent_hex = EXCLUDED.parent_hex;

-- Build hex snapshot for Feb 15 (today — what the app downloads)
INSERT INTO public.hex_snapshot (hex_id, last_runner_team, snapshot_date, last_run_end_time, parent_hex)
SELECT id, last_runner_team, '2026-02-15', last_flipped_at, parent_hex
FROM public.hexes WHERE last_runner_team IS NOT NULL
ON CONFLICT (hex_id, snapshot_date) DO NOTHING;

-- Also build snapshot for Feb 16 (tomorrow — for cron safety)
INSERT INTO public.hex_snapshot (hex_id, last_runner_team, snapshot_date, last_run_end_time, parent_hex)
SELECT id, last_runner_team, '2026-02-16', last_flipped_at, parent_hex
FROM public.hexes WHERE last_runner_team IS NOT NULL
ON CONFLICT (hex_id, snapshot_date) DO NOTHING;

-- Buff stats for Feb 15 (today — based on Feb 14 performance)
INSERT INTO public.daily_all_range_stats (stat_date, dominant_team, red_hex_count, blue_hex_count, purple_hex_count)
VALUES ('2026-02-15', 'red', 49, 0, 0);

INSERT INTO public.daily_buff_stats (
  stat_date, city_hex, dominant_team,
  red_hex_count, blue_hex_count, purple_hex_count,
  red_elite_threshold_points, purple_total_users, purple_active_users, purple_participation_rate
) VALUES (
  '2026-02-15', '8528347303', 'red',
  49, 0, 0,
  20, 0, 0, 0
);

-- ============================================================
-- STEP 5: SET FINAL USER STATE
-- ============================================================
-- app_launch_sync will self-heal from run_history, but set correct
-- values now for immediate verification

UPDATE public.users SET
  season_points = 67,
  total_distance_km = 26.8,
  total_runs = 6,
  avg_pace_min_per_km = 5.05,
  avg_cv = 7.68,
  cv_run_count = 6,
  home_hex_start = '89283472a93ffff',
  home_hex_end = '89283472a93ffff'
WHERE id = 'ff09fc1d-7f75-42da-9279-13a379c0c407';


-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================
-- Run these to verify the seed data

-- 1. Run history by day
-- SELECT run_date, COUNT(*) as runs, SUM(distance_km) as km, SUM(flip_points) as pts
-- FROM run_history WHERE user_id = 'ff09fc1d-7f75-42da-9279-13a379c0c407'
-- GROUP BY run_date ORDER BY run_date;

-- 2. Hex count
-- SELECT COUNT(*) as total_hexes FROM hexes;

-- 3. Snapshot dates
-- SELECT snapshot_date, COUNT(*) as hex_count FROM hex_snapshot GROUP BY snapshot_date ORDER BY snapshot_date;

-- 4. Buff stats
-- SELECT stat_date, dominant_team, red_hex_count FROM daily_all_range_stats ORDER BY stat_date;

-- 5. User state
-- SELECT season_points, total_distance_km, total_runs, avg_pace_min_per_km, avg_cv FROM users
-- WHERE id = 'ff09fc1d-7f75-42da-9279-13a379c0c407';
