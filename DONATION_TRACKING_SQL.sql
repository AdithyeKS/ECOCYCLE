-- ============================================================================
-- DONATION TRACKING SQL QUERIES FOR ECOCYCLE
-- Project: EcoCycle (Waste & Donation Management)
-- Purpose: Track all donation statuses for authenticated users
-- Updated: Fixed to match actual database schema
-- ============================================================================

-- ============================================================================
-- 1. VIEW: All User Donations (Unified across all waste types)
-- ============================================================================
CREATE OR REPLACE VIEW public.user_donation_status AS
SELECT
  'e-waste' AS donation_type,
  e.id,
  e.user_id,
  e.item_name,
  e.category_id AS category,
  e.description,
  e.location,
  e.image_url,
  e.status,
  e.reward_points,
  e.created_at,
  e.pickup_scheduled_at
FROM public.ewaste_items e
UNION ALL
SELECT
  'cloth' AS donation_type,
  c.id::text AS id,
  c.user_id,
  CONCAT(c.type, ' - ', c.quantity, 'pcs') AS item_name,
  c.condition AS category,
  c.type AS description,
  c.location,
  c.image_url,
  c.status,
  NULL::integer AS reward_points,
  c.created_at,
  NULL::timestamp AS pickup_scheduled_at
FROM public.cloth_donations c
UNION ALL
SELECT
  'plastic' AS donation_type,
  p.id,
  p.user_id,
  p.item_name,
  p.plastic_type AS category,
  p.description,
  p.location,
  p.image_url,
  p.status,
  p.points AS reward_points,
  p.created_at,
  NULL::timestamp AS pickup_scheduled_at
FROM public.plastic_items p
ORDER BY created_at DESC;

-- Grant appropriate permissions
GRANT SELECT ON public.user_donation_status TO authenticated;

-- ============================================================================
-- 2. FUNCTION: Get user's donation summary with statistics
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_user_donation_summary(user_id uuid)
RETURNS TABLE (
  total_donations bigint,
  pending_count bigint,
  approved_count bigint,
  completed_count bigint,
  rejected_count bigint,
  total_points_earned integer,
  ewaste_count bigint,
  cloth_count bigint,
  plastic_count bigint
) AS $$
SELECT
  COALESCE(SUM(total)::bigint, 0),
  COALESCE(SUM(CASE WHEN status = 'Pending' OR status LIKE 'Pending%' THEN 1 ELSE 0 END)::bigint, 0),
  COALESCE(SUM(CASE WHEN status = 'Approved' OR status = 'Pending Review' THEN 1 ELSE 0 END)::bigint, 0),
  COALESCE(SUM(CASE WHEN status = 'Completed' OR status = 'Accepted' THEN 1 ELSE 0 END)::bigint, 0),
  COALESCE(SUM(CASE WHEN status = 'Rejected' OR status LIKE 'Rejected%' THEN 1 ELSE 0 END)::bigint, 0),
  COALESCE(SUM(COALESCE(reward_points, 0))::integer, 0),
  COALESCE(SUM(CASE WHEN donation_type = 'e-waste' THEN 1 ELSE 0 END)::bigint, 0),
  COALESCE(SUM(CASE WHEN donation_type = 'cloth' THEN 1 ELSE 0 END)::bigint, 0),
  COALESCE(SUM(CASE WHEN donation_type = 'plastic' THEN 1 ELSE 0 END)::bigint, 0)
FROM (
  SELECT 1 as total, status, reward_points, 'e-waste' as donation_type
  FROM public.ewaste_items
  WHERE user_id = $1
  UNION ALL
  SELECT 1, status, NULL, 'cloth'
  FROM public.cloth_donations
  WHERE user_id = $1
  UNION ALL
  SELECT 1, status, points, 'plastic'
  FROM public.plastic_items
  WHERE user_id = $1
) combined;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.get_user_donation_summary(uuid) TO authenticated;

-- ============================================================================
-- 3. FUNCTION: Get donation by ID with full details
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_donation_details(donation_id text)
RETURNS TABLE (
  id text,
  donation_type text,
  item_name text,
  category text,
  description text,
  status text,
  location text,
  image_url text,
  reward_points integer,
  created_at timestamp,
  submitted_by_user_id uuid,
  submission_date timestamp
) AS $$
SELECT
  d.id::text,
  d.donation_type,
  d.item_name,
  d.category,
  d.description,
  d.status,
  d.location,
  d.image_url,
  d.reward_points,
  d.created_at,
  d.user_id,
  d.created_at
FROM public.user_donation_status d
WHERE d.id::text = $1;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.get_donation_details(text) TO authenticated;

-- ============================================================================
-- 4. FUNCTION: Get donations filtered by status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_donations_by_status(
  p_user_id uuid,
  p_status text DEFAULT NULL
)
RETURNS TABLE (
  id text,
  donation_type text,
  item_name text,
  status text,
  location text,
  reward_points integer,
  created_at timestamp,
  image_url text
) AS $$
SELECT
  d.id::text,
  d.donation_type,
  d.item_name,
  d.status,
  d.location,
  d.reward_points,
  d.created_at,
  d.image_url
FROM public.user_donation_status d
WHERE d.user_id = p_user_id
  AND (p_status IS NULL OR d.status ILIKE '%' || p_status || '%')
ORDER BY d.created_at DESC;
$$ LANGUAGE SQL SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_donations_by_status(uuid, text) TO authenticated;

-- ============================================================================
-- 5. FUNCTION: Get total points earned by user
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_user_total_points(p_user_id uuid)
RETURNS integer AS $$
SELECT COALESCE(SUM(reward_points), 0)::integer
FROM public.user_donation_status
WHERE user_id = p_user_id
  AND status IN ('Completed', 'Accepted', 'Approved');
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

