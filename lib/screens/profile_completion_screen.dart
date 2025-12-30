import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:EcoCycle/core/supabase_config.dart';
import 'package:EcoCycle/screens/home_shell.dart';
import 'package:EcoCycle/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileCompletionScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const ProfileCompletionScreen({super.key, required this.toggleTheme});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  // Removed: _ageController
  final _addressController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    // Removed age controller disposal
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final user = AppSupabase.client.auth.currentUser;
    if (user == null) {
      if (mounted)
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    _userId = user.id;
    final metadata = user.userMetadata;

    // 1. Pre-fill from auth metadata (set during signup)
    _nameController.text = metadata?['full_name'] ?? '';
    _phoneController.text = metadata?['phone'] ?? '';

    // 2. Try to fetch existing profile data in case user navigated here later
    try {
      final existingProfile = await AppSupabase.client
          // FIX: Removed 'age' from the select query to prevent DB error
          .from('profiles')
          .select('full_name, phone_number, address')
          .eq('id', _userId!)
          .maybeSingle();

      if (existingProfile != null) {
        // Overwrite/update with existing profile data
        _nameController.text =
            existingProfile['full_name']?.toString() ?? _nameController.text;
        _phoneController.text = existingProfile['phone_number']?.toString() ??
            _phoneController.text;
        // Age assignment removed
        _addressController.text = existingProfile['address']?.toString() ?? '';

        // existing role is managed by admin; client doesn't set role
      }
    } catch (e) {
      debugPrint('Error loading existing profile: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _completeProfile() async {
    // Age validation removed
    if (!_formKey.currentState!.validate() || _userId == null) return;

    setState(() => _isSaving = true);

    try {
      // Data to insert/update in the 'profiles' table (role is managed by admin)
      final Map<String, dynamic> profileData = {
        'id': _userId!,
        'full_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        // FIX: Removed 'age' field completely from payload
        'address': _addressController.text.trim(),
        'total_points': 0,
      };

      // Use upsert to handle both new user (insert) and existing user (update) cases
      await AppSupabase.client.from('profiles').upsert(profileData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('profile_complete_success'))),
        );
        // Navigate to the main app shell and remove this screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => HomeShell(toggleTheme: widget.toggleTheme)),
          (route) => false,
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database Error: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Using hardcoded string to prevent key display issue
        title: const Text('Complete Profile'),
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // UI CLEANUP: Using hardcoded string to prevent key display issue
                    Text(
                      tr('essential_details'),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    // UI CLEANUP: Using hardcoded string to prevent key display issue
                    const Text(
                      'Please provide your essential details to finalize your account setup.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    // Full Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: tr('full_name'),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? tr('enter_valid_name')
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: tr('mobile_number'),
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().length < 8)
                          ? tr('enter_valid_phone')
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Address
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: tr('address'),
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? tr('required_field')
                          : null,
                    ),
                    const SizedBox(height: 24),

                    const SizedBox(height: 32),

                    FilledButton.icon(
                      onPressed: _isSaving ? null : _completeProfile,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(tr('save_and_continue'),
                            style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
