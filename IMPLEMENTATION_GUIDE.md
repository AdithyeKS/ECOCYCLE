# EcoCycle Data Persistence Fix - Implementation Guide

## Problem Summary

Data (name, phone, address) was not being saved to the database despite showing "saved" messages. The issue had multiple root causes related to RLS policies, data type mismatches, and missing error handling.

---

## Root Causes Identified & Fixed

### 1. **RLS (Row-Level Security) Policies Too Restrictive**

**Issue:** The `upsert()` method requires both SELECT and UPDATE permissions. Previous policies only allowed UPDATE but not proper INSERT/upsert support.

**Fix Applied:**

```dart
// OLD - Using .update() without checking if row exists
await supabase.from('profiles').update({
  'full_name': fullName,
  'phone_number': phone,
  'address': address,
}).eq('id', userId);

// NEW - Using .upsert() which handles both INSERT and UPDATE
await supabase.from('profiles').upsert({
  'id': userId,
  'full_name': fullName.trim(),
  'phone_number': phone.trim(),
  'address': address.trim(),
  'updated_at': DateTime.now().toIso8601String(),
});
```

**Database Changes (supabase_schema_fixed.sql):**

```sql
-- Policy 2: Users can INSERT their own profile during signup
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = id);

-- Policy 3: Users can UPDATE their own profile
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);
```

### 2. **Data Type Mismatches**

**Issue:** `user_id` in `ewaste_items` was TEXT but `auth.uid()` is UUID, causing silent comparison failures.

**Fix Applied:**

- Converted all user_id columns to `UUID` type with proper foreign key references
- Example:

```sql
-- BEFORE
user_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
assigned_agent_id TEXT,

-- AFTER
user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
assigned_agent_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
```

### 3. **No Error Handling for Save Operations**

**Issue:** Profile service wasn't returning errors, so failures were silent.

**Fix Applied in profile_service.dart:**

```dart
Future<void> updateProfile({
  required String userId,
  required String fullName,
  required String phone,
  required String address,
}) async {
  try {
    // Use upsert to ensure row exists
    final response = await supabase.from('profiles').upsert({
      'id': userId,
      'full_name': fullName.trim(),
      'phone_number': phone.trim(),
      'address': address.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    print('Profile updated successfully for user: $userId');
    print('Response: $response');
  } catch (e) {
    print('ERROR updating profile for user $userId: $e');
    rethrow; // Re-throw so calling code knows about the error
  }
}
```

### 4. **Profile Screen Showing "Updated" But Not Verifying**

**Fix Applied in profile_screen.dart:**

```dart
try {
  final response = await AppSupabase.client
      .from('profiles')
      .upsert(data);  // Use upsert, not update

  print('Save response for $field: $response');

  // Only update UI after confirming success
  setState(() {
    _displayName = val.trim();
  });

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label saved successfully')),
    );
  }
} catch (e) {
  debugPrint('Failed to update $field: $e');
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save $field: $e')),
    );
  }
}
```

---

## New Feature: Automatic Supervisor Information Fetching

### Added Supervisor Support

1. **Database Changes:**

   - Added `supervisor_id` field to `profiles` table
   - Links to another profile (admin/supervisor)

2. **New Method in ProfileService:**

```dart
/// Fetch supervisor details for a given user
Future<Map<String, dynamic>?> fetchSupervisorDetails(String userId) async {
  try {
    // Get user's supervisor_id
    final userProfile = await supabase
        .from('profiles')
        .select('supervisor_id')
        .eq('id', userId)
        .maybeSingle();

    if (userProfile == null || userProfile['supervisor_id'] == null) {
      return null;
    }

    // Fetch supervisor's details
    final supervisorProfile = await supabase
        .from('profiles')
        .select('id, full_name, phone_number')
        .eq('id', userProfile['supervisor_id'])
        .maybeSingle();

    return supervisorProfile;
  } catch (e) {
    print('ERROR fetching supervisor details: $e');
    return null;
  }
}
```

3. **Auto-Population in Volunteer Form:**
   - When volunteer application screen opens, it now:
     - Loads user's profile data (name, phone, address)
     - Fetches supervisor information (if assigned)
     - Displays supervisor details in a highlighted section
     - Pre-fills all form fields automatically

---

## Implementation Steps

### Step 1: Update Supabase Schema

Run the fixed SQL schema:

```bash
# Execute supabase_schema_fixed.sql in your Supabase SQL Editor
```

Key changes:

