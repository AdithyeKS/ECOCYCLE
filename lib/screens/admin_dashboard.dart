import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/ewaste_item.dart';
import '../models/plastic_item.dart';
import '../models/cloth_item.dart';
import '../models/ngo.dart';
import '../models/pickup_agent.dart';
import '../models/profile.dart';
import '../models/volunteer_application.dart';
import '../models/volunteer_schedule.dart';
import '../models/feedback.dart';
import '../services/ewaste_service.dart';
import '../services/profile_service.dart';
import '../services/volunteer_schedule_service.dart';
import '../services/feedback_service.dart';
import '../services/plastic_service.dart';
import '../services/cloth_service.dart';
import '../core/supabase_config.dart';
import 'login_screen.dart';

enum AdminTab { dashboard, schedule, volunteerApps, users, ngo, feedback }

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _ewasteService = EwasteService();
  final _profileService = ProfileService();
  final _scheduleService = VolunteerScheduleService();
  final _feedbackService = FeedbackService();
  final _plasticService = PlasticService();
  final _clothService = ClothService();

  List<EwasteItem> ewasteItems = [];
  List<PlasticItem> plasticItems = [];
  List<ClothItem> clothItems = [];
  List<Ngo> ngos = [];
  List<PickupAgent> agents = [];
  List<VolunteerApplication> volunteerApps = [];
  List<VolunteerSchedule> allSchedules = [];
  List<FeedbackItem> feedbackItems = [];
  Map<String, String> userNames = {};
  List<Map<String, dynamic>> allProfiles = [];
  bool isLoading = true;

  // Logistics tab state
  Map<String, dynamic>? selectedWasteItem;
  DateTime selectedDate = DateTime.now();
  List<VolunteerSchedule> availableVolunteers = [];
  bool isFetchingVolunteers = false;
  List<Map<String, dynamic>> pendingAssignments = [];

  // Mobile app state
  AdminTab _selectedTab = AdminTab.dashboard;
  final List<String> _roles = ['user', 'agent', 'volunteer', 'admin'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isDarkMode = true;
  bool _isDeleting = false;

  // Feedback expansion state
  final Set<String> _expandedFeedback = {};

  // Volunteer application expansion state
  final Set<String> _expandedVolunteerApps = {};

  // Calendar state for schedules tab
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

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
        _feedbackService.fetchAllFeedback(),
        _plasticService.fetchAll(),
        _clothService.fetchAll(),
      ], eagerError: false);

      // Extract results with error handling
      final List<EwasteItem> items = results[0] is Exception
          ? []
          : (results[0] as List<EwasteItem>? ?? []);
      final List<Ngo> ngosList =
          results[1] is Exception ? [] : (results[1] as List<Ngo>? ?? []);
      final List<PickupAgent> agentsList = results[2] is Exception
          ? []
          : (results[2] as List<PickupAgent>? ?? []);
      final List<Map<String, dynamic>> profileMaps = results[3] is Exception
          ? []
          : (results[3] as List<Map<String, dynamic>>? ?? []);
      final List<VolunteerApplication> apps = results[4] is Exception
          ? []
          : (results[4] as List<VolunteerApplication>? ?? []);
      final List<VolunteerSchedule> schedules = results[5] is Exception
          ? []
          : (results[5] as List<VolunteerSchedule>? ?? []);
      final List<FeedbackItem> feedbacks = results[6] is Exception
          ? []
          : (results[6] as List<FeedbackItem>? ?? []);
      final List<PlasticItem> plastics = results[7] is Exception
          ? []
          : (results[7] as List<PlasticItem>? ?? []);
      final List<ClothItem> cloths =
          results[8] is Exception ? [] : (results[8] as List<ClothItem>? ?? []);

      // Log any errors
      if (results[4] is Exception) {
        print('⚠️ Error fetching volunteer applications: ${results[4]}');
      }
      if (results[3] is Exception) {
        print('⚠️ Error fetching profiles: ${results[3]}');
      }

      print('✓ E-waste items: ${items.length}');
      print('✓ NGOs: ${ngos.length}');
      print('✓ Agents: ${agents.length}');
      print('✓ Plastic items: ${plastics.length}');
      print('✓ Cloth items: ${cloths.length}');
      print('✓ Profiles: ${profileMaps.length}');
      print('✓ Volunteer applications: ${apps.length}');
      print('✓ Schedules: ${schedules.length}');
      print('✓ Feedbacks: ${feedbacks.length}');

      // Convert maps to Profile objects
      final List<Profile> profiles =
          profileMaps.map((map) => Profile.fromJson(map)).toList();

      // Create a map for quick name lookups by ID
      final Map<String, String> namesMap = {};
      for (final profile in profiles) {
        final id = profile.id;
        final fullName = profile.fullName;
        if (id.isNotEmpty && fullName != null) {
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
        plasticItems = plastics;
        clothItems = cloths;
        ngos = ngosList;
        agents = agentsList;
        userNames = namesMap;
        allProfiles = profileMaps;
        volunteerApps = apps;
        allSchedules = schedules;
        feedbackItems = feedbacks;
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
      await fetchAllData();
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
            icon: Icon(Icons.refresh,
                color: _isDarkMode ? Colors.white : Colors.black),
            onPressed: fetchAllData,
          ),
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
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Dispatch',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_add),
            label: 'Volunteers',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'NGOs',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.feedback),
            label: 'Feedback',
          ),
        ],
      ),
    );
  }

  String _getTabTitle() {
    switch (_selectedTab) {
      case AdminTab.dashboard:
        return 'Admin Dashboard';
      case AdminTab.schedule:
        return 'Dispatch Management';
      case AdminTab.volunteerApps:
        return 'Volunteer Applications';
      case AdminTab.users:
        return 'User Management';
      case AdminTab.ngo:
        return 'NGO Management';
      case AdminTab.feedback:
        return 'Feedback Management';
    }
  }

  Widget _buildTabContent(Color cardColor) {
    switch (_selectedTab) {
      case AdminTab.dashboard:
        return _buildDashboardTab(cardColor);
      case AdminTab.schedule:
        return _buildScheduleTab(cardColor);
      case AdminTab.volunteerApps:
        return _buildVolunteerAppsTab(cardColor);
      case AdminTab.users:
        return _buildUsersTab(cardColor);
      case AdminTab.ngo:
        return _buildNgoManagementTab(cardColor);
      case AdminTab.feedback:
        return _buildFeedbackTab(cardColor);
    }
  }

  Widget _buildDashboardTab(Color cardColor) {
    // Calculate metrics
    final totalPickupRequests =
        ewasteItems.length + plasticItems.length + clothItems.length;
    final pendingVolunteerRequests =
        volunteerApps.where((app) => app.status == 'pending').length;
    final totalNgoCenters = ngos.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildMetricCard('Total NGO Centers', totalNgoCenters.toString(),
                  Icons.business, Colors.purple),
              _buildMetricCard(
                  'Pending Volunteer Requests',
                  pendingVolunteerRequests.toString(),
                  Icons.person_add,
                  Colors.orange),
              _buildMetricCard(
                  'Total Pickup Requests',
                  totalPickupRequests.toString(),
                  Icons.assignment,
                  Colors.blue),
            ],
          ),
          const SizedBox(height: 30),
          // Add charts or additional widgets here if needed
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTab(Color cardColor) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tab Bar
          Container(
            color: cardColor,
            child: const TabBar(
              tabs: [
                Tab(text: 'Pending Requests', icon: Icon(Icons.assignment)),
                Tab(text: 'Schedules', icon: Icon(Icons.calendar_today)),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              children: [
                _buildPendingWasteSection(),
                _buildSchedulesTab(cardColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingWasteSection() {
    // Create unified list of pending waste items
    final pendingItems = <Map<String, dynamic>>[];

    // Add e-waste items
    for (final item
        in ewasteItems.where((item) => item.deliveryStatus == 'pending')) {
      pendingItems.add({
        'type': 'e-waste',
        'item': item,
        'service': _ewasteService,
      });
    }

    // Add plastic items
    for (final item
        in plasticItems.where((item) => item.deliveryStatus == 'pending')) {
      pendingItems.add({
        'type': 'plastic',
        'item': item,
        'service': _plasticService,
      });
    }

    // Add cloth items
    for (final item
        in clothItems.where((item) => item.deliveryStatus == 'pending')) {
      pendingItems.add({
        'type': 'cloth',
        'item': item,
        'service': _clothService,
      });
    }

    if (pendingItems.isEmpty) {
      return _buildEmptyState('No pending requests', Icons.assignment);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingItems.length,
      itemBuilder: (context, index) {
        final itemData = pendingItems[index];
        final item = itemData['item'];
        final type = itemData['type'];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 3,
          color: Colors.blue.shade50,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.imageUrl!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.image_not_supported,
                                      size: 60),
                            ),
                          )
                        : const Icon(Icons.image_not_supported, size: 60),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${type.toUpperCase()}: ${item.itemName ?? 'Unknown'}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description ?? 'No description',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Created by: ${userNames[item.userId] ?? 'Unknown User'}',
                            style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.location ?? 'Unknown location',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.deliveryStatus ?? 'pending',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: isFetchingVolunteers
                          ? null
                          : () => _showVolunteerSelectionDialog(
                              itemData, selectedDate),
                      icon: isFetchingVolunteers
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.schedule),
                      label: Text(
                          isFetchingVolunteers ? 'Loading...' : 'Schedule'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
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

  Ngo? _findBestNgoForItem(dynamic item, String type) {
    // Filter NGOs that accept this waste type
    final suitableNgos = ngos.where((ngo) {
      final wasteTypes = ngo.wasteTypes ?? [];
      return wasteTypes.contains(type) || wasteTypes.isEmpty;
    }).toList();

    if (suitableNgos.isEmpty) return null;

    // For now, just return the first suitable NGO
    // In the future, this could be enhanced with distance calculation
    return suitableNgos.first;
  }

  void _showVolunteerSelectionDialog(
      Map<String, dynamic> itemData, DateTime date) async {
    final currentContext = context; // Store context to avoid async gap issues
    setState(() => isFetchingVolunteers = true);

    try {
      // Get available volunteers for the selected date from schedules
      final dateString = date.toIso8601String().split('T')[0];
      final availableSchedules = await AppSupabase.client
          .from('volunteer_schedules')
          .select('volunteer_id, is_available')
          .eq('date', dateString)
          .eq('is_available', true);

      final volunteerIds = (availableSchedules as List)
          .map((record) => record['volunteer_id'] as String)
          .toSet()
          .toList();

      // Get volunteer profiles from allProfiles
      final availableVolunteers = allProfiles.where((profile) {
        final userId = profile['id'] as String?;
        final userRole = profile['user_role'] as String?;
        return userId != null &&
            volunteerIds.contains(userId) &&
            (userRole == 'volunteer' || userRole == 'agent');
      }).map((profile) {
        return PickupAgent(
          id: profile['id'] ?? '',
          name: profile['full_name'] ?? 'Unknown',
          phone: profile['phone_number'] ?? '',
          email: profile['email'] ?? '',
          isActive: true,
          currentLatitude: null,
          currentLongitude: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();

      // Sort by name
      availableVolunteers.sort((a, b) => a.name.compareTo(b.name));

      setState(() => isFetchingVolunteers = false);

      if (availableVolunteers.isEmpty) {
        showDialog(
          context: currentContext,
          builder: (context) => AlertDialog(
            title: const Text('No Available Volunteers'),
            content: const Text(
                'No volunteers have set their availability for the selected date. Volunteers need to set their availability in their dashboard first.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      showDialog(
        context: currentContext,
        builder: (context) => AlertDialog(
          title: Text(
              'Select Volunteer for ${DateFormat('MMM dd, yyyy').format(date)}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: availableVolunteers.length,
              itemBuilder: (context, index) {
                final volunteer = availableVolunteers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withOpacity(0.2),
                      child: const Icon(Icons.person, color: Colors.green),
                    ),
                    title: Text(volunteer.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Phone: ${volunteer.phone}'),
                        Text(
                            'Status: Available (${DateFormat('MMM dd').format(date)})'),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        try {
                          // Assign volunteer to item
                          final service = itemData['service'];
                          final item = itemData['item'];
                          final type = itemData['type'];

                          // Assign the volunteer/agent
                          await service.assignPickupAgent(
                              item.id, volunteer.id);
                          await service.updateStatus(item.id, 'assigned');

                          // Automatically assign the best NGO
                          final bestNgo = _findBestNgoForItem(item, type);
                          if (bestNgo != null) {
                            await service.assignNgo(item.id, bestNgo.id);
                            setState(() {
                              int index = ewasteItems.indexOf(item);
                              if (index != -1) {
                                ewasteItems[index] = item.copyWith(
                                  assignedAgentId: volunteer.id,
                                  assignedNgoId: bestNgo.id,
                                  deliveryStatus: 'assigned',
                                );
                              }
                            });
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(currentContext).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Assigned ${volunteer.name} to pickup and ${bestNgo.name} as NGO')),
                            );
                          } else {
                            setState(() {
                              int index = ewasteItems.indexOf(item);
                              if (index != -1) {
                                ewasteItems[index] = item.copyWith(
                                  assignedAgentId: volunteer.id,
                                  deliveryStatus: 'assigned',
                                );
                              }
                            });
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(currentContext).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Assigned ${volunteer.name} to pickup. No suitable NGO found - assign manually.')),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(currentContext).showSnackBar(
                            SnackBar(
                                content: Text('Error assigning volunteer: $e')),
                          );
                        }
                      },
                      child: const Text('Assign'),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => isFetchingVolunteers = false);
      showDialog(
        context: currentContext,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to fetch available volunteers: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDispatchManagementTab(Color cardColor) {
    // Create unified list of assigned waste items
    final assignedItems = <Map<String, dynamic>>[];

    // Add e-waste items
    for (final item
        in ewasteItems.where((item) => item.deliveryStatus == 'assigned')) {
      assignedItems.add({
        'type': 'e-waste',
        'item': item,
        'service': _ewasteService,
      });
    }

    // Add plastic items
    for (final item
        in plasticItems.where((item) => item.deliveryStatus == 'assigned')) {
      assignedItems.add({
        'type': 'plastic',
        'item': item,
        'service': _plasticService,
      });
    }

    // Add cloth items
    for (final item
        in clothItems.where((item) => item.deliveryStatus == 'assigned')) {
      assignedItems.add({
        'type': 'cloth',
        'item': item,
        'service': _clothService,
      });
    }

    return assignedItems.isEmpty
        ? _buildEmptyState('No assigned pickups', Icons.local_shipping)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: assignedItems.length,
            itemBuilder: (context, index) {
              final itemData = assignedItems[index];
              final item = itemData['item'];
              final type = itemData['type'];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${type.toUpperCase()}: ${item.itemName ?? 'Unknown'}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Location: ${item.location ?? 'Unknown'}'),
                      Text('User: ${userNames[item.userId] ?? 'Unknown'}'),
                      Text('Status: ${item.deliveryStatus ?? 'Unknown'}'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _assignNgo(itemData),
                              child: Text(item.assignedNgoId != null
                                  ? 'Change NGO'
                                  : 'Assign NGO'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  _updateItemStatus(itemData, 'collected'),
                              child: const Text('Mark Collected'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () =>
                            _updateItemStatus(itemData, 'deposited'),
                        child: const Text('Mark Deposited'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  void _assignNgo(Map<String, dynamic> itemData) {
    final item = itemData['item'];
    final service = itemData['service'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign NGO'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: ngos.length,
            itemBuilder: (context, index) {
              final ngo = ngos[index];
              return ListTile(
                title: Text(ngo.name),
                subtitle: Text('${ngo.district}, ${ngo.address}'),
                onTap: () async {
                  try {
                    // Update item with NGO
                    await service.assignNgo(item.id, ngo.id);
                    setState(() {
                      item.assignedNgoId = ngo.id;
                    });
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Assigned to ${ngo.name}')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error assigning NGO: $e')),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _updateItemStatus(Map<String, dynamic> itemData, String status) async {
    final item = itemData['item'];
    final service = itemData['service'];

    try {
      // Update status based on the status value
      if (status == 'collected') {
        await service.markAsCollected(item.id);
      } else if (status == 'deposited' || status == 'delivered') {
        await service.markAsDelivered(item.id);
      } else {
        await service.updateStatus(item.id, status);
      }
      setState(() {
        item.deliveryStatus = status;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $status')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  Widget _buildNgoManagementTab(Color cardColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: cardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('NGO Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _addNgo,
                icon: const Icon(Icons.add),
                label: const Text('Add NGO'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ngos.isEmpty
              ? _buildEmptyState('No NGOs registered', Icons.business)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ngos.length,
                  itemBuilder: (context, index) {
                    final ngo = ngos[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(ngo.name),
                        subtitle: Text(
                            '${ngo.district}\n${ngo.address}\nWaste Types: ${ngo.wasteTypes?.join(', ') ?? 'N/A'}\nContact: ${ngo.contactInfo ?? 'N/A'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editNgo(ngo),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _addNgo() async {
    final result = await showDialog<Ngo>(
      context: context,
      builder: (context) => const AddNgoDialog(),
    );

    if (result != null) {
      try {
        await _ewasteService.addNgo(result);
        fetchAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NGO added successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding NGO: $e')),
        );
      }
    }
  }

  void _editNgo(Ngo ngo) async {
    final result = await showDialog<Ngo>(
      context: context,
      builder: (context) => EditNgoDialog(ngo: ngo),
    );

    if (result != null) {
      try {
        await _ewasteService.updateNgo(ngo.id, result.toJson());
        fetchAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NGO updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating NGO: $e')),
        );
      }
    }
  }

  Widget _buildFeedbackTab(Color cardColor) {
    final filteredFeedback = feedbackItems.where((feedback) {
      if (_searchQuery.isEmpty) return true;
      final subject = feedback.subject.toLowerCase();
      final message = feedback.message.toLowerCase();
      final userEmail = feedback.userEmail?.toLowerCase() ?? '';
      final category = feedback.category.toLowerCase();
      return subject.contains(_searchQuery) ||
          message.contains(_searchQuery) ||
          userEmail.contains(_searchQuery) ||
          category.contains(_searchQuery);
    }).toList();

    if (filteredFeedback.isEmpty) {
      return _buildEmptyState('No feedback items', Icons.feedback);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredFeedback.length,
      itemBuilder: (context, index) {
        final feedback = filteredFeedback[index];
        final isExpanded = _expandedFeedback.contains(feedback.id);
        final statusColor = feedback.status == 'pending'
            ? Colors.green.shade300
            : feedback.status == 'reviewed'
                ? Colors.green.shade500
                : feedback.status == 'resolved'
                    ? Colors.green.shade700
                    : Colors.grey;

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
                // Header Row - Always visible
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feedback.subject,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            feedback.userEmail ?? 'Anonymous',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showFeedbackStatusDialog(feedback),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              feedback.status.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 14,
                              color: statusColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Category - Always visible
                const SizedBox(height: 8),
                Text(
                  'Category: ${feedback.category}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),

                // Clickable message preview
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedFeedback.remove(feedback.id);
                      } else {
                        _expandedFeedback.add(feedback.id);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isExpanded
                                ? feedback.message
                                : (feedback.message.length > 100
                                    ? '${feedback.message.substring(0, 100)}...'
                                    : feedback.message),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),

                // Expandable content (Admin Response and Actions)
                if (isExpanded) ...[
                  if (feedback.adminResponse != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Response:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            feedback.adminResponse!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showFeedbackStatusDialog(feedback),
                          icon: const Icon(Icons.flag, size: 16),
                          label: const Text('Update Status',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmDeleteFeedback(feedback),
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Delete',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFeedbackStatusDialog(FeedbackItem feedback) {
    // Enforce strict workflow: Pending → Reviewed → Resolved (no Closed option)
    List<String> availableStatuses = [];

    switch (feedback.status) {
      case 'pending':
        availableStatuses = ['reviewed'];
        break;
      case 'reviewed':
        availableStatuses = ['resolved'];
        break;
      case 'resolved':
        // No further transitions allowed - resolved is the final state
        availableStatuses = [];
        break;
      default:
        availableStatuses = ['pending'];
    }

    if (availableStatuses.isEmpty) {
      // Show message that no further status changes are allowed
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Status Update'),
          content: const Text(
              'This feedback has been resolved and cannot be changed further.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Feedback Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableStatuses.map((status) {
            String displayText = status[0].toUpperCase() + status.substring(1);
            return ListTile(
              title: Text(displayText),
              onTap: () async {
                Navigator.pop(context);
                await _updateFeedbackStatus(feedback.id, status, null);
              },
            );
          }).toList(),
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
                  Icons.local_shipping, Colors.green.shade900),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard('Pending Apps', pendingApps.toString(),
                  Icons.person_add, Colors.green.shade300),
              const SizedBox(width: 12),
              _buildStatCard('Total Users', totalUsers.toString(), Icons.people,
                  Colors.green.shade500),
              const SizedBox(width: 12),
              _buildStatCard('Agents', agents.length.toString(),
                  Icons.support_agent, Colors.green),
              const SizedBox(width: 12),
              _buildStatCard('NGOs', ngos.length.toString(), Icons.business,
                  Colors.green.shade700),
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
    // Create unified list of all waste items with type information
    final allItems = <Map<String, dynamic>>[];

    // Add e-waste items
    for (final item in ewasteItems) {
      allItems.add({
        'type': 'e-waste',
        'item': item,
        'service': _ewasteService,
      });
    }

    // Add plastic items
    for (final item in plasticItems) {
      allItems.add({
        'type': 'plastic',
        'item': item,
        'service': _plasticService,
      });
    }

    // Add cloth items
    for (final item in clothItems) {
      allItems.add({
        'type': 'cloth',
        'item': item,
        'service': _clothService,
      });
    }

    // Sort by status and date
    allItems.sort((a, b) {
      final itemA = a['item'];
      final itemB = b['item'];
      final statusA = itemA.deliveryStatus ?? 'pending';
      final statusB = itemB.deliveryStatus ?? 'pending';

      final order = ['pending', 'assigned', 'collected', 'delivered'];
      final statusCompare =
          order.indexOf(statusA).compareTo(order.indexOf(statusB));
      if (statusCompare != 0) return statusCompare;

      // Then sort by created date (newest first)
      final dateA = itemA.createdAt ?? DateTime.now();
      final dateB = itemB.createdAt ?? DateTime.now();
      return dateB.compareTo(dateA);
    });

    // Filter items based on search query
    final filteredItems = allItems.where((itemData) {
      if (_searchQuery.isEmpty) return true;
      final item = itemData['item'];
      final type = itemData['type'] as String;
      final itemName = item.itemName?.toLowerCase() ?? '';
      final description = item.description?.toLowerCase() ?? '';
      final location = item.location?.toLowerCase() ?? '';
      final userName = userNames[item.userId]?.toLowerCase() ?? '';
      return itemName.contains(_searchQuery) ||
          description.contains(_searchQuery) ||
          location.contains(_searchQuery) ||
          userName.contains(_searchQuery) ||
          type.contains(_searchQuery);
    }).toList();

    if (filteredItems.isEmpty) {
      return _buildEmptyState('No waste items found', Icons.inventory);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final itemData = filteredItems[index];
        final type = itemData['type'] as String;
        final item = itemData['item'];
        final service = itemData['service'];
        final userName = userNames[item.userId] ?? 'Unknown';

        // Get type-specific colors and icons
        final typeColor = _getWasteTypeColor(type);
        final typeIcon = _getWasteTypeIcon(type);

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
                  // Header: Type Badge | Username | Item Name | Status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: typeColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(typeIcon, size: 14, color: typeColor),
                            const SizedBox(width: 4),
                            Text(
                              type.toUpperCase(),
                              style: TextStyle(
                                color: typeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Item Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.imageUrl != null && item.imageUrl.isNotEmpty
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
                                  child: Icon(typeIcon,
                                      size: 24, color: typeColor),
                                ),
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[200],
                                child:
                                    Icon(typeIcon, size: 24, color: typeColor),
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
                              item.itemName ?? 'Unnamed Item',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.description ?? 'No description',
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
                      _buildStatusBadge(item.deliveryStatus ?? 'pending'),
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
                          item.location ?? 'No location',
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
                  if ((item.deliveryStatus ?? 'pending') == 'pending' ||
                      (item.deliveryStatus ?? 'pending') == 'assigned')
                    Row(
                      children: [
                        // Assign to NGO
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final selectedNgo =
                                  await _showNgoSelectionDialog();
                              if (selectedNgo != null) {
                                await _assignWasteTask(
                                    itemData, null, selectedNgo);
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
                              final selectedVolunteer =
                                  await _showVolunteerSelectionForAssignment();
                              if (selectedVolunteer != null) {
                                await _assignWasteTask(
                                    itemData, selectedVolunteer, null);
                              }
                            },
                            icon: const Icon(Icons.person, size: 16),
                            label: const Text('Volunteer',
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
                            onPressed: () =>
                                _showWasteStatusChangeDialog(itemData),
                            icon: const Icon(Icons.trending_down, size: 16),
                            label: const Text('Status',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Schedule
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showScheduleDialog(itemData),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: const Text('Date',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
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
        return Colors.green.shade300;
      case 'assigned':
        return Colors.green.shade500;
      case 'collected':
        return Colors.green.shade700;
      case 'delivered':
        return Colors.green.shade900;
      default:
        return Colors.grey;
    }
  }

  Future<String?> _showAgentSelectionDialog() async {
    DateTime selectedDate = DateTime.now();
    List<String> availableAgentIds = [];

    // First, show date selection dialog
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate == null) return null;
    selectedDate = pickedDate;

    // Fetch available agents for the selected date
    try {
      availableAgentIds = await _scheduleService
          .getAvailableVolunteerIdsForDates([selectedDate]);
    } catch (e) {
      _showError('Error fetching agent availability: $e');
      // Fall back to showing all agents
      availableAgentIds = agents.map((a) => a.id).toList();
    }

    // Filter agents to only show available ones
    final availableAgents =
        agents.where((agent) => availableAgentIds.contains(agent.id)).toList();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Available Agent'),
            Text(
              'Date: ${DateFormat('MMM d, yyyy').format(selectedDate)}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: availableAgents.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No agents available on this date.\nTry selecting a different date.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableAgents.length,
                  itemBuilder: (context, index) {
                    final agent = availableAgents[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: const Icon(Icons.check_circle,
                              color: Colors.green),
                        ),
                        title: Text(agent.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(agent.phone),
                            Text(
                              'Available on ${DateFormat('MMM d').format(selectedDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => Navigator.pop(context, agent.id),
                      ),
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

  Future<String?> _showVolunteerSelectionForAssignment() async {
    final volunteers = allProfiles
        .where((profile) => (profile['user_role'] as String?) == 'volunteer')
        .toList();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Volunteer'),
        content: SizedBox(
          width: double.maxFinite,
          child: volunteers.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No volunteers available.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: volunteers.length,
                  itemBuilder: (context, index) {
                    final volunteer = volunteers[index];
                    final name = volunteer['full_name'] as String? ?? 'Unknown';
                    final email = volunteer['email'] as String? ?? '';
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: const Icon(Icons.person, color: Colors.orange),
                        ),
                        title: Text(name),
                        subtitle: Text(email),
                        onTap: () =>
                            Navigator.pop(context, volunteer['id'] as String),
                      ),
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

  Future<void> _showScheduleDialog(Map<String, dynamic> itemData) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      try {
        final service = itemData['service'] as dynamic;
        final item = itemData['item'];
        final itemId = item.id as String;

        await service.schedulePickup(itemId, pickedDate);
        fetchAllData();
        _showSuccess(
            'Pickup scheduled for ${DateFormat('MMM d, yyyy').format(pickedDate)}');
      } catch (e) {
        _showError('Failed to schedule pickup: $e');
      }
    }
  }

  Widget _buildVolunteerAppsTab(Color cardColor) {
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
            ? Colors.green.shade300
            : app.status == 'approved'
                ? Colors.green.shade700
                : Colors.green.shade500;
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
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_expandedVolunteerApps.contains(app.id)) {
                        _expandedVolunteerApps.remove(app.id);
                      } else {
                        _expandedVolunteerApps.add(app.id);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _expandedVolunteerApps.contains(app.id)
                                ? app.motivation
                                : (app.motivation.length > 100
                                    ? '${app.motivation.substring(0, 100)}...'
                                    : app.motivation),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _expandedVolunteerApps.contains(app.id)
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
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
                  Row(
                    children: [
                      Expanded(
                        child: Container(
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
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _confirmDeleteVolunteerApplication(app),
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Delete',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
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
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tab Bar
          Container(
            color: cardColor,
            child: const TabBar(
              tabs: [
                Tab(text: 'Assignments', icon: Icon(Icons.assignment)),
                Tab(text: 'Schedules', icon: Icon(Icons.calendar_today)),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              children: [
                _buildAssignmentsTab(cardColor),
                _buildSchedulesTab(cardColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTab(Color cardColor) {
    // Create unified list of all pending waste items for assignment
    final allPendingItems = <Map<String, dynamic>>[];

    // Add e-waste items
    for (final item in ewasteItems) {
      if (item.deliveryStatus == 'pending' ||
          item.deliveryStatus == 'assigned') {
        allPendingItems.add({
          'type': 'e-waste',
          'item': item,
          'service': _ewasteService,
        });
      }
    }

    // Add plastic items
    for (final item in plasticItems) {
      if (item.deliveryStatus == 'pending' ||
          item.deliveryStatus == 'assigned') {
        allPendingItems.add({
          'type': 'plastic',
          'item': item,
          'service': _plasticService,
        });
      }
    }

    // Add cloth items
    for (final item in clothItems) {
      if (item.deliveryStatus == 'pending' ||
          item.deliveryStatus == 'assigned') {
        allPendingItems.add({
          'type': 'cloth',
          'item': item,
          'service': _clothService,
        });
      }
    }

    // Sort by created date (newest first)
    allPendingItems.sort((a, b) {
      final itemA = a['item'];
      final itemB = b['item'];
      final dateA = itemA.createdAt ?? DateTime.now();
      final dateB = itemB.createdAt ?? DateTime.now();
      return dateB.compareTo(dateA);
    });

    if (allPendingItems.isEmpty) {
      return _buildEmptyState('No pending assignments', Icons.assignment);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allPendingItems.length,
      itemBuilder: (context, index) {
        final itemData = allPendingItems[index];
        final type = itemData['type'] as String;
        final item = itemData['item'];
        final userName = userNames[item.userId] ?? 'Unknown';

        final typeColor = _getWasteTypeColor(type);
        final typeIcon = _getWasteTypeIcon(type);

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
                // Header with type badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: typeColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 14, color: typeColor),
                          const SizedBox(width: 4),
                          Text(
                            type.toUpperCase(),
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
                          Text(
                            item.itemName ?? 'Unnamed Item',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(item.deliveryStatus ?? 'pending'),
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
                        item.location ?? 'No location',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Assignment Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showVolunteerAssignmentDialog(itemData),
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text('Assign Volunteer',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showLocationOnMap(item),
                        icon: const Icon(Icons.map, size: 16),
                        label: const Text('View Map',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
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

  Widget _buildSchedulesTab(Color cardColor) {
    if (allSchedules.isEmpty) {
      return _buildEmptyState('No volunteer schedules', Icons.calendar_today);
    }

    // Group schedules by date and count available volunteers
    final availabilityCounts = <DateTime, int>{};
    for (final schedule in allSchedules) {
      final date =
          DateTime(schedule.date.year, schedule.date.month, schedule.date.day);
      if (schedule.isAvailable) {
        availabilityCounts[date] = (availabilityCounts[date] ?? 0) + 1;
      }
    }

    return Column(
      children: [
        // Calendar view with availability counts
        Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final date = DateTime(day.year, day.month, day.day);
                  final count = availabilityCounts[date] ?? 0;
                  return Container(
                    margin: const EdgeInsets.all(4),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day.day.toString(),
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: isSameDay(day, DateTime.now())
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (count > 0)
                          Text(
                            count.toString(),
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  );
                },
                todayBuilder: (context, day, focusedDay) {
                  final date = DateTime(day.year, day.month, day.day);
                  final count = availabilityCounts[date] ?? 0;
                  return Container(
                    margin: const EdgeInsets.all(4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day.day.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (count > 0)
                          Text(
                            count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  );
                },
                selectedBuilder: (context, day, focusedDay) {
                  final date = DateTime(day.year, day.month, day.day);
                  final count = availabilityCounts[date] ?? 0;
                  return Container(
                    margin: const EdgeInsets.all(4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day.day.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (count > 0)
                          Text(
                            count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // List view of schedules (existing implementation)
        Expanded(
          child: _buildSchedulesListView(),
        ),
      ],
    );
  }

  Widget _buildSchedulesListView() {
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

  void _showVolunteerAssignmentDialog(Map<String, dynamic> itemData) async {
    final item = itemData['item'];
    final type = itemData['type'] as String;

    // Get available volunteers for today
    final today = DateTime.now();
    final availableSchedules = allSchedules.where((schedule) {
      final scheduleDate =
          DateTime(schedule.date.year, schedule.date.month, schedule.date.day);
      final todayDate = DateTime(today.year, today.month, today.day);
      return scheduleDate.isAtSameMomentAs(todayDate) && schedule.isAvailable;
    }).toList();

    if (availableSchedules.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Available Volunteers'),
          content: const Text(
              'No volunteers are available for pickup today. Please check volunteer schedules or try again tomorrow.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final selectedVolunteer = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Volunteer'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableSchedules.length,
            itemBuilder: (context, index) {
              final schedule = availableSchedules[index];
              final volunteerName =
                  userNames[schedule.volunteerId] ?? 'Unknown Volunteer';

              return ListTile(
                leading: const Icon(Icons.person, color: Colors.blue),
                title: Text(volunteerName),
                subtitle: Text('Available today'),
                onTap: () => Navigator.pop(context, schedule.volunteerId),
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

    if (selectedVolunteer != null) {
      await _createVolunteerAssignment(itemData, selectedVolunteer);
    }
  }

  Future<void> _createVolunteerAssignment(
      Map<String, dynamic> itemData, String volunteerId) async {
    try {
      final item = itemData['item'];
      final type = itemData['type'] as String;
      final service = itemData['service'] as dynamic;

      // Create assignment record in volunteer_assignments table
      final assignmentData = {
        'volunteer_id': volunteerId,
        'waste_item_id': item.id,
        'waste_type': type,
        'task_type': 'pickup_delivery',
        'scheduled_date': DateTime.now().toIso8601String().split('T')[0],
        'status': 'assigned',
        'notes': 'Assigned by admin for ${type} pickup',
        'assigned_at': DateTime.now().toIso8601String(),
      };

      await AppSupabase.client
          .from('volunteer_assignments')
          .insert(assignmentData);

      // Update the e-waste item status
      await service.assignPickupAgent(item.id, volunteerId);

      // Show contact sharing dialog
      await _showContactSharingDialog(item, volunteerId, type);

      fetchAllData();
      _showSuccess('Assignment created successfully! Volunteer notified.');
    } catch (e) {
      _showError('Failed to create assignment: $e');
    }
  }

  Future<void> _showContactSharingDialog(
      dynamic item, String volunteerId, String wasteType) async {
    final userName = userNames[item.userId] ?? 'User';
    final volunteerName = userNames[volunteerId] ?? 'Volunteer';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📞 Contact Information Shared'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ Assignment created for $wasteType pickup'),
            const SizedBox(height: 8),
            Text('👤 User: $userName'),
            Text('🚛 Volunteer: $volunteerName'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Text(
                '📱 Contact information has been shared between the user and volunteer for coordination.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLocationOnMap(dynamic item) {
    // This would integrate with Google Maps
    // For now, show a placeholder dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📍 Pickup Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Location: ${item.location ?? 'Not specified'}'),
            const SizedBox(height: 12),
            Container(
              height: 200,
              width: double.maxFinite,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('🗺️ Map Integration\nComing Soon'),
              ),
            ),
          ],
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

  Widget _buildUsersTab(Color cardColor) {
    final filteredProfiles = allProfiles.where((profile) {
      final role = (profile['user_role'] as String?) ?? '';
      if (role != 'user' && role != 'volunteer') return false;
      if (_searchQuery.isEmpty) return true;
      final fullName = (profile['full_name'] as String?)?.toLowerCase() ?? '';
      final email = (profile['email'] as String?)?.toLowerCase() ?? '';
      return fullName.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          role.toLowerCase().contains(_searchQuery);
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
        final phone = profile['phone_number'] as String? ?? '';
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
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmDeleteUser(userId!, fullName),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Delete User'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                        ),
                      ),
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
                              'Admin accounts cannot be deleted',
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

  Future<void> _changeUserRole(
      String userId, String newRole, String userName) async {
    await _showRoleChangeDialog(userId, newRole);
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
              _detailRow('Name', profile['full_name'] as String? ?? 'N/A'),
              _detailRow('Email', profile['email'] as String? ?? 'N/A'),
              _detailRow('Phone', profile['phone_number'] as String? ?? 'N/A'),
              _detailRow('Role',
                  _capitalizeFirst(profile['user_role'] as String? ?? 'user')),
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

  void _showFeedbackResponseDialog(FeedbackItem feedback) {
    final TextEditingController responseController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Respond to Feedback'),
        content: TextField(
          controller: responseController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Enter your response...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (responseController.text.trim().isNotEmpty) {
                await _feedbackService.respondToFeedback(
                  feedback.id,
                  responseController.text.trim(),
                );
                fetchAllData();
                _showSuccess('Response sent successfully');
                Navigator.pop(context);
              }
            },
            child: const Text('Send Response'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFeedbackStatus(
      String feedbackId, String status, String? adminResponse) async {
    try {
      await _feedbackService.updateFeedbackStatus(
          feedbackId, status, adminResponse);
      fetchAllData();
      _showSuccess('Feedback status updated');
    } catch (e) {
      _showError('Failed to update status: $e');
    }
  }

  Future<void> _confirmDeleteFeedback(FeedbackItem feedback) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Delete Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Are you sure you want to delete this feedback: "${feedback.subject}"?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red[300]!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '⚠️ This action CANNOT be undone. The feedback will be permanently deleted.',
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
              await _deleteFeedback(feedback.id, feedback.subject);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete Feedback'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFeedback(String feedbackId, String subject) async {
    try {
      print('🗑️ Attempting to delete feedback: $feedbackId');
      await _feedbackService.deleteFeedback(feedbackId);
      print('✅ Feedback deleted successfully');
      _showSuccess('Feedback deleted successfully');
      await fetchAllData();
    } catch (e) {
      print('❌ Failed to delete feedback: $e');
      _showError('Failed to delete feedback: $e');
    }
  }

  Future<void> _confirmDeleteVolunteerApplication(
      VolunteerApplication app) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Delete Volunteer Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Are you sure you want to delete the application from ${app.fullName}?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red[300]!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '⚠️ This action CANNOT be undone. The volunteer application will be permanently deleted.',
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
              await _deleteVolunteerApplication(app.id, app.fullName);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete Application'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVolunteerApplication(
      String appId, String fullName) async {
    try {
      await _profileService.deleteVolunteerApplication(appId);
      _showSuccess('Volunteer application deleted successfully');
      await fetchAllData();
    } catch (e) {
      _showError('Failed to delete volunteer application: $e');
    }
  }

  // Helper methods for unified waste management
  Color _getWasteTypeColor(String type) {
    switch (type) {
      case 'e-waste':
        return Colors.green.shade300;
      case 'plastic':
        return Colors.green.shade500;
      case 'cloth':
        return Colors.green.shade700;
      default:
        return Colors.grey;
    }
  }

  IconData _getWasteTypeIcon(String type) {
    switch (type) {
      case 'e-waste':
        return Icons.devices;
      case 'plastic':
        return Icons.recycling;
      case 'cloth':
        return Icons.checkroom;
      default:
        return Icons.inventory;
    }
  }

  Future<void> _assignWasteTask(
      Map<String, dynamic> itemData, String? agentId, String? ngoId) async {
    try {
      final service = itemData['service'] as dynamic;
      final item = itemData['item'];
      final itemId = item.id as String;
      final userName = userNames[item.userId] ?? 'Unknown User';

      if (agentId != null) {
        await service.assignPickupAgent(itemId, agentId);

        // Get agent name for success message
        final agent = agents.firstWhere((a) => a.id == agentId);
        _showSuccess(
            '✅ Task assigned successfully to ${agent.name}!\nItem: ${item.itemName}\nCustomer: $userName');
      }
      if (ngoId != null) {
        await service.assignNgo(itemId, ngoId);

        // Get NGO name for success message
        final ngo = ngos.firstWhere((n) => n.id == ngoId);
        _showSuccess(
            '✅ Task assigned successfully to ${ngo.name}!\nItem: ${item.itemName}\nCustomer: $userName');
      }
      fetchAllData();
    } catch (e) {
      _showError('Assignment failed: $e');
    }
  }

  void _showWasteStatusChangeDialog(Map<String, dynamic> itemData) {
    final service = itemData['service'] as dynamic;
    final item = itemData['item'];

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
                await _updateWasteStatus(itemData, 'assigned');
              },
            ),
            ListTile(
              title: const Text('Collected'),
              onTap: () async {
                Navigator.pop(context);
                await _updateWasteStatus(itemData, 'collected');
              },
            ),
            ListTile(
              title: const Text('Delivered'),
              onTap: () async {
                Navigator.pop(context);
                await _updateWasteStatus(itemData, 'delivered');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateWasteStatus(
      Map<String, dynamic> itemData, String newStatus) async {
    try {
      final service = itemData['service'] as dynamic;
      final item = itemData['item'];
      final itemId = item.id as String;

      if (newStatus == 'collected') {
        await service.markAsCollected(itemId);
      }
      if (newStatus == 'delivered') {
        await service.markAsDelivered(itemId);
      }
      fetchAllData();
      _showSuccess('Status updated to ${newStatus.toUpperCase()}');
    } catch (e) {
      _showError('Update failed: $e');
    }
  }
}

class AddNgoDialog extends StatefulWidget {
  const AddNgoDialog({super.key});

  @override
  State<AddNgoDialog> createState() => _AddNgoDialogState();
}

class _AddNgoDialogState extends State<AddNgoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _districtController = TextEditingController();
  final _addressController = TextEditingController();
  final _wasteTypesController = TextEditingController();
  final _contactInfoController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _districtController.dispose();
    _addressController.dispose();
    _wasteTypesController.dispose();
    _contactInfoController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final ngo = Ngo(
        id: '', // Will be generated by database
        name: _nameController.text,
        district: _districtController.text,
        address: _addressController.text,
        wasteTypes: _wasteTypesController.text.isEmpty
            ? null
            : _wasteTypesController.text
                .split(',')
                .map((e) => e.trim())
                .toList(),
        contactInfo: _contactInfoController.text.isEmpty
            ? null
            : _contactInfoController.text,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      Navigator.pop(context, ngo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add NGO'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'NGO Name *'),
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _districtController,
                decoration: const InputDecoration(labelText: 'District *'),
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address *'),
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _wasteTypesController,
                decoration: const InputDecoration(
                    labelText: 'Waste Types Accepted (comma separated)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactInfoController,
                decoration: const InputDecoration(labelText: 'Contact Info'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add NGO'),
        ),
      ],
    );
  }
}

class EditNgoDialog extends StatefulWidget {
  final Ngo ngo;

  const EditNgoDialog({super.key, required this.ngo});

  @override
  State<EditNgoDialog> createState() => _EditNgoDialogState();
}

class _EditNgoDialogState extends State<EditNgoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _districtController;
  late final TextEditingController _addressController;
  late final TextEditingController _wasteTypesController;
  late final TextEditingController _contactInfoController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ngo.name);
    _districtController = TextEditingController(text: widget.ngo.district);
    _addressController = TextEditingController(text: widget.ngo.address);
    _wasteTypesController =
        TextEditingController(text: widget.ngo.wasteTypes?.join(', '));
    _contactInfoController =
        TextEditingController(text: widget.ngo.contactInfo);
    _phoneController = TextEditingController(text: widget.ngo.phone);
    _emailController = TextEditingController(text: widget.ngo.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _districtController.dispose();
    _addressController.dispose();
    _wasteTypesController.dispose();
    _contactInfoController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final updatedNgo = Ngo(
        id: widget.ngo.id,
        name: _nameController.text,
        district: _districtController.text,
        address: _addressController.text,
        wasteTypes: _wasteTypesController.text.isEmpty
            ? null
            : _wasteTypesController.text
                .split(',')
                .map((e) => e.trim())
                .toList(),
        contactInfo: _contactInfoController.text.isEmpty
            ? null
            : _contactInfoController.text,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        isGovernmentApproved: widget.ngo.isGovernmentApproved,
        latitude: widget.ngo.latitude,
        longitude: widget.ngo.longitude,
        createdAt: widget.ngo.createdAt,
        updatedAt: DateTime.now(),
      );
      Navigator.pop(context, updatedNgo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit NGO'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'NGO Name *'),
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _districtController,
                decoration: const InputDecoration(labelText: 'District *'),
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address *'),
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _wasteTypesController,
                decoration: const InputDecoration(
                    labelText: 'Waste Types Accepted (comma separated)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactInfoController,
                decoration: const InputDecoration(labelText: 'Contact Info'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Update NGO'),
        ),
      ],
    );
  }
}
