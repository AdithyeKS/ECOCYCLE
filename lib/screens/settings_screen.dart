import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:EcoCycle/screens/profile_screen.dart';
import 'package:EcoCycle/screens/login_screen.dart';
import 'package:EcoCycle/services/feedback_service.dart';
import 'package:EcoCycle/models/feedback.dart';

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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
            child: const Text('Sign Out'),
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

  void _showFeedbackDialog() {
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController messageController = TextEditingController();
    String selectedCategory = 'general';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Submit Feedback'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'Brief title for your feedback',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(value: 'bug', child: Text('Bug Report')),
                    DropdownMenuItem(
                        value: 'feature', child: Text('Feature Request')),
                    DropdownMenuItem(value: 'support', child: Text('Support')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedCategory = value!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Describe the issue or provide feedback...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (subjectController.text.trim().isNotEmpty &&
                    messageController.text.trim().isNotEmpty) {
                  try {
                    final feedbackService = FeedbackService();
                    await feedbackService.submitFeedback(
                      subject: subjectController.text.trim(),
                      message: messageController.text.trim(),
                      category: selectedCategory,
                    );
                    Navigator.of(ctx).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thank you for your feedback!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    Navigator.of(ctx).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to submit feedback: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        // TODO: Implement actual account deletion via backend
        await Supabase.instance.client.auth.signOut();
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            ),
            (r) => false,
          );
        }
        // Show success message after navigation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Account deletion requested. You have been signed out.'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete account: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(tr('settings')),
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Appearance Section
          _buildSectionHeader('Appearance', Icons.palette),
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(tr('dark_mode')),
                  value: isDarkMode,
                  onChanged: (value) {
                    setState(() => _isDarkMode = value);
                    widget.toggleTheme();
                  },
                  secondary: Icon(
                    isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      Icon(Icons.language, color: theme.colorScheme.primary),
                  title: Text(tr('language')),
                  trailing: DropdownButton<String>(
                    value: _language,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                          value: 'English', child: Text('English')),
                      DropdownMenuItem(value: 'Hindi', child: Text('हिन्दी')),
                      DropdownMenuItem(
                          value: 'Malayalam', child: Text('മലയാളം')),
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
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Account Section
          _buildSectionHeader('Account', Icons.account_circle),
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.person, color: theme.colorScheme.primary),
                  title: Text(tr('profile')),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      Icon(Icons.feedback, color: theme.colorScheme.primary),
                  title: const Text('Feedback'),
                  subtitle: const Text('Report issues or provide feedback'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showFeedbackDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      Icon(Icons.history, color: theme.colorScheme.primary),
                  title: const Text('Feedback History'),
                  subtitle: const Text('View your feedback and responses'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showFeedbackHistory,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: Text(tr('logout')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Danger Zone Section
          _buildSectionHeader('Danger Zone', Icons.warning, color: Colors.red),
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _deleteAccount,
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Account'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // App Info
          Center(
            child: Text(
              'EcoCycle v1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showFeedbackHistory() async {
    try {
      final feedbackService = FeedbackService();
      final userFeedback = await feedbackService.fetchAllFeedback();

      // Filter to only show current user's feedback
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final myFeedback =
          userFeedback.where((f) => f.userId == currentUserId).toList();

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('My Feedback History'),
            content: SizedBox(
              width: double.maxFinite,
              child: myFeedback.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No feedback submitted yet.'),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: myFeedback.length,
                      itemBuilder: (context, index) {
                        final feedback = myFeedback[index];
                        final statusColor = feedback.status == 'pending'
                            ? Colors.orange
                            : feedback.status == 'reviewed'
                                ? Colors.blue
                                : feedback.status == 'resolved'
                                    ? Colors.green
                                    : Colors.grey;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        feedback.subject,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        feedback.status.toUpperCase(),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Category: ${feedback.category}',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Your message:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                                Text(
                                  feedback.message,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load feedback history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, {Color? color}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
