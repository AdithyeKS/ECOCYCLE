import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:EcoCycle/screens/ewaste_dashboard_screen.dart';
import 'package:EcoCycle/screens/cloth_dashboard_screen.dart';
import 'package:EcoCycle/screens/profile_screen.dart';
import 'package:EcoCycle/screens/volunteer_application_screen.dart';
import 'package:EcoCycle/services/profile_service.dart';
import 'package:EcoCycle/core/supabase_config.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const HomeScreen({super.key, required this.toggleTheme});
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userRole = 'user';
  DateTime? _volunteerRequestedAt;
  bool _isDataLoading = true;
  final _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _loadProfileStatus();
  }

  /// Fetches the current user's role and volunteer request status from Supabase
  Future<void> _loadProfileStatus() async {
    final user = AppSupabase.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isDataLoading = false);
      return;
    }
    
    try {
      final profile = await _profileService.fetchProfile(user.id);
      if (profile != null && mounted) {
        setState(() {
          _userRole = profile['user_role']?.toString() ?? 'user';
          final requestedAtVal = profile['volunteer_requested_at'];
          if (requestedAtVal != null) {
             _volunteerRequestedAt = DateTime.tryParse(requestedAtVal.toString());
          }
          _isDataLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile status: $e');
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

  /// Navigates to the professional volunteer application form
  Future<void> _navigateToApplication() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VolunteerApplicationScreen()),
    );
    // If an application was submitted, refresh the status
    if (result == true) {
      _loadProfileStatus();
    }
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  /// Helper widget for dashboard action cards
  Widget _actionCard(BuildContext context, {
    required IconData icon, 
    required String title, 
    required String subtitle, 
    required VoidCallback onTap, 
    Color color = Colors.green
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.06), 
              blurRadius: 8, 
              offset: const Offset(0, 4)
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12), 
              child: Icon(icon, color: color)
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle, 
                    style: const TextStyle(color: Colors.grey, fontSize: 13)
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine UI states based on role and request status
    final bool canRequestVolunteer = _userRole == 'user' && _volunteerRequestedAt == null && !_isDataLoading;
    final bool requestPending = _userRole == 'user' && _volunteerRequestedAt != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('app_title')),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)],
            ),
          ),
        ),
        actions: [
          // Volunteer Request Button (Visible only to standard users with no pending request)
          if (canRequestVolunteer)
             IconButton(
                tooltip: 'Become a Volunteer',
                onPressed: _navigateToApplication,
                icon: const Icon(Icons.volunteer_activism, color: Colors.yellow),
              )
          else if (requestPending)
            IconButton(
                tooltip: 'Application Pending Review',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Your application for social work is currently being reviewed.')),
                ),
                icon: const Icon(Icons.hourglass_empty, color: Colors.orange),
              ),
          
          // Profile Access
          IconButton(
            tooltip: tr('profile'),
            onPressed: () => _open(context, const ProfileScreen()),
            icon: const Icon(Icons.person_outline),
          ),
          
          // Theme Toggle
          IconButton(
            tooltip: 'Toggle Theme',
            onPressed: widget.toggleTheme,
            icon: const Icon(Icons.brightness_6_outlined),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Banner for Pending Applications
            if (requestPending)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Volunteer Request Pending',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Our team is reviewing your application for waste collection social work. You will be notified once approved.',
                            style: TextStyle(
                              color: Colors.orange.shade800, 
                              fontSize: 12
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            // Dashboard Welcome Section
            Row(
              children: [
                Hero(
                  tag: 'logo',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/images/ecocycle.png', width: 64, height: 64),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('hello'), 
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                      ),
                      Text(
                        tr('welcome_msg'), 
                        style: const TextStyle(color: Colors.grey)
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Main Action Modules
            _actionCard(
              context,
              icon: Icons.electric_bolt,
              title: tr('ewaste'),
              subtitle: tr('manage_your_ewaste'),
              color: Colors.deepOrange,
              onTap: () => _open(context, const EwasteDashboardScreen()),
            ),
            const SizedBox(height: 12),
            _actionCard(
              context,
              icon: Icons.shopping_bag_outlined,
              title: tr('cloth'),
              subtitle: tr('manage_your_clothes'),
              color: Colors.indigo,
              onTap: () => _open(context, const ClothDashboardScreen()),
            ),
            
            const SizedBox(height: 24),
            
            // Helpful Tips/Stats section can go here...
          ],
        ),
      ),
    );
  }
}