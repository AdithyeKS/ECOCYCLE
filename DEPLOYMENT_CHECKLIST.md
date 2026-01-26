# ✅ DEPLOYMENT CHECKLIST - ADMIN DASHBOARD

## 📋 Pre-Deployment (Do This First)

- [ ] Read `DEPLOYMENT_FINAL_SUMMARY.md`
- [ ] Read `RLS_AUDIT_FIX_ACTION_GUIDE.md`
- [ ] Understand what RLS audit found
- [ ] Know your admin user email
- [ ] Have Supabase dashboard open
- [ ] Have Flutter project open

---

## 🚀 Deployment Phase 1: SQL (3 minutes)

### Prepare

- [ ] Open file: `SUPABASE_RLS_AUDIT_FIX.sql`
- [ ] Read the entire file (understand what it does)
- [ ] Copy entire file contents to clipboard

### Deploy

- [ ] Go to https://supabase.com
- [ ] Select your Ecocycle project
- [ ] Click: SQL Editor
- [ ] Paste entire file contents
- [ ] Click: **RUN** button
- [ ] Wait for completion

### Verify

- [ ] Check for errors in output (should be none)
- [ ] Look for green checkmark or "success" message
- [ ] No red error messages

---

## 🔍 Deployment Phase 2: Verification (1 minute)

### Check 1: Admin Roles Populated

```sql
SELECT COUNT(*) as admin_count FROM public.admin_roles;
```

**Expected Result:** Shows 1 or more  
**If 0:** See troubleshooting below

- [ ] Admin count ≥ 1 ✅

### Check 2: Verify Function

```sql
SELECT check_is_admin();
```

