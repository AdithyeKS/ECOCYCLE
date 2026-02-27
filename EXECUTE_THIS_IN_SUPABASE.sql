-- ============================================================================
-- SUPABASE SQL FIX - NGO TABLE MISSING COLUMNS
-- ============================================================================
-- Error: PostgresException(message: Could not find the 'contact_info' 
--        column of 'ngos' in the schema cache, code: PGRST204)
--
-- This script adds the 3 missing columns to the ngos table.
-- It is safe to run multiple times (uses IF NOT EXISTS).
-- ============================================================================

-- Step 1: Add contact_info column
ALTER TABLE ngos 
ADD COLUMN IF NOT EXISTS contact_info TEXT;

-- Step 2: Add waste_types column (array of text)
ALTER TABLE ngos 
ADD COLUMN IF NOT EXISTS waste_types TEXT[];

-- Step 3: Add district column with default value
ALTER TABLE ngos 
ADD COLUMN IF NOT EXISTS district TEXT DEFAULT 'Unknown';

-- ============================================================================
-- VERIFICATION - Run these queries to confirm the fix
-- ============================================================================

-- Check that all columns exist and are correct type
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'ngos'
ORDER BY ordinal_position;

-- ============================================================================
-- Optional: Update existing NGO records with default values
-- ============================================================================
-- Uncomment below if you want to backfill existing records

/*
UPDATE ngos 
SET 
  district = COALESCE(district, 'Unknown'),
  contact_info = COALESCE(contact_info, phone || ' | ' || email),
  waste_types = COALESCE(waste_types, ARRAY['Electronics', 'General Waste'])
WHERE district IS NULL 
  OR contact_info IS NULL 
  OR waste_types IS NULL;
*/

-- ============================================================================
-- FINAL CHECK - View all NGOs with the new columns
-- ============================================================================

SELECT 
  id,
  name,
  district,
  contact_info,
  waste_types,
  phone,
  email,
  is_government_approved,
  created_at,
  updated_at
FROM ngos
ORDER BY created_at DESC;

-- ============================================================================
-- SUCCESS! The ngos table now has all required columns.
-- You can now add and edit NGOs without errors.
-- ============================================================================
