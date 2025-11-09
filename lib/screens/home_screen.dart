import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ecocycle_1/screens/ewaste_dashboard_screen.dart';
import 'package:ecocycle_1/screens/contribute_screen.dart';
import 'package:ecocycle_1/screens/profile_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback toggleTheme;
  const HomeScreen({super.key, required this.toggleTheme});

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
          IconButton(
            tooltip: tr('profile'),
            onPressed: () => _open(context, const ProfileScreen()),
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: toggleTheme,
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
              subtitle: tr('contribute_clothes'),
              color: Colors.indigo,
              onTap: () => _open(context, const ContributeScreen()),
            ),
            const SizedBox(height: 24),

            // Rewards are available in navigation bar; no map/settings quick actions on this page per UX
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
