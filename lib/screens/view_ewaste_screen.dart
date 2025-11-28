import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('fetch_error'))),
        );
      }
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
        title: Text(tr('my_ewaste')),
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
              ? Center(child: Text(tr('no_ewaste_found')))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ewasteItems.length,
                  itemBuilder: (context, index) {
                    final item = ewasteItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
                      shadowColor: Colors.black.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showTrackingDetails(item),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Hero(
                                    tag: 'item_image_${item.id}',
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: item.imageUrl.isNotEmpty
                                          ? Image.network(
                                              item.imageUrl,
                                              width: 70,
                                              height: 70,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  Container(
                                                width: 70,
                                                height: 70,
                                                color: Colors.grey[200],
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  size: 30,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              width: 70,
                                              height: 70,
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                Icons.image_not_supported,
                                                size: 30,
                                                color: Colors.grey,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.itemName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.description,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 18,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.location,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(item.status)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: getStatusColor(item.status)
                                            .withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      item.status,
                                      style: TextStyle(
                                        color: getStatusColor(item.status),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: getDeliveryStatusColor(
                                              item.deliveryStatus)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: getDeliveryStatusColor(
                                                item.deliveryStatus)
                                            .withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      item.deliveryStatus.toUpperCase(),
                                      style: TextStyle(
                                        color: getDeliveryStatusColor(
                                            item.deliveryStatus),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  FilledButton.icon(
                                    onPressed: () => _showTrackingDetails(item),
                                    icon: const Icon(Icons.track_changes,
                                        size: 16),
                                    label: const Text('Track'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
            tr('tracking_details'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text('${tr('item')}: ${item.itemName}'),
          Text('${tr('status')}: ${item.status}'),
          Text('${tr('delivery_status')}: ${item.deliveryStatus}'),
          if (item.pickupScheduledAt != null)
            Text(
                '${tr('pickup_scheduled')}: ${item.pickupScheduledAt!.toLocal().toString().split('.')[0]}'),
          if (item.collectedAt != null)
            Text(
                '${tr('collected_at')}: ${item.collectedAt!.toLocal().toString().split('.')[0]}'),
          if (item.deliveredAt != null)
            Text(
                '${tr('delivered_at')}: ${item.deliveredAt!.toLocal().toString().split('.')[0]}'),
          const SizedBox(height: 16),
          if (item.trackingNotes != null && item.trackingNotes!.isNotEmpty) ...[
            Text(tr('tracking_notes'),
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
