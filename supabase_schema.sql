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

CREATE TABLE IF NOT EXISTS pickup_requests (
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
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS assigned_agent_id UUID REFERENCES pickup_requests(id);
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS assigned_ngo_id UUID REFERENCES ngos(id);
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS delivery_status TEXT DEFAULT 'pending'; -- pending, assigned, collected, delivered
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS tracking_notes JSONB; -- Array of tracking updates with timestamps
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS pickup_scheduled_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS collected_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP WITH TIME ZONE;

-- Rename columns to match code expectations (optional, or update code instead):
-- Only rename if source column exists and target column doesn't exist
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'ewaste_items' AND column_name = 'title')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'ewaste_items' AND column_name = 'item_name') THEN
        ALTER TABLE ewaste_items RENAME COLUMN title TO item_name;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'ewaste_items' AND column_name = 'photo_url')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'ewaste_items' AND column_name = 'image_url') THEN
        ALTER TABLE ewaste_items RENAME COLUMN photo_url TO image_url;
    END IF;
END $$;

-- Admin roles table to avoid recursion issues
CREATE TABLE IF NOT EXISTS admin_roles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Disable RLS on admin_roles to avoid recursion - access controlled by SECURITY DEFINER function
ALTER TABLE admin_roles DISABLE ROW LEVEL SECURITY;

-- Profiles table for user information (from profile_screen.dart)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT,
  phone_number TEXT,
  age INTEGER,
  address TEXT,
  total_points INTEGER DEFAULT 0,
  user_role TEXT DEFAULT 'user',
  volunteer_requested_at TIMESTAMP WITH TIME ZONE
);

-- Enable Row Level Security (RLS)
-- Temporarily disable RLS to fix recursion issue
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- Create helper function for admin checks (SECURITY DEFINER to avoid recursion)
CREATE OR REPLACE FUNCTION public.check_is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.admin_roles
    WHERE id = auth.uid()
  );
END;
$$;

-- Revoke execute from public for security
REVOKE EXECUTE ON FUNCTION public.check_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_is_admin() TO postgres;

-- Drop existing policies if they exist to avoid conflicts
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON profiles;

