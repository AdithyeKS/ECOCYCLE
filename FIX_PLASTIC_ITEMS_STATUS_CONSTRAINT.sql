-- ============================================================================
-- CONSTRAINT IS CORRECT - FINDING THE REAL CULPRIT
-- The status constraint is fine, so the error is likely elsewhere
-- ============================================================================

-- The constraint is: CHECK (((status = 'pending'::text) OR (status = 'assigned'::text) ...))
-- This is CORRECT and allows 'pending'

-- So the real problem must be ONE OF THESE:

-- 1. Check if there are OTHER constraints that might be failing
SELECT conname, pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'public.plastic_items'::regclass
ORDER BY conname;

-- 2. Check RLS policies - maybe INSERT is being blocked
SELECT policyname, permissive, roles, qual, with_check
FROM pg_policies
WHERE tablename = 'plastic_items'
ORDER BY policyname;

-- 3. Check if user_id foreign key is the issue
SELECT id FROM public.profiles LIMIT 1;

-- 4. Check table structure for any other issues
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'plastic_items' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 5. Try a direct test insert (use a real user_id from above)
-- Example: SELECT * FROM auth.users LIMIT 1; to get a real user_id
-- Then uncomment and run this with the actual user_id:
-- INSERT INTO public.plastic_items (user_id, plastic_type, item_name, description, location, status)
-- VALUES ('550e8400-e29b-41d4-a716-446655440000'::uuid, 'Bottle', 'Test Bottle', 'Test Description', 'Test Location', 'pending');

-- ============================================================================
-- MOST LIKELY ISSUE: 
-- The error message says "plastic_items_status_check" but it's probably:
-- 1. RLS policy blocking INSERT
-- 2. Missing required field (like delivery_status needs a default)
-- 3. Foreign key constraint on user_id
-- ============================================================================

-- Check if delivery_status has a constraint:
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.plastic_items'::regclass
AND contype = 'c';
