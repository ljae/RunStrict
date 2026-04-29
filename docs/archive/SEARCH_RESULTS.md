# Search Results: Users Table Schema, finalize_run, Elite Threshold, and Buff/District References

## Summary
This document contains the exact line numbers and surrounding context for all mentions of:
1. Users table schema
2. finalize_run function
3. Elite threshold references
4. Buff system with district calculation
5. home_hex_end usage for district/scope

---

## File 1: CLAUDE.md

### 1. User Model (Supabase: users table) - Lines 164-190

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/CLAUDE.md`
**Lines**: 164-190

```
164: ### User Model (Supabase: users table)
165: ```dart
166: class UserModel {
167:   String id;
168:   String name;
169:   Team team;               // 'red' | 'blue' | 'purple'
170:   String avatar;           // Emoji avatar (legacy, not displayed)
171:   int seasonPoints;        // Preserved when defecting to Purple
172:   String? manifesto;       // 30-char declaration
173:   String sex;              // 'male' | 'female' | 'other'
174:   DateTime birthday;       // User birthday
175:   String? nationality;     // ISO country code (e.g., 'KR', 'US')
176:   String? homeHex;         // H3 index of run start location (self only)
177:   String? homeHexEnd;      // H3 index of run end location (visible to others)
178:   String? seasonHomeHex;   // Home hex for current season
179:   double totalDistanceKm;  // Running season aggregate
180:   double? avgPaceMinPerKm; // Weighted average pace
181:   double? avgCv;           // Average CV (from runs ≥ 1km)
182:   int totalRuns;           // Number of completed runs
183:
184:   /// Stability score (100 - avgCv, clamped 0-100). Higher = better.
185:   int? get stabilityScore => avgCv == null ? null : (100 - avgCv!).round().clamp(0, 100);
186: }
187: ```
188: **Note**: Aggregate fields updated incrementally via `finalize_run()` RPC.
189: **Home Hex**: Asymmetric visibility - `homeHex` for self, `homeHexEnd` for others.
190: **Profile**: No avatar display. Profile shows manifesto (30 chars), sex, birthday, nationality (server-persisted).
```

### 2. finalize_run() RPC Reference - Line 103

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/CLAUDE.md`
**Lines**: 102-104

```
102: ├── services/
103: │   ├── supabase_service.dart    # Supabase client init & RPC wrappers (passes CV to finalize_run)
104: │   ├── remote_config_service.dart # Server-configurable constants (fallback: server → cache → defaults)
```

### 3. finalize_run() Reference in User Aggregate Section - Line 188

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/CLAUDE.md`
**Lines**: 186-190

```
186: }
187: ```
188: **Note**: Aggregate fields updated incrementally via `finalize_run()` RPC.
189: **Home Hex**: Asymmetric visibility - `homeHex` for self, `homeHexEnd` for others.
190: **Profile**: No avatar display. Profile shows manifesto (30 chars), sex, birthday, nationality (server-persisted).
```

