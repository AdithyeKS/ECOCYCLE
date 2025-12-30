# EcoCycle Data Flow Diagram - After Fixes

## Data Saving Flow (Profile Screen)

```
User edits profile
       ↓
   Form Input
       ↓
Click "Save"
       ↓
   _editField() or _editName()
       ↓
   profile_service.updateProfile()
       ↓
   Supabase: .upsert() ← FIXED: Now uses upsert instead of update
       ↓
   RLS Policy Check
   ├─ FOR INSERT: (SELECT auth.uid()) = id ✓ FIXED: Now has INSERT permission
   └─ FOR UPDATE: (SELECT auth.uid()) = id WITH CHECK ✓ FIXED: Added WITH CHECK
       ↓
   Database Insert/Update
   ├─ full_name: TEXT
   ├─ phone_number: TEXT
   ├─ address: TEXT
   └─ updated_at: TIMESTAMP
       ↓
   Error Handling ✓ FIXED: Now catches and logs errors
   ├─ Success: Show "saved successfully" + log
   └─ Error: Show detailed error message + log
       ↓
   Update UI locally
       ↓
   Data persisted ✓
```

## Supervisor Information Flow (Volunteer Application Screen)

```
Open Volunteer Application Screen
       ↓
   _loadInitialData()
       ├─ Fetch user profile (name, phone, address)
       │  ├─ full_name ✓
       │  ├─ phone_number ✓
       │  └─ address ✓
       │
       └─ Fetch supervisor info ✓ NEW FEATURE
          ├─ Get supervisor_id from profiles ✓ FIXED: Added field
          │
          └─ If supervisor exists:
             ├─ Query profiles table for supervisor_id
             ├─ Fetch: full_name, phone_number
             └─ Store in _supervisorName, _supervisorPhone
       ↓
   Display Form
   ├─ User Info Section (auto-populated)
   │  ├─ Name: [pre-filled from profile]
   │  ├─ Phone: [pre-filled from profile]
   │  └─ Address: [pre-filled from profile]
   │
   └─ Supervisor Section ✓ NEW
      ├─ Title: "Supervisor Information"
      ├─ Supervisor Name: [auto-populated if available]
      └─ Supervisor Phone: [auto-populated if available]
       ↓
   User completes form
       ↓
   Submit Application
       ↓
   _submit()
       ├─ Create VolunteerApplication object
       └─ Call submitVolunteerApplication()
           ├─ Update profile (name, phone, address)
           ├─ Insert volunteer_applications row
           └─ Update volunteer_requested_at
       ↓
   Success message
```

## Database Relationships (After Fixes)

```
auth.users
│
├─ FOREIGN KEY → profiles.id
│
      profiles
      │
      ├─ id: UUID (PRIMARY KEY, FK to auth.users)
      ├─ full_name: TEXT
      ├─ phone_number: TEXT
      ├─ address: TEXT
      ├─ user_role: TEXT
      ├─ supervisor_id: UUID (FK to profiles.id) ✓ NEW
      ├─ total_points: INTEGER
      └─ volunteer_requested_at: TIMESTAMP
      │
      ├─ FOREIGN KEY → ewaste_items.user_id ✓ FIXED: UUID type
      ├─ FOREIGN KEY → volunteer_applications.user_id
      └─ FOREIGN KEY (supervisor_id) → profiles.id ✓ NEW

      ewaste_items
      │
      ├─ id: UUID (PRIMARY KEY)
      ├─ user_id: UUID (FK to auth.users) ✓ FIXED: Type corrected
      ├─ assigned_agent_id: UUID (FK to profiles) ✓ FIXED: Type corrected
      └─ ...other fields

      volunteer_applications
      │
      ├─ id: UUID (PRIMARY KEY)
      ├─ user_id: UUID (FK to auth.users)
      ├─ full_name: TEXT
      ├─ phone: TEXT
      ├─ address: TEXT
      └─ status: TEXT

      pickup_requests
      │
      ├─ id: UUID (PRIMARY KEY)
      ├─ agent_id: UUID (FK to profiles) ✓ FIXED: Proper type
      └─ ...other fields
```

## RLS Policy Coverage (After Fixes)

```
profiles table
├─ SELECT: Users can view own profile ✓
├─ INSERT: Users can insert own profile ✓ FIXED: Added
├─ UPDATE: Users can update own profile ✓ FIXED: Added WITH CHECK
├─ SELECT: Admins can view all profiles ✓
└─ UPDATE: Admins can update all profiles ✓

ewaste_items table
├─ SELECT: Users can view own items ✓
├─ INSERT: Users can insert own items ✓ FIXED: Fixed type
├─ UPDATE: Users can update own items ✓ FIXED: Fixed type
├─ SELECT: Agents can view assigned items ✓
├─ SELECT: Admins can view all items ✓
└─ UPDATE: Admins can update all items ✓

volunteer_applications table
├─ SELECT: Users can view own applications ✓
├─ INSERT: Users can insert own applications ✓ FIXED: Added
├─ UPDATE: Users can update own applications ✓ FIXED: Added
├─ SELECT: Admins can view all applications ✓
└─ UPDATE: Admins can update applications ✓
```

## Error Handling Flow (After Fixes)

```
Save Operation
│
├─ Try Block
│  ├─ Call supabase.upsert()
│  ├─ Log success: "Profile updated successfully for user: {id}"
│  └─ Update UI: Show "saved successfully" ✓ NEW
│
└─ Catch Block ✓ FIXED: Added comprehensive error handling
   ├─ Log error: "ERROR updating profile for user {id}: {error}"
   ├─ Show UI error: "Failed to save: {error message}"
   └─ Re-throw for calling code to handle ✓ NEW: Propagates errors
```

## Type Safety Corrections

```
BEFORE (Causing silent failures):
├─ user_id: UUID (auth.uid() type)
├─ compared with user_id in DB: TEXT ✗
└─ Result: Type mismatch, silent query failure

AFTER (All consistent):
├─ user_id: UUID (auth.uid() type)
├─ user_id in DB: UUID ✓
├─ assigned_agent_id: UUID ✓
└─ Result: Proper comparison, predictable queries
```

## Key Improvements Summary

| Component       | Before          | After        | Impact                   |
| --------------- | --------------- | ------------ | ------------------------ |
| Upsert Handling | update().eq()   | .upsert()    | Works on new rows        |
| RLS INSERT      | ✗ Missing       | ✓ Added      | Can create profiles      |
| RLS WITH CHECK  | ✗ Missing       | ✓ Added      | Proper permission checks |
| Data Types      | TEXT/UUID mixed | All UUID     | No type errors           |
| Error Handling  | Silent          | Logged + UI  | Visibility               |
| Supervisor Info | N/A             | Auto-fetch   | Auto-populated forms     |
| Debugging       | Hard            | Console logs | Easy troubleshooting     |

## Testing Verification Checklist

```
✓ Profile saves
  ├─ Edit name → "saved successfully"
  ├─ Edit phone → "saved successfully"
  ├─ Edit address → "saved successfully"
  └─ Refresh page → Data persists

✓ Supervisor info loads
  ├─ Open volunteer form
  ├─ Should display supervisor section
  ├─ Shows supervisor name
  └─ Shows supervisor phone

✓ Error handling works
  ├─ Disconnect network → Error shows
  ├─ Console shows logs
  └─ UI shows error message

✓ No RLS errors
  ├─ Browser console: No permission denied
  ├─ Supabase logs: No policy violations
  └─ Database: All operations succeed
```
