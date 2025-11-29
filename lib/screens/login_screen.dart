import 'package:flutter/material.dart';
import 'package:EcoCycle/core/supabase_config.dart';
import 'package:EcoCycle/screens/forgot_password_screen.dart';
import 'package:EcoCycle/screens/home_shell.dart';
import 'package:EcoCycle/screens/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onThemeToggle;
  const LoginScreen({super.key, this.onThemeToggle});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  // Regex for general email validation
  static final _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  // Regex for minimum 8 characters (required for login)
  static final _minPasswordRegex = RegExp(r'^.{8,}$');

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppSupabase.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
                HomeShell(toggleTheme: widget.onThemeToggle ?? () {})),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Gradient Background Layer
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                // Using a darker green/blue gradient for a rich, modern look
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
                  elevation: 20, // High elevation for the floating effect
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  color: theme.cardColor
                      .withOpacity(0.95), // Semi-transparent card
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
                                // Sleek Logo Display
                                Image.asset('assets/images/ecocycle.png',
                                    height: 80),
                                const SizedBox(height: 16),
                                Text('Welcome Back',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary)),
                                const SizedBox(height: 8),
                                Text('Sign in to continue your eco-journey',
                                    style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),

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

                          // Password
                          TextFormField(
                            controller: _password,
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
                            validator: (v) =>
                                (v == null || !_minPasswordRegex.hasMatch(v))
                                    ? 'Minimum 8 characters required'
                                    : null,
                          ),
                          const SizedBox(height: 8),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordScreen()));
                              },
                              child: const Text('Forgot password?'),
                            ),
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(_error!,
                                  style: const TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(height: 8),
                          ],

                          const SizedBox(height: 16),
                          // Login Button
                          FilledButton(
                            onPressed: _busy ? null : _login,
                            style: FilledButton.styleFrom(
                                backgroundColor:
                                    theme.colorScheme.primary, // Themed Color
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
                                : const Text('Login',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                          ),

                          const SizedBox(height: 16),
                          // Create Account Button
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => SignupScreen(
                                            onThemeToggle:
                                                widget.onThemeToggle))),
                            style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(
                                    color: theme.colorScheme.primary),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: Text('Create account',
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
