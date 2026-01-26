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
    final initialStatus =
        isAcceptable ? 'Pending Review' : 'Rejected (High Damage)';

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

  // Admin/Agent method to update status (Placeholder integration)
  Future<void> updateStatus(int itemId, String newStatus) async {
    await supabase
        .from('cloth_donations')
        .update({'status': newStatus}).eq('id', itemId);
  }
}
