# /seed-mock-daily — Seed Daily Mock Run Data

Seeds today's (GMT+2) run data for **30 existing mock runners**. All dates are computed dynamically from `CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2'` — no manual date changes needed.

**Run once per day after midnight GMT+2.**

## Runners Covered
30 mock profiles. Test user `ljae.m10` (`08f88e4b-26f1-4028-a481-bbf140e588a1`) is always excluded.

## What It Does
1. `run_history` — 30 rows for today (GMT+2 date)
2. `hex_snapshot` — 117 rows for `snapshot_date = today+2` (visible to client starting tomorrow)
3. `hexes` — upsert same 117 hex_ids into live table (for tonight's cron)
4. `users.season_points` — increment by today's flip_points

## Snapshot Date Convention
- Client queries `snapshot_date = GMT+2_today + 1` (today's view)
- To be visible **starting tomorrow**: insert `snapshot_date = GMT+2_today + 2`

---

## Step 0: Guard Check

Run this first. If `already_seeded >= 1`, **stop** and report "Already seeded for today — skipping."

```sql
SELECT COUNT(*) AS already_seeded
FROM run_history
WHERE run_date = (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE
  AND user_id = '83417bdd-3aef-46d4-a2f8-6f920f0b4e17';
```

---

## Step 1: Insert run_history (30 rows)

`start_time` / `end_time` are UTC timestamps offset from midnight UTC on today's GMT+2 date.

```sql
WITH today AS (
  SELECT (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE AS d
),
runner_data (user_id, start_secs, duration_s, distance_km, flip_count, flip_points, team_at_run, cv) AS (
  VALUES
  -- name            user_id                                          start(UTC)  dur(s)  dist   flips  pts   team       cv
  -- ApexFlux        blue  province 85283443fffffff
  ('83417bdd-3aef-46d4-a2f8-6f920f0b4e17'::uuid, 14400, 1872, 5.2,  9,  9,  'blue'::text,   11.5),
  -- ArcStride       blue  province 85283473fffffff
  ('24bf6c86-235f-4da8-9e0f-1b74e3db2363'::uuid, 18000, 2088, 5.8,  10, 10, 'blue',   9.2),
  -- BladeVolt       red   province 8528344bfffffff
  ('c8ba2c35-63fb-4247-9166-ba0fd323f5f1'::uuid, 16200, 2700, 7.5,  14, 14, 'red',    8.7),
  -- ChronoHex       purple province 85283423fffffff
  ('89ef89d4-c654-4921-9d4a-b341a0330687'::uuid, 21600, 2520, 7.0,  13, 13, 'purple', 12.3),
  -- CipherRun       blue  province 85283403fffffff
  ('a8a2f2a0-e8ee-424a-b0b1-d64ae798827a'::uuid, 25200, 1980, 5.5,  10, 10, 'blue',   10.1),
  -- EchoBlaze       red   province 85283473fffffff
  ('713bcdaf-614c-4024-8454-567f77b18e4c'::uuid, 23400, 1728, 4.8,  8,  8,  'red',    14.2),
  -- FenixDash       red   province 8528343bfffffff
  ('d257c4db-4120-437f-a8c1-b52bf3fe564a'::uuid, 28800, 1512, 4.2,  7,  7,  'red',    16.8),
  -- FluxHawk        red   province 85283473fffffff
  ('22bebd8b-c803-4d77-8a0f-5c932b44f298'::uuid, 19800, 2160, 6.0,  11, 11, 'red',    7.9),
  -- FrostVolt       blue  province 8528340ffffffff
  ('4226f6d8-6aa4-4dd9-9817-41b5faa36159'::uuid, 32400, 1440, 4.0,  7,  7,  'blue',   17.3),
  -- GhostRun        red   province 85283447fffffff
  ('168ad17c-9705-4c13-abb6-c4097d05d99e'::uuid, 27000, 1512, 4.2,  7,  7,  'red',    15.4),
  -- GlintRun        purple province 85283473fffffff
  ('7cdb088a-ee1c-4aed-824e-665dc3779df2'::uuid, 21600, 2340, 6.5,  12, 12, 'purple', 9.8),
  -- KyloSprint      purple province 8528309bfffffff
  ('490e8a4d-0b4e-4556-adb7-84fe4a71e6be'::uuid, 14400, 2808, 7.8,  15, 15, 'purple', 6.5),
  -- LunaFlip        purple province 852830d3fffffff
  ('5acf5231-00ec-4758-b71f-fbff87b176cd'::uuid, 18000, 2808, 7.8,  15, 15, 'purple', 8.2),
  -- MiruHex         purple province 8528342ffffffff
  ('de7b8e5d-08e5-406e-af53-8daec612c99f'::uuid, 25200, 2700, 7.5,  14, 14, 'purple', 10.6),
  -- MossRun         blue  province 852830d7fffffff
  ('0a625603-164a-4477-9631-243c501814da'::uuid, 14400, 3060, 8.5,  17, 17, 'blue',   7.1),
  -- NeonFury        red   province 85283473fffffff
  ('a758e639-f485-4bc0-a68f-0b0baaed3fad'::uuid, 18000, 3240, 9.0,  18, 18, 'red',    6.3),
  -- NovaDash        blue  province 85283473fffffff
  ('b1a010f9-dc49-4c0c-a96e-fab7d2fd4632'::uuid, 28800, 1800, 5.0,  9,  9,  'blue',   12.7),
  -- OrbitDash       red   province 8528340bfffffff
  ('87e86e98-98b8-4dab-9973-f357ac6285ec'::uuid, 21600, 2160, 6.0,  11, 11, 'red',    9.4),
  -- PlasmaGrit      red   province 85283417fffffff
  ('06826d41-b401-4b7c-a8c7-be9631340f99'::uuid, 34200, 1440, 4.0,  7,  7,  'red',    18.1),
  -- PrismRun        blue  province 85283473fffffff
  ('15c14c4d-9a4a-4814-b4f9-74d1e181eb32'::uuid, 18000, 3420, 9.5,  19, 19, 'blue',   5.8),
  -- PulseArc        blue  province 8528344ffffffff
  ('02900328-95df-42e9-9e46-ce596cc113d6'::uuid, 16200, 2808, 7.8,  15, 15, 'blue',   7.8),
  -- RiftBlaze       purple province 85283407fffffff
  ('780bb396-d969-457d-a885-d4c277c848d7'::uuid, 21600, 2700, 7.5,  14, 14, 'purple', 11.2),
  -- StellarRun      blue  province 8528341bfffffff
  ('3adf998f-10fb-4e01-ac41-b1c138a0cb0a'::uuid, 36000, 1368, 3.8,  6,  6,  'blue',   19.4),
  -- StormGrit       red   province 85283473fffffff
  ('63394070-7353-41d8-b59c-62c122728433'::uuid, 19800, 2880, 8.0,  16, 16, 'red',    7.4),
  -- TerraWave       red   province 85283093fffffff
  ('e38f7525-cf85-40ed-8789-2060b373a65b'::uuid, 14400, 2808, 7.8,  15, 15, 'red',    8.9),
  -- VexorRun        blue  province 85283413fffffff
  ('07779731-d601-44a6-bc07-b019c518de64'::uuid, 27000, 2520, 7.0,  13, 13, 'blue',   10.3),
  -- ViperFlip       red   province 8528342bfffffff
  ('fdd90c73-173a-4219-83bd-c93f0f70b8cc'::uuid, 28800, 2340, 6.5,  12, 12, 'red',    11.7),
  -- VoltPeak        blue  province 85283473fffffff
  ('0e7ae5a0-70a6-4249-96bc-1d15bbf2e86e'::uuid, 18000, 2952, 8.2,  16, 16, 'blue',   8.1),
  -- ZephyrBolt      blue  province 85283473fffffff
  ('ae0086d8-e8a5-4021-8930-17af2ce7c77b'::uuid, 23400, 2808, 7.8,  15, 15, 'blue',   9.0),
  -- ZeroStride      red   province 85283433fffffff
  ('d2bf7a51-e7e5-46b1-8306-767c6913cb62'::uuid, 30600, 1800, 5.0,  9,  9,  'red',    13.5)
)
INSERT INTO run_history (
  user_id, run_date, start_time, end_time,
  distance_km, duration_seconds, avg_pace_min_per_km,
  flip_count, flip_points, team_at_run, cv, has_flips
)
SELECT
  r.user_id,
  t.d,
  (t.d::TIMESTAMP AT TIME ZONE 'UTC') + (r.start_secs || ' seconds')::INTERVAL,
  (t.d::TIMESTAMP AT TIME ZONE 'UTC') + (r.start_secs || ' seconds')::INTERVAL + (r.duration_s || ' seconds')::INTERVAL,
  r.distance_km,
  r.duration_s,
  6.0,
  r.flip_count,
  r.flip_points,
  r.team_at_run,
  r.cv,
  true
FROM today t CROSS JOIN runner_data r;
```

---

## Step 2: Insert hex_snapshot (117 rows, snapshot_date = today+2)

```sql
INSERT INTO hex_snapshot (hex_id, last_runner_team, snapshot_date, parent_hex)
SELECT v.hex_id, v.team,
  (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE + 2,
  v.parent_hex
FROM (VALUES
  -- VoltPeak (blue, district 862834707ffffff, province 85283473fffffff)
  ('89283470003ffff', 'blue', '85283473fffffff'),
  ('89283470007ffff', 'blue', '85283473fffffff'),
  -- ArcStride (blue, district 862834707ffffff)
  ('8928347000bffff', 'blue', '85283473fffffff'),
  ('8928347000fffff', 'blue', '85283473fffffff'),
  ('89283470013ffff', 'blue', '85283473fffffff'),
  ('89283470017ffff', 'blue', '85283473fffffff'),
  -- EchoBlaze (red, district 862834707ffffff)
  ('8928347001bffff', 'red', '85283473fffffff'),
  ('89283470023ffff', 'red', '85283473fffffff'),
  ('89283470027ffff', 'red', '85283473fffffff'),
  -- FluxHawk (red, district 86283471fffffff)
  ('89283471003ffff', 'red', '85283473fffffff'),
  ('89283471007ffff', 'red', '85283473fffffff'),
  ('8928347100bffff', 'red', '85283473fffffff'),
  ('8928347100fffff', 'red', '85283473fffffff'),
  -- GlintRun (purple, district 86283471fffffff)
  ('89283471013ffff', 'purple', '85283473fffffff'),
  ('89283471017ffff', 'purple', '85283473fffffff'),
  ('8928347101bffff', 'purple', '85283473fffffff'),
  ('89283471023ffff', 'purple', '85283473fffffff'),
  -- PrismRun (blue, district 86283471fffffff)
  ('89283471027ffff', 'blue', '85283473fffffff'),
  ('8928347102bffff', 'blue', '85283473fffffff'),
  ('8928347102fffff', 'blue', '85283473fffffff'),
  ('89283471033ffff', 'blue', '85283473fffffff'),
  ('89283471037ffff', 'blue', '85283473fffffff'),
  -- NovaDash (blue, district 862834727ffffff)
  ('89283472003ffff', 'blue', '85283473fffffff'),
  ('89283472007ffff', 'blue', '85283473fffffff'),
  ('8928347200bffff', 'blue', '85283473fffffff'),
  -- NeonFury (red, district 862834727ffffff)
  ('8928347200fffff', 'red', '85283473fffffff'),
  ('89283472013ffff', 'red', '85283473fffffff'),
  ('89283472017ffff', 'red', '85283473fffffff'),
  ('8928347201bffff', 'red', '85283473fffffff'),
  -- StormGrit (red, district 862834717ffffff)
  ('89283471803ffff', 'red', '85283473fffffff'),
  ('89283471807ffff', 'red', '85283473fffffff'),
  ('8928347180bffff', 'red', '85283473fffffff'),
  ('8928347180fffff', 'red', '85283473fffffff'),
  -- ZephyrBolt (blue, district 862834717ffffff)
  ('89283471813ffff', 'blue', '85283473fffffff'),
  ('89283471817ffff', 'blue', '85283473fffffff'),
  ('8928347181bffff', 'blue', '85283473fffffff'),
  ('89283471823ffff', 'blue', '85283473fffffff'),
  -- ApexFlux (blue, province 85283443fffffff)
  ('89283440003ffff', 'blue', '85283443fffffff'),
  ('89283440007ffff', 'blue', '85283443fffffff'),
  ('8928344000bffff', 'blue', '85283443fffffff'),
  ('8928344000fffff', 'blue', '85283443fffffff'),
  -- BladeVolt (red, province 8528344bfffffff)
  ('89283448003ffff', 'red', '8528344bfffffff'),
  ('89283448007ffff', 'red', '8528344bfffffff'),
  ('8928344800bffff', 'red', '8528344bfffffff'),
  ('8928344800fffff', 'red', '8528344bfffffff'),
  -- ChronoHex (purple, province 85283423fffffff)
  ('89283420003ffff', 'purple', '85283423fffffff'),
  ('89283420007ffff', 'purple', '85283423fffffff'),
  ('8928342000bffff', 'purple', '85283423fffffff'),
  ('8928342000fffff', 'purple', '85283423fffffff'),
  -- CipherRun (blue, province 85283403fffffff)
  ('89283400003ffff', 'blue', '85283403fffffff'),
  ('89283400007ffff', 'blue', '85283403fffffff'),
  ('8928340000bffff', 'blue', '85283403fffffff'),
  ('8928340000fffff', 'blue', '85283403fffffff'),
  -- FenixDash (red, province 8528343bfffffff)
  ('89283438003ffff', 'red', '8528343bfffffff'),
  ('89283438007ffff', 'red', '8528343bfffffff'),
  ('8928343800bffff', 'red', '8528343bfffffff'),
  ('8928343800fffff', 'red', '8528343bfffffff'),
  -- FrostVolt (blue, province 8528340ffffffff)
  ('8928340c003ffff', 'blue', '8528340ffffffff'),
  ('8928340c007ffff', 'blue', '8528340ffffffff'),
  ('8928340c00bffff', 'blue', '8528340ffffffff'),
  ('8928340c00fffff', 'blue', '8528340ffffffff'),
  -- GhostRun (red, province 85283447fffffff)
  ('89283444003ffff', 'red', '85283447fffffff'),
  ('89283444007ffff', 'red', '85283447fffffff'),
  ('8928344400bffff', 'red', '85283447fffffff'),
  ('8928344400fffff', 'red', '85283447fffffff'),
  -- KyloSprint (purple, province 8528309bfffffff)
  ('89283098003ffff', 'purple', '8528309bfffffff'),
  ('89283098007ffff', 'purple', '8528309bfffffff'),
  ('8928309800bffff', 'purple', '8528309bfffffff'),
  ('8928309800fffff', 'purple', '8528309bfffffff'),
  -- LunaFlip (purple, province 852830d3fffffff)
  ('892830d0003ffff', 'purple', '852830d3fffffff'),
  ('892830d0007ffff', 'purple', '852830d3fffffff'),
  ('892830d000bffff', 'purple', '852830d3fffffff'),
  ('892830d000fffff', 'purple', '852830d3fffffff'),
  -- MiruHex (purple, province 8528342ffffffff)
  ('8928342c003ffff', 'purple', '8528342ffffffff'),
  ('8928342c007ffff', 'purple', '8528342ffffffff'),
  ('8928342c00bffff', 'purple', '8528342ffffffff'),
  ('8928342c00fffff', 'purple', '8528342ffffffff'),
  -- MossRun (blue, province 852830d7fffffff)
  ('892830d4003ffff', 'blue', '852830d7fffffff'),
  ('892830d4007ffff', 'blue', '852830d7fffffff'),
  ('892830d400bffff', 'blue', '852830d7fffffff'),
  ('892830d400fffff', 'blue', '852830d7fffffff'),
  -- OrbitDash (red, province 8528340bfffffff)
  ('89283408003ffff', 'red', '8528340bfffffff'),
  ('89283408007ffff', 'red', '8528340bfffffff'),
  ('8928340800bffff', 'red', '8528340bfffffff'),
  ('8928340800fffff', 'red', '8528340bfffffff'),
  -- PlasmaGrit (red, province 85283417fffffff)
  ('89283414003ffff', 'red', '85283417fffffff'),
  ('89283414007ffff', 'red', '85283417fffffff'),
  ('8928341400bffff', 'red', '85283417fffffff'),
  ('8928341400fffff', 'red', '85283417fffffff'),
  -- PulseArc (blue, province 8528344ffffffff)
  ('8928344c003ffff', 'blue', '8528344ffffffff'),
  ('8928344c007ffff', 'blue', '8528344ffffffff'),
  ('8928344c00bffff', 'blue', '8528344ffffffff'),
  ('8928344c00fffff', 'blue', '8528344ffffffff'),
  -- RiftBlaze (purple, province 85283407fffffff)
  ('89283404003ffff', 'purple', '85283407fffffff'),
  ('89283404007ffff', 'purple', '85283407fffffff'),
  ('8928340400bffff', 'purple', '85283407fffffff'),
  ('8928340400fffff', 'purple', '85283407fffffff'),
  -- StellarRun (blue, province 8528341bfffffff)
  ('89283418003ffff', 'blue', '8528341bfffffff'),
  ('89283418007ffff', 'blue', '8528341bfffffff'),
  ('8928341800bffff', 'blue', '8528341bfffffff'),
  ('8928341800fffff', 'blue', '8528341bfffffff'),
  -- TerraWave (red, province 85283093fffffff)
  ('89283090003ffff', 'red', '85283093fffffff'),
  ('89283090007ffff', 'red', '85283093fffffff'),
  ('8928309000bffff', 'red', '85283093fffffff'),
  ('8928309000fffff', 'red', '85283093fffffff'),
  -- VexorRun (blue, province 85283413fffffff)
  ('89283410003ffff', 'blue', '85283413fffffff'),
  ('89283410007ffff', 'blue', '85283413fffffff'),
  ('8928341000bffff', 'blue', '85283413fffffff'),
  ('8928341000fffff', 'blue', '85283413fffffff'),
  -- ViperFlip (red, province 8528342bfffffff)
  ('89283428003ffff', 'red', '8528342bfffffff'),
  ('89283428007ffff', 'red', '8528342bfffffff'),
  ('8928342800bffff', 'red', '8528342bfffffff'),
  ('8928342800fffff', 'red', '8528342bfffffff'),
  -- ZeroStride (red, province 85283433fffffff)
  ('89283430003ffff', 'red', '85283433fffffff'),
  ('89283430007ffff', 'red', '85283433fffffff'),
  ('8928343000bffff', 'red', '85283433fffffff'),
  ('8928343000fffff', 'red', '85283433fffffff')
) AS v(hex_id, team, parent_hex)
ON CONFLICT DO NOTHING;
```

---

## Step 3: Upsert hexes (live table, 117 rows)

`last_flipped_at` = runner's end time on today's UTC date. Only updates if newer than existing value.

```sql
INSERT INTO hexes (id, last_runner_team, last_flipped_at, parent_hex)
SELECT
  v.hex_id,
  v.team,
  (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE::TIMESTAMP AT TIME ZONE 'UTC' + v.end_offset,
  v.parent_hex
FROM (VALUES
  -- VoltPeak (end 05:49:12 UTC) — district 862834707ffffff
  ('89283470003ffff', 'blue', '85283473fffffff', INTERVAL '5 hours 49 minutes 12 seconds'),
  ('89283470007ffff', 'blue', '85283473fffffff', INTERVAL '5 hours 49 minutes 12 seconds'),
  -- ArcStride (end 05:34:48 UTC) — district 862834707ffffff
  ('8928347000bffff', 'blue', '85283473fffffff', INTERVAL '5 hours 34 minutes 48 seconds'),
  ('8928347000fffff', 'blue', '85283473fffffff', INTERVAL '5 hours 34 minutes 48 seconds'),
  ('89283470013ffff', 'blue', '85283473fffffff', INTERVAL '5 hours 34 minutes 48 seconds'),
  ('89283470017ffff', 'blue', '85283473fffffff', INTERVAL '5 hours 34 minutes 48 seconds'),
  -- EchoBlaze (end 06:58:48 UTC) — district 862834707ffffff
  ('8928347001bffff', 'red', '85283473fffffff',  INTERVAL '6 hours 58 minutes 48 seconds'),
  ('89283470023ffff', 'red', '85283473fffffff',  INTERVAL '6 hours 58 minutes 48 seconds'),
  ('89283470027ffff', 'red', '85283473fffffff',  INTERVAL '6 hours 58 minutes 48 seconds'),
  -- FluxHawk (end 06:06:00 UTC) — district 86283471fffffff
  ('89283471003ffff', 'red', '85283473fffffff',  INTERVAL '6 hours 6 minutes'),
  ('89283471007ffff', 'red', '85283473fffffff',  INTERVAL '6 hours 6 minutes'),
  ('8928347100bffff', 'red', '85283473fffffff',  INTERVAL '6 hours 6 minutes'),
  ('8928347100fffff', 'red', '85283473fffffff',  INTERVAL '6 hours 6 minutes'),
  -- GlintRun (end 06:39:00 UTC) — district 86283471fffffff
  ('89283471013ffff', 'purple', '85283473fffffff', INTERVAL '6 hours 39 minutes'),
  ('89283471017ffff', 'purple', '85283473fffffff', INTERVAL '6 hours 39 minutes'),
  ('8928347101bffff', 'purple', '85283473fffffff', INTERVAL '6 hours 39 minutes'),
  ('89283471023ffff', 'purple', '85283473fffffff', INTERVAL '6 hours 39 minutes'),
  -- PrismRun (end 05:57:00 UTC) — district 86283471fffffff
  ('89283471027ffff', 'blue', '85283473fffffff', INTERVAL '5 hours 57 minutes'),
  ('8928347102bffff', 'blue', '85283473fffffff', INTERVAL '5 hours 57 minutes'),
  ('8928347102fffff', 'blue', '85283473fffffff', INTERVAL '5 hours 57 minutes'),
  ('89283471033ffff', 'blue', '85283473fffffff', INTERVAL '5 hours 57 minutes'),
  ('89283471037ffff', 'blue', '85283473fffffff', INTERVAL '5 hours 57 minutes'),
  -- NovaDash (end 08:30:00 UTC) — district 862834727ffffff
  ('89283472003ffff', 'blue', '85283473fffffff', INTERVAL '8 hours 30 minutes'),
  ('89283472007ffff', 'blue', '85283473fffffff', INTERVAL '8 hours 30 minutes'),
  ('8928347200bffff', 'blue', '85283473fffffff', INTERVAL '8 hours 30 minutes'),
  -- NeonFury (end 05:54:00 UTC) — district 862834727ffffff
  ('8928347200fffff', 'red', '85283473fffffff',  INTERVAL '5 hours 54 minutes'),
  ('89283472013ffff', 'red', '85283473fffffff',  INTERVAL '5 hours 54 minutes'),
  ('89283472017ffff', 'red', '85283473fffffff',  INTERVAL '5 hours 54 minutes'),
  ('8928347201bffff', 'red', '85283473fffffff',  INTERVAL '5 hours 54 minutes'),
  -- StormGrit (end 06:18:00 UTC) — district 862834717ffffff
  ('89283471803ffff', 'red', '85283473fffffff',  INTERVAL '6 hours 18 minutes'),
  ('89283471807ffff', 'red', '85283473fffffff',  INTERVAL '6 hours 18 minutes'),
  ('8928347180bffff', 'red', '85283473fffffff',  INTERVAL '6 hours 18 minutes'),
  ('8928347180fffff', 'red', '85283473fffffff',  INTERVAL '6 hours 18 minutes'),
  -- ZephyrBolt (end 07:16:48 UTC) — district 862834717ffffff
  ('89283471813ffff', 'blue', '85283473fffffff', INTERVAL '7 hours 16 minutes 48 seconds'),
  ('89283471817ffff', 'blue', '85283473fffffff', INTERVAL '7 hours 16 minutes 48 seconds'),
  ('8928347181bffff', 'blue', '85283473fffffff', INTERVAL '7 hours 16 minutes 48 seconds'),
  ('89283471823ffff', 'blue', '85283473fffffff', INTERVAL '7 hours 16 minutes 48 seconds'),
  -- ApexFlux (end 04:31:12 UTC)
  ('89283440003ffff', 'blue', '85283443fffffff', INTERVAL '4 hours 31 minutes 12 seconds'),
  ('89283440007ffff', 'blue', '85283443fffffff', INTERVAL '4 hours 31 minutes 12 seconds'),
  ('8928344000bffff', 'blue', '85283443fffffff', INTERVAL '4 hours 31 minutes 12 seconds'),
  ('8928344000fffff', 'blue', '85283443fffffff', INTERVAL '4 hours 31 minutes 12 seconds'),
  -- BladeVolt (end 05:15:00 UTC)
  ('89283448003ffff', 'red', '8528344bfffffff',  INTERVAL '5 hours 15 minutes'),
  ('89283448007ffff', 'red', '8528344bfffffff',  INTERVAL '5 hours 15 minutes'),
  ('8928344800bffff', 'red', '8528344bfffffff',  INTERVAL '5 hours 15 minutes'),
  ('8928344800fffff', 'red', '8528344bfffffff',  INTERVAL '5 hours 15 minutes'),
  -- ChronoHex (end 06:42:00 UTC)
  ('89283420003ffff', 'purple', '85283423fffffff', INTERVAL '6 hours 42 minutes'),
  ('89283420007ffff', 'purple', '85283423fffffff', INTERVAL '6 hours 42 minutes'),
  ('8928342000bffff', 'purple', '85283423fffffff', INTERVAL '6 hours 42 minutes'),
  ('8928342000fffff', 'purple', '85283423fffffff', INTERVAL '6 hours 42 minutes'),
  -- CipherRun (end 07:33:00 UTC)
  ('89283400003ffff', 'blue', '85283403fffffff', INTERVAL '7 hours 33 minutes'),
  ('89283400007ffff', 'blue', '85283403fffffff', INTERVAL '7 hours 33 minutes'),
  ('8928340000bffff', 'blue', '85283403fffffff', INTERVAL '7 hours 33 minutes'),
  ('8928340000fffff', 'blue', '85283403fffffff', INTERVAL '7 hours 33 minutes'),
  -- FenixDash (end 08:25:12 UTC)
  ('89283438003ffff', 'red', '8528343bfffffff',  INTERVAL '8 hours 25 minutes 12 seconds'),
  ('89283438007ffff', 'red', '8528343bfffffff',  INTERVAL '8 hours 25 minutes 12 seconds'),
  ('8928343800bffff', 'red', '8528343bfffffff',  INTERVAL '8 hours 25 minutes 12 seconds'),
  ('8928343800fffff', 'red', '8528343bfffffff',  INTERVAL '8 hours 25 minutes 12 seconds'),
  -- FrostVolt (end 09:24:00 UTC)
  ('8928340c003ffff', 'blue', '8528340ffffffff', INTERVAL '9 hours 24 minutes'),
  ('8928340c007ffff', 'blue', '8528340ffffffff', INTERVAL '9 hours 24 minutes'),
  ('8928340c00bffff', 'blue', '8528340ffffffff', INTERVAL '9 hours 24 minutes'),
  ('8928340c00fffff', 'blue', '8528340ffffffff', INTERVAL '9 hours 24 minutes'),
  -- GhostRun (end 07:55:12 UTC)
  ('89283444003ffff', 'red', '85283447fffffff',  INTERVAL '7 hours 55 minutes 12 seconds'),
  ('89283444007ffff', 'red', '85283447fffffff',  INTERVAL '7 hours 55 minutes 12 seconds'),
  ('8928344400bffff', 'red', '85283447fffffff',  INTERVAL '7 hours 55 minutes 12 seconds'),
  ('8928344400fffff', 'red', '85283447fffffff',  INTERVAL '7 hours 55 minutes 12 seconds'),
  -- KyloSprint (end 04:46:48 UTC)
  ('89283098003ffff', 'purple', '8528309bfffffff', INTERVAL '4 hours 46 minutes 48 seconds'),
  ('89283098007ffff', 'purple', '8528309bfffffff', INTERVAL '4 hours 46 minutes 48 seconds'),
  ('8928309800bffff', 'purple', '8528309bfffffff', INTERVAL '4 hours 46 minutes 48 seconds'),
  ('8928309800fffff', 'purple', '8528309bfffffff', INTERVAL '4 hours 46 minutes 48 seconds'),
  -- LunaFlip (end 05:46:48 UTC)
  ('892830d0003ffff', 'purple', '852830d3fffffff', INTERVAL '5 hours 46 minutes 48 seconds'),
  ('892830d0007ffff', 'purple', '852830d3fffffff', INTERVAL '5 hours 46 minutes 48 seconds'),
  ('892830d000bffff', 'purple', '852830d3fffffff', INTERVAL '5 hours 46 minutes 48 seconds'),
  ('892830d000fffff', 'purple', '852830d3fffffff', INTERVAL '5 hours 46 minutes 48 seconds'),
  -- MiruHex (end 07:45:00 UTC)
  ('8928342c003ffff', 'purple', '8528342ffffffff', INTERVAL '7 hours 45 minutes'),
  ('8928342c007ffff', 'purple', '8528342ffffffff', INTERVAL '7 hours 45 minutes'),
  ('8928342c00bffff', 'purple', '8528342ffffffff', INTERVAL '7 hours 45 minutes'),
  ('8928342c00fffff', 'purple', '8528342ffffffff', INTERVAL '7 hours 45 minutes'),
  -- MossRun (end 04:51:00 UTC)
  ('892830d4003ffff', 'blue', '852830d7fffffff', INTERVAL '4 hours 51 minutes'),
  ('892830d4007ffff', 'blue', '852830d7fffffff', INTERVAL '4 hours 51 minutes'),
  ('892830d400bffff', 'blue', '852830d7fffffff', INTERVAL '4 hours 51 minutes'),
  ('892830d400fffff', 'blue', '852830d7fffffff', INTERVAL '4 hours 51 minutes'),
  -- OrbitDash (end 06:36:00 UTC)
  ('89283408003ffff', 'red', '8528340bfffffff',  INTERVAL '6 hours 36 minutes'),
  ('89283408007ffff', 'red', '8528340bfffffff',  INTERVAL '6 hours 36 minutes'),
  ('8928340800bffff', 'red', '8528340bfffffff',  INTERVAL '6 hours 36 minutes'),
  ('8928340800fffff', 'red', '8528340bfffffff',  INTERVAL '6 hours 36 minutes'),
  -- PlasmaGrit (end 09:54:00 UTC)
  ('89283414003ffff', 'red', '85283417fffffff',  INTERVAL '9 hours 54 minutes'),
  ('89283414007ffff', 'red', '85283417fffffff',  INTERVAL '9 hours 54 minutes'),
  ('8928341400bffff', 'red', '85283417fffffff',  INTERVAL '9 hours 54 minutes'),
  ('8928341400fffff', 'red', '85283417fffffff',  INTERVAL '9 hours 54 minutes'),
  -- PulseArc (end 05:16:48 UTC)
  ('8928344c003ffff', 'blue', '8528344ffffffff', INTERVAL '5 hours 16 minutes 48 seconds'),
  ('8928344c007ffff', 'blue', '8528344ffffffff', INTERVAL '5 hours 16 minutes 48 seconds'),
  ('8928344c00bffff', 'blue', '8528344ffffffff', INTERVAL '5 hours 16 minutes 48 seconds'),
  ('8928344c00fffff', 'blue', '8528344ffffffff', INTERVAL '5 hours 16 minutes 48 seconds'),
  -- RiftBlaze (end 06:45:00 UTC)
  ('89283404003ffff', 'purple', '85283407fffffff', INTERVAL '6 hours 45 minutes'),
  ('89283404007ffff', 'purple', '85283407fffffff', INTERVAL '6 hours 45 minutes'),
  ('8928340400bffff', 'purple', '85283407fffffff', INTERVAL '6 hours 45 minutes'),
  ('8928340400fffff', 'purple', '85283407fffffff', INTERVAL '6 hours 45 minutes'),
  -- StellarRun (end 10:22:48 UTC)
  ('89283418003ffff', 'blue', '8528341bfffffff', INTERVAL '10 hours 22 minutes 48 seconds'),
  ('89283418007ffff', 'blue', '8528341bfffffff', INTERVAL '10 hours 22 minutes 48 seconds'),
  ('8928341800bffff', 'blue', '8528341bfffffff', INTERVAL '10 hours 22 minutes 48 seconds'),
  ('8928341800fffff', 'blue', '8528341bfffffff', INTERVAL '10 hours 22 minutes 48 seconds'),
  -- TerraWave (end 04:46:48 UTC)
  ('89283090003ffff', 'red', '85283093fffffff',  INTERVAL '4 hours 46 minutes 48 seconds'),
  ('89283090007ffff', 'red', '85283093fffffff',  INTERVAL '4 hours 46 minutes 48 seconds'),
  ('8928309000bffff', 'red', '85283093fffffff',  INTERVAL '4 hours 46 minutes 48 seconds'),
  ('8928309000fffff', 'red', '85283093fffffff',  INTERVAL '4 hours 46 minutes 48 seconds'),
  -- VexorRun (end 08:12:00 UTC)
  ('89283410003ffff', 'blue', '85283413fffffff', INTERVAL '8 hours 12 minutes'),
  ('89283410007ffff', 'blue', '85283413fffffff', INTERVAL '8 hours 12 minutes'),
  ('8928341000bffff', 'blue', '85283413fffffff', INTERVAL '8 hours 12 minutes'),
  ('8928341000fffff', 'blue', '85283413fffffff', INTERVAL '8 hours 12 minutes'),
  -- ViperFlip (end 08:39:00 UTC)
  ('89283428003ffff', 'red', '8528342bfffffff',  INTERVAL '8 hours 39 minutes'),
  ('89283428007ffff', 'red', '8528342bfffffff',  INTERVAL '8 hours 39 minutes'),
  ('8928342800bffff', 'red', '8528342bfffffff',  INTERVAL '8 hours 39 minutes'),
  ('8928342800fffff', 'red', '8528342bfffffff',  INTERVAL '8 hours 39 minutes'),
  -- ZeroStride (end 09:00:00 UTC)
  ('89283430003ffff', 'red', '85283433fffffff',  INTERVAL '9 hours'),
  ('89283430007ffff', 'red', '85283433fffffff',  INTERVAL '9 hours'),
  ('8928343000bffff', 'red', '85283433fffffff',  INTERVAL '9 hours'),
  ('8928343000fffff', 'red', '85283433fffffff',  INTERVAL '9 hours')
) AS v(hex_id, team, parent_hex, end_offset)
ON CONFLICT (id) DO UPDATE SET
  last_runner_team = EXCLUDED.last_runner_team,
  last_flipped_at  = EXCLUDED.last_flipped_at
WHERE hexes.last_flipped_at < EXCLUDED.last_flipped_at;
```

---

## Step 4: Update users.season_points

Increments each runner's season_points by their flip_points for today's run.

```sql
UPDATE users SET season_points = season_points + CASE id
  WHEN '83417bdd-3aef-46d4-a2f8-6f920f0b4e17' THEN 9   -- ApexFlux
  WHEN '24bf6c86-235f-4da8-9e0f-1b74e3db2363' THEN 10  -- ArcStride
  WHEN 'c8ba2c35-63fb-4247-9166-ba0fd323f5f1' THEN 14  -- BladeVolt
  WHEN '89ef89d4-c654-4921-9d4a-b341a0330687' THEN 13  -- ChronoHex
  WHEN 'a8a2f2a0-e8ee-424a-b0b1-d64ae798827a' THEN 10  -- CipherRun
  WHEN '713bcdaf-614c-4024-8454-567f77b18e4c' THEN 8   -- EchoBlaze
  WHEN 'd257c4db-4120-437f-a8c1-b52bf3fe564a' THEN 7   -- FenixDash
  WHEN '22bebd8b-c803-4d77-8a0f-5c932b44f298' THEN 11  -- FluxHawk
  WHEN '4226f6d8-6aa4-4dd9-9817-41b5faa36159' THEN 7   -- FrostVolt
  WHEN '168ad17c-9705-4c13-abb6-c4097d05d99e' THEN 7   -- GhostRun
  WHEN '7cdb088a-ee1c-4aed-824e-665dc3779df2' THEN 12  -- GlintRun
  WHEN '490e8a4d-0b4e-4556-adb7-84fe4a71e6be' THEN 15  -- KyloSprint
  WHEN '5acf5231-00ec-4758-b71f-fbff87b176cd' THEN 15  -- LunaFlip
  WHEN 'de7b8e5d-08e5-406e-af53-8daec612c99f' THEN 14  -- MiruHex
  WHEN '0a625603-164a-4477-9631-243c501814da' THEN 17  -- MossRun
  WHEN 'a758e639-f485-4bc0-a68f-0b0baaed3fad' THEN 18  -- NeonFury
  WHEN 'b1a010f9-dc49-4c0c-a96e-fab7d2fd4632' THEN 9   -- NovaDash
  WHEN '87e86e98-98b8-4dab-9973-f357ac6285ec' THEN 11  -- OrbitDash
  WHEN '06826d41-b401-4b7c-a8c7-be9631340f99' THEN 7   -- PlasmaGrit
  WHEN '15c14c4d-9a4a-4814-b4f9-74d1e181eb32' THEN 19  -- PrismRun
  WHEN '02900328-95df-42e9-9e46-ce596cc113d6' THEN 15  -- PulseArc
  WHEN '780bb396-d969-457d-a885-d4c277c848d7' THEN 14  -- RiftBlaze
  WHEN '3adf998f-10fb-4e01-ac41-b1c138a0cb0a' THEN 6   -- StellarRun
  WHEN '63394070-7353-41d8-b59c-62c122728433' THEN 16  -- StormGrit
  WHEN 'e38f7525-cf85-40ed-8789-2060b373a65b' THEN 15  -- TerraWave
  WHEN '07779731-d601-44a6-bc07-b019c518de64' THEN 13  -- VexorRun
  WHEN 'fdd90c73-173a-4219-83bd-c93f0f70b8cc' THEN 12  -- ViperFlip
  WHEN '0e7ae5a0-70a6-4249-96bc-1d15bbf2e86e' THEN 16  -- VoltPeak
  WHEN 'ae0086d8-e8a5-4021-8930-17af2ce7c77b' THEN 15  -- ZephyrBolt
  WHEN 'd2bf7a51-e7e5-46b1-8306-767c6913cb62' THEN 9   -- ZeroStride
  ELSE 0
END
WHERE id IN (
  '83417bdd-3aef-46d4-a2f8-6f920f0b4e17','24bf6c86-235f-4da8-9e0f-1b74e3db2363',
  'c8ba2c35-63fb-4247-9166-ba0fd323f5f1','89ef89d4-c654-4921-9d4a-b341a0330687',
  'a8a2f2a0-e8ee-424a-b0b1-d64ae798827a','713bcdaf-614c-4024-8454-567f77b18e4c',
  'd257c4db-4120-437f-a8c1-b52bf3fe564a','22bebd8b-c803-4d77-8a0f-5c932b44f298',
  '4226f6d8-6aa4-4dd9-9817-41b5faa36159','168ad17c-9705-4c13-abb6-c4097d05d99e',
  '7cdb088a-ee1c-4aed-824e-665dc3779df2','490e8a4d-0b4e-4556-adb7-84fe4a71e6be',
  '5acf5231-00ec-4758-b71f-fbff87b176cd','de7b8e5d-08e5-406e-af53-8daec612c99f',
  '0a625603-164a-4477-9631-243c501814da','a758e639-f485-4bc0-a68f-0b0baaed3fad',
  'b1a010f9-dc49-4c0c-a96e-fab7d2fd4632','87e86e98-98b8-4dab-9973-f357ac6285ec',
  '06826d41-b401-4b7c-a8c7-be9631340f99','15c14c4d-9a4a-4814-b4f9-74d1e181eb32',
  '02900328-95df-42e9-9e46-ce596cc113d6','780bb396-d969-457d-a885-d4c277c848d7',
  '3adf998f-10fb-4e01-ac41-b1c138a0cb0a','63394070-7353-41d8-b59c-62c122728433',
  'e38f7525-cf85-40ed-8789-2060b373a65b','07779731-d601-44a6-bc07-b019c518de64',
  'fdd90c73-173a-4219-83bd-c93f0f70b8cc','0e7ae5a0-70a6-4249-96bc-1d15bbf2e86e',
  'ae0086d8-e8a5-4021-8930-17af2ce7c77b','d2bf7a51-e7e5-46b1-8306-767c6913cb62'
);
```

---

## Step 5: Verify

```sql
SELECT
  (SELECT COUNT(*) FROM run_history
    WHERE run_date = (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE
      AND user_id != '08f88e4b-26f1-4028-a481-bbf140e588a1') AS run_history_today,
  (SELECT COUNT(*) FROM hex_snapshot
    WHERE snapshot_date = (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE + 2) AS hex_snapshot_count,
  (SELECT COUNT(DISTINCT parent_hex) FROM hex_snapshot
    WHERE snapshot_date = (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE + 2) AS provinces;
```

**Expected**: `run_history_today = 30, hex_snapshot_count = 117, provinces = 21`
