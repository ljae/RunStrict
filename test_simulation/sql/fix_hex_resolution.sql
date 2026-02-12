-- Fix: allResolution in app_config should be 5, not 4
-- Root cause: Original migration 20260128_create_app_config.sql set allResolution=4
-- But all code expects allResolution=5 (Res 5 = Province, 7^4 = 2,401 hexes)
-- With allResolution=4, province = Res 4 = 7^5 = 16,807 hexes (wrong!)
-- This caused province name to change because Res 4 parent varies more

-- Check current value
SELECT 
  config_data->'hex'->'allResolution' as current_all_resolution,
  config_data->'hex' as hex_config
FROM app_config WHERE id = 1;

-- Fix: Update allResolution from 4 to 5
UPDATE app_config
SET config_data = jsonb_set(
  config_data,
  '{hex,allResolution}',
  '5'::jsonb
),
updated_at = NOW()
WHERE id = 1;

-- Verify fix
SELECT 
  config_data->'hex'->'allResolution' as fixed_all_resolution,
  config_data->'hex' as hex_config
FROM app_config WHERE id = 1;
