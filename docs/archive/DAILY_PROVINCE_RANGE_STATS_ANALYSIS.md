# `daily_province_range_stats` Table Analysis

## Overview
`daily_province_range_stats` is a **server-side, read-only table** that stores per-province hex dominance statistics. It is **NOT directly accessed by any Dart code** — only via SQL RPC functions.

---

## Table Schema

### Current Schema (After Migration 20260306000003)
```sql
CREATE TABLE public.daily_province_range_stats (
  stat_date       DATE    NOT NULL,
  province_hex    TEXT    NOT NULL,   -- H3 Res-5 province hex
  leading_team    TEXT    CHECK (leading_team IN ('red', 'blue', 'purple')),
  red_hex_count   INTEGER NOT NULL DEFAULT 0,
  blue_hex_count  INTEGER NOT NULL DEFAULT 0,
  purple_hex_count INTEGER NOT NULL DEFAULT 0,
  calculated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (stat_date, province_hex)
);

CREATE INDEX idx_daily_province_range_stats_date
  ON public.daily_province_range_stats (stat_date);
```

### Previous Schema (Before Migration 20260306000003)
```sql
CREATE TABLE public.daily_province_range_stats (
  date DATE PRIMARY KEY,  -- Server-wide, one row per day
  leading_team TEXT CHECK (leading_team IN ('red', 'blue')),
  red_hex_count INTEGER NOT NULL DEFAULT 0,
  blue_hex_count INTEGER NOT NULL DEFAULT 0,
  calculated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**Key Change**: Migrated from **server-wide scope** (one row per day) to **per-province scope** (one row per Res-5 province per day) to enable local "Province Win" buff calculation.

---

## Access Patterns

### 1. WRITE Operations (Server-Side Only)

#### Source: `calculate_daily_buffs()` RPC
**File**: `supabase/migrations/20260306000003_province_win_scoped_to_res5.sql` (lines 270-436)

**When Called**: Midnight GMT+2 cron job (via pg_cron)

**Operation**:
```sql
-- Step 1: Delete existing stats for today (idempotent re-run)
DELETE FROM public.daily_province_range_stats WHERE stat_date = v_today_gmt2;

-- Step 2: Loop over each distinct Res-5 province with colored hexes
FOR v_province_hex IN
  SELECT DISTINCT h.parent_hex
  FROM public.hexes h
  WHERE h.parent_hex IS NOT NULL
    AND h.last_runner_team IS NOT NULL
LOOP
  -- Count hexes per team in this province
  SELECT
    COALESCE(SUM(CASE WHEN h.last_runner_team = 'red'    THEN 1 ELSE 0 END), 0) AS red_count,
    COALESCE(SUM(CASE WHEN h.last_runner_team = 'blue'   THEN 1 ELSE 0 END), 0) AS blue_count,
    COALESCE(SUM(CASE WHEN h.last_runner_team = 'purple' THEN 1 ELSE 0 END), 0) AS purple_count
  INTO v_hex_counts
  FROM public.hexes h
  WHERE h.parent_hex = v_province_hex
    AND h.last_runner_team IS NOT NULL;

  -- Determine dominant team
  v_dominant := CASE
    WHEN v_hex_counts.red_count >= v_hex_counts.blue_count
      AND v_hex_counts.red_count >= v_hex_counts.purple_count THEN 'red'
    WHEN v_hex_counts.blue_count >= v_hex_counts.red_count
      AND v_hex_counts.blue_count >= v_hex_counts.purple_count THEN 'blue'
    ELSE 'purple'
  END;

  -- Insert one row per province per day
  INSERT INTO public.daily_province_range_stats (
    stat_date, province_hex, leading_team,
    red_hex_count, blue_hex_count, purple_hex_count
  ) VALUES (
    v_today_gmt2, v_province_hex, v_dominant,
    v_hex_counts.red_count, v_hex_counts.blue_count, v_hex_counts.purple_count
  );
