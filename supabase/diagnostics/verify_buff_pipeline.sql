-- Replace YOUR_USER_ID with your actual Supabase auth user ID
-- Run each section separately in Supabase SQL Editor

-- 1. Check if daily_buff_stats has today's data
SELECT * FROM daily_buff_stats WHERE stat_date = CURRENT_DATE;
SELECT * FROM daily_all_range_stats WHERE stat_date = CURRENT_DATE;

-- 2. Check if your runs reached run_history
SELECT id, run_date, flip_count, flip_points, team_at_run, start_time
FROM run_history
WHERE user_id = 'YOUR_USER_ID'
ORDER BY run_date DESC LIMIT 10;

-- 3. Check what get_user_buff returns for you RIGHT NOW
SELECT get_user_buff('YOUR_USER_ID');

-- 4. Check your user record (team, home_hex_end)
SELECT id, name, team, home_hex_end, season_points
FROM users
WHERE id = 'YOUR_USER_ID';

-- 5. Check if pg_cron is scheduled
SELECT * FROM cron.job;
