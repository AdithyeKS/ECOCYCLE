-- ============================================================================
-- CREATE MISSING TABLES FOR ADMIN DASHBOARD
-- Fixes the missing table errors: plastic_items and cloth_donations
-- Run this entire script in Supabase SQL Editor
-- ============================================================================

-- ============================================================================
-- 1. CREATE PLASTIC_ITEMS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS plastic_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  plastic_type TEXT NOT NULL,
  item_name TEXT NOT NULL,
  description TEXT NOT NULL,
  location TEXT NOT NULL,
  image_url TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'assigned', 'collected', 'delivered')),
  points INTEGER DEFAULT 0,
  delivery_status TEXT DEFAULT 'pending',
  assigned_agent_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  assigned_ngo_id UUID REFERENCES ngos(id) ON DELETE SET NULL,
  tracking_notes JSONB DEFAULT '[]',
  pickup_scheduled_at TIMESTAMP WITH TIME ZONE,
  collected_at TIMESTAMP WITH TIME ZONE,
  delivered_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for plastic_items
CREATE INDEX IF NOT EXISTS plastic_items_user_id_idx ON plastic_items(user_id);
CREATE INDEX IF NOT EXISTS plastic_items_status_idx ON plastic_items(status);
CREATE INDEX IF NOT EXISTS plastic_items_created_at_idx ON plastic_items(created_at DESC);
CREATE INDEX IF NOT EXISTS plastic_items_assigned_agent_id_idx ON plastic_items(assigned_agent_id);

-- Enable RLS for plastic_items
ALTER TABLE plastic_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist for plastic_items
DROP POLICY IF EXISTS "Users can view own plastic items" ON plastic_items;
DROP POLICY IF EXISTS "Users can insert own plastic items" ON plastic_items;
DROP POLICY IF EXISTS "Users can update own plastic items" ON plastic_items;
DROP POLICY IF EXISTS "Agents can view assigned plastic items" ON plastic_items;
DROP POLICY IF EXISTS "Admins can view all plastic items" ON plastic_items;
DROP POLICY IF EXISTS "Admins can update all plastic items" ON plastic_items;

-- Create RLS policies for plastic_items
CREATE POLICY "Users can view own plastic items" ON plastic_items
  FOR SELECT USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own plastic items" ON plastic_items
  FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own plastic items" ON plastic_items
  FOR UPDATE USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Agents can view assigned plastic items" ON plastic_items
  FOR SELECT USING ((SELECT auth.uid()) = assigned_agent_id);

CREATE POLICY "Admins can view all plastic items" ON plastic_items
  FOR SELECT USING (
    (SELECT user_role FROM public.profiles WHERE id = auth.uid() LIMIT 1) = 'admin'
  );

CREATE POLICY "Admins can update all plastic items" ON plastic_items
  FOR UPDATE USING (
    (SELECT user_role FROM public.profiles WHERE id = auth.uid() LIMIT 1) = 'admin'
  );

-- ============================================================================
-- 2. CREATE CLOTH_DONATIONS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS cloth_donations (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  condition TEXT NOT NULL,
  location TEXT NOT NULL,
  status TEXT DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Collected', 'Donated', 'Rejected')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  image_url TEXT,
  damage_percent INTEGER,
  delivery_status TEXT DEFAULT 'pending',
  assigned_agent_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  assigned_ngo_id UUID REFERENCES ngos(id) ON DELETE SET NULL,
  tracking_notes JSONB DEFAULT '[]',
  pickup_scheduled_at TIMESTAMP WITH TIME ZONE,
  collected_at TIMESTAMP WITH TIME ZONE,
  delivered_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for cloth_donations
CREATE INDEX IF NOT EXISTS cloth_donations_user_id_idx ON cloth_donations(user_id);
CREATE INDEX IF NOT EXISTS cloth_donations_status_idx ON cloth_donations(status);
CREATE INDEX IF NOT EXISTS cloth_donations_created_at_idx ON cloth_donations(created_at DESC);
CREATE INDEX IF NOT EXISTS cloth_donations_assigned_agent_id_idx ON cloth_donations(assigned_agent_id);

-- Enable RLS for cloth_donations
ALTER TABLE cloth_donations ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist for cloth_donations
DROP POLICY IF EXISTS "Users can view own cloth donations" ON cloth_donations;
DROP POLICY IF EXISTS "Users can insert own cloth donations" ON cloth_donations;
DROP POLICY IF EXISTS "Users can update own cloth donations" ON cloth_donations;
DROP POLICY IF EXISTS "Agents can view assigned cloth donations" ON cloth_donations;
DROP POLICY IF EXISTS "Admins can view all cloth donations" ON cloth_donations;
DROP POLICY IF EXISTS "Admins can update all cloth donations" ON cloth_donations;

-- Create RLS policies for cloth_donations
CREATE POLICY "Users can view own cloth donations" ON cloth_donations
  FOR SELECT USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own cloth donations" ON cloth_donations
  FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own cloth donations" ON cloth_donations
  FOR UPDATE USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Agents can view assigned cloth donations" ON cloth_donations
  FOR SELECT USING ((SELECT auth.uid()) = assigned_agent_id);

CREATE POLICY "Admins can view all cloth donations" ON cloth_donations
  FOR SELECT USING (
    (SELECT user_role FROM public.profiles WHERE id = auth.uid() LIMIT 1) = 'admin'
  );

CREATE POLICY "Admins can update all cloth donations" ON cloth_donations
  FOR UPDATE USING (
    (SELECT user_role FROM public.profiles WHERE id = auth.uid() LIMIT 1) = 'admin'
  );

-- ============================================================================
-- 3. GRANT PERMISSIONS
-- ============================================================================

GRANT ALL ON plastic_items TO authenticated;
GRANT ALL ON plastic_items TO postgres;
GRANT ALL ON cloth_donations TO authenticated;
GRANT ALL ON cloth_donations TO postgres;

-- ============================================================================
-- END OF MISSING TABLES CREATION
-- ============================================================================