GRANT EXECUTE ON FUNCTION public.get_user_total_points(uuid) TO authenticated;

-- ============================================================================
-- 6. RLS POLICIES for Donation Tracking Views
-- ============================================================================
-- Enable RLS on all donation tables
ALTER TABLE public.ewaste_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cloth_donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plastic_items ENABLE ROW LEVEL SECURITY;

-- E-waste items policies
CREATE POLICY "Users can view own e-waste donations" ON public.ewaste_items
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own e-waste donations" ON public.ewaste_items
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own e-waste donations" ON public.ewaste_items
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Cloth donations policies
CREATE POLICY "Users can view own cloth donations" ON public.cloth_donations
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own cloth donations" ON public.cloth_donations
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own cloth donations" ON public.cloth_donations
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Plastic items policies
CREATE POLICY "Users can view own plastic donations" ON public.plastic_items
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own plastic donations" ON public.plastic_items
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own plastic donations" ON public.plastic_items
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- 6. ADMIN POLICIES - Allow admins to see and manage ALL donations
-- ============================================================================

-- Admin policies for e-waste items
CREATE POLICY "Admins can view all e-waste items" ON public.ewaste_items
  FOR SELECT TO authenticated
  USING (
    (SELECT user_role FROM public.profiles WHERE id = auth.uid() LIMIT 1) = 'admin'
  );

CREATE POLICY "Admins can update all e-waste items" ON public.ewaste_items
  FOR UPDATE TO authenticated
  USING (
    (SELECT user_role FROM public.profiles WHERE id = auth.uid() LIMIT 1) = 'admin'
  )
  WITH CHECK (
    (SELECT user_role FROM public.profiles WHERE id = auth.uid() LIMIT 1) = 'admin'
  );

-- Admin policies for cloth donations
CREATE POLICY "Admins can view all cloth donations" ON public.cloth_donations
  FOR SELECT TO authenticated
  USING (
    (SELECT user_role FROM public.profiles WHERE id = auth.uid() LIMIT 1) = 'admin'
  );

CREATE POLICY "Admins can update all cloth donations" ON public.cloth_donations
  FOR UPDATE TO authenticated
  USING (
    (SELECT user_role FROM public.profiles WHERE id = auth.uid() LIMIT 1) = 'admin'
  )
  WITH CHECK (
    (SELECT user_role FROM public.profiles WHERE id = auth.uid() LIMIT 1) = 'admin'
  );

-- Admin policies for plastic items
CREATE POLICY "Admins can view all plastic items" ON public.plastic_items
  FOR SELECT TO authenticated
  USING (
    (SELECT user_role FROM public.profiles WHERE id = auth.uid() LIMIT 1) = 'admin'
  );

CREATE POLICY "Admins can update all plastic items" ON public.plastic_items
  FOR UPDATE TO authenticated
  USING (
    (SELECT user_role FROM public.profiles WHERE id = auth.uid() LIMIT 1) = 'admin'
  )
  WITH CHECK (
    (SELECT user_role FROM public.profiles WHERE id = auth.uid() LIMIT 1) = 'admin'
  );

-- ============================================================================
-- 7. INDEXES for Performance
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_ewaste_items_user_id ON public.ewaste_items(user_id);
CREATE INDEX IF NOT EXISTS idx_ewaste_items_status ON public.ewaste_items(status);
CREATE INDEX IF NOT EXISTS idx_ewaste_items_created_at ON public.ewaste_items(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ewaste_items_user_created ON public.ewaste_items(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_cloth_donations_user_id ON public.cloth_donations(user_id);
CREATE INDEX IF NOT EXISTS idx_cloth_donations_status ON public.cloth_donations(status);
CREATE INDEX IF NOT EXISTS idx_cloth_donations_created_at ON public.cloth_donations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cloth_donations_user_created ON public.cloth_donations(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_plastic_items_user_id ON public.plastic_items(user_id);
CREATE INDEX IF NOT EXISTS idx_plastic_items_status ON public.plastic_items(status);
CREATE INDEX IF NOT EXISTS idx_plastic_items_created_at ON public.plastic_items(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_plastic_items_user_created ON public.plastic_items(user_id, created_at DESC);

-- ============================================================================
-- 8. READY-TO-USE QUERIES FOR DART/FLUTTER APP
-- ============================================================================

-- Query 1: Get all donations for current user
-- SELECT * FROM public.user_donation_status 
-- WHERE user_id = auth.uid() 
-- ORDER BY created_at DESC;

-- Query 2: Get donation summary statistics
-- SELECT * FROM public.get_user_donation_summary(auth.uid());

-- Query 3: Get donations by status (e.g., 'Pending')
-- SELECT * FROM public.get_donations_by_status(auth.uid(), 'Pending');

-- Query 4: Get user's total earned points
-- SELECT public.get_user_total_points(auth.uid());

-- Query 5: Get specific donation details
-- SELECT * FROM public.get_donation_details('donation-id-here');

-- Query 6: Get pending donations for pickup
-- SELECT * FROM public.user_donation_status
-- WHERE user_id = auth.uid() 
--   AND status ILIKE '%Pending%'
-- ORDER BY created_at ASC;

-- Query 7: Get completed/accepted donations
-- SELECT * FROM public.user_donation_status
-- WHERE user_id = auth.uid()
--   AND (status = 'Completed' OR status = 'Accepted')
-- ORDER BY created_at DESC;

-- Query 8: Get breakdown by donation type
-- SELECT 
--   donation_type,
--   COUNT(*) as count,
--   SUM(reward_points) as total_points
-- FROM public.user_donation_status
-- WHERE user_id = auth.uid()
-- GROUP BY donation_type;

-- ============================================================================
-- END OF DONATION TRACKING SQL
-- ============================================================================
