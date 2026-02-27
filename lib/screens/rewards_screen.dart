import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart'; // FIX: Changed import from .with_effects to standard .dart
import 'package:easy_localization/easy_localization.dart';
import '../core/supabase_config.dart';
import '../services/profile_service.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  int _totalPoints = 0;
  bool _isLoading = true;
  final _profileService = ProfileService();

  // Activity tracking variables are no longer needed since we removed the badge logic
  // int _collectedEwasteCount = 0;
  // int _collectedClothCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // MODIFIED: Simplified data loading to only fetch points
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = AppSupabase.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Fetch Points
      final res = await AppSupabase.client
          .from('profiles')
          .select('total_points')
          .eq('id', user.id)
          .maybeSingle();

      int parsedPoints = 0;
      if (res != null) {
        parsedPoints = (res['total_points'] is int)
            ? res['total_points']
            : int.tryParse(res['total_points'].toString()) ?? 0;
      }

      // Removed badge-related data fetching (ewasteData, clothData)

      if (mounted) {
        setState(() {
          _totalPoints = parsedPoints;
        });
      }
    } catch (e) {
      // print(...);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Removed _getBadges() function

  Future<void> _claimReward(String rewardName, int cost) async {
    final userId = AppSupabase.client.auth.currentUser?.id;
    if (userId == null) return;

    if (_totalPoints < cost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Error: You need $cost points to claim $rewardName.')),
        );
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('confirm_claim', namedArgs: {'rewardName': rewardName})),
        content: Text(
            tr('spend_points_confirm', namedArgs: {'cost': cost.toString()})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel_claim'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('claim_reward_btn'))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _profileService.deductEcoPoints(userId, cost);
        await _loadData(); // Refresh points

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              // NEW: Show reward information specific to a valuable reward
              content: Text(rewardName.contains('Code') ||
                      rewardName.contains('Voucher')
                  ? tr('digital_reward_sent')
                  : tr('claim_success', namedArgs: {'rewardName': rewardName})),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = e.toString().contains('Insufficient EcoPoints')
              ? tr('insufficient_points_msg')
              : '${tr('claim_failed')}: ${e.toString()}';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // Removed _badgeCard() function

  Widget _rewardItem(
      BuildContext context, String name, int cost, IconData icon, Color color) {
    bool canClaim = _totalPoints >= cost;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text('$cost ${tr('points')}'),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: canClaim ? color : Colors.grey.shade400,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed:
              _isLoading || !canClaim ? null : () => _claimReward(name, cost),
          // Show how many more points are needed if the user cannot claim
          child: Text(canClaim
              ? tr('redeem')
              : tr('needed_points',
                  namedArgs: {'needed': (cost - _totalPoints).toString()})),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.scaffoldBackgroundColor;
    final points = _totalPoints.toDouble();
    // Removed call to _getBadges()

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          tr('rewards'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Theme.of(context).brightness == Brightness.dark
            ? null
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)]),
                ),
              ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                          const Icon(Icons.emoji_events,
                              size: 60, color: Colors.white),
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
                    )
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .slideY(begin: 0.3, end: 0),

                    // Removed Badges Section

                    const SizedBox(height: 30),

                    // 🎁 Redeem Rewards
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        tr('redeem_rewards'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Column(
                      children: [
                        // 1. GOOGLE PLAY CODE (Digital, instant value - highest value digital)
                        _rewardItem(
                          context,
                          tr('google_play_reward'), // Higher value code
                          5000,
                          Icons.play_circle_fill,
                          Colors.redAccent,
                        ),
                        // 2. AMAZON VOUCHER (Digital, instant value)
                        _rewardItem(
                          context,
                          tr('amazon_reward'),
                          2500,
                          Icons.redeem,
                          Colors.teal,
                        ),
                        // 3. LOW-VALUE PHYSICAL ITEM (Basic Merchandise)
                        _rewardItem(
                          context,
                          tr('water_bottle_reward'),
                          1500,
                          Icons.water_drop,
                          Colors.blue,
                        ),
                        // 4. LOWEST TIER ITEM
                        _rewardItem(
                          context,
                          tr('tote_bag_reward'),
                          500,
                          Icons.shopping_bag_outlined,
                          Colors.green,
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(duration: 1000.ms)
                        .slideY(begin: 0.3, end: 0),
                  ],
                ),
              ),
            ),
    );
  }
}
