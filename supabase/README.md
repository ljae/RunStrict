# Supabase Database

RunStrict's Supabase backend. Schema is managed directly on the remote database.

## Prerequisites

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Get your project URL and anon key from Settings > API
3. Update `lib/config/supabase_config.dart` with your credentials

## Current Schema

### Tables

| Table | Purpose |
|-------|---------|
| `users` | User profiles, season points, aggregates |
| `hexes` | Live hex state (for buff/dominance calculations) |
| `hex_snapshot` | Daily frozen hex state (for flip point calculation) |
| `daily_buff_stats` | Per-district buff stats (calculated at midnight GMT+2) |
| `daily_all_range_stats` | Province-wide hex dominance stats |
| `run_history` | Lightweight run stats (preserved across seasons) |
| `app_config` | Server-configurable game constants (single row) |

### RPC Functions

| Function | Purpose |
|----------|---------|
| `finalize_run` | The Final Sync — batch upload at run completion |
| `app_launch_sync` | Fetch all initial state on app launch |
| `get_leaderboard` | Season rankings |
| `get_scoped_leaderboard` | Scoped rankings by geographic area |
| `get_user_buff` | Current buff multiplier |
| `get_hex_snapshot` | Download daily hex snapshot |
| `get_hexes_delta` | Delta sync for hex updates |
| `get_hexes_in_scope` | Hex data within geographic scope |
| `get_hex_dominance` | Hex counts per team by scope |
| `get_run_history` | User's run history |
| `get_team_rankings` | Team ranking data |
| `get_user_yesterday_stats` | Yesterday's personal performance |
| `calculate_daily_buffs` | Midnight cron: calculate buff multipliers |
| `build_daily_hex_snapshot` | Midnight cron: build next day's hex snapshot |
| `reset_season` | D-Day reset (wipe season data) |

### Cron Jobs (pg_cron)

| Schedule | Function |
|----------|----------|
| `0 22 * * *` (midnight GMT+2) | `calculate_daily_buffs()` |
| `0 22 * * *` (midnight GMT+2) | `build_daily_hex_snapshot()` |

## Schema Changes

Schema is defined in `DEVELOPMENT_SPEC.md` §4.2. To make changes:

1. Write and test SQL in the Supabase SQL Editor
2. Update `DEVELOPMENT_SPEC.md` to reflect the new schema

## Season Reset

```sql
SELECT reset_season();
```

This will:
- TRUNCATE all hexes
- Reset all user season_points to 0
- Reset team assignments (users must re-select)
- Preserve run_history
