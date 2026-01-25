import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/ewaste_item.dart';
import '../models/volunteer_schedule.dart';
import '../models/volunteer_assignment.dart';
import '../models/volunteer_application.dart';
import '../services/ewaste_service.dart';
import '../services/volunteer_schedule_service.dart';
import '../services/profile_service.dart';
import '../core/supabase_config.dart';
import 'login_screen.dart';

class VolunteerDashboard extends StatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  final _ewasteService = EwasteService();
  final _scheduleService = VolunteerScheduleService();
  final _profileService = ProfileService();
  List<EwasteItem> _assignedItems = [];
  List<VolunteerSchedule> _schedules = [];
  List<VolunteerAssignment> _assignments = [];
  List<VolunteerApplication> _applications = [];
  List<VolunteerSchedule> _allSchedules = [];
  Map<String, String> _userNames = {};
  bool _isLoading = true;
  bool _isScheduleLoading = false;
  String? _agentId;
  String _userRole = 'user';

  // Calendar state
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _initializeAgent();
  }

  void _initializeAgent() async {
    final user = AppSupabase.client.auth.currentUser;
    if (user != null) {
      _agentId = user.id;
      try {
        final profile = await _profileService.fetchProfile(user.id);
        if (profile != null) {
          _userRole = profile['user_role']?.toString() ?? 'user';
        }
      } catch (e) {
        debugPrint('Error fetching user role: $e');
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
      final items = await _ewasteService.fetchItemsForAgent(_agentId!);
      items.sort((a, b) {
        int statusA = a.deliveryStatus == 'assigned' ? 0 : 1;
        int statusB = b.deliveryStatus == 'assigned' ? 0 : 1;
        return statusA.compareTo(statusB);
      });
      setState(() {
        _assignedItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar('Error loading assigned items: $e');
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
      final assignments =
          await _scheduleService.fetchVolunteerAssignments(_agentId!);
      setState(() => _assignments = assignments);
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
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
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

  // Helper to normalize dates to midnight for consistent comparisons
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == 'admin') {
      return DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Volunteer Management'),
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
                onPressed: () {
                  _fetchAllSchedules();
                  _fetchApplications();
                  _fetchUserNames();
                },
                tooltip: tr('refresh'),
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
      // Regular user/volunteer view
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr('volunteer_dashboard_title')),
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
                onPressed: () {
                  _fetchAssignedItems();
                  _fetchSchedules();
                  _fetchAssignments();
                },
                tooltip: tr('refresh'),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: _logout,
                tooltip: 'Sign Out',
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.calendar_today), text: 'Schedule'),
                Tab(icon: Icon(Icons.assignment), text: 'Assignments'),
                Tab(icon: Icon(Icons.task), text: 'Tasks'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildScheduleTab(),
              _buildAssignmentsTab(),
              _buildTasksTab(),
            ],
          ),
        ),
      );
    }
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

    // strictly check if the user is marked available and has a valid ID
    final bool isMarkedAvailable =
        schedule.id.isNotEmpty && schedule.isAvailable;

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDisabled
            ? Colors.grey.shade200
            : isMarkedAvailable
                ? Colors.green.shade100
                : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: Colors.blue.shade700, width: 2)
            : isToday
                ? Border.all(color: Colors.green.shade700, width: 1.5)
                : null,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: isDisabled
                ? Colors.grey.shade400
                : isMarkedAvailable
                    ? Colors.green.shade800
                    : Colors.grey.shade800,
            fontWeight: (isMarkedAvailable || isSelected || isToday)
                ? FontWeight.bold
                : FontWeight.normal,
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

    return Column(
      children: [
        TableCalendar(
          firstDay: today,
          lastDay: today.add(const Duration(days: 90)),
          focusedDay: safeFocusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Tap on a future date to set yourself as available or clear an existing schedule.',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendItem(Colors.green.shade100, 'Available'),
                  const SizedBox(width: 16),
                  _legendItem(Colors.grey.shade100, 'Unset'),
                ],
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildAssignmentsTab() {
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

    if (_assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No assignments yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Assignments will appear here when admins assign tasks to you.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assignments.length,
      itemBuilder: (context, index) {
        final assignment = _assignments[index];
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
                    Icon(
                      assignment.taskType == 'ewaste_pickup'
                          ? Icons.recycling
                          : Icons.checkroom,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Task: ${assignment.taskType.replaceAll('_', ' ').toUpperCase()}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getAssignmentStatusColor(assignment.status)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        assignment.status.toUpperCase(),
                        style: TextStyle(
                          color: _getAssignmentStatusColor(assignment.status),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (assignment.assignedAt != null)
                  Text(
                    'Assigned: ${DateFormat('MMM d, yyyy').format(assignment.assignedAt!)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                if (assignment.scheduledDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Scheduled: ${DateFormat('MMM d, yyyy').format(assignment.scheduledDate!)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
                if (assignment.notes != null &&
                    assignment.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Notes: ${assignment.notes}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
                const SizedBox(height: 12),
                if (assignment.status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _updateAssignmentStatus(
                              assignment.id, 'accepted'),
                          icon: const Icon(Icons.check),
                          label: const Text('Accept'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _updateAssignmentStatus(
                              assignment.id, 'cancelled'),
                          icon: const Icon(Icons.close),
                          label: const Text('Decline'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (assignment.status == 'accepted')
                  FilledButton.icon(
                    onPressed: () =>
                        _updateAssignmentStatus(assignment.id, 'completed'),
                    icon: const Icon(Icons.done),
                    label: const Text('Mark Complete'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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

    if (_assignedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              tr('no_assigned_pickups'),
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              tr('check_back_later'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assignedItems.length,
      itemBuilder: (context, index) {
        final item = _assignedItems[index];
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
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: 70,
                                height: 70,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image_not_supported,
                                    size: 30),
                              ),
                            )
                          : const Icon(Icons.image_not_supported, size: 70),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: TextStyle(color: Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _detailRow(Icons.location_on, 'Location:', item.location),
                if (item.pickupScheduledAt != null)
                  _detailRow(
                    Icons.schedule,
                    'Scheduled:',
                    DateFormat('MMM d, h:mm a')
                        .format(item.pickupScheduledAt!.toLocal()),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(item.deliveryStatus)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.deliveryStatus.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(item.deliveryStatus),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (item.deliveryStatus == 'assigned')
                      FilledButton.icon(
                        onPressed: () => _markAsCollected(item),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(tr('mark_collected')),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                        ),
                      )
                    else if (item.deliveryStatus == 'collected')
                      FilledButton.icon(
                        onPressed: () => _markAsDelivered(item),
                        icon: const Icon(Icons.local_shipping, size: 18),
                        label: Text(tr('mark_delivered')),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
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
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _clearAvailabilityByDate(normalizedDate),
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
    setState(() => _isScheduleLoading = true);

    try {
      await _scheduleService.setAvailability(_agentId!, date, isAvailable);
      // Brief delay to allow Supabase settle
      await Future.delayed(const Duration(milliseconds: 300));
      await _fetchSchedules();
      _showSnackbar('Available on ${DateFormat('MMM d').format(date)}!');
    } catch (e) {
      _showSnackbar('Error updating availability: $e');
    } finally {
      if (mounted) setState(() => _isScheduleLoading = false);
    }
  }

  Future<void> _clearAvailabilityByDate(DateTime date) async {
    Navigator.pop(context);

    // OPTIMISTIC UPDATE: Clear locally immediately so the green goes away instantly
    setState(() {
      _schedules.removeWhere((s) => isSameDay(s.date, date));
      _selectedDay = null;
      _isScheduleLoading = true;
    });

    try {
      // 1. Identify all schedule records for this specific date from our previous state
      // (Using a copy to avoid concurrent modification issues if needed)
      final schedulesToRemove =
          _schedules.where((s) => isSameDay(s.date, date)).toList();

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
      if (mounted) setState(() => _isScheduleLoading = false);
    }
  }

  Future<void> _updateAssignmentStatus(
      String assignmentId, String status) async {
    try {
      await _scheduleService.updateAssignmentStatus(assignmentId, status);
      await _fetchAssignments();
      _showSnackbar('Assignment status updated');
    } catch (e) {
      _showSnackbar('Error updating assignment: $e');
    }
  }

  Color _getAssignmentStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
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
      for (final profile in profiles) {
        namesMap[profile['id'] as String] = profile['full_name'] as String;
      }
      setState(() => _userNames = namesMap);
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

    return SingleChildScrollView(
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
                child: _buildStatCard(
                  'Pending Applications',
                  pendingApps.toString(),
                  Icons.person_add,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
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
                child: _buildStatCard(
                  'Available Today',
                  availableToday.toString(),
                  Icons.calendar_today,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
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
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
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

  Widget _buildAdminAssignmentsTab() {
    // For admin, show all assignments across all volunteers
    // This would require fetching all assignments, but for now show a placeholder
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Assignments management coming soon',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
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