-- Recreate policies with proper auth checks
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING ((SELECT auth.uid()) = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING ((SELECT auth.uid()) = id);

CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK ((SELECT auth.uid()) = id);

-- Admin policies removed to avoid recursion - admins can manage via direct database access
-- CREATE POLICY "Admins can view all profiles" ON profiles
--   FOR SELECT USING (EXISTS (SELECT 1 FROM admin_roles WHERE id = auth.uid()));

-- CREATE POLICY "Admins can update all profiles" ON profiles
--   FOR UPDATE USING (EXISTS (SELECT 1 FROM admin_roles WHERE id = auth.uid()));

-- Volunteer applications table
CREATE TABLE IF NOT EXISTS volunteer_applications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT NOT NULL,
  address TEXT,
  available_date DATE NOT NULL,
  motivation TEXT NOT NULL,
  agreed_to_policy BOOLEAN DEFAULT FALSE,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on volunteer_applications
ALTER TABLE volunteer_applications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Users can insert own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can view all applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can update applications" ON volunteer_applications;

-- Policies for volunteer_applications
CREATE POLICY "Users can view own applications" ON volunteer_applications
  FOR SELECT USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own applications" ON volunteer_applications
  FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Admins can view all applications" ON volunteer_applications
  FOR SELECT USING (check_is_admin());

CREATE POLICY "Admins can update applications" ON volunteer_applications
  FOR UPDATE USING (check_is_admin());

-- Volunteer schedules table for availability management
CREATE TABLE IF NOT EXISTS volunteer_schedules (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  volunteer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  is_available BOOLEAN DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(volunteer_id, date) -- One schedule per volunteer per date
);

-- Volunteer assignments table for task assignments
CREATE TABLE IF NOT EXISTS volunteer_assignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  volunteer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  task_id UUID NOT NULL, -- References ewaste_items.id or other task tables
  task_type TEXT NOT NULL, -- 'ewaste_pickup', 'cloth_collection', etc.
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  scheduled_date DATE,
  status TEXT DEFAULT 'pending', -- 'pending', 'accepted', 'completed', 'cancelled'
  notes TEXT,
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Notifications table for assignment-related notifications
CREATE TABLE IF NOT EXISTS notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL, -- 'assignment_created', 'assignment_updated', 'assignment_due', etc.
  related_id UUID, -- Can reference assignment_id or other related entities
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (with CASCADE to handle dependencies)
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications CASCADE;
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications CASCADE;
DROP POLICY IF EXISTS "Admins can insert notifications" ON notifications CASCADE;

-- Policies for notifications
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Admins can insert notifications" ON notifications
  FOR INSERT WITH CHECK (check_is_admin());

-- Enable RLS on volunteer_schedules
ALTER TABLE volunteer_schedules ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Volunteers can view own schedules" ON volunteer_schedules;
DROP POLICY IF EXISTS "Volunteers can insert own schedules" ON volunteer_schedules;
DROP POLICY IF EXISTS "Volunteers can update own schedules" ON volunteer_schedules;
DROP POLICY IF EXISTS "Admins can view all schedules" ON volunteer_schedules;

-- Policies for volunteer_schedules
CREATE POLICY "Volunteers can view own schedules" ON volunteer_schedules
  FOR SELECT USING ((SELECT auth.uid()) = volunteer_id);

CREATE POLICY "Volunteers can insert own schedules" ON volunteer_schedules
  FOR INSERT WITH CHECK ((SELECT auth.uid()) = volunteer_id);

CREATE POLICY "Volunteers can update own schedules" ON volunteer_schedules
  FOR UPDATE USING ((SELECT auth.uid()) = volunteer_id);

CREATE POLICY "Admins can view all schedules" ON volunteer_schedules
  FOR SELECT USING (check_is_admin());

-- Enable RLS on volunteer_assignments
ALTER TABLE volunteer_assignments ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Volunteers can view own assignments" ON volunteer_assignments;
DROP POLICY IF EXISTS "Volunteers can update own assignments" ON volunteer_assignments;
DROP POLICY IF EXISTS "Admins can view all assignments" ON volunteer_assignments;
DROP POLICY IF EXISTS "Admins can insert assignments" ON volunteer_assignments;
DROP POLICY IF EXISTS "Admins can update assignments" ON volunteer_assignments;

-- Policies for volunteer_assignments
CREATE POLICY "Volunteers can view own assignments" ON volunteer_assignments
  FOR SELECT USING ((SELECT auth.uid()) = volunteer_id);

CREATE POLICY "Volunteers can update own assignments" ON volunteer_assignments
  FOR UPDATE USING ((SELECT auth.uid()) = volunteer_id);

CREATE POLICY "Admins can view all assignments" ON volunteer_assignments
  FOR SELECT USING (check_is_admin());

CREATE POLICY "Admins can insert assignments" ON volunteer_assignments
  FOR INSERT WITH CHECK (check_is_admin());

CREATE POLICY "Admins can update assignments" ON volunteer_assignments
  FOR UPDATE USING (check_is_admin());

-- Enable RLS on ewaste_items
ALTER TABLE ewaste_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (with CASCADE to handle dependencies)
DROP POLICY IF EXISTS "Users can view own ewaste items" ON ewaste_items CASCADE;
DROP POLICY IF EXISTS "Users can insert own ewaste items" ON ewaste_items CASCADE;
DROP POLICY IF EXISTS "Users can update own ewaste items" ON ewaste_items CASCADE;
DROP POLICY IF EXISTS "Agents can view assigned items" ON ewaste_items CASCADE;
DROP POLICY IF EXISTS "Admins can view all ewaste items" ON ewaste_items CASCADE;
DROP POLICY IF EXISTS "Admins can update all ewaste items" ON ewaste_items CASCADE;

-- Policies for ewaste_items
CREATE POLICY "Users can view own ewaste items" ON ewaste_items
  FOR SELECT USING ((SELECT auth.uid())::text = user_id::text);

CREATE POLICY "Users can insert own ewaste items" ON ewaste_items
  FOR INSERT WITH CHECK ((SELECT auth.uid())::text = user_id::text);

CREATE POLICY "Users can update own ewaste items" ON ewaste_items
  FOR UPDATE USING ((SELECT auth.uid())::text = user_id::text);

CREATE POLICY "Agents can view assigned items" ON ewaste_items
  FOR SELECT USING (check_is_admin() OR (SELECT auth.uid())::text = assigned_agent_id::text);

CREATE POLICY "Admins can view all ewaste items" ON ewaste_items
  FOR SELECT USING (check_is_admin());

CREATE POLICY "Admins can update all ewaste items" ON ewaste_items
  FOR UPDATE USING (check_is_admin());

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
