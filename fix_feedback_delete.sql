-- Fix for feedback delete issue in admin page
-- The check_is_admin function needs to check the profiles table for user_role = 'admin'
-- instead of the admin_roles table

-- Drop the old function if it exists
DROP FUNCTION IF EXISTS public.check_is_admin() CASCADE;

-- Create the correct function that checks profiles table
CREATE OR REPLACE FUNCTION public.check_is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_role TEXT;
BEGIN
  -- Get user role from profiles table
  SELECT user_role INTO user_role
  FROM profiles
  WHERE id = auth.uid();

  -- Return true if user is admin
  RETURN user_role = 'admin';
END;
$$;

-- Set ownership and permissions
ALTER FUNCTION public.check_is_admin() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.check_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_is_admin() TO postgres, authenticated;

-- Verify the admin user has user_role = 'admin' in profiles table
-- If not, update it (replace 'your-admin-user-id' with actual user ID)
-- UPDATE profiles SET user_role = 'admin' WHERE id = 'your-admin-user-id';

-- Test the function
-- SELECT check_is_admin(); -- Should return true for admin users
