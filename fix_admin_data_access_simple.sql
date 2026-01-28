-- Fixed admin data access - avoid infinite recursion by using admin_user_details view
BEGIN;

-- First, drop existing view if it exists to avoid column name conflicts
DROP VIEW IF EXISTS public.admin_user_details;

-- Create the admin_user_details view
CREATE VIEW public.admin_user_details AS
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

-- Volunteer applications - allow admin users to view and update
DROP POLICY IF EXISTS "Admins can view all applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can update applications" ON volunteer_applications;
CREATE POLICY "Admins can view all applications" ON volunteer_applications
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  );
CREATE POLICY "Admins can update applications" ON volunteer_applications
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  );

-- E-waste items - allow admin users to view and update
DROP POLICY IF EXISTS "Admins can view all ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Admins can update all ewaste items" ON ewaste_items;
CREATE POLICY "Admins can view all ewaste items" ON ewaste_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  );
CREATE POLICY "Admins can update all ewaste items" ON ewaste_items
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  );

-- Volunteer schedules - allow admin users to view
DROP POLICY IF EXISTS "volunteer_schedules_admin_view" ON volunteer_schedules;
CREATE POLICY "volunteer_schedules_admin_view" ON volunteer_schedules
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  );

-- Feedback - allow admin users to view and update
DROP POLICY IF EXISTS "feedback_admin_view" ON feedback;
DROP POLICY IF EXISTS "feedback_admin_update" ON feedback;
CREATE POLICY "feedback_admin_view" ON feedback
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  );
CREATE POLICY "feedback_admin_update" ON feedback
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  );

-- Pickup agents (volunteers) - allow admin users to view and manage
DROP POLICY IF EXISTS "pickup_requests_admin_view" ON pickup_requests;
DROP POLICY IF EXISTS "pickup_requests_admin_manage" ON pickup_requests;
CREATE POLICY "pickup_requests_admin_view" ON pickup_requests
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  );
CREATE POLICY "pickup_requests_admin_manage" ON pickup_requests
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  );

-- NGOs - allow admin users to view and manage
DROP POLICY IF EXISTS "ngos_admin_view" ON ngos;
DROP POLICY IF EXISTS "ngos_admin_manage" ON ngos;
CREATE POLICY "ngos_admin_view" ON ngos
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  );
CREATE POLICY "ngos_admin_manage" ON ngos
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  );

-- Profiles - allow admin users to view and update (for user management)
-- Use a different approach to avoid recursion - check against auth.users metadata or use a security definer function
DROP POLICY IF EXISTS "profiles_admin_view" ON profiles;
DROP POLICY IF EXISTS "profiles_admin_update" ON profiles;
CREATE POLICY "profiles_admin_view" ON profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  );
CREATE POLICY "profiles_admin_update" ON profiles
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM admin_user_details
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  );

COMMIT;
