import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ecocycle/screens/home_screen.dart';
import 'package:ecocycle/screens/tracking_screen.dart';
import 'package:ecocycle/screens/rewards_screen.dart';
import 'package:ecocycle/screens/volunteer_dashboard.dart';
import 'package:ecocycle/screens/admin_dashboard.dart';
import 'package:ecocycle/screens/volunteer_choice_screen.dart';
import 'package:ecocycle/core/supabase_config.dart';
import 'package:ecocycle/services/profile_service.dart';

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
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _userScreens = [
      const TrackingScreen(),
      HomeScreen(toggleTheme: widget.toggleTheme),
      const RewardsScreen(),
    ];
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    // If forced role is provided, use it directly
    if (widget.forcedRole != null) {
      if (mounted) {
        setState(() {
          _userRole = widget.forcedRole;
          _isLoadingRole = false;
        });
        // print(...);
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
        // print(...);
      }
    } catch (e) {
      // print(...);
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
      // print(...);
      return const AdminDashboard();
    }

    // 2. ROUTE AGENT
    if (_userRole == 'agent') {
      // print(...);
      return VolunteerDashboard(toggleTheme: widget.toggleTheme);
    }

    // 3. ROUTE VOLUNTEER - Show choice screen if no forced role
    if (_userRole == 'volunteer' && widget.forcedRole == null) {
      // print(...);
      return VolunteerChoiceScreen(onThemeToggle: widget.toggleTheme);
    }

    // 4. ROUTE FORCED VOLUNTEER/USER
    if (_userRole == 'volunteer' || widget.forcedRole == 'volunteer') {
      // print(...);
      return VolunteerDashboard(toggleTheme: widget.toggleTheme);
    }

    // 5. STANDARD USER NAVIGATION
    // print(...);
    return PopScope(
      canPop: _currentIndex == 1, // Only allow pop when on home screen
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 1) {
          // If pop was prevented and not on home, navigate to home
          setState(() => _currentIndex = 1);
          _pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
          },
          children: _userScreens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
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
      ),
    );
  }
}
