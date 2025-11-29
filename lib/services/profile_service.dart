import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class ProfileService {
  final SupabaseClient supabase = AppSupabase.client;

  /// Add EcoPoints to user profile
  Future<void> addEcoPoints(String userId, int points) async {
    // Get current points
    final currentProfile = await supabase
        .from('profiles')
        .select('total_points')
        .eq('id', userId)
        .single();

    final currentPoints = currentProfile['total_points'] as int? ?? 0;
    final newPoints = currentPoints + points;

    // Update profile
    await supabase
        .from('profiles')
        .update({'total_points': newPoints}).eq('id', userId);
  }

  /// NEW FUNCTION: Deduct EcoPoints from user profile
  Future<void> deductEcoPoints(String userId, int points) async {
    // Get current points
    final currentProfile = await supabase
        .from('profiles')
        .select('total_points')
        .eq('id', userId)
        .single();

    final currentPoints = currentProfile['total_points'] as int? ?? 0;
    
    if (currentPoints < points) {
      throw Exception('Insufficient EcoPoints to claim this reward.');
    }
    
    final newPoints = currentPoints - points;

    // Update profile
    await supabase
        .from('profiles')
        .update({'total_points': newPoints}).eq('id', userId);
  }

  /// Send email notification (placeholder - would integrate with email service)
  Future<void> sendEmailNotification(
      String userId, String subject, String message) async {
    // TODO: Integrate with actual email service (e.g., SendGrid, Firebase Functions)
    // For now, just log the notification
    print('📧 EMAIL NOTIFICATION for user $userId:');
    print('Subject: $subject');
    print('Message: $message');
    print('---');

    // In production, this would call an email service API
    // Example: await emailService.sendEmail(userEmail, subject, message);
  }

  /// Send status update notification
  Future<void> sendStatusUpdateNotification(
      String userId, String itemName, String newStatus) async {
    final subject = 'E-Waste Status Update';
    final message = '''
Dear EcoCycle User,

Your e-waste item "$itemName" has been updated to status: $newStatus.

Thank you for contributing to a sustainable future!

Best regards,
EcoCycle Team
''';

    await sendEmailNotification(userId, subject, message);
  }

  /// Send EcoPoints earned notification
  Future<void> sendPointsEarnedNotification(
      String userId, String itemName, int points) async {
    final subject = 'EcoPoints Earned!';
    final message = '''
Congratulations!

You've earned $points EcoPoints for recycling your "$itemName".

Keep up the great work for our planet!

Best regards,
EcoCycle Team
''';

    await sendEmailNotification(userId, subject, message);
  }
}