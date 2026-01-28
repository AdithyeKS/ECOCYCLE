-- Comprehensive fix for admin data access issues
BEGIN;

-- 1. Ensure admin_roles table exists and is properly configured
CREATE TABLE IF NOT EXISTS public.admin_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'admin',
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT admin_roles_unique UNIQUE (user_id)
);

-- Disable RLS on admin_roles (system table)
ALTER TABLE public.admin_roles DISABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_admin_roles_user_id ON public.admin_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_roles_role ON public.admin_roles(role);

-- 2. Populate admin_roles with users who have admin role in profiles
INSERT INTO public.admin_roles(user_id, role)
SELECT DISTINCT p.id, 'admin'
FROM profiles p
WHERE p.user_role = 'admin'
  AND p.id NOT IN (SELECT user_id FROM public.admin_roles)
ON CONFLICT (user_id) DO NOTHING;

-- 3. Ensure check_is_admin function exists and works
DROP FUNCTION IF EXISTS public.check_is_admin() CASCADE;
CREATE OR REPLACE FUNCTION public.check_is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = OFF
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.admin_roles
    WHERE user_id = auth.uid()
  );
END;
$$;

ALTER FUNCTION public.check_is_admin() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.check_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_is_admin() TO postgres, authenticated;

-- 4. Ensure all necessary tables have proper RLS policies for admin access

-- Volunteer applications
DROP POLICY IF EXISTS "Admins can view all applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can update applications" ON volunteer_applications;
CREATE POLICY "Admins can view all applications" ON volunteer_applications
  FOR SELECT USING (check_is_admin());
CREATE POLICY "Admins can update applications" ON volunteer_applications
  FOR UPDATE USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- E-waste items
DROP POLICY IF EXISTS "Admins can view all ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Admins can update all ewaste items" ON ewaste_items;
CREATE POLICY "Admins can view all ewaste items" ON ewaste_items
  FOR SELECT USING (check_is_admin());
CREATE POLICY "Admins can update all ewaste items" ON ewaste_items
  FOR UPDATE USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- Volunteer schedules
DROP POLICY IF EXISTS "volunteer_schedules_admin_view" ON volunteer_schedules;
CREATE POLICY "volunteer_schedules_admin_view" ON volunteer_schedules
  FOR SELECT USING (check_is_admin());

-- Feedback
DROP POLICY IF EXISTS "feedback_admin_view" ON feedback;
DROP POLICY IF EXISTS "feedback_admin_update" ON feedback;
CREATE POLICY "feedback_admin_view" ON feedback
  FOR SELECT USING (check_is_admin());
CREATE POLICY "feedback_admin_update" ON feedback
  FOR UPDATE USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- Pickup agents (volunteers)
DROP POLICY IF EXISTS "pickup_requests_admin_view" ON pickup_requests;
DROP POLICY IF EXISTS "pickup_requests_admin_manage" ON pickup_requests;
CREATE POLICY "pickup_requests_admin_view" ON pickup_requests
  FOR SELECT USING (check_is_admin());
CREATE POLICY "pickup_requests_admin_manage" ON pickup_requests
  FOR ALL USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- NGOs
DROP POLICY IF EXISTS "ngos_admin_view" ON ngos;
DROP POLICY IF EXISTS "ngos_admin_manage" ON ngos;
CREATE POLICY "ngos_admin_view" ON ngos
  FOR SELECT USING (check_is_admin());
CREATE POLICY "ngos_admin_manage" ON ngos
  FOR ALL USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- Profiles (admin view)
DROP POLICY IF EXISTS "profiles_admin_view" ON profiles;
DROP POLICY IF EXISTS "profiles_admin_update" ON profiles;
CREATE POLICY "profiles_admin_view" ON profiles
  FOR SELECT USING (check_is_admin());
CREATE POLICY "profiles_admin_update" ON profiles
  FOR UPDATE USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- 5. Ensure admin_user_details view exists and is accessible
CREATE OR REPLACE VIEW public.admin_user_details AS
SELECT
  p.id,
  p.full_name,
  p.phone_number,
  p.address,
  p.total_points,
  p.user_role,
  p.supervisor_id,
  p.volunteer_requested_at,
  p.created_at,
  p.updated_at,
  au.email
FROM public.profiles p
LEFT JOIN auth.users au ON p.id = au.id
ORDER BY p.full_name;

GRANT SELECT ON public.admin_user_details TO authenticated;

COMMIT;
