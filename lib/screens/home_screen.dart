import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:EcoCycle/screens/add_ewaste_screen.dart';
import 'package:EcoCycle/screens/add_cloth_screen.dart';
import 'package:EcoCycle/screens/add_plastic_screen.dart'; // NEW: Plastic screen import
import 'package:EcoCycle/screens/profile_screen.dart';
import 'package:EcoCycle/screens/settings_screen.dart';
import 'package:EcoCycle/screens/volunteer_application_screen.dart';
import 'package:EcoCycle/services/profile_service.dart';
import 'package:EcoCycle/core/supabase_config.dart';
import 'package:url_launcher/url_launcher.dart';

enum MenuOption { youtube, profile, settings }

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

  /// Fetches the current user's role and volunteer request status
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
            _volunteerRequestedAt =
                DateTime.tryParse(requestedAtVal.toString());
          }
          _isDataLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile status: $e');
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  /// Professional dashboard action card helper
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
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
    final bool requestPending =
        _userRole == 'user' && _volunteerRequestedAt != null;
    final bool canRequestVolunteer =
        _userRole == 'user' && _volunteerRequestedAt == null && !_isDataLoading;

    return Scaffold(
      appBar: AppBar(
        leading: PopupMenuButton<MenuOption>(
          icon: const Icon(Icons.menu),
          onSelected: (MenuOption result) async {
            switch (result) {
              case MenuOption.youtube:
                const url =
                    'https://www.youtube.com/watch?v=MQLadfsvfLo'; // Placeholder link
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not launch YouTube')),
                  );
                }
                break;
              case MenuOption.profile:
                _open(context, const ProfileScreen());
                break;
              case MenuOption.settings:
                _open(context, SettingsScreen(toggleTheme: widget.toggleTheme));
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<MenuOption>>[
            const PopupMenuItem<MenuOption>(
              value: MenuOption.youtube,
              child: Row(
                children: [
                  Icon(Icons.play_circle_fill, color: Colors.red),
                  SizedBox(width: 8),
                  Text('YouTube Demo'),
                ],
              ),
            ),
            const PopupMenuItem<MenuOption>(
              value: MenuOption.profile,
              child: Row(
                children: [
                  Icon(Icons.person_outline),
                  SizedBox(width: 8),
                  Text('Profile'),
                ],
              ),
            ),
            const PopupMenuItem<MenuOption>(
              value: MenuOption.settings,
              child: Row(
                children: [
                  Icon(Icons.settings),
                  SizedBox(width: 8),
                  Text('Settings'),
                ],
              ),
            ),
          ],
        ),
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
          if (canRequestVolunteer)
            IconButton(
              onPressed: () =>
                  _open(context, const VolunteerApplicationScreen()),
              icon: const Icon(Icons.volunteer_activism, color: Colors.yellow),
            )
          else if (requestPending)
            IconButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Application Pending Review')),
              ),
              icon: const Icon(Icons.hourglass_empty, color: Colors.orange),
            ),
          IconButton(
            onPressed: widget.toggleTheme,
            icon: const Icon(Icons.brightness_6_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Dashboard Welcome Section
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/images/ecocycle.png',
                      width: 64, height: 64),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('hello'),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(tr('welcome_msg'),
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // E-WASTE CARD: Direct to Add E-Waste
            _actionCard(
              context,
              icon: Icons.electric_bolt,
              title: tr('ewaste'),
              subtitle: "Add new e-waste item",
              color: Colors.deepOrange,
              onTap: () => _open(context, const AddEwasteScreen()),
            ),
            const SizedBox(height: 12),

            // CLOTHES CARD: Direct to Add Cloth
            _actionCard(
              context,
              icon: Icons.shopping_bag_outlined,
              title: tr('cloth'),
              subtitle: "Add new cloth item",
              color: Colors.indigo,
              onTap: () => _open(context, const AddClothScreen()),
            ),
            const SizedBox(height: 12),

            // PLASTIC WASTE CARD: Direct to Add Plastic
            _actionCard(
              context,
              icon: Icons.opacity,
              title: "Plastic Waste",
              subtitle: "Recycle bottles and containers",
              color: Colors.blue,
              onTap: () => _open(context, const AddPlasticScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
