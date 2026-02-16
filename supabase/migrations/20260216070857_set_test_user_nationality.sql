-- Set nationality for test users so flags display on leaderboard
UPDATE public.users SET nationality = 'US' WHERE id::text LIKE 'aaaaaaaa-%' AND nationality IS NULL;
