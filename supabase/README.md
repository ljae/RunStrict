# Supabase Database Setup

This directory contains the SQL migrations for RunStrict's Supabase backend.

## Prerequisites

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Get your project URL and anon key from Settings > API
3. Update `lib/config/supabase_config.dart` with your credentials

## Migration Files

| File | Description |
|------|-------------|
| `001_initial_schema.sql` | Tables, RLS policies, basic functions |
| `002_rpc_functions.sql` | RPC functions (finalize_run, app_launch_sync, etc.) |

## Deployment Instructions

### Option 1: Supabase Dashboard (Recommended for first setup)

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Run migrations in order:
   ```
   1. Copy contents of migrations/001_initial_schema.sql → Run
   2. Copy contents of migrations/002_rpc_functions.sql → Run
   ```

### Option 2: Supabase CLI

```bash
# Install Supabase CLI
brew install supabase/tap/supabase

# Login
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Apply migrations
supabase db push
```

## Verify Deployment

After running migrations, verify functions exist:

```sql
-- Check RPC functions are available
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_type = 'FUNCTION'
ORDER BY routine_name;
```

Expected functions:
- `app_launch_sync`
- `calculate_yesterday_checkins`
- `finalize_run`
- `get_crew_multiplier`
- `get_leaderboard`
- `get_run_history`
- `get_user_multiplier`
- `calculate_yesterday_checkins`
- `has_flipped_today`
- `increment_season_points`
- `reset_season`

## RPC Function Signatures

### `finalize_run` - The Final Sync

Called at run completion to batch upload hex captures.

```sql
finalize_run(
  p_user_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ,
  p_distance_km DOUBLE PRECISION,
  p_duration_seconds INTEGER,
  p_hex_path TEXT[],
  p_yesterday_crew_count INTEGER,
  p_client_points INTEGER DEFAULT NULL  -- optional
) RETURNS JSONB
```

**Returns:**
```json
{
  "run_id": "uuid",
  "flips": 5,
  "multiplier": 3,
  "points_earned": 15,
  "server_validated": true
}
```

### `app_launch_sync` - Pre-patch on Launch

Called once on app launch to fetch all initial state.

```sql
app_launch_sync(
  p_user_id UUID,
  p_viewport_min_lng DOUBLE PRECISION DEFAULT NULL,
  p_viewport_min_lat DOUBLE PRECISION DEFAULT NULL,
  p_viewport_max_lng DOUBLE PRECISION DEFAULT NULL,
  p_viewport_max_lat DOUBLE PRECISION DEFAULT NULL,
  p_leaderboard_limit INTEGER DEFAULT 20
) RETURNS JSONB
```

**Returns:**
```json
{
  "user_stats": {...},
  "crew_info": {...},
  "yesterday_multiplier": 3,
  "hex_map": [...],
  "leaderboard": [...],
  "server_time": "2024-01-27T12:00:00Z"
}
```

### `get_leaderboard`

```sql
get_leaderboard(p_limit INTEGER DEFAULT 20)
RETURNS TABLE(id, name, team, avatar, season_points, crew_id)
```

## Troubleshooting

### Error: "Could not find the function public.X in the schema cache"

This means the SQL function hasn't been deployed. Solutions:

1. **Run the migration again** in SQL Editor
2. **Check for syntax errors** in the SQL output
3. **Verify function exists**:
   ```sql
   SELECT * FROM information_schema.routines 
   WHERE routine_name = 'finalize_run';
   ```

### Error: "permission denied for function X"

RLS or function security issue:

1. Ensure functions have `SECURITY DEFINER`
2. Check user is authenticated
3. Verify RLS policies allow the operation

## Season Reset

To reset the season (D-Day), run:

```sql
SELECT reset_season();
```

**WARNING**: This will:
- TRUNCATE all hexes
- Reset all user season_points to 0
- Clear crews and team assignments
- Preserve run_history (5-year retention)
