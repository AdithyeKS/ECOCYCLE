-- ============================================================================
-- ADMIN SETUP FIX - Ensures volunteer applications are visible to admins
-- ============================================================================
-- This script fixes the issue where volunteer applications are not visible
-- in the admin dashboard. The problem is that:
-- 1. RLS policies filter data based on user_role
-- 2. Admin users need user_role = 'admin' in their profile
-- 3. The check_is_admin() function verifies this role

-- ============================================================================
-- STEP 1: VERIFY check_is_admin() FUNCTION EXISTS AND IS CORRECT
-- ============================================================================

-- The check_is_admin() function should already exist from supabase_schema_fixed.sql
-- If not, it needs to be created with SECURITY DEFINER and row_security = OFF
-- to bypass RLS and check the admin status directly

-- To test if check_is_admin() works, run:
-- SELECT check_is_admin();
-- This should return true if the current user is an admin

-- ============================================================================
-- STEP 2: ENSURE YOUR ADMIN USER HAS user_role = 'admin'
-- ============================================================================

-- Find your admin user's UUID:
SELECT id, full_name, user_role FROM public.profiles 
WHERE user_role = 'admin' 
LIMIT 5;

-- If your admin user is NOT showing above, update their role:
-- Replace 'your-user-email@example.com' with the actual email
UPDATE public.profiles 
SET user_role = 'admin'
WHERE id = (
  SELECT id FROM auth.users 
  WHERE email = 'your-user-email@example.com'
);

-- ============================================================================
-- STEP 3: VERIFY RLS POLICIES ARE CORRECT
-- ============================================================================

-- Check that volunteer_applications table has RLS enabled:
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'volunteer_applications' 
AND schemaname = 'public';

-- Should return: volunteer_applications | true

-- List all policies on volunteer_applications:
SELECT policyname, qual, with_check 
FROM pg_policies 
WHERE tablename = 'volunteer_applications';

-- You should see:
-- - Users can view own applications
-- - Users can insert own applications  
-- - Users can update own applications
-- - Admins can view all applications
-- - Admins can insert applications
-- - Admins can update applications
-- - Admins can delete applications

-- ============================================================================
-- STEP 4: TEST ADMIN ACCESS
-- ============================================================================

-- As an authenticated user with admin role, run:
SELECT COUNT(*) as application_count FROM public.volunteer_applications;

-- If this returns 0, either:
-- 1. There are no volunteer applications in the database
-- 2. The user's role is not 'admin'
-- 3. The RLS policies are blocking access

-- To verify the user is admin:
SELECT check_is_admin();
-- Should return: true (if user is admin)

-- ============================================================================
-- STEP 5: VERIFY VOLUNTEER_APPLICATIONS TABLE EXISTS
-- ============================================================================

-- Check if the volunteer_applications table exists:
SELECT EXISTS (
  SELECT 1 FROM information_schema.tables 
  WHERE table_name = 'volunteer_applications'
) as table_exists;

-- Should return: true

-- Check the table structure:
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'volunteer_applications' 
ORDER BY ordinal_position;

-- Should have columns: id, user_id, full_name, email, phone, address, 
-- available_date, motivation, agreed_to_policy, status, created_at, updated_at

-- ============================================================================
-- TROUBLESHOOTING
-- ============================================================================

-- If volunteer applications still don't show in admin dashboard:
-- 1. Check the browser console for JavaScript errors
-- 2. Check the Flutter debug console for Dart/Supabase errors
-- 3. Verify the admin's user_role is actually 'admin':
SELECT full_name, user_role FROM public.profiles 
WHERE id = auth.uid();

-- 4. Check if there are any volunteer applications in the database:
SELECT COUNT(*) as total_applications FROM public.volunteer_applications;

-- 5. Try fetching as admin with RLS disabled (for debugging only):
SET row_security = off;
SELECT COUNT(*) as applications_without_rls FROM public.volunteer_applications;
SET row_security = on;

-- ============================================================================
-- END OF ADMIN SETUP FIX
-- ============================================================================
