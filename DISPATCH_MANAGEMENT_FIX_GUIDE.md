# 🔧 DISPATCH MANAGEMENT DATA FETCHING FIX

**Issue**: Admin dispatch management tab is showing no data (plastic and cloth items not fetching)  
**Status**: 🔴 CRITICAL - Missing RLS Policies  
**Last Updated**: February 2, 2026

---

## 🎯 ROOT CAUSE

The dispatch management in the admin dashboard is not fetching data because:

1. **Plastic Items Table**: Missing RLS policies that allow admin access
2. **Cloth Donations Table**: Missing RLS policies that allow admin access
3. **E-waste Items**: Has RLS policies ✅ (working fine)

When a table has RLS enabled but no policies allow access, ALL users (including admins) are blocked from reading the data.

---

## ✅ QUICK FIX (3 STEPS)

### Step 1: Copy the SQL Fix

Open the file: [FIX_DISPATCH_MANAGEMENT_DATA_FETCH.sql](FIX_DISPATCH_MANAGEMENT_DATA_FETCH.sql)

### Step 2: Run in Supabase SQL Editor

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Paste the entire SQL from Step 1
3. Click **Run** button
4. Wait for ✅ Success message

### Step 3: Reload Flutter App

1. Go back to your Flutter app
2. Press **R** in terminal for hot reload (or **Shift+R** for full restart)
3. Log in as **Admin**
4. Navigate to **Admin Dashboard → Dispatch**
5. You should now see:
   - ✅ E-waste items
   - ✅ Plastic items (NOW FIXED!)
   - ✅ Cloth items (NOW FIXED!)

---

## 📊 WHAT THE FIX DOES

### Creates/Updates RLS Policies

| Table             | Policy       | Effect                      |
| ----------------- | ------------ | --------------------------- |
| `plastic_items`   | Admin SELECT | Admins can view all items   |
| `plastic_items`   | Admin UPDATE | Admins can modify all items |
| `plastic_items`   | User SELECT  | Users see only their items  |
| `plastic_items`   | User INSERT  | Users can submit items      |
| `cloth_donations` | Admin SELECT | Admins can view all items   |
| `cloth_donations` | Admin UPDATE | Admins can modify all items |
| `cloth_donations` | User SELECT  | Users see only their items  |
| `cloth_donations` | User INSERT  | Users can submit items      |

### Security Function

- Ensures `check_is_admin()` function exists
- This function checks if current user has `user_role = 'admin'`
- Used by all RLS policies to grant admin privileges

---

## ✔️ VERIFICATION

### After running the SQL, verify it worked:

**In Supabase SQL Editor, run these queries:**

```sql
-- Check function exists
SELECT routine_name FROM information_schema.routines
WHERE routine_name = 'check_is_admin';
-- Should return: check_is_admin

-- Check RLS is enabled
SELECT tablename FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('plastic_items', 'cloth_donations')
ORDER BY tablename;
-- Should return: cloth_donations, plastic_items

-- Check policies exist
SELECT tablename, policyname FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('plastic_items', 'cloth_donations')
ORDER BY tablename, policyname;
-- Should return: 4 policies per table (8 total)

-- Test as admin (run this if you're logged in as admin)
SELECT COUNT(*) as plastic_items_count FROM plastic_items;
SELECT COUNT(*) as cloth_items_count FROM cloth_donations;
-- Should return numbers > 0 if you have items in these tables
```

---

## 🐛 TROUBLESHOOTING

### "Still no data in Dispatch tab"

**Check 1: Admin User Exists**

```sql
SELECT id, full_name, user_role FROM public.profiles
WHERE user_role = 'admin' LIMIT 5;
```

If nothing returns: **You need to create an admin user**

**To create an admin:**

```sql
-- Option A: Update existing user to admin
UPDATE public.profiles
SET user_role = 'admin'
WHERE email = 'your_email@example.com';

-- Option B: Verify the admin has correct role
SELECT id, full_name, user_role FROM public.profiles
WHERE id = (SELECT auth.uid());
```

**Check 2: Function is working**

```sql
-- Test the function
SELECT check_is_admin();
-- Should return: true (if you're logged in as admin)
```

**Check 3: RLS Policies exist**

```sql
SELECT tablename, policyname, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('plastic_items', 'cloth_donations')
ORDER BY tablename, policyname;
```

**Check 4: Data exists in tables**

```sql
SELECT COUNT(*) as plastic_count FROM plastic_items;
SELECT COUNT(*) as cloth_count FROM cloth_donations;
-- If 0, you have no items to display (not an error, app is working correctly)
```

---

## 📋 FILES INVOLVED

| File                                                                             | Purpose              | Status               |
| -------------------------------------------------------------------------------- | -------------------- | -------------------- |
| [FIX_DISPATCH_MANAGEMENT_DATA_FETCH.sql](FIX_DISPATCH_MANAGEMENT_DATA_FETCH.sql) | The fix to apply     | ✅ Ready to use      |
| [lib/screens/admin_dashboard.dart](lib/screens/admin_dashboard.dart)             | Admin dashboard code | ✅ No changes needed |
| [lib/services/plastic_service.dart](lib/services/plastic_service.dart)           | Plastic data service | ✅ No changes needed |
| [lib/services/cloth_service.dart](lib/services/cloth_service.dart)               | Cloth data service   | ✅ No changes needed |

---

## 🔐 SECURITY NOTES

- ✅ Only admins can see ALL items (other users only see their own)
- ✅ Only admins can edit ANY item (users can't modify others' submissions)
- ✅ Non-admins still have their own read/write access (their items only)
- ✅ Policies use `check_is_admin()` function with `SECURITY DEFINER`

---

## 📝 ADMIN PERMISSIONS AFTER FIX

After applying this fix, admins can:

- ✅ View ALL e-waste items
- ✅ View ALL plastic items (FIXED!)
- ✅ View ALL cloth donations (FIXED!)
- ✅ Assign items to NGOs
- ✅ Assign items to pickup agents
- ✅ Update delivery status
- ✅ Change dispatch management status

---

## 🎯 NEXT STEPS

1. **Apply the SQL fix** → [FIX_DISPATCH_MANAGEMENT_DATA_FETCH.sql](FIX_DISPATCH_MANAGEMENT_DATA_FETCH.sql)
2. **Reload Flutter app** → Hot reload or restart
3. **Test dispatch tab** → Verify all items appear
4. **If issues persist** → Follow troubleshooting section above

---

**Need help?** Check the detailed troubleshooting section or verify each query returns expected results.
