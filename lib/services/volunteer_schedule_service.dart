import 'package:ecocycle/core/supabase_config.dart';
import 'package:flutter/foundation.dart';
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
      return (response as List)
          .map((json) => VolunteerSchedule.fromJson(json))
          .toList();
    } catch (e) {
      // print(...);
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
    String wasteType = 'e-waste',
  }) async {
    // 1. Strict Limit Check
    final currentCount =
        await getAssignmentCountForVolunteerOnDate(volunteerId, scheduledDate);
    if (currentCount >= 2) {
      throw Exception(
          'Volunteer has already reached the maximum limit of 2 tasks for this date.');
    }

    debugPrint(
        'DEBUG: Creating assignment for item $itemId to volunteer $volunteerId on $scheduledDate');
    await _supabase.from('volunteer_assignments').insert({
      'volunteer_id': volunteerId,
      'waste_item_id': itemId, // Required by DB
      'task_id': itemId, // Legacy column (Required by current DB)
      'waste_type': wasteType, // Required by DB check constraint
      'task_type': taskType,
      'status': 'pending',
      'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
      'notes': notes,
      'assigned_at': DateTime.now().toIso8601String(),
    });
    debugPrint('DEBUG: Assignment record created successfully');

    // 2. Synchronize the specific waste item's status and schedule metadata
    String tableName;
    String statusField = 'delivery_status';
    String statusValue = 'assigned';
    Map<String, dynamic> updateData = {
      statusField: statusValue,
      'assigned_agent_id': volunteerId,
      'pickup_scheduled_at':
          scheduledDate.toIso8601String(), // This column exists in all 3 tables
    };

    // Table-specific overrides
    switch (wasteType.toLowerCase()) {
      case 'plastic':
        tableName = 'plastic_items';
        updateData['status'] = 'Approved';
        break;
      case 'cloth':
        tableName = 'cloth_donations';
        updateData['status'] = 'Approved';
        // Note: pickup_scheduled_at in cloth_donations might be named slightly differently in some schemas,
        // but EwasteService.schedulePickup uses 'pickup_scheduled_at'.
        // Let's verify ClothService.schedulePickup uses 'pickup_scheduled_at' too.
        break;
      default:
        tableName = 'ewaste_items';
        updateData['status'] = 'assigned';
    }

    await _supabase.from(tableName).update(updateData).eq('id', itemId);

    // 3. Auto-hide volunteer if they reached the daily limit (2 tasks)
    try {
      final count = await getAssignmentCountForVolunteerOnDate(
          volunteerId, scheduledDate);
      if (count >= 2) {
        debugPrint(
            'DEBUG: Volunteer $volunteerId reached limit ($count). Marking unavailable.');
        await setAvailability(volunteerId, scheduledDate, false);
      }
    } catch (e) {
      debugPrint('DEBUG: Error updating volunteer availability: $e');
    }
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

  /// Counts the number of assignments for a volunteer on a specific date.
  /// Modified to query item tables directly to avoid RLS/sync issues with volunteer_assignments.
  Future<int> getAssignmentCountForVolunteerOnDate(
      String volunteerId, DateTime date) async {
    // defined start and end of the requested date
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    final startStr = startOfDay.toIso8601String();
    final endStr = endOfDay.toIso8601String();

    try {
      // Query all 3 tables in parallel for items assigned to this volunteer on this date
      // We count items that are NOT delivered or cancelled (i.e., active tasks)
      final futures = [
        _supabase
            .from('ewaste_items')
            .select('id')
            .eq('assigned_agent_id', volunteerId)
            .gte('pickup_scheduled_at', startStr)
            .lte('pickup_scheduled_at', endStr)
            .neq('delivery_status', 'cancelled')
            .neq('delivery_status', 'delivered'),
        _supabase
            .from('plastic_items')
            .select('id')
            .eq('assigned_agent_id', volunteerId)
            .gte('pickup_scheduled_at', startStr)
            .lte('pickup_scheduled_at', endStr)
            .neq('delivery_status', 'cancelled')
            .neq('delivery_status', 'delivered'),
        _supabase
            .from('cloth_donations')
            .select('id')
            .eq('assigned_agent_id', volunteerId)
            .gte('pickup_scheduled_at', startStr)
            .lte('pickup_scheduled_at', endStr)
            .neq('delivery_status', 'cancelled')
            .neq('delivery_status', 'delivered'),
      ];

      final results = await Future.wait(futures);

      int totalCount = 0;
      for (final response in results) {
        totalCount += (response as List).length;
      }

      debugPrint(
          'DEBUG: Volunteer $volunteerId has $totalCount active item assignments on $startStr');
      return totalCount;
    } catch (e) {
      debugPrint('DEBUG: Error counting assignments: $e');
      return 0;
    }
  }

  /// Updates a volunteer's availability for today
  Future<void> updateTodayAvailability(
      String volunteerId, bool isAvailable) async {
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Check if schedule exists for today
    final existing = await _supabase
        .from('volunteer_schedules')
        .select()
        .eq('volunteer_id', volunteerId)
        .eq('date', today)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('volunteer_schedules')
          .update({'is_available': isAvailable}).eq('id', existing['id']);
    } else {
      // Create new schedule entry if it doesn't exist
      await _supabase.from('volunteer_schedules').insert({
        'volunteer_id': volunteerId,
        'date': today,
        'is_available': isAvailable,
      });
    }
  }
}
