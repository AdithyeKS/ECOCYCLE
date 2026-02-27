import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  final _ewasteService = EwasteService();
  final _clothService = ClothService();
  final _plasticService = PlasticService();

  List<EwasteItem> ewasteItems = [];
  List<ClothItem> clothItems = [];
  List<PlasticItem> plasticItems = [];
  bool isLoading = true;

  // Cached data for performance
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];

  // Summary stats
  int _totalItems = 0;
  int _pendingItems = 0;
  int _collectedItems = 0;
  int _deliveredItems = 0;
  int _totalPoints = 0;

  // Filter and search state
  String selectedCategory = 'All';
  String selectedStatus = 'All'; // Kept if needed for future
  String searchQuery = '';
  bool isSearchMode = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    fetchAllItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchAllItems() async {
    try {
      setState(() => isLoading = true);

      final ewaste = await _ewasteService
          .fetchAll()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => [],
          )
          .catchError((e) => <EwasteItem>[]);

      final cloth = await _clothService
          .fetchAll()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => [],
          )
          .catchError((e) => <ClothItem>[]);

      final plastic = await _plasticService
          .fetchAll()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => [],
          )
          .catchError((e) => <PlasticItem>[]);

      if (mounted) {
        setState(() {
          ewasteItems = ewaste;
          clothItems = cloth;
          plasticItems = plastic;
          _processData(); // Process data once after fetch
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _processData() {
    // 1. Combine and Sort
    _allItems = [
      ...ewasteItems.map((item) => {'item': item, 'category': 'ewaste'}),
      ...clothItems.map((item) => {'item': item, 'category': 'cloth'}),
      ...plasticItems.map((item) => {'item': item, 'category': 'plastic'}),
    ]..sort((a, b) {
        final aTime = (a['item'] as dynamic).createdAt;
        final bTime = (b['item'] as dynamic).createdAt;
        return bTime.compareTo(aTime); // Newest first
      });

    // 2. Calculate Summary Stats
    _totalItems = _allItems.length;

    _pendingItems = 0;
    _collectedItems = 0;
    _deliveredItems = 0;
    _totalPoints = 0;

    for (var itemData in _allItems) {
      final item = itemData['item'];
      final status = (item as dynamic).status.toLowerCase();

      // Count status
      if (status == 'pending') {
        _pendingItems++;
      } else if (status == 'collected' || status == 'donated') {
        _collectedItems++;
      } else if ((item as dynamic).deliveryStatus?.toLowerCase() ==
              'delivered' ||
          status == 'delivered') {
        _deliveredItems++;
      }

      // Sum points (only for collected/donated/delivered)
      if (status == 'collected' ||
          status == 'donated' ||
          (item as dynamic).deliveryStatus?.toLowerCase() == 'delivered' ||
          status == 'delivered') {
        if (item is EwasteItem) {
          _totalPoints += item.rewardPoints ?? 0;
        } else if (item is ClothItem) {
          _totalPoints += item.quantity; // Assuming quantity as points for now
        } else if (item is PlasticItem) {
          _totalPoints += item.points;
        }
      }
    }

    // 3. Apply initial filters
    _applyFilters();
  }

  void _applyFilters() {
    var result = _allItems;

    // Category Filter
    if (selectedCategory != 'All') {
      result = result
          .where((itemData) =>
              itemData['category'] == selectedCategory.toLowerCase())
          .toList();
    }

    // Search Filter
    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      result = result.where((itemData) {
        final item = itemData['item'];
        final category = itemData['category'] as String;

        String searchText = '';
        if (item is EwasteItem) {
          searchText = item.itemName.toLowerCase();
        } else if (item is ClothItem) {
          searchText = '${item.type} ${item.condition}'.toLowerCase();
        } else if (item is PlasticItem) {
          searchText = '${item.itemName} ${item.plasticType}'.toLowerCase();
        }

        final location = (item as dynamic).location.toLowerCase();
        final status = (item as dynamic).status.toLowerCase();
        final itemCategory = category.toLowerCase();

        return searchText.contains(query) ||
            location.contains(query) ||
            status.contains(query) ||
            itemCategory.contains(query);
      }).toList();
    }

    _filteredItems = result;
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
    DateTime? pickupScheduledAt;
    DateTime? collectedAt;
    DateTime? deliveredAt;

    if (item is EwasteItem) {
      title = item.itemName;
      subtitle = item.description;
      status = item.status;
      location = item.location;
      imageUrl = item.imageUrl;
      createdAt = item.createdAt;
      pickupScheduledAt = item.pickupScheduledAt;
      collectedAt = item.collectedAt;
      deliveredAt = item.deliveredAt;
    } else if (item is ClothItem) {
      title = '${item.type} (${item.quantity})';
      subtitle = 'Condition: ${item.condition}';
      status = item.status;
      location = item.location;
      imageUrl = item.imageUrl;
      createdAt = item.createdAt;
      pickupScheduledAt = null;
      collectedAt = null;
      deliveredAt = null;
    } else if (item is PlasticItem) {
      title = item.itemName;
      subtitle = '${item.plasticType} - ${item.description}';
      status = item.status;
      location = item.location;
      imageUrl = item.imageUrl;
      createdAt = item.createdAt;
      pickupScheduledAt = null;
      collectedAt = null;
      deliveredAt = null;
    } else {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
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
                        ? Colors.green.withValues(alpha: 0.1)
                        : category == 'cloth'
                            ? Colors.indigo.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.1),
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
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          memCacheHeight: 200,
                          placeholder: (context, url) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                          errorWidget: (context, url, error) => Container(
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
                    color: getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: getStatusColor(status).withValues(alpha: 0.3),
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
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showTrackingDetails(item, category),
                  icon: const Icon(Icons.track_changes, size: 16),
                  label: Text(tr('details')),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pickupScheduledAt != null ||
                collectedAt != null ||
                deliveredAt != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).cardColor.withValues(alpha: 0.5)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[700]!
                        : Colors.grey[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule & Timeline',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[300]
                            : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (pickupScheduledAt != null)
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Pickup: ${pickupScheduledAt.toLocal().toString().split('.')[0]}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    if (collectedAt != null)
                      Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Collected: ${collectedAt.toLocal().toString().split('.')[0]}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    if (deliveredAt != null)
                      Row(
                        children: [
                          Icon(Icons.local_shipping,
                              size: 16, color: Colors.purple),
                          const SizedBox(width: 8),
                          Text(
                            'Delivered: ${deliveredAt.toLocal().toString().split('.')[0]}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showTrackingDetails(dynamic item, String category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          TrackingDetailsSheet(item: item, category: category),
    );
  }

  Widget _buildSummaryDashboard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              tr('donation_summary'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
            ),
          ),
          // Use horizontal scrollable row for small boxes
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  height: 80,
                  child: _buildCompactMetricCard(
                    icon: Icons.inventory_2,
                    title: tr('total_items'),
                    value: _totalItems.toString(),
                    color: Colors.blue,
                    backgroundColor: Colors.blue.shade50,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  height: 80,
                  child: _buildCompactMetricCard(
                    icon: Icons.star,
                    title: 'Eco Points',
                    value: _totalPoints.toString(),
                    color: Colors.amber,
                    backgroundColor: Colors.amber.shade50,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  height: 80,
                  child: _buildCompactMetricCard(
                    icon: Icons.schedule,
                    title: tr('pending'),
                    value: _pendingItems.toString(),
                    color: Colors.orange,
                    backgroundColor: Colors.orange.shade50,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  height: 80,
                  child: _buildCompactMetricCard(
                    icon: Icons.check_circle,
                    title: tr('collected'),
                    value: _collectedItems.toString(),
                    color: Colors.green,
                    backgroundColor: Colors.green.shade50,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  height: 80,
                  child: _buildCompactMetricCard(
                    icon: Icons.local_shipping,
                    title: tr('delivered'),
                    value: _deliveredItems.toString(),
                    color: Colors.purple,
                    backgroundColor: Colors.purple.shade50,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color backgroundColor,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              title,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChip(String label, IconData icon) {
    final isSelected = selectedCategory == label;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
          const SizedBox(width: 8),
          Text(label.toUpperCase()),
        ],
      ),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            selectedCategory = label;
            _applyFilters();
          });
        }
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF2E7D32),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[800],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : Colors.grey.shade300,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          title: !isSearchMode
              ? Text(
                  tr('my_donations'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                )
              : TextField(
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search donations...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                    suffixIcon: Icon(Icons.search, color: Colors.white),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                      _applyFilters();
                    });
                  },
                ),
          flexibleSpace: Theme.of(context).brightness == Brightness.dark
              ? null
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)],
                    ),
                  ),
                ),
          actions: [
            if (!isSearchMode)
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white, size: 28),
                padding: const EdgeInsets.all(8),
                onPressed: () {
                  setState(() {
                    isSearchMode = true;
                  });
                },
              )
            else
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.white, size: 28),
                padding: const EdgeInsets.all(8),
                onPressed: () {
                  setState(() {
                    isSearchMode = false;
                    searchQuery = '';
                    _applyFilters();
                  });
                },
              ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryDashboard(),
                // Category filter bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryFilterChip('All', Icons.all_inclusive),
                        const SizedBox(width: 8),
                        _buildCategoryFilterChip('ewaste', Icons.memory),
                        const SizedBox(width: 8),
                        _buildCategoryFilterChip('cloth', Icons.checkroom),
                        const SizedBox(width: 8),
                        _buildCategoryFilterChip('plastic', Icons.recycling),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredItems.isEmpty
                      ? Center(
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No donations found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your ${selectedCategory.toLowerCase()} donations will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ))
                      : RefreshIndicator(
                          onRefresh: fetchAllItems,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredItems.length,
                            itemBuilder: (context, index) {
                              final itemData = _filteredItems[index];
                              return _buildItemCard(itemData['item'],
                                  itemData['category'] as String);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class TrackingDetailsSheet extends StatelessWidget {
  final dynamic item;
  final String category;

  const TrackingDetailsSheet(
      {super.key, required this.item, required this.category});

  @override
  Widget build(BuildContext context) {
    String itemName = '';
    String status = '';
    String deliveryStatus = '';
    DateTime? pickupScheduledAt;
    DateTime? collectedAt;
    DateTime? deliveredAt;
    List<Map<String, dynamic>>? trackingNotes;

    if (item is EwasteItem) {
      itemName = item.itemName;
      status = item.status;
      deliveryStatus = item.deliveryStatus;
      pickupScheduledAt = item.pickupScheduledAt;
      collectedAt = item.collectedAt;
      deliveredAt = item.deliveredAt;
      trackingNotes = item.trackingNotes;
    } else if (item is ClothItem) {
      itemName = '${item.type} (${item.quantity})';
      status = item.status;
      deliveryStatus = 'N/A';
    } else if (item is PlasticItem) {
      itemName = item.itemName;
      status = item.status;
      deliveryStatus = 'N/A';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: category == 'ewaste'
                        ? Colors.green.withValues(alpha: 0.1)
                        : category == 'cloth'
                            ? Colors.indigo.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
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
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              tr('tracking_details'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            _buildDetailRow('Item', itemName),
            const SizedBox(height: 12),
            _buildDetailRow('Status', status),
            const SizedBox(height: 12),
            if (deliveryStatus != 'N/A')
              _buildDetailRow('Delivery Status', deliveryStatus),
            const SizedBox(height: 24),
            Text(
              tr('timeline'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildTimelineStep(
              icon: Icons.schedule,
              title: tr('donation_submitted'),
              subtitle: item.createdAt.toLocal().toString().split('.')[0],
              isCompleted: true,
              color: Colors.blue,
            ),
            if (pickupScheduledAt != null)
              _buildTimelineStep(
                icon: Icons.calendar_today,
                title: 'Pickup Scheduled',
                subtitle: pickupScheduledAt.toLocal().toString().split('.')[0],
                isCompleted: true,
                color: Colors.orange,
              ),
            if (collectedAt != null)
              _buildTimelineStep(
                icon: Icons.check_circle,
                title: 'Collected',
                subtitle: collectedAt.toLocal().toString().split('.')[0],
                isCompleted: true,
                color: Colors.green,
              ),
            if (deliveredAt != null)
              _buildTimelineStep(
                icon: Icons.local_shipping,
                title: 'Delivered',
                subtitle: deliveredAt.toLocal().toString().split('.')[0],
                isCompleted: true,
                color: Colors.purple,
              ),
            const SizedBox(height: 24),
            if (trackingNotes != null && trackingNotes.isNotEmpty) ...[
              Text(
                'Tracking Notes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ...trackingNotes.map((note) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.note, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note['note'],
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateTime.parse(note['timestamp'])
                                    .toLocal()
                                    .toString()
                                    .split('.')[0],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted ? color : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? color : Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
