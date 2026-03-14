-- ============================================================================
-- FIX: Scope "Province Win" to the user's local H3 Res-5 province
-- ============================================================================
-- Root cause: daily_province_range_stats stored ONE row per day (server-wide).
--   get_user_buff() checked if the global winner matched the user's team.
--   This meant one team "wins province" for ALL users globally — even if they
--   dominate their local area and lose server-wide.
--
-- Fix:
--   1. users.province_hex (Res-5) — stored per user, derived from hex path
--   2. daily_province_range_stats — keyed by (stat_date, province_hex), one
--      row per Res-5 province per day (matches get_hex_dominance scope)
--   3. calculate_daily_buffs() — loops per distinct Res-5 parent_hex in hexes
--   4. get_user_buff() — province win = lookup by users.province_hex (local)
--   5. finalize_run() — sets users.province_hex from p_hex_parents[1]
--
-- After this migration "Province Win" in the buff system matches exactly what
-- the Territory section in TeamScreen shows (local H3 Res-5 area).
-- ============================================================================


-- ============================================================================
-- STEP 1: Add province_hex column to users table
-- ============================================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS province_hex TEXT;

-- Backfill: derive from hexes.parent_hex via home_hex join.
-- hexes.parent_hex = Res-5 (province), users.home_hex = first hex ever run.
UPDATE public.users u
SET province_hex = h.parent_hex
FROM public.hexes h
WHERE (u.home_hex = h.id OR u.season_home_hex = h.id)
  AND u.province_hex IS NULL
  AND h.parent_hex IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_province_hex
  ON public.users (province_hex)
  WHERE province_hex IS NOT NULL;


-- ============================================================================
-- STEP 2: Rebuild daily_province_range_stats with composite PK
--   Old schema: date DATE PRIMARY KEY  (server-wide, one row per day)
--   New schema: (stat_date DATE, province_hex TEXT)  (local, one row per province per day)
-- ============================================================================

-- Drop and recreate; data is recomputed at midnight by calculate_daily_buffs()
DROP TABLE IF EXISTS public.daily_province_range_stats;

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


