# Supabase Patterns — RunStrict

> Activated when editing SQL migrations, Edge Functions, or Dart files using SupabaseService.

## Architecture

- **Serverless**: No backend API server. Flutter → Supabase RLS directly.
- **Auth**: Supabase Auth (email/password + social login)
- **Storage**: PostgreSQL with RLS policies on all tables
- **Functions**: Edge Functions for server-side logic (buff calculations, snapshots)
- **No Realtime/WebSocket**: All data synced on app launch, OnResume, run completion

## Key Tables

```sql
users            -- id, name, team, season_points, home_hex, district_hex, aggregates
hexes            -- id (H3), last_runner_team, last_flipped_at (live state for buff only)
hex_snapshot     -- hex_id, last_runner_team, snapshot_date (frozen daily for flip counting)
runs             -- id, user_id, team_at_run, distance, hex_path[] (partitioned monthly)
run_history      -- preserved across seasons, includes flip_points for Elite threshold
daily_stats      -- per-user per-day aggregates (partitioned monthly)
daily_buff_stats -- per-district buff calculations
season_leaderboard_snapshot -- frozen at midnight for rankings
```

## Key RPC Functions

| Function | Purpose | Called When |
|----------|---------|------------|
| `finalize_run(...)` | Cap-validate flip_points, update hexes, store district_hex | Run completion |
| `get_user_buff(user_id)` | Get current buff multiplier | App launch |
| `calculate_daily_buffs()` | Compute all buffs | Midnight cron |
| `build_daily_hex_snapshot()` | Build tomorrow's snapshot | Midnight cron |
| `get_hex_snapshot(parent, date)` | Download hex snapshot | App launch/OnResume |
| `get_leaderboard(limit)` | Rankings from snapshot table | App launch/OnResume |
| `app_launch_sync(...)` | Batch prefetch data | App launch |

## RPC Call Pattern (Dart)

```dart
// Standard RPC call
final result = await supabase.rpc('get_user_buff', params: {
  'p_user_id': userId,
});

// Batch prefetch on launch
final data = await supabase.rpc('app_launch_sync', params: {
  'p_user_id': userId,
  'p_home_hex': homeHex,
});
```

## Migration Conventions

- Files in `supabase/migrations/` with timestamp prefix: `YYYYMMDD_description.sql`
- Always include `IF NOT EXISTS` for safety
- Use `BEGIN; ... COMMIT;` for multi-statement migrations
- Add RLS policies for every new table
- Partition large tables monthly (runs, daily_stats) or yearly (run_history)

## Server Cap Validation

```sql
-- In finalize_run(): server validates client-reported points
IF p_flip_points > array_length(p_hex_path, 1) * p_buff_multiplier THEN
  RAISE EXCEPTION 'flip_points exceeds cap';
END IF;
```

## Data Domains Impact

- **hex_snapshot** table → Snapshot Domain (read-only, frozen daily)
- **hexes** table → Updated by finalize_run() for buff/dominance ONLY (NOT for flip counting)
- **season_leaderboard_snapshot** → Snapshot Domain (read by LeaderboardScreen, NOT live users table)
- **runs** table → Live Domain (uploaded via Final Sync)

## Security

- RLS policies on ALL tables
- `finalize_run()` runs as SECURITY DEFINER for cross-table updates
- Client never directly writes to `hexes` or `hex_snapshot` — only via RPC
- Points cap validation prevents score inflation
