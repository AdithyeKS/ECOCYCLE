-- ============================================================================
-- COMPLETE DATA FETCHING FIX FOR ECOCYCLE ADMIN DASHBOARD
-- ============================================================================
-- Issue: Admin dashboard showing 0 items for E-waste, Plastic, and Cloth items
-- Root Cause: Missing RLS policies for admin access to waste item tables
-- Solution: Enable RLS and create admin access policies for all waste tables
-- ============================================================================

-- ============================================================================
-- STEP 1: ENSURE check_is_admin() FUNCTION EXISTS
-- ============================================================================
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
-- STEP 2: ENABLE RLS ON ALL WASTE ITEM TABLES
-- ============================================================================
ALTER TABLE public.ewaste_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plastic_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cloth_donations ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 3: DROP EXISTING POLICIES (IF ANY) TO AVOID CONFLICTS
-- ============================================================================
-- E-waste items policies
DROP POLICY IF EXISTS "ewaste_items_admin_select" ON public.ewaste_items;
DROP POLICY IF EXISTS "ewaste_items_admin_update" ON public.ewaste_items;
DROP POLICY IF EXISTS "ewaste_items_user_select" ON public.ewaste_items;
DROP POLICY IF EXISTS "ewaste_items_user_insert" ON public.ewaste_items;
DROP POLICY IF EXISTS "ewaste_items_user_update" ON public.ewaste_items;

-- Plastic items policies
DROP POLICY IF EXISTS "plastic_items_admin_select" ON public.plastic_items;
DROP POLICY IF EXISTS "plastic_items_admin_update" ON public.plastic_items;
DROP POLICY IF EXISTS "plastic_items_user_select" ON public.plastic_items;
DROP POLICY IF EXISTS "plastic_items_user_insert" ON public.plastic_items;

-- Cloth donations policies
DROP POLICY IF EXISTS "cloth_donations_admin_select" ON public.cloth_donations;
DROP POLICY IF EXISTS "cloth_donations_admin_update" ON public.cloth_donations;
DROP POLICY IF EXISTS "cloth_donations_user_select" ON public.cloth_donations;
DROP POLICY IF EXISTS "cloth_donations_user_insert" ON public.cloth_donations;

-- ============================================================================
-- STEP 4: CREATE NEW POLICIES FOR EWASTE_ITEMS TABLE
-- ============================================================================
-- Policy 1: Admin can SELECT all e-waste items
CREATE POLICY "ewaste_items_admin_select"
  ON public.ewaste_items
  FOR SELECT
  USING (check_is_admin());

-- Policy 2: Admin can UPDATE all e-waste items
CREATE POLICY "ewaste_items_admin_update"
  ON public.ewaste_items
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- Policy 3: Users can SELECT their own e-waste items
CREATE POLICY "ewaste_items_user_select"
  ON public.ewaste_items
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy 4: Users can INSERT their own e-waste items
CREATE POLICY "ewaste_items_user_insert"
  ON public.ewaste_items
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy 5: Users can UPDATE their own e-waste items (limited)
CREATE POLICY "ewaste_items_user_update"
  ON public.ewaste_items
  FOR UPDATE
  USING (auth.uid() = user_id);

-- ============================================================================
-- STEP 5: CREATE NEW POLICIES FOR PLASTIC_ITEMS TABLE
-- ============================================================================
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
-- STEP 6: CREATE NEW POLICIES FOR CLOTH_DONATIONS TABLE
-- ============================================================================
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
-- STEP 7: VERIFICATION QUERIES
-- ============================================================================

-- Check if admin user exists
-- SELECT id, email, full_name, user_role FROM public.profiles WHERE user_role = 'admin' LIMIT 5;

-- Check RLS is enabled on all tables
-- SELECT tablename FROM pg_tables
-- WHERE schemaname = 'public'
-- AND tablename IN ('ewaste_items', 'plastic_items', 'cloth_donations')
-- ORDER BY tablename;

-- Check policies exist
-- SELECT tablename, policyname
-- FROM pg_policies
-- WHERE schemaname = 'public'
-- AND tablename IN ('ewaste_items', 'plastic_items', 'cloth_donations')
-- ORDER BY tablename, policyname;

-- Test admin access (run as admin user)
-- SELECT COUNT(*) as ewaste_count FROM ewaste_items;
-- SELECT COUNT(*) as plastic_count FROM plastic_items;
-- SELECT COUNT(*) as cloth_count FROM cloth_donations;

-- ============================================================================
-- IMPLEMENTATION NOTES
-- ============================================================================
/*
✅ WHAT THIS FIX DOES:

1. Creates/Ensures check_is_admin() function exists
   - This function checks if current user has admin role
   - Used by all RLS policies to grant admin access

2. Enables RLS on all three waste item tables
   - ewaste_items, plastic_items, cloth_donations

3. Creates admin access policies for all tables
   - Admins can SELECT all waste items
   - Admins can UPDATE all waste items
   - Users can only see/edit their own items

4. Enables admin dashboard to fetch data
   - Admin dashboard dispatch tab can now fetch all waste types
   - E-waste, plastic, and cloth items visible in dispatch tab

✅ WHAT TO DO AFTER RUNNING THIS SQL:

1. Run this SQL in Supabase SQL Editor
2. Reload the Flutter app (hot reload or hot restart)
3. Log in as admin user
4. Go to Admin Dashboard → Dispatch tab
5. Verify you can see:
   - E-waste items ✅ (NOW FIXED)
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
SELECT * FROM ewaste_items LIMIT 5;
SELECT * FROM plastic_items LIMIT 5;
SELECT * FROM cloth_donations LIMIT 5;
```

*/
