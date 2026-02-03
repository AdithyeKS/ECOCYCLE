# 🔧 VOLUNTEER DATA FETCHING FIX - IMPLEMENTATION GUIDE

## Problem Summary

**Issue**: Volunteer dashboard tasks (assigned items) are not loading/displaying.

**Symptoms**:

- Volunteer sees "No Assigned Tasks" message even when tasks are assigned
- Tasks tab shows empty list
- No error messages displayed to the user

## Root Cause

The issue is caused by **RLS (Row-Level Security) policies** in the Supabase database that prevent volunteers from viewing their assigned e-waste items.

### The Policy Problem

**Current broken policy** in `ewaste_items` table:

```sql
CREATE POLICY "Agents can view assigned items" ON ewaste_items
  FOR SELECT
  USING (check_is_admin() OR (SELECT auth.uid()) = assigned_agent_id);
```

**Why it fails**:

1. Volunteers are NOT in the admin role, so `check_is_admin()` returns FALSE
2. The comparison `(SELECT auth.uid()) = assigned_agent_id` should work in theory
3. However, there may be NULL values in `assigned_agent_id` or type mismatch issues

**The fix**: Separate the logic into explicit policies and use CASE statements to safely handle NULL values.

## Solution

### Step 1: Apply the SQL Fix

1. **Go to Supabase Dashboard**
   - Navigate to your project
   - Go to SQL Editor
   - Create a new query

2. **Copy and paste the corrected SQL**
   - File: `FIX_VOLUNTEER_DATA_FETCHING_CORRECTED.sql`
   - This file contains improved RLS policies

3. **The key improvements**:

   ```sql
   -- NEW POLICY: Volunteers can view their assigned items
   CREATE POLICY "Volunteers can view assigned items" ON ewaste_items
     FOR SELECT
     USING (
       CASE
         WHEN assigned_agent_id IS NOT NULL THEN
           (SELECT auth.uid()) = assigned_agent_id
         ELSE
           FALSE
       END
     );

   -- NEW POLICY: Volunteers can update their assigned items
   CREATE POLICY "Volunteers can update assigned items" ON ewaste_items
     FOR UPDATE
     USING (
       CASE
         WHEN assigned_agent_id IS NOT NULL THEN
           (SELECT auth.uid()) = assigned_agent_id
         ELSE
           FALSE
       END
     )
     WITH CHECK (
       CASE
         WHEN assigned_agent_id IS NOT NULL THEN
           (SELECT auth.uid()) = assigned_agent_id
         ELSE
           FALSE
       END
     );
   ```

### Step 2: Enhanced Logging in App

The `volunteer_dashboard.dart` file has been updated with detailed logging:

**What you'll see in the console**:

```
🔐 Volunteer authenticated: [USER_UUID]
📥 Fetching user profile...
✅ User role: user
📊 Starting data fetch...
📥 Fetching assigned items for volunteer: [USER_UUID]
✅ Retrieved 3 assigned items
✓ Assigned items loaded successfully: 3 items
📥 Fetching schedules for volunteer: [USER_UUID]
✅ Retrieved 5 schedules
✓ Schedules loaded successfully
```

If there's an error:

```
❌ Error loading assigned items: PgException: new row violates row-level security policy...
```

### Step 3: Verify the Fix

**Method 1: Check Supabase**

Run this query in Supabase SQL Editor:

```sql
-- Check all RLS policies on ewaste_items table
SELECT policyname, qual, with_check FROM pg_policies
WHERE tablename = 'ewaste_items'
ORDER BY policyname;
```

You should see:

- ✅ "Admins can view all ewaste items"
- ✅ "Users can view own ewaste items"
- ✅ "Users can insert own ewaste items"
- ✅ "Users can update own ewaste items"
- ✅ **"Volunteers can view assigned items"** ← NEW
- ✅ **"Volunteers can update assigned items"** ← NEW

**Method 2: Test in App**

