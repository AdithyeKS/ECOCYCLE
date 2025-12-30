-- ============================================================================
-- EcoCycle Supabase Schema - PRODUCTION VERSION
-- Comprehensive fixes for all identified issues:
-- ✅ Infinite recursion prevention (SET row_security = OFF)
-- ✅ Consolidated columns (no duplicates)
-- ✅ UUID type consistency (no TEXT casts)
-- ✅ Simplified, non-overlapping RLS policies
-- ✅ Proper helper function with security
-- ✅ Performance indexes on all policy columns
-- ============================================================================

-- Disable RLS during schema setup to avoid issues
ALTER ROLE postgres SET row_security = off;
ALTER ROLE authenticated SET row_security = off;

-- ============================================================================
-- STEP 1: DROP OLD SCHEMA ELEMENTS (CLEANUP)
-- ============================================================================

-- Drop old tables to start fresh
DROP TABLE IF EXISTS user_rewards CASCADE;
DROP TABLE IF EXISTS waste_categories CASCADE;
DROP TABLE IF EXISTS admin_roles CASCADE;
DROP TABLE IF EXISTS ewaste_items CASCADE;
DROP TABLE IF EXISTS volunteer_applications CASCADE;
DROP TABLE IF EXISTS pickup_requests CASCADE;
DROP TABLE IF EXISTS ngos CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- Drop old functions
DROP FUNCTION IF EXISTS public.check_is_admin() CASCADE;
DROP FUNCTION IF EXISTS public.get_supervisor_details(uuid) CASCADE;

-- ============================================================================
-- STEP 2: CORE TABLES WITH CORRECT DATA TYPES
-- ============================================================================

-- PROFILES TABLE - canonical source for user information
-- No duplicate columns, proper UUID types, clear role field
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  email TEXT,
  phone_number TEXT,
  address TEXT,
  user_role TEXT DEFAULT 'user' CHECK (user_role IN ('user', 'agent', 'admin')),
  supervisor_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  total_points INTEGER DEFAULT 0,
  volunteer_requested_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX profiles_id_idx ON profiles(id);
CREATE INDEX profiles_user_role_idx ON profiles(user_role);
CREATE INDEX profiles_supervisor_id_idx ON profiles(supervisor_id);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 3: HELPER FUNCTION FOR ADMIN CHECKS
-- ============================================================================

-- SECURITY DEFINER function with RLS disabled to prevent recursion
-- This function safely checks if the current user is an admin
CREATE OR REPLACE FUNCTION public.check_is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = OFF
STABLE
AS $$
DECLARE
  v_is_admin BOOLEAN;
BEGIN
  SELECT (user_role = 'admin') INTO v_is_admin
  FROM public.profiles
  WHERE id = auth.uid()
  LIMIT 1;
  
  RETURN COALESCE(v_is_admin, FALSE);
EXCEPTION WHEN OTHERS THEN
  RETURN FALSE;
END;
$$;

-- Secure function permissions
ALTER FUNCTION public.check_is_admin() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.check_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_is_admin() TO postgres, authenticated;

-- ============================================================================
-- STEP 4: RLS POLICIES FOR PROFILES
-- ============================================================================

-- Ownership policy: Users can manage their own profile
CREATE POLICY "profiles_user_own"
  ON profiles FOR ALL
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

-- Admin policies: Admins can view and manage all profiles
CREATE POLICY "profiles_admin_view"
  ON profiles FOR SELECT
  USING (check_is_admin());

CREATE POLICY "profiles_admin_manage"
  ON profiles FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- ============================================================================
-- STEP 5: NGOS TABLE (MUST BE CREATED BEFORE EWASTE_ITEMS)
-- ============================================================================

CREATE TABLE ngos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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

-- Enable RLS (but public can read)
ALTER TABLE ngos ENABLE ROW LEVEL SECURITY;

-- Everyone can read NGOs
CREATE POLICY "ngos_public_read"
  ON ngos FOR SELECT
  USING (TRUE);

-- ============================================================================
-- STEP 6: EWASTE_ITEMS TABLE (NOW CAN REFERENCE NGOS)
-- ============================================================================

CREATE TABLE ewaste_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  item_name TEXT NOT NULL,
  description TEXT NOT NULL,
  image_url TEXT,
  location TEXT NOT NULL,
  category_id TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'assigned', 'collected', 'delivered')),
  reward_points INTEGER DEFAULT 0,
  assigned_agent_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  assigned_ngo_id UUID REFERENCES ngos(id) ON DELETE SET NULL,
  delivery_status TEXT DEFAULT 'pending',
  metadata JSONB DEFAULT '{}',
  tracking_notes JSONB DEFAULT '[]',
  pickup_scheduled_at TIMESTAMP WITH TIME ZONE,
  collected_at TIMESTAMP WITH TIME ZONE,
  delivered_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX ewaste_items_user_id_idx ON ewaste_items(user_id);
CREATE INDEX ewaste_items_assigned_agent_id_idx ON ewaste_items(assigned_agent_id);
CREATE INDEX ewaste_items_status_idx ON ewaste_items(status);

-- Enable RLS
ALTER TABLE ewaste_items ENABLE ROW LEVEL SECURITY;

-- RLS policies for ewaste_items
-- Ownership: Users can manage their own items
CREATE POLICY "ewaste_items_user_own"
  ON ewaste_items FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Agents can view items assigned to them
CREATE POLICY "ewaste_items_agent_view"
  ON ewaste_items FOR SELECT
  USING ((SELECT auth.uid()) = assigned_agent_id);

