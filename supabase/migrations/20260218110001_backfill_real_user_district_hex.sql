-- Backfill district_hex for real user (RLS prevented anon key update)
UPDATE public.users
SET district_hex = '86283472fffffff'
WHERE id = 'ff09fc1d-7f75-42da-9279-13a379c0c407'
  AND district_hex IS NULL;
