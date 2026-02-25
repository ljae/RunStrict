-- =============================================================================
-- RESEED: Wipe all data, create 200 runners with S4 run history (Feb 21–23)
-- =============================================================================
-- Season 4: Feb 21–26 (5-day). Yesterday = Feb 23.
-- 200 seed runners: dddddddd-0001 through dddddddd-00c8
-- Province split: 120 in 862834* (7 districts), 80 in 862830* (4 districts)
-- Team split: ~40% red (80), ~35% blue (70), ~25% purple (50)
-- Runner type: 160 hard (80%), 40 lazy (20%)
-- public.users.id = auth.users.id (no separate auth_id column)
-- =============================================================================

-- Step 1: Wipe all existing data (clean slate)
DELETE FROM public.run_history;
DELETE FROM public.hex_snapshot;
DELETE FROM public.hexes;
DELETE FROM public.daily_buff_stats;
DELETE FROM public.daily_province_range_stats;
DELETE FROM public.daily_all_range_stats;
DELETE FROM public.season_leaderboard_snapshot;

-- Remove all seed users (both @seed.local and @stress.local)
DELETE FROM public.users WHERE id IN (
  SELECT u.id FROM public.users u
  JOIN auth.users a ON u.id = a.id
  WHERE a.email LIKE '%@seed.local' OR a.email LIKE '%@stress.local'
);
DELETE FROM auth.identities WHERE user_id IN (
  SELECT id FROM auth.users WHERE email LIKE '%@seed.local' OR email LIKE '%@stress.local'
);
DELETE FROM auth.users WHERE email LIKE '%@seed.local' OR email LIKE '%@stress.local';

-- Reset real user stats
UPDATE public.users SET
  season_points = 0,
  total_runs = 0,
  total_distance_km = 0,
  avg_pace_min_per_km = NULL,
  avg_cv = NULL,
  cv_run_count = 0,
  home_hex = NULL,
  home_hex_start = NULL,
  home_hex_end = NULL,
  season_home_hex = NULL,
  district_hex = NULL
WHERE id IN (
  SELECT u.id FROM public.users u
  JOIN auth.users a ON u.id = a.id
  WHERE a.email NOT LIKE '%@seed.local'
);