-- ============================================================================
-- STEP 3: Update finalize_run to store province_hex on users
--   Source: p_hex_parents[1] (first hex's Res-5 province parent)
--   No new client parameter needed — p_hex_parents already carries this data.
-- ============================================================================

DROP FUNCTION IF EXISTS public.finalize_run(
  UUID, TIMESTAMPTZ, TIMESTAMPTZ, DOUBLE PRECISION, INTEGER,
  TEXT[], INTEGER, DOUBLE PRECISION, INTEGER, INTEGER, TEXT[], TEXT, TEXT[]
);

CREATE OR REPLACE FUNCTION public.finalize_run(
  p_user_id               UUID,
  p_start_time            TIMESTAMPTZ,
  p_end_time              TIMESTAMPTZ,
  p_distance_km           DOUBLE PRECISION,
  p_duration_seconds      INTEGER,
  p_hex_path              TEXT[],
  p_buff_multiplier       INTEGER    DEFAULT 1,
  p_cv                    DOUBLE PRECISION DEFAULT NULL,
  p_client_points         INTEGER    DEFAULT 0,
  p_home_region_flips     INTEGER    DEFAULT 0,
  p_hex_parents           TEXT[]     DEFAULT NULL,  -- Res-5 province parent per hex
  p_district_hex          TEXT       DEFAULT NULL,  -- User's Res-6 district
  p_hex_district_parents  TEXT[]     DEFAULT NULL   -- Res-6 district parent per hex
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_team                TEXT;
  v_hex_id              TEXT;
  v_points              INTEGER;
  v_max_allowed_points  INTEGER;
  v_flip_count          INTEGER;
  v_current_flipped_at  TIMESTAMPTZ;
  v_parent_hex          TEXT;
  v_district_parent_hex TEXT;
  v_province_hex        TEXT;  -- Res-5, derived from p_hex_parents[1]
  v_idx                 INTEGER;
  v_run_history_id      UUID;
  v_server_buff         JSONB;
  v_validated_multiplier INTEGER;
BEGIN
  -- Get user's team
  SELECT team INTO v_team FROM public.users WHERE id = p_user_id;

  IF v_team IS NULL THEN
    RAISE EXCEPTION 'User not found or has no team assigned';
  END IF;

  -- Derive province_hex (Res-5) from first hex's parent (all hexes in one run
  -- share the same province parent when running within home province)
  IF p_hex_parents IS NOT NULL AND array_length(p_hex_parents, 1) > 0 THEN
    v_province_hex := p_hex_parents[1];
  END IF;

  -- Pre-populate users.province_hex BEFORE calling get_user_buff() so that
  -- province win is evaluated correctly even on a user's very first run.
  IF v_province_hex IS NOT NULL THEN
    UPDATE public.users
    SET province_hex = v_province_hex
    WHERE id = p_user_id AND province_hex IS NULL;
  END IF;

  -- Server-side buff validation: client cannot claim higher than server allows
  v_server_buff := public.get_user_buff(p_user_id, p_district_hex);
  v_validated_multiplier := GREATEST((v_server_buff->>'multiplier')::INTEGER, 1);

  -- Use lower of client and server multiplier (anti-cheat)
  IF p_buff_multiplier < v_validated_multiplier THEN
    v_validated_multiplier := p_buff_multiplier;
  END IF;

  -- [SECURITY] Cap validation: client points ≤ hex_path_length × validated_multiplier
  v_max_allowed_points := COALESCE(array_length(p_hex_path, 1), 0) * v_validated_multiplier;
  v_points := LEAST(COALESCE(p_client_points, 0), v_max_allowed_points);
  v_flip_count := CASE
    WHEN v_validated_multiplier > 0 THEN v_points / v_validated_multiplier
    ELSE 0
  END;

  IF p_client_points > v_max_allowed_points THEN
    RAISE WARNING 'Client claimed % points but max allowed is %. Capped.',
      p_client_points, v_max_allowed_points;
  END IF;

  -- Update live hexes table (for buff/dominance calculations only)
  -- hex_snapshot is immutable until midnight build
  IF p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0 THEN
    v_idx := 1;
    FOREACH v_hex_id IN ARRAY p_hex_path LOOP
      v_parent_hex := NULL;
      v_district_parent_hex := NULL;

      IF p_hex_parents IS NOT NULL AND v_idx <= array_length(p_hex_parents, 1) THEN
        v_parent_hex := p_hex_parents[v_idx];
      END IF;

      IF p_hex_district_parents IS NOT NULL AND v_idx <= array_length(p_hex_district_parents, 1) THEN
        v_district_parent_hex := p_hex_district_parents[v_idx];
      END IF;

      SELECT last_flipped_at INTO v_current_flipped_at
      FROM public.hexes WHERE id = v_hex_id;

      IF v_current_flipped_at IS NULL OR p_end_time > v_current_flipped_at THEN
        INSERT INTO public.hexes (id, last_runner_team, last_flipped_at, parent_hex, district_hex)
        VALUES (v_hex_id, v_team, p_end_time, v_parent_hex, v_district_parent_hex)
        ON CONFLICT (id) DO UPDATE
        SET last_runner_team = v_team,
            last_flipped_at  = p_end_time,
            parent_hex       = COALESCE(EXCLUDED.parent_hex,    public.hexes.parent_hex),
            district_hex     = COALESCE(EXCLUDED.district_hex,  public.hexes.district_hex)
        WHERE public.hexes.last_flipped_at IS NULL
           OR public.hexes.last_flipped_at < p_end_time;
      END IF;

      v_idx := v_idx + 1;
    END LOOP;
  END IF;

  -- Update user stats (season_points, distance, pace, cv, home hexes, district, province)
  UPDATE public.users SET
    season_points       = season_points + v_points,
    home_hex            = CASE
                            WHEN home_hex IS NULL
                              AND p_hex_path IS NOT NULL
                              AND array_length(p_hex_path, 1) > 0
                            THEN p_hex_path[1]
                            ELSE home_hex
                          END,
    home_hex_end        = CASE
                            WHEN p_hex_path IS NOT NULL
                              AND array_length(p_hex_path, 1) > 0
                            THEN p_hex_path[array_length(p_hex_path, 1)]
                            ELSE home_hex_end
                          END,
    season_home_hex     = CASE
                            WHEN season_home_hex IS NULL
                              AND p_hex_path IS NOT NULL
                              AND array_length(p_hex_path, 1) > 0
                            THEN p_hex_path[1]
                            ELSE season_home_hex
                          END,
    district_hex        = COALESCE(p_district_hex, district_hex),
    province_hex        = COALESCE(v_province_hex, province_hex),  -- NEW: Res-5
    total_distance_km   = total_distance_km + p_distance_km,
    total_runs          = total_runs + 1,
    avg_pace_min_per_km = CASE
                            WHEN p_distance_km > 0 THEN
                              (COALESCE(avg_pace_min_per_km, 0) * total_runs
                               + (p_duration_seconds / 60.0) / p_distance_km)
                              / (total_runs + 1)
                            ELSE avg_pace_min_per_km
                          END,
    avg_cv              = CASE
                            WHEN p_cv IS NOT NULL THEN
                              (COALESCE(avg_cv, 0) * cv_run_count + p_cv)
                              / (cv_run_count + 1)
                            ELSE avg_cv
                          END,
    cv_run_count        = CASE
                            WHEN p_cv IS NOT NULL THEN cv_run_count + 1
                            ELSE cv_run_count
                          END
  WHERE id = p_user_id;

  -- Insert run history (preserved across seasons)
  INSERT INTO public.run_history (
    user_id, run_date, start_time, end_time,
    distance_km, duration_seconds, avg_pace_min_per_km,
    flip_count, flip_points, team_at_run, cv
  ) VALUES (
    p_user_id,
    (p_end_time AT TIME ZONE 'Etc/GMT-2')::DATE,
    p_start_time, p_end_time,
    p_distance_km, p_duration_seconds,
    CASE WHEN p_distance_km > 0
      THEN (p_duration_seconds / 60.0) / p_distance_km
      ELSE NULL
    END,
    v_flip_count, v_points, v_team, p_cv
  )
  RETURNING id INTO v_run_history_id;

  RETURN jsonb_build_object(
    'run_id',               v_run_history_id,
    'flips',                v_flip_count,
    'hex_count',            COALESCE(array_length(p_hex_path, 1), 0),
    'multiplier',           v_validated_multiplier,
    'points_earned',        v_points,
    'server_validated',     TRUE,
    'total_season_points',  (SELECT season_points FROM public.users WHERE id = p_user_id)
  );
END;
$$;


-- ============================================================================
-- STEP 4: Rewrite calculate_daily_buffs — per-province dominance
-- ============================================================================

CREATE OR REPLACE FUNCTION public.calculate_daily_buffs()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_today_gmt2         DATE;
  v_yesterday          DATE;
  v_district_hex       TEXT;
  v_province_hex       TEXT;
  v_hex_counts         RECORD;
  v_dominant           TEXT;
  v_elite_threshold    INTEGER;
  v_purple_total       INTEGER;
  v_purple_active      INTEGER;
  -- Province-wide totals (for daily_all_range_stats analytics only)
  v_all_red            INTEGER := 0;
  v_all_blue           INTEGER := 0;
  v_all_purple         INTEGER := 0;
  v_districts_processed  INTEGER := 0;
  v_provinces_processed  INTEGER := 0;
BEGIN
  -- Consistent GMT+2 date (must match get_user_buff and get_team_rankings)
  v_today_gmt2 := (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE;
  v_yesterday  := v_today_gmt2 - INTERVAL '1 day';

  -- Delete existing stats for today (idempotent re-run)
  DELETE FROM public.daily_buff_stats         WHERE stat_date = v_today_gmt2;
  DELETE FROM public.daily_province_range_stats WHERE stat_date = v_today_gmt2;
  DELETE FROM public.daily_all_range_stats    WHERE stat_date = v_today_gmt2;

  -- ── Step 1: Per-province (Res-5) dominance ─────────────────────────────────
  -- Loop over each distinct Res-5 province that has colored hexes.
  -- This matches exactly what get_hex_dominance(p_parent_hex) shows in TeamScreen.
  FOR v_province_hex IN
    SELECT DISTINCT h.parent_hex
    FROM public.hexes h
    WHERE h.parent_hex IS NOT NULL
      AND h.last_runner_team IS NOT NULL
  LOOP
    SELECT
      COALESCE(SUM(CASE WHEN h.last_runner_team = 'red'    THEN 1 ELSE 0 END), 0) AS red_count,
      COALESCE(SUM(CASE WHEN h.last_runner_team = 'blue'   THEN 1 ELSE 0 END), 0) AS blue_count,
      COALESCE(SUM(CASE WHEN h.last_runner_team = 'purple' THEN 1 ELSE 0 END), 0) AS purple_count
    INTO v_hex_counts
    FROM public.hexes h
    WHERE h.parent_hex = v_province_hex         -- Res-5 filter: correct!
      AND h.last_runner_team IS NOT NULL;

    v_dominant := CASE
      WHEN v_hex_counts.red_count >= v_hex_counts.blue_count
        AND v_hex_counts.red_count >= v_hex_counts.purple_count THEN 'red'
      WHEN v_hex_counts.blue_count >= v_hex_counts.red_count
        AND v_hex_counts.blue_count >= v_hex_counts.purple_count THEN 'blue'
      ELSE 'purple'
    END;

    INSERT INTO public.daily_province_range_stats (
      stat_date, province_hex, leading_team,
      red_hex_count, blue_hex_count, purple_hex_count
    ) VALUES (
      v_today_gmt2, v_province_hex, v_dominant,
      v_hex_counts.red_count, v_hex_counts.blue_count, v_hex_counts.purple_count
    );

    -- Accumulate totals for server-wide analytics
    v_all_red    := v_all_red    + v_hex_counts.red_count;
    v_all_blue   := v_all_blue   + v_hex_counts.blue_count;
    v_all_purple := v_all_purple + v_hex_counts.purple_count;

    v_provinces_processed := v_provinces_processed + 1;
  END LOOP;

  -- ── Server-wide totals (analytics only, NOT used for buff) ─────────────────
  v_dominant := CASE
    WHEN v_all_red >= v_all_blue AND v_all_red >= v_all_purple THEN 'red'
    WHEN v_all_blue >= v_all_red AND v_all_blue >= v_all_purple THEN 'blue'
    ELSE 'purple'
  END;

  INSERT INTO public.daily_all_range_stats (
    stat_date, dominant_team, red_hex_count, blue_hex_count, purple_hex_count
  ) VALUES (
    v_today_gmt2, v_dominant, v_all_red, v_all_blue, v_all_purple
  );

  -- ── Step 2: Per-district (Res-6) buff stats ─────────────────────────────────
  -- Uses district_hex column on hexes (added in 20260306000001).
  FOR v_district_hex IN
    SELECT DISTINCT u.district_hex
    FROM public.users u
    WHERE u.team IS NOT NULL
      AND u.district_hex IS NOT NULL
  LOOP
    -- FIX: Query hexes by district_hex (Res-6) column — correct Res-6 filter
    SELECT
      COALESCE(SUM(CASE WHEN h.last_runner_team = 'red'    THEN 1 ELSE 0 END), 0) AS red_count,
      COALESCE(SUM(CASE WHEN h.last_runner_team = 'blue'   THEN 1 ELSE 0 END), 0) AS blue_count,
      COALESCE(SUM(CASE WHEN h.last_runner_team = 'purple' THEN 1 ELSE 0 END), 0) AS purple_count
    INTO v_hex_counts
    FROM public.hexes h
    WHERE h.last_runner_team IS NOT NULL
      AND h.district_hex = v_district_hex;

    v_dominant := CASE
      WHEN v_hex_counts.red_count >= v_hex_counts.blue_count
        AND v_hex_counts.red_count >= v_hex_counts.purple_count THEN 'red'
      WHEN v_hex_counts.blue_count >= v_hex_counts.red_count
        AND v_hex_counts.blue_count >= v_hex_counts.purple_count THEN 'blue'
      ELSE 'purple'
    END;

    -- RED Elite threshold: top 20% flip_points from yesterday in this district
    SELECT COALESCE(
      PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY sub.total_points),
      0
    )::INTEGER
    INTO v_elite_threshold
    FROM (
      SELECT SUM(rh.flip_points) AS total_points
      FROM public.run_history rh
      JOIN public.users u ON rh.user_id = u.id
      WHERE rh.run_date = v_yesterday
        AND u.team = 'red'
        AND u.district_hex = v_district_hex
      GROUP BY rh.user_id
    ) sub;

    -- PURPLE participation rate in this district
    SELECT COUNT(*) INTO v_purple_total
    FROM public.users u
    WHERE u.team = 'purple'
      AND u.district_hex = v_district_hex;

    SELECT COUNT(DISTINCT rh.user_id) INTO v_purple_active
    FROM public.run_history rh
    JOIN public.users u ON rh.user_id = u.id
    WHERE rh.run_date = v_yesterday
      AND u.team = 'purple'
      AND u.district_hex = v_district_hex;

    INSERT INTO public.daily_buff_stats (
      stat_date, district_hex, dominant_team,
      red_hex_count, blue_hex_count, purple_hex_count,
      red_elite_threshold_points,
      purple_total_users, purple_active_users, purple_participation_rate
    ) VALUES (
      v_today_gmt2, v_district_hex, v_dominant,
      v_hex_counts.red_count, v_hex_counts.blue_count, v_hex_counts.purple_count,
      v_elite_threshold,
      v_purple_total, v_purple_active,
      CASE WHEN v_purple_total > 0
        THEN v_purple_active::DOUBLE PRECISION / v_purple_total
        ELSE 0
      END
    );

    v_districts_processed := v_districts_processed + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'stat_date',            v_today_gmt2,
    'provinces_processed',  v_provinces_processed,
    'districts_processed',  v_districts_processed,
    'all_range_dominant',   v_dominant
  );