**Expected Result:** `true` (if you're admin) or `false`  
**If error:** Function may not exist, re-run SQL

- [ ] Function returns boolean ✅

### Check 3: RLS Enabled on Profiles

```sql
SELECT tablename, rowsecurity
FROM pg_tables
WHERE tablename = 'profiles';
```

**Expected Result:** `profiles | true`  
**If false:** RLS not enabled, re-run SQL

- [ ] RLS is enabled (true) ✅

### Check 4: Indexes Created

```sql
SELECT COUNT(*) as index_count FROM pg_indexes
WHERE tablename IN ('profiles', 'ewaste_items', 'volunteer_applications');
```

**Expected Result:** Shows 3 or more

- [ ] Indexes exist ✅

---

## 📱 Deployment Phase 3: Flutter Testing (2 minutes)

### Prepare App

- [ ] Close and reopen Flutter project (or hot reload)
- [ ] Ensure internet connection
- [ ] Ensure Supabase config is correct

### Test Login

- [ ] Open app
- [ ] Log in with **ADMIN** email (important!)
- [ ] See admin dashboard screen
- [ ] No error messages
- [ ] App doesn't crash
- [ ] All tabs visible at bottom

### Test Dispatch Tab

- [ ] Click Dispatch tab
- [ ] See list of e-waste items (if any exist)
- [ ] Each item shows:
  - [ ] Image (or placeholder)
  - [ ] Item name
  - [ ] Username (donor)
  - [ ] Location
  - [ ] Status badge
- [ ] Try clicking "NGO" button
- [ ] Try clicking "Agent" button
- [ ] Try clicking "Status" button
- [ ] Search works (type in search bar)

### Test User Management Tab

- [ ] Click Users tab
- [ ] See list of all users
- [ ] Each user shows:
  - [ ] Name with avatar
  - [ ] Email
  - [ ] Role (user/volunteer/agent/admin)
- [ ] Try clicking "Role" button on non-admin user
- [ ] Dialog opens with role options
- [ ] Try clicking "Delete" button
- [ ] Confirmation dialog appears
- [ ] Admin users show lock icon
- [ ] Search works

### Test Volunteer Tab

- [ ] Click Volunteers tab
- [ ] If volunteer applications exist, see them listed
- [ ] Each shows:
  - [ ] Name
  - [ ] Application date
  - [ ] Motivation
  - [ ] Status
- [ ] Try clicking "Approve" button
  - [ ] No RLS errors ✅
  - [ ] Success message appears
  - [ ] Status changes to "APPROVED"
- [ ] Try clicking "Reject" button
  - [ ] No RLS errors ✅
  - [ ] Rejection works

### Test Global Features

- [ ] Dark mode toggle works
- [ ] Search bar filters all tabs
- [ ] Refresh button works (pull down)
- [ ] No console errors
- [ ] No RLS warnings

### Test Logistics Tab (Optional)

- [ ] Click Logistics tab
- [ ] See volunteer schedules (if any)
- [ ] Information displays correctly

### Test Settings Tab

- [ ] Click Settings tab
- [ ] Dark mode toggle present
- [ ] Logout button present

---

## 🎯 Post-Deployment Checks

### Code Quality

- [ ] No red error messages in console
- [ ] No warning messages about RLS
- [ ] No "undefined" or "null" errors
- [ ] App is responsive (no freezing)

### Functionality

- [ ] All tabs accessible
- [ ] All buttons clickable
- [ ] Search works across all tabs
- [ ] Dark mode toggle works
- [ ] Can perform all admin actions

### Data

- [ ] All data loads (no empty screens if data exists)
- [ ] Images load (if URL exists)
- [ ] User names display correctly
- [ ] Dates format correctly

### Security

- [ ] Admin users cannot be deleted
- [ ] Admin users cannot have role changed
- [ ] Role selector only shows user/volunteer
- [ ] Cannot access admin dashboard as non-admin user
- [ ] RLS is enforcing access

---

## 🚨 Troubleshooting Checklist

### Problem: "No data" in dashboard

**Step 1:** Verify admin_roles

```sql
SELECT * FROM public.admin_roles;
```

- [ ] Shows your admin user_id

**Step 2:** If empty, add admin

```sql
INSERT INTO public.admin_roles(user_id, role)
SELECT id FROM public.profiles
WHERE email = 'your-admin@example.com'
ON CONFLICT DO NOTHING;
```

- [ ] Returns "INSERT 0 1"

**Step 3:** Verify check_is_admin works

```sql
SELECT check_is_admin();
```

- [ ] Returns `true` if you're admin

**Step 4:** Restart app

- [ ] Close Flutter app completely
- [ ] Run `flutter clean` in terminal
- [ ] Run `flutter run` to restart

---

### Problem: RLS errors when approving/rejecting

**Step 1:** Verify SQL ran completely

- [ ] Check final lines of output
- [ ] Look for any error messages

**Step 2:** Re-run problem section

```sql
-- From SUPABASE_RLS_AUDIT_FIX.sql, run just:
-- STEP 5: FIX INCONSISTENT POLICY TO CLAUSES
-- STEP 6: VERIFY AND FIX pickup_requests POLICIES
```

**Step 3:** Check policies exist

```sql
SELECT policyname FROM pg_policies
WHERE tablename = 'pickup_requests';
```

- [ ] Shows multiple policies

**Step 4:** Restart app and try again

- [ ] App may need full restart after policy changes

---

### Problem: Admin user not found

**Step 1:** Check profiles table

```sql
SELECT id, email, user_role FROM public.profiles;
```

- [ ] Your admin email should be listed
- [ ] user_role should be 'admin'

**Step 2:** If admin not in profiles

- [ ] You may have logged in as non-admin
- [ ] Log out completely
- [ ] Log in again with admin account
- [ ] Go to Supabase and verify the email

**Step 3:** If still not found

- [ ] Contact system admin
- [ ] May need to create admin account in Supabase

---

### Problem: Indexes not created

**Step 1:** Run manually

```sql
CREATE INDEX IF NOT EXISTS idx_profiles_user_role ON public.profiles(user_role);
CREATE INDEX IF NOT EXISTS idx_ewaste_items_user_id ON public.ewaste_items(user_id);
-- ... (continue for others)
```

**Step 2:** Verify

```sql
SELECT indexname FROM pg_indexes
WHERE tablename IN ('profiles', 'ewaste_items');
```

---

## 📊 Success Criteria - ALL MUST BE TRUE

- [ ] ✅ SQL file ran without errors
- [ ] ✅ admin_roles is populated (≥1 row)
- [ ] ✅ check_is_admin() function exists
- [ ] ✅ profiles RLS is enabled
- [ ] ✅ Flutter app starts without error
- [ ] ✅ Can log in as admin
- [ ] ✅ Admin dashboard loads
- [ ] ✅ All tabs visible and clickable
- [ ] ✅ Dispatch tab shows items (or appropriate empty state)
- [ ] ✅ Users tab shows all users
- [ ] ✅ Volunteers tab visible
- [ ] ✅ Can approve volunteers (no RLS errors)
- [ ] ✅ Can reject volunteers (no RLS errors)
- [ ] ✅ Can change user roles
- [ ] ✅ Can delete non-admin users
- [ ] ✅ Search bar works
- [ ] ✅ Dark mode works
- [ ] ✅ No console errors
- [ ] ✅ No RLS policy errors
- [ ] ✅ All features functional

---

## 🎉 Final Sign-Off

Once all checkboxes are checked:

- [ ] **Deployment Complete** ✅
- [ ] **All Features Working** ✅
- [ ] **No Errors** ✅
- [ ] **Ready for Production** ✅

---

## 📝 NOTES

**Issues Found During Deployment:**
(Write any issues you encountered and how you fixed them)

```
Issue 1: _____________________
Fix: _____________________

Issue 2: _____________________
Fix: _____________________
```

**Date Deployed:** ******\_\_\_\_******  
**Deployed By:** ******\_\_\_\_******  
**Environment:** (Dev/Staging/Production) ******\_\_\_\_******

---

## 🚀 COMPLETION STATUS

**Status: [ ] PENDING [ ] IN PROGRESS [ ] COMPLETE**

**When Complete:**

1. All checkboxes checked
2. All tests pass
3. Admin dashboard fully functional
4. Ready for production use

**Questions?** Refer to:

- `DEPLOYMENT_FINAL_SUMMARY.md`
- `RLS_AUDIT_FIX_ACTION_GUIDE.md`
- `ADMIN_DASHBOARD_SETUP_GUIDE.md`

---

**Expected Time: 10-15 minutes total**

**Difficulty: Easy (follow checklist)**

**Result: Fully Functional Admin Dashboard** 🎯
