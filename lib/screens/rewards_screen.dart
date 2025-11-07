import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class EcoChallenge {
  final String id;
  final String title;
  final String description;
  final int points;
  final bool completed;
  const EcoChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    this.completed = false,
  });
}

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  // This would come from Supabase or an API in production
  List<EcoChallenge> get _challenges => [
        const EcoChallenge(
          id: 'c1',
          title: 'First E-Waste Drop',
          description:
              'Drop off your first e-waste item at a collection center',
          points: 100,
        ),
        const EcoChallenge(
          id: 'c2',
          title: 'Textile Hero',
          description: 'Donate 5 pieces of clothing for recycling',
          points: 150,
        ),
        const EcoChallenge(
          id: 'c3',
          title: 'Eco Navigator',
          description: 'Visit 3 different collection centers',
          points: 200,
          completed: true,
        ),
        const EcoChallenge(
          id: 'c4',
          title: 'Regular Recycler',
          description: 'Drop off items in 3 consecutive months',
          points: 300,
        ),
        const EcoChallenge(
          id: 'c5',
          title: 'Community Champion',
          description: 'Refer 3 friends who make their first drop-off',
          points: 250,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('challenges')),
          bottom: TabBar(
            tabs: [
              Tab(text: tr('challenges')),
              Tab(text: tr('rewards')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Challenges tab
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Points summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('Your EcoPoints',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.eco, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('350',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(tr('active_challenges'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),

                // Challenge cards
                ..._challenges.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: c.completed
                                ? Colors.green.shade100
                                : Colors.grey.shade100,
                            child: Icon(
                              c.completed ? Icons.check : Icons.stars,
                              color: c.completed ? Colors.green : Colors.grey,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(c.title)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.eco,
                                        size: 16, color: Colors.green),
                                    const SizedBox(width: 4),
                                    Text('${c.points}',
                                        style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(c.description),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (ctx) => Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(c.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(height: 8),
                                    Text(c.description),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        const Icon(Icons.eco),
                                        const SizedBox(width: 8),
                                        Text('${c.points} points',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        onPressed: c.completed
                                            ? null
                                            : () {
                                                Navigator.pop(ctx);
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          '${c.title} challenge started!')),
                                                );
                                              },
                                        child: Text(c.completed
                                            ? 'Completed!'
                                            : 'Start Challenge'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    )),
              ],
            ),

            // Rewards tab (placeholder for now)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.redeem, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(tr('rewards_coming_soon')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
