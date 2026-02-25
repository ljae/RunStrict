-- =============================================================================
-- RESEED: 200 runners with VALID H3 res9 hexes, parent_hex = Res 5 province
-- =============================================================================
-- Season 4: Feb 21-26. Yesterday = Feb 23.
-- All 200 runners in province 85283473fffffff (5 districts)
-- Team: 1-80 red, 81-150 blue, 151-200 purple
-- Type: 1-160 hard, 161-200 lazy
-- parent_hex in hexes = Res 5 province, city_hex in daily_buff_stats = Res 6 district
-- =============================================================================

-- Step 1: Wipe all existing data
DELETE FROM public.run_history;
DELETE FROM public.hex_snapshot;
DELETE FROM public.hexes;
DELETE FROM public.daily_buff_stats;
DELETE FROM public.daily_province_range_stats;
DELETE FROM public.daily_all_range_stats;
DELETE FROM public.season_leaderboard_snapshot;

-- Remove all seed users
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
-- Step 2-7: Create 200 runners, run_history, hexes, stats
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
  v_province_hex TEXT;
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

  v_districts TEXT[] := ARRAY['862834707ffffff', '862834717ffffff', '862834727ffffff', '86283472fffffff', '86283471fffffff'];

  v_children_1 TEXT[] := ARRAY['89283470003ffff','89283470007ffff','8928347000bffff','8928347000fffff','89283470013ffff','89283470017ffff','8928347001bffff','89283470023ffff','89283470027ffff','8928347002bffff','8928347002fffff','89283470033ffff','89283470037ffff','8928347003bffff','89283470043ffff','89283470047ffff','8928347004bffff','8928347004fffff','89283470053ffff','89283470057ffff','8928347005bffff','89283470063ffff','89283470067ffff','8928347006bffff','8928347006fffff','89283470073ffff','89283470077ffff','8928347007bffff','89283470083ffff','89283470087ffff','8928347008bffff','8928347008fffff','89283470093ffff','89283470097ffff','8928347009bffff','892834700a3ffff','892834700a7ffff','892834700abffff','892834700afffff','892834700b3ffff','892834700b7ffff','892834700bbffff','892834700c3ffff','892834700c7ffff','892834700cbffff','892834700cfffff','892834700d3ffff','892834700d7ffff','892834700dbffff','89283470103ffff'];
  v_children_2 TEXT[] := ARRAY['89283471003ffff','89283471007ffff','8928347100bffff','8928347100fffff','89283471013ffff','89283471017ffff','8928347101bffff','89283471023ffff','89283471027ffff','8928347102bffff','8928347102fffff','89283471033ffff','89283471037ffff','8928347103bffff','89283471043ffff','89283471047ffff','8928347104bffff','8928347104fffff','89283471053ffff','89283471057ffff','8928347105bffff','89283471063ffff','89283471067ffff','8928347106bffff','8928347106fffff','89283471073ffff','89283471077ffff','8928347107bffff','89283471083ffff','89283471087ffff','8928347108bffff','8928347108fffff','89283471093ffff','89283471097ffff','8928347109bffff','892834710a3ffff','892834710a7ffff','892834710abffff','892834710afffff','892834710b3ffff','892834710b7ffff','892834710bbffff','892834710c3ffff','892834710c7ffff','892834710cbffff','892834710cfffff','892834710d3ffff','892834710d7ffff','892834710dbffff','89283471103ffff'];
  v_children_3 TEXT[] := ARRAY['89283472003ffff','89283472007ffff','8928347200bffff','8928347200fffff','89283472013ffff','89283472017ffff','8928347201bffff','89283472023ffff','89283472027ffff','8928347202bffff','8928347202fffff','89283472033ffff','89283472037ffff','8928347203bffff','89283472043ffff','89283472047ffff','8928347204bffff','8928347204fffff','89283472053ffff','89283472057ffff','8928347205bffff','89283472063ffff','89283472067ffff','8928347206bffff','8928347206fffff','89283472073ffff','89283472077ffff','8928347207bffff','89283472083ffff','89283472087ffff','8928347208bffff','8928347208fffff','89283472093ffff','89283472097ffff','8928347209bffff','892834720a3ffff','892834720a7ffff','892834720abffff','892834720afffff','892834720b3ffff','892834720b7ffff','892834720bbffff','892834720c3ffff','892834720c7ffff','892834720cbffff','892834720cfffff','892834720d3ffff','892834720d7ffff','892834720dbffff','89283472103ffff'];
  v_children_4 TEXT[] := ARRAY['89283472803ffff','89283472807ffff','8928347280bffff','8928347280fffff','89283472813ffff','89283472817ffff','8928347281bffff','89283472823ffff','89283472827ffff','8928347282bffff','8928347282fffff','89283472833ffff','89283472837ffff','8928347283bffff','89283472843ffff','89283472847ffff','8928347284bffff','8928347284fffff','89283472853ffff','89283472857ffff','8928347285bffff','89283472863ffff','89283472867ffff','8928347286bffff','8928347286fffff','89283472873ffff','89283472877ffff','8928347287bffff','89283472883ffff','89283472887ffff','8928347288bffff','8928347288fffff','89283472893ffff','89283472897ffff','8928347289bffff','892834728a3ffff','892834728a7ffff','892834728abffff','892834728afffff','892834728b3ffff','892834728b7ffff','892834728bbffff','892834728c3ffff','892834728c7ffff','892834728cbffff','892834728cfffff','892834728d3ffff','892834728d7ffff','892834728dbffff','89283472903ffff'];
  v_children_5 TEXT[] := ARRAY['89283471803ffff','89283471807ffff','8928347180bffff','8928347180fffff','89283471813ffff','89283471817ffff','8928347181bffff','89283471823ffff','89283471827ffff','8928347182bffff','8928347182fffff','89283471833ffff','89283471837ffff','8928347183bffff','89283471843ffff','89283471847ffff','8928347184bffff','8928347184fffff','89283471853ffff','89283471857ffff','8928347185bffff','89283471863ffff','89283471867ffff','8928347186bffff','8928347186fffff','89283471873ffff','89283471877ffff','8928347187bffff','89283471883ffff','89283471887ffff','8928347188bffff','8928347188fffff','89283471893ffff','89283471897ffff','8928347189bffff','892834718a3ffff','892834718a7ffff','892834718abffff','892834718afffff','892834718b3ffff','892834718b7ffff','892834718bbffff','892834718c3ffff','892834718c7ffff','892834718cbffff','892834718cfffff','892834718d3ffff','892834718d7ffff','892834718dbffff','89283471903ffff'];

  v_province_const TEXT := '85283473fffffff';

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

  v_children TEXT[];
  v_district_idx INTEGER;
  v_d INTEGER;
  v_r INTEGER;
  v_h INTEGER;
  v_hex_id TEXT;
