-- ============================================================================
-- FIX VOLUNTEER ASSIGNMENTS SCHEMA AND RLS POLICIES
-- Run this in the Supabase SQL Editor
-- ============================================================================

-- 1. ENSURE CORRECT COLUMNS EXIST ON volunteer_assignments
-- The migration should have already created 'waste_item_id', but if the
-- old 'task_id' column still exists, copy its data over.
DO $$
BEGIN
  -- If task_id exists but waste_item_id doesn't, rename it
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'volunteer_assignments' AND column_name = 'task_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'volunteer_assignments' AND column_name = 'waste_item_id'
  ) THEN
    ALTER TABLE volunteer_assignments RENAME COLUMN task_id TO waste_item_id;
    RAISE NOTICE 'Renamed task_id to waste_item_id';
  END IF;

  -- If both exist, copy data from task_id to waste_item_id where null
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'volunteer_assignments' AND column_name = 'task_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'volunteer_assignments' AND column_name = 'waste_item_id'
  ) THEN
    UPDATE volunteer_assignments
    SET waste_item_id = task_id
    WHERE waste_item_id IS NULL AND task_id IS NOT NULL;
    RAISE NOTICE 'Copied task_id data to waste_item_id';
  END IF;

  -- Ensure waste_type column exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'volunteer_assignments' AND column_name = 'waste_type'
  ) THEN
    ALTER TABLE volunteer_assignments ADD COLUMN waste_type TEXT DEFAULT 'e-waste';
    RAISE NOTICE 'Added waste_type column';
  END IF;
END $$;

-- 2. FIX RLS POLICIES FOR ewaste_items
-- Enable RLS
ALTER TABLE ewaste_items ENABLE ROW LEVEL SECURITY;

-- Drop old/broken policies (includes both old and new names for idempotency)
DROP POLICY IF EXISTS "Volunteers can view their assigned items" ON ewaste_items;
DROP POLICY IF EXISTS "Volunteers can update their assigned items" ON ewaste_items;
DROP POLICY IF EXISTS "Volunteers can view assigned items" ON ewaste_items;
DROP POLICY IF EXISTS "Volunteers can update assigned items" ON ewaste_items;
DROP POLICY IF EXISTS "Users can view own items" ON ewaste_items;
DROP POLICY IF EXISTS "Users can insert own items" ON ewaste_items;
DROP POLICY IF EXISTS "admin_view_all_ewaste" ON ewaste_items;

-- Allow volunteers to view items assigned to them
CREATE POLICY "Volunteers can view assigned items"
ON ewaste_items FOR SELECT
USING (
  assigned_agent_id = auth.uid()
  OR user_id = auth.uid()
  OR public.check_is_admin()
  OR EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.user_role IN ('admin', 'ngo')
  )
);

-- Allow volunteers to update items assigned to them (for status changes)
CREATE POLICY "Volunteers can update assigned items"
ON ewaste_items FOR UPDATE
USING (
  assigned_agent_id = auth.uid()
  OR user_id = auth.uid()
  OR public.check_is_admin()
  OR EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.user_role IN ('admin', 'ngo')
  )
);

-- Allow users to insert their own items
CREATE POLICY "Users can insert own items"
ON ewaste_items FOR INSERT
WITH CHECK (user_id = auth.uid());

-- 3. FIX RLS POLICIES FOR volunteer_assignments
ALTER TABLE volunteer_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Volunteers can view own assignments" ON volunteer_assignments;
DROP POLICY IF EXISTS "Admins can view all assignments" ON volunteer_assignments;
DROP POLICY IF EXISTS "Admins can insert assignments" ON volunteer_assignments;
DROP POLICY IF EXISTS "Admins can update assignments" ON volunteer_assignments;

-- Volunteers can view their own assignments
CREATE POLICY "Volunteers can view own assignments"
ON volunteer_assignments FOR SELECT
USING (
  volunteer_id = auth.uid()
  OR public.check_is_admin()
);

-- Admins can insert assignments
CREATE POLICY "Admins can insert assignments"
ON volunteer_assignments FOR INSERT
WITH CHECK (
  public.check_is_admin()
);

-- Admins and assigned volunteers can update assignments
CREATE POLICY "Admins can update assignments"
ON volunteer_assignments FOR UPDATE
USING (
  volunteer_id = auth.uid()
  OR public.check_is_admin()
);

-- 4. VERIFICATION QUERIES
-- Check the current columns on volunteer_assignments
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'volunteer_assignments'
ORDER BY ordinal_position;

-- Check active RLS policies
SELECT schemaname, tablename, policyname, cmd, qual
FROM pg_policies
WHERE tablename IN ('ewaste_items', 'volunteer_assignments')
ORDER BY tablename, policyname;
