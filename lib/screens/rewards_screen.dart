import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double points =
        2450; // Example eco points (replace with Supabase data)

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      appBar: AppBar(
        title: Text(
          tr('rewards'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade600,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 🏅 Points Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.teal.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events, size: 60, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(
                    tr('eco_points'),
                    style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    points.toStringAsFixed(0),
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tr('keep_recycling'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0),

            const SizedBox(height: 30),

            // 🎯 Badges Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr('your_badges'),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ),
            const SizedBox(height: 15),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 15,
              runSpacing: 15,
              children: [
                _badgeCard(Icons.recycling, tr('e_waste_hero'), Colors.green),
                _badgeCard(
                    Icons.shopping_bag, tr('cloth_saver'), Colors.orange),
                _badgeCard(Icons.star, tr('eco_champion'), Colors.blue),
              ],
            ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.4, end: 0),

            const SizedBox(height: 40),

            // 🎁 Redeem Rewards
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr('redeem_rewards'),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ),
            const SizedBox(height: 20),

            Column(
              children: [
                _rewardItem(
                  context,
                  'Eco Tote Bag',
                  '500 ${tr('points')}',
                  Icons.shopping_bag_outlined,
                  Colors.green,
                ),
                _rewardItem(
                  context,
                  'Tree Planting',
                  '1000 ${tr('points')}',
                  Icons.eco_outlined,
                  Colors.teal,
                ),
                _rewardItem(
                  context,
                  'Cloth Donation Voucher',
                  '750 ${tr('points')}',
                  Icons.favorite_outline,
                  Colors.orange,
                ),
              ],
            ).animate().fadeIn(duration: 1000.ms).slideY(begin: 0.3, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _badgeCard(IconData icon, String title, Color color) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 38, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardItem(BuildContext context, String name, String cost,
      IconData icon, Color color) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(cost),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Redeemed $name!')),
            );
          },
          child: Text(tr('redeem')),
        ),
      ),
    );
  }
}