BEGIN
  PERFORM setseed(0.42);

  FOR v_idx IN 1..200 LOOP
    v_hex_idx := lpad(to_hex(v_idx), 4, '0');
    v_uid := ('dddddddd-' || v_hex_idx || '-4000-a000-00000000' || v_hex_idx)::UUID;
    v_email := 'runner' || (200 + v_idx) || '@seed.local';

    v_name := v_first_names[1 + (random() * (array_length(v_first_names,1)-1))::INTEGER]
           || v_last_names[1 + (random() * (array_length(v_last_names,1)-1))::INTEGER];

    -- Team: 1-80 red, 81-150 blue, 151-200 purple
    IF v_idx <= 80 THEN v_team := 'red';
    ELSIF v_idx <= 150 THEN v_team := 'blue';
    ELSE v_team := 'purple';
    END IF;

    v_is_hard := (v_idx <= 160);

    -- All 200 runners distributed across 5 districts in province 85283473fffffff
    v_district_idx := 1 + ((v_idx - 1) % 5);
    v_district_hex := v_districts[v_district_idx];
    v_province_hex := v_province_const;

    -- Pick valid res9 children array for this district
    IF v_district_idx = 1 THEN v_children := v_children_1;
    ELSIF v_district_idx = 2 THEN v_children := v_children_2;
    ELSIF v_district_idx = 3 THEN v_children := v_children_3;
    ELSIF v_district_idx = 4 THEN v_children := v_children_4;
    ELSE v_children := v_children_5;
    END IF;

    -- Home hex = one of the 50 valid res9 children
    v_home_hex := v_children[1 + ((v_idx - 1) % 50)];

    v_sex := v_sexes[1 + (random() * 2)::INTEGER];
    v_nationality := v_nationalities[1 + (random() * (array_length(v_nationalities,1)-1))::INTEGER];

    -- Insert auth.users
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

    -- Insert public.users
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

        -- Insert hexes with VALID res9 IDs, parent_hex = Res 5 PROVINCE
        FOR v_h IN 1..v_flip_count LOOP
          v_hex_id := v_children[1 + ((v_idx * 7 + v_d * 13 + v_h) % 50)];
          INSERT INTO public.hexes (id, last_runner_team, last_flipped_at, parent_hex)
          VALUES (v_hex_id, v_team, v_end_time, v_province_hex)
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

  -- hex_snapshot (parent_hex = province)
  INSERT INTO public.hex_snapshot (hex_id, last_runner_team, snapshot_date, last_run_end_time, parent_hex)
  SELECT h.id, h.last_runner_team, d.dt, h.last_flipped_at, h.parent_hex
  FROM public.hexes h
  CROSS JOIN (VALUES ('2026-02-21'::DATE), ('2026-02-22'::DATE), ('2026-02-23'::DATE)) AS d(dt);

  -- daily_buff_stats (city_hex = Res 6 district, NOT province)
  -- We aggregate by user district_hex since hexes.parent_hex is now province
  INSERT INTO public.daily_buff_stats (
    id, stat_date, city_hex, dominant_team,
    red_hex_count, blue_hex_count, purple_hex_count,
    red_elite_threshold_points,
    purple_total_users, purple_active_users, purple_participation_rate,
    created_at
  )
  SELECT
    gen_random_uuid(), dc.dt, dc.district,
    CASE WHEN dc.r >= dc.b AND dc.r >= dc.p THEN 'red'
         WHEN dc.b >= dc.p THEN 'blue' ELSE 'purple' END,
    dc.r, dc.b, dc.p,
    COALESCE((
      SELECT rh.flip_points FROM public.run_history rh
      JOIN public.users u ON u.id = rh.user_id
      WHERE u.team = 'red' AND u.district_hex = dc.district AND rh.run_date = dc.dt
      ORDER BY rh.flip_points DESC
      OFFSET GREATEST(1, (
        SELECT COUNT(*) FROM public.run_history rh2
        JOIN public.users u2 ON u2.id = rh2.user_id
        WHERE u2.team = 'red' AND u2.district_hex = dc.district AND rh2.run_date = dc.dt
      ) * 20 / 100) LIMIT 1
    ), 0),
    COALESCE((SELECT COUNT(*) FROM public.users u WHERE u.team = 'purple' AND u.district_hex = dc.district), 0),
    COALESCE((
      SELECT COUNT(DISTINCT rh.user_id) FROM public.run_history rh
      JOIN public.users u ON u.id = rh.user_id
      WHERE u.team = 'purple' AND u.district_hex = dc.district AND rh.run_date = dc.dt
    ), 0),
    CASE
      WHEN (SELECT COUNT(*) FROM public.users u WHERE u.team = 'purple' AND u.district_hex = dc.district) = 0 THEN 0.0
      ELSE (
        SELECT COUNT(DISTINCT rh.user_id)::DOUBLE PRECISION FROM public.run_history rh
        JOIN public.users u ON u.id = rh.user_id
        WHERE u.team = 'purple' AND u.district_hex = dc.district AND rh.run_date = dc.dt
      ) / NULLIF((SELECT COUNT(*) FROM public.users u WHERE u.team = 'purple' AND u.district_hex = dc.district), 0)
    END,
    now()
  FROM (
    -- Count hex flips per district per day by joining runs with user district
    SELECT u.district_hex AS district, d.dt,
      SUM(CASE WHEN rh.team_at_run = 'red' THEN rh.flip_count ELSE 0 END) AS r,
      SUM(CASE WHEN rh.team_at_run = 'blue' THEN rh.flip_count ELSE 0 END) AS b,
      SUM(CASE WHEN rh.team_at_run = 'purple' THEN rh.flip_count ELSE 0 END) AS p
    FROM public.run_history rh
    JOIN public.users u ON u.id = rh.user_id
    CROSS JOIN (VALUES ('2026-02-21'::DATE), ('2026-02-22'::DATE), ('2026-02-23'::DATE)) AS d(dt)
    WHERE rh.run_date = d.dt
    GROUP BY u.district_hex, d.dt
  ) dc;

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

