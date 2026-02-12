-- Add missing columns to public.users and public.run_history
-- These columns are defined in migrations 003-005 but not yet applied to live DB

-- From migration 003: CV aggregates
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS total_distance_km DOUBLE PRECISION DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avg_pace_min_per_km DOUBLE PRECISION;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avg_cv DOUBLE PRECISION;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS total_runs INTEGER DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS cv_run_count INTEGER DEFAULT 0;
ALTER TABLE public.run_history ADD COLUMN IF NOT EXISTS cv DOUBLE PRECISION;

-- From migration 004: home_hex
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS home_hex TEXT;

-- From migration 005: season_home_hex
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS season_home_hex TEXT;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_total_distance ON public.users(total_distance_km DESC);
CREATE INDEX IF NOT EXISTS idx_users_avg_pace ON public.users(avg_pace_min_per_km);
CREATE INDEX IF NOT EXISTS idx_users_avg_cv ON public.users(avg_cv);
CREATE INDEX IF NOT EXISTS idx_run_history_cv ON public.run_history(cv) WHERE cv IS NOT NULL;

-- Verify
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'users'
ORDER BY ordinal_position;
