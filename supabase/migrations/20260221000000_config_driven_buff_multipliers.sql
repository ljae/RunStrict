-- Make get_user_buff() config-driven: read all buff multiplier values from
-- the app_config.config_data->'buff' JSONB instead of hardcoding them.
-- This allows changing RED/BLUE/PURPLE buff values via a simple UPDATE
-- on app_config without any code deploy or migration.

-- Step 1: Add 'buff' section to existing config_data (merge, don't overwrite)
UPDATE public.app_config
SET config_data = config_data || '{
  "buff": {
    "redEliteThreshold": 0.20,
    "redEliteBase": 2,
    "redCommonBase": 1,
    "eliteDistrictWinBonus": 1,
    "eliteProvinceWinBonus": 1,
    "commonDistrictWinBonus": 0,
    "commonProvinceWinBonus": 1,
    "blueUnionBase": 1,
    "blueDistrictWinBonus": 1,
    "blueProvinceWinBonus": 1,
    "purpleHighTierThreshold": 0.60,
    "purpleMidTierThreshold": 0.30,
    "purpleHighTierBuff": 3,
    "purpleMidTierBuff": 2,
    "purpleLowTierBuff": 1
  }
}'::jsonb,
    updated_at = now()
WHERE id = 1
  AND NOT (config_data ? 'buff');

-- Step 2: Rewrite get_user_buff() to read from app_config
DROP FUNCTION IF EXISTS public.get_user_buff(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.get_user_buff(
  p_user_id UUID,
  p_district_hex TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
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

  -- Config values (read from app_config, with hardcoded fallbacks)
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
  -- ── Load buff config from app_config table ───────────────────────
  SELECT config_data->'buff' INTO v_cfg
  FROM public.app_config
  LIMIT 1;

  -- Extract with fallback defaults (identical to previous hardcoded values)
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

  -- ── Get user info ────────────────────────────────────────────────
  SELECT team, district_hex INTO v_user
  FROM public.users WHERE id = p_user_id;

  -- Use client-provided district_hex as fallback
  v_district_hex := COALESCE(v_user.district_hex, p_district_hex);

  IF v_user IS NULL OR v_district_hex IS NULL THEN
    RETURN jsonb_build_object(
      'multiplier', 1, 'base_buff', 1,
      'all_range_bonus', 0, 'district_bonus', 0, 'province_bonus', 0,
      'reason', 'Default',
      'team', COALESCE(v_user.team, ''),
      'district_hex', NULL,
      'is_elite', false,
      'has_district_win', false,
      'has_province_win', false,
      'elite_threshold', 0,
      'yesterday_points', 0
    );
  END IF;

  -- Yesterday in server timezone (GMT+2) - MUST match get_team_rankings()
  v_yesterday := (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE - INTERVAL '1 day';

  -- ── District win detection ───────────────────────────────────────
  BEGIN
    SELECT * INTO v_buff_stats
    FROM public.daily_buff_stats
    WHERE city_hex = v_district_hex
      AND stat_date = CURRENT_DATE
    LIMIT 1;
  EXCEPTION WHEN undefined_column THEN
    v_buff_stats := NULL;
  END;

  IF v_buff_stats IS NOT NULL THEN
    v_district_win := (v_buff_stats.dominant_team = v_user.team);
  ELSE
    SELECT (
      CASE v_user.team
        WHEN 'red' THEN COUNT(CASE WHEN last_runner_team = 'red' THEN 1 END)
        WHEN 'blue' THEN COUNT(CASE WHEN last_runner_team = 'blue' THEN 1 END)
        ELSE 0
      END >
      GREATEST(
        CASE WHEN v_user.team != 'red' THEN COUNT(CASE WHEN last_runner_team = 'red' THEN 1 END) ELSE 0 END,
        CASE WHEN v_user.team != 'blue' THEN COUNT(CASE WHEN last_runner_team = 'blue' THEN 1 END) ELSE 0 END,
        CASE WHEN v_user.team != 'purple' THEN COUNT(CASE WHEN last_runner_team = 'purple' THEN 1 END) ELSE 0 END
      )
    ) INTO v_district_win
    FROM public.hexes
    WHERE parent_hex = v_district_hex;
  END IF;

  -- ── Province win detection ───────────────────────────────────────
  BEGIN
    SELECT * INTO v_province_stats
    FROM public.daily_province_range_stats
    WHERE date = CURRENT_DATE;
  EXCEPTION WHEN undefined_table THEN
    v_province_stats := NULL;
  END;

  IF v_province_stats IS NOT NULL THEN
    v_province_win := (v_province_stats.leading_team = v_user.team);
  ELSE
    v_province_win := false;
  END IF;

  -- ── Team-specific buff calculation (config-driven) ───────────────
  IF v_user.team = 'red' THEN
    -- RED: Check elite status from run_history
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

      v_is_elite := (v_user_yesterday_points >= v_elite_threshold AND v_user_yesterday_points > 0);
    END IF;

    -- RED buff from config values
    v_base_buff := CASE WHEN v_is_elite THEN v_red_elite_base ELSE v_red_common_base END;
    v_district_bonus := CASE
      WHEN v_is_elite AND v_district_win THEN v_elite_district_win_bonus
      WHEN NOT v_is_elite AND v_district_win THEN v_common_district_win_bonus
      ELSE 0
    END;
    v_province_bonus := CASE
      WHEN v_is_elite AND v_province_win THEN v_elite_province_win_bonus
      WHEN NOT v_is_elite AND v_province_win THEN v_common_province_win_bonus
      ELSE 0
    END;
    v_multiplier := v_base_buff + v_district_bonus + v_province_bonus;
    v_reason := CASE WHEN v_is_elite THEN 'Elite' ELSE 'Common' END;

  ELSIF v_user.team = 'blue' THEN
    -- BLUE buff from config values
    v_base_buff := v_blue_union_base;
    v_district_bonus := CASE WHEN v_district_win THEN v_blue_district_win_bonus ELSE 0 END;
    v_province_bonus := CASE WHEN v_province_win THEN v_blue_province_win_bonus ELSE 0 END;
    v_multiplier := v_base_buff + v_district_bonus + v_province_bonus;
    v_reason := 'Union';

  ELSIF v_user.team = 'purple' THEN
    -- PURPLE buff from config values
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
    'multiplier', v_multiplier,
    'base_buff', v_base_buff,
    'all_range_bonus', v_province_bonus,
    'district_bonus', v_district_bonus,
    'province_bonus', v_province_bonus,
    'reason', v_reason,
    'team', v_user.team,
    'district_hex', v_district_hex,
    'is_elite', v_is_elite,
    'has_district_win', v_district_win,
    'has_province_win', v_province_win,
    'elite_threshold', COALESCE(v_elite_threshold, 0),
    'yesterday_points', COALESCE(v_user_yesterday_points, 0)
  );
END;
$$;
