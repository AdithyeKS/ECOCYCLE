import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feedback.dart';

class FeedbackService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<FeedbackItem>> fetchAllFeedback() async {
    try {
      final response = await _supabase
          .from('feedback')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => FeedbackItem.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch feedback: $e');
    }
  }

  Future<void> respondToFeedback(
      String feedbackId, String adminResponse) async {
    await updateFeedbackStatus(feedbackId, 'responded', adminResponse);
  }

  Future<void> updateFeedbackStatus(
      String feedbackId, String status, String? adminResponse) async {
    try {
      final updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (adminResponse != null && adminResponse.isNotEmpty) {
        updateData['admin_response'] = adminResponse;
        updateData['responded_at'] = DateTime.now().toIso8601String();
        final currentUserId = _supabase.auth.currentUser?.id;
        if (currentUserId != null) {
          updateData['responded_by'] = currentUserId;
        }
      }

      await _supabase.from('feedback').update(updateData).eq('id', feedbackId);

      // Send email notification if there's an admin response
      if (adminResponse != null && adminResponse.isNotEmpty) {
        await _sendFeedbackResponseEmail(feedbackId, adminResponse);
      }
    } catch (e) {
      throw Exception('Failed to update feedback: $e');
    }
  }

  Future<void> _sendFeedbackResponseEmail(
      String feedbackId, String response) async {
    try {
      // Fetch feedback details including user email
      final feedbackResponse = await _supabase
          .from('feedback')
          .select('user_email, subject, message')
          .eq('id', feedbackId)
          .single();

      final userEmail = feedbackResponse['user_email'] as String?;
      final subject = feedbackResponse['subject'] as String;
      final originalMessage = feedbackResponse['message'] as String;

      if (userEmail != null && userEmail.isNotEmpty) {
        // Use Supabase RPC function to send email
        await _supabase.rpc('send_feedback_email', params: {
          'recipient_email': userEmail,
          'email_subject': 'Response to your feedback: $subject',
          'feedback_subject': subject,
          'original_message': originalMessage,
          'admin_response': response,
        });
      }
    } catch (e) {
      // Log the error but don't fail the feedback update
      print('Failed to send feedback response email: $e');
    }
  }

  Future<void> submitFeedback({
    required String subject,
    required String message,
    required String category,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _supabase.from('feedback').insert({
        'user_id': currentUser.id,
        'user_email': currentUser.email,
        'subject': subject,
        'message': message,
        'category': category,
        'status': 'pending',
      });
    } catch (e) {
      throw Exception('Failed to submit feedback: $e');
    }
  }

  Future<String> getFeedbackTableSQL() async {
    // Return the SQL structure of the feedback table
    return '''
-- Feedback Table Structure
CREATE TABLE feedback (
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

-- Indexes
CREATE INDEX feedback_user_id_idx ON feedback(user_id);
CREATE INDEX feedback_status_idx ON feedback(status);
CREATE INDEX feedback_category_idx ON feedback(category);
CREATE INDEX feedback_created_at_idx ON feedback(created_at);

-- Row Level Security
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "feedback_user_own" ON feedback FOR SELECT USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "feedback_user_insert" ON feedback FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "feedback_admin_view" ON feedback FOR SELECT USING (check_is_admin());
CREATE POLICY "feedback_admin_update" ON feedback FOR UPDATE USING (check_is_admin()) WITH CHECK (check_is_admin());
''';
  }
}
