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

  /// Deduct EcoPoints from user profile
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
  
  // --- ROLE MANAGEMENT FUNCTIONS ---

  /// Fetches the profile for a given user ID.
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final res = await supabase
        .from('profiles')
        .select('full_name, user_role, id') // Fetch role and name
        .eq('id', userId)
        .maybeSingle();
    return res;
  }
  
  /// Fetches all profiles for admin management.
  Future<List<Map<String, dynamic>>> fetchAllProfiles() async {
    final data = await supabase
        .from('profiles')
        .select('id, full_name, email, user_role, volunteer_requested_at') // Includes NEW FIELD for filtering requests
        .order('full_name', ascending: true);
    return (data as List).map((e) => e as Map<String, dynamic>).toList();
  }

  /// Updates the role of a user. Clears the request timestamp if role is being set.
  Future<void> updateUserRole(String userId, String newRole) async {
    await supabase.from('profiles').update({
      'user_role': newRole,
      'volunteer_requested_at': null, // Clear request when role is set/changed
    }).eq('id', userId);
  }
  
  /// Marks a user as requesting the Volunteer role by setting a timestamp.
  Future<void> requestVolunteerRole(String userId) async {
    await supabase.from('profiles').update({
      'volunteer_requested_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  // --- EMAIL NOTIFICATION FUNCTIONS ---

  /// Send email notification (placeholder - would integrate with email service)
  Future<void> sendEmailNotification(
      String userId, String subject, String message) async {
    // TODO: Integrate with actual email service (e.g., SendGrid, Firebase Functions)
    // For now, just log the notification
    print('📧 EMAIL NOTIFICATION for user $userId:');
    print('Subject: $subject');
    print('Message: $message');
    print('---');
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