import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/ewaste_item.dart';
import '../models/ngo.dart';
import '../models/pickup_agent.dart';
import 'profile_service.dart';

class EwasteService {
  final SupabaseClient supabase = AppSupabase.client;
  static const bucket = 'ewaste_images';

  /// Calculates the EcoPoints reward for a given E-waste category.
  int calculatePointsForCategory(String categoryId) {
    const basePoints = 50;

    // Additional points based on category (reflecting size/complexity)
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

  /// Uploads image bytes to Supabase storage and returns the public URL.
  Future<String> uploadImage(Uint8List fileBytes, String mimeType) async {
    final filename = 'ew_${DateTime.now().millisecondsSinceEpoch}.png';
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

  /// Inserts a new E-waste item into the database.
  Future<void> insertEwaste({
    required String userId,
    required String categoryId,
    required String itemName,
    required String description,
    required String location,
    required String imageUrl,
  }) async {
    final rewardPoints = calculatePointsForCategory(categoryId);

    await supabase.from('ewaste_items').insert({
      'user_id': userId,
      'category_id': categoryId,
      'item_name': itemName,
      'description': description,
      'location': location,
      'photo_url': imageUrl,
      'status': 'Pending', // User-facing status
      'reward_points': rewardPoints,
      'delivery_status': 'pending', // Internal tracking status
    });

    // Send email confirmation
    final profileService = ProfileService();
    await profileService.sendStatusUpdateNotification(
        userId, itemName, 'Pending - Item submitted for recycling');
  }

  /// Fetches all E-waste items (typically for Admin/Agent view).
  Future<List<EwasteItem>> fetchAll() async {
    final data = await supabase
        .from('ewaste_items')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => EwasteItem.fromJson(e)).toList();
  }

  /// Updates the user-facing status of an E-waste item.
  Future<void> updateStatus(String id, String status) async {
    await supabase.from('ewaste_items').update({'status': status}).eq('id', id);
  }

  /// Assigns a name (placeholder) to an E-waste item.
  Future<void> assignTo(String id, String name) async {
    await supabase
        .from('ewaste_items')
        .update({'assigned_to': name}).eq('id', id);
  }

  /// Deletes an E-waste item.
  Future<void> deleteItem(String id) async {
    await supabase.from('ewaste_items').delete().eq('id', id);
  }

  // --- NGO Management Methods ---

  /// Fetches a list of registered NGOs.
  Future<List<Ngo>> fetchNgos() async {
    final data = await supabase
        .from('ngos')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => Ngo.fromJson(e)).toList();
  }

  /// Adds a new NGO profile.
  Future<void> addNgo(Ngo ngo) async {
    await supabase.from('ngos').insert(ngo.toJson());
  }

  /// Updates an existing NGO profile.
  Future<void> updateNgo(String id, Map<String, dynamic> updates) async {
    await supabase.from('ngos').update(updates).eq('id', id);
  }

  /// Deletes an NGO profile.
  Future<void> deleteNgo(String id) async {
    await supabase.from('ngos').delete().eq('id', id);
  }

  // --- Pickup Agent Management Methods ---

  /// Fetches a list of active Pickup Agents.
  Future<List<PickupAgent>> fetchPickupAgents() async {
    final data = await supabase
        .from('pickup_requests')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return (data as List).map((e) => PickupAgent.fromJson(e)).toList();
  }

  /// Adds a new Pickup Agent profile.
  Future<void> addPickupAgent(PickupAgent agent) async {
    await supabase.from('pickup_requests').insert(agent.toJson());
  }

  /// Updates an existing Pickup Agent profile.
  Future<void> updatePickupAgent(
      String id, Map<String, dynamic> updates) async {
    await supabase.from('pickup_requests').update(updates).eq('id', id);
  }

  /// Deletes a Pickup Agent profile.
  Future<void> deletePickupAgent(String id) async {
    await supabase.from('pickup_requests').delete().eq('id', id);
  }

  // --- Assignment & Tracking Methods ---

  /// Assigns a Pickup Agent to an E-waste item.
  Future<void> assignPickupAgent(String itemId, String agentId) async {
    await supabase.from('ewaste_items').update({
      'assigned_agent_id': agentId,
      'delivery_status': 'assigned',
      'status': 'Picked', // User status updated to reflect assignment
    }).eq('id', itemId);

    // Send status update notification
    final item = await supabase
        .from('ewaste_items')
        .select('user_id, item_name')
        .eq('id', itemId)
        .single();

    final profileService = ProfileService();
    await profileService.sendStatusUpdateNotification(item['user_id'],
        item['item_name'], 'Picked - Agent assigned for pickup');
  }

  /// Assigns an NGO as the final destination for an E-waste item.
  Future<void> assignNgo(String itemId, String ngoId) async {
    await supabase.from('ewaste_items').update({
      'assigned_ngo_id': ngoId,
    }).eq('id', itemId);
  }

  /// Sets a scheduled pickup time for an E-waste item.
  Future<void> schedulePickup(String itemId, DateTime scheduledTime) async {
    await supabase.from('ewaste_items').update({
      'pickup_scheduled_at': scheduledTime.toIso8601String(),
    }).eq('id', itemId);
  }

  /// Marks an item as collected by the agent.
  Future<void> markAsCollected(String itemId) async {
    final now = DateTime.now();
    await supabase.from('ewaste_items').update({
      'delivery_status': 'collected',
      'status': 'Collected',
      'collected_at': now.toIso8601String(),
    }).eq('id', itemId);

    // Add tracking note
    await _addTrackingNote(itemId, 'Item collected by pickup agent', now);
  }

  /// Marks an item as delivered to the NGO and awards points.
  Future<void> markAsDelivered(String itemId) async {
    final now = DateTime.now();
    await supabase.from('ewaste_items').update({
      'delivery_status': 'delivered',
      'status': 'Recycled', // Final status
      'delivered_at': now.toIso8601String(),
    }).eq('id', itemId);

    // Add tracking note
    await _addTrackingNote(itemId, 'Item delivered to NGO for recycling', now);

    // Credit EcoPoints to user
    final item = await supabase
        .from('ewaste_items')
        .select('user_id, item_name, reward_points')
        .eq('id', itemId)
        .single();

    final profileService = ProfileService();
    // Award points
    await profileService.addEcoPoints(item['user_id'], item['reward_points']);
    // Notify user of points earned
    await profileService.sendPointsEarnedNotification(
        item['user_id'], item['item_name'], item['reward_points']);
  }

  /// Internal method to append a note to the item's tracking history.
  Future<void> _addTrackingNote(
      String itemId, String note, DateTime timestamp) async {
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

    // Note: Supabase/Postgres requires Dart List<dynamic> to be cast to
    // List<Map<String, dynamic>> when interacting with the database JSONB field.
    existingNotes.add(newNote);

    await supabase.from('ewaste_items').update({
      'tracking_notes': existingNotes,
    }).eq('id', itemId);
  }

  /// Fetches items specifically assigned to a given Pickup Agent.
  Future<List<EwasteItem>> fetchItemsForAgent(String agentId) async {
    try {
      final data = await supabase
          .from('ewaste_items')
          .select()
          .eq('assigned_agent_id', agentId)
          .order('pickup_scheduled_at', ascending: true);
      // Ensure the return type matches the expected List<EwasteItem>
      return (data as List).map((e) => EwasteItem.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching items for agent: $e');
      return []; // Return an empty list on failure
    }
  }
}
