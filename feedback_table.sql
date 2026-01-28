-- Create feedback table for user feedback submissions
CREATE TABLE IF NOT EXISTS feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  user_email TEXT,
  subject TEXT NOT NULL,
  message TEXT NOT NULL,
  category TEXT DEFAULT 'general' CHECK (category IN ('general', 'bug', 'feature', 'support', 'other')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'closed')),
  admin_response TEXT,
  responded_at TIMESTAMP WITH TIME ZONE,
  responded_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS feedback_user_id_idx ON feedback(user_id);
CREATE INDEX IF NOT EXISTS feedback_status_idx ON feedback(status);
CREATE INDEX IF NOT EXISTS feedback_category_idx ON feedback(category);
CREATE INDEX IF NOT EXISTS feedback_created_at_idx ON feedback(created_at);

-- Enable RLS
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- Users can view their own feedback
CREATE POLICY "feedback_user_own"
  ON feedback FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

-- Users can insert their own feedback
CREATE POLICY "feedback_user_insert"
  ON feedback FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Admins can view all feedback
CREATE POLICY "feedback_admin_view"
  ON feedback FOR SELECT
  USING (check_is_admin());

-- Admins can update feedback (for responses and status)
CREATE POLICY "feedback_admin_update"
  ON feedback FOR UPDATE
  USING (check_is_admin())
  WITH CHECK (check_is_admin());

-- Insert sample feedback data
INSERT INTO feedback (user_id, user_email, subject, message, category, status) VALUES
  ('550e8400-e29b-41d4-a716-446655440002', 'user@ecocycle.com', 'App Performance Issue', 'The app is running slow when submitting e-waste items. Please fix this.', 'bug', 'pending'),
  ('550e8400-e29b-41d4-a716-446655440003', 'volunteer@ecocycle.com', 'Volunteer Scheduling Feature', 'It would be great to have a calendar view for volunteer schedules.', 'feature', 'reviewed'),
  ('550e8400-e29b-41d4-a716-446655440001', 'agent@ecocycle.com', 'Pickup Route Optimization', 'Need better route planning for multiple pickups in the same area.', 'feature', 'resolved')
ON CONFLICT DO NOTHING;
