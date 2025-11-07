import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewEwasteScreen extends StatefulWidget {
  const ViewEwasteScreen({super.key});

  @override
  State<ViewEwasteScreen> createState() => _ViewEwasteScreenState();
}

class _ViewEwasteScreenState extends State<ViewEwasteScreen> {
  List<dynamic> ewasteItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEwasteItems();
  }

  Future<void> fetchEwasteItems() async {
    try {
      final response = await Supabase.instance.client
          .from('ewaste_items')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        ewasteItems = response;
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
      default:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My E-Waste')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ewasteItems.isEmpty
              ? const Center(child: Text('No E-Waste found'))
              : ListView.builder(
                  itemCount: ewasteItems.length,
                  itemBuilder: (context, index) {
                    final item = ewasteItems[index];
                    return Card(
                      margin: const EdgeInsets.all(10),
                      elevation: 3,
                      child: ListTile(
                        leading: item['image_url'] != null
                            ? Image.network(item['image_url'], width: 60, height: 60, fit: BoxFit.cover)
                            : const Icon(Icons.image_not_supported, size: 50),
                        title: Text(item['item_name'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['description'] ?? ''),
                            Text('📍 ${item['location'] ?? 'Unknown'}'),
                            Text(
                              'Status: ${item['status'] ?? 'Pending'}',
                              style: TextStyle(
                                color: getStatusColor(item['status'] ?? 'Pending'),
                                fontWeight: FontWeight.bold,
                              ),
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
