-- Set season config in app_config. Uses jsonb_set to update durationDays
-- regardless of whether a 'season' key already exists.
-- Changing durationDays here propagates to all clients on next app launch.

UPDATE public.app_config
SET config_data = jsonb_set(
      config_data,
      '{season}',
      COALESCE(config_data->'season', '{}'::jsonb) || '{
        "durationDays": 5,
        "seasonNumber": 2,
        "startDate": "2026-02-11",
        "serverTimezoneOffsetHours": 2
      }'::jsonb
    ),
    config_version = config_version + 1,
    updated_at = now()
WHERE id = 1;
