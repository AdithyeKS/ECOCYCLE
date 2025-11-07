import 'package:flutter/material.dart';
import 'package:ecocycle_1/core/supabase_config.dart';
import 'package:ecocycle_1/screens/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AppSupabase.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Row(children: [
            const CircleAvatar(radius: 32, child: Icon(Icons.person, size: 34)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(user?.email ?? 'Unknown',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.verified),
            title: Text(user?.emailConfirmedAt != null ? 'Email verified' : 'Email not verified'),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () async {
              await AppSupabase.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          )
        ]),
      ),
    );
  }
}
