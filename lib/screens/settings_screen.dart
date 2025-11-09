import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecocycle_1/screens/profile_screen.dart';
import 'package:ecocycle_1/screens/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const SettingsScreen({super.key, required this.toggleTheme});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  String _language = 'English';

  void _logout() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      try {
        await Supabase.instance.client.auth.signOut();
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            ),
            (r) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to sign out: $e')),
          );
        }
      }
    }
  }

  void _deleteAccount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client.auth.admin.deleteUser(user.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text(tr('dark_mode')),
            value: _isDarkMode,
            onChanged: (value) {
              setState(() => _isDarkMode = value);
              widget.toggleTheme();
            },
          ),
          const Divider(),

          // Language selector
          ListTile(
            title: Text(tr('language')),
            trailing: DropdownButton<String>(
              value: _language,
              items: const [
                DropdownMenuItem(value: 'English', child: Text('English')),
                DropdownMenuItem(value: 'Hindi', child: Text('हिन्दी')),
                DropdownMenuItem(value: 'Malayalam', child: Text('മലയാളം')),
              ],
              onChanged: (val) async {
                setState(() => _language = val!);
                if (val == 'English') {
                  await context.setLocale(const Locale('en'));
                } else if (val == 'Hindi') {
                  await context.setLocale(const Locale('hi'));
                } else if (val == 'Malayalam') {
                  await context.setLocale(const Locale('ml'));
                }
              },
            ),
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.person),
            title: Text(tr('profile')),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: Text(tr('delete_account')),
            onTap: _deleteAccount,
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(tr('logout')),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
