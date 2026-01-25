import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/ewaste_item.dart';
import '../models/cloth_item.dart';
import '../models/plastic_item.dart';
import '../services/ewaste_service.dart';
import '../services/cloth_service.dart';
import '../services/plastic_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _ewasteService = EwasteService();
  final _clothService = ClothService();
  final _plasticService = PlasticService();

  List<EwasteItem> ewasteItems = [];
  List<ClothItem> clothItems = [];
  List<PlasticItem> plasticItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAllItems();
  }

  Future<void> fetchAllItems() async {
    try {
      setState(() => isLoading = true);
      print('Starting to fetch all items...');

      // Fetch with timeout and error handling
      final ewasteStartTime = DateTime.now();
      final ewaste = await _ewasteService.fetchAll().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('E-waste fetch timed out');
          return [];
        },
      ).catchError((e) {
        print('Error fetching e-waste: $e');
        return <EwasteItem>[];
      });
      print(
          'E-waste fetched: ${ewaste.length} items in ${DateTime.now().difference(ewasteStartTime).inMilliseconds}ms');

      final clothStartTime = DateTime.now();
      final cloth = await _clothService.fetchAll().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('Cloth fetch timed out');
          return [];
        },
      ).catchError((e) {
        print('Error fetching cloth: $e');
        return <ClothItem>[];
      });
      print(
          'Cloth fetched: ${cloth.length} items in ${DateTime.now().difference(clothStartTime).inMilliseconds}ms');

      final plasticStartTime = DateTime.now();
      final plastic = await _plasticService.fetchAll().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('Plastic fetch timed out');
          return [];
        },
      ).catchError((e) {
        print('Error fetching plastic: $e');
        return <PlasticItem>[];
      });
      print(
          'Plastic fetched: ${plastic.length} items in ${DateTime.now().difference(plasticStartTime).inMilliseconds}ms');

      setState(() {
        ewasteItems = ewaste;
        clothItems = cloth;
        plasticItems = plastic;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('Error fetching items: $e');
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'collected':
      case 'donated':
        return Colors.green;
      case 'approved':
      case 'assigned':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.redAccent;
    }
  }

  Widget _buildItemCard(dynamic item, String category) {
    String title = '';
    String subtitle = '';
    String status = '';
    String location = '';
    String? imageUrl;
    DateTime createdAt;

    if (item is EwasteItem) {
      title = item.itemName;
      subtitle = item.description;
      status = item.status;
      location = item.location;
      imageUrl = item.imageUrl;
      createdAt = item.createdAt;
    } else if (item is ClothItem) {
      title = '${item.type} (${item.quantity})';
      subtitle = 'Condition: ${item.condition}';
      status = item.status;
      location = item.location;
      imageUrl = item.imageUrl;
      createdAt = item.createdAt;
    } else if (item is PlasticItem) {
      title = item.itemName;
      subtitle = '${item.plasticType} - ${item.description}';
      status = item.status;
      location = item.location;
      imageUrl = item.imageUrl;
      createdAt = item.createdAt;
    } else {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: category == 'ewaste'
                        ? Colors.green.withOpacity(0.1)
                        : category == 'cloth'
                            ? Colors.indigo.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: TextStyle(
                      color: category == 'ewaste'
                          ? Colors.green
                          : category == 'cloth'
                              ? Colors.indigo
                              : Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  createdAt.toLocal().toString().split(' ')[0],
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                imageUrl != null && imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 24,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.inventory_2,
                          size: 24,
                          color: Colors.grey,
                        ),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: getStatusColor(status).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: getStatusColor(status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (item is EwasteItem &&
                    item.trackingNotes != null &&
                    item.trackingNotes!.isNotEmpty) ...[
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showTrackingDetails(item),
                    icon: const Icon(Icons.track_changes, size: 16),
                    label: const Text('Details'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTrackingDetails(EwasteItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => TrackingDetailsSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allItems = [
      ...ewasteItems.map((item) => {'item': item, 'category': 'ewaste'}),
      ...clothItems.map((item) => {'item': item, 'category': 'cloth'}),
      ...plasticItems.map((item) => {'item': item, 'category': 'plastic'}),
    ]..sort((a, b) {
        final aTime = (a['item'] as dynamic).createdAt;
        final bTime = (b['item'] as dynamic).createdAt;
        return bTime.compareTo(aTime); // Newest first
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('my_donations')),
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
          : allItems.isEmpty
              ? Center(child: Text(tr('no_donations_found')))
              : RefreshIndicator(
                  onRefresh: fetchAllItems,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: allItems.length,
                    itemBuilder: (context, index) {
                      final itemData = allItems[index];
                      return _buildItemCard(
                          itemData['item'], itemData['category'] as String);
                    },
                  ),
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
