-- ============================================================================
-- FIX: Add Missing Columns to NGOs Table
-- ============================================================================
-- Error: Could not find the 'contact_info' column of 'ngos' in the schema cache
-- 
-- The ngos table is missing the following columns that the Dart code expects:
-- - contact_info (TEXT)
-- - waste_types (TEXT[])
-- - district (TEXT)
--
-- This script adds these missing columns safely (idempotent)
-- ============================================================================

-- 1. Add contact_info column (if not exists)
ALTER TABLE ngos 
ADD COLUMN IF NOT EXISTS contact_info TEXT;

-- 2. Add waste_types column (if not exists) - array of strings
ALTER TABLE ngos 
ADD COLUMN IF NOT EXISTS waste_types TEXT[];

-- 3. Add district column (if not exists) - for location organization
ALTER TABLE ngos 
ADD COLUMN IF NOT EXISTS district TEXT DEFAULT 'Unknown';

-- 4. Verify the table structure
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'ngos'
ORDER BY ordinal_position;

-- ============================================================================
-- OPTIONAL: Update existing NGO records with sample data
-- ============================================================================
-- Uncomment the following if you want to populate districts and contact info

/*
UPDATE ngos 
SET district = 'Main District',
    waste_types = ARRAY['Electronics', 'Computers', 'Phones'],
    contact_info = phone || ' | ' || email
WHERE district IS NULL OR district = 'Unknown';
*/

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- Count of NGOs in the table
SELECT COUNT(*) as total_ngos FROM ngos;

-- Show all NGO records with the new columns
SELECT 
  id,
  name,
  district,
  address,
  contact_info,
  waste_types,
  is_government_approved,
  created_at
FROM ngos
ORDER BY created_at DESC;
