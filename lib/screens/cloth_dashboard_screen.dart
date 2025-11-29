import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:EcoCycle/screens/add_cloth_screen.dart';

class ClothDashboardScreen extends StatelessWidget {
  const ClothDashboardScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // NEW PROFESSIONAL TILE WIDGET (adopted from E-Waste dashboard)
  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = Colors.indigo, // Use indigo for cloth theme
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
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
            // Use indigo/purple shades for a distinct cloth theme
            gradient: LinearGradient(
              colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prominent Welcome/Description Header
            Text(
              'Welcome to the Cloth Donation Hub',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3949AB), // Indigo color
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Easily submit, track, and donate your used clothes for reuse and recycling.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),

            // --- Essential Action Tiles (New Design) ---

            // 1. Donate/Add New Item (Most important action)
            _actionTile(
              context,
              icon: Icons.add_circle_outline,
              title: tr('donate_clothes'),
              subtitle:
                  'Upload a photo, assess condition, and submit for donation.',
              color: Colors.indigo,
              onTap: () {
                _open(context, const AddClothScreen());
              },
            ),

            // 2. View Donations / Tracking
            _actionTile(
              context,
              icon: Icons.track_changes,
              title: tr('view_donations'),
              subtitle: 'Monitor the status and journey of your donated items.',
              color: Colors.orange,
              onTap: () {
                // TODO: Implement view donations screen (reuse ViewEwasteScreen structure)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('view_donations_desc'))),
                );
              },
            ),

            // 3. Schedule Pickup
            _actionTile(
              context,
              icon: Icons.local_shipping,
              title: tr('schedule_pickup'),
              subtitle: 'Request a confirmed date and time for collection.',
              color: Colors.purple,
              onTap: () {
                // TODO: Implement pickup scheduling (reuse PickupRequestScreen structure)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('schedule_pickup_desc'))),
                );
              },
            ),

            const SizedBox(height: 32),

            // --- Secondary Resources (Combined into one section) ---
            Text(
              'Resources',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(height: 20, thickness: 1),

            _actionTile(
              context,
              icon: Icons.location_on,
              title: tr('find_drop_points'),
              subtitle: 'Find the nearest drop-off bins or charity locations.',
              color: Colors.green,
              onTap: () {
                // TODO: Implement drop points map
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('coming_soon'))),
                );
              },
            ),
            _actionTile(
              context,
              icon: Icons.school,
              title: tr('cloth_tips'),
              subtitle:
                  'Learn about textile recycling and sustainable fashion.',
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
      ),
    );
  }
}
