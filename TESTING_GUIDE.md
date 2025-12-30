# Testing & Verification Guide

## Pre-Deployment Testing

### Step 1: Backup Current Data

```sql
-- Backup existing profiles
SELECT * FROM profiles LIMIT 100;

-- Save the output or create a backup table
CREATE TABLE profiles_backup AS SELECT * FROM profiles;
```

### Step 2: Deploy the Fixed Schema

1. Open Supabase Dashboard → SQL Editor
2. Copy contents of `supabase_schema_fixed.sql`
3. Paste and execute
4. Look for completion without errors

### Step 3: Verify RLS Policies

```sql
-- Should show 5 policies for profiles table
SELECT policyname, cmd, USING, WITH_CHECK
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY policyname;

-- Expected output:
-- "Admins can update all profiles" | UPDATE
-- "Admins can view all profiles" | SELECT
-- "Users can insert own profile" | INSERT ← NEW
-- "Users can update own profile" | UPDATE (with WITH CHECK) ← FIXED
-- "Users can view own profile" | SELECT
```

### Step 4: Verify Data Types

```sql
-- Check profiles table
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'profiles'
ORDER BY column_name;

-- Expected to see:
-- address | text
-- full_name | text
-- id | uuid
-- phone_number | text
-- supervisor_id | uuid ← NEW
-- total_points | integer
-- user_role | text
-- volunteer_requested_at | timestamp with time zone
-- created_at | timestamp with time zone ← NEW
-- updated_at | timestamp with time zone ← NEW

-- Check ewaste_items table
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'ewaste_items'
  AND column_name IN ('user_id', 'assigned_agent_id')
ORDER BY column_name;

-- Expected:
-- assigned_agent_id | uuid ← FIXED (was TEXT)
-- user_id | uuid ← FIXED (was TEXT)
```

---

## Post-Deployment Testing

### Test 1: Profile Saving (Local Testing)

#### 1.1 Profile Name Update

```
1. Open app and login
2. Navigate to Profile screen
3. Click edit name button
4. Change name to "Test Name [timestamp]"
5. Click Save
6. Should see: "Name saved successfully" ✓
7. Console should show: "Name save response: [...]" ✓
8. Refresh page
9. Name should persist ✓
10. Not "null" or reverted ✓
```

#### 1.2 Profile Phone Update

```
1. Still on Profile screen
2. Click edit phone button
3. Enter phone: "1234567890"
4. Click Save
5. Should see: "Phone saved successfully" ✓
6. Console should show: "Save response for phone: [...]" ✓
7. Refresh page
8. Phone should be "1234567890" ✓
```

#### 1.3 Profile Address Update

```
1. Still on Profile screen
2. Click edit address button
3. Enter address: "123 Test St, Test City"
4. Click Save
5. Should see: "Address saved successfully" ✓
6. Console should show: "Save response for address: [...]" ✓
7. Refresh page
8. Address should be "123 Test St, Test City" ✓
```

#### 1.4 Error Handling Test

```
1. Open browser DevTools: F12
2. Go to Network tab
3. Make profile change
4. Switch network to "Offline"
5. Try to save
6. Should see: "Failed to save [field]: [error message]" ✓
7. Console should show: "ERROR updating profile for user [id]: [error]" ✓
8. Switch back online
```

### Test 2: Supervisor Information (Advanced Testing)

#### 2.1 Setup: Assign a Supervisor (Admin only)

```sql
-- First, identify user and admin IDs
SELECT id, full_name, user_role FROM profiles LIMIT 10;

-- Assign a supervisor to a user
UPDATE profiles
SET supervisor_id = '[ADMIN_ID]'  -- UUID of admin/supervisor
WHERE id = '[USER_ID]';  -- UUID of regular user

-- Verify
SELECT id, full_name, supervisor_id FROM profiles
WHERE id = '[USER_ID]';
```

#### 2.2 Test Supervisor Auto-Population

