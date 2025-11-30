import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:EcoCycle/screens/ewaste_dashboard_screen.dart';
import 'package:EcoCycle/screens/cloth_dashboard_screen.dart';
import 'package:EcoCycle/screens/profile_screen.dart';
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

  Future<void> _loadProfileStatus() async {
    final user = AppSupabase.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isDataLoading = false);
      return;
    }
    
    try {
      // Fetch only the role and request status. This is the query that requires the columns to exist.
      final res = await AppSupabase.client
          .from('profiles')
          .select('user_role, volunteer_requested_at')
          .eq('id', user.id)
          .maybeSingle();

      if (res != null) {
        final dynamic roleVal = res['user_role'];
        final dynamic requestedAtVal = res['volunteer_requested_at'];
        
        DateTime? parsedRequestedAt;
        if (requestedAtVal != null && requestedAtVal is String) {
            parsedRequestedAt = DateTime.tryParse(requestedAtVal);
        }

        if (mounted) {
          setState(() {
            _userRole = roleVal?.toString() ?? 'user';
            _volunteerRequestedAt = parsedRequestedAt;
            _isDataLoading = false;
          });
        }
      } else {
         if (mounted) setState(() => _isDataLoading = false);
      }
    } catch (e) {
      // Catch schema errors gracefully so the app still runs, but log the issue.
      debugPrint('Error loading profile status (Likely missing DB column): $e');
      if (mounted) {
        setState(() {
            _userRole = 'user';
            _volunteerRequestedAt = null;
            _isDataLoading = false;
        });
      }
    }
  }

  Future<void> _requestVolunteer() async {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Volunteer Request'),
          content: const Text('Do you want to submit a request to become a pickup volunteer/agent? An admin will review your application.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Request Role'),
            ),
          ],
        ),
      );
      
      if (confirmed == true) {
        try {
          // This call requires the 'volunteer_requested_at' column to exist in Supabase
          await _profileService.requestVolunteerRole(user.id); 
          if (mounted) {
            setState(() {
              _volunteerRequestedAt = DateTime.now();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Volunteer request submitted!')),
            );
          }
        } catch (e) {
          if (mounted) {
            // Display the specific error message visible in your screenshot
            String errorMessage = e.toString().contains('volunteer_requested_at') 
              ? 'Failed to submit request. DATABASE ERROR: The "volunteer_requested_at" column is missing from your Supabase profiles table. Please add it.'
              : 'Failed to submit request: $e';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          }
        }
      }
  }


  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _actionCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      Color color = Colors.green}) {
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
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canRequestVolunteer = _userRole == 'user' && _volunteerRequestedAt == null && !_isDataLoading;
    final bool requestPending = _userRole == 'user' && _volunteerRequestedAt != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('app_title')),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient:
                LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)]),
          ),
        ),
        actions: [
          // NEW: Volunteer Request Button/Icon
          if (canRequestVolunteer)
             IconButton(
                tooltip: 'Become a Volunteer',
                onPressed: _requestVolunteer,
                icon: const Icon(Icons.delivery_dining, color: Colors.yellow),
              )
          else if (requestPending)
            IconButton(
                tooltip: 'Volunteer Request Pending',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Volunteer request sent on ${DateFormat('MMM d').format(_volunteerRequestedAt!)}. Awaiting admin approval.')),
                ),
                icon: const Icon(Icons.hourglass_empty, color: Colors.orange),
              ),

          // Profile Button
          IconButton(
            tooltip: tr('profile'),
            onPressed: () => _open(context, const ProfileScreen()),
            icon: const Icon(Icons.person_outline),
          ),
          // Theme Toggle Button
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: widget.toggleTheme,
            icon: const Icon(Icons.brightness_6_outlined),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Hero(
                  tag: 'logo',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/images/ecocycle.png',
                        width: 72, height: 72, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TweenAnimationBuilder<Offset>(
                    tween: Tween(begin: const Offset(0, 8), end: Offset.zero),
                    duration: const Duration(milliseconds: 600),
                    builder: (context, offset, child) => Transform.translate(
                      offset: offset,
                      child: child,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('hello'),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(tr('welcome_msg'),
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action cards
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

            // Optional: Persistent Volunteer Request Info box below the welcome message
            if (requestPending)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Volunteer Request Status: Pending approval since ${DateFormat('MMM d').format(_volunteerRequestedAt!)}.',
                        style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}