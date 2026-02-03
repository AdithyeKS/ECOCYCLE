import 'package:flutter/material.dart';
import 'package:EcoCycle/core/supabase_config.dart';
import 'package:EcoCycle/screens/profile_completion_screen.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback? onThemeToggle;
  const SignupScreen({super.key, this.onThemeToggle});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController(); // NEW: Address controller
  final _password = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _obscurePassword = true;

  // Validation Regex
  static final _passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+={}|:;<>,.?/~])(?!.*\s).{8,}$',
  );
  static final _nameRegex = RegExp(r'^[A-Z][a-zA-Z\s]*$');
  static final _phoneRegex = RegExp(r'^\d{10}$');
  static final _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  String _mapSignupError(String rawError) {
    final lowerError = rawError.toLowerCase();

    if (lowerError.contains('already registered') ||
        lowerError.contains('user_already_exists') ||
        lowerError.contains('already exists')) {
      return 'This email is already registered. Please log in instead.';
    }
    if (lowerError.contains('invalid email') ||
        lowerError.contains('email format')) {
      return 'Please enter a valid email address.';
    }
    if (lowerError.contains('weak password') ||
        lowerError.contains('password')) {
      return 'Your password doesn\'t meet our security requirements. Please use a stronger password.';
    }
    if (lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('timeout')) {
      return 'Network connection error. Please check your internet and try again.';
    }
    if (lowerError.contains('validation')) {
      return 'Please check all your information and try again.';
    }
    return 'Unable to create account at this time. Please try again later.';
  }

  Future<void> _signup() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _msg = null;
    });

    try {
      final res = await AppSupabase.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {
          'full_name': _name.text.trim(),
          'phone': _phone.text.trim(),
          'address': _address.text.trim(), // NEW: Save address to metadata
        },
        emailRedirectTo: null,
      );

      if (res.user != null) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileCompletionScreen(
                toggleTheme: widget.onThemeToggle ?? () {}),
          ),
          (route) => false,
        );
      } else {
        setState(() {
          _msg = 'Sign-up failed, try again.';
        });
      }
    } catch (e) {
      setState(() {
        _msg = _mapSignupError(e.toString());
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose(); // NEW: Dispose address
    _password.dispose();
    super.dispose();
  }

  // --- UI Helper Methods ---

  Widget _buildPasswordRequirement(String requirement, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: isValid ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            requirement,
            style: TextStyle(
              color: isValid ? Colors.green.shade700 : Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  bool _checkPasswordRequirement(String value, RegExp pattern) {
    return pattern.hasMatch(value);
  }

  InputDecoration _customInputDecoration(
      {required String labelText,
      required IconData prefixIcon,
      Widget? suffixIcon}) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon:
          Icon(prefixIcon, color: Theme.of(context).colorScheme.primary),
      suffixIcon: suffixIcon,
      fillColor: Theme.of(context).cardColor.withOpacity(0.8),
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passwordText = _password.text;

    final hasMinLength = passwordText.length >= 8;
    final hasUppercase =
        _checkPasswordRequirement(passwordText, RegExp(r'[A-Z]'));
    final hasLowercase =
        _checkPasswordRequirement(passwordText, RegExp(r'[a-z]'));
    final hasNumber = _checkPasswordRequirement(passwordText, RegExp(r'\d'));
    final hasSpecialChar = _checkPasswordRequirement(
        passwordText, RegExp(r'[!@#$%^&*()_+={}|:;<>,.?/~]'));

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.teal.shade800,
                  Colors.green.shade700,
                  Colors.green.shade900,
                ],
              ),
            ),
          ),
          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  elevation: 20,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  color: theme.cardColor.withOpacity(0.95),
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Form(
                      key: _form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Image.asset('assets/images/ecocycle.png',
                                    height: 80),
                                const SizedBox(height: 16),
                                Text('Create Account',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary)),
                                const SizedBox(height: 8),
                                Text('Sign up to join our recycling community',
                                    style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                          // Full name
                          TextFormField(
                            controller: _name,
                            decoration: _customInputDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icons.person_outline),
                            validator: (v) {
                              if (v == null || v.trim().length < 3)
                                return 'Please enter at least 3 characters.';
                              if (!_nameRegex.hasMatch(v.trim()))
                                return 'Please start with a capital letter.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Mobile number
                          TextFormField(
                            controller: _phone,
                            decoration: _customInputDecoration(
                                labelText: 'Mobile number',
                                prefixIcon: Icons.phone_outlined),
                            keyboardType: TextInputType.phone,
                            validator: (v) => (v == null ||
                                    !_phoneRegex.hasMatch(v.trim()))
                                ? 'Please enter a valid phone number (exactly 10 digits).'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          // Email
                          TextFormField(
                            controller: _email,
                            decoration: _customInputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icons.email_outlined),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) =>
                                (v == null || !_emailRegex.hasMatch(v.trim()))
                                    ? 'Please enter a valid email address.'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          // NEW: Address Field
                          TextFormField(
                            controller: _address,
                            maxLines: 2,
                            decoration: _customInputDecoration(
                                labelText: 'Residential Address',
                                prefixIcon: Icons.location_on_outlined),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Please enter your residential address.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          // Password Field
                          TextFormField(
                            controller: _password,
                            onChanged: (value) => setState(() {}),
                            decoration: _customInputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                              ),
                            ),
                            obscureText: _obscurePassword,
                            validator: (v) => (v == null ||
                                    !_passwordRegex.hasMatch(v))
                                ? 'Password must meet all requirements below'
                                : null,
                          ),
                          // Password requirements display...
                          if (passwordText.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildPasswordRequirement(
                                'At least 8 characters', hasMinLength),
                            _buildPasswordRequirement(
                                'One uppercase letter', hasUppercase),
                            _buildPasswordRequirement(
                                'One lowercase letter', hasLowercase),
                            _buildPasswordRequirement('One number', hasNumber),
                            _buildPasswordRequirement(
                                'One special character (!@#\$%...)',
                                hasSpecialChar),
                          ],
                          const SizedBox(height: 24),
                          if (_msg != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.red.shade400, width: 1),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red.shade400, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _msg!,
                                      style: TextStyle(
                                        color: Colors.red.shade400,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy ? null : _signup,
                            style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16)),
                            child: _busy
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('Sign up',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed:
                                _busy ? null : () => Navigator.pop(context),
                            child: const Text('Already have an account?'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
