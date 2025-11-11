import 'package:flutter/material.dart';
import '../models/ewaste_item.dart';
import '../services/ewaste_service.dart';

class ViewEwasteScreen extends StatefulWidget {
  const ViewEwasteScreen({super.key});

  @override
  State<ViewEwasteScreen> createState() => _ViewEwasteScreenState();
}

class _ViewEwasteScreenState extends State<ViewEwasteScreen> {
  final _ewasteService = EwasteService();
  List<EwasteItem> ewasteItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEwasteItems();
  }

  Future<void> fetchEwasteItems() async {
    try {
      final items = await _ewasteService.fetchAll();
      setState(() {
        ewasteItems = items;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('Error fetching: $e');
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'collected':
        return Colors.green;
      case 'approved':
        return Colors.orange;
      case 'delivered':
        return Colors.blue;
      default:
        return Colors.redAccent;
    }
  }

  Color getDeliveryStatusColor(String deliveryStatus) {
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

  void _showTrackingDetails(EwasteItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => TrackingDetailsSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My E-Waste'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)],
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ewasteItems.isEmpty
              ? const Center(child: Text('No E-Waste found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ewasteItems.length,
                  itemBuilder: (context, index) {
                    final item = ewasteItems[index];
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
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: getStatusColor(item.status)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    item.status,
                                    style: TextStyle(
                                      color: getStatusColor(item.status),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: getDeliveryStatusColor(
                                            item.deliveryStatus)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    item.deliveryStatus.toUpperCase(),
                                    style: TextStyle(
                                      color: getDeliveryStatusColor(
                                          item.deliveryStatus),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => _showTrackingDetails(item),
                                  icon:
                                      const Icon(Icons.track_changes, size: 16),
                                  label: const Text('Track'),
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

class TrackingDetailsSheet extends StatelessWidget {
  final EwasteItem item;

  const TrackingDetailsSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tracking Details',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text('Item: ${item.itemName}'),
          Text('Status: ${item.status}'),
          Text('Delivery Status: ${item.deliveryStatus}'),
          if (item.pickupScheduledAt != null)
            Text(
                'Pickup Scheduled: ${item.pickupScheduledAt!.toLocal().toString().split('.')[0]}'),
          if (item.collectedAt != null)
            Text(
                'Collected At: ${item.collectedAt!.toLocal().toString().split('.')[0]}'),
          if (item.deliveredAt != null)
            Text(
                'Delivered At: ${item.deliveredAt!.toLocal().toString().split('.')[0]}'),
          const SizedBox(height: 16),
          if (item.trackingNotes != null && item.trackingNotes!.isNotEmpty) ...[
            const Text('Tracking Notes:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...item.trackingNotes!.map((note) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${note['note']} (${DateTime.parse(note['timestamp']).toLocal().toString().split('.')[0]})',
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
