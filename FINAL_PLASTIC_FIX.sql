-- ============================================================================
-- ABSOLUTE FINAL FIX - Complete constraint recreation
-- The constraint is corrupted, we're removing it completely and recreating it
-- ============================================================================

-- RUN ALL STEPS IN ORDER IN SUPABASE SQL EDITOR

-- STEP 1: Disable RLS temporarily
ALTER TABLE public.plastic_items DISABLE ROW LEVEL SECURITY;

-- STEP 2: DROP the problematic constraint COMPLETELY
ALTER TABLE public.plastic_items
DROP CONSTRAINT IF EXISTS plastic_items_status_check CASCADE;

-- STEP 3: Check all constraints currently on the table
SELECT conname, pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'public.plastic_items'::regclass
ORDER BY conname;

-- STEP 4: Ensure status column is properly configured
ALTER TABLE public.plastic_items
ALTER COLUMN status SET NOT NULL;

ALTER TABLE public.plastic_items
ALTER COLUMN status SET DEFAULT 'pending';

-- STEP 5: Remove any NULL status values
UPDATE public.plastic_items
SET status = 'pending'
WHERE status IS NULL;

-- STEP 6: Recreate the constraint using SIMPLE IN syntax
ALTER TABLE public.plastic_items
ADD CONSTRAINT plastic_items_status_check 
CHECK (status IN ('pending', 'assigned', 'collected', 'delivered'));

-- STEP 7: Re-enable RLS
ALTER TABLE public.plastic_items ENABLE ROW LEVEL SECURITY;

-- STEP 8: Verify the constraint
SELECT conname, pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'public.plastic_items'::regclass
AND conname = 'plastic_items_status_check';

-- STEP 9: Verify column configuration
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'plastic_items' AND column_name IN ('status', 'delivery_status');

-- ============================================================================
-- AFTER RUNNING: Hot restart Flutter app and try again
-- ============================================================================
