import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/cloth_item.dart';
// NEW IMPORT for image uploading

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
      print('✓ Cloth items fetched: ${(data as List).length} items');
      return (data as List).map((e) => ClothItem.fromJson(e)).toList();
    } catch (e) {
      print('✗ Error fetching cloth items: $e');
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
      print('✗ Error fetching cloth items by status: $e');
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
  Future<void> assignPickupAgent(String itemId, String agentId) async {
    await supabase.from('cloth_donations').update({
      'assigned_agent_id': agentId,
      'delivery_status': 'assigned',
      'status': 'Approved', // Valid status for cloth_donations
    }).eq('id', itemId);
  }

  /// Assigns an NGO as the final destination for a cloth donation.
  Future<void> assignNgo(String itemId, String ngoId) async {
    await supabase.from('cloth_donations').update({
      'assigned_ngo_id': ngoId,
    }).eq('id', itemId);
  }

  /// Marks a cloth donation as collected by the agent.
  Future<void> markAsCollected(String itemId) async {
    final now = DateTime.now();
    await supabase.from('cloth_donations').update({
      'delivery_status': 'collected',
      'status': 'Collected', // Valid status for cloth_donations
      'collected_at': now.toIso8601String(),
    }).eq('id', itemId);
  }

  /// Marks a cloth donation as delivered to the NGO.
  Future<void> markAsDelivered(String itemId) async {
    final now = DateTime.now();
    await supabase.from('cloth_donations').update({
      'delivery_status': 'delivered',
      'status': 'Donated', // Valid status for cloth_donations
      'delivered_at': now.toIso8601String(),
    }).eq('id', itemId);
  }
}
