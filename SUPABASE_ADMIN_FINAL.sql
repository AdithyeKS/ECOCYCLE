-- ============================================================================
-- ECOCYCLE COMPLETE ADMIN RLS POLICIES - FINAL VERSION
-- Run this in Supabase SQL Editor for full admin functionality
-- ============================================================================

-- Create admin check function
DROP FUNCTION IF EXISTS public.check_is_admin() CASCADE;
CREATE OR REPLACE FUNCTION public.check_is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = OFF
AS $$
BEGIN
  RETURN COALESCE(
    (SELECT user_role = 'admin' FROM public.profiles WHERE id = auth.uid()),
    FALSE
  );
EXCEPTION WHEN OTHERS THEN
  RETURN FALSE;
END;
$$;

ALTER FUNCTION public.check_is_admin() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.check_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_is_admin() TO postgres, authenticated;

-- ============================================================================
-- VOLUNTEER_APPLICATIONS POLICIES
-- ============================================================================
ALTER TABLE volunteer_applications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Users can insert own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Users can update own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can view all applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can insert applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can update applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can delete applications" ON volunteer_applications;

CREATE POLICY "Users can view own applications" ON volunteer_applications
  FOR SELECT USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own applications" ON volunteer_applications
  FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own applications" ON volunteer_applications
  FOR UPDATE USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Admins can view all applications" ON volunteer_applications
  FOR SELECT USING (check_is_admin());

CREATE POLICY "Admins can insert applications" ON volunteer_applications
  FOR INSERT WITH CHECK (check_is_admin());

CREATE POLICY "Admins can update applications" ON volunteer_applications
  FOR UPDATE USING (check_is_admin()) WITH CHECK (check_is_admin());

CREATE POLICY "Admins can delete applications" ON volunteer_applications
  FOR DELETE USING (check_is_admin());

-- ============================================================================
-- EWASTE_ITEMS POLICIES
-- ============================================================================
ALTER TABLE ewaste_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can view all ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Admins can update all ewaste items" ON ewaste_items;

CREATE POLICY "Admins can view all ewaste items" ON ewaste_items
  FOR SELECT USING (check_is_admin());

CREATE POLICY "Admins can update all ewaste items" ON ewaste_items
  FOR UPDATE USING (check_is_admin()) WITH CHECK (check_is_admin());

-- ============================================================================
-- PICKUP_REQUESTS POLICIES
-- ============================================================================
ALTER TABLE pickup_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Agents can view own pickups" ON pickup_requests;
DROP POLICY IF EXISTS "Admins can view all pickups" ON pickup_requests;
DROP POLICY IF EXISTS "Admins can insert pickups" ON pickup_requests;
DROP POLICY IF EXISTS "Admins can update pickups" ON pickup_requests;
DROP POLICY IF EXISTS "Admins can delete pickups" ON pickup_requests;

CREATE POLICY "Agents can view own pickups" ON pickup_requests
  FOR SELECT USING ((SELECT auth.uid()) = agent_id);

CREATE POLICY "Admins can view all pickups" ON pickup_requests
  FOR SELECT USING (check_is_admin());

CREATE POLICY "Admins can insert pickups" ON pickup_requests
  FOR INSERT WITH CHECK (check_is_admin());

CREATE POLICY "Admins can update pickups" ON pickup_requests
  FOR UPDATE USING (check_is_admin()) WITH CHECK (check_is_admin());

CREATE POLICY "Admins can delete pickups" ON pickup_requests
  FOR DELETE USING (check_is_admin());

-- ============================================================================
-- PROFILES POLICIES
-- ============================================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Admins can update profiles" ON profiles;

CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING ((SELECT auth.uid()) = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING ((SELECT auth.uid()) = id) WITH CHECK ((SELECT auth.uid()) = id);

CREATE POLICY "Admins can view all profiles" ON profiles
  FOR SELECT USING (check_is_admin());

CREATE POLICY "Admins can update profiles" ON profiles
  FOR UPDATE USING (check_is_admin()) WITH CHECK (check_is_admin());

-- ============================================================================
-- NGOS POLICIES
-- ============================================================================
ALTER TABLE ngos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Everyone can view ngos" ON ngos;

CREATE POLICY "Everyone can view ngos" ON ngos
  FOR SELECT USING (TRUE);

-- ============================================================================
-- VERIFY ALL IS WORKING
-- ============================================================================
SELECT 'Admin RLS Setup Complete' as status;
SELECT COUNT(*) as admin_count FROM profiles WHERE user_role = 'admin';
SELECT COUNT(*) as volunteer_apps FROM volunteer_applications;
SELECT COUNT(*) as ewaste_items FROM ewaste_items;
SELECT COUNT(*) as ngos FROM ngos;
