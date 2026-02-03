import 'package:EcoCycle/core/supabase_config.dart';
import '../models/volunteer_schedule.dart';
import '../models/volunteer_assignment.dart';

class VolunteerScheduleService {
  final _supabase = AppSupabase.client;

  // --- User/Volunteer Methods ---

  /// Fetches all schedule records for a specific volunteer.
  Future<List<VolunteerSchedule>> fetchVolunteerSchedules(
      String volunteerId) async {
    final response = await _supabase
        .from('volunteer_schedules')
        .select()
        .eq('volunteer_id', volunteerId);

    return (response as List)
        .map((json) => VolunteerSchedule.fromJson(json))
        .toList();
  }

  /// Sets or updates a volunteer's availability for a specific date.
  Future<void> setAvailability(
      String volunteerId, DateTime date, bool isAvailable) async {
    final dateString = date.toIso8601String().split('T')[0];

    final existing = await _supabase
        .from('volunteer_schedules')
        .select()
        .eq('volunteer_id', volunteerId)
        .eq('date', dateString)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('volunteer_schedules')
          .update({'is_available': isAvailable}).eq('id', existing['id']);
    } else {
      await _supabase.from('volunteer_schedules').insert({
        'volunteer_id': volunteerId,
        'date': dateString,
        'is_available': isAvailable,
      });
    }
  }

  /// Removes a volunteer's schedule entry entirely.
  Future<void> deleteVolunteerSchedule(String scheduleId) async {
    await _supabase.from('volunteer_schedules').delete().eq('id', scheduleId);
  }

  /// Fetches tasks assigned to a specific volunteer.
  Future<List<VolunteerAssignment>> fetchVolunteerAssignments(
      String volunteerId) async {
    final response = await _supabase
        .from('volunteer_assignments')
        .select()
        .eq('volunteer_id', volunteerId);

    return (response as List)
        .map((json) => VolunteerAssignment.fromJson(json))
        .toList();
  }

  /// Fetches detailed assignment information including item and user details for volunteers
  Future<List<Map<String, dynamic>>> fetchDetailedVolunteerAssignments(
      String volunteerId) async {
    final response = await _supabase
        .from('volunteer_assignments')
        .select()
        .eq('volunteer_id', volunteerId);

    final List<Map<String, dynamic>> detailedAssignments = [];

    for (final assignmentJson in response as List) {
      final assignment = VolunteerAssignment.fromJson(assignmentJson);
      Map<String, dynamic>? item;

      // Query the appropriate table based on waste_type
      String tableName;
      switch (assignment.wasteType) {
        case 'e-waste':
          tableName = 'ewaste_items';
          break;
        case 'plastic':
          tableName = 'plastic_items';
          break;
        case 'cloth':
          tableName = 'cloth_items';
          break;
        default:
          tableName = 'ewaste_items'; // fallback
      }

      // Fetch item details
      final itemResponse = await _supabase
          .from(tableName)
          .select(
              'id, item_name, description, location, image_url, category_id, user_id, pickup_scheduled_at, delivery_status')
          .eq('id', assignment.wasteItemId)
          .maybeSingle();

      if (itemResponse != null) {
        item = itemResponse;
        // Fetch user profile for the item owner
        final userProfile = await _supabase
            .from('profiles')
            .select('full_name, phone_number')
            .eq('id', item['user_id'])
            .maybeSingle();

        detailedAssignments.add({
          'assignment': assignment,
          'item': item,
          'user':
              userProfile ?? {'full_name': 'Unknown', 'phone_number': 'N/A'},
        });
      }
    }

    return detailedAssignments;
  }

  /// Fetches detailed assignment information including item and user details for ALL volunteers (admin view)
  Future<List<Map<String, dynamic>>> fetchAllDetailedAssignments() async {
    final response = await _supabase.from('volunteer_assignments').select();

    final List<Map<String, dynamic>> detailedAssignments = [];

    for (final assignmentJson in response as List) {
      final assignment = VolunteerAssignment.fromJson(assignmentJson);
      Map<String, dynamic>? item;
      Map<String, dynamic>? userProfile;

      // Query the appropriate table based on waste_type
      String tableName;
      switch (assignment.wasteType) {
        case 'e-waste':
          tableName = 'ewaste_items';
          break;
        case 'plastic':
          tableName = 'plastic_items';
          break;
        case 'cloth':
          tableName = 'cloth_items';
          break;
        default:
          tableName = 'ewaste_items'; // fallback
      }

      // Fetch item details
      final itemResponse = await _supabase
          .from(tableName)
          .select(
              'id, item_name, description, location, image_url, category_id, user_id, pickup_scheduled_at, delivery_status')
          .eq('id', assignment.wasteItemId)
          .maybeSingle();

      if (itemResponse != null) {
        item = itemResponse;
        // Fetch user profile for the item owner
        userProfile = await _supabase
            .from('profiles')
            .select('full_name, phone_number')
            .eq('id', item['user_id'])
            .maybeSingle();
      }

      // Fetch volunteer profile
      final volunteerProfile = await _supabase
          .from('profiles')
          .select('full_name, phone_number')
          .eq('id', assignment.volunteerId)
          .maybeSingle();

      if (item != null) {
        detailedAssignments.add({
          'assignment': assignment,
          'item': item,
          'user':
              userProfile ?? {'full_name': 'Unknown', 'phone_number': 'N/A'},
          'volunteer': volunteerProfile ??
              {'full_name': 'Unknown Volunteer', 'phone_number': 'N/A'},
        });
      }
    }

    return detailedAssignments;
  }

  /// Allows a volunteer to update the status of their assigned task.
  Future<void> updateAssignmentStatus(
      String assignmentId, String status) async {
    await _supabase
        .from('volunteer_assignments')
        .update({'status': status}).eq('id', assignmentId);
  }

  // --- Admin Methods (Connecting Users and Volunteers) ---

  /// Fetches every schedule entry across the platform for the admin dashboard.
  Future<List<VolunteerSchedule>> fetchAllSchedules() async {
    try {
      final response = await _supabase.from('volunteer_schedules').select();
      print(
          '✓ Volunteer schedules fetched: ${(response as List).length} schedules');
      return (response as List)
          .map((json) => VolunteerSchedule.fromJson(json))
          .toList();
    } catch (e) {
      print('✗ Error fetching volunteer schedules: $e');
      rethrow;
    }
  }

  /// Fetches every task assignment for platform-wide tracking.
  Future<List<VolunteerAssignment>> fetchAllAssignments() async {
    final response = await _supabase.from('volunteer_assignments').select();

    return (response as List)
        .map((json) => VolunteerAssignment.fromJson(json))
        .toList();
  }

  /// Core logic to bridge users and volunteers:
  /// Creates a task assignment and automatically updates the e-waste item status.
  Future<void> createAssignment({
    required String volunteerId,
    required String itemId,
    required String taskType,
    required DateTime scheduledDate,
    String? notes,
  }) async {
    // 1. Record the formal assignment
    await _supabase.from('volunteer_assignments').insert({
      'volunteer_id': volunteerId,
      'item_id': itemId,
      'task_type': taskType,
      'status': 'pending',
      'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
      'notes': notes,
      'assigned_at': DateTime.now().toIso8601String(),
    });

    // 2. Synchronize the e-waste item's status and schedule metadata
    await _supabase.from('ewaste_items').update({
      'delivery_status': 'assigned',
      'assigned_agent_id': volunteerId,
      'pickup_scheduled_at': scheduledDate.toIso8601String(),
    }).eq('id', itemId);
  }

  /// Searches for volunteers available within a flexible date window.
  /// Useful for "close dates" matching (e.g., Target +/- 2 days).
  Future<List<VolunteerSchedule>> getAvailableVolunteersInDateRange(
      DateTime start, DateTime end) async {
    final startStr = start.toIso8601String().split('T')[0];
    final endStr = end.toIso8601String().split('T')[0];

    final response = await _supabase
        .from('volunteer_schedules')
        .select()
        .gte('date', startStr)
        .lte('date', endStr)
        .eq('is_available', true);

    return (response as List)
        .map((json) => VolunteerSchedule.fromJson(json))
        .toList();
  }

  /// Helper for immediate dispatch: Finds IDs of volunteers free on specific dates.
  Future<List<String>> getAvailableVolunteerIdsForDates(
      List<DateTime> dates) async {
    final dateStrings =
        dates.map((d) => d.toIso8601String().split('T')[0]).toList();

    // FIX: Replaced undefined 'in_' with 'filter' to resolve compiler error
    final response = await _supabase
        .from('volunteer_schedules')
        .select('volunteer_id')
        .filter('date', 'in', dateStrings)
        .eq('is_available', true);

    // Filter for unique IDs to avoid duplicates in the selection list
    return (response as List)
        .map((json) => json['volunteer_id'] as String)
        .toSet()
        .toList();
  }

  /// Admin override to cancel an assignment and return the user's item to the queue.
  Future<void> cancelAssignment(String assignmentId, String itemId) async {
    // 1. Mark the assignment as cancelled
    await _supabase
        .from('volunteer_assignments')
        .update({'status': 'cancelled'}).eq('id', assignmentId);

    // 2. Reset the item so other volunteers or admins can pick it up
    await _supabase.from('ewaste_items').update({
      'delivery_status': 'pending',
      'assigned_agent_id': null,
      'pickup_scheduled_at': null,
    }).eq('id', itemId);
  }
}
