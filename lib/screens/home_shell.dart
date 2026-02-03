import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:EcoCycle/screens/home_screen.dart';
import 'package:EcoCycle/screens/tracking_screen.dart';
import 'package:EcoCycle/screens/rewards_screen.dart';
import 'package:EcoCycle/screens/volunteer_dashboard.dart';
import 'package:EcoCycle/screens/admin_dashboard.dart';
import 'package:EcoCycle/screens/volunteer_choice_screen.dart';
import 'package:EcoCycle/core/supabase_config.dart';
import 'package:EcoCycle/services/profile_service.dart';

class HomeShell extends StatefulWidget {
  final VoidCallback toggleTheme;
  final String? forcedRole;
  const HomeShell({super.key, required this.toggleTheme, this.forcedRole});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 1; // Start with Home selected
  String? _userRole;
  bool _isLoadingRole = true;
  final _profileService = ProfileService();

  late final List<Widget> _userScreens;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _userScreens = [
      const TrackingScreen(),
      HomeScreen(toggleTheme: widget.toggleTheme),
      const RewardsScreen(),
    ];
  }

  Future<void> _loadUserRole() async {
    // If forced role is provided, use it directly
    if (widget.forcedRole != null) {
      if (mounted) {
        setState(() {
          _userRole = widget.forcedRole;
          _isLoadingRole = false;
        });
        debugPrint('FORCED USER ROLE: $_userRole');
      }
      return;
    }

    final user = AppSupabase.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingRole = false);
      return;
    }

    try {
      // Fetch the full profile containing the 'user_role' field
      final profile = await _profileService.fetchProfile(user.id);

      if (mounted) {
        setState(() {
          // CRITICAL: Accessing the 'user_role' key (matching SQL schema)
          final fetchedRole = profile?['user_role']?.toString().toLowerCase();
          _userRole = fetchedRole ?? 'user';
          _isLoadingRole = false;
        });

        // DEBUG PRINT: Log the role for troubleshooting
        debugPrint('LOGIN: User role fetched: $_userRole');
      }
    } catch (e) {
      debugPrint('Error fetching user role for routing: $e');
      if (mounted) {
        setState(() {
          _userRole = 'user';
          _isLoadingRole = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL FIX: Always show loading until role is determined
    // This prevents race conditions where volunteer choice screen doesn't show
    if (_isLoadingRole || _userRole == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // DEBUG: Log the final routing decision
    debugPrint(
        'ROUTING DECISION: role=$_userRole, forcedRole=${widget.forcedRole}');

    // 1. ROUTE ADMIN
    if (_userRole == 'admin') {
      debugPrint('ROUTING: Admin dashboard');
      return const AdminDashboard();
    }

    // 2. ROUTE AGENT
    if (_userRole == 'agent') {
      debugPrint('ROUTING: Agent dashboard');
      return const VolunteerDashboard();
    }

    // 3. ROUTE VOLUNTEER - Show choice screen if no forced role
    if (_userRole == 'volunteer' && widget.forcedRole == null) {
      debugPrint('ROUTING: Volunteer choice screen (no forced role)');
      return VolunteerChoiceScreen(onThemeToggle: widget.toggleTheme);
    }

    // 4. ROUTE FORCED VOLUNTEER/USER
    if (_userRole == 'volunteer' || widget.forcedRole == 'volunteer') {
      debugPrint('ROUTING: Volunteer dashboard (forced or confirmed)');
      return const VolunteerDashboard();
    }

    // 5. STANDARD USER NAVIGATION
    debugPrint('ROUTING: Standard user navigation');
    return Scaffold(
      body: _userScreens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.track_changes),
            label: tr('tracking'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: tr('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.star_outline),
            label: tr('rewards'),
          ),
        ],
      ),
    );
  }
}
