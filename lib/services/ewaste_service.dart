import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/ewaste_item.dart';

class EwasteService {
  final SupabaseClient supabase = AppSupabase.client;
  static const bucket = 'ewaste_images';

  int _calculateRewardPoints(String categoryId) {
    // Base points for all e-waste items
    const basePoints = 50;

    // Additional points based on category
    final categoryBonus = switch (categoryId) {
      'tv' => 100, // TVs & Monitors (larger items)
      'computer' => 80, // Computers
      'appliances' => 120, // Home Appliances (largest items)
      'mobile' => 30, // Mobile Devices (smaller items)
      'peripherals' => 20, // Computer Peripherals
      'entertainment' => 40, // Entertainment Devices
      'batteries' => 15, // Batteries
      _ => 25, // Other Electronics
    };

    return basePoints + categoryBonus;
  }

  Future<String> uploadImage(File file) async {
    final filename = 'ew_${DateTime.now().millisecondsSinceEpoch}.png';
    final path = 'uploads/$filename';
    await supabase.storage.from(bucket).upload(path, file);
    return supabase.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> insertEwaste({
    required String categoryId,
    required String itemName,
    required String description,
    required String location,
    required String imageUrl,
  }) async {
    await supabase.from('ewaste_items').insert({
      'category_id': categoryId,
      'item_name': itemName,
      'description': description,
      'location': location,
      'image_url': imageUrl,
      'status': 'Pending',
      'reward_points': _calculateRewardPoints(categoryId),
    });
  }

  Future<List<EwasteItem>> fetchAll() async {
    final data = await supabase
        .from('ewaste_items')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => EwasteItem.fromJson(e)).toList();
  }

  Future<void> updateStatus(int id, String status) async {
    await supabase.from('ewaste_items').update({'status': status}).eq('id', id);
  }

  Future<void> assignTo(int id, String name) async {
    await supabase
        .from('ewaste_items')
        .update({'assigned_to': name}).eq('id', id);
  }

  Future<void> deleteItem(int id) async {
    await supabase.from('ewaste_items').delete().eq('id', id);
  }
}
