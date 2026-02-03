-- ============================================================================
-- COMPLETE FIX FOR ADMIN DASHBOARD DATA FETCHING ISSUES
-- ============================================================================
-- Issues Fixed:
-- 1. No pending requests showing in dispatch management
-- 2. No applications showing in admin page
-- Root Cause: Missing RLS policies for admin access to waste tables
-- ============================================================================

-- ============================================================================
-- STEP 1: CREATE/ENSURE check_is_admin() FUNCTION EXISTS
-- ============================================================================
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
  SELECT (user_role = 'admin') INTO v_is_admin
  FROM public.profiles
  WHERE id = auth.uid()
  LIMIT 1;
  RETURN COALESCE(v_is_admin, FALSE);
EXCEPTION WHEN OTHERS THEN
  RETURN FALSE;
END;
$$;

ALTER FUNCTION public.check_is_admin() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.check_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_is_admin() TO postgres, authenticated;

-- ============================================================================
-- STEP 2: ENABLE RLS ON ALL REQUIRED TABLES
-- ============================================================================
ALTER TABLE volunteer_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE ewaste_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE plastic_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE cloth_donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE volunteer_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 3: DROP EXISTING POLICIES TO AVOID CONFLICTS
-- ============================================================================
-- Volunteer applications
DROP POLICY IF EXISTS "Users can view own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Users can insert own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Users can update own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can view all applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can insert applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can update applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can delete applications" ON volunteer_applications;

-- E-waste items
DROP POLICY IF EXISTS "Admins can view all ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Admins can update all ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Admins can delete all ewaste items" ON ewaste_items;

-- Plastic items
DROP POLICY IF EXISTS "Admins can view all plastic items" ON plastic_items;
DROP POLICY IF EXISTS "Admins can update all plastic items" ON plastic_items;

-- Cloth donations
DROP POLICY IF EXISTS "Admins can view all cloth donations" ON cloth_donations;
DROP POLICY IF EXISTS "Admins can update all cloth donations" ON cloth_donations;

-- Profiles
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;

-- Volunteer schedules
DROP POLICY IF EXISTS "Admins can view all schedules" ON volunteer_schedules;

-- Feedback
DROP POLICY IF EXISTS "Admins can view all feedback" ON feedback;
DROP POLICY IF EXISTS "Admins can delete feedback" ON feedback;

-- ============================================================================
-- STEP 4: CREATE POLICIES FOR VOLUNTEER_APPLICATIONS
-- ============================================================================
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
  WITH CHECK (check_is_admin());

CREATE POLICY "Admins can update applications" ON volunteer_applications
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

CREATE POLICY "Admins can delete applications" ON volunteer_applications
  FOR DELETE
  USING (check_is_admin());

-- ============================================================================
-- STEP 5: CREATE POLICIES FOR EWASTE_ITEMS
-- ============================================================================
CREATE POLICY "Admins can view all ewaste items" ON ewaste_items
  FOR SELECT
  USING (check_is_admin());

CREATE POLICY "Admins can update all ewaste items" ON ewaste_items
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

CREATE POLICY "Admins can delete all ewaste items" ON ewaste_items
  FOR DELETE
  USING (check_is_admin());

-- ============================================================================
-- STEP 6: CREATE POLICIES FOR PLASTIC_ITEMS
-- ============================================================================
CREATE POLICY "Admins can view all plastic items" ON plastic_items
  FOR SELECT
  USING (check_is_admin());

CREATE POLICY "Admins can update all plastic items" ON plastic_items
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- ============================================================================
-- STEP 7: CREATE POLICIES FOR CLOTH_DONATIONS
-- ============================================================================
CREATE POLICY "Admins can view all cloth donations" ON cloth_donations
  FOR SELECT
  USING (check_is_admin());

CREATE POLICY "Admins can update all cloth donations" ON cloth_donations
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- ============================================================================
-- STEP 8: CREATE POLICIES FOR PROFILES
-- ============================================================================
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT
  USING ((SELECT auth.uid()) = id);

CREATE POLICY "Admins can view all profiles" ON profiles
  FOR SELECT
  USING (check_is_admin());

-- ============================================================================
-- STEP 9: CREATE POLICIES FOR VOLUNTEER_SCHEDULES
-- ============================================================================
CREATE POLICY "Admins can view all schedules" ON volunteer_schedules
  FOR SELECT
  USING (check_is_admin());

-- ============================================================================
-- STEP 10: CREATE POLICIES FOR FEEDBACK
-- ============================================================================
CREATE POLICY "Admins can view all feedback" ON feedback
  FOR SELECT
  USING (check_is_admin());

CREATE POLICY "Admins can delete feedback" ON feedback
  FOR DELETE
  USING (check_is_admin());

-- ============================================================================
-- STEP 11: VERIFICATION QUERIES
-- ============================================================================

-- Check that admin users exist
SELECT id, full_name, user_role FROM public.profiles WHERE user_role = 'admin';

-- Check RLS is enabled on all tables
SELECT tablename FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('volunteer_applications', 'ewaste_items', 'plastic_items', 'cloth_donations', 'profiles', 'volunteer_schedules', 'feedback')
ORDER BY tablename;

-- Check policies exist
SELECT tablename, policyname
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('volunteer_applications', 'ewaste_items', 'plastic_items', 'cloth_donations', 'profiles', 'volunteer_schedules', 'feedback')
ORDER BY tablename, policyname;

-- Test data counts (run as admin user)
SELECT 'volunteer_applications' as table_name, COUNT(*) as count FROM volunteer_applications
UNION ALL
SELECT 'ewaste_items', COUNT(*) FROM ewaste_items
UNION ALL
SELECT 'plastic_items', COUNT(*) FROM plastic_items
UNION ALL
SELECT 'cloth_donations', COUNT(*) FROM cloth_donations
UNION ALL
SELECT 'volunteer_schedules', COUNT(*) FROM volunteer_schedules
UNION ALL
SELECT 'feedback', COUNT(*) FROM feedback;

-- ============================================================================
-- IMPLEMENTATION NOTES
-- ============================================================================
/*
✅ WHAT THIS FIX DOES:

1. Creates check_is_admin() function to verify admin role
2. Enables RLS on all required tables
3. Creates admin access policies for all tables
4. Allows admins to view/manage all data
5. Maintains user privacy (users can only see their own data)

✅ WHAT TO DO AFTER RUNNING THIS SQL:

1. Run this SQL in Supabase SQL Editor
2. Click "Run" button
3. Verify no errors in output
4. Restart Flutter app (hot restart or rebuild)
5. Log in as admin user
6. Check Admin Dashboard:
   - Dispatch tab should show pending requests ✅
   - Volunteers tab should show applications ✅
   - All tabs should display data ✅

✅ IF STILL NOT WORKING:

1. Verify admin user exists:
   SELECT * FROM profiles WHERE user_role = 'admin';

2. If no admin user, create one:
   UPDATE profiles SET user_role = 'admin' WHERE email = 'your-admin-email@example.com';

3. Test function works:
   SELECT check_is_admin(); -- Should return TRUE for admin user

4. Check RLS policies:
   SELECT * FROM pg_policies WHERE schemaname = 'public';

5. Clear app cache and rebuild:
   flutter clean && flutter pub get && flutter run

✅ EXPECTED RESULTS AFTER FIX:

Admin Dashboard should now show:
- Dispatch Management: All pending waste requests (e-waste, plastic, cloth donations)
- Volunteer Applications: All pending applications
- User Management: All user profiles
- NGO Management: All NGOs
- Feedback: All feedback items
- Schedules: All volunteer schedules

*/