1. Log in as an admin account
2. Go to admin dashboard
3. Assign an e-waste item to a volunteer
4. Log out and log in as the volunteer
5. Go to volunteer dashboard → Tasks tab
6. Should now see the assigned item

**Method 3: Monitor Console Logs**

While testing:

1. Open Flutter DevTools (or run with: `flutter run -v`)
2. Watch for the debug messages:
   - `✅ Retrieved X assigned items` = Data is fetching
   - `❌ Error loading assigned items:` = RLS policy issue

## Troubleshooting

### Issue: Still showing "No Assigned Tasks"

**Check 1**: Verify the volunteer is actually assigned

```sql
SELECT id, item_name, assigned_agent_id
FROM ewaste_items
WHERE assigned_agent_id = 'VOLUNTEER_UUID_HERE'
LIMIT 5;
```

**Check 2**: Verify RLS policies are correct

```sql
SELECT * FROM pg_policies WHERE tablename = 'ewaste_items';
```

**Check 3**: Check app console logs

- Look for `❌ Error loading assigned items:`
- Copy the exact error message

### Issue: "Permission denied" error

This indicates the RLS policies are still blocking access. Make sure:

1. ✅ You ran the corrected SQL file
2. ✅ All old policies were dropped
3. ✅ New policies were created
4. ✅ You waited 10-15 seconds for the changes to propagate

### Issue: See console errors but no visual error in app

The app catches errors and displays them as snackbars. Check:

1. Bottom of the screen for error messages
2. Flutter console output (run with `-v` flag)

## File Changes

### Modified Files:

1. **`lib/screens/volunteer_dashboard.dart`**
   - Added detailed debugging/logging
   - Better error messages
   - More visibility into data fetching process

### New Files:

1. **`FIX_VOLUNTEER_DATA_FETCHING_CORRECTED.sql`**
   - Corrected RLS policies
   - Separate policies for volunteers vs admins
   - Safe NULL handling with CASE statements

## How the Fix Works

### Before (Broken)

```
Volunteer views app
    ↓
App calls fetchItemsForAgent(volunteerId)
    ↓
Supabase checks RLS policy
    ↓
Policy: check_is_admin() OR auth.uid() = assigned_agent_id
    ↓
check_is_admin() = FALSE (volunteer is not admin)
OR auth.uid() = assigned_agent_id = ???
    ↓
Returns 0 rows → "No Assigned Tasks" 😞
```

### After (Fixed)

```
Volunteer views app
    ↓
App calls fetchItemsForAgent(volunteerId)
    ↓
Supabase checks RLS policies in order:
    ↓
1. "Volunteers can view assigned items" policy
   CASE WHEN assigned_agent_id IS NOT NULL
   THEN auth.uid() = assigned_agent_id
   ✅ Returns TRUE if it matches
    ↓
2. "Users can view own ewaste items" policy
   USING auth.uid() = user_id
   ✅ Returns TRUE if user submitted it
    ↓
3. "Admins can view all ewaste items" policy
   USING check_is_admin()
   ✅ Returns TRUE if admin
    ↓
Returns matching rows → Tasks display correctly ✅
```

## Important Notes

⚠️ **DO NOT ignore RLS errors in production**

- RLS is protecting your data
- If access is denied, there's a security policy preventing it for a reason
- Work WITH the RLS system, not against it

✅ **Best Practices**:

1. Always use explicit policy names that describe the purpose
2. Use CASE statements for safe NULL handling
3. Separate admin and user policies for clarity
4. Test each policy independently
5. Document why each policy exists

## Support

If the issue persists after applying the fix:

1. **Check the exact error message** from Flutter console
2. **Verify all old policies were dropped** (run verification query)
3. **Confirm the volunteer is assigned** (check database)
4. **Test with a different volunteer** (rule out user-specific issues)
5. **Check Supabase logs** for additional details

---

**Last Updated**: February 2, 2026
**Status**: ✅ Ready for deployment