### 4. Elite Threshold Reference - Lines 276-281

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/CLAUDE.md`
**Lines**: 260-281

```
260: | Normal (no wins) | 2x | 1x |
261: | District win only | 3x | 1x |
262: | Province win only | 3x | 2x |
263: | District + Province | 4x | 2x |
264:
265: **BLUE WAVE:**
266: | Scenario | Union |
267: |----------|-------|
268: | Normal (no wins) | 1x |
269: | District win only | 2x |
270: | Province win only | 2x |
271: | District + Province | 3x |
272:
273: **PURPLE:** Participation Rate = 1x (<30%), 2x (30-59%), 3x (≥60%)
274:
275: - **New users** = 1x (default until yesterday's data exists)
276: - Buff is **frozen** when run starts — no changes mid-run
277: - Fetched on app launch via `get_user_buff()` RPC
278: - Elite threshold stored in `daily_buff_stats.red_elite_threshold_points` (computed from `run_history.flip_points`)
279:
280: ### Purple Team (The Protocol of Chaos)
281: - **Unlock**: Available **anytime** during season
```

### 5. Average CV Calculation via finalize_run() - Line 318

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/CLAUDE.md`
**Lines**: 315-320

```
315: ```
316:
317: **Lap Recording**: Automatic during runs, stored in local SQLite `laps` table.
318: **User Aggregate**: Average CV calculated incrementally via `finalize_run()` RPC.
319:
320: ### Flip Points Calculation (Snapshot-Based)
321: ```
```

### 6. Schema List - Lines 442-459

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/CLAUDE.md`
**Lines**: 442-459

```
442: ```sql
443: users            -- id, name, team, avatar, season_points, manifesto,
444:                  -- sex, birthday, nationality,
445:                  -- home_hex, home_hex_end, season_home_hex,
446:                  -- total_distance_km, avg_pace_min_per_km,
447:                  -- avg_cv, total_runs, cv_run_count
448: hexes            -- id (H3 index), last_runner_team, last_flipped_at (live state for buff/dominance only)
449: hex_snapshot     -- hex_id, last_runner_team, snapshot_date, parent_hex (frozen daily snapshot for flip counting)
450: runs             -- id, user_id, team_at_run, distance_meters, hex_path[] (partitioned monthly)
451: run_history      -- id, user_id, run_date, distance_km, duration_seconds, flip_count, flip_points, cv
452:                  -- (preserved across seasons. flip_points = flip_count × buff, used for RED Elite threshold)
453: daily_stats      -- id, user_id, date_key, total_distance_km, flip_count (partitioned monthly)
454: daily_buff_stats -- stat_date, city_hex, dominant_team, red/blue/purple_hex_count,
455:                  -- red_elite_threshold_points (from run_history.flip_points), purple_participation_rate
456: season_leaderboard_snapshot -- user_id, season_number, rank, name, team, avatar, season_points,
457:                  -- total_distance_km, avg_pace_min_per_km, avg_cv, total_runs,
458:                  -- home_hex, home_hex_end, manifesto, nationality (frozen at midnight)
```

### 7. Key RPC Function - Line 462

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/CLAUDE.md`
**Lines**: 460-464

```
460: **Key RPC Functions:**
461: - `finalize_run(...)` → accept client flip_points with cap validation, update live hexes for buff/dominance
462: - `get_user_buff(user_id)` → get user's current buff multiplier
463: - `calculate_daily_buffs()` → daily cron to compute all buffs at midnight GMT+2
464: - `build_daily_hex_snapshot()` → daily cron to build tomorrow's hex snapshot at midnight GMT+2
```

### 8. Live Hexes Table Note - Lines 691-695

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/CLAUDE.md`
**Lines**: 691-695

```
691: - **Live `hexes` table**: Still updated by `finalize_run()` for buff/dominance calculations only. NOT used for flip counting.
692: - **Prefetch**: Downloads from `hex_snapshot` (not `hexes`). Delta sync uses `snapshot_date`.
693:
694: ---
```

---

## File 2: AGENTS.md

### 1. Buff System Overview - Lines 14-14

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/AGENTS.md`
**Lines**: 10-15

```
10: - **Season**: 40 days (fixed duration)
11: - **Teams**: Red (FLAME), Blue (WAVE), Purple (CHAOS - available anytime)
12: - **Hex System**: Displays color of **last runner** - no ownership
13: - **D-Day Reset**: All territories and scores wiped via TRUNCATE/DROP (The Void)
14: - **Buff System**: Team-based multipliers calculated daily (Red: Elite 2-4x / Common 1-2x, Blue: 1-3x, Purple: Participation 1-3x)
```

### 2. Buff System Details - Lines 353-382

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/AGENTS.md`
**Lines**: 353-382

```
353: ### Team-Based Buff System
354: ```dart
355: // Buff multiplier determined by team, performance, and territory dominance
356: // Calculated daily at midnight GMT+2 via Edge Function
357: //
358: // RED FLAME:
359: // Elite = Top 20% by yesterday's FLIP POINTS (points with multiplier, NOT raw flip count)
360: //         among RED runners in the same District
361: // Common = Bottom 80%
362: // | Scenario              | Elite (Top 20%) | Common |
363: // |-----------------------|-----------------|--------|
364: // | Normal (no wins)      | 2x              | 1x     |
365: // | District win only     | 3x              | 1x     |
366: // | Province win only     | 3x              | 2x     |
367: // | District + Province   | 4x              | 2x     |
368: //
369: // BLUE WAVE:
370: // | Scenario              | Union |
371: // |-----------------------|-------|
372: // | Normal (no wins)      | 1x    |
373: // | District win only     | 2x    |
374: // | Province win only     | 2x    |
375: // | District + Province   | 3x    |
376: //
377: // PURPLE: Participation Rate = 1x (<30%), 2x (30-59%), 3x (≥60%) (no territory bonus)
378: // New users = 1x (default until yesterday's data exists)
379: final multiplier = BuffService().currentBuff; // Frozen at run start
380: final points = flipsEarned * multiplier;
381: ```
382: ```
```

### 3. Live Hexes Table Note - Lines 450-454

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/AGENTS.md`
**Lines**: 446-454

```
446: ### Hex Data Architecture (Snapshot + Local Overlay)
447: `HexRepository` is the **single source of truth** for hex data (no duplicate caches).
448: - `PrefetchService.getCachedHex()` delegates to `HexRepository().getHex()`
449: - `HexDataProvider.getHex()` reads directly from `HexRepository`
450: - PrefetchService downloads from `hex_snapshot` table (NOT live `hexes`) into HexRepository
451: - **Local overlay**: User's own today's flips stored in SQLite, applied on top of snapshot
452: - **Map display**: Snapshot + own local flips (other users' today activity invisible)
453: - **Live `hexes` table**: Updated by `finalize_run()` for buff/dominance only, NOT for flip counting
```

---

## File 3: DEVELOPMENT_SPEC.md

### 1. Complete Users Table Schema - Lines 1035-1056

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/DEVELOPMENT_SPEC.md`
**Lines**: 1035-1056

```sql
1035: CREATE TABLE users (
1036:   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
1037:   auth_id UUID REFERENCES auth.users(id) NOT NULL,
1038:   name TEXT NOT NULL,
1039:   team TEXT CHECK (team IN ('red', 'blue', 'purple')),
1040:   avatar TEXT NOT NULL DEFAULT '🏃',
1041:   sex TEXT CHECK (sex IN ('male', 'female', 'other')),
1042:   birthday DATE,
1043:   nationality TEXT,                           -- ISO country code (e.g., 'KR', 'US')
1044:   season_points INTEGER NOT NULL DEFAULT 0,
1045:   manifesto TEXT CHECK (char_length(manifesto) <= 30),
1046:   home_hex_start TEXT,                        -- First hex of last run (used for SELF leaderboard scope)
1047:   home_hex_end TEXT,                          -- Last hex of last run (used for OTHERS leaderboard scope)
1048:   season_home_hex TEXT,                       -- Home hex at season start
1049:   total_distance_km DOUBLE PRECISION NOT NULL DEFAULT 0,
1050:   avg_pace_min_per_km DOUBLE PRECISION,
1051:   avg_cv DOUBLE PRECISION,
1052:   total_runs INTEGER NOT NULL DEFAULT 0,
1053:   cv_run_count INTEGER NOT NULL DEFAULT 0,   -- For incremental CV average
1054:   created_at TIMESTAMPTZ NOT NULL DEFAULT now()
1055: );
```

### 2. Daily Buff Stats Schema (Elite Threshold) - Lines 1066-1081

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/DEVELOPMENT_SPEC.md`
**Lines**: 1066-1081

```sql
1066: CREATE TABLE daily_buff_stats (
1067:   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
1068:   stat_date DATE NOT NULL,
1069:   city_hex TEXT,                                  -- District (Res 6) hex prefix
1070:   dominant_team TEXT,                             -- Team with most hexes in this district
1071:   red_hex_count INTEGER DEFAULT 0,
1072:   blue_hex_count INTEGER DEFAULT 0,
1073:   purple_hex_count INTEGER DEFAULT 0,
1074:   red_elite_threshold_points INTEGER DEFAULT 0,   -- Top 20% flip_points threshold (from run_history.flip_points, NOT flip_count)
1075:   purple_total_users INTEGER DEFAULT 0,
1076:   purple_active_users INTEGER DEFAULT 0,
1077:   purple_participation_rate DOUBLE PRECISION DEFAULT 0,
1078:   created_at TIMESTAMPTZ NOT NULL DEFAULT now()
1079: );
```

### 3. Run History Schema (for Elite Threshold) - Lines 1137-1154

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/DEVELOPMENT_SPEC.md`
**Lines**: 1137-1154

```sql
1137: -- Run history: lightweight stats preserved across seasons
1138: -- Separate from runs table which contains heavy hex_path data
1139: CREATE TABLE run_history (
1140:   id UUID NOT NULL DEFAULT gen_random_uuid(),
1141:   user_id UUID NOT NULL REFERENCES users(id),
1142:   run_date DATE NOT NULL,                       -- Date of the run
1143:   start_time TIMESTAMPTZ NOT NULL,
1144:   end_time TIMESTAMPTZ NOT NULL,
1145:   distance_km DOUBLE PRECISION NOT NULL,
1146:   duration_seconds INTEGER NOT NULL,
1147:   avg_pace_min_per_km DOUBLE PRECISION,
1148:   flip_count INTEGER NOT NULL DEFAULT 0,        -- Raw flips (hex color changes)
1149:   flip_points INTEGER NOT NULL DEFAULT 0,      -- Points with multiplier (flip_count × buff). Used for RED Elite threshold.
1150:   team_at_run TEXT NOT NULL CHECK (team_at_run IN ('red', 'blue', 'purple')),
1151:   cv DOUBLE PRECISION,                         -- Pace consistency (Coefficient of Variation)
1152:   created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
1153:   PRIMARY KEY (id, created_at)
1154: ) PARTITION BY RANGE (created_at);
```

### 4. Season Leaderboard Snapshot Schema - Lines 1159-1178

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/DEVELOPMENT_SPEC.md`
**Lines**: 1159-1178

```sql
1159: CREATE TABLE season_leaderboard_snapshot (
1160:   user_id UUID NOT NULL REFERENCES users(id),
1161:   season_number INTEGER NOT NULL,
1162:   rank INTEGER NOT NULL,
1163:   name TEXT,
1164:   team TEXT,
1165:   avatar TEXT,
1166:   season_points INTEGER NOT NULL DEFAULT 0,
1167:   total_distance_km DOUBLE PRECISION NOT NULL DEFAULT 0,
1168:   avg_pace_min_per_km DOUBLE PRECISION,
1169:   avg_cv DOUBLE PRECISION,
1170:   total_runs INTEGER DEFAULT 0,
1171:   home_hex TEXT,
1172:   home_hex_end TEXT,
1173:   manifesto TEXT,
1174:   nationality TEXT,
1175:   PRIMARY KEY (user_id, season_number)
1176: );
```

### 5. get_leaderboard() RPC with home_hex_end - Lines 1254-1281

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/DEVELOPMENT_SPEC.md`
**Lines**: 1254-1281

```sql
1254: -- Leaderboard query (reads from season_leaderboard_snapshot — Snapshot Domain)
1255: -- IMPORTANT: Do NOT read from live `users` table — leaderboard is frozen at midnight.
1256: CREATE OR REPLACE FUNCTION get_leaderboard(p_limit INTEGER DEFAULT 20)
1257: RETURNS TABLE(
1258:   id UUID, name TEXT, team TEXT, avatar TEXT,
1259:   season_points INT, total_distance_km FLOAT8,
1260:   avg_pace_min_per_km FLOAT8, avg_cv FLOAT8,
1261:   home_hex TEXT, home_hex_end TEXT, manifesto TEXT,
1262:   nationality TEXT, total_runs INT, rank BIGINT
1263: ) AS $fn$
1264:   SELECT
1265:     s.user_id, s.name, s.team, s.avatar,
1266:     s.season_points, s.total_distance_km,
1267:     s.avg_pace_min_per_km, s.avg_cv,
1268:     s.home_hex,
1269:     COALESCE(s.home_hex_end, u.home_hex_end),
1270:     s.manifesto,
1271:     COALESCE(s.nationality, u.nationality),
1272:     s.total_runs,
1273:     s.rank::BIGINT
1274:   FROM public.season_leaderboard_snapshot s
1275:   LEFT JOIN public.users u ON u.id = s.user_id
1276:   ORDER BY s.rank ASC
1277:   LIMIT p_limit;
```

### 6. Complete finalize_run() RPC Function - Lines 1283-1388

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/DEVELOPMENT_SPEC.md`
**Lines**: 1283-1388

```sql
1283: -- Finalize run: accept client flip points with cap validation ("The Final Sync")
1284: -- Snapshot-based: client counts flips against daily snapshot, server cap-validates only.
1285: -- Server still updates live `hexes` table for buff/dominance calculations.
1286: CREATE OR REPLACE FUNCTION finalize_run(
1287:   p_user_id UUID,
1288:   p_start_time TIMESTAMPTZ,
1289:   p_end_time TIMESTAMPTZ,
1290:   p_distance_km DOUBLE PRECISION,
1291:   p_duration_seconds INTEGER,
1292:   p_hex_path TEXT[],
1293:   p_buff_multiplier INTEGER DEFAULT 1,
1294:   p_cv DOUBLE PRECISION DEFAULT NULL,
1295:   p_client_points INTEGER DEFAULT 0,
1296:   p_home_region_flips INTEGER DEFAULT 0,
1297:   p_hex_parents TEXT[] DEFAULT NULL
1298: )
1299: RETURNS jsonb AS $$
1300: DECLARE
1301:   v_hex_id TEXT;
1302:   v_team TEXT;
1303:   v_points INTEGER;
1304:   v_max_allowed_points INTEGER;
1305:   v_flip_count INTEGER;
1306:   v_current_flipped_at TIMESTAMPTZ;
1307:   v_parent_hex TEXT;
1308:   v_idx INTEGER;
1309: BEGIN
1310:   -- Get user's team
1311:   FETCH v_team FROM users WHERE id = p_user_id;
1312:
1313:   -- [SECURITY] Cap validation: client points cannot exceed hex_path_length × buff_multiplier
1314:   v_max_allowed_points := COALESCE(array_length(p_hex_path, 1), 0) * p_buff_multiplier;
1315:   v_points := LEAST(p_client_points, v_max_allowed_points);
1316:   v_flip_count := CASE WHEN p_buff_multiplier > 0 THEN v_points / p_buff_multiplier ELSE 0 END;
1317:
1318:   IF p_client_points > v_max_allowed_points THEN
1319:     RAISE WARNING 'Client claimed % points but max allowed is %. Capped.', p_client_points, v_max_allowed_points;
1320:   END IF;
1321:
1322:   -- Update live `hexes` table for buff/dominance calculations (NOT for flip points)
1323:   -- hex_snapshot is immutable until midnight build
1324:   IF p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0 THEN
1325:     v_idx := 1;
1326:     FOREACH v_hex_id IN ARRAY p_hex_path LOOP
1327:       -- Get parent hex from provided array or calculate
1328:       v_parent_hex := NULL;
1329:       IF p_hex_parents IS NOT NULL AND v_idx <= array_length(p_hex_parents, 1) THEN
1330:         v_parent_hex := p_hex_parents[v_idx];
1331:       END IF;
1332:
1333:       SELECT last_flipped_at INTO v_current_flipped_at FROM public.hexes WHERE id = v_hex_id;
1334:
1335:       IF v_current_flipped_at IS NULL OR p_end_time > v_current_flipped_at THEN
1336:         INSERT INTO public.hexes (id, last_runner_team, last_flipped_at, parent_hex)
1337:         VALUES (v_hex_id, v_team, p_end_time, v_parent_hex)
1338:         ON CONFLICT (id) DO UPDATE
1339:         SET last_runner_team = v_team,
1340:             last_flipped_at = p_end_time,
1341:             parent_hex = COALESCE(v_parent_hex, hexes.parent_hex)
1342:         WHERE hexes.last_flipped_at IS NULL OR hexes.last_flipped_at < p_end_time;
1343:       END IF;
1344:       v_idx := v_idx + 1;
1345:     END LOOP;
1346:   END IF;
1347:
1348:   -- Award client-calculated points (cap-validated)
1349:   UPDATE users SET
1350:     season_points = season_points + v_points,
1351:     home_hex_start = CASE WHEN array_length(p_hex_path, 1) > 0 THEN p_hex_path[1] ELSE home_hex_start END,
1352:     home_hex_end = CASE WHEN array_length(p_hex_path, 1) > 0 THEN p_hex_path[array_length(p_hex_path, 1)] ELSE home_hex_end END,
1353:     total_distance_km = total_distance_km + p_distance_km,
1354:     total_runs = total_runs + 1,
1355:     avg_pace_min_per_km = CASE
1356:       WHEN p_distance_km > 0 THEN
1357:         (COALESCE(avg_pace_min_per_km, 0) * total_runs + (p_duration_seconds / 60.0) / p_distance_km) / (total_runs + 1)
1358:       ELSE avg_pace_min_per_km
1359:     END,
1360:     avg_cv = CASE
1361:       WHEN p_cv IS NOT NULL THEN
1362:         (COALESCE(avg_cv, 0) * cv_run_count + p_cv) / (cv_run_count + 1)
1363:       ELSE avg_cv
1364:     END,
1365:     cv_run_count = CASE WHEN p_cv IS NOT NULL THEN cv_run_count + 1 ELSE cv_run_count END
1366:   WHERE id = p_user_id;
1367:
1368:   -- Insert lightweight run history (PRESERVED across seasons)
1369:   INSERT INTO run_history (
1370:     user_id, run_date, start_time, end_time,
1371:     distance_km, duration_seconds, avg_pace_min_per_km,
1372:     flip_count, flip_points, team_at_run, cv
1373:   ) VALUES (
1374:     p_user_id, (p_end_time AT TIME ZONE 'Etc/GMT-2')::DATE, p_start_time, p_end_time,
1375:     p_distance_km, p_duration_seconds,
1376:     CASE WHEN p_distance_km > 0 THEN (p_duration_seconds / 60.0) / p_distance_km ELSE NULL END,
1377:     v_flip_count, v_points, v_team, p_cv
1378:   );
1379:
1380:   -- Return summary
1381:   RETURN jsonb_build_object(
1382:     'flips', v_flip_count,
1383:     'multiplier', p_buff_multiplier,
1384:     'points_earned', v_points,
1385:     'server_validated', true
1386:   );
1387: END;
1388: $$ LANGUAGE plpgsql;
```

### 7. Buff Scope and District Reference - Lines 204-214

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/DEVELOPMENT_SPEC.md`
**Lines**: 204-214

```
204: | Property | Value |
205: |----------|-------|
206: | Calculation Time | Daily at midnight (GMT+2) via Edge Function |
207: | Display Timing | Shown at run START (frozen for entire run) |
208: | Scope | District-level (determined by user's home hex) |
209: | Mid-day changes | Buff frozen at run start; new district = new buff next day |
210:
211: **Rules:**
212: - Buff is **frozen** when a run starts. Mid-run location changes don't affect multiplier.
213: - Users see their buff breakdown before starting a run.
214: - Server-configurable thresholds via `app_config.buff_config`.
```

### 8. Data Design Principles - Lines 1391-1402

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/DEVELOPMENT_SPEC.md`
**Lines**: 1391-1402

```
1391: **Design Principles:**
1392: - `hex_snapshot`: Daily frozen hex state — basis for all flip point calculations. Immutable during the day.
1393: - `hexes`: Live hex state for buff/dominance calculations. Updated by `finalize_run()`. NOT used for flip counting.
1394: - `users`: Aggregate stats updated incrementally via `finalize_run()`.
1395: - `runs`: Heavy data with `hex_path` (H3 IDs) → **DELETED on season reset**. Used at midnight to build next snapshot.
1396: - `run_history`: Lightweight stats (distance, time, flips, cv) → **PRESERVED across seasons**.
1397: - `daily_buff_stats`: Team-based buff multipliers (District Leader, Province Range) calculated daily at midnight GMT+2.
1398: - **Snapshot-based flip counting**: Client counts flips against downloaded snapshot, server cap-validates only.
1399: - **No daily flip limit**: Same hex can be flipped multiple times per day.
1400: - **Multiplier**: Team-based buff via `calculate_daily_buffs()` at midnight GMT+2.
1401: - **Sync**: No real-time — all hex data uploaded via `finalize_run()` at run completion.
1402: - All security handled via RLS — **no separate backend API server needed**.
```

---

## File 4: DATA_FLOW_ANALYSIS.md

### 1. Data Models with Elite/Buff References - Lines 32-35

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/DATA_FLOW_ANALYSIS.md`
**Lines**: 29-38

```
29: | `LeaderboardEntry` | `leaderboard_provider.dart` | 2 (wraps `UserModel` + `rank`) | Season leaderboard row (delegates to `UserModel`) |
30: | `YesterdayStats` | `models/team_stats.dart` | 8 | Yesterday's personal performance |
31: | `RankingEntry` | `models/team_stats.dart` | 4 | Mini leaderboard entry (yesterday's points) |
32: | `TeamRankings` | `models/team_stats.dart` | 9 | Red elite/common + Blue rankings |
33: | `HexDominanceScope` | `models/team_stats.dart` | 3 + 2 computed | Hex counts per team in a scope |
34: | `HexDominance` | `models/team_stats.dart` | 4 | Wraps allRange + cityRange scopes |
35: | `RedTeamBuff` | `models/team_stats.dart` | 6 | Red buff status with elite tier |
36: | `PurpleParticipation` | `models/team_stats.dart` | 3 | Purple participation rate + count |
37: | `TeamBuffComparison` | `models/team_stats.dart` | 3 + delegates to `BuffBreakdown` | Wraps team buffs + user multiplier |
38: | `BuffBreakdown` | `buff_service.dart` | 8 | Buff calculation details from RPC |
```

### 2. finalize_run() RPC Reference - Line 172

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/DATA_FLOW_ANALYSIS.md`
**Lines**: 170-174

```
170: |                  | finalize_run() RPC |   |
171: | Run-level aggregates | finalize_run() RPC | ✅ Yes (incremental) |
172: |                  | in user_stats.total_distance_km |   |
173: | CV (run-level) | finalize_run() RPC | ✅ Yes (avg_cv, cv_run_count) |
```

### 3. UserModel and Users Table Reference - Line 208

**File**: `/Users/jaelee/.gemini/antigravity/scratch/runner/DATA_FLOW_ANALYSIS.md`
**Lines**: 205-211

```
205: |----------|--------|:---:|
206: | `Run.avgPaceMinPerKm` | Computed getter | NO - derived on demand |
207: | ~~`Run.toMap()['avgPaceSecPerKm']`~~ | ~~Stored in SQLite (sec/km)~~ | ~~YES~~ REMOVED in v13 |
208: | `UserModel.avgPaceMinPerKm` | Supabase `users` table | Aggregate - needed |
209: | `DailyRunningStat.avgPaceMinPerKm` | Supabase `daily_stats` | Can compute from distance/duration |
210: | `LeaderboardEntry.avgPaceMinPerKm` | Supabase leaderboard RPC | Copy of UserModel field |
```

---

## Summary Table: Key References

| Section | File | Lines | Key Points |
|---------|------|-------|-----------|
| **Users Table Schema** | DEVELOPMENT_SPEC.md | 1035-1056 | Complete CREATE TABLE with home_hex_start, home_hex_end, season_home_hex |
| **Elite Threshold** | CLAUDE.md | 278-278 | `daily_buff_stats.red_elite_threshold_points` computed from `run_history.flip_points` |
| **Elite Threshold Schema** | DEVELOPMENT_SPEC.md | 1074-1074 | `red_elite_threshold_points INTEGER` in daily_buff_stats (Top 20% flip_points threshold) |
| **District Scope** | DEVELOPMENT_SPEC.md | 208-208 | Buff scope: District-level (determined by user's home hex) |
| **home_hex_end Usage** | CLAUDE.md | 177-177 | "H3 index of run end location (visible to others)" |
| **home_hex_end in finalize_run()** | DEVELOPMENT_SPEC.md | 1352-1352 | Updated via finalize_run(): last hex of run path |
| **finalize_run() Complete Spec** | DEVELOPMENT_SPEC.md | 1283-1388 | Full RPC function with home_hex_start/end updates and points capping |
| **Buff System Overview** | AGENTS.md | 359-361 | "Elite = Top 20% by yesterday's FLIP POINTS among RED runners in the same District" |
| **Live vs Snapshot Hexes** | CLAUDE.md | 694-694 | `finalize_run()` updates live `hexes` for buff/dominance only, NOT for flip counting |
| **run_history for Elite** | DEVELOPMENT_SPEC.md | 1149-1149 | `flip_points` used for RED Elite threshold calculation |

---

## Key Findings

1. **users table** has `home_hex_end` (line 1047) for determining user's leaderboard district scope
2. **finalize_run()** updates `home_hex_end` as the last hex in the run path (line 1352)
3. **Elite threshold** is stored in `daily_buff_stats.red_elite_threshold_points` (line 1074) and is the Top 20% flip_points threshold for a specific district
4. **District** determination is based on user's `home_hex` which converts to Res 6 parent hex (city_hex in daily_buff_stats)
5. **Buff scope** is District-level, with daily calculation at midnight GMT+2 (line 206)
6. **finalize_run()** validates points cap: `client_points ≤ len(hex_path) × buff_multiplier` (line 1314-1316)
7. **Red Elite** is Top 20% of RED runners in same District by flip_points (flip_count × buff_multiplier)

