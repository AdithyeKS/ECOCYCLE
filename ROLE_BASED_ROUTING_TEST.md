# 🧪 Role-Based Routing Verification Checklist

## Pre-Test Requirements

- [ ] Database schema executed (supabase_schema_production.sql)
- [ ] All code changes applied
- [ ] App rebuilt with `flutter clean && flutter pub get && flutter run`

---

## Test 1: Signup with Role Selection ✅

### Steps:

1. Launch app → Click "Sign Up"
2. Fill in details:
   - Name: `Test Agent`
   - Phone: `9876543210`
   - Email: `agent@test.com`
   - Password: `SecurePass123!`
3. **Click "Complete Profile"** to reach role selection screen
4. Verify you see:
   - ✅ "Select Your Role" heading
   - ✅ Info box with three roles explained
   - ✅ Dropdown showing "Regular User" as default
5. **Select "Pickup Agent"** from dropdown
6. Click "Save Profile & Continue"

### Expected Outcome:

- ✅ Debug console shows: `✅ Saving profile with role: agent`
- ✅ Routed to **Agent Dashboard** (not user dashboard)
- ✅ App shows agent-specific UI

### Database Verification:

```sql
SELECT id, full_name, user_role FROM profiles WHERE full_name = 'Test Agent';
```

Expected: `user_role = 'agent'`

---

## Test 2: Signup with Different Roles

### Test 2a: Volunteer Role

1. Sign up again with different email
2. Name: `Test Volunteer`
3. **Select "Volunteer"** from role dropdown
4. Save

### Expected:

- ✅ Routes to volunteer interface
- ✅ DB shows `user_role = 'volunteer'`

### Test 2b: Regular User Role

1. Sign up again
2. Name: `Test User`
3. **Leave as "Regular User"** (default)
4. Save

### Expected:

- ✅ Routes to regular user dashboard with bottom nav bar
- ✅ DB shows `user_role = 'user'`

---

## Test 3: Login After Logout

### Steps:

1. Complete signup as Agent
2. Go to Settings → Logout
3. Login with same credentials
4. Verify redirected to Agent Dashboard

### Debug Console Check:

```
--- USER ROLE FETCHED: agent ---
```

---

## Test 4: Edit Profile - Role Persistence

### Steps:

1. Go to Settings → Edit Profile
2. Change name or phone
3. Note: Role dropdown should show currently saved role
4. **Leave role as is** or change it
5. Save

### Expected:

- ✅ Role persists (if not changed)
- ✅ New role takes effect (if changed)
- ✅ Correct dashboard shows after save

---

## Test 5: Admin User (Manual DB Update)

Since there's no admin signup flow, manually set a user as admin:

### Steps:

1. Sign up normally as any user
2. In Supabase SQL Editor:

```sql
UPDATE profiles
SET user_role = 'admin'
WHERE full_name = 'Your Name';
```

3. Logout and login
4. Verify routed to **Admin Dashboard**

### Debug:

```
--- USER ROLE FETCHED: admin ---
```

---

## Test 6: Error Handling

### Test 6a: Missing Role (NULL)

If `user_role` is NULL in DB:

- ✅ Should default to 'user'
- ✅ No crashes

### Test 6b: Invalid Role (TYPO)

```sql
UPDATE profiles SET user_role = 'invalid_role' WHERE id = '<user-id>';
```

- ✅ Should default to 'user'
- ✅ No crashes

---

## Test 7: RLS Security Check

Verify Row-Level Security is working:

### Steps:

1. Login as User A (regular user)
2. Try to access User B's data through app:
   - Open profile edit
   - Try network intercept to modify someone else's ID
3. Verify: 403 Forbidden from Supabase

### Console Log Indicators:

- User A sees only own profile
- User A cannot modify other profiles

---

## Debug Output Expected

During entire flow, watch for:

```
✅ Saving profile with role: agent          (After profile save)
--- USER ROLE FETCHED: agent ---             (After login)
```

NO errors like:

```
ERROR: infinite recursion detected in policy
ERROR: column "user_role" does not exist
FAILED: type mismatches
```

---

## Success Criteria ✅

| Test                       | Status | Notes                           |
| -------------------------- | ------ | ------------------------------- |
| Signup shows role dropdown | ✅     | All three roles visible         |
| Save includes user_role    | ✅     | Debug shows role being saved    |
| Login fetches correct role | ✅     | Dashboard routing works         |
| Agent route works          | ✅     | Agent Dashboard loads           |
| Volunteer route works      | ✅     | Volunteer interface shows       |
| User route works           | ✅     | Bottom nav bar visible          |
| Role persistence           | ✅     | After logout/login              |
| Error handling             | ✅     | Defaults to user on error       |
| No infinite recursion      | ✅     | Database completes queries      |
| RLS enforced               | ✅     | Users can't access others' data |

---

## Troubleshooting

### Issue: Always routes to User Dashboard

**Check:**

1. Is `user_role` being saved?
   ```sql
   SELECT * FROM profiles WHERE email = 'your@email.com';
   ```
2. Is role fetching failing silently?
   - Add more `debugPrint()` statements
   - Check Android Studio console for errors

### Issue: "Infinite Recursion" Error

**Solution:**

- Schema not executed correctly
- Re-run: `supabase_schema_production.sql`
- Verify `check_is_admin()` has `SET row_security = OFF`

### Issue: Role Dropdown Not Visible

**Check:**

- File: `profile_completion_screen.dart` lines 230-280
- Verify UI code is present
- Check Material version compatibility

### Issue: Database Role is NULL

**Fix:**

```sql
UPDATE profiles
SET user_role = 'user'
WHERE user_role IS NULL;
```

---

## Final Checklist

- [ ] All three roles route to correct dashboards
- [ ] Debug output shows role being saved and fetched
- [ ] No infinite recursion errors
- [ ] Role persists after logout/login
- [ ] Error handling works (defaults to user)
- [ ] No RLS violations (users can't access others)
- [ ] UI shows role dropdown on profile completion
- [ ] Dropdown persists selected value on edit

---

**Status: Ready for Testing** ✅

Once all tests pass, the role-based routing is fully functional!
