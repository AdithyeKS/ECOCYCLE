// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:ecocycle/core/supabase_config.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ecocycle/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _firstName;
  String? _lastName;
  String? _email;
  String? _phoneNumber;
  String? _houseName;
  String? _pinCode;
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
          .select(
              'first_name, last_name, phone_number, house_name, pin_code, total_points')
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        // res may be Map<String, dynamic> or dynamic — handle types safely
        final dynamic firstNameVal = res['first_name'];
        final dynamic lastNameVal = res['last_name'];
        final dynamic phoneVal = res['phone_number'];
        final dynamic houseVal = res['house_name'];
        final dynamic pinCodeVal = res['pin_code'];
        final dynamic pointsVal = res['total_points'];

        int parsedPoints = 0;
        if (pointsVal == null) {
          parsedPoints = 0;
        } else if (pointsVal is int) {
          parsedPoints = pointsVal;
        } else {
          parsedPoints = int.tryParse(pointsVal.toString()) ?? 0;
        }

        setState(() {
          _firstName = firstNameVal?.toString();
          _lastName = lastNameVal?.toString();
          _phoneNumber = phoneVal?.toString();
          _houseName = houseVal?.toString();
          _pinCode = pinCodeVal?.toString();
          _totalPoints = parsedPoints;
        });
      } else {
        // If profile row missing, create it and reload
        await AppSupabase.client.from('profiles').insert({
          'id': userId,
          'first_name': _email?.split('@').first ?? 'User',
          'total_points': 0,
        });
        // Reload once after insert
        await _loadProfile();
        return;
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
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
        title = tr('edit_phone');
        label = tr('phone');
        keyboardType = TextInputType.phone;
        break;
      case 'house_name':
        title = tr('edit_house');
        label = tr('house_name');
        keyboardType = TextInputType.streetAddress;
        break;
      case 'pin_code':
        title = tr('edit_pincode');
        label = tr('pin_code');
        keyboardType = TextInputType.number;
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
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(tr('save')),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (val == null) return;

    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      final Map<String, dynamic> data = {'id': user.id};

      switch (field) {
        case 'phone':
          data['phone_number'] = val.trim().isEmpty ? null : val.trim();
          break;
        case 'house_name':
          data['house_name'] = val.trim().isEmpty ? null : val.trim();
          break;
        case 'pin_code':
          data['pin_code'] = val.trim().isEmpty ? null : val.trim();
          break;
      }

      await AppSupabase.client.from('profiles').upsert(data);

      // Update local state immediately
      setState(() {
        switch (field) {
          case 'phone':
            _phoneNumber = val.trim().isEmpty ? null : val.trim();
            break;
          case 'house_name':
            _houseName = val.trim().isEmpty ? null : val.trim();
            break;
          case 'pin_code':
            _pinCode = val.trim().isEmpty ? null : val.trim();
            break;
        }
      });

      if (mounted) {
        String successKey = field == 'phone'
            ? 'phone_saved_success'
            : field == 'house_name'
                ? 'house_saved_success'
                : 'pincode_saved_success';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(successKey))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save $field: $e')),
        );
      }
    }
  }

  Future<void> _editName() async {
    final firstController = TextEditingController(text: _firstName ?? '');
    final lastController = TextEditingController(text: _lastName ?? '');

    final confirmed = await showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('edit_name')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstController,
              decoration: InputDecoration(labelText: tr('first_name')),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lastController,
              decoration: InputDecoration(labelText: tr('last_name')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('save')),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed != true) return;

    try {
      final user = AppSupabase.client.auth.currentUser;
      if (user == null) return;

      await AppSupabase.client.from('profiles').upsert({
        'id': user.id,
        'first_name': firstController.text.trim(),
        'last_name': lastController.text.trim(),
      });

      setState(() {
        _firstName = firstController.text.trim();
        _lastName = lastController.text.trim();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('name_saved_success'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save name: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSupabase.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('profile')),
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
                            color: Colors.black.withValues(alpha: 0.05),
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
                                            '${_firstName ?? ''} ${_lastName ?? ''}'
                                                    .trim()
                                                    .isEmpty
                                                ? (_email?.split('@').first ??
                                                    'Unknown User')
                                                : '${_firstName ?? ''} ${_lastName ?? ''}',
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
                                      Text(
                                        tr('total_ecopoints'),
                                        style: const TextStyle(
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
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('personal_info'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _profileField(
                            icon: Icons.phone_outlined,
                            label: tr('phone'),
                            value: _phoneNumber ?? 'Not set',
                            onEdit: () => _editField('phone', _phoneNumber),
                          ),
                          _profileField(
                            icon: Icons.home_outlined,
                            label: tr('house_name'),
                            value: _houseName ?? 'Not set',
                            onEdit: () => _editField('house_name', _houseName),
                          ),
                          _profileField(
                            icon: Icons.pin_drop_outlined,
                            label: tr('pin_code'),
                            value: _pinCode ?? 'Not set',
                            onEdit: () => _editField('pin_code', _pinCode),
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
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('account_status'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: user?.emailConfirmedAt != null
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
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
                                        ? tr('email_verified')
                                        : tr('email_not_verified'),
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
                                    title: Text(tr('confirm_logout')),
                                    content: Text(tr('logout_confirm_msg')),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: Text(tr('cancel')),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red.shade400,
                                        ),
                                        child: Text(tr('logout')),
                                      ),
                                    ],
                                  ),
                                );

                                if (shouldSignOut == true) {
                                  try {
                                    await AppSupabase.client.auth.signOut();
                                    if (!context.mounted) return;
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (_) => const LoginScreen(),
                                      ),
                                      (r) => false,
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Failed to sign out: $e')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.logout),
                              label: Text(tr('logout')),
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
