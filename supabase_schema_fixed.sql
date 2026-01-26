-- EcoCycle Supabase Schema - FIXED VERSION
-- This version addresses RLS policies, data type issues, and adds supervisor support

-- Disable RLS during schema setup to avoid recursion issues
ALTER ROLE postgres SET row_security = off;

-- ============================================================================
-- STEP 1: CREATE/UPDATE TABLES WITH CORRECT DATA TYPES
-- ============================================================================

-- Profiles table - FIXED with supervisor_id field
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT,
  phone_number TEXT,
  address TEXT,
  total_points INTEGER DEFAULT 0,
  user_role TEXT DEFAULT 'user', -- 'user', 'agent', 'admin'
  supervisor_id UUID REFERENCES profiles(id) ON DELETE SET NULL, -- Links to a supervisor/admin
  volunteer_requested_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Add missing columns to existing profiles table if they don't exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS supervisor_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS user_role TEXT DEFAULT 'user';

-- Create helper function for admin checks (SECURITY DEFINER - bypasses RLS)
DROP FUNCTION IF EXISTS public.check_is_admin() CASCADE;
CREATE OR REPLACE FUNCTION public.check_is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = OFF
AS $$
DECLARE
  v_is_admin BOOLEAN;
BEGIN
  -- Direct access with RLS disabled to prevent recursion
  SELECT (user_role = 'admin') INTO v_is_admin
  FROM public.profiles
  WHERE id = auth.uid()
  LIMIT 1;
  
  RETURN COALESCE(v_is_admin, FALSE);
EXCEPTION WHEN OTHERS THEN
  -- If any error (including recursion), return false for security
  RETURN FALSE;
END;
$$;

-- Critical: Set role to bypass RLS in function
ALTER FUNCTION public.check_is_admin() OWNER TO postgres;

-- Revoke execute from public for security
REVOKE EXECUTE ON FUNCTION public.check_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_is_admin() TO postgres, authenticated;

-- ============================================================================
-- STEP 2: DROP OLD RLS POLICIES AND CREATE PROPER ONES
-- ============================================================================

-- Drop all existing policies
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON profiles;
DROP POLICY IF EXISTS "profiles_self_manage" ON profiles;
DROP POLICY IF EXISTS "profiles_admin_view" ON profiles;

-- ============================================================================
-- STEP 3: CREATE CORRECTED RLS POLICIES FOR PROFILES (NON-RECURSIVE)
-- ============================================================================

-- Policy 1: Users can SELECT (view) their own profile
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT
  USING ((SELECT auth.uid()) = id);

-- Policy 2: Users can INSERT their own profile during signup
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = id);

-- Policy 3: Users can UPDATE their own profile
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

-- Policy 4: Admins can SELECT all profiles (separate policy to avoid recursion)
CREATE POLICY "Admins can view all profiles" ON profiles
  FOR SELECT
  USING (check_is_admin());

-- Policy 5: Admins can UPDATE all profiles
CREATE POLICY "Admins can update all profiles" ON profiles
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- ============================================================================
-- STEP 4: CREATE VOLUNTEER_APPLICATIONS TABLE
-- ============================================================================

DROP TABLE IF EXISTS volunteer_applications CASCADE;
CREATE TABLE IF NOT EXISTS volunteer_applications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT NOT NULL,
  address TEXT,
  available_date DATE NOT NULL,
  motivation TEXT NOT NULL,
  agreed_to_policy BOOLEAN DEFAULT FALSE,
  status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on volunteer_applications
ALTER TABLE volunteer_applications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Users can insert own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Users can update own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can view all applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can update applications" ON volunteer_applications;

-- Policies for volunteer_applications
CREATE POLICY "Users can view own applications" ON volunteer_applications
  FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own applications" ON volunteer_applications
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own applications" ON volunteer_applications
  FOR UPDATE
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Admins can view all applications" ON volunteer_applications
  FOR SELECT
  USING (check_is_admin());

CREATE POLICY "Admins can insert applications" ON volunteer_applications
  FOR INSERT
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

CREATE POLICY "Admins can update applications" ON volunteer_applications
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

CREATE POLICY "Admins can delete applications" ON volunteer_applications
  FOR DELETE
  USING (check_is_admin());

-- ============================================================================
-- STEP 5: EWASTE_ITEMS TABLE - FIX DATA TYPES
-- ============================================================================

