import 'package:flutter/material.dart';
import 'package:ecocycle_1/core/supabase_config.dart';
import 'package:ecocycle_1/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _displayName;
  String? _email;
  String? _phoneNumber;
  int? _age;
  String? _address;
  int _totalPoints = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = AppSupabase.client.auth.currentUser;
    setState(() {
      _email = user?.email;
    });
    try {
      final userId = user?.id;
      if (userId != null) {
        final res = await AppSupabase.client
            .from('profiles')
            .select('full_name, phone_number, age, address, total_points')
            .eq('id', userId)
            .maybeSingle();
        if (res != null) {
          setState(() {
            _displayName = res['full_name'] as String?;
            _phoneNumber = res['phone_number'] as String?;
            _age = res['age'] as int?;
            _address = res['address'] as String?;
            _totalPoints = res['total_points'] as int? ?? 0;
          });
        }
      }
    } catch (e) {
      // Fallback to email prefix for display name
      if (_displayName == null && _email != null) {
        setState(() => _displayName = _email!.split('@').first);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _profileField({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }

  Future<void> _editField(String field, String? currentValue) async {
    final controller = TextEditingController(text: currentValue ?? '');
    String title, label;
    TextInputType? keyboardType;

    switch (field) {
      case 'phone':
        title = 'Edit Phone Number';
        label = 'Phone Number';
        keyboardType = TextInputType.phone;
        break;
      case 'age':
        title = 'Edit Age';
        label = 'Age';
        keyboardType = TextInputType.number;
        break;
      case 'address':
        title = 'Edit Address';
        label = 'Address';
        keyboardType = TextInputType.streetAddress;
        break;
      default:
        return;
    }

    final val = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          keyboardType: keyboardType,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (val == null) return;
    final value = val.trim();
    if (value.isEmpty) return;

    try {
      final user = AppSupabase.client.auth.currentUser;
      final data = <String, dynamic>{'id': user?.id};

      switch (field) {
        case 'phone':
          data['phone_number'] = value;
          setState(() => _phoneNumber = value);
          break;
        case 'age':
          final age = int.tryParse(value);
          if (age == null) return;
          data['age'] = age;
          setState(() => _age = age);
          break;
        case 'address':
          data['address'] = value;
          setState(() => _address = value);
          break;
      }

      await AppSupabase.client.from('profiles').upsert(data);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update $label')),
        );
      }
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _displayName ?? '');
    final val = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Full Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (val == null) return;
    final name = val.trim();
    if (name.isEmpty) return;

    try {
      final user = AppSupabase.client.auth.currentUser;
      await AppSupabase.client
          .from('profiles')
          .upsert({'id': user?.id, 'full_name': name});
      setState(() => _displayName = name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update name')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSupabase.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile header with points
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.green.shade100,
                              child: const Icon(Icons.person,
                                  size: 40, color: Colors.green),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _displayName ??
                                              _email?.split('@').first ??
                                              'Unknown',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: _editName,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _email ?? '',
                                    style:
                                        TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade700,
                                Colors.green.shade500
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.eco,
                                  color: Colors.white, size: 32),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total EcoPoints',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$_totalPoints',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward,
                                  color: Colors.white70),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Personal Information Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _profileField(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: _phoneNumber ?? 'Not set',
                          onEdit: () => _editField('phone', _phoneNumber),
                        ),
                        _profileField(
                          icon: Icons.calendar_today_outlined,
                          label: 'Age',
                          value: _age?.toString() ?? 'Not set',
                          onEdit: () => _editField('age', _age?.toString()),
                        ),
                        _profileField(
                          icon: Icons.location_on_outlined,
                          label: 'Address',
                          value: _address ?? 'Not set',
                          onEdit: () => _editField('address', _address),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account Status',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: user?.emailConfirmedAt != null
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                user?.emailConfirmedAt != null
                                    ? Icons.verified_outlined
                                    : Icons.warning_outlined,
                                color: user?.emailConfirmedAt != null
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  user?.emailConfirmedAt != null
                                      ? 'Email verified'
                                      : 'Email not verified',
                                  style: TextStyle(
                                    color: user?.emailConfirmedAt != null
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              await AppSupabase.client.auth.signOut();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                  (r) => false,
                                );
                              }
                            },
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign out'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
