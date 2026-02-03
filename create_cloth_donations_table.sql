-- ============================================================================
-- CREATE CLOTH_DONATIONS TABLE
-- Fixes the missing table error in admin dashboard
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

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS cloth_donations_user_id_idx ON cloth_donations(user_id);
CREATE INDEX IF NOT EXISTS cloth_donations_status_idx ON cloth_donations(status);
CREATE INDEX IF NOT EXISTS cloth_donations_created_at_idx ON cloth_donations(created_at DESC);
CREATE INDEX IF NOT EXISTS cloth_donations_assigned_agent_id_idx ON cloth_donations(assigned_agent_id);

-- Enable Row Level Security
ALTER TABLE cloth_donations ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own cloth donations" ON cloth_donations;
DROP POLICY IF EXISTS "Users can insert own cloth donations" ON cloth_donations;
DROP POLICY IF EXISTS "Users can update own cloth donations" ON cloth_donations;
DROP POLICY IF EXISTS "Agents can view assigned cloth donations" ON cloth_donations;
DROP POLICY IF EXISTS "Admins can view all cloth donations" ON cloth_donations;
DROP POLICY IF EXISTS "Admins can update all cloth donations" ON cloth_donations;

-- Create RLS policies
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

-- Grant permissions
GRANT ALL ON cloth_donations TO authenticated;
GRANT ALL ON cloth_donations TO postgres;

-- ============================================================================
-- END OF CLOTH_DONATIONS TABLE CREATION
-- ============================================================================
