import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/plastic_item.dart';
import 'profile_service.dart';

/// Service for managing plastic waste items and recycling tracking.
class PlasticService {
  final SupabaseClient supabase = AppSupabase.client;

  // Reusing your established bucket for images
  static const String _bucket = 'ewaste_images';

  /// Uploads plastic image to Supabase storage and returns public URL
  Future<String> uploadImage(Uint8List bytes, String mimeType) async {
    final fileName = 'plastic_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'plastic_uploads/$fileName';

    try {
      await supabase.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType),
          );
      return supabase.storage.from(_bucket).getPublicUrl(path);
    } catch (e) {
      throw Exception('Upload Failed: $e');
    }
  }

  /// Inserts plastic item with reward points logic
  Future<void> insertPlastic({
    required String userId,
    required String plasticType,
    required String itemName,
    required String description,
    required String location,
    String? imageUrl,
    int quantity = 1, // NEW: Quantity parameter
  }) async {
    // Reward points based on category
    int basePoints = (plasticType == 'Bottle') ? 40 : 20;
    // User requested: Add only 5 points for each additional item.
    int rewardPoints = basePoints + ((quantity - 1) * 5);

    await supabase.from('plastic_items').insert({
      'user_id': userId,
      'plastic_type': plasticType,
      'item_name': itemName,
      'description': description,
      'location': location,
      'image_url': imageUrl,
      'points': rewardPoints,
      'status': 'Pending',
      'created_at': DateTime.now().toIso8601String(),
      'quantity': quantity, // Store quantity
    });

    final profileService = ProfileService();
    await profileService.sendStatusUpdateNotification(
        userId, itemName, 'Pending - Plastic item submitted for recycling');
  }

  /// Fetches all plastic items (RLS will filter based on user role)
  Future<List<PlasticItem>> fetchAll() async {
    try {
      final data = await supabase
          .from('plastic_items')
          .select()
          .order('created_at', ascending: false);
      // print(...);
      return (data as List).map((e) => PlasticItem.fromJson(e)).toList();
    } catch (e) {
      // print(...);
      rethrow;
    }
  }

  /// Fetches plastic items by delivery status.
  Future<List<PlasticItem>> fetchItemsByDeliveryStatus(String status) async {
    try {
      final data = await supabase
          .from('plastic_items')
          .select()
          .eq('delivery_status', status)
          .order('created_at', ascending: false);
      return (data as List).map((e) => PlasticItem.fromJson(e)).toList();
    } catch (e) {
      // print(...);
      rethrow;
    }
  }

  /// Assigns a Pickup Agent to a plastic item.
  Future<void> assignPickupAgent(String itemId, String agentId) async {
    await supabase.from('plastic_items').update({
      'assigned_agent_id': agentId,
      'delivery_status': 'assigned',
      'status': 'Approved', // Consistent with other services
    }).eq('id', itemId);

    // Send status update notification
    final item = await supabase
        .from('plastic_items')
        .select('user_id, item_name')
        .eq('id', itemId)
        .single();

    final profileService = ProfileService();
    await profileService.sendStatusUpdateNotification(item['user_id'],
        item['item_name'], 'Assigned - Agent assigned for plastic pickup');
  }

  /// Marks a plastic item as collected.
  Future<void> markAsCollected(String itemId, {String? providedOtp}) async {
    // If OTP is provided, verify it first
    if (providedOtp != null) {
      final item = await supabase
          .from('plastic_items')
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
    await supabase.from('plastic_items').update({
      'delivery_status': 'collected',
      'status': 'collected',
      'collected_at': now.toIso8601String(),
    }).eq('id', itemId);

    await _addTrackingNote(
        itemId, 'Plastic item collected by pickup agent', now);
  }

  /// Marks a plastic item as delivered and awards points.
  Future<void> markAsDelivered(String itemId) async {
    final now = DateTime.now();
    await supabase.from('plastic_items').update({
      'delivery_status': 'delivered',
      'status': 'delivered',
      'delivered_at': now.toIso8601String(),
    }).eq('id', itemId);

    await _addTrackingNote(
        itemId, 'Plastic item delivered to recycling center', now);

    // Credit EcoPoints
    final item = await supabase
        .from('plastic_items')
        .select('user_id, item_name, points, assigned_agent_id')
        .eq('id', itemId)
        .single();

    final profileService = ProfileService();
    if (item['user_id'] != null && item['points'] != null) {
      await profileService.addEcoPoints(item['user_id'], item['points']);
      await profileService.sendPointsEarnedNotification(
          item['user_id'], item['item_name'], item['points']);
    }

    // Award points to volunteer
    if (item['assigned_agent_id'] != null) {
      const volunteerReward = 50; // Plastic reward
      await profileService.addEcoPoints(
          item['assigned_agent_id'], volunteerReward);
    }
  }

  /// Generates a 6-digit OTP and saves it to the item.
  Future<String> generateAndSaveOtp(String itemId) async {
    final String otp =
        (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
    await supabase
        .from('plastic_items')
        .update({'otp_code': otp}).eq('id', itemId);
    return otp;
  }

  /// Internal method to append a note to the item's tracking history.
  Future<void> _addTrackingNote(
      String itemId, String note, DateTime timestamp) async {
    final currentItem = await supabase
        .from('plastic_items')
        .select('tracking_notes')
        .eq('id', itemId)
        .single();

    final existingNotes = currentItem['tracking_notes'] as List<dynamic>? ?? [];
    existingNotes.add({
      'note': note,
      'timestamp': timestamp.toIso8601String(),
    });

    await supabase.from('plastic_items').update({
      'tracking_notes': existingNotes,
    }).eq('id', itemId);
  }

  /// Fetches items specifically assigned to a given Pickup Agent.
  Future<List<PlasticItem>> fetchItemsForAgent(String agentId) async {
    try {
      final data = await supabase
          .from('plastic_items')
          .select()
          .eq('assigned_agent_id', agentId)
          .order('created_at', ascending: false);
      return (data as List).map((e) => PlasticItem.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Updates the user-facing status of a plastic item.
  Future<void> updateStatus(String id, String status) async {
    await supabase
        .from('plastic_items')
        .update({'status': status}).eq('id', id);
  }

  /// Schedules pickup for a plastic item.
  Future<void> schedulePickup(String itemId, DateTime pickupDate) async {
    await supabase.from('plastic_items').update({
      'pickup_scheduled_at': pickupDate.toIso8601String(),
      'delivery_status': 'scheduled',
    }).eq('id', itemId);
  }

  /// Assigns an NGO as the final destination for a plastic item.
  Future<void> assignNgo(String itemId, String ngoId) async {
    await supabase.from('plastic_items').update({
      'assigned_ngo_id': ngoId,
    }).eq('id', itemId);
  }
}
