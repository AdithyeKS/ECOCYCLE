import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/volunteer_application.dart';

class ProfileService {
  final SupabaseClient supabase = AppSupabase.client;

  /// Updates basic profile info (Name, Phone, Address)
  /// Use this to save user data before or during the volunteer process
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String phone,
    required String address,
  }) async {
    await supabase.from('profiles').update({
      'full_name': fullName,
      'phone_number': phone,
      'address': address,
    }).eq('id', userId);
  }

  /// Add EcoPoints to user profile
  Future<void> addEcoPoints(String userId, int points) async {
    final currentProfile = await supabase
        .from('profiles')
        .select('total_points')
        .eq('id', userId)
        .single();

    final currentPoints = currentProfile['total_points'] as int? ?? 0;
    final newPoints = currentPoints + points;

    await supabase
        .from('profiles')
        .update({'total_points': newPoints}).eq('id', userId);
  }

  /// Deduct EcoPoints from user profile
  Future<void> deductEcoPoints(String userId, int points) async {
    final currentProfile = await supabase
        .from('profiles')
        .select('total_points')
        .eq('id', userId)
        .single();

    final currentPoints = currentProfile['total_points'] as int? ?? 0;

    if (currentPoints < points) {
      throw Exception('Insufficient EcoPoints.');
    }

    final newPoints = currentPoints - points;

    await supabase
        .from('profiles')
        .update({'total_points': newPoints}).eq('id', userId);
  }

  // --- ROLE & APPLICATION MANAGEMENT ---

  /// Fetches profile with extra fields for pre-filling volunteer forms
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    return await supabase
        .from('profiles')
        .select('id, full_name, email, phone_number, address, user_role, total_points, volunteer_requested_at')
        .eq('id', userId)
        .maybeSingle();
  }

  /// Fetches all profiles for admin management.
  Future<List<Map<String, dynamic>>> fetchAllProfiles() async {
    final data = await supabase
        .from('profiles')
        .select('id, full_name, email, user_role, volunteer_requested_at')
        .order('full_name', ascending: true);
    return (data as List).map((e) => e as Map<String, dynamic>).toList();
  }

  /// Professional Volunteer Application Submission for Social Work
  Future<void> submitVolunteerApplication(VolunteerApplication app) async {
    // 1. Ensure profile has the latest contact info from the app
    await updateProfile(
      userId: app.userId,
      fullName: app.fullName,
      phone: app.phone,
      address: '', // Update if your app captures address here
    );

    // 2. Insert detailed application
    await supabase.from('volunteer_applications').insert(app.toJson());
    
    // 3. Mark profile as having a pending volunteer request
    await supabase.from('profiles').update({
      'volunteer_requested_at': DateTime.now().toIso8601String(),
    }).eq('id', app.userId);
  }

  /// Fetch all applications for Admin review
  Future<List<VolunteerApplication>> fetchAllApplications() async {
    final res = await supabase
        .from('volunteer_applications')
        .select()
        .order('created_at', ascending: false);
    return (res as List).map((e) => VolunteerApplication.fromJson(e)).toList();
  }

  /// Admin Decision Procedure for Volunteers
  Future<void> decideOnApplication(String appId, String userId, bool approve) async {
    final newStatus = approve ? 'approved' : 'rejected';
    final newRole = approve ? 'agent' : 'user';

    // 1. Update the application record status
    await supabase.from('volunteer_applications').update({
      'status': newStatus
    }).eq('id', appId);

    // 2. Update the user role and clear the request timestamp
    await supabase.from('profiles').update({
      'user_role': newRole,
      'volunteer_requested_at': null, 
    }).eq('id', userId);
    
    // 3. If approved, ensure they are in the pickup agents list
    if (approve) {
       final profile = await fetchProfile(userId);
       await supabase.from('pickup_requests').upsert({
         'id': userId,
         'name': profile?['full_name'] ?? 'Volunteer Agent',
         'phone': profile?['phone_number'] ?? 'N/A',
         'is_active': true,
       });
    }
  }

  /// Updates the role of a user manually.
  Future<void> updateUserRole(String userId, String newRole) async {
    await supabase.from('profiles').update({
      'user_role': newRole,
      'volunteer_requested_at': null,
    }).eq('id', userId);
  }

  /// Clears the volunteer request timestamp.
  Future<void> clearVolunteerRequest(String userId) async {
    await supabase.from('profiles').update({
      'volunteer_requested_at': null,
    }).eq('id', userId);
  }

  // --- NOTIFICATION METHODS ---

  Future<void> sendEmailNotification(String userId, String subject, String message) async {
    // Integration placeholder
    print('Notification for $userId: $subject - $message');
  }

  Future<void> sendStatusUpdateNotification(String userId, String itemName, String newStatus) async {
    await sendEmailNotification(userId, 'EcoCycle Status Update', 'Your item "$itemName" is now: $newStatus.');
  }

  /// Notifies the user about earned points (Required by EwasteService)
  Future<void> sendPointsEarnedNotification(String userId, String itemName, int points) async {
    final subject = 'EcoPoints Earned!';
    final message = 'You earned $points EcoPoints for recycling "$itemName".';
    await sendEmailNotification(userId, subject, message);
  }
}