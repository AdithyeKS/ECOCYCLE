-- ============================================================================
-- FIX VOLUNTEER TASK VISIBILITY AND ACCEPTANCE (RLS)
-- Run this in the Supabase SQL Editor to allow volunteers to see and accept tasks.
-- ============================================================================

BEGIN;

-- 1. E-WASTE ITEMS POLICIES
DROP POLICY IF EXISTS "Volunteers can view assigned items" ON ewaste_items;
DROP POLICY IF EXISTS "Volunteers can update assigned items" ON ewaste_items;
DROP POLICY IF EXISTS "Volunteers can view available and assigned items" ON ewaste_items;
DROP POLICY IF EXISTS "Volunteers can accept and update assigned items" ON ewaste_items;

CREATE POLICY "Volunteers can view available and assigned items"
ON ewaste_items FOR SELECT
USING (
  assigned_agent_id = auth.uid()
  OR user_id = auth.uid()
  OR (delivery_status = 'pending' AND EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.user_role IN ('admin', 'volunteer', 'agent')
  ))
  OR public.check_is_admin()
);

CREATE POLICY "Volunteers can accept and update assigned items"
ON ewaste_items FOR UPDATE
USING (
  assigned_agent_id = auth.uid()
  OR (delivery_status = 'pending' AND EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.user_role IN ('admin', 'volunteer', 'agent')
  ))
  OR public.check_is_admin()
)
WITH CHECK (
  assigned_agent_id = auth.uid()
  OR (delivery_status = 'assigned' AND assigned_agent_id = auth.uid())
  OR public.check_is_admin()
);


-- 2. PLASTIC ITEMS POLICIES
ALTER TABLE plastic_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Volunteers can view plastic" ON plastic_items;
DROP POLICY IF EXISTS "Volunteers can update plastic" ON plastic_items;

CREATE POLICY "Volunteers can view plastic"
ON plastic_items FOR SELECT
USING (
  assigned_agent_id = auth.uid()
  OR user_id = auth.uid()
  OR (delivery_status = 'pending' AND EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.user_role IN ('admin', 'volunteer', 'agent')
  ))
  OR public.check_is_admin()
);

CREATE POLICY "Volunteers can update plastic"
ON plastic_items FOR UPDATE
USING (
  assigned_agent_id = auth.uid()
  OR (delivery_status = 'pending' AND EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.user_role IN ('admin', 'volunteer', 'agent')
  ))
  OR public.check_is_admin()
)
WITH CHECK (
  assigned_agent_id = auth.uid()
  OR (delivery_status = 'assigned' AND assigned_agent_id = auth.uid())
  OR public.check_is_admin()
);


-- 3. CLOTH DONATIONS POLICIES
ALTER TABLE cloth_donations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Volunteers can view cloth" ON cloth_donations;
DROP POLICY IF EXISTS "Volunteers can update cloth" ON cloth_donations;

CREATE POLICY "Volunteers can view cloth"
ON cloth_donations FOR SELECT
USING (
  assigned_agent_id = auth.uid()
  OR user_id = auth.uid()
  OR (delivery_status = 'pending' AND EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.user_role IN ('admin', 'volunteer', 'agent')
  ))
  OR public.check_is_admin()
);

CREATE POLICY "Volunteers can update cloth"
ON cloth_donations FOR UPDATE
USING (
  assigned_agent_id = auth.uid()
  OR (delivery_status = 'pending' AND EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.user_role IN ('admin', 'volunteer', 'agent')
  ))
  OR public.check_is_admin()
)
WITH CHECK (
  assigned_agent_id = auth.uid()
  OR (delivery_status = 'assigned' AND assigned_agent_id = auth.uid())
  OR public.check_is_admin()
);

COMMIT;
