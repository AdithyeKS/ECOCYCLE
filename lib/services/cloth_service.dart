import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/cloth_item.dart';
// NEW IMPORT for image uploading
import 'profile_service.dart';

class ClothService {
  final SupabaseClient supabase = AppSupabase.client;
  static const bucket = 'cloth_images'; // NEW BUCKET FOR CLOTHES

  // NEW FUNCTION: Uploads image bytes to Supabase Storage
  Future<String> uploadImage(Uint8List fileBytes, String mimeType) async {
    final filename = 'cl_${DateTime.now().millisecondsSinceEpoch}.png';
    final path = 'uploads/$filename';

    // Upload the bytes directly
    await supabase.storage.from(bucket).uploadBinary(
          path,
          fileBytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            cacheControl: '3600',
          ),
        );

    // Get the public URL for display and database storage
    return supabase.storage.from(bucket).getPublicUrl(path);
  }

  // MODIFIED: Inserts a new cloth donation item with image data
  Future<void> insertClothDonation({
    required String userId,
    required String type,
    required int quantity,
    required String condition,
    required String location,
    required String imageUrl, // ADDED
    required int estimatedDamagePercent, // ADDED
    double? latitude,
    double? longitude,
  }) async {
    // Determine acceptance based on your rule (e.g., 80% damage or less accepted)
    final isAcceptable = estimatedDamagePercent <= 80;

    // Assign status based on acceptance (Can be manually reviewed later by admin)
    final initialStatus = isAcceptable ? 'Pending' : 'Rejected';

    await supabase.from('cloth_donations').insert({
      'user_id': userId,
      'type': type,
      'quantity': quantity,
      'condition': condition,
      'location': location,
      'image_url': imageUrl, // ADDED
      'damage_percent': estimatedDamagePercent, // ADDED
      'status': initialStatus, // USING DYNAMIC STATUS
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  // Fetches all cloth donation items for the current user
  Future<List<ClothItem>> fetchUserDonations(String userId) async {
    final data = await supabase
        .from('cloth_donations')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => ClothItem.fromJson(e)).toList();
  }

  // Fetches all cloth donation items (RLS will filter based on user role)
  Future<List<ClothItem>> fetchAll() async {
    try {
      final data = await supabase
          .from('cloth_donations')
          .select()
          .order('created_at', ascending: false);
      // print(...);
      return (data as List).map((e) => ClothItem.fromJson(e)).toList();
    } catch (e) {
      // print(...);
      rethrow;
    }
  }

  /// Fetches cloth items by delivery status.
  Future<List<ClothItem>> fetchItemsByDeliveryStatus(String status) async {
    try {
      final data = await supabase
          .from('cloth_donations')
          .select()
          .eq('delivery_status', status)
          .order('created_at', ascending: false);
      return (data as List).map((e) => ClothItem.fromJson(e)).toList();
    } catch (e) {
      // print(...);
      rethrow;
    }
  }

  // Admin/Agent method to update status (Placeholder integration)
  Future<void> updateStatus(int itemId, String newStatus) async {
    await supabase
        .from('cloth_donations')
        .update({'status': newStatus}).eq('id', itemId);
  }

  /// Assigns a Pickup Agent to a cloth donation.
  Future<void> assignPickupAgent(int itemId, String agentId) async {
    await supabase.from('cloth_donations').update({
      'assigned_agent_id': agentId,
      'delivery_status': 'assigned',
      'status': 'Approved', // Valid status for cloth_donations
    }).eq('id', itemId);

    // Send status update notification
    final item = await supabase
        .from('cloth_donations')
        .select('user_id, type')
        .eq('id', itemId)
        .single();

    final profileService = ProfileService();
    await profileService.sendStatusUpdateNotification(item['user_id'],
        item['type'], 'Assigned - Agent assigned for cloth pickup');
  }

  /// Assigns an NGO as the final destination for a cloth donation.
  Future<void> assignNgo(int itemId, String ngoId) async {
    await supabase.from('cloth_donations').update({
      'assigned_ngo_id': ngoId,
    }).eq('id', itemId);
  }

  /// Schedules pickup for a cloth donation.
  Future<void> schedulePickup(int itemId, DateTime pickupDate) async {
    await supabase.from('cloth_donations').update({
      'pickup_scheduled_at': pickupDate.toIso8601String(),
      'delivery_status': 'scheduled',
    }).eq('id', itemId);
  }

  /// Marks a cloth donation as collected by the agent.
  Future<void> markAsCollected(int itemId, {String? providedOtp}) async {
    // If OTP is provided, verify it first
    if (providedOtp != null) {
      final item = await supabase
          .from('cloth_donations')
          .select('otp_code')
          .eq('id', itemId)
          .single();

      final storedOtp = item['otp_code'] as String?;
      if (storedOtp != null && storedOtp != providedOtp) {
        throw Exception(
            'Invalid OTP. Please ask the user for the correct code.');
      }
    }

    final now = DateTime.now();
    await supabase.from('cloth_donations').update({
      'delivery_status': 'collected',
      'status': 'Collected', // Valid status for cloth_donations
      'collected_at': now.toIso8601String(),
    }).eq('id', itemId);

    await _addTrackingNote(
        itemId, 'Cloth donation collected by pickup agent', now);
  }

  /// Marks a cloth donation as delivered to the NGO.
  Future<void> markAsDelivered(int itemId) async {
    final now = DateTime.now();
    await supabase.from('cloth_donations').update({
      'delivery_status': 'delivered',
      'status': 'Donated', // Valid status for cloth_donations
      'delivered_at': now.toIso8601String(),
    }).eq('id', itemId);

    await _addTrackingNote(itemId, 'Cloth donation delivered to NGO', now);

    // Credit EcoPoints
    final item = await supabase
        .from('cloth_donations')
        .select('user_id, type, assigned_agent_id')
        .eq('id', itemId)
        .single();

    final profileService = ProfileService();
    // User points for cloth (fixed reward for now)
    if (item['user_id'] != null) {
      await profileService.addEcoPoints(item['user_id'], 50);
      await profileService.sendPointsEarnedNotification(
          item['user_id'], item['type'], 50);
    }

    // Award points to volunteer
    if (item['assigned_agent_id'] != null) {
      const volunteerReward = 75; // Cloth reward
      await profileService.addEcoPoints(
          item['assigned_agent_id'], volunteerReward);
    }
  }

  /// Generates a 6-digit OTP and saves it to the item.
  Future<String> generateAndSaveOtp(int itemId) async {
    final String otp =
        (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
    await supabase
        .from('cloth_donations')
        .update({'otp_code': otp}).eq('id', itemId);
    return otp;
  }

  /// Internal method to append a note to the item's tracking history.
  Future<void> _addTrackingNote(
      int itemId, String note, DateTime timestamp) async {
    final currentItem = await supabase
        .from('cloth_donations')
        .select('tracking_notes')
        .eq('id', itemId)
        .single();

    final existingNotes = currentItem['tracking_notes'] as List<dynamic>? ?? [];
    existingNotes.add({
      'note': note,
      'timestamp': timestamp.toIso8601String(),
    });

    await supabase.from('cloth_donations').update({
      'tracking_notes': existingNotes,
    }).eq('id', itemId);
  }

  /// Fetches items specifically assigned to a given Pickup Agent.
  Future<List<ClothItem>> fetchItemsForAgent(String agentId) async {
    try {
      final data = await supabase
          .from('cloth_donations')
          .select()
          .eq('assigned_agent_id', agentId)
          .order('created_at', ascending: false);
      return (data as List).map((e) => ClothItem.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }
}