END LOOP;
```

**Access Level**: `SECURITY DEFINER` (runs as database owner)

---

### 2. READ Operations (Server-Side Only)

#### Source: `get_user_buff()` RPC
**File**: `supabase/migrations/20260306000003_province_win_scoped_to_res5.sql` (lines 532-562)

**When Called**: 
- App launch (via `app_launch_sync()`)
- Run completion (via `finalize_run()`)
- OnResume (via `app_launch_sync()`)

**Operation**:
```sql
-- Province Win: lookup by user's local Res-5 province
IF v_user.team != 'purple' AND v_province_hex IS NOT NULL THEN
  -- Primary: precomputed daily_province_range_stats keyed by province_hex
  SELECT leading_team INTO v_province_leading_team
  FROM public.daily_province_range_stats
  WHERE province_hex = v_province_hex   -- LOCAL Res-5 scope
    AND stat_date = v_today_gmt2
  LIMIT 1;

  IF v_province_leading_team IS NOT NULL THEN
    v_province_win := (v_province_leading_team = v_user.team);
  ELSE
    -- Fallback: count live hexes in user's Res-5 province (parent_hex column)
    SELECT (
      CASE v_user.team
        WHEN 'red'  THEN COUNT(CASE WHEN last_runner_team = 'red'  THEN 1 END)
        WHEN 'blue' THEN COUNT(CASE WHEN last_runner_team = 'blue' THEN 1 END)
        ELSE 0
      END >
      GREATEST(
        CASE WHEN v_user.team != 'red'  THEN COUNT(CASE WHEN last_runner_team = 'red'  THEN 1 END) ELSE 0 END,
        CASE WHEN v_user.team != 'blue' THEN COUNT(CASE WHEN last_runner_team = 'blue' THEN 1 END) ELSE 0 END,
        COUNT(CASE WHEN last_runner_team = 'purple' THEN 1 END)
      )
    ) INTO v_province_win
    FROM public.hexes
    WHERE parent_hex = v_province_hex;  -- Res-5 filter: correct!
  END IF;
END IF;
```

**Access Level**: `SECURITY DEFINER` (runs as database owner)

**Return Value**: Included in `get_user_buff()` response:
```json
{
  "multiplier": 2,
  "base_buff": 1,
  "province_range_bonus": 1,
  "district_bonus": 0,
  "province_bonus": 1,
  "reason": "Union",
  "team": "blue",
  "district_hex": "...",
  "is_elite": false,
  "has_district_win": false,
  "has_province_win": true,
  "elite_threshold": 0,
  "yesterday_points": 0
}
```

---

## Dart Access (None Direct)

### ✅ NO Dart files directly reference `daily_province_range_stats`

**Grep Result**: 0 matches in `lib/**/*.dart`

**Why**: The table is **server-side only**. Dart code accesses province win data indirectly:

1. **Buff Calculation**: `BuffService` calls `get_user_buff()` RPC
   - File: `lib/features/team/providers/buff_provider.dart`
   - Receives `has_province_win` in the RPC response
   - Uses it to calculate final multiplier

2. **No Direct Queries**: Dart never queries `daily_province_range_stats` directly
   - No `supabase.from('daily_province_range_stats').select()`
   - No local caching of province stats
   - All logic is server-side

---

## RLS Policies

**File**: `supabase/migrations/20260306000003_province_win_scoped_to_res5.sql` (line 672)

```sql
GRANT SELECT, INSERT, DELETE ON public.daily_province_range_stats TO authenticated;
```

### Access Control
| Operation | Authenticated | Service Role | Anonymous |
|-----------|---------------|--------------|-----------|
| SELECT | ✅ Yes | ✅ Yes | ❌ No |
| INSERT | ✅ Yes | ✅ Yes | ❌ No |
| DELETE | ✅ Yes | ✅ Yes | ❌ No |
| UPDATE | ❌ No | ❌ No | ❌ No |

**Note**: No explicit RLS policies defined (only GRANT). Authenticated users can read/insert/delete, but the table is only written by `calculate_daily_buffs()` (SECURITY DEFINER).

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Midnight GMT+2 Cron                       │
│                  (pg_cron schedule: 0 22 * * *)              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │  calculate_daily_buffs()       │
        │  (SECURITY DEFINER)            │
        └────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
    ┌────────┐   ┌──────────────┐   ┌──────────┐
    │ hexes  │   │daily_buff_   │   │daily_all_│
    │        │   │stats         │   │range_    │
    │        │   │(per-district)│   │stats     │
    └────────┘   └──────────────┘   └──────────┘
         │
         │ (reads)
         │
         ▼
    ┌──────────────────────────────────┐
    │daily_province_range_stats        │
    │(per-province, one row per day)   │
    │                                  │
    │ stat_date, province_hex,         │
    │ leading_team, hex_counts         │
    └──────────────────────────────────┘
         │
         │ (reads at run completion)
         │
         ▼
    ┌────────────────────────────────┐
    │  get_user_buff()               │
    │  (called by finalize_run)       │
    │  (called by app_launch_sync)    │
    └────────────────────────────────┘
         │
         │ (returns has_province_win)
         │
         ▼
    ┌────────────────────────────────┐
    │  Dart: BuffService             │
    │  (calculates final multiplier)  │
    └────────────────────────────────┘
```

