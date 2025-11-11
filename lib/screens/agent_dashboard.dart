import 'package:flutter/material.dart';
import '../models/ewaste_item.dart';
import '../services/ewaste_service.dart';

class AgentDashboard extends StatefulWidget {
  const AgentDashboard({super.key});

  @override
  State<AgentDashboard> createState() => _AgentDashboardState();
}

class _AgentDashboardState extends State<AgentDashboard> {
  final _ewasteService = EwasteService();
  List<EwasteItem> _assignedItems = [];
  bool _isLoading = true;
  String? _agentId; // In a real app, this would come from authentication

  @override
  void initState() {
    super.initState();
    // For demo purposes, using a hardcoded agent ID
    // In production, get this from authentication
    _agentId = 'demo-agent-id';
    _fetchAssignedItems();
  }

  Future<void> _fetchAssignedItems() async {
    if (_agentId == null) return;

    try {
      final items = await _ewasteService.fetchItemsForAgent(_agentId!);
      setState(() {
        _assignedItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading assigned items: $e')),
      );
    }
  }

  Future<void> _markAsCollected(EwasteItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Collection'),
        content: Text('Mark "${item.itemName}" as collected?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Collected'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _ewasteService.markAsCollected(item.id);
        _fetchAssignedItems();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item marked as collected')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating item: $e')),
        );
      }
    }
  }

  Future<void> _markAsDelivered(EwasteItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: Text('Mark "${item.itemName}" as delivered to NGO?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delivered'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _ewasteService.markAsDelivered(item.id);
        _fetchAssignedItems();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item marked as delivered')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating item: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String deliveryStatus) {
    switch (deliveryStatus) {
      case 'assigned':
        return Colors.blue;
      case 'collected':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup Agent Dashboard'),
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
            onPressed: _fetchAssignedItems,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignedItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No assigned pickups',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _assignedItems.length,
                  itemBuilder: (context, index) {
                    final item = _assignedItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                item.imageUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          item.imageUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(Icons.image_not_supported,
                                        size: 60),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.itemName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.description,
                                        style:
                                            TextStyle(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item.location,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                            if (item.pickupScheduledAt != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.schedule,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Scheduled: ${item.pickupScheduledAt!.toLocal().toString().split('.')[0]}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(item.deliveryStatus)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    item.deliveryStatus.toUpperCase(),
                                    style: TextStyle(
                                      color:
                                          _getStatusColor(item.deliveryStatus),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (item.deliveryStatus == 'assigned')
                                  FilledButton.icon(
                                    onPressed: () => _markAsCollected(item),
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text('Collected'),
                                  )
                                else if (item.deliveryStatus == 'collected')
                                  FilledButton.icon(
                                    onPressed: () => _markAsDelivered(item),
                                    icon: const Icon(Icons.local_shipping),
                                    label: const Text('Delivered'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
