-- ============================================================================
-- FIX: BREAK RLS RECURSION LOOP
-- Run this in the Supabase SQL Editor
-- ============================================================================
 1. Create SECURITY DEFINER functions to break recursion
-- These functions bypass RLS and allow checking related data safely

-- Helper to check user role without triggering Profiles RLS
CREATE OR REPLACE FUNCTION public.check_user_role_simple(user_id UUID, required_roles TEXT[])
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER -- Runs as owner, bypasses RLS
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = user_id
    AND user_role = ANY(required_roles)
  );
END;
$$;

-- Helper to check assignment without triggering Ewaste_items RLS
CREATE OR REPLACE FUNCTION public.is_volunteer_for_user(volunteer_id UUID, target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER -- Runs as owner, bypasses RLS
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM ewaste_items
    WHERE assigned_agent_id = volunteer_id
    AND user_id = target_user_id
  );
END;
$$;

-- 2. Update EWASTE_ITEMS RLS to use the new role check
DROP POLICY IF EXISTS "Volunteers can view assigned items" ON ewaste_items;
DROP POLICY IF EXISTS "Volunteers can update assigned items" ON ewaste_items;

CREATE POLICY "Volunteers can view assigned items"
ON ewaste_items FOR SELECT
USING (
  assigned_agent_id = auth.uid()
  OR user_id = auth.uid()
  OR public.check_is_admin()
  OR public.check_user_role_simple(auth.uid(), ARRAY['admin', 'ngo'])
);

CREATE POLICY "Volunteers can update assigned items"
ON ewaste_items FOR UPDATE
USING (
  assigned_agent_id = auth.uid()
  OR user_id = auth.uid()
  OR public.check_is_admin()
  OR public.check_user_role_simple(auth.uid(), ARRAY['admin', 'ngo'])
);

-- 3. Update PROFILES RLS to use the new assignment check
DROP POLICY IF EXISTS "Volunteers can view assigned user profiles" ON profiles;

CREATE POLICY "Volunteers can view assigned user profiles"
ON profiles FOR SELECT
USING (
  id = auth.uid()
  OR public.check_is_admin()
  OR public.is_volunteer_for_user(auth.uid(), id)
);

-- 4. VERIFY
SELECT policyname, tablename, cmd, qual
FROM pg_policies
WHERE tablename IN ('ewaste_items', 'profiles')
ORDER BY tablename, policyname;
