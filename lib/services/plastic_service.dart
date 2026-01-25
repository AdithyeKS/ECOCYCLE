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
    final fileName = 'plastic_${ DateTime.now().millisecondsSinceEpoch}.jpg';
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
  }) async {
    // Reward points based on category
    int rewardPoints = (plasticType == 'Bottle') ? 40 : 20;

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
    });

    final profileService = ProfileService();
    await profileService.sendStatusUpdateNotification(
        userId, itemName, 'Pending - Plastic item submitted for recycling');
  }

  /// Fetches all plastic items for the current user
  Future<List<PlasticItem>> fetchAll() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final data = await supabase
        .from('plastic_items')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (data as List).map((e) => PlasticItem.fromJson(e)).toList();
  }
}
