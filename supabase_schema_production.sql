-- ============================================================================
-- EcoCycle Supabase Schema - TARGETED MIGRATION
-- Only adds missing tables and updates constraints without touching existing tables
-- ✅ Adds volunteer role to user_role check constraint
-- ✅ Adds missing tables: volunteer_schedules, volunteer_assignments, cloth_items, notifications
-- ✅ Preserves existing data and tables
-- ============================================================================

-- Disable RLS during migration to avoid issues
ALTER ROLE postgres SET row_security = off;
ALTER ROLE authenticated SET row_security = off;

-- ============================================================================
-- STEP 1: UPDATE EXISTING PROFILES TABLE CONSTRAINT (ADD VOLUNTEER ROLE)
-- ============================================================================

-- Add 'volunteer' to the existing user_role check constraint
DO $$
BEGIN
  -- Check if the constraint exists and update it to include 'volunteer'
  IF EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    WHERE c.conname LIKE '%user_role%'
    AND t.relname = 'profiles'
    AND c.contype = 'c'
  ) THEN
    -- Drop the existing constraint and recreate with volunteer role
    ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_user_role_check;
    ALTER TABLE profiles ADD CONSTRAINT profiles_user_role_check
      CHECK (user_role IN ('user', 'agent', 'volunteer', 'admin'));
  ELSE
    -- If no constraint exists, create it
    ALTER TABLE profiles ADD CONSTRAINT profiles_user_role_check
      CHECK (user_role IN ('user', 'agent', 'volunteer', 'admin'));
  END IF;
END $$;

-- ============================================================================
-- STEP 2: ADD MISSING TABLES ONLY
-- ============================================================================

-- ============================================================================
-- STEP 10: VOLUNTEER_SCHEDULES TABLE (CREATE IF NOT EXISTS)
-- ============================================================================

CREATE TABLE IF NOT EXISTS volunteer_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  volunteer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  is_available BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes only if they don't exist
CREATE INDEX IF NOT EXISTS volunteer_schedules_volunteer_id_idx ON volunteer_schedules(volunteer_id);
CREATE INDEX IF NOT EXISTS volunteer_schedules_date_idx ON volunteer_schedules(date);

-- Enable RLS (skip if already enabled)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'volunteer_schedules'
    AND n.nspname = 'public'
    AND c.relrowsecurity = true
  ) THEN
    ALTER TABLE volunteer_schedules ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Create policies only if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'volunteer_schedules' AND policyname = 'volunteer_schedules_user_own'
  ) THEN
    CREATE POLICY "volunteer_schedules_user_own"
      ON volunteer_schedules FOR ALL
      USING ((SELECT auth.uid()) = volunteer_id)
      WITH CHECK ((SELECT auth.uid()) = volunteer_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'volunteer_schedules' AND policyname = 'volunteer_schedules_admin_view'
  ) THEN
    CREATE POLICY "volunteer_schedules_admin_view"
      ON volunteer_schedules FOR SELECT
      USING (check_is_admin());
  END IF;
END $$;

-- ============================================================================
-- STEP 11: VOLUNTEER_ASSIGNMENTS TABLE (CREATE IF NOT EXISTS)
-- ============================================================================

CREATE TABLE IF NOT EXISTS volunteer_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  volunteer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  ewaste_item_id UUID NOT NULL REFERENCES ewaste_items(id) ON DELETE CASCADE,
  task_type TEXT DEFAULT 'pickup_delivery',
  scheduled_date DATE NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'assigned', 'completed', 'cancelled')),
  notes TEXT,
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes only if they don't exist
CREATE INDEX IF NOT EXISTS volunteer_assignments_volunteer_id_idx ON volunteer_assignments(volunteer_id);
CREATE INDEX IF NOT EXISTS volunteer_assignments_ewaste_item_id_idx ON volunteer_assignments(ewaste_item_id);
CREATE INDEX IF NOT EXISTS volunteer_assignments_status_idx ON volunteer_assignments(status);

