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
  final _password = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _obscurePassword = true; // State for password visibility

  // Regex for strong password validation: Min 8 chars, 1 uppercase, 1 lowercase, 1 digit, 1 special char
  static final _passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+={}|:;<>,.?/~])(?!.*\s).{8,}$',
  );

  // Regex for full name validation: Must start with a capital letter, only contains letters and spaces
  static final _nameRegex = RegExp(r'^[A-Z][a-zA-Z\s]*$');

  // Regex for mobile number validation: Only digits, 8 to 15 length
  static final _phoneRegex = RegExp(r'^\d{8,15}$');

  // Regex for general email validation
  static final _emailRegex =
      RegExp(r'^[a-zA-Z0-Z9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

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
        },
        emailRedirectTo: null,
      );

      // MODIFIED: Navigate to ProfileCompletionScreen
      if (res.user != null) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            // Pass the required toggleTheme function
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
        _msg = e.toString();
      });
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

  // Function to check individual password requirements (used for real-time feedback)
  bool _checkPasswordRequirement(String value, RegExp pattern) {
    return pattern.hasMatch(value);
  }

  // Custom Input Decoration for the sleek look
  InputDecoration _customInputDecoration(
      {required String labelText,
      required IconData prefixIcon,
      Widget? suffixIcon}) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon:
          Icon(prefixIcon, color: Theme.of(context).colorScheme.primary),
      suffixIcon: suffixIcon,
      fillColor: Theme.of(context)
          .cardColor
          .withOpacity(0.8), // Slightly transparent background
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none, // Remove border for a cleaner look
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
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passwordText = _password.text;

    // Individual checks for real-time feedback
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
          // 1. Gradient Background Layer
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
          // Top Left: Blue blob (suggesting screens/plastic)
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 40)
                ],
              ),
            ),
          ),
          // Bottom Right: Yellow/Orange element (suggesting copper/gold circuits)
          Positioned(
            bottom: -30,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.yellow.shade700.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                      color: Colors.yellow.shade700.withOpacity(0.2),
                      blurRadius: 30)
                ],
              ),
            ),
          ),
          // Center Right: Green element (representing growth/recycling)
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
                              if (v == null || v.trim().length < 3) {
                                return 'Enter a valid name (min 3 characters)';
                              }
                              if (!_nameRegex.hasMatch(v.trim())) {
                                return 'Name must start with a capital letter and only contain letters/spaces.';
                              }
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
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Mobile number is required';
                              }
                              if (!_phoneRegex.hasMatch(v.trim())) {
                                return 'Enter a valid phone number (8-15 digits only)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email
                          TextFormField(
                            controller: _email,
                            decoration: _customInputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icons.email_outlined),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Email is required';
                              }
                              if (!_emailRegex.hasMatch(v.trim())) {
                                return 'Enter a valid email format';
                              }
                              return null;
                            },
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          TextFormField(
                            controller: _password,
                            onChanged: (value) =>
                                setState(() {}), // Trigger rebuild on change
                            decoration: _customInputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
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
                              if (v == null || v.isEmpty) {
                                return 'Password is required.';
                              }
                              if (!_passwordRegex.hasMatch(v)) {
                                // Simplified error message for submission failure
                                return 'Password does not meet all requirements.';
                              }
                              return null;
                            },
                          ),

                          // Password Requirements List (visible when typing)
                          const SizedBox(height: 8),
                          if (passwordText
                              .isNotEmpty) // Only show when user starts typing
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Recommended security requirements:',
                                      style: TextStyle(
                                          color: theme.hintColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                  _buildPasswordRequirement(
                                      'Minimum 8 characters', hasMinLength),
                                  _buildPasswordRequirement(
                                      'At least one uppercase letter (A-Z)',
                                      hasUppercase),
                                  _buildPasswordRequirement(
                                      'At least one lowercase letter (a-z)',
                                      hasLowercase),
                                  _buildPasswordRequirement(
                                      'At least one number (0-9)', hasNumber),
                                  _buildPasswordRequirement(
                                      'At least one special symbol',
                                      hasSpecialChar),
                                ],
                              ),
                            ),
                          // End Password Requirements List

                          const SizedBox(height: 24),

                          if (_msg != null) ...[
                            Text(_msg!, textAlign: TextAlign.center),
                            const SizedBox(height: 10),
                          ],

                          // Sign Up Button
                          FilledButton(
                            onPressed: _busy ? null : _signup,
                            style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: _busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Sign up',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                          ),

                          const SizedBox(height: 16),
                          // Back to Login Button
                          OutlinedButton(
                            onPressed:
                                _busy ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(
                                    color: theme.colorScheme.primary),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: Text('Already have an account?',
                                style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 16)),
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
