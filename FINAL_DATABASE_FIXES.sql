-- ============================================================================
-- FINAL DATABASE FIXES FOR ECOCYCLE APP
-- Apply these fixes to resolve data persistence and RLS policy issues
-- Execute in Supabase SQL Editor
-- ============================================================================

-- ============================================================================
-- FIX 1: Add INSERT Permission for Profiles (CRITICAL)
-- ============================================================================
-- This was missing and causing upsert operations to fail silently

DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = id);

-- ============================================================================
-- FIX 2: Add WITH CHECK Clause for Profile Updates
-- ============================================================================
-- This ensures both read and write conditions are checked

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

-- ============================================================================
-- FIX 3: Fix Data Type Mismatch in ewaste_items.user_id
-- ============================================================================
-- Change from TEXT to UUID to prevent silent comparison failures

BEGIN;
  ALTER TABLE ewaste_items DROP CONSTRAINT IF EXISTS ewaste_items_user_id_fkey;
  ALTER TABLE ewaste_items ALTER COLUMN user_id TYPE UUID USING user_id::UUID;
  ALTER TABLE ewaste_items ADD CONSTRAINT ewaste_items_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
COMMIT;

-- ============================================================================
-- FIX 4: Fix assigned_agent_id Type in ewaste_items
-- ============================================================================
-- Should be UUID, not TEXT

BEGIN;
  ALTER TABLE ewaste_items DROP CONSTRAINT IF EXISTS ewaste_items_assigned_agent_id_fkey;
  ALTER TABLE ewaste_items ALTER COLUMN assigned_agent_id TYPE UUID USING
    CASE WHEN assigned_agent_id IS NULL THEN NULL ELSE assigned_agent_id::UUID END;
  ALTER TABLE ewaste_items ADD CONSTRAINT ewaste_items_assigned_agent_id_fkey
    FOREIGN KEY (assigned_agent_id) REFERENCES profiles(id) ON DELETE SET NULL;
COMMIT;

-- ============================================================================
-- FIX 5: Add Supervisor Support
-- ============================================================================
-- This allows fetching supervisor info for volunteer requests

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS supervisor_id UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- ============================================================================
-- FIX 6: Fix Volunteer Applications RLS
-- ============================================================================
-- Ensure users can insert their own applications

DROP POLICY IF EXISTS "Users can insert own applications" ON volunteer_applications;
CREATE POLICY "Users can insert own applications" ON volunteer_applications
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- ============================================================================
-- FIX 7: Fix EWaste Items RLS for User Inserts
-- ============================================================================
-- Users must be able to insert their own items

DROP POLICY IF EXISTS "Users can insert own ewaste items" ON ewaste_items;
CREATE POLICY "Users can insert own ewaste items" ON ewaste_items
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- ============================================================================
-- FIX 8: Add RLS Policies for Cloth Donations
-- ============================================================================

DROP POLICY IF EXISTS "Users can view own cloth donations" ON cloth_donations;
CREATE POLICY "Users can view own cloth donations" ON cloth_donations
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own cloth donations" ON cloth_donations;
CREATE POLICY "Users can insert own cloth donations" ON cloth_donations
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- FIX 9: Add RLS Policies for Plastic Items
-- ============================================================================

DROP POLICY IF EXISTS "Users can view own plastic donations" ON plastic_items;
CREATE POLICY "Users can view own plastic donations" ON plastic_items
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own plastic donations" ON plastic_items;
CREATE POLICY "Users can insert own plastic donations" ON plastic_items
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- FIX 10: Admin Access Policies for Key Tables
-- ============================================================================

-- Volunteer Schedules (Admin only)
DROP POLICY IF EXISTS "Admins can view all schedules" ON volunteer_schedules;
CREATE POLICY "Admins can view all schedules" ON volunteer_schedules
  FOR SELECT TO authenticated
  USING ((SELECT user_role FROM profiles WHERE id = auth.uid()) = 'admin');

-- Volunteer Applications (Admin only)
DROP POLICY IF EXISTS "Admins can view all applications" ON volunteer_applications;
CREATE POLICY "Admins can view all applications" ON volunteer_applications
  FOR SELECT TO authenticated
  USING ((SELECT user_role FROM profiles WHERE id = auth.uid()) = 'admin');

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- 1. Check if user can insert profile (RLS verification):
-- SELECT * FROM profiles WHERE id = 'USER_ID' LIMIT 1;

-- 2. Check data types are correct:
-- SELECT table_name, column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name IN ('profiles', 'ewaste_items', 'volunteer_applications', 'cloth_donations', 'plastic_items')
-- ORDER BY table_name, column_name;

-- 3. Verify RLS is enabled:
-- SELECT schemaname, tablename, rowsecurity
-- FROM pg_tables
-- WHERE tablename IN ('profiles', 'ewaste_items', 'volunteer_applications', 'cloth_donations', 'plastic_items');

-- 4. List all policies on profiles table:
-- SELECT policyname, cmd, QUAL, WITH_CHECK FROM pg_policies
-- WHERE tablename = 'profiles' ORDER BY policyname;

-- ============================================================================
-- SUCCESS INDICATORS
-- ============================================================================

/*
AFTER APPLYING THESE FIXES, YOU SHOULD SEE:

✅ Profile data saves successfully
✅ E-waste items can be inserted
✅ Cloth donations work
✅ Plastic donations work
✅ Volunteer applications can be submitted
✅ Admin can view all data
✅ No RLS permission errors in console
✅ Data persists after page refresh

TEST BY:
1. Creating a new user account
2. Editing profile information
3. Adding e-waste, cloth, and plastic items
4. Checking that data saves and reloads correctly
5. Logging in as admin to verify data access
*/

-- ============================================================================
-- END OF FIXES
-- ============================================================================