-- Admins can view all items
CREATE POLICY "ewaste_items_admin_view"
  ON ewaste_items FOR SELECT
  USING (check_is_admin());

-- Admins can manage all items
CREATE POLICY "ewaste_items_admin_manage"
  ON ewaste_items FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- ============================================================================
-- STEP 7: PICKUP_REQUESTS TABLE
-- ============================================================================

CREATE TABLE pickup_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
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

CREATE INDEX pickup_requests_agent_id_idx ON pickup_requests(agent_id);

-- Enable RLS
ALTER TABLE pickup_requests ENABLE ROW LEVEL SECURITY;

-- Agents can view their own requests
CREATE POLICY "pickup_requests_agent_own"
  ON pickup_requests FOR SELECT
  USING ((SELECT auth.uid()) = agent_id);

-- Admins can view all requests
CREATE POLICY "pickup_requests_admin_view"
  ON pickup_requests FOR SELECT
  USING (check_is_admin());

-- Admins can manage all requests
CREATE POLICY "pickup_requests_admin_manage"
  ON pickup_requests FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- ============================================================================
-- STEP 8: VOLUNTEER_APPLICATIONS TABLE
-- ============================================================================

CREATE TABLE volunteer_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT NOT NULL,
  address TEXT,
  available_date DATE NOT NULL,
  motivation TEXT NOT NULL,
  agreed_to_policy BOOLEAN DEFAULT FALSE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX volunteer_applications_user_id_idx ON volunteer_applications(user_id);
CREATE INDEX volunteer_applications_status_idx ON volunteer_applications(status);

-- Enable RLS
ALTER TABLE volunteer_applications ENABLE ROW LEVEL SECURITY;

-- Users can manage their own applications
CREATE POLICY "volunteer_applications_user_own"
  ON volunteer_applications FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Admins can view and manage all applications
CREATE POLICY "volunteer_applications_admin_view"
  ON volunteer_applications FOR SELECT
  USING (check_is_admin());

CREATE POLICY "volunteer_applications_admin_manage"
  ON volunteer_applications FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- ============================================================================
-- STEP 9: WASTE_CATEGORIES TABLE
-- ============================================================================

CREATE TABLE waste_categories (
  id SERIAL PRIMARY KEY,
  name VARCHAR NOT NULL UNIQUE,
  description TEXT,
  icon VARCHAR,
  price_per_kg NUMERIC DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS (public can read)
ALTER TABLE waste_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "waste_categories_public_read"
  ON waste_categories FOR SELECT
  USING (TRUE);

-- ============================================================================
-- STEP 10: USER_REWARDS TABLE
-- ============================================================================

CREATE TABLE user_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  points INTEGER DEFAULT 0,
  total_waste_kg NUMERIC DEFAULT 0,
  total_pickups INTEGER DEFAULT 0,
  level VARCHAR DEFAULT 'beginner',
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX user_rewards_user_id_idx ON user_rewards(user_id);

-- Enable RLS
ALTER TABLE user_rewards ENABLE ROW LEVEL SECURITY;

-- Users can view their own rewards
CREATE POLICY "user_rewards_user_own"
  ON user_rewards FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

-- Admins can view all rewards
CREATE POLICY "user_rewards_admin_view"
  ON user_rewards FOR SELECT
  USING (check_is_admin());

-- ============================================================================
-- STEP 11: HELPER FUNCTIONS
-- ============================================================================

-- Function to get supervisor details with RLS disabled
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
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.supervisor_id,
    p.full_name,
    p.phone_number,
    p.email
  FROM profiles p
  WHERE p.id = (SELECT supervisor_id FROM profiles WHERE id = user_id LIMIT 1)
  LIMIT 1;
END;
$$;

ALTER FUNCTION public.get_supervisor_details(uuid) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.get_supervisor_details(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_supervisor_details(uuid) TO postgres, authenticated;

-- ============================================================================
-- STEP 12: RE-ENABLE ROW SECURITY FOR POSTGRES ROLE
-- ============================================================================

ALTER ROLE postgres SET row_security = on;
ALTER ROLE authenticated SET row_security = on;

-- ============================================================================
-- INITIALIZATION: Insert sample categories
-- ============================================================================

INSERT INTO waste_categories (name, description, icon, price_per_kg) VALUES
  ('Phones', 'Mobile phones and accessories', '📱', 5.00),
  ('Computers', 'Desktop and laptop computers', '💻', 3.00),
  ('Tablets', 'Tablets and e-readers', '📋', 4.00),
  ('Monitors', 'Computer monitors and screens', '🖥️', 2.00),
  ('Keyboards', 'Keyboards and input devices', '⌨️', 1.50),
  ('Printers', 'Printers and scanners', '🖨️', 2.50),
  ('Cables', 'Cables and connectors', '🔌', 0.50),
  ('Batteries', 'Batteries and chargers', '🔋', 3.50),
  ('Headphones', 'Headphones and speakers', '🎧', 2.00),
  ('Others', 'Other electronic waste', '📦', 1.00)
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- SUMMARY OF FIXES
-- ============================================================================
-- ✅ Removed duplicate columns (role/user_role → user_role, photo_url/image_url → image_url)
-- ✅ All identity columns are UUID type (no TEXT casts)
-- ✅ Consolidated policies: ownership + admin pattern
-- ✅ check_is_admin() has SET row_security = OFF to prevent recursion
-- ✅ All helper functions owned by postgres
-- ✅ Indexes on all columns used in RLS policies
-- ✅ CHECK constraints for status fields
-- ✅ Default timestamps on all tables
-- ✅ Proper foreign key relationships with ON DELETE CASCADE/SET NULL
-- ============================================================================
