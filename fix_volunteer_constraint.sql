-- Fix the profiles user_role check constraint to include only 'user', 'volunteer', 'admin'
BEGIN;

-- First, update any existing 'agent' roles to 'user' (or 'volunteer' if they have pickup requests)
UPDATE profiles
SET user_role = CASE
  WHEN id IN (SELECT agent_id FROM pickup_requests WHERE agent_id IS NOT NULL) THEN 'volunteer'
  ELSE 'user'
END
WHERE user_role = 'agent';

-- Drop the existing constraint if it exists
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_user_role_check;

-- Add the correct constraint that includes only the 3 roles
ALTER TABLE profiles ADD CONSTRAINT profiles_user_role_check
  CHECK (user_role IN ('user', 'volunteer', 'admin'));

COMMIT;
