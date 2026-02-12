-- Remote Configuration System for RunStrict
-- This table stores all server-configurable game parameters
-- Single-row design with JSONB for atomic updates and easy migrations

-- Create app_config table
CREATE TABLE IF NOT EXISTS app_config (
  id INTEGER PRIMARY KEY DEFAULT 1,
  config_version INTEGER NOT NULL DEFAULT 1,
  config_data JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  -- Ensure only one row can exist
  CONSTRAINT single_row CHECK (id = 1)
);

-- Create trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_app_config_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  NEW.config_version = OLD.config_version + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER app_config_update_timestamp
  BEFORE UPDATE ON app_config
  FOR EACH ROW
  EXECUTE FUNCTION update_app_config_timestamp();

-- Insert default configuration
-- JSON Schema:
-- {
--   "season": { durationDays, serverTimezoneOffsetHours },
--   "crew": { maxMembersRegular, maxMembersPurple },
--   "gps": { maxSpeedMps, minSpeedMps, maxAccuracyMeters, ... },
--   "scoring": { tierThresholdsKm, tierPoints, paceMultipliers, crewMultipliers },
--   "hex": { baseResolution, zoneResolution, cityResolution, allResolution, ... },
--   "timing": { accelerometerSamplingPeriodMs, refreshThrottleSeconds }
-- }

INSERT INTO app_config (id, config_version, config_data) VALUES (
  1,
  1,
  '{
    "season": {
      "durationDays": 40,
      "serverTimezoneOffsetHours": 2
    },
    "crew": {
      "maxMembersRegular": 12,
      "maxMembersPurple": 24
    },
    "gps": {
      "maxSpeedMps": 6.94,
      "minSpeedMps": 0.3,
      "maxAccuracyMeters": 50.0,
      "maxAltitudeChangeMps": 5.0,
      "maxJumpDistanceMeters": 100,
      "movingAvgWindowSeconds": 20,
      "maxCapturePaceMinPerKm": 8.0,
      "pollingRateHz": 0.5,
      "minTimeBetweenPointsMs": 1500
    },
    "scoring": {
      "tierThresholdsKm": [0, 3, 6, 9, 12, 15],
      "tierPoints": [10, 25, 50, 100, 150, 200],
      "paceMultipliers": {
        "walking": 0.8,
        "easyJog": 1.0,
        "comfortable": 1.2,
        "strong": 1.5,
        "fast": 1.8,
        "sprint": 2.0
      },
      "crewMultipliers": {
        "solo": 1.0,
        "duo": 1.3,
        "squad": 1.6,
        "crew": 2.0,
        "fullForce": 2.5,
        "unityWave": 3.0
      }
    },
    "hex": {
      "baseResolution": 9,
      "zoneResolution": 8,
      "cityResolution": 6,
      "allResolution": 5,
      "captureCheckDistanceMeters": 20.0,
      "maxCacheSize": 4000
    },
    "timing": {
      "accelerometerSamplingPeriodMs": 200,
      "refreshThrottleSeconds": 30
    }
  }'::jsonb
) ON CONFLICT (id) DO NOTHING;

-- Enable RLS (Row Level Security)
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read config (public)
CREATE POLICY "Anyone can read app_config" ON app_config
  FOR SELECT
  USING (true);

-- Only service role can update (admin only)
CREATE POLICY "Service role can update app_config" ON app_config
  FOR UPDATE
  USING (auth.role() = 'service_role');

-- Add comment for documentation
COMMENT ON TABLE app_config IS 'Server-configurable game parameters. Single-row table with JSONB data.';
COMMENT ON COLUMN app_config.config_version IS 'Auto-incremented on each update. Used for cache invalidation.';
COMMENT ON COLUMN app_config.config_data IS 'All configuration values as nested JSON object.';