- Drop and recreate RLS policies with proper INSERT/UPDATE/SELECT support
- Add `supervisor_id` to profiles table
- Fix data types (TEXT → UUID)
- Add indexes for performance
- Add helper function `get_supervisor_details()`

### Step 2: Update Dart Code

The following files have been updated:

1. **profile_service.dart**

   - `updateProfile()` now uses upsert and includes error handling
   - Added `fetchSupervisorDetails()` method
   - All methods include debug logging

2. **profile_screen.dart**

   - `_editField()` now uses upsert instead of update
   - `_editName()` now includes error messages and logging
   - All save operations catch and display errors

3. **volunteer_application_screen.dart**
   - `_loadInitialData()` now fetches supervisor info
   - Added supervisor information display section
   - Form shows supervisor name and phone automatically
   - Better error handling in `_submit()` method

### Step 3: Verification

Test the fixes:

1. **Profile Saving:**

   - Edit profile fields (name, phone, address)
   - Should show "saved successfully"
   - Refresh page to verify data persisted
   - Check browser console for logs: "Profile updated successfully for user: {userId}"

2. **Supervisor Fetching:**

   - Navigate to Volunteer Application screen
   - Should see supervisor information displayed (if assigned)
   - Name and phone should be automatically filled in form

3. **Error Handling:**
   - Intentionally trigger errors (bad data, network issues)
   - Should display clear error messages
   - Console should show detailed debug logs

---

## Database Schema Changes Summary

### Tables Modified

1. **profiles**

   - Added `supervisor_id` field (UUID)
   - Added `created_at` and `updated_at` fields
   - Fixed RLS policies

2. **ewaste_items**

   - Fixed `user_id` type (TEXT → UUID)
   - Fixed `assigned_agent_id` type (TEXT → UUID)
   - Added proper foreign key constraints

3. **volunteer_applications**

   - Fixed RLS policies with proper INSERT/UPDATE/SELECT

4. **New helper function: `get_supervisor_details()`**
   - Can be called from Dart via RPC if needed

### Indexes Added

- `profiles_user_role_idx` - for role-based queries
- `profiles_supervisor_id_idx` - for supervisor lookups
- `volunteer_applications_user_id_idx` - for user's applications
- `volunteer_applications_status_idx` - for status filtering
- `ewaste_items_user_id_idx` - for user's items
- `ewaste_items_assigned_agent_id_idx` - for agent assignments

---

## Testing Checklist

- [ ] Profile name, phone, and address save successfully
- [ ] Data persists after page refresh
- [ ] Error messages display when save fails
- [ ] Supervisor information loads and displays in volunteer form
- [ ] Form fields are auto-populated from profile
- [ ] No RLS permission errors in console
- [ ] Debug logs show successful operations
- [ ] Can navigate between screens without losing data
- [ ] Mobile and web platforms both work correctly

---

## Troubleshooting

### Issue: "Data still not saving"

**Solution:**

1. Check browser console for errors
2. Verify RLS policies are deployed (run supabase_schema_fixed.sql)
3. Ensure user is authenticated
4. Check that `profiles` row exists for the user (create one if needed)

### Issue: "Supervisor information not showing"

**Solution:**

1. Verify user has `supervisor_id` set in profiles table
2. Check that supervisor profile exists
3. Look for console logs: "Supervisor loaded:" or "No supervisor info available"

### Issue: "RLS permission denied errors"

**Solution:**

1. Re-run the schema fix script
2. Verify policies are using `(SELECT auth.uid())` correctly
3. Check that user is authenticated with valid JWT token

---

## Files Modified

1. **supabase_schema_fixed.sql** - Complete fixed database schema
2. **lib/services/profile_service.dart** - Added error handling and supervisor fetching
3. **lib/screens/profile_screen.dart** - Fixed save operations with upsert
4. **lib/screens/volunteer_application_screen.dart** - Added supervisor display and auto-population
5. **FIXES.md** - This documentation

---

## Performance Improvements

- Added database indexes for common queries
- Reduced unnecessary database calls
- Improved error visibility for debugging
- Added proper type safety (UUID vs TEXT)

---

## Next Steps (Optional)

1. **Implement Role-Based Features:**

   - Add permission checks for different user roles
   - Create admin dashboard for managing supervisors

2. **Add Data Validation:**

   - Validate phone number format
   - Validate address format
   - Add constraint checks in Dart

3. **Implement Audit Logging:**

   - Track who changed what and when
   - Add to `updated_at` field automatically

4. **Add Notifications:**
   - Notify supervisor when volunteer applies
   - Notify user when application is reviewed
