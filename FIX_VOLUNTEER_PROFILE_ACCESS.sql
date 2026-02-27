-- ============================================================================
-- FIX: Allow volunteers to read profiles of users whose items they are assigned to
-- Run this in the Supabase SQL Editor
-- ============================================================================

-- Drop if exists for idempotency
DROP POLICY IF EXISTS "Volunteers can view assigned user profiles" ON profiles;

-- Allow volunteers to view profiles of users whose e-waste items are assigned to them
CREATE POLICY "Volunteers can view assigned user profiles"
ON profiles FOR SELECT
USING (
  -- Users can always see their own profile
  id = auth.uid()
  -- Volunteers can see profiles of users whose items they are picking up
  OR id IN (
    SELECT user_id FROM ewaste_items
    WHERE assigned_agent_id = auth.uid()
  )
  -- Admins can see all profiles
  OR public.check_is_admin()
);

-- Verify
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY policyname;
