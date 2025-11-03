-- Create app_settings table to store global app configuration
CREATE TABLE IF NOT EXISTS app_settings (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  setting_key VARCHAR(255) UNIQUE NOT NULL,
  setting_value BOOLEAN DEFAULT true,
  description TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add RLS (Row Level Security) policies
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- Allow public read access (anyone can check if SMS is enabled)
CREATE POLICY "Enable public read access for app_settings"
  ON app_settings FOR SELECT
  USING (true);

-- Allow authenticated users with admin role to update settings
CREATE POLICY "Enable update for authenticated admin users"
  ON app_settings FOR UPDATE
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

-- Insert default settings
INSERT INTO app_settings (setting_key, setting_value, description)
VALUES 
  ('sms_enabled', true, 'Enable or disable OTP SMS feature'),
  ('maintenance_mode', false, 'Enable or disable maintenance mode')
ON CONFLICT (setting_key) DO NOTHING;
