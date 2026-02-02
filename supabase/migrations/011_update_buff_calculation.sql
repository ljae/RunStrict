-- RunStrict: Updated Buff Calculation Rules
-- Run this in Supabase SQL Editor after 008_buff_system.sql
-- 
-- Updates get_user_buff() to implement the new buff calculation matrix:
--
-- RED FLAME:
-- | Scenario              | Elite (Top 20%) | Common |
-- |-----------------------|-----------------|--------|
-- | Normal (no wins)      | 2x              | 1x     |
-- | District win only     | 3x              | 1x     |
-- | Province win only     | 3x              | 2x     |
-- | District + Province   | 4x              | 2x     |
--
-- BLUE WAVE:
-- | Scenario              | Union |
-- |-----------------------|-------|
-- | Normal (no wins)      | 1x    |
-- | District win only     | 2x    |
-- | Province win only     | 2x    |
-- | District + Province   | 3x    |
--
-- PURPLE CHAOS:
-- | Participation Rate    | Multiplier |
-- |-----------------------|------------|
-- | >= 60%                | 3x         |
-- | 30% - 59%             | 2x         |
-- | < 30%                 | 1x         |
--
-- Terminology changes:
-- - "City Leader" -> "District Win" (team controls most hexes in District)
-- - "All Range"   -> "Province Win" (team controls most hexes server-wide)

COMMENT ON FUNCTION public.get_user_buff(UUID) IS 
'Returns user buff multiplier using the updated calculation matrix (2026-02-01):

RED FLAME:
- Elite (top 20%): Base 2x, +1 District, +1 Province = max 4x
- Common: Base 1x, NO District bonus, +1 Province = max 2x

BLUE WAVE:
- Union: Base 1x, +1 District, +1 Province = max 3x

PURPLE CHAOS:
- Participation >= 60%: 3x
- Participation 30-59%: 2x
- Participation < 30%: 1x
- No territory bonuses

Terminology:
- District Win = Team controls most hexes in user district (Res 6)
- Province Win = Team controls most hexes server-wide';

