-- QUICK FIX REFERENCE: Data Persistence Issues
-- This script highlights the most critical RLS policy changes

-- ============================================================================
-- CRITICAL FIX #1: Add INSERT Permission for Profiles
-- ============================================================================
-- This was missing and causing upsert operations to fail silently

DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = id);

-- ============================================================================
-- CRITICAL FIX #2: Add WITH CHECK Clause for Updates
-- ============================================================================
-- This ensures both read and write conditions are checked

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

-- ============================================================================
-- CRITICAL FIX #3: Fix Data Type Mismatch in user_id
-- ============================================================================
-- Change from TEXT to UUID to prevent silent comparison failures

-- Check current type:
-- SELECT column_name, data_type FROM information_schema.columns 
-- WHERE table_name = 'ewaste_items' AND column_name = 'user_id';

-- If it's TEXT, run this:
BEGIN;
  ALTER TABLE ewaste_items DROP CONSTRAINT IF EXISTS ewaste_items_user_id_fkey;
  ALTER TABLE ewaste_items ALTER COLUMN user_id TYPE UUID USING user_id::UUID;
  ALTER TABLE ewaste_items ADD CONSTRAINT ewaste_items_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
COMMIT;

-- ============================================================================
-- CRITICAL FIX #4: Fix assigned_agent_id Type
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
-- CRITICAL FIX #5: Add Supervisor Support
-- ============================================================================
-- This allows fetching supervisor info for volunteer requests

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS supervisor_id UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- Test query to verify supervisor info can be fetched:
-- SELECT p.full_name, p.phone_number, s.full_name as supervisor_name, s.phone_number as supervisor_phone
-- FROM profiles p
-- LEFT JOIN profiles s ON p.supervisor_id = s.id
-- WHERE p.id = 'USER_ID_HERE';

-- ============================================================================
-- CRITICAL FIX #6: Fix Volunteer Applications RLS
-- ============================================================================
-- Ensure users can insert their own applications

DROP POLICY IF EXISTS "Users can insert own applications" ON volunteer_applications;
CREATE POLICY "Users can insert own applications" ON volunteer_applications
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- ============================================================================
-- CRITICAL FIX #7: Fix EWaste Items RLS for User Inserts
-- ============================================================================
-- Users must be able to insert their own items

DROP POLICY IF EXISTS "Users can insert own ewaste items" ON ewaste_items;
CREATE POLICY "Users can insert own ewaste items" ON ewaste_items
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- 1. Check if user can insert profile (RLS verification):
-- SELECT * FROM profiles WHERE id = 'USER_ID' LIMIT 1;

-- 2. Check data types are correct:
-- SELECT table_name, column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name IN ('profiles', 'ewaste_items', 'volunteer_applications')
-- ORDER BY table_name, column_name;

-- 3. Verify RLS is enabled:
-- SELECT schemaname, tablename, rowsecurity 
-- FROM pg_tables 
-- WHERE tablename IN ('profiles', 'ewaste_items', 'volunteer_applications');

-- 4. List all policies on profiles table:
-- SELECT policyname, cmd, QUAL, WITH_CHECK FROM pg_policies 
-- WHERE tablename = 'profiles' ORDER BY policyname;

-- 5. Test supervisor fetch:
-- SELECT p.full_name as user_name, p.phone_number as user_phone,
--        s.full_name as supervisor_name, s.phone_number as supervisor_phone
-- FROM profiles p
-- LEFT JOIN profiles s ON p.supervisor_id = s.id
-- LIMIT 10;