CREATE TABLE IF NOT EXISTS ewaste_items (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item_name TEXT NOT NULL,
  description TEXT NOT NULL,
  image_url TEXT,
  location TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  category_id TEXT,
  reward_points INTEGER DEFAULT 0,
  assigned_agent_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  assigned_ngo_id UUID,
  delivery_status TEXT DEFAULT 'pending',
  metadata JSONB,
  tracking_notes JSONB,
  pickup_scheduled_at TIMESTAMP WITH TIME ZONE,
  collected_at TIMESTAMP WITH TIME ZONE,
  delivered_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add missing columns to existing ewaste_items table
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS item_name TEXT;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS category_id TEXT;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS reward_points INTEGER DEFAULT 0;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS assigned_agent_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS assigned_ngo_id UUID;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS delivery_status TEXT DEFAULT 'pending';
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS metadata JSONB;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS tracking_notes JSONB;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS pickup_scheduled_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS collected_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE ewaste_items ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Enable RLS on ewaste_items
ALTER TABLE ewaste_items ENABLE ROW LEVEL SECURITY;

-- Drop old policies
DROP POLICY IF EXISTS "Users can view own ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Users can insert own ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Users can update own ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Agents can view assigned items" ON ewaste_items;
DROP POLICY IF EXISTS "Admins can view all ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Admins can update all ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "ewaste_user_manage" ON ewaste_items;
DROP POLICY IF EXISTS "ewaste_admin_agent_view" ON ewaste_items;

-- Create corrected policies
CREATE POLICY "Users can view own ewaste items" ON ewaste_items
  FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own ewaste items" ON ewaste_items
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own ewaste items" ON ewaste_items
  FOR UPDATE
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Agents can view assigned items" ON ewaste_items
  FOR SELECT
  USING (check_is_admin() OR (SELECT auth.uid()) = assigned_agent_id);

CREATE POLICY "Admins can view all ewaste items" ON ewaste_items
  FOR SELECT
  USING (check_is_admin());

CREATE POLICY "Admins can update all ewaste items" ON ewaste_items
  FOR UPDATE
  USING (check_is_admin());

-- ============================================================================
-- STEP 6: PICKUP_REQUESTS TABLE
-- ============================================================================

-- Drop existing table if it exists to avoid conflicts
DROP TABLE IF EXISTS pickup_requests CASCADE;

CREATE TABLE IF NOT EXISTS pickup_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  agent_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
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

-- Enable RLS
ALTER TABLE pickup_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own pickup requests" ON pickup_requests;
DROP POLICY IF EXISTS "Agents can view assigned pickups" ON pickup_requests;
DROP POLICY IF EXISTS "Admins can view all pickups" ON pickup_requests;

CREATE POLICY "Agents can view own pickups" ON pickup_requests
  FOR SELECT
  USING ((SELECT auth.uid()) = agent_id);

CREATE POLICY "Admins can view all pickups" ON pickup_requests
  FOR SELECT
  USING (check_is_admin());

CREATE POLICY "Admins can update pickups" ON pickup_requests
  FOR UPDATE
  USING (check_is_admin());

-- ============================================================================
-- STEP 6.5: VOLUNTEER_AVAILABILITY TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS volunteer_availability (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  volunteer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  available_date DATE NOT NULL,
  is_available BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(volunteer_id, available_date)
);

-- Enable RLS
ALTER TABLE volunteer_availability ENABLE ROW LEVEL SECURITY;

-- Policies for volunteer_availability
CREATE POLICY "Volunteers can view own availability" ON volunteer_availability
  FOR SELECT
  USING ((SELECT auth.uid()) = volunteer_id);

CREATE POLICY "Volunteers can insert own availability" ON volunteer_availability
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = volunteer_id);

CREATE POLICY "Volunteers can update own availability" ON volunteer_availability
  FOR UPDATE
  USING ((SELECT auth.uid()) = volunteer_id)
  WITH CHECK ((SELECT auth.uid()) = volunteer_id);

CREATE POLICY "Admins can view all availability" ON volunteer_availability
  FOR SELECT
  USING (check_is_admin());

CREATE POLICY "Admins can update all availability" ON volunteer_availability
  FOR UPDATE
  USING (check_is_admin());

-- ============================================================================
-- STEP 7: NGO TABLE
-- ============================================================================

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

-- Enable RLS
ALTER TABLE ngos ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Everyone can view ngos" ON ngos;

CREATE POLICY "Everyone can view ngos" ON ngos
  FOR SELECT
  USING (TRUE);

-- ============================================================================
-- STEP 8: HELPER FUNCTIONS FOR QUERIES
-- ============================================================================

-- Function to get supervisor details
DROP FUNCTION IF EXISTS public.get_supervisor_details(uuid) CASCADE;
CREATE OR REPLACE FUNCTION public.get_supervisor_details(user_id uuid)
RETURNS TABLE (
  supervisor_id UUID,
  supervisor_name TEXT,
  supervisor_phone TEXT,
  supervisor_email TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = OFF
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.supervisor_id,
    p.full_name,
    p.phone_number,
    auth_user.email
  FROM profiles p
  LEFT JOIN auth.users auth_user ON p.id = auth_user.id
  WHERE p.id = (SELECT supervisor_id FROM profiles WHERE id = user_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_supervisor_details(uuid) TO authenticated;

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX IF NOT EXISTS profiles_user_role_idx ON profiles(user_role);
CREATE INDEX IF NOT EXISTS profiles_supervisor_id_idx ON profiles(supervisor_id);
CREATE INDEX IF NOT EXISTS volunteer_applications_user_id_idx ON volunteer_applications(user_id);
CREATE INDEX IF NOT EXISTS volunteer_applications_status_idx ON volunteer_applications(status);
CREATE INDEX IF NOT EXISTS ewaste_items_user_id_idx ON ewaste_items(user_id);
CREATE INDEX IF NOT EXISTS ewaste_items_assigned_agent_id_idx ON ewaste_items(assigned_agent_id);
CREATE INDEX IF NOT EXISTS ewaste_items_status_idx ON ewaste_items(status);

-- Add index for pickup_requests only if table has agent_id column
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'pickup_requests' AND column_name = 'agent_id'
  ) THEN
    CREATE INDEX IF NOT EXISTS pickup_requests_agent_id_idx ON pickup_requests(agent_id);
  END IF;
END
$$;

-- ============================================================================
-- STEP 9: RE-ENABLE ROW SECURITY FOR POSTGRES ROLE
-- ============================================================================
ALTER ROLE postgres SET row_security = on;
