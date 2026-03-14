-- =============================================================================
-- Config Architecture Cleanup
-- =============================================================================
-- PURPOSE:
--   1. Fix durationDays fallback in handle_season_transition() from 5 → 40.
--
--   2. Add a _note sentinel to the app_config.buff section documenting that
--      buff values are Tier 3 (hardcoded in SQL, not config-driven). See
--      CONFIG_GUIDE.md §Tier 3 for rationale.
--
--   3. Update app_config.season.durationDays from 5 → 40 (the live stored value).
--      Fix 1 only corrects the SQL fallback used when the 'season' key is absent
--      entirely. The actual row had durationDays: 5 (set by migration
--      20260224125748_seed_season_config as a testing artifact). This UPDATE
--      ensures RemoteConfigService returns 40 on next app launch.
--
--   2. Add sentinel comments to get_user_buff() documenting that buff values
--      are Tier 3 (code-only). These values must be kept in sync with:
--        - lib/data/models/app_config.dart  (BuffConfig)
--        - DEVELOPMENT_SPEC.md §2.3
--      Changing buff values requires BOTH a new SQL migration AND updating
--      BuffConfig defaults. See CONFIG_GUIDE.md for the decision tree.
--
-- BACKGROUND:
--   Migration 20260221000000 made get_user_buff() read buff values from the
--   app_config table dynamically. Migration 20260306000003 rewrote the function
--   to fix province scoping but re-hardcoded all buff values. The values are
--   correct (matching DEVELOPMENT_SPEC), but the config-driven mechanism was
--   intentionally NOT restored — see CONFIG_GUIDE.md §Tier 3 for rationale.
-- =============================================================================


-- =============================================================================
-- Fix 1: Correct durationDays fallback in handle_season_transition()
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_season_transition()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_cfg                 JSONB;
  v_duration            INT;
  v_base_season         INT;
  v_start_date          DATE;
  v_today_gmt2          DATE;
  v_tomorrow_gmt2       DATE;
  v_days_elapsed_tomorrow INT;
  v_ending_season       INT;
  v_result              jsonb;
BEGIN
  -- Read season config with fallback defaults.
  -- durationDays fallback: 40 (production season length).
  -- Previously this was 5 — a testing artifact. Fixed here.
  SELECT config_data->'season' INTO v_cfg FROM app_config LIMIT 1;
  v_duration    := COALESCE((v_cfg->>'durationDays')::INT,  40); -- was 5, now 40
  v_base_season := COALESCE((v_cfg->>'seasonNumber')::INT,  2);
  v_start_date  := COALESCE((v_cfg->>'startDate')::DATE, '2026-02-11'::DATE);

  -- Current date in GMT+2 (runs at 23:55 GMT+2 when cron fires at 21:55 UTC)
  v_today_gmt2    := (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE;
  v_tomorrow_gmt2 := v_today_gmt2 + 1;

  -- How many days until tomorrow from the first season's start?
  v_days_elapsed_tomorrow := v_tomorrow_gmt2 - v_start_date;

  -- Guard: never fire on or before the first season start day
  -- Season boundary: tomorrow's days_elapsed is a positive multiple of durationDays
  IF v_days_elapsed_tomorrow > 0 AND v_days_elapsed_tomorrow % v_duration = 0 THEN
    v_ending_season := v_base_season + (v_days_elapsed_tomorrow / v_duration) - 1;

    SELECT reset_season(v_ending_season) INTO v_result;

    RETURN v_result || jsonb_build_object(
      'trigger',      'season_end',
      'ending_season', v_ending_season,
      'fired_at_gmt2', v_today_gmt2::TEXT
    );
  END IF;

  RETURN jsonb_build_object(
    'trigger',       'none',
    'today_gmt2',    v_today_gmt2::TEXT,
    'days_to_next_season', v_duration - (v_days_elapsed_tomorrow % v_duration)
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.handle_season_transition() TO service_role;


-- =============================================================================
-- Fix 2: Add config documentation note to app_config buff section
-- =============================================================================
-- The buff key in config_data was left over from 20260221000000 (config-driven
-- buff attempt). get_user_buff() no longer reads it. We add a _note key to
-- prevent future developers from thinking this drives server behavior.

UPDATE public.app_config
SET config_data = jsonb_set(
  config_data,
  '{buff,_note}',
  '"Tier 3: buff values are hardcoded in get_user_buff(). This section is documentation only. See CONFIG_GUIDE.md."'::jsonb
),
  updated_at = now()
WHERE id = 1
  AND config_data ? 'buff';


-- =============================================================================
-- Fix 3: Update app_config.season.durationDays 5 → 40 (live stored value)
-- =============================================================================
-- Fix 1 corrects the SQL fallback (used only when the 'season' key is absent).
-- This UPDATE fixes the actual stored value in the row, which is what
-- RemoteConfigService reads and propagates to all clients on app launch.
-- Condition: only runs if current value is not already 40 (idempotent).

UPDATE public.app_config
SET config_data = jsonb_set(
  config_data,
  '{season,durationDays}',
  '40'::jsonb
),
  updated_at = now()
WHERE id = 1
  AND (config_data -> 'season' ->> 'durationDays')::INT != 40;

NOTIFY pgrst, 'reload schema';
