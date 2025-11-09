// lib/screens/profile_screen.dart
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

  /// Load profile safely and parse types correctly
  Future<void> _loadProfile() async {
    final user = AppSupabase.client.auth.currentUser;
    setState(() {
      _email = user?.email;
      _loading = true;
    });

    try {
      final userId = user?.id;
      if (userId == null) {
        // No logged-in user
        if (mounted) setState(() => _loading = false);
        return;
      }

      final res = await AppSupabase.client
          .from('profiles')
          .select('full_name, phone_number, age, address, total_points')
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        // res may be Map<String, dynamic> or dynamic — handle types safely
        final dynamic fullNameVal = res['full_name'];
        final dynamic phoneVal = res['phone_number'];
        final dynamic ageVal = res['age'];
        final dynamic addressVal = res['address'];
        final dynamic pointsVal = res['total_points'];

        int? parsedAge;
        if (ageVal == null) {
          parsedAge = null;
        } else if (ageVal is int) {
          parsedAge = ageVal;
        } else {
          parsedAge = int.tryParse(ageVal.toString());
        }

        int parsedPoints = 0;
        if (pointsVal == null) {
          parsedPoints = 0;
        } else if (pointsVal is int) {
          parsedPoints = pointsVal;
        } else {
          parsedPoints = int.tryParse(pointsVal.toString()) ?? 0;
        }

        setState(() {
          _displayName = fullNameVal?.toString();
          _phoneNumber = phoneVal?.toString();
          _age = parsedAge;
          _address = addressVal?.toString();
          _totalPoints = parsedPoints;
        });
      } else {
        // If profile row missing, create it and reload
        await AppSupabase.client.from('profiles').insert({
          'id': userId,
          'full_name': _email?.split('@').first ?? '',
          'total_points': 0,
        });
        // Reload once after insert
        await _loadProfile();
        return;
      }
    } catch (e, st) {
      debugPrint('Error loading profile: $e\n$st');
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
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
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

    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      final Map<String, dynamic> data = {'id': user.id};
      int? ageParsed;

      switch (field) {
        case 'phone':
          data['phone_number'] = val.trim().isEmpty ? null : val.trim();
          break;
        case 'age':
          if (val.trim().isEmpty) {
            data['age'] = null;
          } else {
            ageParsed = int.tryParse(val.trim());
            if (ageParsed == null) {
              // invalid number; show message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid age')),
                );
              }
              return;
            }
            data['age'] = ageParsed;
          }
          break;
        case 'address':
          data['address'] = val.trim().isEmpty ? null : val.trim();
          break;
      }

      await AppSupabase.client.from('profiles').upsert(data);

      // Update local state immediately
      setState(() {
        switch (field) {
          case 'phone':
            _phoneNumber = val.trim().isEmpty ? null : val.trim();
            break;
          case 'age':
            _age = val.trim().isEmpty ? null : ageParsed;
            break;
          case 'address':
            _address = val.trim().isEmpty ? null : val.trim();
            break;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label updated successfully')),
        );
      }
    } catch (e) {
      debugPrint('Failed to update $field: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update $field')),
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

    if (val == null || val.trim().isEmpty) return;

    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      await AppSupabase.client
          .from('profiles')
          .upsert({'id': user.id, 'full_name': val.trim()});

      // Update local state immediately
      setState(() {
        _displayName = val.trim();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated successfully')),
        );
      }
    } catch (e) {
      debugPrint('Failed to update name: $e');
      if (mounted) {
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
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
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
                                                'Unknown User',
                                            style: const TextStyle(
                                              fontSize: 22,
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
                                      style: TextStyle(
                                          color: Colors.grey.shade600),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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

                    // Personal Information
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
                                final shouldSignOut = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirm Sign Out'),
                                    content: const Text(
                                        'Are you sure you want to sign out?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
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
                                    await AppSupabase.client.auth.signOut();
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
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Failed to sign out: $e')),
                                      );
                                    }
                                  }
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
            ),
    );
  }
}
