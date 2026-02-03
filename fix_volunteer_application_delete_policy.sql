-- Fix delete policy for volunteer applications
-- This ensures admins can delete volunteer applications

-- Drop the policy if it exists
DROP POLICY IF EXISTS "Admins can delete applications" ON volunteer_applications;

-- Create the delete policy for admins
CREATE POLICY "Admins can delete applications" ON volunteer_applications
  FOR DELETE USING (check_is_admin());
