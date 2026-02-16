-- Baseline schema for RunStrict
-- All tables, indexes, RLS policies as of 2026-02-16
-- On production: supabase migration repair --status applied 20260216063756

-- =============================================================================
-- TABLES
-- =============================================================================

-- Users (permanent, survives season reset)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id UUID REFERENCES auth.users(id) NOT NULL,
  name TEXT NOT NULL,
  team TEXT CHECK (team IN ('red', 'blue', 'purple')),
  avatar TEXT NOT NULL DEFAULT '🏃',
  sex TEXT CHECK (sex IN ('male', 'female', 'other')),
  birthday DATE,
  nationality TEXT,
  season_points INTEGER NOT NULL DEFAULT 0,
  manifesto TEXT CHECK (char_length(manifesto) <= 30),
  home_hex TEXT,
  home_hex_end TEXT,
  season_home_hex TEXT,
  total_distance_km DOUBLE PRECISION NOT NULL DEFAULT 0,
  avg_pace_min_per_km DOUBLE PRECISION,
  avg_cv DOUBLE PRECISION,
  total_runs INTEGER NOT NULL DEFAULT 0,
  cv_run_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Hexes (live state for buff/dominance; deleted on season reset)
CREATE TABLE IF NOT EXISTS public.hexes (
  id TEXT PRIMARY KEY,
  last_runner_team TEXT CHECK (last_runner_team IN ('red', 'blue', 'purple')),
  last_flipped_at TIMESTAMPTZ,
  parent_hex TEXT
);

-- Hex snapshot (frozen daily at midnight GMT+2)
CREATE TABLE IF NOT EXISTS public.hex_snapshot (
  hex_id TEXT NOT NULL,
  last_runner_team TEXT NOT NULL CHECK (last_runner_team IN ('red', 'blue', 'purple')),
  snapshot_date DATE NOT NULL,
  last_run_end_time TIMESTAMPTZ,
  parent_hex TEXT,
  PRIMARY KEY (hex_id, snapshot_date)
);

-- Runs (partitioned monthly, deleted on season reset)
CREATE TABLE IF NOT EXISTS public.runs (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id),
  team_at_run TEXT NOT NULL CHECK (team_at_run IN ('red', 'blue', 'purple')),
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  distance_meters DOUBLE PRECISION NOT NULL DEFAULT 0,
  avg_pace_min_per_km DOUBLE PRECISION,
  hexes_colored INTEGER NOT NULL DEFAULT 0,
  hex_path TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Run history (partitioned monthly, preserved across seasons)
CREATE TABLE IF NOT EXISTS public.run_history (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id),
  run_date DATE NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  distance_km DOUBLE PRECISION NOT NULL,
  duration_seconds INTEGER NOT NULL,
  avg_pace_min_per_km DOUBLE PRECISION,
  flip_count INTEGER NOT NULL DEFAULT 0,
  flip_points INTEGER NOT NULL DEFAULT 0,
  cv DOUBLE PRECISION,
  team_at_run TEXT NOT NULL CHECK (team_at_run IN ('red', 'blue', 'purple')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Daily stats (partitioned monthly, preserved across seasons)
CREATE TABLE IF NOT EXISTS public.daily_stats (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id),
  date_key DATE NOT NULL,
  total_distance_km DOUBLE PRECISION NOT NULL DEFAULT 0,
  total_duration_seconds INTEGER NOT NULL DEFAULT 0,
  avg_pace_min_per_km DOUBLE PRECISION,
  flip_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at),
  UNIQUE (user_id, date_key, created_at)
) PARTITION BY RANGE (created_at);

-- Daily buff stats (calculated nightly, deleted on season reset)
CREATE TABLE IF NOT EXISTS public.daily_buff_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id),
  date DATE NOT NULL,
  buff_multiplier INTEGER NOT NULL DEFAULT 1,
  is_elite BOOLEAN NOT NULL DEFAULT false,
  is_district_leader BOOLEAN NOT NULL DEFAULT false,
  has_province_range BOOLEAN NOT NULL DEFAULT false,
  participation_rate DOUBLE PRECISION,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, date)
);

-- Daily province range stats (tracks server-wide hex dominance)
CREATE TABLE IF NOT EXISTS public.daily_province_range_stats (
  date DATE PRIMARY KEY,
  leading_team TEXT CHECK (leading_team IN ('red', 'blue')),
  red_hex_count INTEGER NOT NULL DEFAULT 0,
  blue_hex_count INTEGER NOT NULL DEFAULT 0,
  calculated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- App config (server-configurable constants)
CREATE TABLE IF NOT EXISTS public.app_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_users_team ON public.users(team);
CREATE INDEX IF NOT EXISTS idx_users_season_points ON public.users(season_points DESC);
CREATE INDEX IF NOT EXISTS idx_users_auth_id ON public.users(auth_id);
CREATE INDEX IF NOT EXISTS idx_hexes_team ON public.hexes(last_runner_team);
CREATE INDEX IF NOT EXISTS idx_hexes_parent ON public.hexes(parent_hex);
CREATE INDEX IF NOT EXISTS idx_hex_snapshot_date_parent ON public.hex_snapshot(snapshot_date, parent_hex);
CREATE INDEX IF NOT EXISTS idx_daily_buff_stats_user_date ON public.daily_buff_stats(user_id, date);

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY users_select ON public.users
  FOR SELECT USING (true);

CREATE POLICY users_update ON public.users
  FOR UPDATE USING (auth_id = auth.uid())
  WITH CHECK (auth_id = auth.uid());

ALTER TABLE public.hexes ENABLE ROW LEVEL SECURITY;

CREATE POLICY hexes_select ON public.hexes
  FOR SELECT USING (true);

ALTER TABLE public.hex_snapshot ENABLE ROW LEVEL SECURITY;

CREATE POLICY hex_snapshot_select ON public.hex_snapshot
  FOR SELECT USING (true);

ALTER TABLE public.daily_buff_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY daily_buff_stats_select ON public.daily_buff_stats
  FOR SELECT USING (user_id IN (SELECT id FROM public.users WHERE auth_id = auth.uid()));

ALTER TABLE public.run_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY run_history_select ON public.run_history
  FOR SELECT USING (user_id IN (SELECT id FROM public.users WHERE auth_id = auth.uid()));

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY app_config_select ON public.app_config
  FOR SELECT USING (true);

-- =============================================================================
-- PARTITION MANAGEMENT (pg_partman)
-- =============================================================================

-- Note: Run these after enabling pg_partman extension:
-- SELECT partman.create_parent('public.runs', 'created_at', 'native', '1 month', p_premake := 3);
-- SELECT partman.create_parent('public.daily_stats', 'created_at', 'native', '1 month', p_premake := 3);
-- SELECT partman.create_parent('public.run_history', 'created_at', 'native', '1 month', p_premake := 3);
