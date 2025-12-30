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

  // NEW: Supervisor info fields
  String? _supervisorName;
  String? _supervisorPhone;
  bool _supervisorLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// Fetches existing profile data and pre-fills the form
  /// FIXED: Now also loads supervisor information
  Future<void> _loadInitialData() async {
    final user = AppSupabase.client.auth.currentUser;
    if (user != null) {
      try {
        // Load user profile
        final profile = await _profileService.fetchProfile(user.id);
        if (profile != null && mounted) {
          setState(() {
            _nameController.text = profile['full_name'] ?? '';
            _phoneController.text = profile['phone_number'] ?? '';
            _addressController.text = profile['address'] ?? '';
          });
        }

        // FIXED: Also load supervisor information
        final supervisorInfo =
            await _profileService.fetchSupervisorDetails(user.id);
        if (supervisorInfo != null && mounted) {
          setState(() {
            _supervisorName = supervisorInfo['full_name'] ?? 'N/A';
            _supervisorPhone = supervisorInfo['phone_number'] ?? 'N/A';
            _supervisorLoaded = true;
          });
          print('Supervisor loaded: $_supervisorName ($_supervisorPhone)');
        } else {
          if (mounted) {
            setState(() => _supervisorLoaded = true);
          }
          print('No supervisor info available');
        }
      } catch (e) {
        print('Error loading initial data: $e');
        if (mounted) {
          setState(() => _supervisorLoaded = true);
        }
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

  void _showPolicy() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Security & User Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Professionalism: Volunteers must act professionally during waste collection.\n\n'
            '2. User Security: You agree not to misuse any user data or access provided during the collection process.\n\n'
            '3. Safety: You must follow all environmental safety protocols for handling hazardous waste.\n\n'
            '4. Integrity: Collecting waste is a social service for the community. No unauthorized fees should be charged to users.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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
          content:
              Text('You must agree to the Security Policies to proceed.')));
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

      // FIXED: Better error handling
      await _profileService.submitVolunteerApplication(app);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Social Work Application submitted successfully!')));
      }
    } catch (e) {
      print('Submission error: $e');
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
        title: const Text('Volunteer for Social Work'),
        backgroundColor: Colors.green.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Impact the Environment',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
              const SizedBox(height: 8),
              const Text(
                  'Join us in our mission to collect and manage waste effectively. This is a voluntary social service role.',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),

              // FIXED: NEW - Display supervisor information if available
              if (_supervisorLoaded)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    border: Border.all(color: Colors.green.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Supervisor Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Name',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                                Text(
                                  _supervisorName ?? 'Not assigned',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Phone',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                                Text(
                                  _supervisorPhone ?? 'Not available',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Your Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder()),
                validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Contact Number',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder()),
                validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.event_available, color: Colors.green),
                title: Text(_selectedDate == null
                    ? 'When can you start?'
                    : 'Starting on: ${DateFormat('MMM d, yyyy').format(_selectedDate!)}'),
                trailing: TextButton(
                    onPressed: _pickDate, child: const Text('SELECT DATE')),
                shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _motivationController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Your Motivation for Social Work',
                  hintText:
                      'Tell us why you want to help with waste collection...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v?.isEmpty ?? true)
                    ? 'Please share your motivation'
                    : null,
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
                      'I agree to the Security Policies and User Safety Terms.',
                      style: TextStyle(fontSize: 14)),
                  subtitle: InkWell(
                      onTap: _showPolicy,
                      child: const Text('Read our Policy',
                          style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline))),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SUBMIT VOLUNTEER REQUEST'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
