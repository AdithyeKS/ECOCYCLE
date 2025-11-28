-- EcoCycle Supabase Schema
-- Based on the Flutter code analysis

-- You already created this table:
-- CREATE TABLE public.ewaste_items (
--   id uuid NOT NULL DEFAULT gen_random_uuid(),
--   user_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
--   title text NOT NULL,
--   description text NOT NULL,
--   photo_url text NOT NULL,
--   location text NOT NULL,
--   status text NOT NULL DEFAULT 'Pending'::text,
--   created_at timestamp without time zone NOT NULL DEFAULT now(),
--   CONSTRAINT ewaste_items_pkey PRIMARY KEY (id)
-- );

-- NOTE: Your ewaste_items table has some mismatches with the Flutter code:
-- Code expects: item_name, image_url, category_id, reward_points, assigned_to, metadata
-- Your table has: title, photo_url, user_id (but no category_id, reward_points, etc.)
-- You may need to add these columns or update the Flutter code to match.

-- Add missing columns to your existing ewaste_items table:
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS category_id TEXT;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS reward_points INTEGER;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS assigned_to TEXT;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS metadata JSONB;

-- New tables for NGO and pickup agent system
CREATE TABLE IF NOT EXISTS ngos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  address TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  is_government_approved BOOLEAN DEFAULT TRUE,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pickup_agents (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  vehicle_number TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  current_latitude DOUBLE PRECISION,
  current_longitude DOUBLE PRECISION,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Extend ewaste_items table with new columns for the complete flow
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS assigned_agent_id UUID REFERENCES pickup_agents(id);
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS assigned_ngo_id UUID REFERENCES ngos(id);
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS delivery_status TEXT DEFAULT 'pending'; -- pending, assigned, collected, delivered
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS tracking_notes JSONB; -- Array of tracking updates with timestamps
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS pickup_scheduled_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS collected_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP WITH TIME ZONE;

-- Rename columns to match code expectations (optional, or update code instead):
ALTER TABLE ewaste_items RENAME COLUMN title TO item_name;
ALTER TABLE ewaste_items RENAME COLUMN photo_url TO image_url;

-- Profiles table for user information (from profile_screen.dart)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT,
  phone_number TEXT,
  age INTEGER,
  address TEXT,
  total_points INTEGER DEFAULT 0
);

-- Enable Row Level Security (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Policy for users to read/update their own profile
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- For future expansion (dynamic rewards/badges system):

-- CREATE TABLE user_badges (
--   id SERIAL PRIMARY KEY,
--   user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
--   badge_name TEXT NOT NULL,
--   earned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
-- );

-- CREATE TABLE rewards (
--   id SERIAL PRIMARY KEY,
--   name TEXT NOT NULL,
--   description TEXT,
--   cost_points INTEGER NOT NULL,
--   is_available BOOLEAN DEFAULT TRUE
-- );

-- CREATE TABLE redeemed_rewards (
--   id SERIAL PRIMARY KEY,
--   user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
--   reward_id INTEGER REFERENCES rewards(id),
--   redeemed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
-- );
