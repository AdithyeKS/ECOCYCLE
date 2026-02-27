-- ============================================================================
-- NORMALIZE PROFILES SCHEMA (Strictly Additive & Cleanup)
-- Adding atomic fields (3NF) and removing unused ones
-- ============================================================================

-- 1. Add new granular columns to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS first_name TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_name TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS house_name TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pin_code TEXT;

-- 2. Cleanup: Remove post_office if it was added in a previous run
ALTER TABLE profiles DROP COLUMN IF EXISTS post_office;

-- 3. Data Migration: Populate first_name and last_name from existing full_name
-- (Only if the new columns are currently empty)
UPDATE profiles 
SET 
  first_name = split_part(full_name, ' ', 1),
  last_name = CASE 
                WHEN position(' ' in full_name) > 0 
                THEN substring(full_name from position(' ' in full_name) + 1)
                ELSE ''
              END
WHERE (first_name IS NULL OR first_name = '') AND full_name IS NOT NULL;

-- 4. Update Admin view (STRICTLY APPENDING)
-- Postgres requires EXACT column matching for positions 1-11.
-- We keep 'post_office' as a dummy NULL in the view (at Col 15) to avoid
-- breaking the dozens of RLS policies that depend on this view.
CREATE OR REPLACE VIEW admin_user_details AS
SELECT 
  p.id,                      -- Col 1
  p.full_name,               -- Col 2
  p.phone_number,            -- Col 3
  p.address,                 -- Col 4
  p.total_points,            -- Col 5
  p.user_role,               -- Col 6
  p.supervisor_id,           -- Col 7
  p.volunteer_requested_at,  -- Col 8
  p.created_at,              -- Col 9
  p.updated_at,              -- Col 10
  au.email,                  -- Col 11
  -- NEW COLUMNS MUST BE APPENDED AT THE END (Col 12+)
  p.first_name,              -- Col 12
  p.last_name,               -- Col 13
  p.house_name,              -- Col 14
  NULL::TEXT as post_office, -- Col 15 (Dummy column for view stability)
  p.pin_code                 -- Col 16
FROM public.profiles p
LEFT JOIN auth.users au ON p.id = au.id;
