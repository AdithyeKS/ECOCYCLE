import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/ewaste_item.dart';
import '../models/plastic_item.dart';
import '../models/cloth_item.dart';

class DeliveredItemsScreen extends StatefulWidget {
  final List<EwasteItem> ewasteItems;
  final List<PlasticItem> plasticItems;
  final List<ClothItem> clothItems;

  const DeliveredItemsScreen({
    super.key,
    required this.ewasteItems,
    required this.plasticItems,
    required this.clothItems,
  });

  @override
  State<DeliveredItemsScreen> createState() => _DeliveredItemsScreenState();
}

class _DeliveredItemsScreenState extends State<DeliveredItemsScreen> {
  String _selectedFilter = 'All'; // All, E-Waste, Plastic, Cloth
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _allDeliveredItems = [];

  @override
  void initState() {
    super.initState();
    _processItems();
  }

  @override
  void didUpdateWidget(DeliveredItemsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ewasteItems != oldWidget.ewasteItems ||
        widget.plasticItems != oldWidget.plasticItems ||
        widget.clothItems != oldWidget.clothItems) {
      _processItems();
    }
  }

  void _processItems() {
    _allDeliveredItems.clear();

    void addItem(dynamic item, String type) {
      if (item.deliveryStatus != 'delivered') return;

      _allDeliveredItems.add({
        'item': item,
        'type': type,
        'date': item.createdAt,
        'name': type == 'Cloth' ? item.type : item.itemName,
        'description': type == 'E-Waste'
            ? item.description
            : (type == 'Plastic' ? '${item.quantity} kg' : item.condition),
        'image': item.imageUrl,
        'location': item.location,
      });
    }

    for (var i in widget.ewasteItems) {
      addItem(i, 'E-Waste');
    }
    for (var i in widget.plasticItems) {
      addItem(i, 'Plastic');
    }
    for (var i in widget.clothItems) {
      addItem(i, 'Cloth');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredItems() {
    return _allDeliveredItems.where((data) {
      final matchesFilter =
          _selectedFilter == 'All' || data['type'] == _selectedFilter;
      final matchesSearch = data['name']
              .toString()
              .toLowerCase()
              .contains(_searchQuery) ||
          data['description'].toString().toLowerCase().contains(_searchQuery) ||
          data['location'].toString().toLowerCase().contains(_searchQuery);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivered Items'),
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
      ),
      backgroundColor:
          isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Search & Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search delivered items...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        ['All', 'E-Waste', 'Plastic', 'Cloth'].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            if (selected) {
                              setState(() => _selectedFilter = filter);
                            }
                          },
                          backgroundColor:
                              isDarkMode ? Colors.grey[800] : Colors.grey[100],
                          selectedColor: Colors.green.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.green
                                : (isDarkMode ? Colors.white : Colors.black),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.green
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_turned_in_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No delivered items found',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildItemCard(item, isDarkMode);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> data, bool isDarkMode) {
    Color typeColor;
    switch (data['type']) {
      case 'E-Waste':
        typeColor = Colors.blue;
        break;
      case 'Plastic':
        typeColor = Colors.red;
        break;
      case 'Cloth':
        typeColor = Colors.amber;
        break;
      default:
        typeColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 80,
                height: 80,
                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                child: data['image'] != null &&
                        data['image'].toString().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: data['image'],
                        fit: BoxFit.cover,
                        memCacheHeight: 200, // Optimize memory usage
                        placeholder: (context, url) => Container(
                          color:
                              isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey),
                      )
                    : const Icon(Icons.inventory_2, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 16),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          data['type'],
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Delivered',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['name'] ?? 'Unknown Item',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['description'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['location'] ?? 'No location',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
}