-- =============================================================================
-- Fix get_user_buff: district win fallback no longer queries hexes.parent_hex
-- Since parent_hex is now Res 5 (province), the old fallback
-- WHERE parent_hex = v_district_hex no longer works.
-- Safe default: no district win when daily_buff_stats is empty.
-- The primary path (daily_buff_stats) still uses city_hex = Res 6 district.
-- =============================================================================

-- Must drop old 2-param overload first to avoid ambiguity
DROP FUNCTION IF EXISTS public.get_user_buff(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.get_user_buff(
  p_user_id UUID,
  p_district_hex TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_user RECORD;
  v_district_hex TEXT;
  v_buff_stats RECORD;
  v_province_stats RECORD;
  v_is_elite BOOLEAN := false;
  v_district_win BOOLEAN := false;
  v_province_win BOOLEAN := false;
  v_multiplier INTEGER := 1;
  v_base_buff INTEGER := 1;
  v_district_bonus INTEGER := 0;
  v_province_bonus INTEGER := 0;
  v_reason TEXT := 'Default';
  v_yesterday DATE;
  v_red_runner_count INTEGER;
  v_elite_cutoff_rank INTEGER;
  v_elite_threshold INTEGER := 0;
  v_user_yesterday_points INTEGER := 0;

  -- Config values
  v_cfg jsonb;
  v_red_elite_threshold NUMERIC;
  v_red_elite_base INTEGER;
  v_red_common_base INTEGER;
  v_elite_district_win_bonus INTEGER;
  v_elite_province_win_bonus INTEGER;
  v_common_district_win_bonus INTEGER;
  v_common_province_win_bonus INTEGER;
  v_blue_union_base INTEGER;
  v_blue_district_win_bonus INTEGER;
  v_blue_province_win_bonus INTEGER;
  v_purple_high_tier_threshold NUMERIC;
  v_purple_mid_tier_threshold NUMERIC;
  v_purple_high_tier_buff INTEGER;
  v_purple_mid_tier_buff INTEGER;
  v_purple_low_tier_buff INTEGER;
BEGIN
  -- Load buff config
  SELECT config_data->'buff' INTO v_cfg FROM public.app_config LIMIT 1;

  v_red_elite_threshold     := COALESCE((v_cfg->>'redEliteThreshold')::NUMERIC, 0.20);
  v_red_elite_base          := COALESCE((v_cfg->>'redEliteBase')::INTEGER, 2);
  v_red_common_base         := COALESCE((v_cfg->>'redCommonBase')::INTEGER, 1);
  v_elite_district_win_bonus := COALESCE((v_cfg->>'eliteDistrictWinBonus')::INTEGER, 1);
  v_elite_province_win_bonus := COALESCE((v_cfg->>'eliteProvinceWinBonus')::INTEGER, 1);
  v_common_district_win_bonus := COALESCE((v_cfg->>'commonDistrictWinBonus')::INTEGER, 0);
  v_common_province_win_bonus := COALESCE((v_cfg->>'commonProvinceWinBonus')::INTEGER, 1);
  v_blue_union_base         := COALESCE((v_cfg->>'blueUnionBase')::INTEGER, 1);
  v_blue_district_win_bonus := COALESCE((v_cfg->>'blueDistrictWinBonus')::INTEGER, 1);
  v_blue_province_win_bonus := COALESCE((v_cfg->>'blueProvinceWinBonus')::INTEGER, 1);
  v_purple_high_tier_threshold := COALESCE((v_cfg->>'purpleHighTierThreshold')::NUMERIC, 0.60);
  v_purple_mid_tier_threshold  := COALESCE((v_cfg->>'purpleMidTierThreshold')::NUMERIC, 0.30);
  v_purple_high_tier_buff   := COALESCE((v_cfg->>'purpleHighTierBuff')::INTEGER, 3);
  v_purple_mid_tier_buff    := COALESCE((v_cfg->>'purpleMidTierBuff')::INTEGER, 2);
  v_purple_low_tier_buff    := COALESCE((v_cfg->>'purpleLowTierBuff')::INTEGER, 1);

  -- Get user info
  SELECT team, district_hex INTO v_user FROM public.users WHERE id = p_user_id;
  v_district_hex := COALESCE(v_user.district_hex, p_district_hex);

  IF v_user IS NULL OR v_district_hex IS NULL THEN
    RETURN jsonb_build_object(
      'multiplier', 1, 'base_buff', 1,
      'all_range_bonus', 0, 'district_bonus', 0, 'province_bonus', 0,
      'reason', 'Default', 'team', COALESCE(v_user.team, ''),
      'district_hex', NULL, 'is_elite', false,
      'has_district_win', false, 'has_province_win', false,
      'elite_threshold', 0, 'yesterday_points', 0
    );
  END IF;

  v_yesterday := (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE - INTERVAL '1 day';

  -- District win: from daily_buff_stats (precomputed) or safe default
  BEGIN
    SELECT * INTO v_buff_stats
    FROM public.daily_buff_stats
    WHERE city_hex = v_district_hex AND stat_date = CURRENT_DATE
    LIMIT 1;
  EXCEPTION WHEN undefined_column THEN
    v_buff_stats := NULL;
  END;

  IF v_buff_stats IS NOT NULL THEN
    v_district_win := (v_buff_stats.dominant_team = v_user.team);
  ELSE
    -- CHANGED: No longer queries hexes.parent_hex (now Res 5, not district)
    -- Safe default when no precomputed buff stats exist
    v_district_win := false;
  END IF;

  -- Province win
  BEGIN
    SELECT * INTO v_province_stats
    FROM public.daily_province_range_stats WHERE date = CURRENT_DATE;
  EXCEPTION WHEN undefined_table THEN
    v_province_stats := NULL;
  END;

  IF v_province_stats IS NOT NULL THEN
    v_province_win := (v_province_stats.leading_team = v_user.team);
  ELSE
    v_province_win := false;
  END IF;

  -- Team-specific buff calculation (config-driven)
  IF v_user.team = 'red' THEN
    v_is_elite := false;

    SELECT COUNT(DISTINCT rh.user_id) INTO v_red_runner_count
    FROM public.run_history rh
    JOIN public.users u ON u.id = rh.user_id
    WHERE u.team = 'red'
      AND (v_district_hex IS NULL OR u.district_hex = v_district_hex)
      AND rh.run_date = v_yesterday;

    IF v_red_runner_count > 0 THEN
      v_elite_cutoff_rank := GREATEST(1, (v_red_runner_count * v_red_elite_threshold)::INTEGER);

      SELECT COALESCE(sub.total_points, 0) INTO v_elite_threshold
      FROM (
        SELECT rh.user_id, SUM(rh.flip_points) AS total_points,
          ROW_NUMBER() OVER (ORDER BY SUM(rh.flip_points) DESC) AS rn
        FROM public.run_history rh
        JOIN public.users u ON u.id = rh.user_id
        WHERE u.team = 'red'
          AND (v_district_hex IS NULL OR u.district_hex = v_district_hex)
          AND rh.run_date = v_yesterday
        GROUP BY rh.user_id
      ) sub WHERE sub.rn = v_elite_cutoff_rank;

      v_elite_threshold := COALESCE(v_elite_threshold, 0);

      SELECT COALESCE(SUM(rh.flip_points), 0) INTO v_user_yesterday_points
      FROM public.run_history rh
      WHERE rh.user_id = p_user_id AND rh.run_date = v_yesterday;

      v_is_elite := (v_user_yesterday_points >= v_elite_threshold AND v_user_yesterday_points > 0);
    END IF;

    v_base_buff := CASE WHEN v_is_elite THEN v_red_elite_base ELSE v_red_common_base END;
    v_district_bonus := CASE
      WHEN v_is_elite AND v_district_win THEN v_elite_district_win_bonus
      WHEN NOT v_is_elite AND v_district_win THEN v_common_district_win_bonus
      ELSE 0 END;
    v_province_bonus := CASE
      WHEN v_is_elite AND v_province_win THEN v_elite_province_win_bonus
      WHEN NOT v_is_elite AND v_province_win THEN v_common_province_win_bonus
      ELSE 0 END;
    v_multiplier := v_base_buff + v_district_bonus + v_province_bonus;
    v_reason := CASE WHEN v_is_elite THEN 'Elite' ELSE 'Common' END;

  ELSIF v_user.team = 'blue' THEN
    v_base_buff := v_blue_union_base;
    v_district_bonus := CASE WHEN v_district_win THEN v_blue_district_win_bonus ELSE 0 END;
    v_province_bonus := CASE WHEN v_province_win THEN v_blue_province_win_bonus ELSE 0 END;
    v_multiplier := v_base_buff + v_district_bonus + v_province_bonus;
    v_reason := 'Union';

  ELSIF v_user.team = 'purple' THEN
    IF v_buff_stats IS NOT NULL AND v_buff_stats.purple_participation_rate IS NOT NULL THEN
      IF v_buff_stats.purple_participation_rate >= v_purple_high_tier_threshold THEN
        v_base_buff := v_purple_high_tier_buff;
      ELSIF v_buff_stats.purple_participation_rate >= v_purple_mid_tier_threshold THEN
        v_base_buff := v_purple_mid_tier_buff;
      ELSE
        v_base_buff := v_purple_low_tier_buff;
      END IF;
    ELSE
      v_base_buff := v_purple_low_tier_buff;
    END IF;
    v_multiplier := v_base_buff;
    v_reason := 'Participation';
  END IF;

  RETURN jsonb_build_object(
    'multiplier', v_multiplier, 'base_buff', v_base_buff,
    'all_range_bonus', v_province_bonus,
    'district_bonus', v_district_bonus, 'province_bonus', v_province_bonus,
    'reason', v_reason, 'team', v_user.team, 'district_hex', v_district_hex,
    'is_elite', v_is_elite, 'has_district_win', v_district_win,
    'has_province_win', v_province_win,
    'elite_threshold', COALESCE(v_elite_threshold, 0),
    'yesterday_points', COALESCE(v_user_yesterday_points, 0)
  );
END;
$function$;

-- =============================================================================
-- Fix get_hex_dominance: rename p_city_hex -> p_parent_hex, works with Res 5
-- =============================================================================
DROP FUNCTION IF EXISTS public.get_hex_dominance(TEXT);

CREATE OR REPLACE FUNCTION public.get_hex_dominance(
  p_parent_hex TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql STABLE
AS $$
  SELECT jsonb_build_object(
    'red_hexes', COUNT(CASE WHEN last_runner_team = 'red' THEN 1 END),
    'blue_hexes', COUNT(CASE WHEN last_runner_team = 'blue' THEN 1 END),
    'purple_hexes', COUNT(CASE WHEN last_runner_team = 'purple' THEN 1 END),
    'total_hexes', COUNT(*)
  )
  FROM public.hexes
  WHERE p_parent_hex IS NULL OR parent_hex = p_parent_hex;
$$;

