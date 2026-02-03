import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/ewaste_item.dart';
import '../models/plastic_item.dart';
import '../models/cloth_item.dart';
import '../services/ewaste_service.dart';
import '../services/plastic_service.dart';
import '../services/cloth_service.dart';
import '../core/supabase_config.dart';

class PendingWasteRequestsScreen extends StatefulWidget {
  const PendingWasteRequestsScreen({super.key});

  @override
  State<PendingWasteRequestsScreen> createState() =>
      _PendingWasteRequestsScreenState();
}

class _PendingWasteRequestsScreenState
    extends State<PendingWasteRequestsScreen> {
  final _ewasteService = EwasteService();
  final _plasticService = PlasticService();
  final _clothService = ClothService();

  List<Map<String, dynamic>> _pendingItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingItems();
  }

  Future<void> _fetchPendingItems() async {
    setState(() => _isLoading = true);

    try {
      final ewasteItems =
          await _ewasteService.fetchItemsByDeliveryStatus('pending');
      final plasticItems =
          await _plasticService.fetchItemsByDeliveryStatus('pending');
      final clothItems =
          await _clothService.fetchItemsByDeliveryStatus('pending');

      final allItems = <Map<String, dynamic>>[];

      // Add e-waste items
      for (final item in ewasteItems) {
        allItems.add({
          'type': 'e-waste',
          'item': item,
          'service': _ewasteService,
        });
      }

      // Add plastic items
      for (final item in plasticItems) {
        allItems.add({
          'type': 'plastic',
          'item': item,
          'service': _plasticService,
        });
      }

      // Add cloth items
      for (final item in clothItems) {
        allItems.add({
          'type': 'cloth',
          'item': item,
          'service': _clothService,
        });
      }

      // Sort by creation date (newest first)
      allItems.sort((a, b) {
        final dateA = a['item'].createdAt ?? DateTime.now();
        final dateB = b['item'].createdAt ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      setState(() {
        _pendingItems = allItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading pending items: $e')),
        );
      }
    }
  }

  Color _getWasteTypeColor(String type) {
    switch (type) {
      case 'e-waste':
        return Colors.blue;
      case 'plastic':
        return Colors.green;
      case 'cloth':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getWasteTypeIcon(String type) {
    switch (type) {
      case 'e-waste':
        return Icons.devices;
      case 'plastic':
        return Icons.recycling;
      case 'cloth':
        return Icons.checkroom;
      default:
        return Icons.inventory;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Waste Requests'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPendingItems,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingItems.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchPendingItems,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingItems.length,
                    itemBuilder: (context, index) {
                      final itemData = _pendingItems[index];
                      final type = itemData['type'] as String;
                      final item = itemData['item'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with type and status
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getWasteTypeColor(type)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getWasteTypeIcon(type),
                                          size: 16,
                                          color: _getWasteTypeColor(type),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          type.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _getWasteTypeColor(type),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'PENDING',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Item name
                              Text(
                                item.itemName ?? 'Unknown Item',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Description
                              if (item.description != null &&
                                  item.description!.isNotEmpty)
                                Text(
                                  item.description!,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),

                              const SizedBox(height: 12),

                              // Location and date
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      item.location ?? 'Location not specified',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.createdAt != null
                                        ? 'Created: ${item.createdAt!.toLocal().toString().split(' ')[0]}'
                                        : 'Date not available',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Action note
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.info,
                                      color: Colors.blue,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'This request is waiting for admin assignment to a volunteer.',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment,
              size: 64,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Pending Waste Requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'All waste requests have been assigned or completed.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