```
1. Login as the regular user (who has supervisor_id set)
2. Navigate to Volunteer Application screen
3. Should see loading indicator briefly
4. Should display "Supervisor Information" section ✓
5. Should show supervisor's name ✓
6. Should show supervisor's phone ✓
7. Console should show: "Supervisor loaded: [name] ([phone])" ✓
```

#### 2.3 Test Form Pre-population

```
1. Still on Volunteer Application screen
2. Should see:
   - "Your Name" pre-filled with user's name ✓
   - "Contact Number" pre-filled with user's phone ✓
   - Address field in form (if exists) ✓
   - "Supervisor Information" section visible ✓
   - Supervisor name populated ✓
   - Supervisor phone populated ✓
```

#### 2.4 Test Volunteer Application Submission

```
1. Complete the form:
   - Name: [already filled]
   - Phone: [already filled]
   - Date: Select a date
   - Motivation: Enter motivation
   - Agree to policy: Check checkbox
2. Click "SUBMIT VOLUNTEER REQUEST"
3. Should see success message ✓
4. Navigation should go back
5. Database should have new record
```

### Test 3: Database Verification

#### 3.1 Check Profile Data Persisted

```sql
SELECT id, full_name, phone_number, address, updated_at
FROM profiles
WHERE id = '[USER_ID]'
ORDER BY updated_at DESC
LIMIT 1;

-- Should show the updated values and recent timestamp
```

#### 3.2 Check Supervisor Reference

```sql
SELECT
  p.id,
  p.full_name,
  p.supervisor_id,
  s.full_name as supervisor_name,
  s.phone_number as supervisor_phone
FROM profiles p
LEFT JOIN profiles s ON p.supervisor_id = s.id
WHERE p.id = '[USER_ID]';

-- Should show supervisor details if supervisor_id is set
```

#### 3.3 Check Volunteer Application

```sql
SELECT
  id,
  user_id,
  full_name,
  phone,
  address,
  status,
  created_at
FROM volunteer_applications
WHERE user_id = '[USER_ID]'
ORDER BY created_at DESC
LIMIT 1;

-- Should show the submitted application
```

### Test 4: RLS Permission Testing

#### 4.1 Test User Can View Own Profile

```sql
-- As authenticated user (use Supabase RLS context)
SELECT * FROM profiles WHERE id = auth.uid();

-- Should return their own profile ✓
```

#### 4.2 Test User Cannot View Others' Profiles

```sql
-- As authenticated user
SELECT * FROM profiles WHERE id != auth.uid() LIMIT 1;

-- Should return 0 rows or empty ✓
```

#### 4.3 Test Admin Can View All Profiles

```sql
-- As admin user (check_is_admin() returns true)
SELECT * FROM profiles LIMIT 10;

-- Should return multiple profiles ✓
```

---

## Automated Testing Checklist

| Test               | Command                                             | Expected                | Status |
| ------------------ | --------------------------------------------------- | ----------------------- | ------ |
| Schema deployed    | Run `supabase_schema_fixed.sql`                     | No errors               | [ ]    |
| RLS policies exist | Query pg_policies                                   | 5 policies for profiles | [ ]    |
| Data types fixed   | Query information_schema.columns                    | All UUIDs               | [ ]    |
| Supervisor field   | SELECT supervisor_id FROM profiles                  | Column exists           | [ ]    |
| Indexes created    | SELECT \* FROM pg_indexes WHERE schemaname='public' | 6+ indexes              | [ ]    |
| INSERT permission  | INSERT INTO profiles (id, full_name)                | Success                 | [ ]    |
| UPDATE permission  | UPDATE profiles SET full_name WHERE id              | Success                 | [ ]    |
| Upsert works       | UPSERT profiles                                     | Insert or update        | [ ]    |

---

## Debugging Guide

### Issue: "Failed to save: RLS policy violation"

**Solution:**

1. Verify RLS policies were deployed
2. Run: `SELECT * FROM pg_policies WHERE tablename = 'profiles';`
3. Check that user is authenticated
4. Verify user's UUID matches the id column

