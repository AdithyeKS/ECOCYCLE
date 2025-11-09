import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ClothDashboardScreen extends StatelessWidget {
  const ClothDashboardScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _dashboardCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      Color color = Colors.green}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('cloth_dashboard')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('cloth_welcome'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('cloth_description'),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _dashboardCard(
                  context,
                  icon: Icons.add_circle_outline,
                  title: tr('donate_clothes'),
                  subtitle: tr('donate_clothes_desc'),
                  color: Colors.blue,
                  onTap: () {
                    // TODO: Implement donate clothes screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('coming_soon'))),
                    );
                  },
                ),
                _dashboardCard(
                  context,
                  icon: Icons.list_alt,
                  title: tr('view_donations'),
                  subtitle: tr('view_donations_desc'),
                  color: Colors.orange,
                  onTap: () {
                    // TODO: Implement view donations screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('coming_soon'))),
                    );
                  },
                ),
                _dashboardCard(
                  context,
                  icon: Icons.location_on,
                  title: tr('find_drop_points'),
                  subtitle: tr('find_drop_points_desc'),
                  color: Colors.green,
                  onTap: () {
                    // TODO: Implement drop points map
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('coming_soon'))),
                    );
                  },
                ),
                _dashboardCard(
                  context,
                  icon: Icons.local_shipping,
                  title: tr('schedule_pickup'),
                  subtitle: tr('schedule_pickup_desc'),
                  color: Colors.purple,
                  onTap: () {
                    // TODO: Implement pickup scheduling
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('coming_soon'))),
                    );
                  },
                ),
                _dashboardCard(
                  context,
                  icon: Icons.school,
                  title: tr('cloth_tips'),
                  subtitle: tr('cloth_tips_desc'),
                  color: Colors.teal,
                  onTap: () {
                    // TODO: Implement cloth recycling tips
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('coming_soon'))),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
