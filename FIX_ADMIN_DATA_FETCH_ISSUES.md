# 🔧 FIX: ADMIN PAGE DATA NOT FETCHING

**Last Updated**: February 2, 2026
**Status**: Ready to Apply

## Quick Diagnosis

When admin page data is not fetching, follow these steps:

### Step 1: Enable Console Logging

Run the app in debug mode to see what's happening:

```bash
flutter run -v
```

Watch the console for one of these messages:

- ✅ `=== 📊 ADMIN DATA FETCH STARTED ===` → Data fetch is working
- ❌ `=== ❌ ADMIN DATA FETCH FAILED ===` → Data fetch failed
- Shows `0 items` for each data type → RLS policies might be blocking access

---

## Solution: Step-by-Step Fix

### **STEP 1: Fix RLS Policies in Supabase** ⚡ CRITICAL

If console shows data fetch failures or 0 items, your RLS policies are likely missing or incorrect.

**Action**: Go to Supabase Dashboard → SQL Editor → Copy and paste the entire SQL below:

```sql
-- ============================================================================
-- CREATE ADMIN CHECK FUNCTION
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

ALTER FUNCTION public.check_is_admin() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.check_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_is_admin() TO postgres, authenticated;

-- ============================================================================
-- VOLUNTEER_APPLICATIONS - ENABLE RLS & SET POLICIES
-- ============================================================================

ALTER TABLE volunteer_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Users can insert own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Users can update own applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can view all applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can insert applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can update applications" ON volunteer_applications;
DROP POLICY IF EXISTS "Admins can delete applications" ON volunteer_applications;

CREATE POLICY "Users can view own applications" ON volunteer_applications
  FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own applications" ON volunteer_applications
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own applications" ON volunteer_applications
  FOR UPDATE
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Admins can view all applications" ON volunteer_applications
  FOR SELECT
  USING (check_is_admin());

CREATE POLICY "Admins can insert applications" ON volunteer_applications
  FOR INSERT
  WITH CHECK (check_is_admin());

CREATE POLICY "Admins can update applications" ON volunteer_applications
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

CREATE POLICY "Admins can delete applications" ON volunteer_applications
  FOR DELETE
  USING (check_is_admin());

-- ============================================================================
-- EWASTE_ITEMS - ENABLE RLS & SET POLICIES
-- ============================================================================

ALTER TABLE ewaste_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view all ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Admins can update all ewaste items" ON ewaste_items;
DROP POLICY IF EXISTS "Admins can delete all ewaste items" ON ewaste_items;

CREATE POLICY "Admins can view all ewaste items" ON ewaste_items
  FOR SELECT
  USING (check_is_admin());

CREATE POLICY "Admins can update all ewaste items" ON ewaste_items
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

CREATE POLICY "Admins can delete all ewaste items" ON ewaste_items
  FOR DELETE
  USING (check_is_admin());

-- ============================================================================
-- PLASTIC_ITEMS - ENABLE RLS & SET POLICIES
-- ============================================================================

ALTER TABLE plastic_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view all plastic items" ON plastic_items;
DROP POLICY IF EXISTS "Admins can update all plastic items" ON plastic_items;

CREATE POLICY "Admins can view all plastic items" ON plastic_items
  FOR SELECT
  USING (check_is_admin());

CREATE POLICY "Admins can update all plastic items" ON plastic_items
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- ============================================================================
-- CLOTH_ITEMS - ENABLE RLS & SET POLICIES
-- ============================================================================

ALTER TABLE cloth_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view all cloth items" ON cloth_items;
DROP POLICY IF EXISTS "Admins can update all cloth items" ON cloth_items;

CREATE POLICY "Admins can view all cloth items" ON cloth_items
  FOR SELECT
  USING (check_is_admin());

CREATE POLICY "Admins can update all cloth items" ON cloth_items
  FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- ============================================================================
-- PROFILES - ENABLE RLS & SET POLICIES (IF NOT ALREADY ENABLED)
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;

CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT
  USING ((SELECT auth.uid()) = id);

CREATE POLICY "Admins can view all profiles" ON profiles
  FOR SELECT
  USING (check_is_admin());

-- ============================================================================
-- VOLUNTEER_SCHEDULES - ENABLE RLS & SET POLICIES (IF NOT ALREADY ENABLED)
-- ============================================================================

ALTER TABLE volunteer_schedules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view all schedules" ON volunteer_schedules;

CREATE POLICY "Admins can view all schedules" ON volunteer_schedules
  FOR SELECT
  USING (check_is_admin());

-- ============================================================================
-- FEEDBACK - ENABLE RLS & SET POLICIES (IF NOT ALREADY ENABLED)
-- ============================================================================

ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view all feedback" ON feedback;

CREATE POLICY "Admins can view all feedback" ON feedback
  FOR SELECT
  USING (check_is_admin());

-- ============================================================================
-- VERIFY SETUP
-- ============================================================================

-- Check that admin users exist and have correct role
SELECT id, full_name, user_role FROM public.profiles WHERE user_role = 'admin';

-- Check that check_is_admin function exists and works
SELECT check_is_admin() AS is_admin_result;
```

