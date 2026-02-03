# ❌ FIX: Plastic Items Status Check Constraint Violation

ERROR:
"new row for relation "plastic_items" violates check constraint
"plastic_items_status_check""

ROOT CAUSE:
The database CHECK constraint for plastic_items.status is expecting specific
lowercase values, but either:

1. The constraint definition was corrupted/mismatched
2. The database table doesn't have the correct constraint applied

# SOLUTION - 2 STEPS:

STEP 1: Fix Database Constraint
Location: FIX_PLASTIC_ITEMS_STATUS_CONSTRAINT.sql

✅ Run this SQL in Supabase SQL Editor:

```sql
-- Drop existing constraint
ALTER TABLE public.plastic_items
DROP CONSTRAINT IF EXISTS plastic_items_status_check;

-- Add corrected constraint with lowercase values
ALTER TABLE public.plastic_items
ADD CONSTRAINT plastic_items_status_check
CHECK (status IN ('pending', 'assigned', 'collected', 'delivered'));
```

STEP 2: Verify Code Uses Lowercase Status
Location: lib/services/plastic_service.dart

✅ Verified - Code already uses lowercase:
'status': 'pending' ← CORRECT (lowercase)

Valid status values (ALL LOWERCASE):

- 'pending' (initial state)
- 'assigned' (assigned to agent/NGO)
- 'collected' (item collected)
- 'delivered' (item delivered)

VERIFICATION:
After applying the SQL fix, test:

1. Go to Add Plastic Waste screen
2. Take a photo or select image
3. Fill in details
4. Submit
5. Should succeed without constraint error

IF STILL GETTING ERROR:

- Verify RLS policies allow INSERT for authenticated users
- Check that user_id foreign key references valid user
- Ensure user exists in profiles table
- Run: SELECT \* FROM plastic_items LIMIT 1; to verify table structure

KEY POINTS:
✅ Dart code is CORRECT (uses lowercase 'pending')
✅ Status values MUST match: 'pending', 'assigned', 'collected', 'delivered'
✅ Database constraint must enforce lowercase only
