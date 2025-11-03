-- Create users table in Supabase
-- Run this SQL query in your Supabase SQL Editor

CREATE TABLE IF NOT EXISTS users (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  phone_number VARCHAR(11) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  is_active BOOLEAN DEFAULT true,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_users_phone_number ON users(phone_number);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active);

-- Enable Row Level Security (RLS) for security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all users to insert
CREATE POLICY "Allow all users to insert users"
  ON users
  FOR INSERT
  WITH CHECK (true);

-- Create policy to allow users to read users
CREATE POLICY "Allow users to read users"
  ON users
  FOR SELECT
  USING (true);

-- Create policy to allow users to update users
CREATE POLICY "Allow users to update users"
  ON users
  FOR UPDATE
  USING (true)
  WITH CHECK (true);
