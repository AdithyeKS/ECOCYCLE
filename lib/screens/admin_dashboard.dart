import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/ewaste_item.dart';
import '../models/ngo.dart';
import '../models/pickup_agent.dart';
import '../models/volunteer_application.dart';
import '../models/volunteer_schedule.dart';
import '../services/ewaste_service.dart';
import '../services/profile_service.dart';
import '../services/volunteer_schedule_service.dart';
import '../core/supabase_config.dart';
import 'login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  final _ewasteService = EwasteService();
  final _profileService = ProfileService();
  final _scheduleService = VolunteerScheduleService();

  List<EwasteItem> ewasteItems = [];
  List<Ngo> ngos = [];
  List<PickupAgent> agents = [];
  List<VolunteerApplication> volunteerApps = [];
  List<VolunteerSchedule> allSchedules = [];
  Map<String, String> userNames = {};
  bool isLoading = true;

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchAllData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      // FIX: Cast the list to Iterable<Future<dynamic>> to satisfy Future.wait requirements
      final results = await Future.wait<dynamic>([
        _ewasteService.fetchAll(),
        _ewasteService.fetchNgos(),
        _ewasteService.fetchPickupAgents(),
        _profileService.fetchAllProfiles(),
        _profileService.fetchAllApplications(),
        _scheduleService.fetchAllSchedules(),
      ]);

      final items = results[0] as List<EwasteItem>;
      final ngoList = results[1] as List<Ngo>;
      final agentList = results[2] as List<PickupAgent>;
      final profiles = results[3] as List<Map<String, dynamic>>;
      final apps = results[4] as List<VolunteerApplication>;
      final schedules = results[5] as List<VolunteerSchedule>;

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
        volunteerApps = apps;
        allSchedules = schedules;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // --- Actions ---

  Future<void> _updateStatus(String itemId, String newStatus, String agentId) async {
    try {
      if (newStatus == 'collected') await _ewasteService.markAsCollected(itemId);
      if (newStatus == 'delivered') await _ewasteService.markAsDelivered(itemId);
      fetchAllData();
      _showSuccess('Status updated to ${newStatus.toUpperCase()}');
    } catch (e) {
      _showError('Failed to update: $e');
    }
  }

  Future<void> _assignTask(String itemId, String? agentId, String? ngoId) async {
    try {
      if (agentId != null) await _ewasteService.assignPickupAgent(itemId, agentId);
      if (ngoId != null) await _ewasteService.assignNgo(itemId, ngoId);
      fetchAllData();
      _showSuccess('Task assigned successfully!');
    } catch (e) {
      _showError('Assignment failed: $e');
    }
  }

  Future<void> _handleAppDecision(VolunteerApplication app, bool approve) async {
    try {
      await _profileService.decideOnApplication(app.id, app.userId, approve);
      fetchAllData();
      _showSuccess(approve ? 'Volunteer Approved' : 'Volunteer Rejected');
    } catch (e) {
      _showError('Decision error: $e');
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ $msg'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.green.shade800,
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('❌ $msg'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.red.shade800,
    ));
  }

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isDarkMode 
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] 
                : [const Color(0xFF15803D), const Color(0xFF166534)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Admin Console', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(text: 'Dispatch', icon: Icon(Icons.local_shipping)),
            Tab(text: 'Gatekeeper', icon: Icon(Icons.how_to_reg)),
            Tab(text: 'Logistics', icon: Icon(Icons.calendar_month)),
            Tab(text: 'Directory', icon: Icon(Icons.business_center)),
            Tab(text: 'Pulse', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(),
          ),
        ],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
            children: [
              _buildModernHeader(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDispatchTab(cardColor),
                    _buildGatekeeperTab(cardColor),
                    _buildLogisticsTab(cardColor),
                    _buildDirectoryTab(cardColor),
                    _buildPulseTab(cardColor),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMiniKPI('Queue', ewasteItems.where((i) => i.deliveryStatus == 'pending').length.toString(), Colors.orange),
            _buildMiniKPI('Active Help', agents.length.toString(), Colors.blue),
            _buildMiniKPI('Pending Apps', volunteerApps.where((a) => a.status == 'pending').length.toString(), Colors.purple),
            _buildMiniKPI('Completed', ewasteItems.where((i) => i.deliveryStatus == 'delivered').length.toString(), Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniKPI(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: _isDarkMode ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }

  // --- Tab Contents ---

  Widget _buildDispatchTab(Color cardColor) {
    final items = ewasteItems.where((i) => 
      i.itemName.toLowerCase().contains(_searchQuery) ||
      (userNames[i.userId] ?? '').toLowerCase().contains(_searchQuery)
    ).toList();

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) => _EwasteItemCard(
              item: items[index],
              cardColor: cardColor,
              isDarkMode: _isDarkMode,
              agents: agents,
              ngos: ngos,
              userName: userNames[items[index].userId] ?? 'Unknown User',
              onAssign: _assignTask,
              onStatusUpdate: _updateStatus,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGatekeeperTab(Color cardColor) {
    final pending = volunteerApps.where((a) => a.status == 'pending').toList();
    if (pending.isEmpty) return _buildEmptyState('No pending volunteer requests');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final app = pending[index];
        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(child: Text(app.fullName[0])),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(app.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(DateFormat('MMM d, yyyy').format(app.availableDate), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    if (app.agreedToPolicy) const Icon(Icons.verified_user, color: Colors.blue, size: 20),
                  ],
                ),
                const Divider(height: 25),
                const Text('Motivation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(app.motivation, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => _handleAppDecision(app, false), child: const Text('Reject'))),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton(onPressed: () => _handleAppDecision(app, true), child: const Text('Approve'))),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogisticsTab(Color cardColor) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentSchedules = allSchedules.where((s) => !s.date.isBefore(today)).toList();
    currentSchedules.sort((a, b) => a.date.compareTo(b.date));

    if (currentSchedules.isEmpty) return _buildEmptyState('No volunteer schedules found');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: currentSchedules.length,
      itemBuilder: (context, index) {
        final schedule = currentSchedules[index];
        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Icon(Icons.calendar_today, color: schedule.isAvailable ? Colors.green : Colors.grey),
            title: Text(userNames[schedule.volunteerId] ?? 'Volunteer'),
            subtitle: Text(DateFormat('EEEE, MMM d').format(schedule.date)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: schedule.isAvailable ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(schedule.isAvailable ? 'AVAILABLE' : 'BUSY', 
                style: TextStyle(color: schedule.isAvailable ? Colors.green : Colors.grey, fontWeight: FontWeight.bold, fontSize: 10)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDirectoryTab(Color cardColor) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDirectoryHeader('NGO Partners', Icons.business, Colors.blue),
        ...ngos.map((n) => _buildDirectoryTile(n.name, n.address, cardColor)),
        const SizedBox(height: 20),
        _buildDirectoryHeader('Active Agents', Icons.delivery_dining, Colors.green),
        ...agents.map((a) => _buildDirectoryTile(a.name, a.isActive ? 'Active' : 'Inactive', cardColor)),
      ],
    );
  }

  Widget _buildDirectoryHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDirectoryTile(String title, String subtitle, Color cardColor) {
    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 18),
      ),
    );
  }

  Widget _buildPulseTab(Color cardColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildChartCard('E-Waste Status Distribution', _buildPieChart(), cardColor),
          const SizedBox(height: 20),
          _buildChartCard('Weekly Contribution Trends', _buildLineChart(), cardColor),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chart, Color cardColor) {
    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20), // FIX: Removed invalid 'padding' from Card and wrapped child in Padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 25),
            SizedBox(height: 200, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final pending = ewasteItems.where((i) => i.deliveryStatus == 'pending').length.toDouble();
    final delivered = ewasteItems.where((i) => i.deliveryStatus == 'delivered').length.toDouble();
    final transit = ewasteItems.length - pending - delivered;

    return PieChart(
      PieChartData(
        sectionsSpace: 5,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(value: pending, color: Colors.orange, title: 'Queue', radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          PieChartSectionData(value: delivered, color: Colors.green, title: 'Done', radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          PieChartSectionData(value: transit.toDouble(), color: Colors.blue, title: 'In-Way', radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [FlSpot(0, 1), FlSpot(1, 3), FlSpot(2, 2), FlSpot(3, 5), FlSpot(4, 3.5), FlSpot(5, 4), FlSpot(6, 6)],
            isCurved: true,
            color: Colors.blueAccent,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search items or contributors...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to exit the Admin Console?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirm == true) {
      await AppSupabase.client.auth.signOut();
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
    }
  }
}

class _EwasteItemCard extends StatefulWidget {
  final EwasteItem item;
  final Color cardColor;
  final bool isDarkMode;
  final List<PickupAgent> agents;
  final List<Ngo> ngos;
  final String userName;
  final Function(String, String?, String?) onAssign;
  final Function(String, String, String) onStatusUpdate;

  const _EwasteItemCard({
    required this.item,
    required this.cardColor,
    required this.isDarkMode,
    required this.agents,
    required this.ngos,
    required this.userName,
    required this.onAssign,
    required this.onStatusUpdate,
  });

  @override
  State<_EwasteItemCard> createState() => _EwasteItemCardState();
}

class _EwasteItemCardState extends State<_EwasteItemCard> {
  String? _tempAgentId;
  String? _tempNgoId;

  @override
  void initState() {
    super.initState();
    _tempAgentId = widget.item.assignedAgentId;
    _tempNgoId = widget.item.assignedNgoId;
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.item.deliveryStatus;
    final isPending = status == 'pending';
    
    return Card(
      color: widget.cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: widget.item.imageUrl.isNotEmpty 
            ? Image.network(widget.item.imageUrl, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
            : const Icon(Icons.image_not_supported),
        ),
        title: Text(widget.item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(status))),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail('Contributor', widget.userName),
                _detail('Location', widget.item.location),
                const Divider(height: 30),
                if (isPending) ...[
                  const Text('Dispatch Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _tempAgentId == '0' ? null : _tempAgentId,
                    decoration: const InputDecoration(labelText: 'Select Volunteer'),
                    items: widget.agents.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                    onChanged: (v) => setState(() => _tempAgentId = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _tempNgoId == '0' ? null : _tempNgoId,
                    decoration: const InputDecoration(labelText: 'Select NGO Target'),
                    items: widget.ngos.map((n) => DropdownMenuItem(value: n.id, child: Text(n.name))).toList(),
                    onChanged: (v) => setState(() => _tempNgoId = v),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_tempAgentId == null || _tempNgoId == null) 
                        ? null 
                        : () => widget.onAssign(widget.item.id, _tempAgentId, _tempNgoId),
                      child: const Text('Confirm Dispatch'),
                    ),
                  )
                ] else ...[
                  _detail('Assigned Agent', widget.agents.firstWhere((a) => a.id == widget.item.assignedAgentId, orElse: () => PickupAgent.placeholder()).name),
                  _detail('Target NGO', widget.ngos.firstWhere((n) => n.id == widget.item.assignedNgoId, orElse: () => Ngo.placeholder()).name),
                  const SizedBox(height: 15),
                  if (status == 'assigned') 
                    SizedBox(width: double.infinity, child: FilledButton(onPressed: () => widget.onStatusUpdate(widget.item.id, 'collected', widget.item.assignedAgentId!), child: const Text('Confirm Collection'))),
                  if (status == 'collected') 
                    SizedBox(width: double.infinity, child: FilledButton(onPressed: () => widget.onStatusUpdate(widget.item.id, 'delivered', widget.item.assignedAgentId!), style: FilledButton.styleFrom(backgroundColor: Colors.green), child: const Text('Confirm Final Delivery'))),
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.black87, fontSize: 13),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'assigned': return Colors.blue;
      case 'collected': return Colors.purple;
      case 'delivered': return Colors.green;
      default: return Colors.grey;
    }
  }
}