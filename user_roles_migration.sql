-- Migration to add user_roles table for multiple roles per user
-- This allows users to have both 'user' and 'volunteer' roles simultaneously

-- Create user_roles table
CREATE TABLE IF NOT EXISTS user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'agent', 'volunteer', 'admin')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Ensure no duplicate roles per user
  UNIQUE(user_id, role)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role);

-- Enable RLS
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can read their own roles
CREATE POLICY "Users can view their own roles" ON user_roles
  FOR SELECT USING (auth.uid() = user_id);

-- Admins can manage all roles
CREATE POLICY "Admins can manage all roles" ON user_roles
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND user_role = 'admin'
    )
  );

-- Migration: Insert default 'user' role for existing profiles
INSERT INTO user_roles (user_id, role)
SELECT id, COALESCE(user_role, 'user')
FROM profiles
WHERE id NOT IN (SELECT user_id FROM user_roles WHERE role = COALESCE(profiles.user_role, 'user'))
ON CONFLICT (user_id, role) DO NOTHING;

-- For users who are volunteers, add both roles
INSERT INTO user_roles (user_id, role)
SELECT id, 'user'
FROM profiles
WHERE user_role = 'volunteer'
AND id NOT IN (SELECT user_id FROM user_roles WHERE role = 'user')
ON CONFLICT (user_id, role) DO NOTHING;

-- Update the profiles table to keep backward compatibility
-- The user_role field will remain for single-role users, but multi-role users will use the user_roles table

-- Add a comment to the profiles table
COMMENT ON TABLE user_roles IS 'Stores multiple roles per user. Users can have both user and volunteer roles simultaneously.';
