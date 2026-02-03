-- ============================================================================
-- MIGRATE VOLUNTEER_ASSIGNMENTS TABLE TO SUPPORT MULTIPLE WASTE TYPES
-- ============================================================================

-- Add new columns for generic waste item support
DO $$
BEGIN
  -- Add waste_type column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'volunteer_assignments' AND column_name = 'waste_type'
  ) THEN
    ALTER TABLE volunteer_assignments ADD COLUMN waste_type TEXT DEFAULT 'e-waste';
  END IF;

  -- Add waste_item_id column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'volunteer_assignments' AND column_name = 'waste_item_id'
  ) THEN
    ALTER TABLE volunteer_assignments ADD COLUMN waste_item_id UUID;
  END IF;
END $$;

-- Update existing records to populate the new columns
-- Check if ewaste_item_id column exists before trying to use it
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'volunteer_assignments' AND column_name = 'ewaste_item_id'
  ) THEN
    -- Populate from existing ewaste_item_id if it exists
    UPDATE volunteer_assignments
    SET
      waste_type = 'e-waste',
      waste_item_id = ewaste_item_id
    WHERE waste_type IS NULL OR waste_item_id IS NULL;
  ELSE
    -- If no existing data, just set default values for new records
    UPDATE volunteer_assignments
    SET
      waste_type = COALESCE(waste_type, 'e-waste')
    WHERE waste_type IS NULL;
  END IF;
END $$;

-- Create indexes for the new columns
CREATE INDEX IF NOT EXISTS volunteer_assignments_waste_type_idx ON volunteer_assignments(waste_type);
CREATE INDEX IF NOT EXISTS volunteer_assignments_waste_item_id_idx ON volunteer_assignments(waste_item_id);

-- Drop the old ewaste_item_id column and its constraints after migration
-- Using CASCADE to drop dependent constraints and indexes
ALTER TABLE volunteer_assignments DROP COLUMN IF EXISTS ewaste_item_id CASCADE;

-- Add check constraint for waste_type values if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'volunteer_assignments' AND constraint_name = 'volunteer_assignments_waste_type_check'
  ) THEN
    ALTER TABLE volunteer_assignments ADD CONSTRAINT volunteer_assignments_waste_type_check
    CHECK (waste_type IN ('e-waste', 'plastic', 'cloth'));
  END IF;
END $$;

-- Set waste_item_id to NOT NULL since all records should now have it populated
ALTER TABLE volunteer_assignments ALTER COLUMN waste_item_id SET NOT NULL;

-- Note: The application code will handle populating this when creating new assignments

-- ============================================================================
-- UPDATE VOLUNTEER_ASSIGNMENT SERVICE TO HANDLE MULTIPLE TYPES
-- ============================================================================

-- Note: The service methods need to be updated to query the appropriate tables
-- based on waste_type (e-waste -> ewaste_items, plastic -> plastic_items, cloth -> cloth_items)