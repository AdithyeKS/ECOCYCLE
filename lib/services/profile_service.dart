import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecocycle/core/supabase_config.dart';
import 'package:ecocycle/models/volunteer_application.dart';

class ProfileService {
  final SupabaseClient supabase = AppSupabase.client;

  /// Updates basic profile info (Name, Phone, Address)
  /// Use this to save user data before or during the volunteer process
  /// IMPORTANT: This now properly handles upsert to ensure data is saved
  Future<void> updateProfile({
    required String userId,
    required String firstName,
    required String lastName,
    required String phone,
    required String houseName,
    required String pinCode,
  }) async {
    try {
      // Use upsert to ensure the row exists and is updated
      await supabase.from('profiles').upsert({
        'id': userId,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'phone_number': phone.trim(),
        'house_name': houseName.trim(),
        'pin_code': pinCode.trim(),
        'address': '$houseName - $pinCode', // Legacy address sync
        'user_role':
            'user', // Ensure user_role is set to avoid constraint violation
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
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
            'id, first_name, last_name, full_name, phone_number, address, user_role, total_points, volunteer_requested_at, supervisor_id')
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
        return null;
      }

      final supervisorId = userProfile['supervisor_id'];

      // Now fetch the supervisor's details
      final supervisorProfile = await supabase
          .from('profiles')
          .select('id, full_name, phone_number')
          .eq('id', supervisorId)
          .maybeSingle();

      return supervisorProfile;
    } catch (e) {
      return null;
    }
  }

  /// Fetches all profiles for admin management.
  Future<List<Map<String, dynamic>>> fetchAllProfiles() async {
    try {
      try {
        // Try to fetch from admin_user_details view first
        final data = await supabase
            .from('admin_user_details')
            .select(
                'id, full_name, email, user_role, phone_number, address, total_points, created_at')
            .order('full_name', ascending: true);

        final List<Map<String, dynamic>> profiles =
            (data as List).cast<Map<String, dynamic>>();

        return profiles;
      } catch (viewError) {
        // Fallback to profiles table if view doesn't exist
        final data = await supabase
            .from('profiles')
            .select(
                'id, full_name, user_role, phone_number, address, total_points, created_at')
            .order('full_name', ascending: true);

        final List<Map<String, dynamic>> profiles =
            (data as List).cast<Map<String, dynamic>>();

        return profiles;
      }
    } catch (e) {
      return []; // Return empty list instead of rethrowing to prevent cascading failures
    }
  }

