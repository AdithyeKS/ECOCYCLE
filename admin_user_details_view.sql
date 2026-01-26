-- Create a view for admin to fetch user details including emails
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

-- Grant access to authenticated users (admins)
GRANT SELECT ON public.admin_user_details TO authenticated;
