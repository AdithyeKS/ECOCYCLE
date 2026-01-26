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

enum AdminTab { dispatch, volunteer, logistics, users, settings }

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _ewasteService = EwasteService();
  final _profileService = ProfileService();
  final _scheduleService = VolunteerScheduleService();

  List<EwasteItem> ewasteItems = [];
  List<Ngo> ngos = [];
  List<PickupAgent> agents = [];
  List<VolunteerApplication> volunteerApps = [];
  List<VolunteerSchedule> allSchedules = [];
  Map<String, String> userNames = {};
  List<Map<String, dynamic>> allProfiles = [];
  bool isLoading = true;

  // Logistics tab state
  EwasteItem? selectedItem;
  DateTime selectedDate = DateTime.now();
  List<VolunteerSchedule> availableVolunteers = [];
  bool isFetchingVolunteers = false;

  // Mobile app state
  AdminTab _selectedTab = AdminTab.dispatch;
  final List<String> _roles = ['user', 'agent', 'volunteer', 'admin'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isDarkMode = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    fetchAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // UPDATED: Centralized and parallel data fetching for reliability
  Future<void> fetchAllData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      print('--- Starting admin data fetch ---');

      // Parallel execution ensures all data is fetched before the UI updates
      final results = await Future.wait([
        _ewasteService.fetchAll(),
        _ewasteService.fetchNgos(),
        _ewasteService.fetchPickupAgents(),
        _profileService.fetchAllProfiles(),
        _profileService.fetchAllApplications(),
        _scheduleService.fetchAllSchedules(),
      ], eagerError: false);

      final List<EwasteItem> items = results[0] as List<EwasteItem>;
      final List<Map<String, dynamic>> profiles =
          results[3] as List<Map<String, dynamic>>;
      final List<VolunteerApplication> apps =
          results[4] as List<VolunteerApplication>;

      print('✓ E-waste items: ${items.length}');
      print('✓ Profiles: ${profiles.length}');
      print('✓ Volunteer applications: ${apps.length}');

      // Create a map for quick name lookups by ID
      final Map<String, String> namesMap = {};
      for (final profile in profiles) {
        final id = profile['id'] as String?;
        final fullName = profile['full_name'] as String?;
        if (id != null && fullName != null) {
          namesMap[id] = fullName;
        }
      }

      // Sort items by status
      items.sort((a, b) {
        final order = ['pending', 'assigned', 'collected', 'delivered'];
        return order
            .indexOf(a.deliveryStatus)
            .compareTo(order.indexOf(b.deliveryStatus));
      });

      setState(() {
        ewasteItems = items;
        ngos = results[1] as List<Ngo>;
        agents = results[2] as List<PickupAgent>;
        userNames = namesMap;
        allProfiles = profiles;
        volunteerApps = apps;
        allSchedules = results[5] as List<VolunteerSchedule>;
        isLoading = false;
      });
      print('--- Admin data fetch complete ---');
    } catch (e) {
      setState(() => isLoading = false);
      print('✗ Error fetching admin data: $e');
      _showError('Failed to synchronize data: $e');
    }
  }

  // --- Actions ---

  Future<void> _updateStatus(
      String itemId, String newStatus, String agentId) async {
    try {
      if (newStatus == 'collected')
        await _ewasteService.markAsCollected(itemId);
      if (newStatus == 'delivered')
        await _ewasteService.markAsDelivered(itemId);
      fetchAllData();
      _showSuccess('Status updated to ${newStatus.toUpperCase()}');
    } catch (e) {
      _showError('Update failed: $e');
    }
  }

  Future<void> _assignTask(
      String itemId, String? agentId, String? ngoId) async {
    try {
      if (agentId != null)
        await _ewasteService.assignPickupAgent(itemId, agentId);
      if (ngoId != null) await _ewasteService.assignNgo(itemId, ngoId);
      fetchAllData();
      _showSuccess('Task assigned successfully!');
    } catch (e) {
      _showError('Assignment failed: $e');
    }
  }

  Future<void> _handleAppDecision(
      VolunteerApplication app, bool approve) async {
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
  @override
  Widget build(BuildContext context) {
    final bgColor =
        _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          _getTabTitle(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: _isDarkMode ? Colors.white : Colors.black),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
          IconButton(
            icon: Icon(Icons.logout,
                color: _isDarkMode ? Colors.white : Colors.black),
            onPressed: _logout,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchAllData,
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search users, items, emails...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor:
                            _isDarkMode ? Colors.grey[800] : Colors.grey[100],
                      ),
                    ),
                  ),
                  Expanded(child: _buildTabContent(cardColor)),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: AdminTab.values.indexOf(_selectedTab),
        onTap: (index) => setState(() => _selectedTab = AdminTab.values[index]),
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        selectedItemColor: Colors.green,
        unselectedItemColor:
            _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Dispatch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.how_to_reg),
            label: 'Volunteers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Logistics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  String _getTabTitle() {
    switch (_selectedTab) {
      case AdminTab.dispatch:
        return 'Dispatch Management';
      case AdminTab.volunteer:
        return 'Volunteer Applications';
      case AdminTab.logistics:
        return 'Logistics & Scheduling';
      case AdminTab.users:
        return 'User Management';
      case AdminTab.settings:
        return 'Settings';
    }
  }

  Widget _buildTabContent(Color cardColor) {
    switch (_selectedTab) {
      case AdminTab.dispatch:
        return _buildDispatchTab(cardColor);
      case AdminTab.volunteer:
        return _buildGatekeeperTab(cardColor);
      case AdminTab.logistics:
        return _buildLogisticsTab(cardColor);
      case AdminTab.users:
        return _buildUsersTab(cardColor);
      case AdminTab.settings:
        return _buildSettingsTab(cardColor);
    }
  }

  Widget _buildSettingsTab(Color cardColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Dark Mode',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Switch(
                  value: _isDarkMode,
                  onChanged: (value) => setState(() => _isDarkMode = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeader() {
    final pendingItems =
        ewasteItems.where((item) => item.deliveryStatus == 'pending').length;
    final assignedItems =
        ewasteItems.where((item) => item.deliveryStatus == 'assigned').length;
    final collectedItems =
        ewasteItems.where((item) => item.deliveryStatus == 'collected').length;
    final deliveredItems =
        ewasteItems.where((item) => item.deliveryStatus == 'delivered').length;
    final pendingApps =
        volunteerApps.where((app) => app.status == 'pending').length;
    final totalUsers = allProfiles.length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard Overview',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard('Pending Items', pendingItems.toString(),
                  Icons.pending, Colors.orange),
              const SizedBox(width: 12),
              _buildStatCard('Assigned', assignedItems.toString(),
                  Icons.assignment, Colors.blue),
              const SizedBox(width: 12),
              _buildStatCard('Collected', collectedItems.toString(),
                  Icons.check_circle, Colors.green),
              const SizedBox(width: 12),
              _buildStatCard('Delivered', deliveredItems.toString(),
                  Icons.local_shipping, Colors.purple),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard('Pending Apps', pendingApps.toString(),
                  Icons.person_add, Colors.red),
              const SizedBox(width: 12),
              _buildStatCard('Total Users', totalUsers.toString(), Icons.people,
                  Colors.teal),
              const SizedBox(width: 12),
              _buildStatCard('Agents', agents.length.toString(),
                  Icons.support_agent, Colors.indigo),
              const SizedBox(width: 12),
              _buildStatCard(
                  'NGOs', ngos.length.toString(), Icons.business, Colors.brown),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDispatchTab(Color cardColor) {
    final filteredItems = ewasteItems.where((item) {
      if (_searchQuery.isEmpty) return true;
      final itemName = item.itemName.toLowerCase();
      final description = item.description.toLowerCase();
      final location = item.location.toLowerCase();
      final userName = userNames[item.userId]?.toLowerCase() ?? '';
      return itemName.contains(_searchQuery) ||
          description.contains(_searchQuery) ||
          location.contains(_searchQuery) ||
          userName.contains(_searchQuery);
    }).toList();

    if (filteredItems.isEmpty) {
      return _buildEmptyState('No e-waste items', Icons.inventory);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final userName = userNames[item.userId] ?? 'Unknown';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey[50]!],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Username | Item Name | Status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.imageUrl.isNotEmpty
                            ? Image.network(
                                item.imageUrl,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image_not_supported,
                                      size: 28),
                                ),
                              )
                            : Container(
                                width: 70,
                                height: 70,
                                color: Colors.grey[200],
                                child: const Icon(Icons.inventory, size: 28),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '👤 $userName',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.itemName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(item.deliveryStatus),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.location,
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[700]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons Row
                  if (item.deliveryStatus == 'pending' ||
                      item.deliveryStatus == 'assigned')
                    Row(
                      children: [
                        // Assign to NGO
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final selectedNgo =
                                  await _showNgoSelectionDialog();
                              if (selectedNgo != null) {
                                await _assignTask(item.id, null, selectedNgo);
                              }
                            },
                            icon: const Icon(Icons.business, size: 16),
                            label: const Text('NGO',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Assign to Volunteer
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final selectedAgent =
                                  await _showAgentSelectionDialog();
                              if (selectedAgent != null) {
                                await _assignTask(item.id, selectedAgent, null);
                              }
                            },
                            icon: const Icon(Icons.person, size: 16),
                            label: const Text('Agent',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Status Change
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showStatusChangeDialog(item),
                            icon: const Icon(Icons.trending_down, size: 16),
                            label: const Text('Status',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: _getStatusColor(status),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showStatusChangeDialog(EwasteItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Assigned'),
              onTap: () async {
                Navigator.pop(context);
                await _updateStatus(item.id, 'assigned', '');
              },
            ),
            ListTile(
              title: const Text('Collected'),
              onTap: () async {
                Navigator.pop(context);
                await _updateStatus(item.id, 'collected', '');
              },
            ),
            ListTile(
              title: const Text('Delivered'),
              onTap: () async {
                Navigator.pop(context);
                await _updateStatus(item.id, 'delivered', '');
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'collected':
        return Colors.green;
      case 'delivered':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<String?> _showAgentSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Agent'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: agents.length,
            itemBuilder: (context, index) {
              final agent = agents[index];
              return ListTile(
                title: Text(agent.name),
                subtitle: Text(agent.phone),
                onTap: () => Navigator.pop(context, agent.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showNgoSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select NGO'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: ngos.length,
            itemBuilder: (context, index) {
              final ngo = ngos[index];
              return ListTile(
                title: Text(ngo.name),
                subtitle: Text(ngo.phone ?? ngo.address),
                onTap: () => Navigator.pop(context, ngo.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildGatekeeperTab(Color cardColor) {
    // Show all applications sorted by status and date
    final sortedApps = volunteerApps.toList();
    sortedApps.sort((a, b) {
      // Sort by status: pending first, then approved, then rejected
      final statusOrder = {'pending': 0, 'approved': 1, 'rejected': 2};
      final statusCompare =
          (statusOrder[a.status] ?? 3).compareTo(statusOrder[b.status] ?? 3);
      if (statusCompare != 0) return statusCompare;
      // Then sort by date (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });

    if (sortedApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'No applications',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedApps.length,
      itemBuilder: (context, index) {
        final app = sortedApps[index];
        final statusColor = app.status == 'pending'
            ? Colors.orange
            : app.status == 'approved'
                ? Colors.green
                : Colors.red;
        final statusLabel = app.status.toUpperCase();

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(child: Text(app.fullName[0].toUpperCase())),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, yyyy').format(app.availableDate),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 25),
                const Text(
                  'Motivation:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(app.motivation, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Text(
                  'Email: ${app.email}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  'Phone: ${app.phone}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  'Address: ${app.address}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 15),
                // Only show action buttons for pending applications
                if (app.status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleAppDecision(app, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _handleAppDecision(app, true),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: Text(
                      '${app.status.toUpperCase()} on ${DateFormat('MMM d, yyyy').format(app.createdAt)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogisticsTab(Color cardColor) {
    if (allSchedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No volunteer schedules',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Group schedules by date
    final groupedSchedules = <DateTime, List<VolunteerSchedule>>{};
    for (final schedule in allSchedules) {
      final date =
          DateTime(schedule.date.year, schedule.date.month, schedule.date.day);
      groupedSchedules[date] = (groupedSchedules[date] ?? [])..add(schedule);
    }

    final sortedDates = groupedSchedules.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final schedules = groupedSchedules[date]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMM d, yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...schedules.map((schedule) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            schedule.isAvailable
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: schedule.isAvailable
                                ? Colors.green
                                : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              userNames[schedule.volunteerId] ??
                                  'Unknown Volunteer',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: schedule.isAvailable
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              schedule.isAvailable
                                  ? 'Available'
                                  : 'Unavailable',
                              style: TextStyle(
                                color: schedule.isAvailable
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersTab(Color cardColor) {
    final filteredProfiles = allProfiles.where((profile) {
      if (_searchQuery.isEmpty) return true;
      final fullName = (profile['full_name'] as String?)?.toLowerCase() ?? '';
      final email = (profile['email'] as String?)?.toLowerCase() ?? '';
      final role = (profile['user_role'] as String?)?.toLowerCase() ?? '';
      return fullName.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          role.contains(_searchQuery);
    }).toList();

    if (filteredProfiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No users found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredProfiles.length,
      itemBuilder: (context, index) {
        final profile = filteredProfiles[index];
        final userId = profile['id'] as String?;
        final fullName = profile['full_name'] as String? ?? 'Unknown';
        final email = profile['email'] as String? ?? '';
        final role = profile['user_role'] as String? ?? 'user';
        final phone = profile['phone'] as String? ?? '';
        final isAdmin = role == 'admin';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: isAdmin
                    ? [Colors.red[50]!, Colors.red[100]!]
                    : [Colors.white, Colors.grey[50]!],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isAdmin ? Colors.red : Colors.blue,
                        child: Text(
                          fullName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              email,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            color: _getRoleColor(role),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          phone,
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (!isAdmin)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _showRoleChangeDialog(userId!, role),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Role',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _confirmDeleteUser(userId!, fullName),
                            icon: const Icon(Icons.delete, size: 16),
                            label: const Text('Delete',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showUserDetailsDialog(profile),
                            icon: const Icon(Icons.info, size: 16),
                            label: const Text('Info',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock, size: 16, color: Colors.red[400]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Admin accounts cannot be modified',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteUser(String userId, String userName) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Delete User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete $userName?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red[300]!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '⚠️ This action CANNOT be undone. The user account, profile, and all related data will be permanently deleted.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[700],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteUser(userId, userName);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete User'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String userId, String userName) async {
    try {
      setState(() => _isDeleting = true);

      // Delete user profile first
      await AppSupabase.client.from('profiles').delete().eq('id', userId);

      // Delete user auth account
      try {
        await AppSupabase.client.auth.admin.deleteUser(userId);
      } catch (e) {
        print('Auth deletion note: $e (profile already deleted)');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $userName deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await fetchAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'agent':
        return Colors.blue;
      case 'volunteer':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showRoleChangeDialog(String userId, String currentRole) async {
    String selectedRole = currentRole;
    // Only allow user and volunteer roles (not admin or agent)
    final allowedRoles = ['user', 'volunteer'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change User Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: allowedRoles
                .map((role) => RadioListTile<String>(
                      title: Text(role[0].toUpperCase() + role.substring(1)),
                      value: role,
                      groupValue: selectedRole,
                      onChanged: (value) {
                        setState(() => selectedRole = value!);
                      },
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await _profileService.updateUserRole(userId, selectedRole);
                  fetchAllData();
                  _showSuccess(
                      'Role updated to ${selectedRole[0].toUpperCase() + selectedRole.substring(1)}');
                  Navigator.pop(context);
                } catch (e) {
                  _showError('Failed to update role: $e');
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetailsDialog(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Name', profile['full_name'] ?? 'N/A'),
              _detailRow('Email', profile['email'] ?? 'N/A'),
              _detailRow('Phone', profile['phone'] ?? 'N/A'),
              _detailRow('Role', _capitalizeFirst(profile['user_role'] ?? 'user')),
              _detailRow(
                  'Created',
                  profile['created_at'] != null
                      ? DateFormat('MMM d, yyyy')
                          .format(DateTime.parse(profile['created_at']))
                      : 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // (Include other tab methods as originally defined)

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AppSupabase.client.auth.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false,
                );
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
