-- FIX USER DELETE POLICY - ADMIN DASHBOARD DELETE BUTTON FIX
-- This SQL fixes the issue where the delete button in user management
-- is not working due to Row Level Security (RLS) policies.
-- The admin dashboard tries to delete users from the profiles table,
-- but the RLS policy may not be allowing it.

-- STEP 1: ENSURE check_is_admin() FUNCTION EXISTS AND WORKS
-- Drop and recreate the function to ensure it's correct
DROP FUNCTION IF EXISTS public.check_is_admin() CASCADE;

CREATE FUNCTION public.check_is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS(
    SELECT 1 FROM admin_roles
    WHERE user_id = auth.uid()
  );
$$;

-- STEP 2: ENSURE admin_roles TABLE EXISTS AND HAS ADMINS
-- Create admin_roles table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.admin_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'admin' CHECK (role IN ('admin', 'super_admin')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  created_by UUID REFERENCES auth.users(id),
  CONSTRAINT admin_roles_unique UNIQUE (user_id)
);

-- Disable RLS on admin_roles (system table)
ALTER TABLE public.admin_roles DISABLE ROW LEVEL SECURITY;

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_admin_roles_user_id ON public.admin_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_roles_role ON public.admin_roles(role);

-- Populate admin_roles from existing admin profiles
INSERT INTO public.admin_roles(user_id, role)
SELECT DISTINCT p.id, 'admin'
FROM public.profiles p
WHERE p.user_role = 'admin'
  AND p.id NOT IN (SELECT user_id FROM public.admin_roles)
ON CONFLICT (user_id) DO NOTHING;

-- ============================================================================
-- STEP 3: ENABLE RLS ON profiles TABLE AND FIX DELETE POLICY
-- ============================================================================
-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing delete policy if it exists
DROP POLICY IF EXISTS "profiles_delete_admin" ON public.profiles;

-- Create the correct delete policy for admins
CREATE POLICY "profiles_delete_admin" ON public.profiles
  FOR DELETE
  USING (check_is_admin());

-- STEP 4: VERIFY THE FIX
-- Check if RLS is enabled on profiles
-- SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'profiles';

-- Check if the delete policy exists
-- SELECT policyname, cmd, qual FROM pg_policies WHERE tablename = 'profiles' AND cmd = 'DELETE';

-- Check if admin_roles has admins
-- SELECT COUNT(*) as admin_count FROM admin_roles;

-- Test the function (run as admin user)
-- SELECT check_is_admin();

-- DEPLOYMENT INSTRUCTIONS
/*
1. Run this SQL in your Supabase SQL Editor
2. Verify no errors occur
3. Check that admin_roles table has your admin users
4. Test the delete button in the admin dashboard

WHAT THIS FIXES:
✅ Ensures check_is_admin() function works correctly
✅ Populates admin_roles table with existing admins
✅ Creates proper RLS delete policy for profiles table
✅ Allows admins to delete user profiles

AFTER DEPLOYMENT:
1. Open Flutter app
2. Login as admin
3. Go to Users tab in admin dashboard
4. Try deleting a user - should work now

If still not working:
1. Check browser console for RLS errors
2. Verify admin user is in admin_roles table
3. Run: SELECT check_is_admin(); as admin user (should return true)
4. Check Supabase logs for policy violations
*/
