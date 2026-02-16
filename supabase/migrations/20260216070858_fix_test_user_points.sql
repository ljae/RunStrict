-- Populate season_points from run_history for test users
-- The original get_leaderboard computed points from run data;
-- our new version reads from users.season_points directly.
-- Sync the aggregate so both approaches return the same data.
UPDATE public.users u
SET season_points = COALESCE(sub.total_points, 0)
FROM (
  SELECT r.user_id, SUM(COALESCE(r.flip_points, 0)) AS total_points
  FROM public.run_history r
  GROUP BY r.user_id
) sub
WHERE u.id = sub.user_id
  AND u.season_points = 0
  AND sub.total_points > 0;
