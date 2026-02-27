-- Add coordinates to plastic_items and cloth_donations
ALTER TABLE plastic_items ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE plastic_items ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

ALTER TABLE cloth_donations ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE cloth_donations ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
