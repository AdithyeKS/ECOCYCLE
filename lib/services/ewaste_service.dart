import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/ewaste_item.dart';

class EwasteService {
  final supabase = AppSupabase.client;
  static const bucket = 'ewaste_images';

  Future<String> uploadImage(File file) async {
    final filename = 'ew_${DateTime.now().millisecondsSinceEpoch}.png';
    final path = 'uploads/$filename';
    await supabase.storage.from(bucket).upload(path, file);
    return supabase.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> insertEwaste({
    required String itemName,
    required String description,
    required String location,
    required String imageUrl,
  }) async {
    await supabase.from('ewaste_items').insert({
      'item_name': itemName,
      'description': description,
      'location': location,
      'image_url': imageUrl,
      'status': 'Pending',
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
    await supabase.from('ewaste_items').update({'assigned_to': name}).eq('id', id);
  }

  Future<void> deleteItem(int id) async {
    await supabase.from('ewaste_items').delete().eq('id', id);
  }
}