-- =============================================================================
-- Step 2-7: Create 200 runners, run_history, hexes, stats (procedural)
-- =============================================================================
DO $$
DECLARE
  v_uid UUID;
  v_idx INTEGER;
  v_hex_idx TEXT;
  v_email TEXT;
  v_name TEXT;
  v_team TEXT;
  v_is_hard BOOLEAN;
  v_district_hex TEXT;
  v_home_hex TEXT;
  v_sex TEXT;
  v_nationality TEXT;

  -- Run generation
  v_run_date DATE;
  v_runs_today INTEGER;
  v_distance DOUBLE PRECISION;
  v_pace DOUBLE PRECISION;
  v_duration INTEGER;
  v_flip_count INTEGER;
  v_cv DOUBLE PRECISION;
  v_start_hour INTEGER;
  v_start_time TIMESTAMPTZ;
  v_end_time TIMESTAMPTZ;

  -- Aggregates
  v_total_points INTEGER;
  v_total_distance DOUBLE PRECISION;
  v_total_runs INTEGER;
  v_avg_pace DOUBLE PRECISION;
  v_avg_cv DOUBLE PRECISION;

  -- District assignments
  v_districts_834 TEXT[] := ARRAY[
    '862834707ffffff', '862834717ffffff', '862834727ffffff',
    '86283472fffffff', '862834757ffffff', '862834777ffffff',
    '86283471fffffff'
  ];
  v_districts_830 TEXT[] := ARRAY[
    '86283082fffffff', '862830947ffffff', '862830957ffffff',
    '862830977ffffff'
  ];

  v_hex_id TEXT;
  v_hex_suffixes TEXT[] := ARRAY[
    '03ffff','07ffff','0bffff','0fffff','13ffff','17ffff','1bffff','1fffff',
    '23ffff','27ffff','2bffff','2fffff','33ffff','37ffff','3bffff','3fffff',
    '43ffff','47ffff','4bffff','4fffff','53ffff','57ffff','5bffff','5fffff',
    '63ffff','67ffff','6bffff','6fffff','73ffff','77ffff','7bffff','7fffff',
    '83ffff','87ffff','8bffff','8fffff','93ffff','97ffff','9bffff','9fffff',
    'a3ffff','a7ffff','abffff','afffff','b3ffff','b7ffff','bbffff','bfffff',
    'c3ffff','c7ffff'
  ];

  v_first_names TEXT[] := ARRAY[
    'Ace','Ada','Ash','Bay','Bo','Cal','Cam','Cy','Dex','Eli',
    'Eve','Finn','Gil','Hal','Ida','Ivy','Jax','Jet','Kai','Kit',
    'Leo','Liv','Max','Mia','Neo','Nia','Ori','Paz','Rae','Rex',
    'Rio','Rue','Sam','Sky','Sol','Tai','Val','Vic','Wes','Zoe',
    'Arlo','Bea','Cole','Dana','Eden','Fay','Gray','Hope','Iris','Jade',
    'Knox','Lark','Milo','Nova','Odin','Pax','Quinn','Reed','Sage','Tate',
    'Uma','Vera','Wade','Xena','Yuki','Zara','Axel','Bree','Cruz','Drew',
    'Ember','Fox','Glen','Hart','Isla','June','Kira','Lane','Mars','Nell',
    'Oak','Pip','Remy','Star','Troy','Uri','Vex','Wren','Yael','Zion',
    'Alba','Blaze','Cedar','Dove','Echo','Fern','Gem','Haze','Ink','Joy',
    'Koda','Luna','Moss','Nyx','Onyx','Pine','Quill','Rain','Storm','Thorn',
    'Ursa','Vale','Wisp','Xion','York','Zen','Aria','Birch','Clay','Dawn',
    'Elio','Flint','Gold','Hawk','Ion','Jasper','Kelp','Lux','Mira','North',
    'Opal','Pearl','Quartz','River','Stone','Tide','Ulric','Viper','Wolf','Xeno',
    'Yarrow','Zinc','Aero','Bolt','Cliff','Drift','Elm','Flash','Grit','Husk',
    'Iron','Jolt','Keen','Lyric','Meadow','Nimbus','Orbit','Prism','Radiant','Silk',
    'Terra','Umbra','Volt','Zenith','Aura','Bliss','Coral','Dusk','Frost','Glow',
    'Ivory','Jewel','Lunar','Marble','Noble','Orca','Plume','Raven','Swift','Thunder',
    'Unity','Velvet','Willow','Xylo','Yew','Zephyr','Amber','Breeze','Crest','Delta',
    'Ember','Flame','Grove','Horizon','Indigo','Jewel','Karma','Light','Mystic','Nebula'
  ];

  v_last_names TEXT[] := ARRAY[
    'Run','Bolt','Dash','Fire','Wind','Rock','Star','Moon','Sun','Wave',
    'Storm','Cloud','Iron','Steel','Gold','Frost','Blaze','Flash','Swift','Light',
    'Shadow','Spark','Trail','Pace','Stride','Sprint','Glide','Chase','Flow','Rush',
    'Jet','Gale','Strike','Rise','Soar','Drift','Leap','Surge','Zoom','Arc',
    'Peak','Ridge','Crest','Vale','Brook','Creek','Shore','Bay','Marsh','Glen',
    'Hill','Cliff','Stone','Slate','Flint','Ash','Ember','Flame','Blaze','Heat',
    'Frost','Ice','Snow','Hail','Rain','Mist','Fog','Dawn','Dusk','Night',
    'Sky','Terra','Field','Meadow','Grove','Wood','Oak','Elm','Pine','Cedar',
    'Hawk','Eagle','Falcon','Wolf','Fox','Bear','Lion','Tiger','Raven','Crane',
    'Coral','Pearl','Jade','Ruby','Opal','Onyx','Agate','Topaz','Amber','Quartz',
    'Zen','Sage','Brave','True','Noble','Keen','Wise','Pure','Free','Strong',
    'Bright','Clear','Deep','High','Long','Fast','Far','Wild','Grand','Bold',
    'North','South','East','West','Cross','Bridge','Gate','Tower','Wall','Path',
    'Road','Track','Lane','Trail','Route','Loop','Ring','Bend','Turn','Edge',
    'Spark','Volt','Beam','Glow','Ray','Flash','Pulse','Wave','Tide','Flow',
    'Crown','Crest','Peak','Summit','Ridge','Spire','Apex','Zenith','Pinnacle','Top',
    'Forge','Anvil','Blade','Edge','Point','Tip','Shard','Spike','Thorn','Barb',
    'River','Lake','Ocean','Sea','Pond','Pool','Stream','Falls','Rapids','Delta',
    'Dust','Sand','Clay','Mud','Soil','Earth','Ground','Base','Root','Core',
    'Wing','Feather','Plume','Down','Fur','Mane','Claw','Fang','Horn','Tusk'
  ];

  v_nationalities TEXT[] := ARRAY[
    'US','KR','JP','DE','GB','FR','AU','CA','IN','BR',
    'ES','IT','NL','MX','PH','CN'
  ];
  v_sexes TEXT[] := ARRAY['male','female','other'];
  v_manifestos TEXT[] := ARRAY[
    'Born to run','Never stop running','Every step counts',
    'Find your stride','Keep moving forward','No limits',
    'Run the world','Pain is temporary','Built different',
    'Outrun your demons','Heart of a champion','Roads are my canvas',
    'The grind never stops','Speed is a mindset','Conquer every mile',
    'Miles of smiles','Running is freedom','Eat sleep run repeat',
    'The road calls me','Push your limits'
  ];

  v_d INTEGER;
  v_r INTEGER;
  v_h INTEGER;