END;
$$;


-- ============================================================================
-- STEP 5: Rewrite get_user_buff — province win scoped to users.province_hex
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_user_buff(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.get_user_buff(
  p_user_id       UUID,
  p_district_hex  TEXT DEFAULT NULL  -- client fallback if users.district_hex is NULL
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_user                  RECORD;
  v_district_hex          TEXT;
  v_province_hex          TEXT;   -- Res-5: user's home province
  v_buff_stats            RECORD;
  v_is_elite              BOOLEAN := false;
  v_district_win          BOOLEAN := false;
  v_province_win          BOOLEAN := false;
  v_multiplier            INTEGER := 1;
  v_base_buff             INTEGER := 1;
  v_district_bonus        INTEGER := 0;
  v_province_bonus        INTEGER := 0;
  v_reason                TEXT    := 'Default';
  v_today_gmt2            DATE;
  v_yesterday             DATE;
  v_red_runner_count      INTEGER;
  v_elite_cutoff_rank     INTEGER;
  v_elite_threshold       INTEGER := 0;
  v_user_yesterday_points INTEGER := 0;
  v_province_leading_team TEXT;
BEGIN
  -- Consistent GMT+2 dates (must match calculate_daily_buffs and get_team_rankings)
  v_today_gmt2 := (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE;
  v_yesterday  := v_today_gmt2 - INTERVAL '1 day';

  -- ── Get user info ─────────────────────────────────────────────────────────
  SELECT team, district_hex, province_hex INTO v_user
  FROM public.users WHERE id = p_user_id;

  -- Apply client-provided fallbacks for district (province has no client fallback)
  v_district_hex := COALESCE(v_user.district_hex, p_district_hex);
  v_province_hex := v_user.province_hex;  -- NULL until first run; province win = false

  IF v_user IS NULL OR v_district_hex IS NULL THEN
    RETURN jsonb_build_object(
      'multiplier',       1,
      'base_buff',        1,
      'province_range_bonus', 0,
      'district_bonus',   0,
      'province_bonus',   0,
      'reason',           'Default',
      'team',             COALESCE(v_user.team, ''),
      'district_hex',     NULL,
      'is_elite',         false,
      'has_district_win', false,
      'has_province_win', false,
      'elite_threshold',  0,
      'yesterday_points', 0
    );
  END IF;

  -- ── District Win ──────────────────────────────────────────────────────────
  -- Primary: precomputed daily_buff_stats (set by calculate_daily_buffs cron)
  SELECT * INTO v_buff_stats
  FROM public.daily_buff_stats
  WHERE district_hex = v_district_hex
    AND stat_date = v_today_gmt2
  LIMIT 1;

  IF v_buff_stats IS NOT NULL THEN
    v_district_win := (v_buff_stats.dominant_team = v_user.team);
  ELSE
    -- Fallback: live hexes by district_hex (Res-6) column — correct resolution
    SELECT (
      CASE v_user.team
        WHEN 'red'    THEN COUNT(CASE WHEN last_runner_team = 'red'    THEN 1 END)
        WHEN 'blue'   THEN COUNT(CASE WHEN last_runner_team = 'blue'   THEN 1 END)
        WHEN 'purple' THEN COUNT(CASE WHEN last_runner_team = 'purple' THEN 1 END)
        ELSE 0
      END >
      GREATEST(
        CASE WHEN v_user.team != 'red'    THEN COUNT(CASE WHEN last_runner_team = 'red'    THEN 1 END) ELSE 0 END,
        CASE WHEN v_user.team != 'blue'   THEN COUNT(CASE WHEN last_runner_team = 'blue'   THEN 1 END) ELSE 0 END,
        CASE WHEN v_user.team != 'purple' THEN COUNT(CASE WHEN last_runner_team = 'purple' THEN 1 END) ELSE 0 END
      )
    ) INTO v_district_win
    FROM public.hexes
    WHERE district_hex = v_district_hex;  -- Res-6 filter: correct!
  END IF;

  -- ── Province Win ──────────────────────────────────────────────────────────
  -- "Province Win" = the user's local H3 Res-5 province (matches TeamScreen display).
  -- Purple gets NO province bonus per §2.3.4.
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
  -- If v_province_hex IS NULL (user hasn't run yet), v_province_win stays false.

  -- ── Team-specific buff calculation ───────────────────────────────────────
  IF v_user.team = 'red' THEN
    -- RED: Elite = top 20% by yesterday's flip_points in district
    v_is_elite := false;

    SELECT COUNT(DISTINCT rh.user_id) INTO v_red_runner_count
    FROM public.run_history rh
    JOIN public.users u ON u.id = rh.user_id
    WHERE u.team = 'red'
      AND (v_district_hex IS NULL OR u.district_hex = v_district_hex)
      AND rh.run_date = v_yesterday;

    IF v_red_runner_count > 0 THEN
      v_elite_cutoff_rank := GREATEST(1, (v_red_runner_count * 0.2)::INTEGER);

      -- Elite threshold: SUM flip_points per user, then rank by cutoff
      SELECT COALESCE(sub.total_points, 0) INTO v_elite_threshold
      FROM (
        SELECT
          rh.user_id,
          SUM(rh.flip_points) AS total_points,
          ROW_NUMBER() OVER (ORDER BY SUM(rh.flip_points) DESC) AS rn
        FROM public.run_history rh
        JOIN public.users u ON u.id = rh.user_id
        WHERE u.team = 'red'
          AND (v_district_hex IS NULL OR u.district_hex = v_district_hex)
          AND rh.run_date = v_yesterday
        GROUP BY rh.user_id
      ) sub
      WHERE sub.rn = v_elite_cutoff_rank;

      v_elite_threshold := COALESCE(v_elite_threshold, 0);

      SELECT COALESCE(SUM(rh.flip_points), 0) INTO v_user_yesterday_points
      FROM public.run_history rh
      WHERE rh.user_id = p_user_id
        AND rh.run_date = v_yesterday;

      v_is_elite := (v_user_yesterday_points >= v_elite_threshold
                     AND v_user_yesterday_points > 0);
    END IF;

    -- RED buff matrix (per DEVELOPMENT_SPEC §2.3.2):
    -- Elite base=2x, +1 district win, +1 province win (local Res-5) → max 4x
    -- Common base=1x, +0 district win, +1 province win (local Res-5) → max 2x
    v_base_buff     := CASE WHEN v_is_elite THEN 2 ELSE 1 END;
    v_district_bonus := CASE WHEN v_is_elite AND v_district_win THEN 1 ELSE 0 END;
    v_province_bonus := CASE WHEN v_province_win THEN 1 ELSE 0 END;
    v_multiplier    := v_base_buff + v_district_bonus + v_province_bonus;
    v_reason        := CASE WHEN v_is_elite THEN 'Elite' ELSE 'Common' END;

  ELSIF v_user.team = 'blue' THEN
    -- BLUE buff matrix (per DEVELOPMENT_SPEC §2.3.3):
    -- Base=1x, +1 district win, +1 province win (local Res-5) → max 3x
    v_base_buff      := 1;
    v_district_bonus := CASE WHEN v_district_win THEN 1 ELSE 0 END;
    v_province_bonus := CASE WHEN v_province_win THEN 1 ELSE 0 END;
    v_multiplier     := v_base_buff + v_district_bonus + v_province_bonus;
    v_reason         := 'Union';

  ELSIF v_user.team = 'purple' THEN
    -- PURPLE buff (per DEVELOPMENT_SPEC §2.3.4):
    -- Participation rate: ≥60%→3x, ≥30%→2x, <30%→1x. NO province bonus.
    IF v_buff_stats IS NOT NULL AND v_buff_stats.purple_participation_rate IS NOT NULL THEN
      IF v_buff_stats.purple_participation_rate >= 0.6 THEN
        v_base_buff := 3;
      ELSIF v_buff_stats.purple_participation_rate >= 0.3 THEN
        v_base_buff := 2;
      ELSE
        v_base_buff := 1;
      END IF;
    ELSE
      v_base_buff := 1;
    END IF;
    v_multiplier := v_base_buff;
    v_reason     := 'Participation';
  END IF;

  RETURN jsonb_build_object(
    'multiplier',           v_multiplier,
    'base_buff',            v_base_buff,
    'province_range_bonus', v_province_bonus,   -- Dart: BuffBreakdown.provinceRangeBonus
    'district_bonus',       v_district_bonus,
    'province_bonus',       v_province_bonus,
    'reason',               v_reason,
    'team',                 v_user.team,
    'district_hex',         v_district_hex,
    'is_elite',             v_is_elite,
    'has_district_win',     v_district_win,
    'has_province_win',     v_province_win,
    'elite_threshold',      COALESCE(v_elite_threshold, 0),
    'yesterday_points',     COALESCE(v_user_yesterday_points, 0)
  );
END;
$$;


-- ============================================================================
-- STEP 6: Grants
-- ============================================================================

GRANT EXECUTE ON FUNCTION public.get_user_buff(UUID, TEXT)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_daily_buffs()          TO authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_run(
  UUID, TIMESTAMPTZ, TIMESTAMPTZ, DOUBLE PRECISION, INTEGER,
  TEXT[], INTEGER, DOUBLE PRECISION, INTEGER, INTEGER, TEXT[], TEXT, TEXT[]
) TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.daily_province_range_stats TO authenticated;
