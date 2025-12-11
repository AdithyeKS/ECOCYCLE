import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/ewaste_item.dart';
import '../services/ewaste_service.dart';
import '../core/supabase_config.dart'; // Import for Supabase client
import 'login_screen.dart'; // REQUIRED for navigation after logout

class AgentDashboard extends StatefulWidget {
  const AgentDashboard({super.key});

  @override
  State<AgentDashboard> createState() => _AgentDashboardState();
}

class _AgentDashboardState extends State<AgentDashboard> {
  final _ewasteService = EwasteService();
  List<EwasteItem> _assignedItems = [];
  bool _isLoading = true;
  String? _agentId;

  @override
  void initState() {
    super.initState();
    _initializeAgent();
  }

  // New function to get the current user's ID
  void _initializeAgent() {
    final user = AppSupabase.client.auth.currentUser;
    if (user != null) {
      // Use the logged-in user's ID as the agent ID
      _agentId = user.id;
      _fetchAssignedItems();
    } else {
      // Handle case where user is not logged in (shouldn't happen if routed correctly)
      setState(() {
        _isLoading = false;
        _agentId = null;
      });
      _showSnackbar('Agent not authenticated.');
    }
  }

  Future<void> _fetchAssignedItems() async {
    if (_agentId == null) return;

    setState(() => _isLoading = true);
    try {
      // Fetch items assigned to the current agent ID
      final items = await _ewasteService.fetchItemsForAgent(_agentId!);
      setState(() {
        // Sort items to show 'assigned' first, then 'collected'
        items.sort((a, b) {
          int statusA = a.deliveryStatus == 'assigned' ? 0 : 1;
          int statusB = b.deliveryStatus == 'assigned' ? 0 : 1;
          return statusA.compareTo(statusB);
        });
        _assignedItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar('Error loading assigned items: $e');
    }
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _markAsCollected(EwasteItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('confirm_collection')),
        content: Text(tr('mark_collected_confirm')
            .replaceAll('{itemName}', item.itemName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('collected')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _ewasteService.markAsCollected(item.id);
        _fetchAssignedItems();
        _showSnackbar(tr('item_marked_collected'));
      } catch (e) {
        _showSnackbar('Error updating item: $e');
      }
    }
  }

  Future<void> _markAsDelivered(EwasteItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('confirm_delivery')),
        content: Text(tr('mark_delivered_confirm')
            .replaceAll('{itemName}', item.itemName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delivered')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _ewasteService.markAsDelivered(item.id);
        _fetchAssignedItems();
        _showSnackbar(tr('item_marked_delivered'));
      } catch (e) {
        _showSnackbar('Error updating item: $e');
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

  // --- Logout Functionality ---
  Future<void> _logout() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Sign Out'),
        content: const Text(
            'Are you sure you want to sign out of the Agent Dashboard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      try {
        await AppSupabase.client.auth.signOut();
        if (context.mounted) {
          // Navigate back to login screen and remove all other routes
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            ),
            (r) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to sign out: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('agent_dashboard_title')),
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
            tooltip: tr('refresh'),
          ),
          // ADDED: Logout Button
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _agentId == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      tr('agent_auth_required'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.redAccent),
                    ),
                  ),
                )
              : _assignedItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.assignment,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            tr('no_assigned_pickups'),
                            style: const TextStyle(
                                fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr('check_back_later'),
                            style: TextStyle(color: Colors.grey[600]),
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
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
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
                                                    size: 30),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.image_not_supported,
                                              size: 70),
                                    ),
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
                                            style: TextStyle(
                                                color: Colors.grey[600]),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),

                                // Pickup Details
                                _detailRow(Icons.location_on, 'Location:',
                                    item.location),
                                if (item.pickupScheduledAt != null)
                                  _detailRow(
                                      Icons.schedule,
                                      'Scheduled:',
                                      DateFormat('MMM d, h:mm a').format(
                                          item.pickupScheduledAt!.toLocal())),

                                const SizedBox(height: 12),

                                // Status and Action Buttons
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color:
                                            _getStatusColor(item.deliveryStatus)
                                                .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        item.deliveryStatus.toUpperCase(),
                                        style: TextStyle(
                                          color: _getStatusColor(
                                              item.deliveryStatus),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (item.deliveryStatus == 'assigned')
                                      FilledButton.icon(
                                        onPressed: () => _markAsCollected(item),
                                        icon: const Icon(
                                            Icons.check_circle_outline,
                                            size: 18),
                                        label: Text(tr('mark_collected')),
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              Colors.orange.shade700,
                                        ),
                                      )
                                    else if (item.deliveryStatus == 'collected')
                                      FilledButton.icon(
                                        onPressed: () => _markAsDelivered(item),
                                        icon: const Icon(Icons.local_shipping,
                                            size: 18),
                                        label: Text(tr('mark_delivered')),
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              Colors.green.shade700,
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

  // Helper widget for detailed rows
  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text(
            label,
            style:
                TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
