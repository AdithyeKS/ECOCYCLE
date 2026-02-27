-- Add importance column to notifications table
-- This allows filtering notifications by importance level
-- Users will only see 'high' importance notifications
-- Volunteers and admins will see all notifications

ALTER TABLE notifications 
ADD COLUMN IF NOT EXISTS importance TEXT DEFAULT 'normal' CHECK (importance IN ('high', 'normal', 'low'));

-- Update existing notifications to have default importance
UPDATE notifications 
SET importance = 'normal' 
WHERE importance IS NULL;

-- Mark important notification types as high importance
UPDATE notifications 
SET importance = 'high' 
WHERE type IN ('delivery_pickup', 'otp_message', 'assignment_new', 'assignment_pending', 'collection_request', 'volunteer_revoked', 'points_earned');

-- Create index for faster filtering
CREATE INDEX IF NOT EXISTS idx_notifications_importance ON notifications(user_id, importance, is_read);

COMMENT ON COLUMN notifications.importance IS 'Importance level: high (shown to all users), normal (shown to volunteers/admins only), low (optional notifications)';
