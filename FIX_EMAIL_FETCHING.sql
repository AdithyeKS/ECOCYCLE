-- ============================================================================
-- ECOCYCLE: SECURE EMAIL FETCHING FOR NOTIFICATIONS
-- This script creates a security definer function to allow volunteers
-- to fetch user emails for OTP notifications, bypassing strict RLS.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_email_secure(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email TEXT;
BEGIN
  -- We fetch directly from auth.users (which is only accessible by service_role or via security definer)
  SELECT email INTO v_email
  FROM auth.users
  WHERE id = p_user_id;
  
  RETURN v_email;
END;
$$;

-- Grant access to authenticated users
GRANT EXECUTE ON FUNCTION public.get_user_email_secure(UUID) TO authenticated;

-- COMMENT FOR DOCUMENTATION
COMMENT ON FUNCTION public.get_user_email_secure(UUID) IS 'Securely fetches a users email from auth.users. Used for sending OTP notifications across RLS boundaries.';
