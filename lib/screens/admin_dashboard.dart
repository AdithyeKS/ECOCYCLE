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
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'delivered_items_screen.dart';

enum AdminTab { dashboard, schedule, volunteerApps, users, ngo, feedback }

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
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
  Map<String, String> userEmails = {};
  List<Map<String, dynamic>> allProfiles = [];
  bool isLoading = true;

  // Logistics tab state
  Map<String, dynamic>? selectedWasteItem;
  DateTime selectedDate = DateTime.now();
  List<VolunteerSchedule> availableVolunteers = [];
  final Map<String, bool> _loadingStates = {}; // Track loading state per item
  List<Map<String, dynamic>> pendingAssignments = [];

  // Optimized lists to prevent re-calculation on every build
  final List<Map<String, dynamic>> _allPendingItems = [];
  List<Map<String, dynamic>> _filteredPendingItems = [];
  final List<Map<String, dynamic>> _allAssignedItems = [];
  List<Map<String, dynamic>> _filteredProfiles = [];
  List<FeedbackItem> _filteredFeedbackItems = [];

  // Memoized stats and schedule data
  Map<String, int> _dashboardStats = {};
  final Map<DateTime, int> _availabilityCounts = {};
  final Map<DateTime, List<VolunteerSchedule>> _volunteersByDate = {};
  Timer? _debounce;

  void _processData() {
    _allPendingItems.clear();
    _allAssignedItems.clear();

    // Helper to process items
    void processItems(List<dynamic> items, String type, dynamic service) {
      for (var item in items) {
        final entry = {
          'type': type,
          'item': item,
          'service': service,
        };

        if (item.deliveryStatus == 'pending') {
          _allPendingItems.add(entry);
        } else if (item.deliveryStatus == 'assigned') {
          _allAssignedItems.add(entry);
        }
      }
    }

    processItems(ewasteItems, 'e-waste', _ewasteService);
    processItems(plasticItems, 'plastic', _plasticService);
    processItems(clothItems, 'cloth', _clothService);

    // Memoize Dashboard Stats
    final pendingVolunteerRequests =
        volunteerApps.where((app) => app.status == 'pending').length;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final availableVolunteersToday = allSchedules.where((schedule) {
      final scheduleDate =
          DateTime(schedule.date.year, schedule.date.month, schedule.date.day);
      return scheduleDate.isAtSameMomentAs(todayDate) && schedule.isAvailable;
    }).length;

    final pendingPickupRequests =
        ewasteItems.where((i) => i.deliveryStatus == 'pending').length +
            plasticItems.where((i) => i.deliveryStatus == 'pending').length +
            clothItems.where((i) => i.deliveryStatus == 'pending').length;

    final deliveredItemsCount =
        ewasteItems.where((i) => i.deliveryStatus == 'delivered').length +
            plasticItems.where((i) => i.deliveryStatus == 'delivered').length +
            clothItems.where((i) => i.deliveryStatus == 'delivered').length;

    _dashboardStats = {
      'pendingVolunteerRequests': pendingVolunteerRequests,
      'availableVolunteersToday': availableVolunteersToday,
      'pendingPickupRequests': pendingPickupRequests,
      'deliveredItemsCount': deliveredItemsCount,
    };

    // Memoize Schedule Availability
    _availabilityCounts.clear();
    _volunteersByDate.clear();

    for (final schedule in allSchedules) {
      final date =
          DateTime(schedule.date.year, schedule.date.month, schedule.date.day);
      if (schedule.isAvailable) {
        _availabilityCounts[date] = (_availabilityCounts[date] ?? 0) + 1;
        _volunteersByDate[date] = (_volunteersByDate[date] ?? [])
          ..add(schedule);
      }
    }
  }

  void _updateFilteredLists() {
    setState(() {
      _filteredPendingItems = _filterList(_allPendingItems);
      _filteredProfiles = _filterProfiles(allProfiles);
      _filteredFeedbackItems = _filterFeedback(feedbackItems);
    });
  }

  List<Map<String, dynamic>> _filterProfiles(
      List<Map<String, dynamic>> profiles) {
    return profiles.where((profile) {
      final role = (profile['user_role'] as String?) ?? '';

      // Exclude admin users from the user management list
      if (role == 'admin') return false;

      // Apply search query filtering if present
      if (_searchQuery.isEmpty) return true;
      final fullName = (profile['full_name'] as String?)?.toLowerCase() ?? '';
      final email = (profile['email'] as String?)?.toLowerCase() ?? '';
      return fullName.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          role.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  List<FeedbackItem> _filterFeedback(List<FeedbackItem> items) {
    if (_searchQuery.isEmpty) return List.from(items);

    return items.where((feedback) {
      final subject = feedback.subject.toLowerCase();
      final message = feedback.message.toLowerCase();
      final userEmail = feedback.userEmail?.toLowerCase() ?? '';
      final category = feedback.category.toLowerCase();
      return subject.contains(_searchQuery) ||
          message.contains(_searchQuery) ||
          userEmail.contains(_searchQuery) ||
          category.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> _filterList(List<Map<String, dynamic>> items) {
    if (_searchQuery.isEmpty) return List.from(items);

    return items.where((itemData) {
      final item = itemData['item'];
      final wasteType = itemData['type'] as String;
      // For cloth items, use 'type' field; for others, use 'itemName'
      final itemName = (wasteType == 'cloth')
          ? (item.type?.toLowerCase() ?? '')
          : (item.itemName?.toLowerCase() ?? '');
      final description = _getItemDescription(item, wasteType).toLowerCase();
      final location = item.location?.toLowerCase() ?? '';
      final userName = userNames[item.userId]?.toLowerCase() ?? '';
      final userEmail = userEmails[item.userId]?.toLowerCase() ?? '';

      return itemName.contains(_searchQuery) ||
          description.contains(_searchQuery) ||
          location.contains(_searchQuery) ||
          userName.contains(_searchQuery) ||
          userEmail.contains(_searchQuery) ||
          wasteType.contains(_searchQuery);
    }).toList();
  }

  // Mobile app state
  AdminTab _selectedTab = AdminTab.dashboard;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // Default to light mode until preference is loaded
  bool _isDarkMode = false;
  final bool _canPop = false;
  // Calendar state for schedules tab
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Tab controller for schedule tabs
  late TabController _scheduleTabController;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _selectedDay = DateTime.now();
    _focusedDay = _selectedDay!;
    _scheduleTabController = TabController(length: 2, vsync: this);
    _pageController =
        PageController(initialPage: AdminTab.values.indexOf(_selectedTab));
    _searchController.addListener(_onSearchChanged);
    fetchAllData();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
          _updateFilteredLists();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scheduleTabController.dispose();
    _pageController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isDarkMode = prefs.getBool('admin_dark_mode') ?? false;
        });
      }
    } catch (e) {
      // print(...);
    }
  }

  Future<void> _toggleTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDarkMode = !_isDarkMode;
      });
      await prefs.setBool('admin_dark_mode', _isDarkMode);
    } catch (e) {
      // print(...);
    }
  }

  // UPDATED: Centralized and parallel data fetching for reliability
  Future<void> fetchAllData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      // print(...);

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
        // print(...);
      }
      if (results[3] is Exception) {
        // print(...);
      }

      // print(...);
      // print(...);
      // print(...);
      // print(...);
      // print(...);
      // print(...);
      // print(...);
      // print(...);
      // print(...);

      // Convert maps to Profile objects
      final List<Profile> profiles =
          profileMaps.map((map) => Profile.fromJson(map)).toList();

      // Create a map for quick name and email lookups by ID
      final Map<String, String> namesMap = {};
      final Map<String, String> emailsMap = {};
      for (final profile in profiles) {
        final id = profile.id;
        final fullName = profile.fullName;
        final email = profile.email;
        if (id.isNotEmpty) {
          if (fullName != null) namesMap[id] = fullName;
          if (email != null) emailsMap[id] = email;
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
        userEmails = emailsMap;
        allProfiles = profileMaps;
        volunteerApps = apps;
        allSchedules = schedules;
        feedbackItems = feedbacks;

        // Process and filter data
        _processData();
        _filteredPendingItems = _filterList(_allPendingItems);
        _filteredProfiles = _filterProfiles(allProfiles);
        _filteredFeedbackItems = _filterFeedback(feedbackItems);

        isLoading = false;
      });
      // print(...);
    } catch (e) {
      setState(() => isLoading = false);
      // print(...);
      _showError('Failed to synchronize data: $e');
    }
  }

  // --- Actions ---

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

  Future<bool> _onWillPop() async {
    // Show confirmation dialog when user tries to go back
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: _isDarkMode
            ? ThemeData.dark().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Color(0xFF1a1f3a)),
              )
            : ThemeData.light().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Colors.white),
                colorScheme: ColorScheme.light(
                  primary: Colors.green.shade800,
                  surface: Colors.white,
                  surfaceTint: Colors.transparent,
                ),
              ),
        child: AlertDialog(
          title: const Text('Exit Admin Dashboard?'),
          content: const Text(
            'Are you sure you want to exit the admin dashboard? You will need to log in again to access admin features.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Exit', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    final bgColor =
        _isDarkMode ? const Color(0xFF0a0e27) : const Color(0xFFF8FAFC);
    final cardColor = _isDarkMode ? const Color(0xFF1a1f3a) : Colors.white;

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_selectedTab != AdminTab.dashboard) {
          _pageController.animateToPage(
            AdminTab.dashboard.index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          return;
        }

        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          // Use SystemNavigator.pop() to close the app completely and avoid black screen
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _isDarkMode ? const Color(0xFF1a1f3a) : Colors.white,
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
              onPressed: _toggleTheme,
            ),
            IconButton(
              icon: Icon(Icons.logout,
                  color: _isDarkMode ? Colors.white : Colors.black),
              onPressed: _logout,
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Search Bar
                if (_selectedTab != AdminTab.dashboard)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: _isDarkMode ? const Color(0xFF1a1f3a) : Colors.white,
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black87,
                      ),
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
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _selectedTab = AdminTab.values[index]);
                    },
                    children: [
                      _buildDashboardTab(cardColor),
                      _buildScheduleTab(cardColor),
                      _buildVolunteerAppsTab(cardColor),
                      _buildUsersTab(cardColor),
                      _buildNgoManagementTab(cardColor),
                      _buildFeedbackTab(cardColor),
                    ],
                  ),
                ),
              ],
            ),
            if (isLoading)
              Container(
                color: Colors.black12,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
        bottomNavigationBar: _buildModernBottomNavBar(),
      ),
    );
  }

  Widget _buildModernBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1a1f3a) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: AdminTab.values.map((tab) {
              final isSelected = _selectedTab == tab;
              return GestureDetector(
                onTap: () {
                  _pageController.jumpToPage(tab.index);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.transparent, // No background
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getTabIcon(tab),
                        color: isSelected
                            ? Colors.green
                            : (_isDarkMode ? Colors.grey : Colors.grey[600]),
                        size: 24,
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 4),
                        Text(
                          _getTabTitleForNav(tab),
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  IconData _getTabIcon(AdminTab tab) {
    switch (tab) {
      case AdminTab.dashboard:
        return Icons.dashboard;
      case AdminTab.schedule:
        return Icons.local_shipping;
      case AdminTab.volunteerApps:
        return Icons.person_add;
      case AdminTab.users:
        return Icons.people;
      case AdminTab.ngo:
        return Icons.business;
      case AdminTab.feedback:
        return Icons.feedback;
    }
  }

  String _getTabTitleForNav(AdminTab tab) {
    switch (tab) {
      case AdminTab.dashboard:
        return 'Home';
      case AdminTab.schedule:
        return 'Dispatch';
      case AdminTab.volunteerApps:
        return 'Approve';
      case AdminTab.users:
        return 'Users';
      case AdminTab.ngo:
        return 'NGOs';
      case AdminTab.feedback:
        return 'Feedback';
    }
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

  Widget _buildDashboardTab(Color cardColor) {
    // Use memoized stats
    final pendingVolunteerRequests =
        _dashboardStats['pendingVolunteerRequests'] ?? 0;
    final availableVolunteersToday =
        _dashboardStats['availableVolunteersToday'] ?? 0;
    final pendingPickupRequests = _dashboardStats['pendingPickupRequests'] ?? 0;
    final deliveredItemsCount = _dashboardStats['deliveredItemsCount'] ?? 0;

    return RefreshIndicator(
      onRefresh: fetchAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: _buildHeader(),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Quick Stats',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
              ).animate().fadeIn().slideX(),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.9,
                    children: [
                      // 1. Pending Requests (Red)
                      _buildModernStatCard(
                        'Pending Requests',
                        pendingPickupRequests.toString(),
                        Icons.pending_actions,
                        [Colors.red.shade400, Colors.red.shade700],
                        onTap: () {
                          setState(() {
                            _scheduleTabController.index = 0;
                          });
                          _pageController.animateToPage(
                            AdminTab.schedule.index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                      // 2. Pending Volunteers (Orange)
                      _buildModernStatCard(
                        'Pending Volunteers',
                        pendingVolunteerRequests.toString(),
                        Icons.person_add,
                        [Colors.orange.shade400, Colors.orange.shade700],
                        onTap: () => _pageController.animateToPage(
                          AdminTab.volunteerApps.index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      ),
                      // 3. Available Volunteers (Teal)
                      _buildModernStatCard(
                        'Available Volunteers',
                        availableVolunteersToday.toString(),
                        Icons.directions_run,
                        [Colors.teal.shade400, Colors.teal.shade700],
                        onTap: () {
                          setState(() {
                            _scheduleTabController.index = 1;
                          });
                          _pageController.animateToPage(
                            AdminTab.schedule.index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                      // 4. Delivered Items (Blue - New)
                      _buildModernStatCard(
                        'Delivered Items',
                        deliveredItemsCount.toString(),
                        Icons.done_all,
                        [Colors.blue.shade400, Colors.blue.shade700],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DeliveredItemsScreen(
                                ewasteItems: ewasteItems,
                                plasticItems: plasticItems,
                                clothItems: clothItems,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Analytics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
              ).animate().fadeIn().slideX(),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildWastePieChart(cardColor)
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'App Version 1.0.0',
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, d MMMM y').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formattedDate.toUpperCase(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Welcome back, ',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              'Admin',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideX();
  }

  Widget _buildModernStatCard(
      String title, String value, IconData icon, List<Color> gradientColors,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                icon,
                size: 100,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
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

  Widget _buildWastePieChart(Color cardColor) {
    final ewasteCount = ewasteItems.length;
    final plasticCount = plasticItems.length;
    final clothCount = clothItems.length;
    final total = ewasteCount + plasticCount + clothCount;

    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: _isDarkMode
              ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: _isDarkMode
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: _isDarkMode ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            "No pickup requests data yet.",
            style:
                TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: _isDarkMode
            ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: _isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: _isDarkMode ? 20 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Waste Distribution',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isDarkMode
                      ? Colors.grey.withValues(alpha: 0.2)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Total: $total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          color: Colors.blueAccent,
                          value: ewasteCount.toDouble(),
                          title: '${((ewasteCount / total) * 100).toInt()}%',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: Colors.redAccent,
                          value: plasticCount.toDouble(),
                          title: '${((plasticCount / total) * 100).toInt()}%',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: Colors.amber,
                          value: clothCount.toDouble(),
                          title: '${((clothCount / total) * 100).toInt()}%',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem(
                          'E-Waste', Colors.blueAccent, ewasteCount),
                      const SizedBox(height: 12),
                      _buildLegendItem(
                          'Plastic', Colors.redAccent, plasticCount),
                      const SizedBox(height: 12),
                      _buildLegendItem('Cloth', Colors.amber, clothCount),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: _isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const Spacer(),
        Text(
          count.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleTab(Color cardColor) {
    return Column(
      children: [
        // Tab Bar
        Container(
          color: cardColor,
          child: TabBar(
            controller: _scheduleTabController,
            tabs: const [
              Tab(text: 'Pending Requests', icon: Icon(Icons.assignment)),
              Tab(text: 'Schedules', icon: Icon(Icons.calendar_today)),
            ],
          ),
        ),
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _scheduleTabController,
            children: [
              _buildPendingWasteSection(),
              _buildSchedulesTab(cardColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingWasteSection() {
    // Use the memoized filtered items list
    final filteredItems = _filteredPendingItems;

    if (filteredItems.isEmpty) {
      return _buildEmptyState('No pending requests found', Icons.assignment);
    }

    return RefreshIndicator(
      onRefresh: fetchAllData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: filteredItems.length,
        itemBuilder: (context, index) {
          final itemData = filteredItems[index];
          final item = itemData['item'];
          final type = itemData['type'];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: _isDarkMode ? 8 : 3,
            color: _isDarkMode ? const Color(0xFF1a1f3a) : Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: _isDarkMode
                  ? BorderSide(
                      color: Colors.white.withValues(alpha: 0.1), width: 1)
                  : BorderSide.none,
            ),
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
                              child: CachedNetworkImage(
                                imageUrl: item.imageUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                memCacheHeight: 200,
                                placeholder: (context, url) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image,
                                      color: Colors.grey),
                                ),
                                errorWidget: (context, url, error) =>
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
                              '${type.toUpperCase()}: ${_getItemDisplayName(item, type)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color:
                                    _isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getItemDescription(item, type),
                              style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Created by: ${userNames[item.userId] ?? 'Unknown User'}',
                              style: TextStyle(
                                color: _isDarkMode
                                    ? Colors.blue[300]
                                    : Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 16,
                          color: _isDarkMode ? Colors.grey[400] : Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.location ?? 'Unknown location',
                          style: TextStyle(
                              color: _isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600]),
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
                          color: Colors.blue.withValues(alpha: 0.1),
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
                        onPressed: (_loadingStates[
                                    itemData['item'].id.toString()] ??
                                false)
                            ? null
                            : () {
                                // Validation: Check if item already has an assigned volunteer
                                if (item.assignedAgentId != null &&
                                    item.assignedAgentId!.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.orange,
                                      duration: const Duration(seconds: 4),
                                      content: const Text(
                                        '⚠️ This item already has an assigned volunteer. Only one volunteer can be assigned per item.',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                _showVolunteerSelectionDialog(
                                    itemData, _selectedDay!);
                              },
                        icon: (_loadingStates[itemData['item'].id.toString()] ??
                                false)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.schedule),
                        label: Text(
                            (_loadingStates[itemData['item'].id.toString()] ??
                                    false)
                                ? 'Loading...'
                                : 'Schedule'),
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
      ),
    );
  }

  Ngo? _findClosestNgoByLocation(String userLocation) {
    if (userLocation.isEmpty || ngos.isEmpty) return null;

    final userLoc = userLocation.toLowerCase().trim();
    Ngo? closestNgo;
    int bestMatchLength = 0;

    // Find NGO with location that best matches user's location
    for (final ngo in ngos) {
      final ngoLocation = (ngo.address).toLowerCase().trim();

      // Check if NGO location contains user's location or vice versa
      if (userLoc.isNotEmpty && ngoLocation.isNotEmpty) {
        // Look for substring matches (indicating same area/district)
        final userParts = userLoc.split(',');
        final ngoParts = ngoLocation.split(',');

        // Count matching location parts
        int matchCount = 0;
        for (final userPart in userParts) {
          for (final ngoPart in ngoParts) {
            if (userPart.trim() == ngoPart.trim()) {
              matchCount++;
            }
          }
        }

        if (matchCount > bestMatchLength) {
          bestMatchLength = matchCount;
          closestNgo = ngo;
        }
      }
    }

    // If no location match, return first NGO as fallback
    return closestNgo ?? ngos.first;
  }

  /// Calculate location match score between user location and volunteer address
  /// Returns a score (higher = better match) based on matching address parts
  int _calculateLocationMatchScore(
      String userLocation, String volunteerAddress) {
    if (userLocation.isEmpty || volunteerAddress.isEmpty) return 0;

    final userLoc = userLocation.toLowerCase().trim();
    final volLoc = volunteerAddress.toLowerCase().trim();

    // Split by comma to get address parts (e.g., "Street, City, State")
    final userParts = userLoc
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final volParts = volLoc
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    // Count matching parts
    int matchCount = 0;
    for (final userPart in userParts) {
      for (final volPart in volParts) {
        if (userPart == volPart) {
          matchCount++;
        }
      }
    }

    return matchCount;
  }

  void _showVolunteerSelectionDialog(
      Map<String, dynamic> itemData, DateTime date) async {
    final currentContext = context; // Store context to avoid async gap issues
    final itemId = itemData['item'].id.toString();
    final item = itemData['item'];

    setState(() => _loadingStates[itemId] = true);

    try {
      // Fetch volunteer schedules for today only
      final now = DateTime.now();

      final availableSchedules = await AppSupabase.client
          .from('volunteer_schedules')
          .select('volunteer_id, date, is_available')
          .eq('date', now.toIso8601String().split('T')[0])
          .eq('is_available', true);

      // Group schedules by volunteer and collect their available dates (only Today now)
      final Map<String, List<DateTime>> volunteerDates = {};
      for (final record in (availableSchedules as List)) {
        final volunteerId = record['volunteer_id'] as String;
        final dateStr = record['date'] as String;
        final dateTime = DateTime.parse(dateStr);

        if (!volunteerDates.containsKey(volunteerId)) {
          volunteerDates[volunteerId] = [];
        }
        volunteerDates[volunteerId]!.add(dateTime);
      }

      debugPrint(
          'DEBUG: Today\'s Schedule fetch result: ${availableSchedules.length} records');
      // print(...);

      // Get volunteer profiles - no location filtering
      final volunteersWithDates = <Map<String, dynamic>>[];
      for (final profile in allProfiles) {
        final userId = profile['id'] as String?;
        final userRole = profile['user_role'] as String?;

        // Check if volunteer has availability
        if (userId != null &&
            volunteerDates.containsKey(userId) &&
            (userRole == 'volunteer' || userRole == 'agent')) {
          // Sort volunteer's available dates
          volunteerDates[userId]!.sort();

          volunteersWithDates.add({
            'volunteer': PickupAgent(
              id: userId,
              name: profile['full_name'] ?? 'Unknown',
              phone: profile['phone_number'] ?? '',
              email: profile['email'] ?? '',
              isActive: true,
              currentLatitude: null,
              currentLongitude: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            'availableDates': volunteerDates[userId]!,
            'address': profile['address'] as String? ?? '',
          });
        }
      }

      // print(...);
      // print(...);

      // Populate task counts and location match scores
      final userLocation = item.location ?? '';
      for (var volData in volunteersWithDates) {
        final volunteer = volData['volunteer'] as PickupAgent;

        // Strictly fetch count for TODAY
        final countDate = DateTime.now();
        final count = await _scheduleService
            .getAssignmentCountForVolunteerOnDate(volunteer.id, countDate);
        volData['taskCount'] = count;

        // Calculate proximity score
        final volunteerAddress = volData['address'] as String? ?? '';
        final matchScore =
            _calculateLocationMatchScore(userLocation, volunteerAddress);
        volData['matchScore'] = matchScore;
      }

      setState(() => _loadingStates[itemId] = false);

      if (volunteersWithDates.isEmpty) {
        if (!context.mounted) return;
        showDialog(
          context: currentContext,
          builder: (context) => AlertDialog(
            title: const Text('No Available Volunteers'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No volunteers have set their availability for upcoming dates.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Debug Info:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey[700]),
                  ),
                  Text(
                    'Volunteers with schedules: ${volunteerDates.length}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  Text(
                    'Total user profiles: ${allProfiles.length}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Make sure volunteers have:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const Text('• Marked dates as available in their dashboard',
                      style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
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

      // Sort volunteers by proximity score (descending), then by earliest available date
      volunteersWithDates.sort((a, b) {
        final scoreA = a['matchScore'] as int? ?? 0;
        final scoreB = b['matchScore'] as int? ?? 0;

        // Sort by match score (higher score = closer)
        return scoreB.compareTo(scoreA); // Descending order
      });

      // Check if item is already assigned - this is a safety check
      if (item.assignedAgentId != null && item.assignedAgentId!.isNotEmpty) {
        if (!context.mounted) return;
        showDialog(
          context: currentContext,
          builder: (context) => AlertDialog(
            title: const Text('Cannot Assign Volunteer'),
            content: const Text(
              'This item already has an assigned volunteer. Only one volunteer can be assigned per item.\n\nTo assign a different volunteer, you must first unassign the current one.',
            ),
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

      // Map to track selected volunteer and date - only one volunteer can be selected at a time
      String? selectedVolunteerId;
      DateTime? selectedDate;

      showDialog(
        context: context.mounted ? currentContext : context,
        builder: (context) {
          // Define state variables HERE, outside the builder function to persist across rebuilds
          Map<String, int> dateTaskCounts = {};
          bool isLoadingCounts = false;

          return Theme(
            data: _isDarkMode
                ? ThemeData.dark().copyWith(
                    dialogTheme: const DialogThemeData(
                        backgroundColor: Color(0xFF1a1f3a)),
                  )
                : ThemeData.light().copyWith(
                    dialogTheme:
                        const DialogThemeData(backgroundColor: Colors.white),
                    colorScheme: ColorScheme.light(
                      primary: Colors.green.shade800,
                      surface: Colors.white,
                      surfaceTint: Colors.transparent,
                    ),
                  ),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                Future<void> updateCountsForDate(DateTime date) async {
                  setDialogState(() => isLoadingCounts = true);
                  try {
                    final Map<String, int> newCounts = {};
                    for (var volData in volunteersWithDates) {
                      final volId = (volData['volunteer'] as PickupAgent).id;
                      final count = await _scheduleService
                          .getAssignmentCountForVolunteerOnDate(volId, date);
                      newCounts[volId] = count;
                    }
                    setDialogState(() {
                      dateTaskCounts = newCounts;
                      isLoadingCounts = false;
                    });
                    debugPrint(
                        'DEBUG: Dialog counts updated for date $date: $newCounts');
                  } catch (e) {
                    debugPrint('DEBUG: Error in updateCountsForDate: $e');
                    setDialogState(() => isLoadingCounts = false);
                  }
                }

                // Fetch initial counts if a date is already selected
                if (selectedDate != null &&
                    dateTaskCounts.isEmpty &&
                    !isLoadingCounts) {
                  // Use Future.microtask to avoid calling setState during build
                  Future.microtask(() => updateCountsForDate(selectedDate!));
                }

                return Dialog(
                  backgroundColor: Colors.transparent,
                  child: Container(
                    width: 500,
                    height: 650,
                    decoration: BoxDecoration(
                      color:
                          _isDarkMode ? const Color(0xFF1a1f3a) : Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.fromLTRB(28, 28, 20, 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Schedule Pickup',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: _isDarkMode
                                            ? Colors.greenAccent
                                            : const Color(0xFF1B5E20),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Select a volunteer and available date',
                                      style: TextStyle(
                                        color: _isDarkMode
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (isLoadingCounts)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: LinearProgressIndicator(
                                          backgroundColor: Colors.green
                                              .withValues(alpha: 0.1),
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                  Color>(Colors.green),
                                          minHeight: 2,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _isDarkMode
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.close,
                                      size: 20,
                                      color: _isDarkMode
                                          ? Colors.white
                                          : Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // Volunteers List
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              if (isLoadingCounts) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const CircularProgressIndicator(
                                        strokeWidth: 3,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.green),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Verifying capacity...',
                                        style: TextStyle(
                                          color: _isDarkMode
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // Pre-filter volunteers who reached the limit for the CURRENTLY selected date
                              // (if no date is selected, we use the initial today/first-date counts)
                              final filteredVolunteers =
                                  volunteersWithDates.where((volData) {
                                final volunteer =
                                    volData['volunteer'] as PickupAgent;
                                final isVolunteerSelected =
                                    selectedVolunteerId == volunteer.id;

                                // Logic: If a date is selected, check count for THAT date.
                                // If NO date selected yet, check the initial count we fetched.
                                final taskCount = selectedDate != null
                                    ? (dateTaskCounts[volunteer.id] ?? 0)
                                    : (volData['taskCount'] as int? ?? 0);

                                // Rule: Hide if limit reached AND not currently selected
                                // (If they are selected, we keep them visible so the user can see what they selected)
                                return !(taskCount >= 2 &&
                                    !isVolunteerSelected);
                              }).toList();

                              if (filteredVolunteers.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_off_rounded,
                                          size: 64, color: Colors.grey[400]),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No more volunteers available\nfor this capacity/date.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.all(20),
                                itemCount: filteredVolunteers.length,
                                itemBuilder: (context, volIndex) {
                                  final volunteerData =
                                      filteredVolunteers[volIndex];
                                  final volunteer =
                                      volunteerData['volunteer'] as PickupAgent;
                                  final isVolunteerSelected =
                                      selectedVolunteerId == volunteer.id;

                                  final taskCount = selectedDate != null
                                      ? (dateTaskCounts[volunteer.id] ?? 0)
                                      : (volunteerData['taskCount'] as int? ??
                                          0);

                                  final isMaxLimitReached = taskCount >= 2;
                                  final matchScore =
                                      volunteerData['matchScore'] as int? ?? 0;
                                  final volunteerAddress =
                                      volunteerData['address'] as String? ?? '';
                                  final isNearby = matchScore > 0;

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: isVolunteerSelected
                                          ? (_isDarkMode
                                              ? Colors.green
                                                  .withValues(alpha: 0.2)
                                              : const Color(0xFFF1F8E9))
                                          : (_isDarkMode
                                              ? const Color(0xFF262b49)
                                              : Colors.white),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isVolunteerSelected
                                            ? const Color(0xFF4CAF50)
                                            : (_isDarkMode
                                                ? Colors.white
                                                    .withValues(alpha: 0.1)
                                                : Colors.grey
                                                    .withValues(alpha: 0.2)),
                                        width: isVolunteerSelected ? 2 : 1,
                                      ),
                                      boxShadow: isVolunteerSelected
                                          ? [
                                              BoxShadow(
                                                color: Colors.green
                                                    .withValues(alpha: 0.1),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: InkWell(
                                      onTap: isMaxLimitReached
                                          ? null
                                          : () async {
                                              setDialogState(() {
                                                if (selectedVolunteerId ==
                                                    volunteer.id) {
                                                  selectedVolunteerId = null;
                                                  selectedDate = null;
                                                } else {
                                                  selectedVolunteerId =
                                                      volunteer.id;
                                                  // Auto-select today
                                                  selectedDate = DateTime.now();
                                                  isLoadingCounts = true;
                                                }
                                              });

                                              if (selectedVolunteerId != null &&
                                                  selectedDate != null) {
                                                try {
                                                  final count = await _scheduleService
                                                      .getAssignmentCountForVolunteerOnDate(
                                                          selectedVolunteerId!,
                                                          selectedDate!);
                                                  setDialogState(() {
                                                    dateTaskCounts[
                                                            selectedVolunteerId!] =
                                                        count;
                                                    isLoadingCounts = false;
                                                  });
                                                } catch (e) {
                                                  setDialogState(() =>
                                                      isLoadingCounts = false);
                                                }
                                              }
                                            },
                                      borderRadius: BorderRadius.circular(24),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Opacity(
                                          opacity:
                                              isMaxLimitReached ? 0.5 : 1.0,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Hero(
                                                    tag: 'vol_${volunteer.id}',
                                                    child: Container(
                                                      height: 48,
                                                      width: 48,
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            const LinearGradient(
                                                          colors: [
                                                            Color(0xFF43A047),
                                                            Color(0xFF66BB6A)
                                                          ],
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16),
                                                      ),
                                                      child: const Icon(
                                                          Icons.person_rounded,
                                                          color: Colors.white,
                                                          size: 28),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          volunteer.name,
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 17,
                                                            color: _isDarkMode
                                                                ? Colors.white
                                                                : const Color(
                                                                    0xFF263238),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Row(
                                                          children: [
                                                            const Icon(
                                                                Icons
                                                                    .phone_rounded,
                                                                size: 14,
                                                                color: Colors
                                                                    .grey),
                                                            const SizedBox(
                                                                width: 4),
                                                            Text(
                                                              volunteer.phone,
                                                              style: TextStyle(
                                                                color: _isDarkMode
                                                                    ? Colors.grey[
                                                                        400]
                                                                    : Colors.grey[
                                                                        600],
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        if (volunteerAddress
                                                            .isNotEmpty) ...[
                                                          const SizedBox(
                                                              height: 4),
                                                          Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .location_on,
                                                                size: 14,
                                                                color: isNearby
                                                                    ? Colors
                                                                        .green
                                                                    : Colors
                                                                        .grey,
                                                              ),
                                                              const SizedBox(
                                                                  width: 4),
                                                              Expanded(
                                                                child: Text(
                                                                  volunteerAddress,
                                                                  style:
                                                                      TextStyle(
                                                                    color: _isDarkMode
                                                                        ? Colors.grey[
                                                                            400]
                                                                        : Colors
                                                                            .grey[600],
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                        const SizedBox(
                                                            height: 8),
                                                        Row(
                                                          children: [
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: isMaxLimitReached
                                                                    ? Colors.red
                                                                        .withValues(
                                                                            alpha:
                                                                                0.1)
                                                                    : Colors
                                                                        .blue
                                                                        .withValues(
                                                                            alpha:
                                                                                0.1),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Icon(
                                                                    isMaxLimitReached
                                                                        ? Icons
                                                                            .block
                                                                        : Icons
                                                                            .assignment,
                                                                    size: 12,
                                                                    color: isMaxLimitReached
                                                                        ? Colors
                                                                            .red
                                                                        : Colors
                                                                            .blue,
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 4),
                                                                  Text(
                                                                    'Tasks: $taskCount/2',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: isMaxLimitReached
                                                                          ? Colors
                                                                              .red
                                                                          : Colors
                                                                              .blue,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            if (isNearby) ...[
                                                              const SizedBox(
                                                                  width: 6),
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .green
                                                                      .withValues(
                                                                          alpha:
                                                                              0.1),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              6),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    const Icon(
                                                                      Icons
                                                                          .near_me,
                                                                      size: 12,
                                                                      color: Colors
                                                                          .green,
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            4),
                                                                    const Text(
                                                                      'Nearby',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        color: Colors
                                                                            .green,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (isVolunteerSelected)
                                                    const Icon(
                                                        Icons
                                                            .check_circle_rounded,
                                                        color:
                                                            Color(0xFF43A047),
                                                        size: 24),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        // Selection Summary
                        if (selectedVolunteerId != null && selectedDate != null)
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _isDarkMode
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_circle,
                                      color: Colors.green, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Selected: ${volunteersWithDates.firstWhere((v) => v['volunteer'].id == selectedVolunteerId)['volunteer'].name}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: _isDarkMode
                                              ? Colors.greenAccent
                                              : Colors.green.shade900,
                                        ),
                                      ),
                                      Text(
                                        'For: Today (${DateFormat('EEEE, MMM dd').format(selectedDate!)})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _isDarkMode
                                              ? Colors.greenAccent
                                                  .withValues(alpha: 0.7)
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn().scale(),

                        // Actions Footer
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? const Color(0xFF1a1f3a)
                                : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, -5),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                          color: _isDarkMode
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: (selectedVolunteerId != null &&
                                            selectedDate != null &&
                                            !isLoadingCounts &&
                                            (dateTaskCounts[
                                                        selectedVolunteerId] ??
                                                    0) <
                                                2)
                                        ? () async {
                                            try {
                                              final volunteer = volunteersWithDates
                                                      .firstWhere((v) =>
                                                          v['volunteer'].id ==
                                                          selectedVolunteerId)[
                                                  'volunteer'];

                                              // Find closest NGO based on user location
                                              final closestNgo =
                                                  _findClosestNgoByLocation(
                                                      item.location ?? '');

                                              // Set pickup scheduled date
                                              final pickupDateTime = DateTime(
                                                selectedDate!.year,
                                                selectedDate!.month,
                                                selectedDate!.day,
                                                9, // Default time
                                                0,
                                              );

                                              final wasteType =
                                                  itemData['type'] as String? ??
                                                      'e-waste';

                                              // CENTRALIZED ASSIGNMENT: This ensures both the item table
                                              // AND the volunteer_assignments table are updated.
                                              await _scheduleService
                                                  .createAssignment(
                                                volunteerId: volunteer.id,
                                                itemId: item.id.toString(),
                                                taskType: 'Pickup',
                                                scheduledDate: pickupDateTime,
                                                wasteType: wasteType,
                                              );

                                              // Assign closest NGO
                                              if (closestNgo != null) {
                                                final service =
                                                    itemData['service'];
                                                await service.assignNgo(
                                                    item.id, closestNgo.id);
                                              }

                                              await fetchAllData();
                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                              }

                                              // Enhanced Success Feedback
                                              if (!currentContext.mounted) {
                                                return;
                                              }
                                              ScaffoldMessenger.of(
                                                      currentContext)
                                                  .showSnackBar(
                                                SnackBar(
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  elevation: 0,
                                                  duration: const Duration(
                                                      seconds: 4),
                                                  content: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFF2E7D32),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      boxShadow: const [
                                                        BoxShadow(
                                                          color: Colors.black26,
                                                          blurRadius: 10,
                                                          offset: Offset(0, 4),
                                                        )
                                                      ],
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                            Icons
                                                                .check_circle_rounded,
                                                            color: Colors.white,
                                                            size: 28),
                                                        const SizedBox(
                                                            width: 12),
                                                        Expanded(
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const Text(
                                                                'Assignment Successful!',
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        14),
                                                              ),
                                                              Text(
                                                                '${volunteer.name} scheduled for ${DateFormat('MMM dd').format(pickupDateTime)}',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .white
                                                                        .withValues(
                                                                            alpha:
                                                                                0.9),
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );

                                              // Refresh the pending requests
                                              setState(() {});
                                            } catch (e) {
                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                              }
                                              if (currentContext.mounted) {
                                                ScaffoldMessenger.of(
                                                        currentContext)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          'Error: ${e.toString()}')),
                                                );
                                              }
                                            }
                                          }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: _isDarkMode
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : Colors.grey.shade300,
                                      disabledForegroundColor: _isDarkMode
                                          ? Colors.white.withValues(alpha: 0.38)
                                          : Colors.grey.shade600,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Assign Volunteer',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    } catch (e) {
      setState(() => _loadingStates[itemId] = false);
      if (currentContext.mounted) {
        showDialog(
          context: currentContext,
          builder: (context) => Theme(
            data: _isDarkMode
                ? ThemeData.dark().copyWith(
                    dialogTheme: const DialogThemeData(
                        backgroundColor: Color(0xFF1a1f3a)),
                  )
                : ThemeData.light().copyWith(
                    dialogTheme:
                        const DialogThemeData(backgroundColor: Colors.white),
                    colorScheme: ColorScheme.light(
                      primary: Colors.green.shade800,
                      surface: Colors.white,
                      surfaceTint: Colors.transparent,
                    ),
                  ),
            child: AlertDialog(
              title: const Text('Error'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Failed to fetch available volunteers:\n$e'),
                    const SizedBox(height: 12),
                    Text(
                      'Debug Info:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey[700]),
                    ),
                    Text(
                      'Item ID: $itemId',
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      'All Profiles Loaded: ${allProfiles.isNotEmpty}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  Widget _buildNgoManagementTab(Color cardColor) {
    if (isLoading && ngos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredNgos = ngos.where((ngo) {
      if (_searchQuery.isEmpty) return true;
      return ngo.name.toLowerCase().contains(_searchQuery) ||
          (ngo.district.toLowerCase().contains(_searchQuery));
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Registered NGOs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              FilledButton.icon(
                onPressed: _addNgo,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add NGO'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: fetchAllData,
            child: filteredNgos.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.6,
                      alignment: Alignment.center,
                      child: _buildEmptyState(
                          'No NGOs found', Icons.business_outlined),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredNgos.length,
                    itemBuilder: (context, index) {
                      final ngo = filteredNgos[index];
                      return Card(
                        elevation: _isDarkMode ? 8 : 2,
                        color: _isDarkMode
                            ? const Color(0xFF1a1f3a)
                            : Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: _isDarkMode
                              ? BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 1)
                              : BorderSide.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(Icons.business,
                                        color: Colors.purple.shade700),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                ngo.name,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: _isDarkMode
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (ngo.isGovernmentApproved) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                      color: Colors.blue),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: const [
                                                    Icon(Icons.verified,
                                                        size: 14,
                                                        color: Colors.blue),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'GOV',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          ngo.district,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: _isDarkMode
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert,
                                        size: 20,
                                        color: _isDarkMode
                                            ? Colors.white
                                            : Colors.black87),
                                    color: _isDarkMode
                                        ? const Color(0xFF1a1f3a)
                                        : Colors.white,
                                    surfaceTintColor: Colors.transparent,
                                    onSelected: (value) {
                                      if (value == 'edit') _editNgo(ngo);
                                      if (value == 'delete') _deleteNgo(ngo);
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined,
                                                size: 18,
                                                color: _isDarkMode
                                                    ? Colors.white70
                                                    : Colors.black87),
                                            const SizedBox(width: 8),
                                            Text('Edit',
                                                style: TextStyle(
                                                    color: _isDarkMode
                                                        ? Colors.white
                                                        : Colors.black87)),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline,
                                                size: 18, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _isDarkMode
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    _buildNgoInfoRow(Icons.location_on_outlined,
                                        ngo.address),
                                    const SizedBox(height: 8),
                                    _buildNgoInfoRow(Icons.phone_outlined,
                                        ngo.contactInfo ?? 'N/A'),
                                    if (ngo.wasteTypes != null &&
                                        ngo.wasteTypes!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: ngo.wasteTypes!
                                            .map((type) => Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    border: Border.all(
                                                        color: Colors.green
                                                            .withValues(
                                                                alpha: 0.2)),
                                                  ),
                                                  child: Text(
                                                    type.toUpperCase(),
                                                    style: const TextStyle(
                                                      color: Colors.green,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNgoInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon,
            size: 16, color: _isDarkMode ? Colors.grey[400] : Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: _isDarkMode ? Colors.grey[300] : Colors.grey[800],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _addNgo() async {
    final result = await showDialog<Ngo>(
      context: context,
      builder: (context) => Theme(
        data: _isDarkMode
            ? ThemeData.dark().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Color(0xFF1a1f3a)),
              )
            : ThemeData.light().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Colors.white),
                colorScheme: ColorScheme.light(
                  primary: Colors.green.shade800,
                  surface: Colors.white,
                  surfaceTint: Colors.transparent,
                ),
              ),
        child: const AddNgoDialog(),
      ),
    );

    if (result != null) {
      try {
        await _ewasteService.addNgo(result);
        if (!mounted) return;
        fetchAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NGO added successfully')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding NGO: $e')),
        );
      }
    }
  }

  void _editNgo(Ngo ngo) async {
    final result = await showDialog<Ngo>(
      context: context,
      builder: (context) => Theme(
        data: _isDarkMode
            ? ThemeData.dark().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Color(0xFF1a1f3a)),
              )
            : ThemeData.light().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Colors.white),
                colorScheme: ColorScheme.light(
                  primary: Colors.green.shade800,
                  surface: Colors.white,
                  surfaceTint: Colors.transparent,
                ),
              ),
        child: EditNgoDialog(ngo: ngo),
      ),
    );

    if (result != null) {
      try {
        await _ewasteService.updateNgo(ngo.id, result.toJson());
        if (!mounted) return;
        fetchAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NGO updated successfully')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating NGO: $e')),
        );
      }
    }
  }

  Widget _buildFeedbackTab(Color cardColor) {
    if (isLoading && feedbackItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredFeedback = _filteredFeedbackItems;

    return RefreshIndicator(
      onRefresh: fetchAllData,
      child: filteredFeedback.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                alignment: Alignment.center,
                child: _buildEmptyState(
                    'No feedback items found', Icons.feedback_outlined),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredFeedback.length,
              itemBuilder: (context, index) {
                final feedback = filteredFeedback[index];
                final statusColor = _getFeedbackStatusColor(feedback.status);

                return Card(
                  elevation: _isDarkMode ? 8 : 2,
                  color: _isDarkMode ? const Color(0xFF1a1f3a) : Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: _isDarkMode
                        ? BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1)
                        : BorderSide.none,
                  ),
                  child: ExpansionTile(
                    shape: const RoundedRectangleBorder(side: BorderSide.none),
                    collapsedShape:
                        const RoundedRectangleBorder(side: BorderSide.none),
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feedback.subject,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color:
                                      _isDarkMode ? Colors.white : Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                feedback.userEmail ?? 'Anonymous',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusChip(feedback.status, statusColor),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Category: ${feedback.category}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade700),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            const SizedBox(height: 8),
                            const Text(
                              'Message',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              feedback.message,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: _isDarkMode
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                            if (feedback.adminResponse != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color:
                                          Colors.blue.withValues(alpha: 0.1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.reply,
                                            size: 14, color: Colors.blue),
                                        SizedBox(width: 4),
                                        Text(
                                          'Admin Response',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Colors.blue),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      feedback.adminResponse!,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _confirmDeleteFeedback(feedback),
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18),
                                    label: const Text('Delete'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () =>
                                        _showFeedbackStatusDialog(feedback),
                                    icon: const Icon(Icons.flag_outlined,
                                        size: 18),
                                    label: const Text('Update Status'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Color _getFeedbackStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'reviewed':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
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
        builder: (context) => Theme(
          data: _isDarkMode
              ? ThemeData.dark().copyWith(
                  dialogTheme:
                      const DialogThemeData(backgroundColor: Color(0xFF1a1f3a)),
                )
              : ThemeData.light().copyWith(
                  dialogTheme:
                      const DialogThemeData(backgroundColor: Colors.white),
                  colorScheme: ColorScheme.light(
                    primary: Colors.green.shade800,
                    surface: Colors.white,
                    surfaceTint: Colors.transparent,
                  ),
                ),
          child: AlertDialog(
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
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Theme(
        data: _isDarkMode
            ? ThemeData.dark().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Color(0xFF1a1f3a)),
              )
            : ThemeData.light().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Colors.white),
                colorScheme: ColorScheme.light(
                  primary: Colors.green.shade800,
                  surface: Colors.white,
                  surfaceTint: Colors.transparent,
                ),
              ),
        child: AlertDialog(
          title: const Text('Update Feedback Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableStatuses.map((status) {
              String displayText =
                  status[0].toUpperCase() + status.substring(1);
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
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 64, color: _isDarkMode ? Colors.grey[600] : Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: _isDarkMode ? Colors.grey[400] : Colors.grey,
            ),
          ),
        ],
      ),
    );
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

    return RefreshIndicator(
      onRefresh: fetchAllData,
      child: sortedApps.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                alignment: Alignment.center,
                child: _buildEmptyState('No volunteer applications found',
                    Icons.person_add_disabled),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: sortedApps.length,
              itemBuilder: (context, index) {
                final app = sortedApps[index];
                final isPending = app.status == 'pending';
                final isApproved = app.status == 'approved';

                final statusColor = isPending
                    ? Colors.orange
                    : isApproved
                        ? Colors.green
                        : Colors.red;

                return Card(
                  elevation: _isDarkMode ? 8 : 2,
                  color: _isDarkMode ? const Color(0xFF1a1f3a) : Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: _isDarkMode
                        ? BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1)
                        : BorderSide.none,
                  ),
                  child: ExpansionTile(
                    shape: const RoundedRectangleBorder(side: BorderSide.none),
                    collapsedShape:
                        const RoundedRectangleBorder(side: BorderSide.none),
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withValues(alpha: 0.1),
                      child: Text(
                        app.fullName[0].toUpperCase(),
                        style: TextStyle(
                            color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            app.fullName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        _buildStatusChip(app.status.toUpperCase(), statusColor),
                      ],
                    ),
                    subtitle: Text(
                      'Applied on ${DateFormat('MMM d, yyyy').format(app.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            const SizedBox(height: 12),

                            // Contact Info Section
                            const Text(
                              'Contact Information',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.blue),
                            ),
                            const SizedBox(height: 8),
                            _buildFeedbackInfoRow(
                                Icons.email_outlined, 'Email', app.email),
                            const SizedBox(height: 4),
                            _buildFeedbackInfoRow(
                                Icons.phone_outlined, 'Phone', app.phone),
                            const SizedBox(height: 4),
                            _buildFeedbackInfoRow(Icons.location_on_outlined,
                                'Address', app.address),

                            const SizedBox(height: 16),

                            // Motivation Section
                            const Text(
                              'Motivation',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.blue),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.grey.withValues(alpha: 0.1)),
                              ),
                              child: Text(
                                app.motivation,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: _isDarkMode
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Action Buttons
                            if (isPending)
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _handleAppDecision(app, false),
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Reject'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side:
                                            const BorderSide(color: Colors.red),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () =>
                                          _handleAppDecision(app, true),
                                      icon: const Icon(Icons.check, size: 18),
                                      label: const Text('Approve'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Icon(
                                    isApproved ? Icons.verified : Icons.cancel,
                                    size: 16,
                                    color:
                                        isApproved ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Decision made on ${DateFormat('MMM d').format(app.availableDate)}',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: _isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isApproved)
                                    IconButton(
                                      onPressed: () =>
                                          _showRevokeVolunteerDialog(app),
                                      icon: const Icon(
                                          Icons.person_remove_outlined,
                                          color: Colors.orange),
                                      tooltip: 'Revoke Volunteer Status',
                                    ),
                                  IconButton(
                                    onPressed: () =>
                                        _confirmDeleteVolunteerApplication(app),
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    tooltip: 'Delete Application',
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildFeedbackInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 14, color: _isDarkMode ? Colors.grey[400] : Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: _isDarkMode ? Colors.grey[400] : Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSchedulesTab(Color cardColor) {
    if (allSchedules.isEmpty) {
      return _buildEmptyState('No volunteer schedules', Icons.calendar_today);
    }

    // Get today's date for validation
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Use memoized data
    final availabilityCounts = _availabilityCounts;
    final volunteersByDate = _volunteersByDate;

    return RefreshIndicator(
      onRefresh: fetchAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Calendar view with availability counts
            Card(
              margin: const EdgeInsets.all(16),
              elevation: _isDarkMode ? 8 : 4,
              color: _isDarkMode ? const Color(0xFF1a1f3a) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: _isDarkMode
                    ? BorderSide(
                        color: Colors.white.withValues(alpha: 0.1), width: 1)
                    : BorderSide.none,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TableCalendar(
                  firstDay: todayDate, // Start from today
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    // Only allow selection of today and future dates
                    final selectedDateOnly = DateTime(
                        selectedDay.year, selectedDay.month, selectedDay.day);
                    if (selectedDateOnly.isBefore(todayDate)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Cannot select past dates. Please choose today or a future date.')),
                      );
                      return;
                    }

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
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                    leftChevronIcon: Icon(
                      Icons.chevron_left,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      color: _isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                    weekendStyle: TextStyle(
                      color: _isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: _isDarkMode
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color:
                          _isDarkMode ? Colors.green : const Color(0xFF2E7D32),
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    disabledDecoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      final date = DateTime(day.year, day.month, day.day);
                      final count = availabilityCounts[date] ?? 0;
                      final isPastDate = date.isBefore(todayDate);

                      return Container(
                        margin: const EdgeInsets.all(4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: count > 0 && !isPastDate
                              ? Colors.green.withValues(alpha: 0.1)
                              : null,
                          border: count > 0 && !isPastDate
                              ? Border.all(color: Colors.green, width: 2)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              day.day.toString(),
                              style: TextStyle(
                                color: isPastDate
                                    ? (_isDarkMode
                                        ? Colors.grey[600]
                                        : Colors.grey)
                                    : (_isDarkMode
                                        ? Colors.white
                                        : Colors.black),
                                fontWeight: isSameDay(day, DateTime.now())
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (count > 0 && !isPastDate)
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
                          color: _isDarkMode
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: count > 0
                              ? Border.all(color: Colors.green, width: 2)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              day.day.toString(),
                              style: TextStyle(
                                color: _isDarkMode
                                    ? Colors.white
                                    : Colors.green[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (count > 0)
                              Text(
                                count.toString(),
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.green[800],
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
                          color: _isDarkMode
                              ? Colors.green
                              : const Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                          border: count > 0
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    color: _isDarkMode ? Colors.green[400] : Colors.green[700],
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Available Volunteers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedDay != null)
                    Text(
                      DateFormat('MMM d, y').format(_selectedDay!),
                      style: TextStyle(
                        color:
                            _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(indent: 24, endIndent: 24),
            _buildVolunteerCardsForDate(
              DateTime(
                  _selectedDay!.year, _selectedDay!.month, _selectedDay!.day),
              volunteersByDate[DateTime(_selectedDay!.year, _selectedDay!.month,
                      _selectedDay!.day)] ??
                  [],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildVolunteerCardsForDate(
      DateTime date, List<VolunteerSchedule> volunteers) {
    if (volunteers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.person_off,
                size: 48,
                color: _isDarkMode ? Colors.grey[700] : Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'No volunteers available for this date',
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: volunteers.length,
      itemBuilder: (context, index) {
        final schedule = volunteers[index];
        final volunteerName =
            userNames[schedule.volunteerId] ?? 'Unknown Volunteer';

        final volunteerProfile = allProfiles.firstWhere(
          (profile) => profile['id'] == schedule.volunteerId,
          orElse: () => <String, dynamic>{},
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          color: _isDarkMode ? const Color(0xFF262b49) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: _isDarkMode
                ? BorderSide(
                    color: Colors.white.withValues(alpha: 0.1), width: 1)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                      child: const Icon(
                        Icons.person,
                        color: Colors.green,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            volunteerName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  _isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Available',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  color: _isDarkMode
                      ? Colors.grey[700]
                      : Colors.grey.withValues(alpha: 0.3),
                  height: 1,
                ),
                const SizedBox(height: 12),
                if (volunteerProfile.isNotEmpty) ...[
                  Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (volunteerProfile['phone_number'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              volunteerProfile['phone_number'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: 13,
                                color: _isDarkMode
                                    ? Colors.grey[300]
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (volunteerProfile['email'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.email, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              volunteerProfile['email'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: 13,
                                color: _isDarkMode
                                    ? Colors.grey[300]
                                    : Colors.black87,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (volunteerProfile['address'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              volunteerProfile['address'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: 13,
                                color: _isDarkMode
                                    ? Colors.grey[300]
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersTab(Color cardColor) {
    if (isLoading && allProfiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredProfiles = _filteredProfiles;

    return RefreshIndicator(
      onRefresh: fetchAllData,
      child: filteredProfiles.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                alignment: Alignment.center,
                child: _buildEmptyState('No users found', Icons.people_outline),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredProfiles.length,
              itemBuilder: (context, index) {
                final profile = filteredProfiles[index];
                final userId = profile['id'] as String? ?? '';
                final fullName = profile['full_name'] as String? ?? 'N/A';
                final email = profile['email'] as String? ?? 'N/A';
                final role = profile['user_role'] as String? ?? 'user';
                final points = profile['total_points'] as int? ?? 0;
                final roleColor = _getRoleColor(role);

                return Card(
                  elevation: _isDarkMode ? 8 : 2,
                  color: _isDarkMode ? const Color(0xFF1a1f3a) : Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: _isDarkMode
                        ? BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1)
                        : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                fullName.isNotEmpty
                                    ? fullName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: roleColor),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: roleColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: TextStyle(
                                  color: roleColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    size: 16, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  '$points Points',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            _buildUserActionButton(
                              icon: Icons.info_outline,
                              onPressed: () => _showUserDetailsDialog(profile),
                              tooltip: 'Details',
                            ),
                            const SizedBox(width: 8),
                            _buildUserActionButton(
                              icon: Icons.emoji_events_outlined,
                              onPressed: () => _showEchoPointStatusDialog(
                                  userId, fullName, points, profile),
                              tooltip: 'Echo Point Status',
                              color: Colors.amber[800],
                            ),
                            const SizedBox(width: 8),
                            _buildUserActionButton(
                              icon: Icons.delete_outline,
                              onPressed: () =>
                                  _confirmDeleteUser(userId, fullName),
                              tooltip: 'Delete User',
                              color: Colors.red,
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

  Widget _buildUserActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color? color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? Colors.grey[700])!.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: color ?? Colors.grey[700]),
      ),
    );
  }

  Future<void> _confirmDeleteUser(String userId, String userName) async {
    showDialog(
        context: context,
        builder: (context) => Theme(
              data: _isDarkMode
                  ? ThemeData.dark().copyWith(
                      dialogTheme: const DialogThemeData(
                          backgroundColor: Color(0xFF1a1f3a)),
                    )
                  : ThemeData.light().copyWith(
                      dialogTheme:
                          const DialogThemeData(backgroundColor: Colors.white),
                      colorScheme: ColorScheme.light(
                        primary: Colors.green.shade800,
                        surface: Colors.white,
                        surfaceTint: Colors.transparent,
                      ),
                    ),
              child: AlertDialog(
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
            ));
  }

  Future<void> _deleteUser(String userId, String userName) async {
    try {
      // Delete user profile first
      await AppSupabase.client.from('profiles').delete().eq('id', userId);

      // Delete user auth account
      try {
        await AppSupabase.client.auth.admin.deleteUser(userId);
      } catch (e) {
        // print(...);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $userName deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await fetchAllData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {});
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

  void _showUserDetailsDialog(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: _isDarkMode
            ? ThemeData.dark().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Color(0xFF1a1f3a)),
              )
            : ThemeData.light().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Colors.white),
                colorScheme: ColorScheme.light(
                  primary: Colors.green.shade800,
                  surface: Colors.white,
                  surfaceTint: Colors.transparent,
                ),
              ),
        child: AlertDialog(
          title: const Text('User Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Name', profile['full_name'] as String? ?? 'N/A'),
                _detailRow('Email', profile['email'] as String? ?? 'N/A'),
                _detailRow(
                    'Phone', profile['phone_number'] as String? ?? 'N/A'),
                _detailRow(
                    'Role',
                    _capitalizeFirst(
                        profile['user_role'] as String? ?? 'user')),
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.grey[300] : Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // (Include other tab methods as originally defined)

  Future<void> _deleteNgo(Ngo ngo) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => Theme(
              data: _isDarkMode
                  ? ThemeData.dark().copyWith(
                      dialogTheme: const DialogThemeData(
                          backgroundColor: Color(0xFF1a1f3a)),
                    )
                  : ThemeData.light().copyWith(
                      dialogTheme:
                          const DialogThemeData(backgroundColor: Colors.white),
                      colorScheme: ColorScheme.light(
                        primary: Colors.green.shade800,
                        surface: Colors.white,
                        surfaceTint: Colors.transparent,
                      ),
                    ),
              child: AlertDialog(
                title: const Text('Delete NGO'),
                content: Text('Are you sure you want to delete ${ngo.name}?'),
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  TextButton(
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ));
    if (confirm == true) {
      try {
        await _ewasteService.deleteNgo(ngo.id);
        if (!mounted) return;
        fetchAllData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NGO deleted successfully')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting NGO: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: _isDarkMode
            ? ThemeData.dark().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Color(0xFF1a1f3a)),
              )
            : ThemeData.light().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Colors.white),
                colorScheme: ColorScheme.light(
                  primary: Colors.green.shade800,
                  surface: Colors.white,
                  surfaceTint: Colors.transparent,
                ),
              ),
        child: AlertDialog(
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
              child:
                  const Text('Sign Out', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _updateFeedbackStatus(
      String feedbackId, String status, String? adminResponse) async {
    try {
      await _feedbackService.updateFeedbackStatus(
          feedbackId, status, adminResponse);
      if (!mounted) return;
      fetchAllData();
      _showSuccess('Feedback status updated');
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to update status: $e');
    }
  }

  Future<void> _confirmDeleteFeedback(FeedbackItem feedback) async {
    showDialog(
        context: context,
        builder: (context) => Theme(
              data: _isDarkMode
                  ? ThemeData.dark().copyWith(
                      dialogTheme: const DialogThemeData(
                          backgroundColor: Color(0xFF1a1f3a)),
                    )
                  : ThemeData.light().copyWith(
                      dialogTheme:
                          const DialogThemeData(backgroundColor: Colors.white),
                      colorScheme: ColorScheme.light(
                        primary: Colors.green.shade800,
                        surface: Colors.white,
                        surfaceTint: Colors.transparent,
                      ),
                    ),
              child: AlertDialog(
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
            ));
  }

  Future<void> _deleteFeedback(String feedbackId, String subject) async {
    try {
      // print(...);
      await _feedbackService.deleteFeedback(feedbackId);
      // print(...);
      if (!mounted) return;
      _showSuccess('Feedback deleted successfully');
      await fetchAllData();
    } catch (e) {
      // print(...);
      if (!mounted) return;
      _showError('Failed to delete feedback: $e');
    }
  }

  Future<void> _confirmDeleteVolunteerApplication(
      VolunteerApplication app) async {
    showDialog(
        context: context,
        builder: (context) => Theme(
              data: _isDarkMode
                  ? ThemeData.dark().copyWith(
                      dialogTheme: const DialogThemeData(
                          backgroundColor: Color(0xFF1a1f3a)),
                    )
                  : ThemeData.light().copyWith(
                      dialogTheme:
                          const DialogThemeData(backgroundColor: Colors.white),
                      colorScheme: ColorScheme.light(
                        primary: Colors.green.shade800,
                        surface: Colors.white,
                        surfaceTint: Colors.transparent,
                      ),
                    ),
              child: AlertDialog(
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
            ));
  }

  Future<void> _deleteVolunteerApplication(
      String appId, String fullName) async {
    try {
      await _profileService.deleteVolunteerApplication(appId);
      if (!mounted) return;
      _showSuccess('Volunteer application deleted successfully');
      await fetchAllData();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to delete volunteer application: $e');
    }
  }

  Future<void> _showRevokeVolunteerDialog(VolunteerApplication app) async {
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Theme(
        data: _isDarkMode
            ? ThemeData.dark().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Color(0xFF1a1f3a)),
              )
            : ThemeData.light().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Colors.white),
                colorScheme: ColorScheme.light(
                  primary: Colors.green.shade800,
                  surface: Colors.white,
                  surfaceTint: Colors.transparent,
                ),
              ),
        child: AlertDialog(
          title: const Text('Revoke Volunteer Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Are you sure you want to revoke the volunteer status of ${app.fullName}?'),
              const SizedBox(height: 12),
              const Text(
                'Reason/Comment (optional):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: 'e.g., Accidentally approved or policy violation',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: _isDarkMode ? Colors.grey[800] : Colors.grey[100],
                ),
                maxLines: 3,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[300]!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Note: This will revert the user to a regular role and they will be able to apply again.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[800],
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
                final comment = commentController.text.trim();
                Navigator.pop(context);
                try {
                  setState(() => isLoading = true);
                  await _profileService.revokeVolunteerStatus(
                      app.id, app.userId, comment);
                  if (!mounted) return;
                  _showSuccess('Volunteer status revoked successfully');
                  await fetchAllData();
                } catch (e) {
                  if (!mounted) return;
                  _showError('Failed to revoke status: $e');
                } finally {
                  setState(() => isLoading = false);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Revoke Status'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEchoPointStatusDialog(String userId, String userName,
      int totalPoints, Map<String, dynamic> profile) {
    // Define rewards matching User App
    final List<Map<String, dynamic>> rewards = [
      {
        'name': 'Google Play Store Code (₹500)',
        'cost': 5000,
        'icon': Icons.play_circle_fill,
        'color': Colors.redAccent
      },
      {
        'name': 'Amazon Gift Voucher (₹200)',
        'cost': 2500,
        'icon': Icons.redeem,
        'color': Colors.teal
      },
      {
        'name': 'Eco-Friendly Water Bottle',
        'cost': 1500,
        'icon': Icons.water_drop,
        'color': Colors.blue
      },
      {
        'name': 'Eco Tote Bag',
        'cost': 500,
        'icon': Icons.shopping_bag_outlined,
        'color': Colors.green
      },
    ];

    showDialog(
      context: context,
      builder: (context) => Theme(
        data: _isDarkMode
            ? ThemeData.dark().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Color(0xFF1a1f3a)),
              )
            : ThemeData.light().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Colors.white),
                colorScheme: ColorScheme.light(
                  primary: Colors.green.shade800,
                  surface: Colors.white,
                  surfaceTint: Colors.transparent,
                ),
              ),
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emoji_events,
                          color: Colors.amber, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rewards Status',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color:
                                  _isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            userName,
                            style: TextStyle(
                              fontSize: 14,
                              color: _isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '$totalPoints pts',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Rewards List
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Rewards',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _isDarkMode
                                ? Colors.grey[300]
                                : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...rewards.map((reward) {
                          final bool isUnlocked =
                              totalPoints >= (reward['cost'] as int);
                          final color = reward['color'] as Color;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isDarkMode
                                  ? Colors.black.withValues(alpha: 0.2)
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isUnlocked
                                    ? color.withValues(alpha: 0.5)
                                    : (_isDarkMode
                                        ? Colors.white10
                                        : Colors.grey[300]!),
                                width: isUnlocked ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isUnlocked
                                        ? color.withValues(alpha: 0.1)
                                        : Colors.grey.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    reward['icon'] as IconData,
                                    color: isUnlocked ? color : Colors.grey,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reward['name'] as String,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isUnlocked
                                              ? (_isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87)
                                              : Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '${reward['cost']} points',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              isUnlocked ? color : Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isUnlocked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Unlocked',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    '${(reward['cost'] as int) - totalPoints} more',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showRewardHistoryDialog(userId);
                        },
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text('History'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _isDarkMode
                              ? Colors.greenAccent
                              : Colors.green.shade800,
                          side: BorderSide(
                              color: _isDarkMode
                                  ? Colors.greenAccent
                                  : Colors.green.shade800),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAdjustPointsDialog(
                              userId, userName, totalPoints);
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Adjust'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAdjustPointsDialog(
      String userId, String userName, int currentPoints) {
    final TextEditingController pointsController = TextEditingController();
    String operation = 'add'; // 'add' or 'subtract'

    showDialog(
        context: context,
        builder: (context) => Theme(
              data: _isDarkMode
                  ? ThemeData.dark().copyWith(
                      dialogTheme: const DialogThemeData(
                          backgroundColor: Color(0xFF1a1f3a)),
                      colorScheme: const ColorScheme.dark(
                        primary: Colors.green,
                        surface: Color(0xFF1a1f3a),
                      ),
                    )
                  : ThemeData.light().copyWith(
                      dialogTheme:
                          const DialogThemeData(backgroundColor: Colors.white),
                      colorScheme: ColorScheme.light(
                        primary: Colors.green.shade800,
                        surface: Colors.white,
                        surfaceTint: Colors.transparent,
                      ),
                    ),
              child: StatefulBuilder(
                builder: (context, setState) => AlertDialog(
                  title: Text('Adjust Points for $userName'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Current Points: $currentPoints'),
                      const SizedBox(height: 16),
                      RadioGroup<String>(
                        groupValue: operation,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => operation = value);
                          }
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Add Points'),
                                value: 'add',
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Subtract Points'),
                                value: 'subtract',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: pointsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Points Amount',
                          border: OutlineInputBorder(),
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
                        final pointsAmount =
                            int.tryParse(pointsController.text);
                        if (pointsAmount == null || pointsAmount <= 0) {
                          _showError('Please enter a valid positive number');
                          return;
                        }

                        try {
                          if (operation == 'add') {
                            await _profileService.addEcoPoints(
                                userId, pointsAmount);
                            if (!mounted) return;
                            _showSuccess(
                                'Added $pointsAmount points to $userName');
                          } else {
                            await _profileService.deductEcoPoints(
                                userId, pointsAmount);
                            if (!mounted) return;
                            _showSuccess(
                                'Subtracted $pointsAmount points from $userName');
                          }
                          if (!mounted) return;
                          if (context.mounted) Navigator.pop(context);
                          fetchAllData(); // Refresh the data
                        } catch (e) {
                          _showError('Failed to adjust points: $e');
                        }
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ),
            ));
  }

  void _showRewardHistoryDialog(String userId) {
    showDialog(
        context: context,
        builder: (context) => Theme(
              data: _isDarkMode
                  ? ThemeData.dark().copyWith(
                      dialogTheme: const DialogThemeData(
                          backgroundColor: Color(0xFF1a1f3a)),
                    )
                  : ThemeData.light().copyWith(
                      dialogTheme:
                          const DialogThemeData(backgroundColor: Colors.white),
                      colorScheme: ColorScheme.light(
                        primary: Colors.green.shade800,
                        surface: Colors.white,
                        surfaceTint: Colors.transparent,
                      ),
                    ),
              child: AlertDialog(
                title: const Text('Reward History'),
                content: const Text(
                    'Reward history tracking would be implemented here.\n\n'
                    'This would show:\n'
                    '• When rewards were claimed\n'
                    '• Points spent on rewards\n'
                    '• Reward delivery status\n'
                    '• Admin adjustments to points'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ));
  }

  String _getItemDisplayName(dynamic item, String type) {
    if (type == 'cloth') {
      return item.type ?? 'Unknown';
    }
    return item.itemName ?? 'Unknown';
  }

  String _getItemDescription(dynamic item, String type) {
    if (type == 'cloth') {
      return 'Condition: ${item.condition ?? 'Unknown'}, Quantity: ${item.quantity ?? 0}';
    }
    return item.description ?? 'No description';
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