BEGIN
  PERFORM setseed(0.42);

  FOR v_idx IN 1..200 LOOP
    v_hex_idx := lpad(to_hex(v_idx), 4, '0');
    v_uid := ('dddddddd-' || v_hex_idx || '-4000-a000-00000000' || v_hex_idx)::UUID;
    v_email := 'runner' || (200 + v_idx) || '@seed.local';

    v_name := v_first_names[1 + (random() * (array_length(v_first_names,1)-1))::INTEGER]
           || v_last_names[1 + (random() * (array_length(v_last_names,1)-1))::INTEGER];

    IF v_idx <= 80 THEN v_team := 'red';
    ELSIF v_idx <= 150 THEN v_team := 'blue';
    ELSE v_team := 'purple';
    END IF;

    v_is_hard := (v_idx <= 160);

    IF v_idx <= 120 THEN
      v_district_hex := v_districts_834[1 + ((v_idx - 1) % 7)];
    ELSE
      v_district_hex := v_districts_830[1 + ((v_idx - 121) % 4)];
    END IF;

    v_home_hex := '89' || substring(v_district_hex from 3 for 7)
               || v_hex_suffixes[1 + ((v_idx - 1) % 50)];

    v_sex := v_sexes[1 + (random() * 2)::INTEGER];
    v_nationality := v_nationalities[1 + (random() * (array_length(v_nationalities,1)-1))::INTEGER];

    -- Insert auth.users (id = public.users.id)
    INSERT INTO auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      raw_app_meta_data, raw_user_meta_data, is_super_admin
    ) VALUES (
      v_uid, '00000000-0000-0000-0000-000000000000',
      'authenticated', 'authenticated', v_email,
      '$2a$10$PK.0Bq2gGGlOJf/XQHf1pOKGwHAQKbP0lWP.JZl8BQKXF.AeGsOLC',
      now(), now(), now(), '', '', '', '',
      '{"provider":"email","providers":["email"]}', '{}', false
    );

    INSERT INTO auth.identities (
      id, provider_id, user_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) VALUES (
      gen_random_uuid(), v_uid::TEXT, v_uid,
      jsonb_build_object('sub', v_uid::TEXT, 'email', v_email),
      'email', now(), now(), now()
    );

    -- Insert public.users (id matches auth.users.id)
    INSERT INTO public.users (
      id, name, team, avatar, season_points, manifesto,
      home_hex, home_hex_start, home_hex_end, season_home_hex, district_hex,
      sex, birthday, nationality,
      total_distance_km, avg_pace_min_per_km, avg_cv, total_runs, cv_run_count, created_at
    ) VALUES (
      v_uid, v_name, v_team, '🏃', 0,
      v_manifestos[1 + (random() * (array_length(v_manifestos,1)-1))::INTEGER],
      v_home_hex, v_home_hex, v_home_hex, v_home_hex, v_district_hex,
      v_sex, ('1985-01-01'::DATE + (random() * 10000)::INTEGER), v_nationality,
      0, NULL, NULL, 0, 0, now()
    );

    -- Generate runs for Feb 21, 22, 23
    v_total_points := 0; v_total_distance := 0; v_total_runs := 0;
    v_avg_pace := 0; v_avg_cv := 0;

    FOR v_d IN 0..2 LOOP
      v_run_date := '2026-02-21'::DATE + v_d;

      IF v_is_hard THEN
        IF random() < 0.15 THEN v_runs_today := 0;
        ELSIF random() < 0.5 THEN v_runs_today := 2;
        ELSE v_runs_today := 1;
        END IF;
      ELSE
        IF random() < 0.45 THEN v_runs_today := 0;
        ELSE v_runs_today := 1;
        END IF;
      END IF;

      FOR v_r IN 1..v_runs_today LOOP
        IF v_is_hard THEN
          v_distance := 3.0 + random() * 9.0;
          v_pace := 4.5 + random() * 2.0;
          v_flip_count := 5 + (random() * 20)::INTEGER;
          v_cv := 0.05 + random() * 0.10;
        ELSE
          v_distance := 1.0 + random() * 2.0;
          v_pace := 7.0 + random() * 3.0;
          v_flip_count := 1 + (random() * 4)::INTEGER;
          v_cv := 0.15 + random() * 0.15;
        END IF;

        v_duration := (v_distance * v_pace * 60)::INTEGER;
        v_start_hour := 6 + (random() * 14)::INTEGER;
        v_start_time := (v_run_date || 'T' || lpad(v_start_hour::TEXT, 2, '0')
                        || ':' || lpad((random()*59)::INTEGER::TEXT, 2, '0')
                        || ':00.000Z')::TIMESTAMPTZ;
        v_end_time := v_start_time + (v_duration || ' seconds')::INTERVAL;

        INSERT INTO public.run_history (
          id, user_id, run_date, start_time, end_time,
          distance_km, duration_seconds, avg_pace_min_per_km,
          flip_count, flip_points, team_at_run, cv, created_at
        ) VALUES (
          gen_random_uuid(), v_uid, v_run_date, v_start_time, v_end_time,
          round(v_distance::NUMERIC, 2), v_duration, round(v_pace::NUMERIC, 2),
          v_flip_count, v_flip_count, v_team, round(v_cv::NUMERIC, 2), v_end_time
        );

        FOR v_h IN 1..v_flip_count LOOP
          v_hex_id := '89' || substring(v_district_hex from 3 for 7)
                   || v_hex_suffixes[1 + ((v_idx * 7 + v_d * 13 + v_h) % 50)];
          INSERT INTO public.hexes (id, last_runner_team, last_flipped_at, parent_hex)
          VALUES (v_hex_id, v_team, v_end_time, v_district_hex)
          ON CONFLICT (id) DO UPDATE SET
            last_runner_team = EXCLUDED.last_runner_team,
            last_flipped_at = GREATEST(hexes.last_flipped_at, EXCLUDED.last_flipped_at);
        END LOOP;

        v_total_points := v_total_points + v_flip_count;
        v_total_distance := v_total_distance + v_distance;
        v_total_runs := v_total_runs + 1;
        v_avg_pace := v_avg_pace + v_pace * v_distance;
        v_avg_cv := v_avg_cv + v_cv;
      END LOOP;
    END LOOP;

    IF v_total_runs > 0 THEN
      UPDATE public.users SET
        season_points = v_total_points,
        total_distance_km = round(v_total_distance::NUMERIC, 2),
        total_runs = v_total_runs,
        avg_pace_min_per_km = round((v_avg_pace / v_total_distance)::NUMERIC, 2),
        avg_cv = round((v_avg_cv / v_total_runs)::NUMERIC, 2),
        cv_run_count = v_total_runs
      WHERE id = v_uid;
    END IF;
  END LOOP;

  -- hex_snapshot
  INSERT INTO public.hex_snapshot (hex_id, last_runner_team, snapshot_date, last_run_end_time, parent_hex)
  SELECT h.id, h.last_runner_team, d.dt, h.last_flipped_at, h.parent_hex
  FROM public.hexes h
  CROSS JOIN (VALUES ('2026-02-21'::DATE), ('2026-02-22'::DATE), ('2026-02-23'::DATE)) AS d(dt);

  -- daily_buff_stats
  INSERT INTO public.daily_buff_stats (
    id, stat_date, city_hex, dominant_team,
    red_hex_count, blue_hex_count, purple_hex_count,
    red_elite_threshold_points,
    purple_total_users, purple_active_users, purple_participation_rate,
    created_at
  )
  SELECT
    gen_random_uuid(), hc.dt, hc.district,
    CASE WHEN hc.r >= hc.b AND hc.r >= hc.p THEN 'red'
         WHEN hc.b >= hc.p THEN 'blue' ELSE 'purple' END,
    hc.r, hc.b, hc.p,
    COALESCE((
      SELECT rh.flip_points FROM public.run_history rh
      JOIN public.users u ON u.id = rh.user_id
      WHERE u.team = 'red' AND u.district_hex = hc.district AND rh.run_date = hc.dt
      ORDER BY rh.flip_points DESC
      OFFSET GREATEST(1, (
        SELECT COUNT(*) FROM public.run_history rh2
        JOIN public.users u2 ON u2.id = rh2.user_id
        WHERE u2.team = 'red' AND u2.district_hex = hc.district AND rh2.run_date = hc.dt
      ) * 20 / 100) LIMIT 1
    ), 0),
    COALESCE((SELECT COUNT(*) FROM public.users u WHERE u.team = 'purple' AND u.district_hex = hc.district), 0),
    COALESCE((
      SELECT COUNT(DISTINCT rh.user_id) FROM public.run_history rh
      JOIN public.users u ON u.id = rh.user_id
      WHERE u.team = 'purple' AND u.district_hex = hc.district AND rh.run_date = hc.dt
    ), 0),
    CASE
      WHEN (SELECT COUNT(*) FROM public.users u WHERE u.team = 'purple' AND u.district_hex = hc.district) = 0 THEN 0.0
      ELSE (
        SELECT COUNT(DISTINCT rh.user_id)::DOUBLE PRECISION FROM public.run_history rh
        JOIN public.users u ON u.id = rh.user_id
        WHERE u.team = 'purple' AND u.district_hex = hc.district AND rh.run_date = hc.dt
      ) / NULLIF((SELECT COUNT(*) FROM public.users u WHERE u.team = 'purple' AND u.district_hex = hc.district), 0)
    END,
    now()
  FROM (
    SELECT h.parent_hex AS district, d.dt,
      SUM(CASE WHEN h.last_runner_team = 'red' THEN 1 ELSE 0 END) AS r,
      SUM(CASE WHEN h.last_runner_team = 'blue' THEN 1 ELSE 0 END) AS b,
      SUM(CASE WHEN h.last_runner_team = 'purple' THEN 1 ELSE 0 END) AS p
    FROM public.hexes h
    CROSS JOIN (VALUES ('2026-02-21'::DATE), ('2026-02-22'::DATE), ('2026-02-23'::DATE)) AS d(dt)
    GROUP BY h.parent_hex, d.dt
  ) hc;

  -- daily_all_range_stats
  INSERT INTO public.daily_all_range_stats (stat_date, dominant_team, red_hex_count, blue_hex_count, purple_hex_count, created_at)
  SELECT d.dt,
    CASE WHEN SUM(CASE WHEN h.last_runner_team = 'red' THEN 1 ELSE 0 END)
              >= SUM(CASE WHEN h.last_runner_team = 'blue' THEN 1 ELSE 0 END)
          AND SUM(CASE WHEN h.last_runner_team = 'red' THEN 1 ELSE 0 END)
              >= SUM(CASE WHEN h.last_runner_team = 'purple' THEN 1 ELSE 0 END)
         THEN 'red'
         WHEN SUM(CASE WHEN h.last_runner_team = 'blue' THEN 1 ELSE 0 END)
              >= SUM(CASE WHEN h.last_runner_team = 'purple' THEN 1 ELSE 0 END)
         THEN 'blue' ELSE 'purple' END,
    SUM(CASE WHEN h.last_runner_team = 'red' THEN 1 ELSE 0 END),
    SUM(CASE WHEN h.last_runner_team = 'blue' THEN 1 ELSE 0 END),
    SUM(CASE WHEN h.last_runner_team = 'purple' THEN 1 ELSE 0 END),
    now()
  FROM public.hexes h
  CROSS JOIN (VALUES ('2026-02-21'::DATE), ('2026-02-22'::DATE), ('2026-02-23'::DATE)) AS d(dt)
  GROUP BY d.dt;

  -- daily_province_range_stats
  INSERT INTO public.daily_province_range_stats (date, leading_team, red_hex_count, blue_hex_count, calculated_at)
  SELECT d.dt,
    CASE WHEN SUM(CASE WHEN h.last_runner_team = 'red' THEN 1 ELSE 0 END)
              >= SUM(CASE WHEN h.last_runner_team = 'blue' THEN 1 ELSE 0 END)
         THEN 'red' ELSE 'blue' END,
    SUM(CASE WHEN h.last_runner_team = 'red' THEN 1 ELSE 0 END),
    SUM(CASE WHEN h.last_runner_team = 'blue' THEN 1 ELSE 0 END),
    now()
  FROM public.hexes h
  CROSS JOIN (VALUES ('2026-02-21'::DATE), ('2026-02-22'::DATE), ('2026-02-23'::DATE)) AS d(dt)
  GROUP BY d.dt;

END $$;
