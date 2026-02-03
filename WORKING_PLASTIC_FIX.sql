-- ABSOLUTE FIX - RUN THIS EXACTLY

-- Step 1: Temporarily disable RLS to test if that's the issue
ALTER TABLE public.plastic_items DISABLE ROW LEVEL SECURITY;

-- Step 2: Clean up all conflicting RLS policies
DROP POLICY IF EXISTS "Users can insert own plastic donations" ON public.plastic_items;
DROP POLICY IF EXISTS "Users can view own plastic donations" ON public.plastic_items;
DROP POLICY IF EXISTS "Users can insert own plastic items" ON public.plastic_items;
DROP POLICY IF EXISTS "plastic_items_user_insert" ON public.plastic_items;
DROP POLICY IF EXISTS "Users can update own plastic items" ON public.plastic_items;
DROP POLICY IF EXISTS "Users can view own plastic items" ON public.plastic_items;
DROP POLICY IF EXISTS "plastic_items_user_select" ON public.plastic_items;
DROP POLICY IF EXISTS "Agents can view assigned plastic items" ON public.plastic_items;

-- Step 3: Re-enable RLS
ALTER TABLE public.plastic_items ENABLE ROW LEVEL SECURITY;

-- Step 4: Create clean, non-conflicting policies
CREATE POLICY "user_insert" ON public.plastic_items FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "user_select" ON public.plastic_items FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "admin_select" ON public.plastic_items FOR SELECT USING (check_is_admin());
CREATE POLICY "admin_update" ON public.plastic_items FOR UPDATE USING (check_is_admin()) WITH CHECK (check_is_admin());

-- Step 5: Verify
SELECT policyname, permissive FROM pg_policies WHERE tablename = 'plastic_items' ORDER BY policyname;
