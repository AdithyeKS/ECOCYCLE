import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/volunteer_application.dart';

class ProfileService {
  final SupabaseClient supabase = AppSupabase.client;

  /// Updates basic profile info (Name, Phone, Address)
  /// Use this to save user data before or during the volunteer process
  /// IMPORTANT: This now properly handles upsert to ensure data is saved
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String phone,
    required String address,
  }) async {
    try {
      // Use upsert to ensure the row exists and is updated
      final response = await supabase.from('profiles').upsert({
        'id': userId,
        'full_name': fullName.trim(),
        'phone_number': phone.trim(),
        'address': address.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Log success
      print('Profile updated successfully for user: $userId');
      print('Response: $response');
    } catch (e) {
      print('ERROR updating profile for user $userId: $e');
      rethrow; // Re-throw so calling code knows about the error
    }
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
        .select(
            'id, full_name, phone_number, address, user_role, total_points, volunteer_requested_at, supervisor_id')
        .eq('id', userId)
        .maybeSingle();
  }

  /// FIXED: Fetch supervisor details for a given user
  /// Returns supervisor's name and phone number if they have one
  Future<Map<String, dynamic>?> fetchSupervisorDetails(String userId) async {
    try {
      // First get the user's supervisor_id
      final userProfile = await supabase
          .from('profiles')
          .select('supervisor_id')
          .eq('id', userId)
          .maybeSingle();

      if (userProfile == null || userProfile['supervisor_id'] == null) {
        print('No supervisor found for user: $userId');
        return null;
      }

      final supervisorId = userProfile['supervisor_id'];

      // Now fetch the supervisor's details
      final supervisorProfile = await supabase
          .from('profiles')
          .select('id, full_name, phone_number')
          .eq('id', supervisorId)
          .maybeSingle();

      print('Supervisor details fetched: $supervisorProfile');
      return supervisorProfile;
    } catch (e) {
      print('ERROR fetching supervisor details: $e');
      return null;
    }
  }

  /// Fetches all profiles for admin management.
  Future<List<Map<String, dynamic>>> fetchAllProfiles() async {
    try {
      final data = await supabase
          .from('profiles')
          .select(
              'id, full_name, email, user_role, volunteer_requested_at, phone_number, address, total_points')
          .order('full_name', ascending: true);
      print(
          '✓ Profiles fetched successfully: ${(data as List).length} profiles');
      return (data as List).map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      print('✗ Error fetching profiles: $e');
      rethrow;
    }
  }

  /// Professional Volunteer Application Submission for Social Work
  Future<void> submitVolunteerApplication(VolunteerApplication app) async {
    // 1. Ensure profile has the latest contact info from the app
    await updateProfile(
      userId: app.userId,
      fullName: app.fullName,
      phone: app.phone,
      address: app.address,
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
    try {
      final res = await supabase
          .from('volunteer_applications')
          .select()
          .order('created_at', ascending: false);
      print(
          '✓ All volunteer applications fetched: ${(res as List).length} applications');
      return (res as List)
          .map((e) => VolunteerApplication.fromJson(e))
          .toList();
    } catch (e) {
      print('✗ Error fetching volunteer applications: $e');
      rethrow;
    }
  }

  /// Admin Decision Procedure for Volunteers
  Future<void> decideOnApplication(
      String appId, String userId, bool approve) async {
    final newStatus = approve ? 'approved' : 'rejected';
    final newRole = approve ? 'volunteer' : 'user';

    try {
      // 1. Update the application record status
      await supabase
          .from('volunteer_applications')
          .update({'status': newStatus}).eq('id', appId);

      // 2. Update the user role
      await supabase.from('profiles').update({
        'user_role': newRole,
        'volunteer_requested_at': null,
      }).eq('id', userId);

      // 3. If approved, create pickup request entry
      if (approve) {
        final profile = await fetchProfile(userId);
        try {
          await supabase.from('pickup_requests').insert({
            'agent_id': userId,
            'name': profile?['full_name'] ?? 'Volunteer',
            'phone': profile?['phone_number'] ?? 'N/A',
            'email': profile?['email'] ?? 'N/A',
            'is_active': true,
          });
        } catch (e) {
          print('Note: Could not create pickup_request: $e');
          // Not critical if this fails
        }
      }

      print('Application decision successful: $newStatus');
    } catch (e) {
      print('Error in decideOnApplication: $e');
      rethrow;
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

  Future<void> sendEmailNotification(
      String userId, String subject, String message) async {
    // Integration placeholder
    print('Notification for $userId: $subject - $message');
  }

  Future<void> sendStatusUpdateNotification(
      String userId, String itemName, String newStatus) async {
    await sendEmailNotification(userId, 'EcoCycle Status Update',
        'Your item "$itemName" is now: $newStatus.');
  }

  /// Notifies the user about earned points (Required by EwasteService)
  Future<void> sendPointsEarnedNotification(
      String userId, String itemName, int points) async {
    final subject = 'EcoPoints Earned!';
    final message = 'You earned $points EcoPoints for recycling "$itemName".';
    await sendEmailNotification(userId, subject, message);
  }

  /// Deletes a user account and all associated data
  Future<void> deleteUser(String userId) async {
    try {
      // Delete in order to avoid foreign key constraints
      // 1. Delete volunteer assignments
      await supabase
          .from('volunteer_assignments')
          .delete()
          .eq('volunteer_id', userId);

      // 2. Delete volunteer schedules
      await supabase
          .from('volunteer_schedules')
          .delete()
          .eq('volunteer_id', userId);

      // 3. Delete volunteer applications
      await supabase
          .from('volunteer_applications')
          .delete()
          .eq('user_id', userId);

      // 4. Delete e-waste items
      await supabase.from('ewaste_items').delete().eq('user_id', userId);

      // 5. Delete cloth items
      await supabase.from('cloth_items').delete().eq('user_id', userId);

      // 6. Delete pickup agent entry if exists
      await supabase.from('pickup_requests').delete().eq('id', userId);

      // 7. Delete notifications
      await supabase.from('notifications').delete().eq('user_id', userId);

      // 8. Finally delete the profile
      await supabase.from('profiles').delete().eq('id', userId);

      print('User $userId and all associated data deleted successfully');
    } catch (e) {
      print('ERROR deleting user $userId: $e');
      rethrow;
    }
  }

  /// Fetches all volunteer applications (Admin only)
}
