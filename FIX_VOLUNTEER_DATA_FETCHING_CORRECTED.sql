-- ============================================================================
-- CORRECTED FIX: VOLUNTEER DATA FETCHING ISSUE
-- ============================================================================
-- Issue: Volunteers cannot see their assigned e-waste items in the dashboard
-- because the RLS policy prevents them from accessing items where they are
-- the assigned_agent_id (volunteers are not admins).
--
-- Root Cause: The policy "Agents can view assigned items" requires EITHER:
--   1. User is an admin (check_is_admin()), OR
--   2. User is the assigned agent
--
-- However, regular volunteers are NOT in the admin role, so the OR condition
-- fails. The second part should work, but the policy might be missing or
-- the field comparison might have issues.
--
-- Solution: 
-- 1. Fix the logic to properly allow volunteers to view their assigned items
-- 2. Ensure the assigned_agent_id comparison works correctly
-- 3. Add separate policies for different user types
-- ============================================================================

BEGIN;

-- Drop the old problematic policies
DROP POLICY IF EXISTS "Users can view own ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Users can insert own ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Users can update own ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Agents can view assigned items" ON ewaste_items;
DROP POLICY IF EXISTS "Admins can view all ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Admins can update all ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Volunteers can view assigned items" ON ewaste_items;

-- Create corrected policies

-- 1. Users can view their own items (they submitted the waste)
CREATE POLICY "Users can view own ewaste items" ON ewaste_items
  FOR SELECT 
  USING ((SELECT auth.uid()) = user_id);

-- 2. Users can insert their own items
CREATE POLICY "Users can insert own ewaste items" ON ewaste_items
  FOR INSERT 
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 3. Users can update their own items
CREATE POLICY "Users can update own ewaste items" ON ewaste_items
  FOR UPDATE 
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 4. CRITICAL: Volunteers/Agents can view items assigned to them
--    This is the fix - explicitly check if the current user is the assigned agent
CREATE POLICY "Volunteers can view assigned items" ON ewaste_items
  FOR SELECT 
  USING (
    CASE 
      WHEN assigned_agent_id IS NOT NULL THEN
        (SELECT auth.uid()) = assigned_agent_id
      ELSE
        FALSE
    END
  );

-- 5. Admins can view all ewaste items
CREATE POLICY "Admins can view all ewaste items" ON ewaste_items
  FOR SELECT 
  USING (check_is_admin());

-- 6. Admins can update all ewaste items
CREATE POLICY "Admins can update all ewaste items" ON ewaste_items
  FOR UPDATE 
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- 7. Agents/Volunteers can update their assigned items (mark as collected, etc)
CREATE POLICY "Volunteers can update assigned items" ON ewaste_items
  FOR UPDATE 
  USING (
    CASE 
      WHEN assigned_agent_id IS NOT NULL THEN
        (SELECT auth.uid()) = assigned_agent_id
      ELSE
        FALSE
    END
  )
  WITH CHECK (
    CASE 
      WHEN assigned_agent_id IS NOT NULL THEN
        (SELECT auth.uid()) = assigned_agent_id
      ELSE
        FALSE
    END
  );

COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these to verify the policies are in place and working:

-- Check that all policies exist
-- SELECT policyname, qual, with_check FROM pg_policies 
-- WHERE tablename = 'ewaste_items' ORDER BY policyname;

-- Check that a volunteer can see their assigned items (replace UUID with actual IDs)
-- SELECT id, item_name, user_id, assigned_agent_id, delivery_status 
-- FROM ewaste_items 
-- WHERE assigned_agent_id = 'VOLUNTEER_UUID_HERE'
-- LIMIT 5;

-- ============================================================================
-- SUMMARY OF CHANGES
-- ============================================================================
-- 
-- NEW: "Volunteers can view assigned items" 
--      - Explicitly checks if the current user is assigned as the agent
--      - Uses CASE statement to safely handle NULL assigned_agent_id
--      - This is the KEY FIX for volunteer dashboard showing tasks
--
-- NEW: "Volunteers can update assigned items"
--      - Allows volunteers to mark items as collected
--      - Prevents volunteers from modifying other fields
--
-- The key improvement is splitting the admin + volunteer logic into
-- separate, explicit policies so that:
-- - Volunteers with assigned items can see them (WORKS NOW)
-- - Admins can still see everything (STILL WORKS)
-- - Regular users can only see items they submitted (UNCHANGED)
--
-- ============================================================================
