-- RunStrict: Initial Schema Migration
-- Run this in Supabase SQL Editor (https://supabase.com/dashboard/project/vhooaslzkmbnzmzwiium/sql)

-- ============================================================
-- 1. CREWS TABLE
-- ============================================================
create table if not exists public.crews (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  team text not null check (team in ('red', 'blue', 'purple')),
  member_ids jsonb not null default '[]'::jsonb,
  pin text,
  representative_image text,
  created_at timestamptz not null default now()
);

alter table public.crews enable row level security;

-- Anyone can read crews
create policy "crews_select" on public.crews
  for select using (true);

-- Authenticated users can create crews
create policy "crews_insert" on public.crews
  for insert to authenticated
  with check (true);

-- Only crew leader (first member) can update
create policy "crews_update" on public.crews
  for update to authenticated
  using (member_ids->0 #>> '{}' = auth.uid()::text);

-- ============================================================
-- 2. USERS TABLE (profiles linked to auth.users)
-- ============================================================
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  team text not null check (team in ('red', 'blue', 'purple')),
  avatar text not null default '🏃',
  crew_id uuid references public.crews(id) on delete set null,
  season_points integer not null default 0,
  manifesto text,
  created_at timestamptz not null default now()
);

alter table public.users enable row level security;

-- Anyone can read user profiles
create policy "users_select" on public.users
  for select using (true);

-- Users can insert their own profile
create policy "users_insert" on public.users
  for insert to authenticated
  with check (id = auth.uid());

-- Users can update their own profile
create policy "users_update" on public.users
  for update to authenticated
  using (id = auth.uid());

-- ============================================================
-- 3. HEXES TABLE
-- ============================================================
create table if not exists public.hexes (
  id text primary key,  -- H3 index string
  last_runner_team text check (last_runner_team in ('red', 'blue', 'purple'))
);

alter table public.hexes enable row level security;

-- Anyone can read hex state
create policy "hexes_select" on public.hexes
  for select using (true);

-- Authenticated users can upsert hexes (flip colors)
create policy "hexes_insert" on public.hexes
  for insert to authenticated
  with check (true);

create policy "hexes_update" on public.hexes
  for update to authenticated
  using (true);

-- ============================================================
-- 4. ACTIVE_RUNS TABLE (for crew multiplier via Realtime)
-- ============================================================
create table if not exists public.active_runs (
  user_id uuid primary key references public.users(id) on delete cascade,
  crew_id uuid references public.crews(id) on delete set null,
  team text not null check (team in ('red', 'blue', 'purple')),
  started_at timestamptz not null default now()
);

alter table public.active_runs enable row level security;

-- Anyone can read active runs (needed for multiplier display)
create policy "active_runs_select" on public.active_runs
  for select using (true);

-- Users can manage their own active run
create policy "active_runs_insert" on public.active_runs
  for insert to authenticated
  with check (user_id = auth.uid());

create policy "active_runs_update" on public.active_runs
  for update to authenticated
  using (user_id = auth.uid());

create policy "active_runs_delete" on public.active_runs
  for delete to authenticated
  using (user_id = auth.uid());

-- Enable Realtime for active_runs
alter publication supabase_realtime add table public.active_runs;

-- ============================================================
-- 5. DAILY_FLIPS TABLE (dedup: 1 flip per hex per user per day)
-- ============================================================
create table if not exists public.daily_flips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  date_key text not null,  -- 'YYYY-MM-DD'
  hex_id text not null,
  created_at timestamptz not null default now(),
  unique (user_id, date_key, hex_id)
);

alter table public.daily_flips enable row level security;

-- Users can read their own flips
create policy "daily_flips_select" on public.daily_flips
  for select to authenticated
  using (user_id = auth.uid());

-- Users can insert their own flips
create policy "daily_flips_insert" on public.daily_flips
  for insert to authenticated
  with check (user_id = auth.uid());

-- ============================================================
-- 6. INDEXES
-- ============================================================
create index if not exists idx_users_crew_id on public.users(crew_id);
create index if not exists idx_users_season_points on public.users(season_points desc);
create index if not exists idx_active_runs_crew_id on public.active_runs(crew_id);
create index if not exists idx_daily_flips_user_date on public.daily_flips(user_id, date_key);

-- ============================================================
-- 7. RPC FUNCTIONS
-- ============================================================

-- Check if user already flipped a specific hex today
create or replace function public.has_flipped_today(p_user_id uuid, p_hex_id text)
returns boolean
language sql
stable
security definer
as $$
  select exists(
    select 1 from public.daily_flips
    where user_id = p_user_id
      and hex_id = p_hex_id
      and date_key = to_char(now() at time zone 'UTC', 'YYYY-MM-DD')
  );
$$;

-- Get crew multiplier (count of active runners in the crew)
create or replace function public.get_crew_multiplier(p_crew_id uuid)
returns integer
language sql
stable
security definer
as $$
  select coalesce(count(*)::integer, 1)
  from public.active_runs
  where crew_id = p_crew_id;
$$;

-- Get leaderboard (top users by season points)
create or replace function public.get_leaderboard(p_limit integer default 20)
returns table(
  id uuid,
  name text,
  team text,
  avatar text,
  season_points integer,
  crew_id uuid
)
language sql
stable
security definer
as $$
  select u.id, u.name, u.team, u.avatar, u.season_points, u.crew_id
  from public.users u
  where u.season_points > 0
  order by u.season_points desc
  limit p_limit;
$$;

-- Increment season points atomically
create or replace function public.increment_season_points(p_user_id uuid, p_points integer)
returns void
language sql
security definer
as $$
  update public.users
  set season_points = season_points + p_points
  where id = p_user_id;
$$;

-- ============================================================
-- 8. SEASON RESET FUNCTION (call on D-Day)
-- ============================================================
create or replace function public.reset_season()
returns void
language plpgsql
security definer
as $$
begin
  -- Wipe all hex colors
  truncate public.hexes;
  -- Reset all user points
  update public.users set season_points = 0;
  -- Clear active runs
  truncate public.active_runs;
  -- Clear daily flips
  truncate public.daily_flips;
end;
$$;
