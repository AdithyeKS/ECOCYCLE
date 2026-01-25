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

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
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

  late TabController _tabController;
  final List<String> _roles = ['user', 'agent', 'volunteer', 'admin'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isDarkMode = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() {
      setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // UPDATED: Centralized and parallel data fetching for reliability
  Future<void> fetchAllData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      // Parallel execution ensures all data is fetched before the UI updates
      final results = await Future.wait([
        _ewasteService.fetchAll(),
        _ewasteService.fetchNgos(),
        _ewasteService.fetchPickupAgents(),
        _profileService.fetchAllProfiles(),
        _profileService.fetchAllApplications(),
        _scheduleService.fetchAllSchedules(),
      ]);

      final List<EwasteItem> items = results[0] as List<EwasteItem>;
      final List<Map<String, dynamic>> profiles =
          results[3] as List<Map<String, dynamic>>;

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
        volunteerApps = results[4] as List<VolunteerApplication>;
        allSchedules = results[5] as List<VolunteerSchedule>;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
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
  Widget build(BuildContext context) {
    final bgColor =
        _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(130),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isDarkMode
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFF059669), const Color(0xFF047857)],
            ),
          ),
          child: Column(
            children: [
              AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                title: const Text('Admin Console',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                actions: [
                  IconButton(
                    icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode,
                        color: Colors.white),
                    onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () => _logout(),
                  ),
                ],
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.amber,
                tabs: const [
                  Tab(text: 'Dispatch', icon: Icon(Icons.local_shipping)),
                  Tab(text: 'Volunteer', icon: Icon(Icons.how_to_reg)),
                  Tab(text: 'Logistics', icon: Icon(Icons.calendar_month)),
                  Tab(text: 'Users', icon: Icon(Icons.people)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchAllData,
              child: Column(
                children: [
                  _buildModernHeader(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDispatchTab(cardColor),
                        _buildGatekeeperTab(cardColor),
                        _buildLogisticsTab(cardColor),
                        _buildUsersTab(cardColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Tabs continue with your existing UI building logic...
  // (Include _buildDispatchTab, _buildModernHeader, etc. from your original code)

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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No items found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.imageUrl.isNotEmpty
                          ? Image.network(
                              item.imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image_not_supported,
                                    size: 24),
                              ),
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[200],
                              child: const Icon(Icons.inventory, size: 24),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            userNames[item.userId] ?? 'Unknown User',
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
                        color: _getStatusColor(item.deliveryStatus)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.deliveryStatus.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(item.deliveryStatus),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      item.location,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const Spacer(),
                    if (item.deliveryStatus == 'pending' ||
                        item.deliveryStatus == 'assigned')
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'assign_agent') {
                            final selectedAgent =
                                await _showAgentSelectionDialog();
                            if (selectedAgent != null) {
                              await _assignTask(item.id, selectedAgent, null);
                            }
                          } else if (value == 'assign_ngo') {
                            final selectedNgo = await _showNgoSelectionDialog();
                            if (selectedNgo != null) {
                              await _assignTask(item.id, null, selectedNgo);
                            }
                          } else if (value == 'mark_collected') {
                            await _updateStatus(item.id, 'collected', '');
                          } else if (value == 'mark_delivered') {
                            await _updateStatus(item.id, 'delivered', '');
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'assign_agent',
                            child: Text('Assign Agent'),
                          ),
                          const PopupMenuItem(
                            value: 'assign_ngo',
                            child: Text('Assign NGO'),
                          ),
                          if (item.deliveryStatus == 'assigned')
                            const PopupMenuItem(
                              value: 'mark_collected',
                              child: Text('Mark Collected'),
                            ),
                          if (item.deliveryStatus == 'collected')
                            const PopupMenuItem(
                              value: 'mark_delivered',
                              child: Text('Mark Delivered'),
                            ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
    final pendingApps =
        volunteerApps.where((app) => app.status == 'pending').toList();

    if (pendingApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'No pending applications',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingApps.length,
      itemBuilder: (context, index) {
        final app = pendingApps[index];
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
                  ],
                ),
                const Divider(height: 25),
                const Text(
                  'Motivation:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(app.motivation, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 15),
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

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      child: Text(fullName[0].toUpperCase()),
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (role != 'admin')
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRoleChangeDialog(userId!, role),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Change Role'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showUserDetailsDialog(profile),
                        icon: const Icon(Icons.info, size: 16),
                        label: const Text('Details'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change User Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _roles
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
                  _showSuccess('Role updated to ${selectedRole[0].toUpperCase() + selectedRole.substring(1)}');
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
              _detailRow('Role', (profile['user_role'] ?? 'user').capitalize()),
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
    await AppSupabase.client.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
    }
  }
}
