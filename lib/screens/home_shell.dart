import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:EcoCycle/screens/home_screen.dart';
import 'package:EcoCycle/screens/map_screen.dart';
import 'package:EcoCycle/screens/rewards_screen.dart';
import 'package:EcoCycle/screens/settings_screen.dart';
import 'package:EcoCycle/screens/volunteer_dashboard.dart';
import 'package:EcoCycle/screens/admin_dashboard.dart';
import 'package:EcoCycle/core/supabase_config.dart';
import 'package:EcoCycle/services/profile_service.dart';

class HomeShell extends StatefulWidget {
  final VoidCallback toggleTheme;
  const HomeShell({super.key, required this.toggleTheme});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  String? _userRole;
  bool _isLoadingRole = true;
  final _profileService = ProfileService();

  late final List<Widget> _userScreens;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _userScreens = [
      HomeScreen(toggleTheme: widget.toggleTheme),
      const MapScreen(),
      const RewardsScreen(),
      SettingsScreen(toggleTheme: widget.toggleTheme),
    ];
  }

  Future<void> _loadUserRole() async {
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
        debugPrint('--- USER ROLE FETCHED: $_userRole ---');
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
    if (_isLoadingRole) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 1. ROUTE ADMIN
    if (_userRole == 'admin') {
      return const AdminDashboard();
    }

    // 2. ROUTE AGENT/VOLUNTEER
    if (_userRole == 'agent' || _userRole == 'volunteer') {
      return const VolunteerDashboard();
    }

    // 3. STANDARD USER NAVIGATION
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
            icon: const Icon(Icons.home),
            label: tr('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.map_outlined),
            label: tr('map'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.star_outline),
            label: tr('rewards'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: tr('settings'),
          ),
        ],
      ),
    );
  }
}