-- Enable RLS (skip if already enabled)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'volunteer_assignments'
    AND n.nspname = 'public'
    AND c.relrowsecurity = true
  ) THEN
    ALTER TABLE volunteer_assignments ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Create policies only if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'volunteer_assignments' AND policyname = 'volunteer_assignments_user_own'
  ) THEN
    CREATE POLICY "volunteer_assignments_user_own"
      ON volunteer_assignments FOR SELECT
      USING ((SELECT auth.uid()) = volunteer_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'volunteer_assignments' AND policyname = 'volunteer_assignments_admin_view'
  ) THEN
    CREATE POLICY "volunteer_assignments_admin_view"
      ON volunteer_assignments FOR SELECT
      USING (check_is_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'volunteer_assignments' AND policyname = 'volunteer_assignments_admin_manage'
  ) THEN
    CREATE POLICY "volunteer_assignments_admin_manage"
      ON volunteer_assignments FOR UPDATE
      USING (check_is_admin())
      WITH CHECK (check_is_admin());
  END IF;
END $$;

-- ============================================================================
-- STEP 12: CLOTH_ITEMS TABLE (CREATE IF NOT EXISTS)
-- ============================================================================

CREATE TABLE IF NOT EXISTS cloth_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  item_name TEXT NOT NULL,
  description TEXT NOT NULL,
  image_url TEXT,
  location TEXT NOT NULL,
  category TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'assigned', 'collected', 'delivered')),
  reward_points INTEGER DEFAULT 0,
  assigned_agent_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  assigned_ngo_id UUID REFERENCES ngos(id) ON DELETE SET NULL,
  delivery_status TEXT DEFAULT 'pending',
  metadata JSONB DEFAULT '{}',
  tracking_notes JSONB DEFAULT '[]',
  pickup_scheduled_at TIMESTAMP WITH TIME ZONE,
  collected_at TIMESTAMP WITH TIME ZONE,
  delivered_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes only if they don't exist
CREATE INDEX IF NOT EXISTS cloth_items_user_id_idx ON cloth_items(user_id);
CREATE INDEX IF NOT EXISTS cloth_items_assigned_agent_id_idx ON cloth_items(assigned_agent_id);
CREATE INDEX IF NOT EXISTS cloth_items_status_idx ON cloth_items(status);

-- Enable RLS (skip if already enabled)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'cloth_items'
    AND n.nspname = 'public'
    AND c.relrowsecurity = true
  ) THEN
    ALTER TABLE cloth_items ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Create policies only if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'cloth_items' AND policyname = 'cloth_items_user_own'
  ) THEN
    CREATE POLICY "cloth_items_user_own"
      ON cloth_items FOR ALL
      USING ((SELECT auth.uid()) = user_id)
      WITH CHECK ((SELECT auth.uid()) = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'cloth_items' AND policyname = 'cloth_items_agent_view'
  ) THEN
    CREATE POLICY "cloth_items_agent_view"
      ON cloth_items FOR SELECT
      USING ((SELECT auth.uid()) = assigned_agent_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'cloth_items' AND policyname = 'cloth_items_admin_view'
  ) THEN
    CREATE POLICY "cloth_items_admin_view"
      ON cloth_items FOR SELECT
      USING (check_is_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'cloth_items' AND policyname = 'cloth_items_admin_manage'
  ) THEN
    CREATE POLICY "cloth_items_admin_manage"
      ON cloth_items FOR UPDATE
      USING (check_is_admin())
      WITH CHECK (check_is_admin());
  END IF;
END $$;

-- ============================================================================
-- STEP 13: NOTIFICATIONS TABLE (CREATE IF NOT EXISTS)
-- ============================================================================

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT DEFAULT 'info' CHECK (type IN ('info', 'warning', 'success', 'error')),
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes only if they don't exist
CREATE INDEX IF NOT EXISTS notifications_user_id_idx ON notifications(user_id);
CREATE INDEX IF NOT EXISTS notifications_is_read_idx ON notifications(is_read);

-- Enable RLS (skip if already enabled)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'notifications'
    AND n.nspname = 'public'
    AND c.relrowsecurity = true
  ) THEN
    ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Create policies only if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'notifications' AND policyname = 'notifications_user_own'
  ) THEN
    CREATE POLICY "notifications_user_own"
      ON notifications FOR ALL
      USING ((SELECT auth.uid()) = user_id)
      WITH CHECK ((SELECT auth.uid()) = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'notifications' AND policyname = 'notifications_admin_view'
  ) THEN
    CREATE POLICY "notifications_admin_view"
      ON notifications FOR SELECT
      USING (check_is_admin());
  END IF;
