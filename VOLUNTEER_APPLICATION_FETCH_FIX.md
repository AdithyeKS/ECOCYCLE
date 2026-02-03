# 🔧 FIX: Volunteer Applications Not Fetching on Admin Page

**Issue**: Admin page is not displaying volunteer applications
**Status**: Critical - Needs RLS Policy Configuration
**Last Updated**: February 2, 2026

---

## 🎯 Root Cause

The volunteer applications are not fetching because:

1. **RLS Policies Not Applied**: The `volunteer_applications` table doesn't have proper Row Level Security policies configured for admin access
2. **Admin Function Missing**: The `check_is_admin()` function that validates admin role may not exist in your Supabase database
3. **Missing Permissions**: Without proper RLS policies, even admins cannot read volunteer application data

---

## ✅ Solution: Apply RLS Policies

### Step 1: Copy All SQL Below

Go to your **Supabase Dashboard** → **SQL Editor** and paste the complete SQL below:

```sql
-- ============================================================================
-- CREATE ADMIN CHECK FUNCTION (Required for all admin access)
-- ============================================================================

DROP FUNCTION IF EXISTS public.check_is_admin() CASCADE;

CREATE OR REPLACE FUNCTION public.check_is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = OFF
AS $$
DECLARE
  v_is_admin BOOLEAN;
BEGIN
  SELECT (user_role = 'admin') INTO v_is_admin
  FROM public.profiles
  WHERE id = auth.uid()
  LIMIT 1;
  RETURN COALESCE(v_is_admin, FALSE);
EXCEPTION WHEN OTHERS THEN
  RETURN FALSE;
END;
$$;

-- Set proper permissions on the function
ALTER FUNCTION public.check_is_admin() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.check_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_is_admin() TO postgres, authenticated;

-- ============================================================================
-- VOLUNTEER_APPLICATIONS - ENABLE RLS & SET POLICIES
-- ============================================================================

-- Enable RLS on the table
ALTER TABLE public.volunteer_applications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (prevents conflicts)
DROP POLICY IF EXISTS "Users can view own applications" ON public.volunteer_applications;
DROP POLICY IF EXISTS "Users can insert own applications" ON public.volunteer_applications;
DROP POLICY IF EXISTS "Users can update own applications" ON public.volunteer_applications;
DROP POLICY IF EXISTS "Admins can view all applications" ON public.volunteer_applications;
DROP POLICY IF EXISTS "Admins can insert applications" ON public.volunteer_applications;
DROP POLICY IF EXISTS "Admins can update applications" ON public.volunteer_applications;
DROP POLICY IF EXISTS "Admins can delete applications" ON public.volunteer_applications;

-- Policy 1: Users can only view their own applications
CREATE POLICY "Users can view own applications" ON public.volunteer_applications
  FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

-- Policy 2: Users can only insert their own applications
CREATE POLICY "Users can insert own applications" ON public.volunteer_applications
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Policy 3: Users can only update their own applications
CREATE POLICY "Users can update own applications" ON public.volunteer_applications
  FOR UPDATE
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Policy 4: Admins can view ALL applications ⭐ CRITICAL FOR ADMIN PAGE
CREATE POLICY "Admins can view all applications" ON public.volunteer_applications
  FOR SELECT
  USING (check_is_admin());

-- Policy 5: Admins can insert applications
CREATE POLICY "Admins can insert applications" ON public.volunteer_applications
  FOR INSERT
  WITH CHECK (check_is_admin());

-- Policy 6: Admins can update applications
CREATE POLICY "Admins can update applications" ON public.volunteer_applications
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- Policy 7: Admins can delete applications
CREATE POLICY "Admins can delete applications" ON public.volunteer_applications
  FOR DELETE
  USING (check_is_admin());

-- ============================================================================
-- Create indexes for better performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS volunteer_applications_user_id_idx
  ON public.volunteer_applications(user_id);

CREATE INDEX IF NOT EXISTS volunteer_applications_status_idx
  ON public.volunteer_applications(status);

-- ============================================================================
```

### Step 2: Execute the SQL

1. Open the SQL text area in Supabase
2. Paste the SQL above
3. Click **Run** (or press Ctrl+Enter)
4. Wait for success message: ✅ "Query executed successfully"

### Step 3: Verify in Your Flutter App

After applying the SQL, restart your Flutter app:

```bash
# Stop the app (Ctrl+C)
# Then restart it
flutter run
```

**Watch the console for success messages:**

```
✓ All volunteer applications fetched: X applications
✓ Profiles: Y profiles
--- Admin data fetch complete ---
```

---

## 🔍 Troubleshooting

### Still Showing "0 applications"?

**Check 1: Verify Admin Status**

```sql
-- In Supabase SQL Editor, run this:
SELECT id, full_name, user_role FROM public.profiles
WHERE user_role = 'admin' LIMIT 5;
```

Make sure your user appears with `user_role = 'admin'`

**Check 2: Verify RLS Policies**

```sql
-- In Supabase SQL Editor, run this:
SELECT * FROM pg_policies
WHERE tablename = 'volunteer_applications';
```

You should see 7 policies listed

**Check 3: Test Volunteer Applications Table**

```sql
-- In Supabase SQL Editor, run this:
SELECT COUNT(*) as total_apps FROM public.volunteer_applications;
```

Make sure there are applications in the database

### App Still Not Showing Applications?

1. **Force Clear Cache**
   - Stop the app (Ctrl+C)
   - Delete the app from your device/emulator
   - Run `flutter clean`
   - Run `flutter pub get`
   - Run `flutter run`

2. **Check Debug Console**
   - Run with `flutter run -v` to see full logs
   - Look for error messages starting with `✗ Error fetching volunteer applications`

3. **Verify Supabase Connection**
   - Make sure you're logged in as an admin user
   - Check that your Supabase URL and API key are correct in `lib/core/supabase_config.dart`

---

## 📋 Checklist

- [ ] SQL code copied from this guide
- [ ] Pasted into Supabase SQL Editor
- [ ] Executed successfully (no errors)
- [ ] Flutter app restarted
- [ ] Admin page now shows volunteer applications
- [ ] Console shows "✓ All volunteer applications fetched: X applications"

---

## 📚 What Changed

**Before**: Volunteer applications table had no RLS policies, so admin couldn't access the data
**After**: RLS policies now allow:

- Users to see/manage only their own applications
- Admins to see/manage all applications
- Proper role-based access control

**Files Affected**:

- Database: `volunteer_applications` table (RLS policies added)
- No code changes needed in Flutter

---

## ⚡ Quick Summary

| Issue                            | Solution                                            |
| -------------------------------- | --------------------------------------------------- |
| 0 volunteer applications showing | Apply RLS policies with `check_is_admin()` function |
| Admin can't see applications     | Grant admin select permission via RLS policy        |
| Function not found error         | Create `check_is_admin()` function                  |
| Data fetch fails silently        | Check user has `admin` role in profiles table       |

---

## 🆘 Still Need Help?

1. Check the error message in Flutter console
2. Run the troubleshooting SQL checks above
3. Ensure RLS policies were created (7 policies should exist)
4. Verify your user has `user_role = 'admin'` in the profiles table