CREATE OR REPLACE FUNCTION public.get_user_buff(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_district_hex TEXT;
  v_district_stats RECORD;
  v_province_stats RECORD;
  v_yesterday DATE := CURRENT_DATE - INTERVAL '1 day';
  v_today DATE := CURRENT_DATE;
  v_yesterday_points INTEGER;
  v_multiplier INTEGER := 1;
  v_has_district_win BOOLEAN := FALSE;
  v_has_province_win BOOLEAN := FALSE;
  v_is_elite BOOLEAN := FALSE;
  v_reason TEXT := 'Default';
  v_base_buff INTEGER := 1;
  v_district_bonus INTEGER := 0;
  v_province_bonus INTEGER := 0;
BEGIN
  -- Get user info
  SELECT u.id, u.team, u.home_hex_end
  INTO v_user
  FROM public.users u
  WHERE u.id = p_user_id;

  IF v_user.id IS NULL OR v_user.team IS NULL THEN
    RETURN jsonb_build_object(
      'multiplier', 1,
      'base_buff', 1,
      'all_range_bonus', 0,  -- backward compat
      'district_bonus', 0,
      'province_bonus', 0,
      'reason', 'User not found or no team',
      'is_city_leader', FALSE,  -- backward compat
      'has_district_win', FALSE,
      'has_province_win', FALSE,
      'is_elite', FALSE
    );
  END IF;

  -- Derive user's district (Res 6 parent - simplified: first 10 chars)
  IF v_user.home_hex_end IS NOT NULL AND length(v_user.home_hex_end) > 0 THEN
    v_district_hex := substring(v_user.home_hex_end from 1 for 10);
  ELSE
    v_district_hex := NULL;
  END IF;

  -- Get district buff stats for today
  SELECT * INTO v_district_stats
  FROM public.daily_buff_stats
  WHERE stat_date = v_today
    AND city_hex = v_district_hex;

  -- Get Province (All Range) stats for today
  SELECT * INTO v_province_stats
  FROM public.daily_all_range_stats
  WHERE stat_date = v_today;

  -- Check if user's team has district win
  IF v_district_stats IS NOT NULL THEN
    v_has_district_win := (v_district_stats.dominant_team = v_user.team);
  END IF;

  -- Check if user's team has province win
  IF v_province_stats IS NOT NULL THEN
    v_has_province_win := (v_province_stats.dominant_team = v_user.team);
  END IF;

  -- Calculate buff based on team
  CASE v_user.team
    WHEN 'red' THEN
      -- Get user's yesterday flip points to determine Elite status
      SELECT COALESCE(SUM(rh.flip_points), 0)
      INTO v_yesterday_points
      FROM public.run_history rh
      WHERE rh.user_id = p_user_id
        AND rh.run_date = v_yesterday;

      -- Check if Elite (top 20%)
      v_is_elite := (v_yesterday_points >= COALESCE(v_district_stats.red_elite_threshold_points, 0) 
                     AND v_yesterday_points > 0);

      IF v_is_elite THEN
        -- RED Elite: Base 2x, +1 for district, +1 for province = max 4x
        v_base_buff := 2;
        v_reason := 'RED Elite';
        
        IF v_has_district_win THEN
          v_district_bonus := 1;
          v_reason := v_reason || ' +District';
        END IF;
        
        IF v_has_province_win THEN
          v_province_bonus := 1;
          v_reason := v_reason || ' +Province';
        END IF;
        
        v_multiplier := v_base_buff + v_district_bonus + v_province_bonus;
      ELSE
        -- RED Common: Base 1x, NO district bonus, +1 for province = max 2x
        v_base_buff := 1;
        v_reason := 'RED Common';
        
        -- Common does NOT get district bonus (v_district_bonus stays 0)
        IF v_has_district_win THEN
          v_reason := v_reason || ' (District win - no bonus)';
        END IF;
        
        IF v_has_province_win THEN
          v_province_bonus := 1;
          v_reason := v_reason || ' +Province';
        END IF;
        
        v_multiplier := v_base_buff + v_province_bonus;
      END IF;

    WHEN 'blue' THEN
      -- BLUE Union: Base 1x, +1 for district, +1 for province = max 3x
      v_base_buff := 1;
      v_reason := 'BLUE Union';
      
      IF v_has_district_win THEN
        v_district_bonus := 1;
        v_reason := v_reason || ' +District';
      END IF;
      
      IF v_has_province_win THEN
        v_province_bonus := 1;
        v_reason := v_reason || ' +Province';
      END IF;
      
      v_multiplier := v_base_buff + v_district_bonus + v_province_bonus;

    WHEN 'purple' THEN
      -- Purple uses participation rate tiers (no district/province bonus)
      v_has_district_win := FALSE;  -- Purple ignores territory wins
      v_has_province_win := FALSE;
      v_district_bonus := 0;
      v_province_bonus := 0;
      
      IF v_district_stats IS NOT NULL AND v_district_stats.purple_participation_rate IS NOT NULL THEN
        IF v_district_stats.purple_participation_rate >= 0.60 THEN
          v_multiplier := 3;
          v_base_buff := 3;
          v_reason := 'PURPLE High Participation (>=60%)';
        ELSIF v_district_stats.purple_participation_rate >= 0.30 THEN
          v_multiplier := 2;
          v_base_buff := 2;
          v_reason := 'PURPLE Mid Participation (30-59%)';
        ELSE
          v_multiplier := 1;
          v_base_buff := 1;
          v_reason := 'PURPLE Low Participation (<30%)';
        END IF;
      ELSE
        v_multiplier := 1;
        v_base_buff := 1;
        v_reason := 'PURPLE (no district stats)';
      END IF;

    ELSE
      v_multiplier := 1;
      v_base_buff := 1;
      v_reason := 'Unknown team';
  END CASE;

  RETURN jsonb_build_object(
    'multiplier', v_multiplier,
    'base_buff', v_base_buff,
    -- Backward compatibility fields
    'all_range_bonus', v_province_bonus,
    'is_city_leader', v_has_district_win,
    -- New fields with clearer names
    'district_bonus', v_district_bonus,
    'province_bonus', v_province_bonus,
    'reason', v_reason,
    'team', v_user.team,
    'city_hex', v_district_hex,  -- backward compat
    'district_hex', v_district_hex,
    'has_district_win', v_has_district_win,
    'has_province_win', v_has_province_win,
    'is_elite', v_is_elite
  );
END;
$$;