  /// Professional Volunteer Application Submission for Social Work
  Future<void> submitVolunteerApplication(VolunteerApplication app) async {
    // 1. Ensure profile has the latest contact info from the app
    await updateProfile(
      userId: app.userId,
      firstName: app.fullName.split(' ').first,
      lastName: app.fullName.contains(' ') ? app.fullName.split(' ').last : '',
      phone: app.phone,
      houseName: app.address.split(',').first,
      pinCode: '', // Not easily splittable from old format
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
      return (res as List)
          .map((e) => VolunteerApplication.fromJson(e))
          .toList();
    } catch (e) {
      return []; // Return empty list instead of rethrowing to prevent cascading failures
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

      // 2. Update the user role (only update role and timestamp)
      final existingProfile = await supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existingProfile != null) {
        await supabase.from('profiles').update({
          'user_role': newRole,
          'volunteer_requested_at': null,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      } else {
        // Create profile if it doesn't exist
        await supabase.from('profiles').insert({
          'id': userId,
          'user_role': newRole,
          'volunteer_requested_at': null,
          'full_name': 'Unknown',
          'phone_number': 'N/A',
          'address': 'N/A',
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // 3. If approved, create pickup request entry
      if (approve) {
        final profile = await fetchProfile(userId);
        try {
          await supabase.from('pickup_requests').insert({
            'id': userId,
            'name': profile?['full_name'] ?? 'Volunteer',
            'phone': profile?['phone_number'] ?? 'N/A',
            'email': profile?['email'] ?? 'N/A',
            'is_active': true,
          });
        } catch (e) {
          // Not critical if this fails
        }
      }
    } catch (e) {
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

  /// Fetches a user's email address for notifications securely
  Future<String?> _getUserEmail(String userId) async {
    try {
      // Use the security definer RPC to bypass RLS
      final response = await supabase.rpc('get_user_email_secure', params: {
        'p_user_id': userId,
      });
      return response as String?;
    } catch (e) {
      // Fallback to existing view if RPC fails
      try {
        final viewData = await supabase
            .from('admin_user_details')
            .select('email')
            .eq('id', userId)
            .maybeSingle();
        return viewData?['email'] as String?;
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> sendEmailNotification(
      String userId, String subject, String message,
      {String importance = 'normal'}) async {
    try {
      // 1. Persist notification to database so user can see it in-app
      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': subject,
        'message': message,
        'type': 'email_notification',
        'importance': importance,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Fetch recipient email
      final email = await _getUserEmail(userId);

      if (email != null && email.isNotEmpty) {
        // 3. Call Supabase RPC to send real email
        await supabase.rpc('send_notification_email', params: {
          'recipient_email': email,
          'email_subject': subject,
          'email_message': message,
        });
      }
    } catch (e) {
      // Log error but don't block the UI flow
    }
  }

  Future<void> sendStatusUpdateNotification(
      String userId, String itemName, String newStatus) async {
    // Status updates are normal importance (won't show for regular users)
    await sendEmailNotification(userId, 'EcoCycle Status Update',
        'Your item "$itemName" is now: $newStatus.',
        importance: 'normal');
  }

  /// Notifies the user about earned points (Required by EwasteService) - HIGH importance
  Future<void> sendPointsEarnedNotification(
      String userId, String itemName, int points) async {
    final subject = 'EcoPoints Earned!';
    final message = 'You earned $points EcoPoints for recycling "$itemName".';
    await sendEmailNotification(userId, subject, message, importance: 'high');
  }

  /// Notifies the user about their OTP for collection verification - HIGH importance
  Future<void> sendOtpNotification(
      String userId, String otp, String itemName) async {
    try {
      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': 'Collection Verification Code',
        'message':
            'Your verification code for the collection of "$itemName" is: $otp. Valid for 10 minutes.',
        'type': 'otp_message',
        'importance': 'high',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Log error or handle gracefully
    }
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

      // 5. Delete cloth items (Correct table name: cloth_donations)
      await supabase.from('cloth_donations').delete().eq('user_id', userId);

      // 6. Delete plastic items
      await supabase.from('plastic_items').delete().eq('user_id', userId);

      // 7. Delete pickup agent entry if exists
      await supabase.from('pickup_requests').delete().eq('id', userId);

      // 8. Delete notifications
      await supabase.from('notifications').delete().eq('user_id', userId);

      // 9. Finally delete the profile
      await supabase.from('profiles').delete().eq('id', userId);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a volunteer application
  Future<void> deleteVolunteerApplication(String appId) async {
    try {
      await supabase.from('volunteer_applications').delete().eq('id', appId);
    } catch (e) {
      throw Exception('Failed to delete volunteer application: $e');
    }
  }

  /// Revokes volunteer status and allows them to re-apply
  Future<void> revokeVolunteerStatus(
      String appId, String userId, String? comment) async {
    try {
      // 1. Delete from applications so they can re-apply
      await supabase.from('volunteer_applications').delete().eq('id', appId);

      // 2. Set role back to user
      await supabase.from('profiles').update({
        'user_role': 'user',
        'volunteer_requested_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      // 3. Remove from pickup_requests if they were added as a picker
      await supabase.from('pickup_requests').delete().eq('id', userId);

      // 4. Send notification if a comment is provided - HIGH importance
      if (comment != null && comment.isNotEmpty) {
        await sendEmailNotification(
            userId, 'Volunteer Status Revoked', 'Comment: $comment',
            importance: 'high');
      }
    } catch (e) {
      rethrow;
    }
  }
}
