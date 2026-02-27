# NGO Table Column Missing - FIX GUIDE

## ⚠️ Problem

**Error**: `PostgresException(message: Could not find the 'contact_info' column of 'ngos' in the schema cache, code: PGRST204...)`

This happens when you try to add or edit NGO records because your Supabase **ngos table is missing columns** that your Dart code expects.

---

## 📋 Root Cause

The `ngos` table in your Supabase database is missing these columns:

- `contact_info` (TEXT) - for storing contact information
- `waste_types` (TEXT[]) - array of waste types the NGO accepts
- `district` (TEXT) - geographic district information

Your Dart `Ngo` model and UI forms are trying to save data to these columns, but they don't exist in the database.

---

## ✅ Solution

### Step 1: Run the Database Migration SQL

Execute this SQL in your **Supabase SQL Editor** (`project > SQL Editor > New Query`):

```sql
-- Add missing columns to NGOs table
ALTER TABLE ngos
ADD COLUMN IF NOT EXISTS contact_info TEXT;

ALTER TABLE ngos
ADD COLUMN IF NOT EXISTS waste_types TEXT[];

ALTER TABLE ngos
ADD COLUMN IF NOT EXISTS district TEXT DEFAULT 'Unknown';

-- Verify the changes
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'ngos'
ORDER BY ordinal_position;
```

**File provided**: `FIX_NGO_TABLE_COLUMNS.sql` - Use this for reference

### Step 2: Update Your Code (Already Done ✓)

The `ngo_management_screen.dart` has been updated to include form fields for:

- ✅ `district` (required field)
- ✅ `waste_types` (comma-separated input)
- ✅ `contactInfo` (free text)

These now match the `admin_dashboard.dart` implementation.

---

## 📊 Table Structure After Fix

Your `ngos` table will now have:

```
Column Name              | Data Type | Nullable | Default
------------------------+-----------+----------+----------
id                      | uuid      | NO       | gen_random_uuid()
name                    | text      | NO       | -
description             | text      | YES      | -
address                 | text      | NO       | -
phone                   | text      | YES      | -
email                   | text      | YES      | -
is_government_approved  | boolean   | YES      | true
latitude                | double    | YES      | -
longitude               | double    | YES      | -
created_at              | timestamp | YES      | NOW()
updated_at              | timestamp | YES      | NOW()
contact_info            | text      | YES      | -         [NEW]
waste_types             | text[]    | YES      | -         [NEW]
district                | text      | YES      | 'Unknown' [NEW]
```

---

## 🔄 How It Works Now

### Creating an NGO:

1. User fills form in `ngo_management_screen.dart`
2. Form captures: name, district, address, waste_types, contact_info, phone, email
3. Data is saved to database via `EwasteService.addNgo()`
4. All columns now exist in the database ✓

### Editing an NGO:

1. Edit form (in admin_dashboard) loads existing data
2. User updates fields
3. Changes are saved via `EwasteService.updateNgo()`
4. No "column not found" errors ✓

---

## 🧪 Verification Steps

After running the SQL migration:

1. **Check column exists**:

   ```sql
   SELECT contact_info, waste_types, district FROM ngos LIMIT 1;
   ```

   ✓ Should return columns without errors

2. **Try adding an NGO**:
   - Open your app
   - Go to NGO management
   - Click "Add NGO"
   - Fill in all fields (including District, Waste Types, Contact Info)
   - Click "Add NGO"
   - Should succeed without "contact_info not found" error

3. **Check the data**:
   ```sql
   SELECT id, name, district, contact_info, waste_types FROM ngos;
   ```
   ✓ Should show your new NGO with all fields

---

## 📝 Code Changes Summary

### Files Modified:

1. **ngo_management_screen.dart** - Updated AddNgoDialog to include missing form fields
2. **Database** - Added missing columns to ngos table (via FIX_NGO_TABLE_COLUMNS.sql)

### What Changed:

- ✅ Added `district` field (required) to AddNgoDialog
- ✅ Added `wasteTypes` field (comma-separated) to AddNgoDialog
- ✅ Added `contactInfo` field to AddNgoDialog
- ✅ Updated form submission to include these fields
- ✅ Database columns now exist to store this data

---

## 🚀 Next Steps

1. Run the SQL migration from `FIX_NGO_TABLE_COLUMNS.sql`
2. Reload your app or restart the development server
3. Try adding/editing an NGO record
4. All errors should be resolved!

---

## 💡 Why This Happened

The Dart `Ngo` model was defined to support all these fields:

```dart
final String? contactInfo;
final List<String>? wasteTypes;
final String district;
```

But the database table didn't have the columns to match. When Supabase tried to insert/update data with these fields, it failed because the columns didn't exist.

Now everything is aligned! ✓

---

## 📞 If You Still Get Errors

If you still see the error after the fix:

1. **Clear app cache**:

   ```bash
   flutter clean
   flutter pub get
   ```

2. **Restart the app** in debug mode

3. **Verify SQL was applied**:

   ```sql
   \d ngos  -- Shows table structure
   ```

4. **Check RLS Policies**: Make sure you have proper INSERT/UPDATE permissions on the ngos table for your user role

---

**Status**: ✅ **COMPLETE** - Ready to test!
