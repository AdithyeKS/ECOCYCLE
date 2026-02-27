import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ecocycle/core/supabase_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecocycle/models/volunteer_schedule.dart';
import 'package:ecocycle/models/volunteer_assignment.dart';
import 'package:ecocycle/models/volunteer_application.dart';
import 'package:ecocycle/services/ewaste_service.dart';
import 'package:ecocycle/services/plastic_service.dart';
import 'package:ecocycle/services/cloth_service.dart';
import 'package:ecocycle/services/volunteer_schedule_service.dart';
import 'package:ecocycle/services/profile_service.dart';
import 'package:ecocycle/models/ewaste_item.dart';
import 'package:ecocycle/models/plastic_item.dart';
import 'package:ecocycle/models/cloth_item.dart';
import 'login_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'feedback_screen.dart';
// import 'pending_waste_requests_screen.dart';
import 'assigned_pickup_history_screen.dart';
import 'volunteer_task_map_screen.dart';
import 'notifications_screen.dart';
import 'delivered_items_screen.dart';
import '../services/notification_service.dart';
import 'dart:async';

enum VolunteerTab { home, tasks, schedule, profile }

class VolunteerDashboard extends StatefulWidget {
  final VoidCallback? toggleTheme;
  const VolunteerDashboard({super.key, this.toggleTheme});

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  final _ewasteService = EwasteService();
  final _plasticService = PlasticService();
  final _clothService = ClothService();
  final _scheduleService = VolunteerScheduleService();
  final _profileService = ProfileService();
  List<Map<String, dynamic>> _assignedItems = [];
  List<VolunteerSchedule> _schedules = [];
  List<VolunteerAssignment> _assignments = [];
  List<Map<String, dynamic>> _adminAssignments = [];
  List<VolunteerApplication> _applications = [];
  List<VolunteerSchedule> _allSchedules = [];
  Map<String, String> _userNames = {};
  Map<String, String> _userPhones = {};
  final Map<String, dynamic> _ngoCache = {}; // Cache for NGO details
  bool _isLoading = true;
  String? _agentId;
  String _userRole = 'user';
  VolunteerTab _currentTab = VolunteerTab.home;
  String _selectedTaskFilter = 'all';
  final PageController _pageController =
      PageController(initialPage: VolunteerTab.home.index);
  final NotificationService _notificationService = NotificationService();
  int _unreadNotificationCount = 0;

  // Carousel State
  int _currentCarouselIndex = 0;
  Timer? _carouselTimer;
  final List<Map<String, String>> _carouselMessages = [
    {
      'title': 'Ready to impact?',
      'subtitle': 'Make a difference today.',
    },
    {
      'title': 'Small acts matter.',
      'subtitle': 'Every pickup helps the planet.',
    },
    {
      'title': 'You are a hero!',
      'subtitle': 'Thank you for volunteering.',
    },
  ];

