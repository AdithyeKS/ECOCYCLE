import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:EcoCycle/screens/add_ewaste_screen.dart';
import 'package:EcoCycle/screens/view_ewaste_screen.dart';
import 'package:EcoCycle/screens/tracking_screen.dart';
import 'package:EcoCycle/screens/rewards_screen.dart';
import 'package:EcoCycle/screens/pickup_request_screen.dart';

class EwasteDashboardScreen extends StatelessWidget {
  const EwasteDashboardScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // NEW PROFESSIONAL TILE WIDGET
  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = Colors.green,
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
        // Using hardcoded string for professional consistency
        title: const Text('E-Waste Recycling Hub'),
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
            // Prominent Welcome/Description Header
            Text(
              'Welcome to the E-Waste Hub',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Contribute, track, and get rewarded for your electronics recycling efforts.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),

            // Main Action Tiles
            _actionTile(
              context,
              icon: Icons.add_circle_outline,
              title: tr('Add New E-Waste Item'),
              subtitle: 'Register your electronics for recycling pickup.',
              color: Colors.blue,
              onTap: () => _open(context, const AddEwasteScreen()),
            ),
            _actionTile(
              context,
              icon: Icons.local_shipping,
              title: tr('Schedule Pickup'),
              subtitle: 'Request and confirm a date/time for item collection.',
              color: Colors.purple,
              onTap: () => _open(context, const PickupRequestScreen()),
            ),
            _actionTile(
              context,
              icon: Icons.track_changes,
              title: tr('View & Track My Items'),
              subtitle: 'Monitor the status of all your submitted e-waste.',
              color: Colors.orange,
              onTap: () => _open(context, const ViewEwasteScreen()),
            ),

            const SizedBox(height: 24),

            // Resource Section Header
            Text(
              'Resources & Rewards',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(height: 20, thickness: 1),

            // Resource Tiles
            _actionTile(
              context,
              icon: Icons.track_changes,
              title: 'Track My Products',
              subtitle:
                  'View current status of your donated products and delivery details.',
              color: Colors.green,
              onTap: () => _open(context, const TrackingScreen()),
            ),
            _actionTile(
              context,
              icon: Icons.emoji_events,
              title: tr('My Eco-Points & Rewards'),
              subtitle: 'View your earned points and available rewards.',
              color: Colors.teal,
              onTap: () => _open(context, const RewardsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
