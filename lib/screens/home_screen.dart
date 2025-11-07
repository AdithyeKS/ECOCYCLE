import 'package:flutter/material.dart';
import 'package:ecocycle_1/widgets/round_action.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final greeting = Text.rich(
      TextSpan(children: [
        const TextSpan(text: 'Hello,\n', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        TextSpan(
          text: 'What would you like to do today?',
          style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
        ),
      ]),
    );

    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const CircleAvatar(radius: 34, backgroundColor: Color(0xFFE7F1EA), child: Icon(Icons.person, size: 36)),
                const SizedBox(width: 16),
                Expanded(child: greeting),
              ]),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  RoundAction(
                    icon: Icons.search,
                    title: 'Search product or shop',
                    onTap: () {},
                  ),
                  RoundAction(
                    icon: Icons.add,
                    title: 'Add a shop into the map',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: RoundAction(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Do a challenge',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