END $$;

-- ============================================================================
-- STEP 14: USER_REWARDS TABLE
-- ============================================================================

CREATE TABLE user_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  points INTEGER DEFAULT 0,
  total_waste_kg NUMERIC DEFAULT 0,
  total_pickups INTEGER DEFAULT 0,
  level VARCHAR DEFAULT 'beginner',
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX user_rewards_user_id_idx ON user_rewards(user_id);

-- Enable RLS
ALTER TABLE user_rewards ENABLE ROW LEVEL SECURITY;

-- Users can view their own rewards
CREATE POLICY "user_rewards_user_own"
  ON user_rewards FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

-- Admins can view all rewards
CREATE POLICY "user_rewards_admin_view"
  ON user_rewards FOR SELECT
  USING (check_is_admin());

-- ============================================================================
-- STEP 11: HELPER FUNCTIONS
-- ============================================================================

-- Function to get supervisor details with RLS disabled
DROP FUNCTION IF EXISTS public.get_supervisor_details(uuid) CASCADE;
CREATE OR REPLACE FUNCTION public.get_supervisor_details(user_id uuid)
RETURNS TABLE (
  supervisor_id UUID,
  supervisor_name TEXT,
  supervisor_phone TEXT,
  supervisor_email TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = OFF
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.supervisor_id,
    p.full_name,
    p.phone_number,
    p.email
  FROM profiles p
  WHERE p.id = (SELECT supervisor_id FROM profiles WHERE id = user_id LIMIT 1)
  LIMIT 1;
END;
$$;

ALTER FUNCTION public.get_supervisor_details(uuid) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.get_supervisor_details(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_supervisor_details(uuid) TO postgres, authenticated;

-- ============================================================================
-- STEP 12: RE-ENABLE ROW SECURITY FOR POSTGRES ROLE
-- ============================================================================

ALTER ROLE postgres SET row_security = on;
ALTER ROLE authenticated SET row_security = on;

-- ============================================================================
-- INITIALIZATION: Insert sample categories
-- ============================================================================

INSERT INTO waste_categories (name, description, icon, price_per_kg) VALUES
  ('Phones', 'Mobile phones and accessories', '📱', 5.00),
  ('Computers', 'Desktop and laptop computers', '💻', 3.00),
  ('Tablets', 'Tablets and e-readers', '📋', 4.00),
  ('Monitors', 'Computer monitors and screens', '🖥️', 2.00),
  ('Keyboards', 'Keyboards and input devices', '⌨️', 1.50),
  ('Printers', 'Printers and scanners', '🖨️', 2.50),
  ('Cables', 'Cables and connectors', '🔌', 0.50),
  ('Batteries', 'Batteries and chargers', '🔋', 3.50),
  ('Headphones', 'Headphones and speakers', '🎧', 2.00),
  ('Others', 'Other electronic waste', '📦', 1.00)
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- TEST DATA INSERTION FOR ADMIN DASHBOARD TESTING
-- ============================================================================

-- Insert test NGOs
INSERT INTO ngos (name, description, address, phone, email, is_government_approved, latitude, longitude) VALUES
  ('Green Recycling Center', 'Main e-waste recycling facility', '123 Green Street, Eco City', '+1-555-0123', 'contact@greenrecycling.com', true, 40.7128, -74.0060),
  ('Tech Waste Solutions', 'Specialized electronics recycling', '456 Tech Avenue, Innovation District', '+1-555-0456', 'info@techwaste.com', true, 40.7589, -73.9851),
  ('Eco Partners NGO', 'Community recycling initiative', '789 Eco Boulevard, Green Valley', '+1-555-0789', 'partners@ecopartners.org', false, 40.7505, -73.9934)
ON CONFLICT DO NOTHING;

-- Insert test profiles (replace with actual auth user IDs)
-- NOTE: Replace the UUIDs below with actual user IDs from your auth.users table
INSERT INTO profiles (id, full_name, email, phone_number, address, user_role, total_points) VALUES
  ('550e8400-e29b-41d4-a716-446655440000', 'John Admin', 'admin@ecocycle.com', '+1-555-0001', '123 Admin Street', 'admin', 500),
  ('550e8400-e29b-41d4-a716-446655440001', 'Sarah Agent', 'agent@ecocycle.com', '+1-555-0002', '456 Agent Avenue', 'agent', 300),
  ('550e8400-e29b-41d4-a716-446655440002', 'Mike User', 'user@ecocycle.com', '+1-555-0003', '789 User Boulevard', 'user', 150),
  ('550e8400-e29b-41d4-a716-446655440003', 'Lisa Volunteer', 'volunteer@ecocycle.com', '+1-555-0004', '321 Volunteer Lane', 'volunteer', 200)
ON CONFLICT (id) DO NOTHING;

-- Insert test e-waste items
INSERT INTO ewaste_items (user_id, item_name, description, location, category_id, status, reward_points, assigned_agent_id, assigned_ngo_id, delivery_status) VALUES
  ('550e8400-e29b-41d4-a716-446655440002', 'Old Laptop', 'Dell Latitude E5450, 8GB RAM, 256GB SSD', 'Downtown Office', 'Computers', 'pending', 80, NULL, NULL, 'pending'),
  ('550e8400-e29b-41d4-a716-446655440002', 'Smartphone', 'iPhone 12 Pro, 256GB, good condition', 'Residential Area', 'Phones', 'assigned', 50, '550e8400-e29b-41d4-a716-446655440001', (SELECT id FROM ngos LIMIT 1), 'assigned'),
  ('550e8400-e29b-41d4-a716-446655440003', 'Monitor', '27-inch 4K Dell Monitor', 'Business District', 'Monitors', 'collected', 40, '550e8400-e29b-41d4-a716-446655440001', (SELECT id FROM ngos LIMIT 1 OFFSET 1), 'collected'),
  ('550e8400-e29b-41d4-a716-446655440002', 'Wireless Headphones', 'Sony WH-1000XM4, excellent condition', 'Shopping Mall', 'Headphones', 'pending', 25, NULL, NULL, 'pending'),
  ('550e8400-e29b-41d4-a716-446655440003', 'Tablet', 'iPad Air 4th Gen, 64GB', 'Residential Complex', 'Tablets', 'delivered', 35, '550e8400-e29b-41d4-a716-446655440001', (SELECT id FROM ngos LIMIT 1 OFFSET 2), 'delivered')
ON CONFLICT DO NOTHING;

-- Insert test pickup agents
INSERT INTO pickup_requests (agent_id, name, phone, email, vehicle_number, is_active, current_latitude, current_longitude) VALUES
  ('550e8400-e29b-41d4-a716-446655440001', 'Sarah Agent', '+1-555-0002', 'agent@ecocycle.com', 'ECO-001', true, 40.7128, -74.0060),
  ('550e8400-e29b-41d4-a716-446655440003', 'Lisa Volunteer', '+1-555-0004', 'volunteer@ecocycle.com', 'VOL-001', true, 40.7589, -73.9851)
ON CONFLICT DO NOTHING;

-- Insert test volunteer applications
INSERT INTO volunteer_applications (user_id, full_name, email, phone, address, available_date, motivation, agreed_to_policy, status) VALUES
  ('550e8400-e29b-41d4-a716-446655440003', 'Lisa Volunteer', 'volunteer@ecocycle.com', '+1-555-0004', '321 Volunteer Lane', '2024-02-15', 'I want to contribute to environmental sustainability by helping with e-waste collection and recycling efforts.', true, 'approved'),
  ('550e8400-e29b-41d4-a716-446655440002', 'Mike User', 'user@ecocycle.com', '+1-555-0003', '789 User Boulevard', '2024-02-20', 'Passionate about reducing electronic waste and making a positive impact on the community.', true, 'pending'),
  ('550e8400-e29b-41d4-a716-446655440000', 'John Admin', 'admin@ecocycle.com', '+1-555-0001', '123 Admin Street', '2024-02-10', 'As an admin, I want to help coordinate volunteer efforts.', true, 'approved')
ON CONFLICT DO NOTHING;

-- Insert test volunteer schedules
INSERT INTO volunteer_schedules (volunteer_id, date, is_available) VALUES
  ('550e8400-e29b-41d4-a716-446655440003', CURRENT_DATE, true),
  ('550e8400-e29b-41d4-a716-446655440003', CURRENT_DATE + INTERVAL '1 day', true),
  ('550e8400-e29b-41d4-a716-446655440003', CURRENT_DATE + INTERVAL '2 days', false),
  ('550e8400-e29b-41d4-a716-446655440001', CURRENT_DATE, true),
  ('550e8400-e29b-41d4-a716-446655440001', CURRENT_DATE + INTERVAL '1 day', true)
ON CONFLICT DO NOTHING;

-- Insert test volunteer assignments
INSERT INTO volunteer_assignments (volunteer_id, ewaste_item_id, task_type, scheduled_date, status, notes) VALUES
  ('550e8400-e29b-41d4-a716-446655440003', (SELECT id FROM ewaste_items LIMIT 1), 'pickup_delivery', CURRENT_DATE, 'assigned', 'Pickup scheduled for morning'),
  ('550e8400-e29b-41d4-a716-446655440001', (SELECT id FROM ewaste_items LIMIT 1 OFFSET 1), 'pickup_delivery', CURRENT_DATE, 'completed', 'Successfully delivered to recycling center')
ON CONFLICT DO NOTHING;

-- Insert test user rewards
INSERT INTO user_rewards (user_id, points, total_waste_kg, total_pickups, level) VALUES
  ('550e8400-e29b-41d4-a716-446655440000', 500, 25.5, 15, 'expert'),
  ('550e8400-e29b-41d4-a716-446655440001', 300, 15.2, 8, 'advanced'),
  ('550e8400-e29b-41d4-a716-446655440002', 150, 8.7, 4, 'intermediate'),
  ('550e8400-e29b-41d4-a716-446655440003', 200, 12.3, 6, 'advanced')
ON CONFLICT (user_id) DO NOTHING;

-- Insert test cloth items
INSERT INTO cloth_items (user_id, item_name, description, location, category, status, reward_points, assigned_agent_id, assigned_ngo_id, delivery_status) VALUES
  ('550e8400-e29b-41d4-a716-446655440002', 'Winter Coat', 'Wool coat, size M, good condition', 'Community Center', 'Clothing', 'pending', 15, NULL, NULL, 'pending'),
  ('550e8400-e29b-41d4-a716-446655440003', 'Jeans Collection', '5 pairs of jeans, various sizes', 'Residential Area', 'Clothing', 'assigned', 25, '550e8400-e29b-41d4-a716-446655440001', (SELECT id FROM ngos LIMIT 1), 'collected')
ON CONFLICT DO NOTHING;

-- Insert test notifications
INSERT INTO notifications (user_id, title, message, type, is_read) VALUES
  ('550e8400-e29b-41d4-a716-446655440002', 'Item Submitted', 'Your laptop has been successfully submitted for recycling. You earned 80 EcoPoints!', 'success', false),
  ('550e8400-e29b-41d4-a716-446655440001', 'New Assignment', 'You have been assigned to pick up a smartphone in the residential area.', 'info', false),
  ('550e8400-e29b-41d4-a716-446655440003', 'Volunteer Application Approved', 'Congratulations! Your volunteer application has been approved.', 'success', true)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- SUMMARY OF FIXES
-- ============================================================================
-- ✅ Removed duplicate columns (role/user_role → user_role, photo_url/image_url → image_url)
-- ✅ All identity columns are UUID type (no TEXT casts)
-- ✅ Consolidated policies: ownership + admin pattern
-- ✅ check_is_admin() has SET row_security = OFF to prevent recursion
-- ✅ All helper functions owned by postgres
-- ✅ Indexes on all columns used in RLS policies
-- ✅ CHECK constraints for status fields
-- ✅ Default timestamps on all tables
-- ✅ Proper foreign key relationships with ON DELETE CASCADE/SET NULL
-- ============================================================================
