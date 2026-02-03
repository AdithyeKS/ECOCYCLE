-- ============================================================================
-- FIX: DISPATCH MANAGEMENT NOT FETCHING DATA - RLS POLICIES FOR PLASTIC & CLOTH
-- ============================================================================
-- Issue: Admin dispatch management tab showing no data for plastic and cloth items
-- Root Cause: Missing RLS policies for plastic_items and cloth_donations tables
-- Solution: Add admin access policies for these tables
-- ============================================================================

-- ============================================================================
-- STEP 1: ENSURE check_is_admin() FUNCTION EXISTS
-- ============================================================================
-- This function is required by all the RLS policies below
CREATE OR REPLACE FUNCTION check_is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
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

-- ============================================================================
-- STEP 2: ENABLE RLS ON PLASTIC_ITEMS TABLE
-- ============================================================================
ALTER TABLE public.plastic_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "plastic_items_admin_select" ON public.plastic_items;
DROP POLICY IF EXISTS "plastic_items_admin_update" ON public.plastic_items;
DROP POLICY IF EXISTS "plastic_items_user_select" ON public.plastic_items;
DROP POLICY IF EXISTS "plastic_items_user_insert" ON public.plastic_items;
DROP POLICY IF EXISTS "Admins can view all plastic items" ON public.plastic_items;
DROP POLICY IF EXISTS "Admins can update all plastic items" ON public.plastic_items;

-- CREATE NEW POLICIES FOR plastic_items
-- Policy 1: Admin can SELECT all plastic items
CREATE POLICY "plastic_items_admin_select"
  ON public.plastic_items
  FOR SELECT
  USING (check_is_admin());

-- Policy 2: Admin can UPDATE all plastic items
CREATE POLICY "plastic_items_admin_update"
  ON public.plastic_items
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- Policy 3: Users can SELECT their own plastic items
CREATE POLICY "plastic_items_user_select"
  ON public.plastic_items
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy 4: Users can INSERT their own plastic items
CREATE POLICY "plastic_items_user_insert"
  ON public.plastic_items
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- STEP 3: ENABLE RLS ON CLOTH_DONATIONS TABLE
-- ============================================================================
ALTER TABLE public.cloth_donations ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "cloth_donations_admin_select" ON public.cloth_donations;
DROP POLICY IF EXISTS "cloth_donations_admin_update" ON public.cloth_donations;
DROP POLICY IF EXISTS "cloth_donations_user_select" ON public.cloth_donations;
DROP POLICY IF EXISTS "cloth_donations_user_insert" ON public.cloth_donations;
DROP POLICY IF EXISTS "Admins can view all cloth donations" ON public.cloth_donations;
DROP POLICY IF EXISTS "Admins can update all cloth donations" ON public.cloth_donations;

-- CREATE NEW POLICIES FOR cloth_donations
-- Policy 1: Admin can SELECT all cloth donations
CREATE POLICY "cloth_donations_admin_select"
  ON public.cloth_donations
  FOR SELECT
  USING (check_is_admin());

-- Policy 2: Admin can UPDATE all cloth donations
CREATE POLICY "cloth_donations_admin_update"
  ON public.cloth_donations
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- Policy 3: Users can SELECT their own cloth donations
CREATE POLICY "cloth_donations_user_select"
  ON public.cloth_donations
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy 4: Users can INSERT their own cloth donations
CREATE POLICY "cloth_donations_user_insert"
  ON public.cloth_donations
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- STEP 4: VERIFY SETUP
-- ============================================================================

-- Verify check_is_admin() function exists
-- SELECT routine_name FROM information_schema.routines WHERE routine_name = 'check_is_admin';

-- Verify RLS is enabled on tables
-- SELECT tablename FROM pg_tables 
-- WHERE schemaname = 'public' 
-- AND tablename IN ('plastic_items', 'cloth_donations')
-- ORDER BY tablename;

-- Verify policies exist
-- SELECT tablename, policyname 
-- FROM pg_policies 
-- WHERE schemaname = 'public' 
-- AND tablename IN ('plastic_items', 'cloth_donations')
-- ORDER BY tablename, policyname;

-- Verify admin user exists
-- SELECT id, full_name, user_role FROM public.profiles WHERE user_role = 'admin' LIMIT 5;

-- ============================================================================
-- IMPLEMENTATION NOTES
-- ============================================================================
/*
✅ WHAT THIS FIX DOES:

1. Creates/Ensures check_is_admin() function exists
   - This function checks if current user has admin role
   - Used by all RLS policies to grant admin access

2. Enables RLS on plastic_items table
   - Admins can SELECT all plastic items
   - Admins can UPDATE all plastic items
   - Users can only see/edit their own items

3. Enables RLS on cloth_donations table
   - Admins can SELECT all cloth donations
   - Admins can UPDATE all cloth donations
   - Users can only see/edit their own items

4. Enables dispatch management to fetch data
   - Admin dashboard dispatch tab can now fetch plastic and cloth items
   - All waste types (e-waste, plastic, cloth) visible in dispatch tab

✅ WHAT TO DO AFTER RUNNING THIS SQL:

1. Run this SQL in Supabase SQL Editor
2. Reload the Flutter app (hot reload or hot restart)
3. Log in as admin user
4. Go to Admin Dashboard → Dispatch tab
5. Verify you can see:
   - E-waste items ✅
   - Plastic items ✅ (NOW FIXED)
   - Cloth items ✅ (NOW FIXED)

✅ IF STILL NOT WORKING:

Check that:
1. At least ONE user has user_role = 'admin' in profiles table
2. The check_is_admin() function returns TRUE for admin user
3. RLS is enabled on all three tables: ewaste_items, plastic_items, cloth_donations
4. All policies use check_is_admin() correctly
5. No other conflicting policies exist

Test with SQL:
```
-- As admin user, this should return items:
SELECT * FROM plastic_items LIMIT 5;
SELECT * FROM cloth_donations LIMIT 5;
```

*/
