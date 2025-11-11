import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/ewaste_item.dart';
import '../models/ngo.dart';
import '../models/pickup_agent.dart';

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
      'delivery_status': 'pending',
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

  // NGO Management Methods
  Future<List<Ngo>> fetchNgos() async {
    final data = await supabase
        .from('ngos')
        .select()
        .eq('is_government_approved', true)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Ngo.fromJson(e)).toList();
  }

  Future<void> addNgo(Ngo ngo) async {
    await supabase.from('ngos').insert(ngo.toJson());
  }

  Future<void> updateNgo(String id, Map<String, dynamic> updates) async {
    await supabase.from('ngos').update(updates).eq('id', id);
  }

  Future<void> deleteNgo(String id) async {
    await supabase.from('ngos').delete().eq('id', id);
  }

  // Pickup Agent Management Methods
  Future<List<PickupAgent>> fetchPickupAgents() async {
    final data = await supabase
        .from('pickup_agents')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return (data as List).map((e) => PickupAgent.fromJson(e)).toList();
  }

  Future<void> addPickupAgent(PickupAgent agent) async {
    await supabase.from('pickup_agents').insert(agent.toJson());
  }

  Future<void> updatePickupAgent(
      String id, Map<String, dynamic> updates) async {
    await supabase.from('pickup_agents').update(updates).eq('id', id);
  }

  Future<void> deletePickupAgent(String id) async {
    await supabase.from('pickup_agents').delete().eq('id', id);
  }

  // Assignment Methods
  Future<void> assignPickupAgent(int itemId, String agentId) async {
    await supabase.from('ewaste_items').update({
      'assigned_agent_id': agentId,
      'delivery_status': 'assigned',
      'status': 'Approved',
    }).eq('id', itemId);
  }

  Future<void> assignNgo(int itemId, String ngoId) async {
    await supabase.from('ewaste_items').update({
      'assigned_ngo_id': ngoId,
    }).eq('id', itemId);
  }

  Future<void> schedulePickup(int itemId, DateTime scheduledTime) async {
    await supabase.from('ewaste_items').update({
      'pickup_scheduled_at': scheduledTime.toIso8601String(),
    }).eq('id', itemId);
  }

  Future<void> markAsCollected(int itemId) async {
    final now = DateTime.now();
    await supabase.from('ewaste_items').update({
      'delivery_status': 'collected',
      'status': 'Collected',
      'collected_at': now.toIso8601String(),
    }).eq('id', itemId);

    // Add tracking note
    await _addTrackingNote(itemId, 'Item collected by pickup agent', now);
  }

  Future<void> markAsDelivered(int itemId) async {
    final now = DateTime.now();
    await supabase.from('ewaste_items').update({
      'delivery_status': 'delivered',
      'delivered_at': now.toIso8601String(),
    }).eq('id', itemId);

    // Add tracking note
    await _addTrackingNote(itemId, 'Item delivered to NGO', now);
  }

  Future<void> _addTrackingNote(
      int itemId, String note, DateTime timestamp) async {
    final currentItem = await supabase
        .from('ewaste_items')
        .select('tracking_notes')
        .eq('id', itemId)
        .single();

    final existingNotes = currentItem['tracking_notes'] as List<dynamic>? ?? [];
    final newNote = {
      'note': note,
      'timestamp': timestamp.toIso8601String(),
    };

    existingNotes.add(newNote);

    await supabase.from('ewaste_items').update({
      'tracking_notes': existingNotes,
    }).eq('id', itemId);
  }

  // Get items assigned to a specific agent
  Future<List<EwasteItem>> fetchItemsForAgent(String agentId) async {
    final data = await supabase
        .from('ewaste_items')
        .select()
        .eq('assigned_agent_id', agentId)
        .order('pickup_scheduled_at', ascending: true);
    return (data as List).map((e) => EwasteItem.fromJson(e)).toList();
  }
}
