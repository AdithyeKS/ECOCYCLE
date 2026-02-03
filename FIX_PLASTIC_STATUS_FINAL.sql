-- ============================================================================
-- FINAL FIX: STATUS COLUMN IS NULLABLE BUT CONSTRAINT REQUIRES VALUES
-- This is the ROOT CAUSE
-- ============================================================================

-- PROBLEM FOUND:
-- - status column is_nullable: YES (can be NULL)
-- - But CHECK constraint requires: 'pending', 'assigned', 'collected', or 'delivered'
-- - When NULL is inserted, it violates the constraint

-- SOLUTION: Make status NOT NULL

-- STEP 1: Make status NOT NULL
ALTER TABLE public.plastic_items
ALTER COLUMN status SET NOT NULL;

-- STEP 2: Ensure the default value
ALTER TABLE public.plastic_items
ALTER COLUMN status SET DEFAULT 'pending';

-- STEP 3: Remove any existing NULL values
UPDATE public.plastic_items
SET status = 'pending'
WHERE status IS NULL;

-- STEP 4: Verify the fix
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'plastic_items' AND column_name = 'status';

-- STEP 5: Verify constraint still exists
SELECT conname, pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'public.plastic_items'::regclass
AND conname = 'plastic_items_status_check';

-- STEP 6: Check RLS policies (if restrictive, might need INSERT policy)
SELECT policyname, permissive, roles, qual, with_check
FROM pg_policies
WHERE tablename = 'plastic_items'
ORDER BY policyname;

-- ============================================================================
-- AFTER THIS FIX:
-- 1. Hot restart your Flutter app
-- 2. Try adding a plastic item again
-- 3. It should work now!
-- ============================================================================
