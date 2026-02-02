# Migration 003: CV Aggregates

## Overview
Adds CV (Cardiovascular) aggregate tracking to the RunStrict server. Enables leaderboard filtering by distance, pace, and CV metrics.

## File
`supabase/migrations/003_cv_aggregates.sql`

## Deployment Steps

### Option 1: Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Copy the entire contents of `003_cv_aggregates.sql`
4. Paste into the SQL editor
5. Click **Run**
6. Verify no errors appear

### Option 2: Supabase CLI
```bash
supabase db push
```

## Schema Changes

### Users Table
```sql
ALTER TABLE users ADD COLUMN total_distance_km DOUBLE PRECISION DEFAULT 0;
ALTER TABLE users ADD COLUMN avg_pace_min_per_km DOUBLE PRECISION;
ALTER TABLE users ADD COLUMN avg_cv DOUBLE PRECISION;
ALTER TABLE users ADD COLUMN total_runs INTEGER DEFAULT 0;
ALTER TABLE users ADD COLUMN cv_run_count INTEGER DEFAULT 0;
```

### Run History Table
```sql
ALTER TABLE run_history ADD COLUMN cv DOUBLE PRECISION;
```

## Function Updates

### finalize_run()
**New Parameter:**
- `p_cv DOUBLE PRECISION DEFAULT NULL` - CV value from client (optional)

**New Behavior:**
- Updates user aggregates using incremental formulas
- Stores CV in run_history
- Tracks cv_run_count separately for accurate averaging

**Incremental Formulas:**
```
total_distance_km = total_distance_km + p_distance_km

total_runs = total_runs + 1

avg_pace_min_per_km = old_avg + (new_value - old_avg) / new_count

avg_cv = (old_avg * (cv_count - 1) + new_cv) / cv_count
```

### get_leaderboard()
**New Return Columns:**
- `total_distance_km`
- `avg_pace_min_per_km`
- `avg_cv`
- `total_runs`
- `rank`

### app_launch_sync()
**New Response Fields:**
- `user_stats.total_distance_km`
- `user_stats.avg_pace_min_per_km`
- `user_stats.avg_cv`
- `user_stats.total_runs`
- `leaderboard[].total_distance_km`
- `leaderboard[].avg_pace_min_per_km`
- `leaderboard[].avg_cv`
- `leaderboard[].total_runs`

## Indexes Added
```sql
CREATE INDEX idx_users_total_distance ON users(total_distance_km DESC);
CREATE INDEX idx_users_avg_pace ON users(avg_pace_min_per_km);
CREATE INDEX idx_users_avg_cv ON users(avg_cv);
CREATE INDEX idx_run_history_cv ON run_history(cv) WHERE cv IS NOT NULL;
```

## Idempotency
✅ Safe to run multiple times:
- All `ALTER TABLE` use `IF NOT EXISTS`
- All functions use `CREATE OR REPLACE`
- All indexes use `IF NOT EXISTS`

## Verification

After deployment, verify functions exist:
```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name IN ('finalize_run', 'get_leaderboard', 'app_launch_sync')
ORDER BY routine_name;
```

Expected output:
```
app_launch_sync
finalize_run
get_leaderboard
```

## Client Integration

### Calling finalize_run with CV
```dart
final result = await supabase.rpc('finalize_run', params: {
  'p_user_id': userId,
  'p_start_time': startTime.toIso8601String(),
  'p_end_time': endTime.toIso8601String(),
  'p_distance_km': distanceKm,
  'p_duration_seconds': durationSeconds,
  'p_hex_path': hexPath,
  'p_buff_multiplier': buffMultiplier,
  'p_cv': cvValue,  // NEW: Optional CV data
});
```

### Accessing new leaderboard fields
```dart
final leaderboard = await supabase.rpc('get_leaderboard', params: {
  'p_limit': 20,
});

// Now includes:
// - total_distance_km
// - avg_pace_min_per_km
// - avg_cv
// - total_runs
// - rank
```

## Rollback (if needed)
If you need to rollback, you can drop the new columns:
```sql
ALTER TABLE public.users DROP COLUMN IF EXISTS total_distance_km;
ALTER TABLE public.users DROP COLUMN IF EXISTS avg_pace_min_per_km;
ALTER TABLE public.users DROP COLUMN IF EXISTS avg_cv;
ALTER TABLE public.users DROP COLUMN IF EXISTS total_runs;
ALTER TABLE public.users DROP COLUMN IF EXISTS cv_run_count;
ALTER TABLE public.run_history DROP COLUMN IF EXISTS cv;
```

Then recreate the original functions from `002_rpc_functions.sql`.

## Notes
- CV is optional (NULL default) - runs without CV data still work
- Aggregates are calculated incrementally to avoid recalculation
- All existing data is preserved
- Migration is backward compatible