---

## Key Invariants

### 1. **Composite Primary Key: (stat_date, province_hex)**
- One row per Res-5 province per day
- Enables local "Province Win" scoping
- Matches exactly what TeamScreen Territory display shows

### 2. **Calculated at Midnight GMT+2**
- `calculate_daily_buffs()` runs at `0 22 * * *` (midnight GMT+2)
- Deletes and rebuilds entire table for the day
- Idempotent: safe to re-run

### 3. **Reads from Live `hexes` Table**
- Source of truth: `hexes.last_runner_team` (updated by `finalize_run()`)
- `hexes.parent_hex` = Res-5 province (set by `finalize_run()`)
- Snapshot is NOT used (unlike hex_snapshot for flip counting)

### 4. **Purple Gets NO Province Bonus**
- `get_user_buff()` checks: `IF v_user.team != 'purple'`
- Purple team only gets participation rate buff (no territory bonus)

### 5. **Fallback to Live Hexes**
- If `daily_province_range_stats` row missing, `get_user_buff()` falls back to live hex count
- Ensures buff calculation never fails (graceful degradation)

---

## Migration History

| Migration | Date | Change |
|-----------|------|--------|
| `20260216063756_baseline_schema.sql` | 2026-02-16 | Initial schema: `date DATE PRIMARY KEY` (server-wide) |
| `20260219000000_sql_function_cleanup.sql` | 2026-02-19 | First use in `get_user_buff()` (server-wide scope) |
| `20260306000003_province_win_scoped_to_res5.sql` | 2026-03-06 | **MAJOR**: Rebuild with composite PK `(stat_date, province_hex)` |

### Migration 20260306000003 Details
**Root Cause**: Province win was server-wide (one row per day). All users saw the same "province winner" globally, even if they dominated their local area.

**Fix**: 
1. Add `users.province_hex` (Res-5) column
2. Rebuild `daily_province_range_stats` with `(stat_date, province_hex)` PK
3. Update `calculate_daily_buffs()` to loop per distinct province
4. Update `get_user_buff()` to lookup by user's local province_hex
5. Update `finalize_run()` to set `users.province_hex` from `p_hex_parents[1]`

---

## Seeding & Testing

### Seed Data (Migration 20260220000000)
```sql
INSERT INTO daily_province_range_stats (date, leading_team, red_hex_count, blue_hex_count, calculated_at)
VALUES 
  ('2026-02-10', 'blue', 11, 13, now()),
  ('2026-02-11', 'red', 20, 17, now()),
  ('2026-02-12', 'blue', 32, 35, now()),
  ...
```

**Note**: Old schema (server-wide). After migration 20260306000003, seed data would need `province_hex` column.

### Verification (Migration 20260225200000)
```sql
SELECT 'daily_province_range_stats', COUNT(*) FROM public.daily_province_range_stats WHERE date = CURRENT_DATE;
```

---

## Summary Table

| Aspect | Details |
|--------|---------|
| **Table Name** | `daily_province_range_stats` |
| **Primary Key** | `(stat_date, province_hex)` |
| **Scope** | Per Res-5 province, per day |
| **Write Source** | `calculate_daily_buffs()` RPC (midnight GMT+2) |
| **Read Source** | `get_user_buff()` RPC (run completion, app launch) |
| **Dart Access** | ❌ None (server-side only) |
| **RLS Policy** | `GRANT SELECT, INSERT, DELETE TO authenticated` |
| **Fallback** | Live `hexes` table (if row missing) |
| **Purple Bonus** | ❌ No (participation rate only) |
| **Timezone** | GMT+2 (stat_date) |

---

## Related Tables

| Table | Relationship |
|-------|-------------|
| `hexes` | Source of truth (read by `calculate_daily_buffs()`) |
| `hex_snapshot` | NOT used (flip counting uses snapshot, buff uses live) |
| `daily_buff_stats` | Per-district stats (sibling table, same cron) |
| `daily_all_range_stats` | Server-wide stats (analytics only, not used for buff) |
| `users` | Stores `province_hex` (set by `finalize_run()`) |
| `run_history` | Used for Elite threshold calculation (not province win) |

---

## Conclusion

`daily_province_range_stats` is a **pure server-side table** that enables local "Province Win" buff calculation. It is:
- ✅ Written by `calculate_daily_buffs()` at midnight GMT+2
- ✅ Read by `get_user_buff()` during run completion and app launch
- ❌ Never directly accessed by Dart code
- ✅ Scoped to user's local Res-5 province (not server-wide)
- ✅ Accessible to authenticated users (SELECT, INSERT, DELETE)