  // Calendar state
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _initializeAgent();
    _loadUnreadNotificationCount();
    _startCarouselTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentCarouselIndex =
              (_currentCarouselIndex + 1) % _carouselMessages.length;
        });
      }
    });
  }

  Future<void> _initializeAgent() async {
    final user = AppSupabase.client.auth.currentUser;
    if (user != null) {
      _agentId = user.id;
      try {
        final profile = await _profileService.fetchProfile(user.id);
        if (profile != null) {
          _userRole = profile['user_role']?.toString() ?? 'user';
          // Populate the user name for display
          if (mounted) {
            setState(() {
              String firstName = profile['first_name'] ?? '';
              String lastName = profile['last_name'] ?? '';
              String fullName = '$firstName $lastName'.trim();
              if (fullName.isEmpty) {
                fullName = profile['full_name'] ?? 'Volunteer';
              }
              _userNames[_agentId!] = fullName;
            });
          }
        }
      } catch (e) {
        // print(...);
        _userRole = 'user';
      }

      _fetchAssignedItems();
      _fetchSchedules();
      _fetchAssignments();

      // Fetch admin data if user is admin
      if (_userRole == 'admin') {
        _fetchAllSchedules();
        _fetchApplications();
        _fetchUserNames();
      }
    } else {
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
      final results = await Future.wait([
        // E-waste
        _ewasteService.fetchItemsForAgent(_agentId!),
        // Plastic
        _plasticService.fetchItemsForAgent(_agentId!),
        // Cloth
        _clothService.fetchItemsForAgent(_agentId!),
      ]);

      final List<Map<String, dynamic>> allItems = [];

      // Helper to process items
      void addItems(List<dynamic> items, String type, dynamic service) {
        for (var item in items) {
          if (true) {
            // Already filtered by service call
            // Avoid duplicates check
            final exists = allItems.any((element) =>
                element['item'].id.toString() == item.id.toString() &&
                element['type'] == type);
            if (!exists) {
              allItems.add({
                'type': type,
                'item': item,
                'service': service,
                'deliveryStatus': item.deliveryStatus,
                'itemName': item.itemName,
                'location': item.location,
                'latitude': item.latitude,
                'longitude': item.longitude,
                'id': item.id,
              });
            }
          }
        }
      }

      addItems(results[0] as List, 'e-waste', _ewasteService);
      addItems(results[1] as List, 'plastic', _plasticService);
      addItems(results[2] as List, 'cloth', _clothService);

      allItems.sort((a, b) {
        final itemA = a['item'];
        final itemB = b['item'];

        int getScore(dynamic item) {
          return item.deliveryStatus == 'assigned' ? 0 : 1;
        }

        return getScore(itemA).compareTo(getScore(itemB));
      });

      setState(() {
        _assignedItems = allItems;
        _isLoading = false;
      });

      // Update counts for home tab
      _fetchAssignments();

      // Pre-fetch NGO details to prevent UI flickering
      _loadNgoDetailsForItems(allItems);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackbar('Error loading tasks: $e');
      }
    }
  }

  Future<void> _loadNgoDetailsForItems(List<Map<String, dynamic>> items) async {
    final Set<String> ngoIdsToFetch = {};

    for (var item in items) {
      final dynamic wasteItem = item['item'];
      try {
        if (wasteItem.assignedNgoId != null) {
          final String ngoId = wasteItem.assignedNgoId;
          if (!_ngoCache.containsKey(ngoId)) {
            ngoIdsToFetch.add(ngoId);
          }
        }
      } catch (e) {
        // Item might not have assignedNgoId property
      }
    }

    if (ngoIdsToFetch.isEmpty) return;

    for (final ngoId in ngoIdsToFetch) {
      await _fetchNgoDetails(ngoId);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchSchedules() async {
    if (_agentId == null) return;

    try {
      final schedules =
          await _scheduleService.fetchVolunteerSchedules(_agentId!);
      setState(() {
        _schedules = schedules;
      });
    } catch (e) {
      _showSnackbar('Error loading schedules: $e');
    }
  }

  Future<void> _fetchAssignments() async {
    if (_agentId == null) return;

    try {
      if (_userRole == 'admin') {
        // For admin, fetch all assignments with details
        final adminAssignments =
            await _scheduleService.fetchAllDetailedAssignments();
        setState(() => _adminAssignments = adminAssignments);
      } else {
        // For volunteers, fetch their specific assignments
        final assignments =
            await _scheduleService.fetchVolunteerAssignments(_agentId!);
        setState(() => _assignments = assignments);
      }
    } catch (e) {
      _showSnackbar('Error loading assignments: $e');
    }
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  /// Fetch NGO details by ID, with caching
  Future<Map<String, dynamic>?> _fetchNgoDetails(String ngoId) async {
    // Check cache first
    if (_ngoCache.containsKey(ngoId)) {
      return _ngoCache[ngoId];
    }

    try {
      final response = await AppSupabase.client
          .from('ngos')
          .select()
          .eq('id', ngoId)
          .single();

      final ngoData = response;
      // Cache the result
      _ngoCache[ngoId] = ngoData;
      return ngoData;
    } catch (e) {
      // print(...);
      return null;
    }
  }

  Future<void> _markAsDelivered(Map<String, dynamic> itemMap) async {
    final item = itemMap['item'];
    final dynamic service = itemMap['service'];
    final String itemName = itemMap['itemName'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('confirm_delivery')),
        content: Text(
            tr('mark_delivered_confirm').replaceAll('{itemName}', itemName)),
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
        await service.markAsDelivered(item.id);

        // Also update the assignment status to completed so the task count drops
        try {
          final assignment = _assignments.firstWhere(
            (a) => a.wasteItemId.toString() == item.id.toString(),
            orElse: () => VolunteerAssignment(
                id: '',
                volunteerId: '',
                wasteItemId: '',
                wasteType: '',
                taskType: '',
                status: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now()),
          );

          if (assignment.id.isNotEmpty) {
            await _scheduleService.updateAssignmentStatus(
                assignment.id, 'completed');
          }
        } catch (e) {
          debugPrint('Error updating assignment status: $e');
        }

        _fetchAssignedItems();
        await _fetchAssignments(); // Wait for assignments to update

        // Reward volunteer with EcoPoints for successful delivery
        if (_agentId != null) {
          try {
            await _profileService.addEcoPoints(_agentId!, 150);
            await _profileService.sendPointsEarnedNotification(
                _agentId!, item.itemName, 150);
            _showSnackbar('You earned 150 EcoPoints!');
          } catch (e) {
            debugPrint('Error awarding volunteer points: $e');
          }
        }

        _showSnackbar(tr('item_marked_delivered'));

        // Ask the volunteer if they want to continue after completing any task
        if (mounted) {
          await _askToContinueVolunteering();
        }
      } catch (e) {
        _showSnackbar('Error updating item: $e');
      }
    }
  }

  Future<void> _askToContinueVolunteering() async {
    if (_agentId == null) return;

    final wantsToContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Great Job!'),
        content: const Text(
            'You have completed this task. Do you want to continue executing tasks today?\n\n'
            'If you choose "No", your availability for today will be turned off.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, I\'m done'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Continue'),
          ),
        ],
      ),
    );

    if (wantsToContinue == true) {
      // Mark available (sets back to true if they were hidden)
      await _scheduleService.updateTodayAvailability(_agentId!, true);
      _showSnackbar('You remain available for more tasks!');
    } else {
      // Mark unavailable
      await _scheduleService.updateTodayAvailability(_agentId!, false);
      _showSnackbar('Your availability for today has been turned off.');
    }
    // Refresh schedules and assignments to reflect the change visually
    await _fetchSchedules();
    await _fetchAssignments();
  }

  // Help Desk Feature
  void _openHelpDesk() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.support_agent, size: 60, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Volunteer Help Desk',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Need assistance with a pickup or issue?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.email, color: Colors.blue),
              ),
              title: const Text('Email Support'),
              subtitle: const Text('support@ecocycle.com'),
              onTap: () {
                Navigator.pop(context);
                launchUrl(Uri.parse('mailto:support@ecocycle.com'));
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(String deliveryStatus) {
    switch (deliveryStatus) {
      case 'assigned':
        return 'Assigned';
      case 'collected':
        return 'Collected';
      case 'delivered':
        return 'Delivered';
      default:
        return 'Unknown';
    }
  }

  IconData _getStatusIcon(String deliveryStatus) {
    switch (deliveryStatus) {
      case 'assigned':
        return Icons.assignment;
      case 'collected':
        return Icons.inventory;
      case 'delivered':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  Color _getAssignmentStatusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getAssignmentStatusIcon(String status) {
    switch (status) {
      case 'assigned':
        return Icons.assignment_turned_in;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'pending':
        return Icons.schedule;
      default:
        return Icons.help;
    }
  }

  Future<void> _updateAssignmentStatus(
      String assignmentId, String status) async {
    try {
      await _scheduleService.updateAssignmentStatus(assignmentId, status);
      await _fetchAssignments();
      _showSnackbar('Assignment status updated to $status');
    } catch (e) {
      _showSnackbar('Error updating assignment: $e');
    }
  }

  Future<void> _cancelAssignment(String assignmentId, String itemId) async {
    try {
      await _scheduleService.cancelAssignment(assignmentId, itemId);
      await _fetchAssignments();
      _showSnackbar('Assignment cancelled');
    } catch (e) {
      _showSnackbar('Error cancelling assignment: $e');
    }
  }

  Widget _buildEmptyState(String message, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Sign Out'),
        content: const Text(
            'Are you sure you want to sign out of the Volunteer Dashboard?'),
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
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (r) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to sign out: $e')),
          );
        }
      }
    }
  }

  // Helper to normalize dates to midnight for consistent comparisons
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId != null) {
        final count = await _notificationService.getUnreadCount(userId,
            userRole: _userRole);
        if (mounted) {
          setState(() {
            _unreadNotificationCount = count;
          });
        }
      }
    } catch (e) {
      // Silently fail, notification count is not critical
    }
  }

  void _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
    // Refresh count after returning from notifications screen
    _loadUnreadNotificationCount();
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == 'admin') {
      return DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Volunteer Management'),
            flexibleSpace: Theme.of(context).brightness == Brightness.dark
                ? null
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)],
                      ),
                    ),
                  ),
            actions: [
              if (widget.toggleTheme != null)
                IconButton(
                  icon: Icon(
                    Theme.of(context).brightness == Brightness.dark
                        ? Icons.light_mode
                        : Icons.dark_mode,
                    color: Colors.white,
                  ),
                  onPressed: widget.toggleTheme,
                  tooltip: Theme.of(context).brightness == Brightness.dark
                      ? 'Light Mode'
                      : 'Dark Mode',
                ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: _logout,
                tooltip: 'Sign Out',
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
                Tab(icon: Icon(Icons.person_add), text: 'Applications'),
                Tab(icon: Icon(Icons.calendar_view_month), text: 'Schedules'),
                Tab(icon: Icon(Icons.assignment), text: 'Assignments'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildAdminOverviewTab(),
              _buildAdminApplicationsTab(),
              _buildAdminSchedulesTab(),
              _buildAdminAssignmentsTab(),
            ],
          ),
        ),
      );
    } else {
      // Regular user/volunteer view - App Version UI Design with Bottom Navigation
      return PopScope(
        canPop: _currentTab == VolunteerTab.home,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _currentTab != VolunteerTab.home) {
            setState(() {
              _currentTab = VolunteerTab.home;
            });
            _pageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        },
        child: Scaffold(
          appBar: _buildAppBar(),
          drawer: _buildDrawer(),
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentTab = VolunteerTab.values[index];
              });
            },
            children: [
              _buildHomeTab(),
              _buildTasksTab(),
              _buildScheduleTab(),
              _buildProfileTab(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentTab.index,
            onTap: (index) {
              setState(() {
                _currentTab = VolunteerTab.values[index];
              });
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            backgroundColor:
                Theme.of(context).bottomNavigationBarTheme.backgroundColor,
            selectedItemColor: const Color(0xFF2E7D32),
            unselectedItemColor: Colors.grey.shade400,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assignment),
                label: 'Tasks',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month),
                label: 'Schedule',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF2E7D32),
            ),
            accountName: Text(
              _userNames[_agentId] ?? "Volunteer",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            accountEmail: Text(_userRole.toUpperCase()),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                (_userNames[_agentId] ?? "V").substring(0, 1).toUpperCase(),
                style:
                    const TextStyle(fontSize: 24.0, color: Color(0xFF2E7D32)),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.feedback),
            title: const Text('Feedback'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FeedbackScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Contact Help Desk'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              _openHelpDesk();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    switch (_currentTab) {
      case VolunteerTab.home:
        return AppBar(
          title: Text(tr('volunteer_dashboard_title')),
          flexibleSpace: Theme.of(context).brightness == Brightness.dark
              ? null
              : Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                ),
          actions: [
            IconButton(
              icon: Badge(
                label: Text(_unreadNotificationCount.toString()),
                isLabelVisible: _unreadNotificationCount > 0,
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: _openNotifications,
              tooltip: 'Notifications',
            ),
            if (widget.toggleTheme != null)
              IconButton(
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: widget.toggleTheme,
                tooltip: Theme.of(context).brightness == Brightness.dark
                    ? 'Light Mode'
                    : 'Dark Mode',
              ),
          ],
        );

      case VolunteerTab.tasks:
        return AppBar(
          title: const Text('My Tasks'),
          flexibleSpace: Theme.of(context).brightness == Brightness.dark
              ? null
              : Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                ),
          actions: [
            IconButton(
              icon: const Icon(Icons.map),
              onPressed: () {
                _showMapOverlay();
              },
              tooltip: 'View Map',
            ),
            if (widget.toggleTheme != null)
              IconButton(
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: widget.toggleTheme,
                tooltip: Theme.of(context).brightness == Brightness.dark
                    ? 'Light Mode'
                    : 'Dark Mode',
              ),
          ],
        );
      case VolunteerTab.schedule:
        return AppBar(
          title: const Text('My Schedule'),
          flexibleSpace: Theme.of(context).brightness == Brightness.dark
              ? null
              : Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                ),
          actions: [
            if (widget.toggleTheme != null)
              IconButton(
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: widget.toggleTheme,
                tooltip: Theme.of(context).brightness == Brightness.dark
                    ? 'Light Mode'
                    : 'Dark Mode',
              ),
          ],
        );
      case VolunteerTab.profile:
        return AppBar(
          title: const Text('My Profile'),
          flexibleSpace: Theme.of(context).brightness == Brightness.dark
              ? null
              : Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                ),
          actions: [
            if (widget.toggleTheme != null)
              IconButton(
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: widget.toggleTheme,
                tooltip: Theme.of(context).brightness == Brightness.dark
                    ? 'Light Mode'
                    : 'Dark Mode',
              ),
          ],
        );
    }
  }

  Widget _buildHomeTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0a0e27) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      color: bgColor,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _fetchAssignedItems(),
            _fetchSchedules(),
            _fetchAssignments(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero, // Padding handled internally
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModernHeader(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ).animate().fadeIn().slideX(),
              ),
              const SizedBox(height: 12),
              _buildStatsGrid(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ).animate().fadeIn().slideX(),
              ),
              const SizedBox(height: 12),
              _buildQuickActionsRow(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AssignedPickupHistoryScreen(),
                          ),
                        );
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideX(),
              const SizedBox(height: 8),
              _buildRecentActivityList(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final dateString =
        DateFormat('EEEE, d MMMM yyyy').format(now).toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateString,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.grey[600],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 28,
                color: isDark ? Colors.white : Colors.black87,
                fontFamily: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.fontFamily, // Reuse app font
              ),
              children: [
                const TextSpan(
                  text: 'Welcome back, ',
                  style: TextStyle(fontWeight: FontWeight.w300),
                ),
                TextSpan(
                  text: _userNames[_agentId] ?? "Volunteer",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildMotivationalCarousel(),
        ],
      ),
    );
  }

  Widget _buildMotivationalCarousel() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Container(
        key: ValueKey<int>(_currentCarouselIndex),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)], // Indigo 900 -> 600
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A237E).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.volunteer_activism,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _carouselMessages[_currentCarouselIndex]['title']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _carouselMessages[_currentCarouselIndex]['subtitle']!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    // Calculate stats
    final assignedCount = _assignedItems
        .where((item) => item['deliveryStatus'] == 'assigned')
        .length;

    final collectedCount = _assignedItems
        .where((item) => item['deliveryStatus'] == 'collected')
        .length;
    final completedCount = _assignedItems
        .where((item) => item['deliveryStatus'] == 'delivered')
        .length;
    final availableDays =
        _schedules.where((s) => s.isAvailable && s.id.isNotEmpty).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use a fixed aspect ratio or calculate based on needs
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            padding: EdgeInsets.zero,
            children: [
              _buildModernStatCard(
                'Collected Tasks',
                collectedCount.toString(),
                Icons.inventory_2,
                Colors.blue, // Reverted to blue as requested
              ),
              _buildModernStatCard(
                'Assigned Pickups',
                assignedCount.toString(),
                Icons.assignment_ind,
                Colors.orange,
              ),
              _buildModernStatCard(
                'Completed',
                completedCount.toString(),
                Icons.check_circle,
                Colors.green,
              ),
              _buildModernStatCard(
                'Available Days',
                availableDays.toString(),
                Icons.calendar_today,
                Colors.purple,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModernStatCard(
      String title, String value, IconData icon, Color color) {
    // Styling Update: Cleaner, flatter look with soft shadows
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            // Optional: Navigate to relevant tab on tap
            if (title.contains('Available')) {
              setState(() {
                _currentTab = VolunteerTab.schedule;
              });
              _pageController.animateToPage(
                VolunteerTab.schedule.index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else if (title.contains('Completed')) {
              _navigateToDeliveredItems();
            } else if (title.contains('Collected')) {
              setState(() {
                _currentTab = VolunteerTab.tasks;
                _selectedTaskFilter = 'collected';
              });
              _pageController.animateToPage(
                VolunteerTab.tasks.index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else if (title.contains('Assigned')) {
              setState(() {
                _currentTab = VolunteerTab.tasks;
                _selectedTaskFilter =
                    'pending'; // 'pending' filter shows assigned items
              });
              _pageController.animateToPage(
                VolunteerTab.tasks.index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? Colors.white
                            : color.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
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

  void _navigateToDeliveredItems() {
    // Filter delivered items from the assigned items list
    final deliveredItems = _assignedItems
        .where((element) => element['deliveryStatus'] == 'delivered')
        .toList();

    final List<EwasteItem> ewaste = [];
    final List<PlasticItem> plastic = [];
    final List<ClothItem> cloth = [];

    // Segregate items into their respective types
    for (var element in deliveredItems) {
      final item = element['item'];
      final type = element['type'];

      if (type == 'e-waste' && item is EwasteItem) {
        ewaste.add(item);
      } else if (type == 'plastic' && item is PlasticItem) {
        plastic.add(item);
      } else if (type == 'cloth' && item is ClothItem) {
        cloth.add(item);
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveredItemsScreen(
          ewasteItems: ewaste,
          plasticItems: plastic,
          clothItems: cloth,
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildQuickActionButton(
            'History',
            Icons.history,
            const Color(0xFF2E7D32),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AssignedPickupHistoryScreen()),
            ),
          ),
          const SizedBox(width: 12),
          _buildQuickActionButton(
            'Feedback',
            Icons.feedback_outlined,
            Colors.teal,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbackScreen()),
            ),
          ),
          const SizedBox(width: 12),
          _buildQuickActionButton(
            'Help Desk',
            Icons.support_agent,
            Colors.indigo,
            _openHelpDesk,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
    // Create gradient based on the primary color
    final List<Color> gradientColors = [
      color.withValues(alpha: 0.85),
      color.withValues(alpha: 0.65),
    ];

    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivityList() {
    final recentItems = _assignedItems.take(5).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (recentItems.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 48, color: isDark ? Colors.white24 : Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No recent activity',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: recentItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final itemMap = recentItems[index];
        final String deliveryStatus = itemMap['deliveryStatus'];
        final String itemName = itemMap['itemName'];

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getStatusColor(deliveryStatus).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getStatusIcon(deliveryStatus),
                color: _getStatusColor(deliveryStatus),
                size: 20,
              ),
            ),
            title: Text(
              itemName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              _getStatusText(deliveryStatus),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 14, color: isDark ? Colors.white30 : Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildProfileTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _initializeAgent(),
          _fetchAssignedItems(),
          _fetchSchedules(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userNames[_agentId] ?? 'Volunteer Profile',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Active EcoCycle Volunteer',
                          style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Statistics
            const Text(
              'Your Impact',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildVolunteerStatsHeader(),

            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        _buildActionCard(
          'Set Availability',
          'Manage your pickup schedule',
          Icons.calendar_today,
          () => _showAvailabilityDialog(DateTime.now()),
        ),
        const SizedBox(height: 8),
        _buildActionCard(
          'Contact Support',
          'Get help or report issues',
          Icons.support,
          () => _launchUrl('mailto:support@ecocycle.com'),
        ),
        const SizedBox(height: 8),
        _buildActionCard(
          'View Guidelines',
          'Pickup and safety guidelines',
          Icons.book,
          () => _launchUrl('https://ecocycle.com/volunteer-guidelines'),
        ),
      ],
    );
  }

  Widget _buildActionCard(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF2E7D32)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600])),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Widget _buildVolunteerStatsHeader() {
    final pendingItems = _assignedItems
        .where((item) => item['deliveryStatus'] == 'assigned')
        .length;
    final completedItems = _assignedItems
        .where((item) => item['deliveryStatus'] == 'delivered')
        .length;
    final totalTasks = _assignedItems.length;
    final totalScheduleDays =
        _schedules.where((s) => s.isAvailable && s.id.isNotEmpty).length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildVolunteerStatCard(
                  'Pending',
                  pendingItems.toString(),
                  Icons.schedule,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVolunteerStatCard(
                  'Completed',
                  completedItems.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVolunteerStatCard(
                  'Total',
                  totalTasks.toString(),
                  Icons.task,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVolunteerStatCard(
                  'Available',
                  totalScheduleDays.toString(),
                  Icons.calendar_month,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVolunteerStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _calendarCellBuilder(DateTime day, DateTime today,
      {bool isSelected = false,
      bool isToday = false,
      bool isDisabled = false}) {
    // Look for any schedule record for this day using normalized comparison
    final schedule = _schedules.firstWhere(
      (s) => isSameDay(s.date, day),
      orElse: () => VolunteerSchedule(
        id: '',
        volunteerId: _agentId ?? '',
        date: day,
        isAvailable: false,
        createdAt: DateTime.now(),
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // strictly check if the user is marked available and has a valid ID
    final bool isMarkedAvailable =
        schedule.id.isNotEmpty && schedule.isAvailable;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              final normalizedSelection = _normalizeDate(day);
              if (normalizedSelection.isBefore(today)) return;

              setState(() {
                _selectedDay = normalizedSelection;
                _focusedDay = day;
              });
              _showAvailabilityDialog(normalizedSelection);
            },
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDisabled
              ? (isDark ? Colors.grey.shade900 : Colors.grey.shade200)
              : isMarkedAvailable
                  ? (isDark
                      ? Colors.green.shade900.withValues(alpha: 0.5)
                      : Colors.green.shade100)
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                  width: 2)
              : isToday
                  ? Border.all(
                      color: isDark
                          ? Colors.green.shade300
                          : Colors.green.shade700,
                      width: 1.5)
                  : null,
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: isDisabled
                  ? (isDark ? Colors.grey.shade700 : Colors.grey.shade400)
                  : isMarkedAvailable
                      ? (isDark ? Colors.green.shade100 : Colors.green.shade800)
                      : (isDark ? Colors.grey.shade100 : Colors.grey.shade800),
              fontWeight: (isMarkedAvailable || isSelected || isToday)
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleTab() {
    if (_agentId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            tr('agent_auth_required'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.redAccent),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final today = _normalizeDate(now);

    DateTime safeFocusedDay = _focusedDay;
    if (safeFocusedDay.isBefore(today)) {
      safeFocusedDay = today;
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchSchedules();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Stats Header
            _buildVolunteerStatsHeader(),
            const SizedBox(height: 8),
            // Calendar Card
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Set Your Availability',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TableCalendar(
                      firstDay: today,
                      lastDay: today.add(const Duration(days: 90)),
                      focusedDay: safeFocusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      enabledDayPredicate: (day) => !day.isBefore(today),
                      onDaySelected: (selectedDay, focusedDay) {
                        final normalizedSelection = _normalizeDate(selectedDay);
                        if (normalizedSelection.isBefore(today)) return;

                        setState(() {
                          _selectedDay = normalizedSelection;
                          _focusedDay = focusedDay;
                        });
                        _showAvailabilityDialog(normalizedSelection);
                      },
                      onFormatChanged: (format) {
                        setState(() => _calendarFormat = format);
                      },
                      onPageChanged: (focusedDay) {
                        setState(() => _focusedDay = focusedDay);
                      },
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) =>
                            _calendarCellBuilder(day, today),
                        selectedBuilder: (context, day, focusedDay) =>
                            _calendarCellBuilder(day, today, isSelected: true),
                        todayBuilder: (context, day, focusedDay) =>
                            _calendarCellBuilder(day, today, isToday: true),
                        disabledBuilder: (context, day, focusedDay) =>
                            _calendarCellBuilder(day, today, isDisabled: true),
                        outsideBuilder: (context, day, focusedDay) =>
                            _calendarCellBuilder(day, today, isDisabled: true),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.blue.shade900.withValues(alpha: 0.3)
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.blue.shade200
                                  : Colors.blue.shade700,
                              size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Click on a date to mark yourself available or unavailable.',
                              style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.blue.shade100
                                    : Colors.blue.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legendItem(
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.green.shade900.withValues(alpha: 0.5)
                                : Colors.green.shade100,
                            'Available'),
                        const SizedBox(width: 24),
                        _legendItem(
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade800
                                : Colors.grey.shade100,
                            'Not Set'),
                        const SizedBox(width: 24),
                        _legendItem(
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade900
                                : Colors.grey.shade300,
                            'Past Date'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTasksTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_agentId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            tr('agent_auth_required'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.redAccent),
          ),
        ),
      );
    }

    final filteredItems = _assignedItems.where((item) {
      final status = item['deliveryStatus'] as String;
      if (_selectedTaskFilter == 'all') return true;
      if (_selectedTaskFilter == 'pending') return status == 'assigned';

      if (_selectedTaskFilter == 'collected') return status == 'collected';
      if (_selectedTaskFilter == 'delivered') return status == 'delivered';
      return true;
    }).toList();

    return Column(
      children: [
        _buildVolunteerStatsHeader(),
        // Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Assigned', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Collected', 'collected'),
                const SizedBox(width: 8),
                _buildFilterChip('Delivered', 'delivered'),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _fetchAssignedItems();
            },
            child: filteredItems.isEmpty
                ? ListView(
                    // Using ListView for scrollable empty state (for refresh)
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 100),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.orange.shade900
                                        .withValues(alpha: 0.3)
                                    : Colors.orange.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.task,
                                  size: 64, color: Colors.orange.shade400),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No ${_selectedTaskFilter == 'all' ? '' : _selectedTaskFilter} Tasks',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                'No tasks found for this category.',
                                style: TextStyle(color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildTaskCardExtended(item);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedTaskFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedTaskFilter = value);
        }
      },
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildTaskCardExtended(Map<String, dynamic> itemMap) {
    final item = itemMap['item'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = itemMap['deliveryStatus'] as String;
    final statusColor = _getStatusColor(status);
    final isActionable = status == 'assigned' || status == 'collected';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image and Details Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          memCacheHeight: 200,
                          placeholder: (context, url) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 30,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[200],
                          child: const Icon(Icons.electric_bolt,
                              size: 30, color: Colors.grey),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.itemName,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.description,
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),

            // Pickup Location Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade600, Colors.green.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.shade900.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow(
                      Icons.location_on, 'Pickup Location:', item.location),
                  if (item.pickupScheduledAt != null) ...[
                    const SizedBox(height: 8),
                    _detailRow(
                      Icons.schedule,
                      'Scheduled:',
                      DateFormat('MMM d, h:mm a')
                          .format(item.pickupScheduledAt!.toLocal()),
                    ),
                  ],
                ],
              ),
            ),

            // NGO Delivery Instructions Section
            if (item.assignedNgoId != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Builder(
                  builder: (context) {
                    final ngoId = item.assignedNgoId!;
                    final ngoData = _ngoCache[ngoId];

                    if (ngoData == null) {
                      // Only show loading if we really don't have data yet
                      // This should be brief as we pre-fetch
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.green.shade900.withValues(alpha: 0.3)
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? Colors.green.shade700
                                : Colors.green.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(isDark
                                    ? Colors.green.shade200
                                    : Colors.green.shade700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text('Loading delivery center...',
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.green.shade100
                                            : Colors.green.shade700,
                                        fontSize: 12))),
                          ],
                        ),
                      );
                    }

                    final ngoName = ngoData['name'] ?? 'NGO Center';
                    final ngoAddress = ngoData['address'] ?? 'Unknown address';
                    final ngoPhone = ngoData['phone'] ?? 'No phone available';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade600,
                            Colors.green.shade900
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade900.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '📍 Deliver Here:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ngoName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.location_on_outlined,
                                        size: 16,
                                        color: Colors.white
                                            .withValues(alpha: 0.8)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        ngoAddress,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (ngoPhone.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.phone,
                                          size: 16,
                                          color: Colors.white
                                              .withValues(alpha: 0.8)),
                                      const SizedBox(width: 4),
                                      Text(
                                        ngoPhone,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
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
                  },
                ),
              ),
            const SizedBox(height: 16),

            // Action Buttons (Call, Map, Action)
            if (status != 'delivered')
              Row(
                children: [
                  // Call Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callUser(itemMap),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Map Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VolunteerTaskMapScreen(
                              latitude: itemMap['latitude'] ?? 0.0,
                              longitude: itemMap['longitude'] ?? 0.0,
                              destinationName:
                                  itemMap['itemName'] ?? 'Pickup Location',
                              destinationAddress:
                                  itemMap['location'] ?? 'Unknown Address',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('Map'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Action Button
                  if (isActionable)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: item.deliveryStatus == 'assigned'
                            ? () => _handleCollectionVerification(itemMap)
                            : () => _markAsDelivered(itemMap),
                        icon: Icon(
                          item.deliveryStatus == 'assigned'
                              ? Icons.qr_code_scanner
                              : Icons.check_circle,
                          size: 18,
                        ),
                        label: Text(
                          item.deliveryStatus == 'assigned'
                              ? 'Verify'
                              : 'Deliver',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: item.deliveryStatus == 'assigned'
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.blue.shade700;
      case 'collected':
        return Colors.orange.shade700;
      case 'delivered':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showAvailabilityDialog(DateTime date) {
    // Normalizing date for lookup
    final normalizedDate = _normalizeDate(date);

    final schedule = _schedules.firstWhere(
      (s) => isSameDay(s.date, normalizedDate),
      orElse: () => VolunteerSchedule(
        id: '',
        volunteerId: _agentId ?? '',
        date: normalizedDate,
        isAvailable: false,
        createdAt: DateTime.now(),
      ),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Manage Schedule: ${DateFormat('MMM d, yyyy').format(normalizedDate)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Would you like to mark yourself as available for delivery on this date?'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _setAvailability(normalizedDate, true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('I am Available'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            // Check if a valid ID exists to show removal option
            if (schedule.id.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              if (isSameDay(normalizedDate, _normalizeDate(DateTime.now())))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Cannot remove schedule for today.',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _clearAvailabilityByDate(normalizedDate),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove Schedule'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text(
                        'Clears your availability for this date.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
            ],
          ],
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

  Future<void> _setAvailability(DateTime date, bool isAvailable) async {
    if (_agentId == null) return;

    Navigator.pop(context);
    setState(() {});

    try {
      await _scheduleService.setAvailability(_agentId!, date, isAvailable);
      // Brief delay to allow Supabase settle
      await Future.delayed(const Duration(milliseconds: 300));
      await _fetchSchedules();
      _showSnackbar('Available on ${DateFormat('MMM d').format(date)}!');
    } catch (e) {
      _showSnackbar('Error updating availability: $e');
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _clearAvailabilityByDate(DateTime date) async {
    if (isSameDay(date, _normalizeDate(DateTime.now()))) {
      Navigator.pop(context);
      _showSnackbar('Cannot remove schedule for today.');
      return;
    }

    Navigator.pop(context);

    // 1. Identify all schedule records for this specific date BEFORE modifying local state
    final schedulesToRemove =
        _schedules.where((s) => isSameDay(s.date, date)).toList();

    // OPTIMISTIC UPDATE: Clear locally immediately so the green goes away instantly
    setState(() {
      _schedules.removeWhere((s) => isSameDay(s.date, date));
      _selectedDay = null;
    });

    try {
      // 2. Perform remote deletions
      for (var s in schedulesToRemove) {
        if (s.id.isNotEmpty) {
          await _scheduleService.deleteVolunteerSchedule(s.id);
        }
      }

      // 3. Briefly wait for Supabase synchronization to ensure admin sees it as Unset
      await Future.delayed(const Duration(milliseconds: 600));

      // 4. Final re-fetch to ensure everything is in sync
      await _fetchSchedules();
      _showSnackbar('Schedule removed successfully');
    } catch (e) {
      _showSnackbar('Error clearing availability: $e');
      _fetchSchedules(); // Refresh to restore state if deletion failed
    } finally {
      if (mounted) setState(() {});
    }
  }

  void _showMapOverlay() {
    if (_assignedItems.isEmpty) {
      _showSnackbar('No assigned tasks to show on map');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Task Map',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(
                    _assignedItems.first['latitude'] ?? 12.9716,
                    _assignedItems.first['longitude'] ?? 77.5946,
                  ),
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.ecocycle',
                  ),
                  MarkerLayer(
                    markers: _assignedItems.map((item) {
                      return Marker(
                        point: LatLng(
                          (item['latitude'] as num?)?.toDouble() ?? 12.9716,
                          (item['longitude'] as num?)?.toDouble() ?? 77.5946,
                        ),
                        width: 80,
                        height: 80,
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(item['itemName'] as String),
                                content: Text(item['location'] as String),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      Navigator.pop(
                                          context); // Close map dialog
                                      Navigator.pop(context); // Close map sheet
                                      // Ideally scroll to item in list
                                    },
                                    child: const Text('View Details'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callUser(Map<String, dynamic> itemMap) async {
    final item = itemMap['item'];
    final userId = item.userId as String;
    String? phoneNumber = _userPhones[userId];
    String? fullName = _userNames[userId];
    bool isFetching = false;

    // Helper function to extract phone number from location string
    String? extractPhoneFromLocation(String loc) {
      // Look for common phone patterns: +91-XXXXX XXXXX, +91 XXXXXXXXXX, 9876543210 etc.
      final regExp = RegExp(r'(?:\+91[\-\s]?)?[6-9][\d\-\s]{9,13}\d');
      final match = regExp.firstMatch(loc);
      if (match == null) return null;

      String matched = match.group(0)!;
      bool hasPlus = matched.startsWith('+');
      String digits = matched.replaceAll(RegExp(r'[^\d]'), '');

      if (digits.length == 10 ||
          (digits.length == 12 && digits.startsWith('91'))) {
        return hasPlus ? '+$digits' : digits;
      }
      return null;
    }

    bool hasAttemptedFetch = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Trigger fetch only if missing data and not already fetching/tried
          if (userId.isNotEmpty &&
              (phoneNumber == null || phoneNumber!.isEmpty) &&
              !isFetching &&
              !hasAttemptedFetch) {
            isFetching = true;
            hasAttemptedFetch = true;

            _profileService
                .fetchProfile(userId)
                .timeout(const Duration(seconds: 10))
                .then((profile) {
              if (mounted) {
                try {
                  final fName = profile?['full_name']?.toString() ?? 'User';
                  String pNum = profile?['phone_number']?.toString() ?? '';

                  if (pNum.isEmpty) {
                    pNum = extractPhoneFromLocation(item.location) ?? '';
                  }

                  // Update parent only if we actually found something meaningful
                  if (pNum.isNotEmpty || fName != 'User') {
                    setState(() {
                      _userNames[userId] = fName;
                      _userPhones[userId] = pNum;
                    });
                  }

                  setDialogState(() {
                    fullName = fName;
                    phoneNumber = pNum;
                    isFetching = false;
                  });
                } catch (e) {
                  setDialogState(() => isFetching = false);
                }
              }
            }).catchError((_) {
              if (mounted) {
                setDialogState(() {
                  isFetching = false;
                  phoneNumber ??= '';
                });
              }
            });
          } else if (userId.isEmpty && phoneNumber == null) {
            phoneNumber = '';
          }

          final displayPhone = (phoneNumber?.isNotEmpty == true)
              ? phoneNumber!
              : (extractPhoneFromLocation(item.location) ??
                  'Phone number not provided');

          return AlertDialog(
            title: const Text('Contact User'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor:
                      Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.person,
                      size: 35, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 16),
                if (isFetching && (phoneNumber == null || phoneNumber!.isEmpty))
                  const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Fetching contact...',
                          style: TextStyle(fontSize: 12)),
                    ],
                  )
                else ...[
                  Text(
                    fullName ?? 'User',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displayPhone,
                    style: TextStyle(
                      fontSize: 16,
                      color: (displayPhone != 'Phone number not provided')
                          ? Colors.grey[600]
                          : Colors.red,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              if (displayPhone != 'Phone number not provided')
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context); // Close dialog first
                    final cleanPhone = displayPhone.startsWith('+')
                        ? '+$displayPhone'.replaceAll(RegExp(r'\D'), '')
                        : displayPhone.replaceAll(RegExp(r'\D'), '');
                    final uri = Uri.parse('tel:$cleanPhone');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      _showSnackbar('Could not launch phone dialer');
                    }
                  },
                  child: const Text('OK'),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleCollectionVerification(
      Map<String, dynamic> itemMap) async {
    final item = itemMap['item'];
    final dynamic service = itemMap['service'];
    final String itemName = itemMap['itemName'] as String;

    final otpController = TextEditingController();
    bool isOtpSent = false;
    bool isVerifying = false;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Animated Header Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      size: 48,
                      color: Color(0xFF2E7D32),
                    ),
                  )
                      .animate()
                      .scale(duration: 400.ms, curve: Curves.easeOutBack)
                      .fadeIn(duration: 300.ms),
                  const SizedBox(height: 24),

                  // 2. Title and Description
                  Text(
                    'Verification Required',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E7D32),
                        ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 12),
                  Text(
                    tr('otp_verification_instruction', args: [itemName]),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 32),

                  // 3. Dynamic Content Switcher (Send OTP vs Enter OTP)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: !isOtpSent
                        ? SizedBox(
                            key: const ValueKey('send_otp'),
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                try {
                                  setDialogState(() => isVerifying = true);
                                  final otp =
                                      await service.generateAndSaveOtp(item.id);
                                  await _profileService.sendOtpNotification(
                                      item.userId, otp, itemName);
                                  if (context.mounted) {
                                    setDialogState(() {
                                      isOtpSent = true;
                                      isVerifying = false;
                                    });
                                  }
                                  _showSnackbar(
                                      'Verification code sent to user!');
                                } catch (e) {
                                  if (context.mounted) {
                                    setDialogState(() => isVerifying = false);
                                  }
                                  _showSnackbar('Error sending OTP: $e');
                                }
                              },
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: const Color(0xFF2E7D32),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: isVerifying
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                              label: Text(
                                isVerifying ? 'Sending...' : 'Send OTP to User',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        : Column(
                            key: const ValueKey('enter_otp'),
                            children: [
                              TextField(
                                controller: otpController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 8,
                                ),
                                decoration: InputDecoration(
                                  hintText: '000000',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade300,
                                    letterSpacing: 8,
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context)
                                          .inputDecorationTheme
                                          .fillColor ??
                                      Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF2E7D32), width: 2),
                                  ),
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                ),
                                onChanged: (value) {
                                  if (value.length == 6) {
                                    setDialogState(() {});
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 16, color: Colors.green[700]),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Code sent via email/notification',
                                    style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: otpController.text.length == 6
                                      ? () {
                                          Navigator.pop(context, true);
                                        }
                                      : null, // Disable until 6 digits
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    backgroundColor: const Color(0xFF2E7D32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                  ),
                                  child: const Text('Verify & Collect',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setDialogState(() => isOtpSent = false);
                                },
                                child: const Text(
                                  'Resend Code',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                  ),

                  // 4. Cancel Button
                  if (!isOtpSent) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                      ),
                      child: const Text('Cancel Verification'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    );

    if (verified == true) {
      try {
        await service.markAsCollected(item.id, providedOtp: otpController.text);
        _fetchAssignedItems();

        // Show success animation/dialog instead of just snackbar?
        // keeping snackbar for now to be safe, but making it consistent.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Collection successfully verified!'),
                ],
              ),
              backgroundColor: Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        _showSnackbar('Error verifying collection: $e');
      }
    }
  }

  Future<void> _fetchAllSchedules() async {
    try {
      final schedules = await _scheduleService.fetchAllSchedules();
      setState(() => _allSchedules = schedules);
    } catch (e) {
      _showSnackbar('Error loading all schedules: $e');
    }
  }

  Future<void> _fetchApplications() async {
    try {
      final apps = await _profileService.fetchAllApplications();
      setState(() => _applications = apps);
    } catch (e) {
      _showSnackbar('Error loading applications: $e');
    }
  }

  Future<void> _fetchUserNames() async {
    try {
      final profiles = await _profileService.fetchAllProfiles();
      final Map<String, String> namesMap = {};
      final Map<String, String> phonesMap = {};
      for (final profile in profiles) {
        final id = profile['id'] as String?;
        if (id != null) {
          namesMap[id] = profile['full_name']?.toString() ?? 'User';
          phonesMap[id] = profile['phone_number']?.toString() ?? '';
        }
      }
      if (mounted) {
        setState(() {
          _userNames = namesMap;
          _userPhones = phonesMap;
        });
      }
    } catch (e) {
      _showSnackbar('Error loading user names: $e');
    }
  }

  Widget _buildAdminOverviewTab() {
    final pendingApps =
        _applications.where((a) => a.status == 'pending').length;
    final totalVolunteers = _userNames.length;
    final availableToday = _allSchedules
        .where((s) => s.isAvailable && isSameDay(s.date, DateTime.now()))
        .length;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        return Future.value();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Volunteer Management Overview',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildModernStatCard(
                    'Pending Applications',
                    pendingApps.toString(),
                    Icons.person_add,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModernStatCard(
                    'Total Volunteers',
                    totalVolunteers.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildModernStatCard(
                    'Available Today',
                    availableToday.toString(),
                    Icons.calendar_today,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModernStatCard(
                    'Active Assignments',
                    _allSchedules.length.toString(),
                    Icons.assignment,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminApplicationsTab() {
    final pendingApps =
        _applications.where((a) => a.status == 'pending').toList();

    if (pendingApps.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'No pending applications',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
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
                        onPressed: () => _handleApplicationDecision(app, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _handleApplicationDecision(app, true),
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

  Widget _buildAdminSchedulesTab() {
    if (_allSchedules.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No volunteer schedules',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Group schedules by date
    final groupedSchedules = <DateTime, List<VolunteerSchedule>>{};
    for (final schedule in _allSchedules) {
      final date =
          DateTime(schedule.date.year, schedule.date.month, schedule.date.day);
      groupedSchedules[date] = (groupedSchedules[date] ?? [])..add(schedule);
    }

    final sortedDates = groupedSchedules.keys.toList()..sort();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
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
                              _userNames[schedule.volunteerId] ??
                                  'Unknown Volunteer',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: schedule.isAvailable
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
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

  Widget _buildAdminAssignmentsTab() {
    if (_adminAssignments.isEmpty) {
      return _buildEmptyState('No assignments found', Icons.assignment);
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _adminAssignments.length,
      itemBuilder: (context, index) {
        final assignmentData = _adminAssignments[index];
        final assignment = assignmentData['assignment'] as VolunteerAssignment;
        final item = assignmentData['item'] as Map<String, dynamic>;
        final user = assignmentData['user'] as Map<String, dynamic>;
        final volunteer = assignmentData['volunteer'] as Map<String, dynamic>;

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
                // Assignment header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getAssignmentStatusColor(assignment.status)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getAssignmentStatusIcon(assignment.status),
                        color: _getAssignmentStatusColor(assignment.status),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['item_name'] ?? 'Unknown Item',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Status: ${assignment.status}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // User and Volunteer info
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'User',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            user['full_name'] ?? 'Unknown User',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            user['phone_number'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Volunteer',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            volunteer['full_name'] ?? 'Unknown Volunteer',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            volunteer['phone_number'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Location and actions
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item['location'] ?? 'No location',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Action buttons
                Row(
                  children: [
                    if (assignment.status == 'assigned')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateAssignmentStatus(
                              assignment.id, 'completed'),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Mark Complete',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _cancelAssignment(assignment.id, item['id']),
                        icon: const Icon(Icons.cancel, size: 16),
                        label: const Text('Cancel',
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

  Future<void> _handleApplicationDecision(
      VolunteerApplication app, bool approve) async {
    try {
      await _profileService.decideOnApplication(app.id, app.userId, approve);
      await _fetchApplications();
      _showSnackbar(approve ? 'Application approved' : 'Application rejected');
    } catch (e) {
      _showSnackbar('Error processing application: $e');
    }
  }
}