**IMPORTANT**: After pasting, click "Run" button in Supabase SQL Editor.

---

### **STEP 2: Verify Admin User Has Correct Role**

Run this query in Supabase SQL Editor to check admin users:

```sql
SELECT
  id,
  full_name,
  email,
  user_role,
  created_at
FROM public.profiles
WHERE user_role = 'admin'
ORDER BY created_at DESC;
```

**Expected Result**: You should see at least one row with `user_role = 'admin'`

**If NOT**: You need to manually set an admin user. Run:

```sql
UPDATE public.profiles
SET user_role = 'admin'
WHERE email = 'your-admin-email@example.com';
```

Replace `your-admin-email@example.com` with your actual admin email.

---

### **STEP 3: Verify Data Exists in Tables**

Run these queries to verify data actually exists:

```sql
-- Check e-waste items
SELECT COUNT(*) as ewaste_count FROM ewaste_items;

-- Check volunteer applications
SELECT COUNT(*) as app_count FROM volunteer_applications;

-- Check plastic items
SELECT COUNT(*) as plastic_count FROM plastic_items;

-- Check cloth items
SELECT COUNT(*) as cloth_count FROM cloth_items;

-- Check volunteer schedules
SELECT COUNT(*) as schedule_count FROM volunteer_schedules;

-- Check feedback
SELECT COUNT(*) as feedback_count FROM feedback;
```

**Expected Result**: Each should show a count (0 or higher)

**If you see errors**: The table might not exist. Create it or check the database structure.

---

### **STEP 4: Test the Fix in the App**

1. **Rebuild the app**:

   ```bash
   flutter clean
   flutter pub get
   flutter run -v
   ```

2. **Log in as admin** and watch the console

3. **Check console for**:

   ```
   === 📊 ADMIN DATA FETCH STARTED ===
   ✅ E-waste: X items
   ✅ NGOs: X items
   ✅ Agents: X items
   ✅ Profiles: X items
   ✅ Applications: X items
   ✅ Schedules: X items
   ✅ Feedback: X items
   ✅ Plastic: X items
   ✅ Cloth: X items
   === ✅ ADMIN DATA FETCH COMPLETE ===
   ```

4. **Navigate to each tab**:
   - Dashboard → Should show metrics
   - Dispatch → Should show waste items
   - Volunteers → Should show applications

---

## Troubleshooting

### Issue: Still shows "0 items" or empty tabs

**Check**:

1. **Did you run the SQL?** Verify RLS policies exist:

   ```sql
   SELECT schemaname, tablename, policyname FROM pg_policies
   WHERE tablename IN ('ewaste_items', 'volunteer_applications', 'plastic_items', 'cloth_items');
   ```

2. **Is admin user role correct?**

   ```sql
   SELECT user_role FROM profiles WHERE id = auth.uid();
   ```

   Should return: `admin`

3. **Does data exist in database?**
   ```sql
   SELECT COUNT(*) FROM ewaste_items;
   ```
   Should return: > 0

### Issue: "Permission denied" errors

**Solution**:

1. Check RLS policies were applied correctly
2. Verify admin user role is set
3. Try clearing app cache: `flutter clean`
4. Force rebuild: `flutter pub get`

### Issue: Admin user doesn't exist

**Solution**:

1. Find your admin email (check Firebase/Supabase Auth)
2. Run this SQL to set them as admin:
   ```sql
   UPDATE profiles
   SET user_role = 'admin'
   WHERE email = 'admin@example.com';
   ```

---

## Files Reference

- **SQL Fix**: `SUPABASE_FINAL.sql` (same content as above)
- **Code**: `lib/screens/admin_dashboard.dart` (already has logging)
- **Service**: `lib/services/profile_service.dart` (data fetching logic)

---

## Common Error Messages & Fixes

| Error                                     | Cause                               | Fix                    |
| ----------------------------------------- | ----------------------------------- | ---------------------- |
| `permission denied`                       | RLS policy blocking                 | Run SQL fix above      |
| `Admin sees 0 items`                      | No data in database OR RLS blocking | Check both             |
| `Function check_is_admin() doesn't exist` | SQL not run                         | Copy and run SQL above |
| `admin_user_details view not found`       | View needs to be created            | Check schema.sql       |

---

## Verification Checklist

- [ ] RLS policies applied in Supabase
- [ ] Admin user has role = 'admin'
- [ ] Data exists in database tables
- [ ] App rebuilt with `flutter clean`
- [ ] Logged in as admin user
- [ ] Console shows fetch logs
- [ ] Dashboard tab shows data
- [ ] Dispatch tab shows items
- [ ] Volunteers tab shows applications

---

**Need help?** Check the detailed documentation:

- Admin Fixes: `ADMIN_DASHBOARD_DATA_FETCHING_FIX.md`
- Database Setup: `SUPABASE_FINAL.sql`
- Deployment: `DATA_FETCHING_DEPLOYMENT_CHECKLIST.md`
