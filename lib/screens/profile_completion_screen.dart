import 'package:flutter/material.dart';
import 'package:ecocycle/core/supabase_config.dart';
import 'package:ecocycle/screens/home_shell.dart';
import 'package:ecocycle/services/profile_service.dart';

class ProfileCompletionScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const ProfileCompletionScreen({super.key, required this.toggleTheme});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  @override
  void initState() {
    super.initState();
    // Start the automatic background saving process immediately
    _autoCompleteProfile();
  }

  Future<void> _autoCompleteProfile() async {
    final user = AppSupabase.client.auth.currentUser;
    if (user == null) return;

    try {
      final metadata = user.userMetadata;
      final profileService = ProfileService();

      // Automatically sync metadata to the database profiles table
      await profileService.updateProfile(
        userId: user.id,
        firstName: metadata?['first_name'] ?? 'User',
        lastName: metadata?['last_name'] ?? '',
        phone: metadata?['phone'] ?? '',
        houseName: metadata?['house_name'] ?? '',
        pinCode: metadata?['pin_code'] ?? '',
      );

      if (mounted) {
        // Redirect to Home immediately
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => HomeShell(toggleTheme: widget.toggleTheme)),
          (route) => false,
        );
      }
    } catch (e) {
      // print(...);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return an empty screen with a loading indicator in case of a split-second delay
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
