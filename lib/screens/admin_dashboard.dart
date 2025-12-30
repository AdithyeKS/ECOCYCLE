import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/ewaste_item.dart';
import '../models/ngo.dart';
import '../models/pickup_agent.dart';
import '../models/volunteer_application.dart'; // Added model
import '../services/ewaste_service.dart';
import '../services/profile_service.dart';
import 'ngo_management_screen.dart';
import 'agent_management_screen.dart';
import '../core/supabase_config.dart'; 
import 'login_screen.dart'; 

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final _ewasteService = EwasteService();
  final _profileService = ProfileService();
  
  List<EwasteItem> ewasteItems = [];
  List<Ngo> ngos = [];
  List<PickupAgent> agents = [];
  List<VolunteerApplication> volunteerApps = []; // Detailed applications
  Map<String, String> userNames = {}; 
  List<Map<String, dynamic>> allProfiles = []; 
  bool isLoading = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchAllData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final items = await _ewasteService.fetchAll();
      final ngoList = await _ewasteService.fetchNgos();
      final agentList = await _ewasteService.fetchPickupAgents();
      final profiles = await _profileService.fetchAllProfiles();
      final apps = await _profileService.fetchAllApplications(); // Fetch professional apps

      final Map<String, String> namesMap = {};
      for (final profile in profiles) {
        namesMap[profile['id'] as String] = profile['full_name'] as String;
      }

      items.sort((a, b) {
        final order = ['pending', 'assigned', 'collected', 'delivered'];
        return order.indexOf(a.deliveryStatus).compareTo(order.indexOf(b.deliveryStatus));
      });

      setState(() {
        ewasteItems = items;
        ngos = ngoList;
        agents = agentList;
        userNames = namesMap;
        allProfiles = profiles;
        volunteerApps = apps;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching data: $e')));
      }
    }
  }

  // --- E-Waste Actions ---

  Future<void> updateDeliveryStatus(String itemId, String newStatus, String agentId) async {
    try {
      if (newStatus == 'collected') {
        await _ewasteService.markAsCollected(itemId);
      } else if (newStatus == 'delivered') {
        await _ewasteService.markAsDelivered(itemId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Status updated to "$newStatus"!')));
      }
      fetchAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed to update status: $e')));
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Assignment successful!')));
      }
      fetchAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed to assign: $e')));
      }
    }
  }

  // --- Professional Volunteer Actions ---

  Future<void> _handleVolunteerDecision(VolunteerApplication app, bool approve) async {
    final action = approve ? 'APPROVE' : 'REJECT';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action Volunteer?'),
        content: Text('User: ${app.fullName}\nDecision will update their role and access.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: approve ? Colors.green : Colors.red),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _profileService.decideOnApplication(app.id, app.userId, approve);
        fetchAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Decision recorded for ${app.fullName}')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _logout() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Sign Out'),
        content: const Text('Are you sure you want to sign out of the Admin Console?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await AppSupabase.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (r) => false,
        );
      }
    }
  }

  // --- UI Tabs ---

  Widget _buildKPI(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEwasteListTab() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (ewasteItems.isEmpty) return const Center(child: Text('No e-waste items found'));
    return RefreshIndicator(
      onRefresh: fetchAllData,
      child: ListView.builder(
        itemCount: ewasteItems.length,
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) => _EwasteItemCard(
          item: ewasteItems[index],
          statusColor: _getStatusColor(ewasteItems[index].deliveryStatus),
          agents: agents,
          ngos: ngos,
          userNames: userNames,
          onAssign: assignAgentAndNgo,
          onStatusUpdate: updateDeliveryStatus,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.redAccent;
      case 'assigned': return Colors.blue;
      case 'collected': return Colors.orange;
      case 'delivered': return Colors.green;
      default: return Colors.grey;
    }
  }

  Widget _buildVolunteerRequestsTab() {
    final pendingApps = volunteerApps.where((a) => a.status == 'pending').toList();
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (pendingApps.isEmpty) return const Center(child: Text('No pending volunteer requests'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingApps.length,
      itemBuilder: (context, index) {
        final app = pendingApps[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(app.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (app.agreedToPolicy)
                      const Chip(label: Text('Policy Signed', style: TextStyle(fontSize: 10, color: Colors.blue)), backgroundColor: Colors.blueAccent),
                  ],
                ),
                Text('Available from: ${DateFormat('MMM d, yyyy').format(app.availableDate)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Divider(height: 24),
                const Text('Social Work Motivation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(app.motivation, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => _handleVolunteerDecision(app, false), child: const Text('REJECT', style: TextStyle(color: Colors.red)))),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(onPressed: () => _handleVolunteerDecision(app, true), style: FilledButton.styleFrom(backgroundColor: Colors.green), child: const Text('APPROVE'))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveVolunteersTab() {
    final activeAgents = agents.where((a) => a.isActive).toList();
    if (activeAgents.isEmpty) return const Center(child: Text('No active volunteers/agents found'));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeAgents.length,
      itemBuilder: (context, index) {
        final agent = activeAgents[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(agent.name),
          subtitle: Text('Status: Active Agent'),
          trailing: const Icon(Icons.verified, color: Colors.green),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Analytics Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildKPI('Total Items', ewasteItems.length.toString(), Icons.inventory, Colors.blue),
              _buildKPI('Volunteers', agents.length.toString(), Icons.people, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Delivery Distribution', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(value: ewasteItems.where((i) => i.deliveryStatus == 'pending').length.toDouble(), color: Colors.red, radius: 40),
                  PieChartSectionData(value: ewasteItems.where((i) => i.deliveryStatus == 'delivered').length.toDouble(), color: Colors.green, radius: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)]),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.yellow,
          tabs: const [
            Tab(text: 'Queue', icon: Icon(Icons.list_alt)),
            Tab(text: 'NGOs', icon: Icon(Icons.business)),
            Tab(text: 'Agents', icon: Icon(Icons.delivery_dining)),
            Tab(text: 'Requests', icon: Icon(Icons.assignment_ind)),
            Tab(text: 'Volunteers', icon: Icon(Icons.volunteer_activism)),
            Tab(text: 'Stats', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEwasteListTab(),
          const NgoManagementScreen(),
          const AgentManagementScreen(),
          _buildVolunteerRequestsTab(),
          _buildActiveVolunteersTab(),
          _buildAnalyticsTab(),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Reusable E-Waste Item Card (Updated with Dropdowns)
// -----------------------------------------------------------------------

class _EwasteItemCard extends StatefulWidget {
  final EwasteItem item;
  final Color statusColor;
  final List<PickupAgent> agents;
  final List<Ngo> ngos;
  final Map<String, String> userNames;
  final Function(String itemId, String? agentId, String? ngoId) onAssign;
  final Function(String itemId, String newStatus, String agentId) onStatusUpdate;

  const _EwasteItemCard({
    required this.item,
    required this.statusColor,
    required this.agents,
    required this.ngos,
    required this.userNames,
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
    final bool isPending = widget.item.deliveryStatus == 'pending';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(widget.item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Status: ${widget.item.deliveryStatus.toUpperCase()}', style: TextStyle(color: widget.statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User: ${widget.userNames[widget.item.userId] ?? "Unknown"}'),
                Text('Location: ${widget.item.location}'),
                const Divider(),
                if (isPending) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedAgentId == '0' ? null : _selectedAgentId,
                    decoration: const InputDecoration(labelText: 'Assign Agent'),
                    items: widget.agents.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                    onChanged: (v) => setState(() => _selectedAgentId = v),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedNgoId == '0' ? null : _selectedNgoId,
                    decoration: const InputDecoration(labelText: 'Assign NGO'),
                    items: widget.ngos.map((n) => DropdownMenuItem(value: n.id, child: Text(n.name))).toList(),
                    onChanged: (v) => setState(() => _selectedNgoId = v),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_selectedAgentId == null || _selectedNgoId == null) 
                        ? null 
                        : () => widget.onAssign(widget.item.id, _selectedAgentId, _selectedNgoId),
                      child: const Text('CONFIRM ASSIGNMENT'),
                    ),
                  ),
                ] else ...[
                   Text('Agent: ${widget.agents.firstWhere((a) => a.id == widget.item.assignedAgentId, orElse: () => PickupAgent.placeholder()).name}'),
                   Text('NGO: ${widget.ngos.firstWhere((n) => n.id == widget.item.assignedNgoId, orElse: () => Ngo.placeholder()).name}'),
                   const SizedBox(height: 12),
                   if (widget.item.deliveryStatus == 'assigned')
                     SizedBox(width: double.infinity, child: FilledButton(onPressed: () => widget.onStatusUpdate(widget.item.id, 'collected', widget.item.assignedAgentId!), child: const Text('MARK COLLECTED'))),
                   if (widget.item.deliveryStatus == 'collected')
                     SizedBox(width: double.infinity, child: FilledButton(onPressed: () => widget.onStatusUpdate(widget.item.id, 'delivered', widget.item.assignedAgentId!), style: FilledButton.styleFrom(backgroundColor: Colors.green), child: const Text('MARK DELIVERED'))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}