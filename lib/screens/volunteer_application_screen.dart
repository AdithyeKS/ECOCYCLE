import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/supabase_config.dart';
import '../services/profile_service.dart';
import '../models/volunteer_application.dart';

class VolunteerApplicationScreen extends StatefulWidget {
  const VolunteerApplicationScreen({super.key});

  @override
  State<VolunteerApplicationScreen> createState() =>
      _VolunteerApplicationScreenState();
}

class _VolunteerApplicationScreenState
    extends State<VolunteerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _motivationController = TextEditingController();

  DateTime? _selectedDate;
  bool _agreedToPolicy = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// Fetches existing profile data and pre-fills the form
  Future<void> _loadInitialData() async {
    final user = AppSupabase.client.auth.currentUser;
    if (user != null) {
      try {
        final profile = await _profileService.fetchProfile(user.id);
        if (profile != null && mounted) {
          setState(() {
            _nameController.text = profile['full_name'] ?? '';
            _phoneController.text = profile['phone_number'] ?? '';
            _addressController.text = profile['address'] ?? '';
          });
        }
      } catch (e) {
        debugPrint('Error loading initial data: $e');
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  /// Displays the full Terms and Conditions
  void _showPolicy() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms & Conditions of Service'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Section A: Terms of Service',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Divider(),
              Text(
                '1. Status: You acknowledge that volunteering is a non-paid social service and does not constitute an employment contract.\n\n'
                '2. Duration: You agree to commit to the requested dates. If you cannot attend, you must notify the administrator 24 hours in advance.\n\n'
                '3. Equipment: You are responsible for using the mobile application as intended and reporting any technical issues immediately.\n\n'
                '4. Representation: You shall not represent yourself as a legal official or authorized employee of EcoCycle for any purpose other than waste collection.',
              ),
              SizedBox(height: 16),
              Text(
                'Section B: Security & Privacy Policies',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Divider(),
              Text(
                '1. Professionalism: Volunteers must act professionally and respectfully during waste collection at user locations.\n\n'
                '2. User Security: You strictly agree not to misuse, share, or store any user personal data (name, phone, address) outside the app.\n\n'
                '3. Safety: You must follow all environmental safety protocols provided for handling hazardous e-waste materials.\n\n'
                '4. Integrity: No unauthorized fees, tips, or charges should be requested from users. Any such act will result in immediate termination.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I UNDERSTAND'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please complete the form and select a date.')));
      return;
    }

    if (!_agreedToPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You must agree to the Terms & Conditions to proceed.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      final app = VolunteerApplication(
        id: '',
        userId: user.id,
        fullName: _nameController.text.trim(),
        email: user.email ?? '',
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        availableDate: _selectedDate!,
        motivation: _motivationController.text.trim(),
        agreedToPolicy: _agreedToPolicy,
        createdAt: DateTime.now(),
      );

      await _profileService.submitVolunteerApplication(app);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Social Work Application submitted successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Submission failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Volunteer'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Attractive Header Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.8),
                        Theme.of(context).colorScheme.primary.withOpacity(0.4),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.volunteer_activism, size: 64, color: Colors.white),
                      const SizedBox(height: 16),
                      const Text(
                        'Make a Difference Today',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join our community of volunteers in the fight against waste. Help collect and manage e-waste and clothes, making our environment cleaner and greener.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Personal Information Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                            labelText: 'Your Name',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder()),
                        validator: (v) => (v?.isEmpty ?? true) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                            labelText: 'Contact Number',
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder()),
                        validator: (v) => (v?.isEmpty ?? true) ? 'Phone is required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Availability and Motivation Cards...
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Availability & Motivation',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(_selectedDate == null
                            ? 'When can you start?'
                            : 'Starting: ${DateFormat('MMM d, yyyy').format(_selectedDate!)}'),
                        trailing: TextButton(onPressed: _pickDate, child: const Text('SELECT')),
                        shape: RoundedRectangleBorder(
                            side: const BorderSide(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _motivationController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Why do you want to volunteer?',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v?.isEmpty ?? true) ? 'Motivation is required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Agreement Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Terms & Agreement',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade100)),
                        child: CheckboxListTile(
                          value: _agreedToPolicy,
                          onChanged: (v) => setState(() => _agreedToPolicy = v!),
                          title: const Text(
                              'I agree to the Terms of Service and Security Conditions.',
                              style: TextStyle(fontSize: 14)),
                          subtitle: InkWell(
                              onTap: _showPolicy,
                              child: const Text('Read Terms & Conditions',
                                  style: TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline))),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('BECOME A VOLUNTEER', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}