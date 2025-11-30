import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/ewaste_item.dart';
import '../models/ngo.dart';
import '../models/pickup_agent.dart';
import '../services/ewaste_service.dart';
import 'ngo_management_screen.dart';
import 'agent_management_screen.dart';
import 'agent_dashboard.dart'; // Agent Dashboard for quick link
import 'profile_completion_screen.dart'; // Used as a placeholder for User/Volunteer Management
import '../core/supabase_config.dart'; // REQUIRED for Supabase client
import 'login_screen.dart'; // REQUIRED for navigation after logout

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  final _ewasteService = EwasteService();
  List<EwasteItem> ewasteItems = [];
  List<Ngo> ngos = [];
  List<PickupAgent> agents = [];
  bool isLoading = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchAllData() async {
    setState(() => isLoading = true);
    try {
      final items = await _ewasteService.fetchAll();
      final ngoList = await _ewasteService.fetchNgos();
      final agentList = await _ewasteService.fetchPickupAgents();

      // Sort items: Pending first, then Assigned, then Collected
      items.sort((a, b) {
        final order = ['pending', 'assigned', 'collected', 'delivered'];
        return order.indexOf(a.deliveryStatus).compareTo(order.indexOf(b.deliveryStatus));
      });

      setState(() {
        ewasteItems = items;
        ngos = ngoList;
        agents = agentList;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error fetching data: $e')));
      }
    }
  }

  // --- Data Actions (Simplified) ---

  Future<void> updateDeliveryStatus(String itemId, String newStatus, String agentId) async {
    try {
      if (newStatus == 'collected') {
        // Calls the service method which also logs tracking notes and updates user status
        await _ewasteService.markAsCollected(itemId);
      } else if (newStatus == 'delivered') {
        // Calls the service method which also awards points and notifies user
        await _ewasteService.markAsDelivered(itemId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Status updated to "$newStatus"!')),
        );
      }
      fetchAllData(); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> assignAgentAndNgo(String itemId, String? agentId, String? ngoId) async {
    try {
      if (agentId != null && agentId != '0') {
        await _ewasteService.assignPickupAgent(itemId, agentId);
      }
      if (ngoId != null && ngoId != '0') {
        await _ewasteService.assignNgo(itemId, ngoId);
      }
      
      // If assignment succeeded, show success message and refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Assignment successful!')),
        );
      }
      fetchAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to assign: $e')),
        );
      }
    }
  }
  
  // --- Logout Functionality ---
  Future<void> _logout() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Sign Out'),
        content: const Text('Are you sure you want to sign out of the Admin Console?'),
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
  
  // --- UI Helpers ---

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.redAccent;
      case 'assigned':
        return Colors.blue.shade700;
      case 'collected':
        return Colors.orange;
      case 'delivered':
      case 'recycled':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildKPI(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEwasteListTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (ewasteItems.isEmpty) {
      return const Center(child: Text('No e-waste items found'));
    }
    
    return RefreshIndicator(
      onRefresh: fetchAllData,
      child: ListView.builder(
        itemCount: ewasteItems.length,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemBuilder: (context, index) {
          final item = ewasteItems[index];
          return _EwasteItemCard(
            item: item,
            statusColor: getStatusColor(item.deliveryStatus),
            agents: agents,
            ngos: ngos,
            onAssign: assignAgentAndNgo,
            onStatusUpdate: updateDeliveryStatus,
          );
        },
      ),
    );
  }

  // Helper screens for management tabs
  Widget _buildManagementTab() {
    return const NgoManagementScreen(); // Reuse existing NGO management
  }

  Widget _buildAgentManagementTab() {
    return const AgentManagementScreen(); // Reuse existing Agent management
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ewasteItems.where((i) => i.deliveryStatus == 'pending').length;
    final assignedCount = ewasteItems.where((i) => i.deliveryStatus == 'assigned').length;
    final collectedCount = ewasteItems.where((i) => i.deliveryStatus == 'collected').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'E-Waste Queue', icon: Icon(Icons.list_alt)),
            Tab(text: 'NGO Management', icon: Icon(Icons.business_center)),
            Tab(text: 'Agent Management', icon: Icon(Icons.delivery_dining)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchAllData,
            tooltip: 'Refresh All Data',
          ),
          // REMOVED: Placeholder for User/Volunteer Management (Icons.group)
          // REMOVED: Profile icon (Icons.person)
          
          // ADDED: Logout Button
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: E-Waste Processing Queue
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 8, right: 8),
                child: Row(
                  children: [
                    _buildKPI('New Pending', pendingCount.toString(), Icons.pending_actions, Colors.redAccent),
                    _buildKPI('Assigned Pickups', assignedCount.toString(), Icons.local_shipping, Colors.blue),
                    _buildKPI('Collected Items', collectedCount.toString(), Icons.inventory, Colors.orange),
                  ],
                ),
              ),
              Expanded(
                child: _buildEwasteListTab(),
              ),
            ],
          ),
          
          // Tab 2: NGO Management
          _buildManagementTab(),
          
          // Tab 3: Agent Management
          _buildAgentManagementTab(),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// New Widget: Enhanced E-Waste Item Card
