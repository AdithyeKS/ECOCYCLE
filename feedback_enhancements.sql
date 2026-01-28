-- Feedback System Enhancements SQL
-- This file contains the SQL updates for enhanced feedback management

-- Update feedback table to include new status options
-- Note: The table already has the required fields, but let's ensure the status check constraint is updated

-- First, drop the existing constraint if it exists
ALTER TABLE feedback DROP CONSTRAINT IF EXISTS feedback_status_check;

-- Add the updated status check constraint with new statuses
ALTER TABLE feedback ADD CONSTRAINT feedback_status_check
  CHECK (status IN ('pending', 'reviewed', 'resolved', 'closed'));

-- Create a function to send feedback response emails (for Supabase Edge Functions)
-- This would be deployed as a Supabase Edge Function
/*
Edge Function: send-feedback-response
Body: {
  "to": "user@example.com",
  "subject": "Response to your feedback: Issue Title",
  "feedback_subject": "Original Subject",
  "original_message": "User's original message",
  "admin_response": "Admin's response message"
}
*/

-- Create a view for admin feedback management
CREATE OR REPLACE VIEW admin_feedback_view AS
SELECT
  f.id,
  f.user_id,
  f.user_email,
  f.subject,
  f.message,
  f.category,
  f.status,
  f.admin_response,
  f.responded_at,
  f.responded_by,
  f.created_at,
  f.updated_at,
  p.full_name as user_name,
  p.phone_number as user_phone
FROM feedback f
LEFT JOIN profiles p ON f.user_id = p.id
ORDER BY f.created_at DESC;

-- Create a view for user feedback history
CREATE OR REPLACE VIEW user_feedback_history AS
SELECT
  f.id,
  f.subject,
  f.message,
  f.category,
  f.status,
  f.admin_response,
  f.responded_at,
  f.created_at,
  f.updated_at
FROM feedback f
WHERE f.user_id = auth.uid()
ORDER BY f.created_at DESC;

-- Grant permissions
GRANT SELECT ON admin_feedback_view TO authenticated;
GRANT SELECT ON user_feedback_history TO authenticated;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS feedback_status_updated_at_idx ON feedback(status, updated_at DESC);
CREATE INDEX IF NOT EXISTS feedback_user_status_idx ON feedback(user_id, status);



-- Function to get feedback statistics for admin dashboard
CREATE OR REPLACE FUNCTION get_feedback_stats()
RETURNS TABLE (
  total_feedback bigint,
  pending_count bigint,
  reviewed_count bigint,
  resolved_count bigint,
  closed_count bigint,
  avg_response_time interval
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) as total_feedback,
    COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
    COUNT(*) FILTER (WHERE status = 'reviewed') as reviewed_count,
    COUNT(*) FILTER (WHERE status = 'resolved') as resolved_count,
    COUNT(*) FILTER (WHERE status = 'closed') as closed_count,
    AVG(responded_at - created_at) FILTER (WHERE responded_at IS NOT NULL) as avg_response_time
  FROM feedback;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;



-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_feedback_stats() TO authenticated;

-- Comments for documentation
COMMENT ON TABLE feedback IS 'User feedback and support tickets with admin responses';
COMMENT ON COLUMN feedback.status IS 'Status of feedback: pending, reviewed, resolved, closed';
COMMENT ON COLUMN feedback.admin_response IS 'Admin response to the feedback';
COMMENT ON COLUMN feedback.responded_at IS 'Timestamp when admin responded';
COMMENT ON COLUMN feedback.responded_by IS 'Admin user ID who responded';
COMMENT ON VIEW admin_feedback_view IS 'Admin view of all feedback with user details';
COMMENT ON VIEW user_feedback_history IS 'User view of their own feedback history';
COMMENT ON FUNCTION get_feedback_stats() IS 'Returns feedback statistics for admin dashboard';

