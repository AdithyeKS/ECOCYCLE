import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ecocycle_1/core/supabase_config.dart';
import 'package:ecocycle_1/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import for UserAttributes

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Regex for strong password validation: Min 8 chars, 1 uppercase, 1 lowercase, 1 digit, 1 special char
  static final _passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+={}|:;<>,.?/~])(?!.*\s).{8,}$',
  );

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _msg = null;
    });

    try {
      // Supabase automatically sets the session upon deep-linking from the email.
      // We use that existing session to update the user's password.
      await AppSupabase.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      // Sign out to force the user to log in with the new password
      await AppSupabase.client.auth.signOut();

      if (mounted) {
        // Navigate back to login screen and remove all other routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
          (r) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('password_update_success')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Only show the message if it's an error and not successful redirection
          _msg = 'Error updating password: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Helper widget to display password requirements
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

  // Function to check individual password requirements
  bool _checkPasswordRequirement(String value, RegExp pattern) {
    return pattern.hasMatch(value);
  }
  
  // Custom Input Decoration for the sleek look (Copied from login_screen.dart)
  InputDecoration _customInputDecoration({
    required String labelText, 
    required IconData prefixIcon, 
    Widget? suffixIcon
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(prefixIcon, color: Theme.of(context).colorScheme.primary),
      suffixIcon: suffixIcon,
      fillColor: Theme.of(context).cardColor.withOpacity(0.8), // Slightly transparent background
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none, // Remove border for a cleaner look
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passwordText = _passwordController.text;

    // Individual checks for real-time feedback
    final hasMinLength = passwordText.length >= 8;
    final hasUppercase = _checkPasswordRequirement(passwordText, RegExp(r'[A-Z]'));
    final hasLowercase = _checkPasswordRequirement(passwordText, RegExp(r'[a-z]'));
    final hasNumber = _checkPasswordRequirement(passwordText, RegExp(r'\d'));
    final hasSpecialChar = _checkPasswordRequirement(passwordText, RegExp(r'[!@#$%^&*()_+={}|:;<>,.?/~]'));

    return Scaffold(
      body: Stack(
        children: [
          // 1. Gradient Background Layer (PWASE Theme)
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
          
          // 2. Thematic Elements Layer (Simulated E-Waste/Recycling Blobs)
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15), 
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 40)],
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.yellow.shade700.withOpacity(0.1), 
                borderRadius: BorderRadius.circular(50),
                boxShadow: [BoxShadow(color: Colors.yellow.shade700.withOpacity(0.2), blurRadius: 30)],
              ),
            ),
          ),
          Positioned(
            top: 200,
            right: 10,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.lightGreenAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // 3. Main Content Layer (Centered Card)
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
                      key: _formKey,
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
                                Text('Set New Password',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                                const SizedBox(height: 8),
                                Text('Please enter and confirm your new password.',
                                    style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),

                          // New Password Field
                          TextFormField(
                            controller: _passwordController,
                            onChanged: (value) => setState(() {}), // Trigger rebuild for strength indicator
                            decoration: _customInputDecoration(
                              labelText: 'New Password',
                              prefixIcon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                      color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            obscureText: _obscurePassword,
                            validator: (v) {
                              if (v == null || v.length < 8) {
                                return 'Minimum 8 characters required.';
                              }
                              if (!_passwordRegex.hasMatch(v)) {
                                return 'Password must meet all security requirements.';
                              }
                              return null;
                            },
                          ),
                          
                          // Password Requirements List
                          const SizedBox(height: 8),
                          if (passwordText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Password requirements:', style: TextStyle(color: theme.hintColor, fontSize: 13, fontWeight: FontWeight.w500)),
                                  _buildPasswordRequirement('Minimum 8 characters', hasMinLength),
                                  _buildPasswordRequirement('At least one uppercase letter (A-Z)', hasUppercase),
                                  _buildPasswordRequirement('At least one lowercase letter (a-z)', hasLowercase),
                                  _buildPasswordRequirement('At least one number (0-9)', hasNumber),
                                  _buildPasswordRequirement('At least one special symbol', hasSpecialChar),
                                ],
                              ),
                            ),
                          // End Password Requirements List

                          const SizedBox(height: 16),

                          // Confirm Password Field
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: _customInputDecoration(
                              labelText: tr('confirm_password'),
                              prefixIcon: Icons.lock_reset,
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                      color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            obscureText: _obscureConfirmPassword,
                            validator: (v) {
                              if (v != _passwordController.text) {
                                return tr('passwords_do_not_match');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          if (_msg != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                _msg!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],

                          FilledButton(
                            onPressed: _busy ? null : _updatePassword,
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    tr('update_password'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),
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