// -----------------------------------------------------------------------

class _EwasteItemCard extends StatefulWidget {
  final EwasteItem item;
  final Color statusColor;
  final List<PickupAgent> agents;
  final List<Ngo> ngos;
  final Function(String itemId, String? agentId, String? ngoId) onAssign;
  final Function(String itemId, String newStatus, String agentId) onStatusUpdate;

  const _EwasteItemCard({
    required this.item,
    required this.statusColor,
    required this.agents,
    required this.ngos,
    required this.onAssign,
    required this.onStatusUpdate,
  });

  @override
  State<_EwasteItemCard> createState() => _EwasteItemCardState();
}

class _EwasteItemCardState extends State<_EwasteItemCard> {
  String? _selectedAgentId;
  String? _selectedNgoId;

  @override
  void initState() {
    super.initState();
    _selectedAgentId = widget.item.assignedAgentId;
    _selectedNgoId = widget.item.assignedNgoId;
  }

  @override
  Widget build(BuildContext context) {
    // Safely look up Agent/NGO, falling back to placeholder if ID is missing or lookup fails
    final assignedAgent = widget.agents.firstWhere(
        (a) => a.id == (widget.item.assignedAgentId ?? '0'),
        orElse: () => PickupAgent.placeholder());
    final assignedNgo = widget.ngos.firstWhere(
        (n) => n.id == (widget.item.assignedNgoId ?? '0'),
        orElse: () => Ngo.placeholder());
        
    final bool needsAssignment = widget.item.deliveryStatus == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: widget.statusColor.withOpacity(0.3), width: 1.5),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: widget.item.imageUrl.isNotEmpty
              ? Image.network(
                  widget.item.imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
                )
              : Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.devices_other)),
        ),
        title: Text(
          widget.item.itemName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display truncated User ID for brevity
            Text('User: ${widget.item.userId.substring(0, widget.item.userId.length > 8 ? 8 : widget.item.userId.length)}...', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: widget.statusColor),
                const SizedBox(width: 6),
                Text(
                  widget.item.deliveryStatus.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.statusColor,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text('${widget.item.rewardPoints ?? 0} EcoPoints', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.teal)),
              ],
            ),
          ],
        ),
        children: [
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Detailed Info
                _detailRow(Icons.description, 'Description', widget.item.description),
                _detailRow(Icons.location_on, 'Location', widget.item.location),
                _detailRow(Icons.category, 'Category', widget.item.categoryId.toUpperCase()),
                _detailRow(Icons.schedule, 'Submitted', DateFormat('MMM d, h:mm a').format(widget.item.createdAt)),

                const SizedBox(height: 16),
                const Text('Assignment Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),

                // Current Assignments
                _assignmentDisplay(Icons.delivery_dining, 'Agent', assignedAgent.name, needsAssignment ? Colors.grey : Colors.blue),
                _assignmentDisplay(Icons.business, 'NGO', assignedNgo.name, needsAssignment ? Colors.grey : Colors.green),
                
                // Assignment Dropdowns (Only visible for Pending items)
                if (needsAssignment) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Assign Pickup Agent'),
                    value: _selectedAgentId,
                    // Add an 'Unassigned' option (id: '0')
                    items: [
                      const DropdownMenuItem(value: '0', child: Text('— Select Agent —')),
                      ...widget.agents.map((agent) {
                        return DropdownMenuItem<String>(
                          value: agent.id,
                          child: Text(agent.name),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) => setState(() => _selectedAgentId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Assign NGO Destination'),
                    value: _selectedNgoId,
                     // Add an 'Unassigned' option (id: '0')
                    items: [
                      const DropdownMenuItem(value: '0', child: Text('— Select NGO —')),
                      ...widget.ngos.map((ngo) {
                        return DropdownMenuItem<String>(
                          value: ngo.id,
                          child: Text(ngo.name),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) => setState(() => _selectedNgoId = value),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      // Disable if no valid assignment is selected (neither '0' nor null is valid for initial assignment)
                      onPressed: (_selectedAgentId == null || _selectedNgoId == null || _selectedAgentId == '0' || _selectedNgoId == '0') ? null : () {
                        widget.onAssign(widget.item.id, _selectedAgentId, _selectedNgoId);
                      },
                      icon: const Icon(Icons.assignment_ind),
                      label: const Text('Confirm Assignment'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                    ),
                  ),
                ],
                
                // Manual Status Update (for Assigned/Collected items)
                if (!needsAssignment) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (widget.item.deliveryStatus == 'assigned' && _selectedAgentId != null && _selectedAgentId != '0')
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => widget.onStatusUpdate(widget.item.id, 'collected', _selectedAgentId!),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Mark Collected'),
                            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (widget.item.deliveryStatus == 'collected' && _selectedAgentId != null && _selectedAgentId != '0')
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => widget.onStatusUpdate(widget.item.id, 'delivered', _selectedAgentId!),
                            icon: const Icon(Icons.done_all),
                            label: const Text('Mark Delivered'),
                            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                          ),
                        ),
                    ],
                  ),
                ],

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _assignmentDisplay(IconData icon, String label, String name, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}