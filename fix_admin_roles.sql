-- Fix admin roles setup for volunteer application approval
BEGIN;

-- Ensure admin_roles table exists
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

-- Populate admin_roles with users who have admin role in profiles
INSERT INTO public.admin_roles(user_id, role)
SELECT DISTINCT p.id, 'admin'
FROM profiles p
WHERE p.user_role = 'admin'
  AND p.id NOT IN (SELECT user_id FROM public.admin_roles)
ON CONFLICT (user_id) DO NOTHING;

-- Ensure check_is_admin function exists and works
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

-- Ensure volunteer_applications has proper RLS policies
DROP POLICY IF EXISTS "Admins can update applications" ON volunteer_applications;
CREATE POLICY "Admins can update applications" ON volunteer_applications
  FOR UPDATE USING (check_is_admin())
  WITH CHECK (check_is_admin());

COMMIT;
