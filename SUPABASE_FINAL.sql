-- ============================================================================
-- ECOCYCLE SUPABASE - ADMIN FIXES & RLS POLICIES (FINAL - ONLY EXISTING TABLES)
-- Paste this entire script into Supabase SQL Editor
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
-- VOLUNTEER_APPLICATIONS POLICIES
-- ============================================================================

DROP POLICY IF EXISTS "Users can view own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Users can insert own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Users can update own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can view all applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can insert applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can update applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can delete applications" ON volunteer_applications;

ALTER TABLE volunteer_applications ENABLE ROW LEVEL SECURITY;

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
-- EWASTE_ITEMS POLICIES
-- ============================================================================

ALTER TABLE ewaste_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view all ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Admins can update all ewaste items" ON ewaste_items;

CREATE POLICY "Admins can view all ewaste items" ON ewaste_items
  FOR SELECT
  USING (check_is_admin());

CREATE POLICY "Admins can update all ewaste items" ON ewaste_items
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- ============================================================================
-- CLOTH_ITEMS POLICIES
-- ============================================================================

ALTER TABLE cloth_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view all cloth items" ON cloth_items;
DROP POLICY IF EXISTS "Admins can update all cloth items" ON cloth_items;

CREATE POLICY "Admins can view all cloth items" ON cloth_items
  FOR SELECT
  USING (check_is_admin());

CREATE POLICY "Admins can update all cloth items" ON cloth_items
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- ============================================================================
-- VERIFY ADMIN USER
-- ============================================================================

SELECT id, full_name, user_role FROM public.profiles WHERE user_role = 'admin' LIMIT 10;
