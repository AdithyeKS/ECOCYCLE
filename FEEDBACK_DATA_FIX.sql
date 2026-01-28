-- ============================================================================
-- FEEDBACK DATA FIX - Add Test Data and Verify Policies
-- Run this in Supabase SQL Editor to fix feedback data fetching issues
-- ============================================================================

-- First, verify the feedback table exists and has correct structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'feedback' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Verify RLS policies exist
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'feedback';

-- Insert test feedback data (only if table is empty)
INSERT INTO feedback (user_id, user_email, subject, message, category, status) VALUES
  ('550e8400-e29b-41d4-a716-446655440002', 'user@ecocycle.com', 'App Performance Issue', 'The app is running slow when submitting e-waste items. Please fix this.', 'bug', 'pending'),
  ('550e8400-e29b-41d4-a716-446655440003', 'volunteer@ecocycle.com', 'Volunteer Scheduling Feature', 'It would be great to have a calendar view for volunteer schedules.', 'feature', 'reviewed'),
  ('550e8400-e29b-41d4-a716-446655440001', 'agent@ecocycle.com', 'Pickup Route Optimization', 'Need better route planning for multiple pickups in the same area.', 'feature', 'resolved'),
  ('550e8400-e29b-41d4-a716-446655440002', 'user@ecocycle.com', 'UI Improvement Suggestion', 'The navigation could be more intuitive. Consider adding breadcrumbs.', 'feature', 'pending'),
  ('550e8400-e29b-41d4-a716-446655440003', 'volunteer@ecocycle.com', 'Notification System', 'I would like to receive notifications about new assignments.', 'feature', 'pending')
ON CONFLICT DO NOTHING;

-- Verify admin user exists and has admin role
SELECT id, full_name, email, user_role FROM profiles WHERE user_role = 'admin';

-- Test the check_is_admin function (run this manually by replacing with actual admin user ID)
-- SELECT check_is_admin() as is_admin;

-- If still no data shows, temporarily disable RLS for testing (REMOVE THIS AFTER TESTING)
-- ALTER TABLE feedback DISABLE ROW LEVEL SECURITY;

-- Check current feedback count
SELECT COUNT(*) as feedback_count FROM feedback;

-- Show all feedback (admin should be able to see this)
SELECT id, user_email, subject, category, status, created_at FROM feedback ORDER BY created_at DESC;
