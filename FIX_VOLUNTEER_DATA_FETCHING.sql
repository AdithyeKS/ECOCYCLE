-- ============================================================================
-- FIX: VOLUNTEER DATA FETCHING ISSUE
-- ============================================================================
-- Issue: When admin assigns a volunteer to an e-waste item, the volunteer
-- cannot see the assigned items in their dashboard because the RLS policy
-- has a type mismatch.
--
-- Root Cause: The RLS policy was casting UUID types to TEXT unnecessarily,
-- causing comparison failures.
--
-- Solution: Fix the RLS policy to correctly compare UUID types without casting.
-- ============================================================================

BEGIN;

-- Drop the old problematic policies
DROP POLICY IF EXISTS "Users can view own ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Users can insert own ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Users can update own ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Agents can view assigned items" ON ewaste_items;
DROP POLICY IF EXISTS "Admins can view all ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Admins can update all ewaste items" ON ewaste_items;

-- Create corrected policies without unnecessary text casting
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
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

COMMIT;

-- ============================================================================
-- VERIFICATION QUERY
-- ============================================================================
-- Run this to verify the policies are in place:
-- SELECT policyname, qual, with_check FROM pg_policies 
-- WHERE tablename = 'ewaste_items' ORDER BY policyname;
