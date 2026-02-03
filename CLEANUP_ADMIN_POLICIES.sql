-- Clean up remaining duplicate admin policies

DROP POLICY IF EXISTS "Admins can update all plastic items" ON public.plastic_items;
DROP POLICY IF EXISTS "Admins can view all plastic items" ON public.plastic_items;

-- Verify only the new clean policies remain
SELECT policyname, permissive, roles FROM pg_policies WHERE tablename = 'plastic_items' ORDER BY policyname;
