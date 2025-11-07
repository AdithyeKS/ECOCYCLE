import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<dynamic> ewasteItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAllEwaste();
  }

  Future<void> fetchAllEwaste() async {
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> updateStatus(String id, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('ewaste_items')
          .update({'status': newStatus})
          .eq('id', id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Status updated to "$newStatus"!')),
      );
      fetchAllEwaste(); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to update status: $e')),
      );
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.orange;
      case 'collected':
        return Colors.green;
      default:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchAllEwaste,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ewasteItems.isEmpty
              ? const Center(child: Text('No e-waste items found'))
              : ListView.builder(
                  itemCount: ewasteItems.length,
                  itemBuilder: (context, index) {
                    final item = ewasteItems[index];
                    return Card(
                      margin: const EdgeInsets.all(10),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item['image_url'] != null)
                              Image.network(item['image_url'],
                                  height: 120, fit: BoxFit.cover),
                            const SizedBox(height: 10),
                            Text('🧱 ${item['item_name'] ?? 'Unknown'}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                            Text(item['description'] ?? ''),
                            Text('📍 Location: ${item['location'] ?? 'N/A'}'),
                            Text(
                              'Status: ${item['status'] ?? 'Pending'}',
                              style: TextStyle(
                                  color: getStatusColor(item['status'] ?? 'Pending'),
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () =>
                                      updateStatus(item['id'].toString(), 'Approved'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange),
                                  child: const Text('Approve'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      updateStatus(item['id'].toString(), 'Collected'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green),
                                  child: const Text('Collected'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      updateStatus(item['id'].toString(), 'Pending'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  child: const Text('Pending'),
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