### Issue: "Profile saved successfully" but data not persisting

**Solution:**

1. Check browser console: `F12 → Console`
2. Look for error messages
3. Check Supabase logs: Dashboard → Logs
4. Verify profile row exists (create if needed):

```sql
INSERT INTO profiles (id, full_name, total_points)
VALUES (auth.uid(), 'User', 0)
ON CONFLICT (id) DO NOTHING;
```

### Issue: "Supervisor information not showing"

**Solution:**

1. Check console logs: Look for "Supervisor loaded:" or "No supervisor info"
2. Verify user has supervisor_id:

```sql
SELECT supervisor_id FROM profiles WHERE id = auth.uid();
```

3. Verify supervisor exists:

```sql
SELECT id, full_name, phone_number FROM profiles
WHERE id = (SELECT supervisor_id FROM profiles WHERE id = auth.uid());
```

### Issue: "Type mismatch" errors

**Solution:**

1. Verify data types:

```sql
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'ewaste_items'
  AND column_name IN ('user_id', 'assigned_agent_id');
```

2. Should both be `uuid`, not `text`
3. Re-run schema fix if needed

---

## Browser Console Monitoring

**Open DevTools:** Press `F12`

**Look for these logs (indicate success):**

```javascript
// Profile save
"Profile updated successfully for user: 12345678-...";
"Save response for phone: {...}";
"Name save response: {...}";

// Supervisor info
"Supervisor loaded: John Doe (555-1234)";
"Supervisor details fetched: {id: '...', full_name: 'John', phone_number: '555-1234'}";
```

**Look for these logs (indicate errors):**

```javascript
// Profile save error
"ERROR updating profile for user 12345678-...: RLS policy violation";

// Supervisor error
"No supervisor found for user: 12345678-...";
"ERROR fetching supervisor details: [error message]";
```

---

## Performance Testing

### Query Performance

```sql
-- Should complete in <100ms
SELECT * FROM profiles WHERE id = auth.uid();

-- Should complete in <100ms
SELECT * FROM profiles WHERE user_role = 'admin';

-- Should complete in <100ms
SELECT * FROM profiles WHERE supervisor_id IS NOT NULL;
```

### Index Verification

```sql
-- Should show all indexes are VALID
SELECT indexname, indexdef FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY indexname;
```

---

## Rollback Plan (if needed)

```bash
# 1. Restore from backup
psql -U postgres -d ecocycle -f backup.sql

# 2. Revert Dart code changes (use git)
git checkout lib/services/profile_service.dart
git checkout lib/screens/profile_screen.dart
git checkout lib/screens/volunteer_application_screen.dart

# 3. Rebuild app
flutter clean
flutter pub get
flutter run
```

---

## Success Indicators ✓

After testing, you should have:

- ✓ All three profile fields (name, phone, address) saving successfully
- ✓ Data persisting across page refreshes
- ✓ Clear success/error messages in UI
- ✓ Console logs showing successful operations
- ✓ Supervisor information auto-displaying in volunteer form
- ✓ No RLS permission errors
- ✓ All database queries completing quickly
- ✓ No data type errors

---

## Final Verification

Run this final query to confirm everything is working:

```sql
-- Comprehensive verification
SELECT
  'Profiles table' as check_item,
  COUNT(*) as record_count,
  MAX(updated_at) as last_update
FROM profiles
UNION ALL
SELECT
  'Volunteer applications',
  COUNT(*),
  MAX(created_at)
FROM volunteer_applications
UNION ALL
SELECT
  'RLS policies on profiles',
  COUNT(*),
  NULL
FROM pg_policies
WHERE tablename = 'profiles';

-- If all look good, deployment is successful!
```

---

## Support

If issues persist:

1. Check CRITICAL_FIXES_REFERENCE.sql for exact changes
2. Review IMPLEMENTATION_GUIDE.md for detailed explanations
3. Check browser console logs
4. Check Supabase dashboard logs
5. Verify all schema changes were applied
