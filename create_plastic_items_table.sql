-- ============================================================================
-- CREATE PLASTIC_ITEMS TABLE
-- Fixes the missing table error in admin dashboard
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

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS plastic_items_user_id_idx ON plastic_items(user_id);
CREATE INDEX IF NOT EXISTS plastic_items_status_idx ON plastic_items(status);
CREATE INDEX IF NOT EXISTS plastic_items_created_at_idx ON plastic_items(created_at DESC);
CREATE INDEX IF NOT EXISTS plastic_items_assigned_agent_id_idx ON plastic_items(assigned_agent_id);

-- Enable Row Level Security
ALTER TABLE plastic_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own plastic items" ON plastic_items;
DROP POLICY IF EXISTS "Users can insert own plastic items" ON plastic_items;
DROP POLICY IF EXISTS "Users can update own plastic items" ON plastic_items;
DROP POLICY IF EXISTS "Agents can view assigned plastic items" ON plastic_items;
DROP POLICY IF EXISTS "Admins can view all plastic items" ON plastic_items;
DROP POLICY IF EXISTS "Admins can update all plastic items" ON plastic_items;

-- Create RLS policies
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

-- Grant permissions
GRANT ALL ON plastic_items TO authenticated;
GRANT ALL ON plastic_items TO postgres;

-- ============================================================================
-- END OF PLASTIC_ITEMS TABLE CREATION
-- ============================================================================
