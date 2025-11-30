import 'package:flutter/material.dart';
import 'package:EcoCycle/core/supabase_config.dart';
import 'package:EcoCycle/screens/forgot_password_screen.dart';
import 'package:EcoCycle/screens/home_shell.dart';
import 'package:EcoCycle/screens/signup_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  static final _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  String _mapAuthError(String rawError) {
    if (rawError.contains('Invalid login credentials')) {
      return 'Incorrect email or password. If you don\'t have an account, please create one.';
    }
    if (rawError.contains('Email not confirmed')) {
      return 'Email not verified. Please check your inbox (and spam folder).';
    }
    return 'Login failed. Check your connection or contact support.';
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final authResponse = await AppSupabase.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      // CRITICAL FIX: Ensure the profile exists and has a role set upon login.
      // This helps mitigate race conditions where HomeShell might load faster than the DB update.
      final user = authResponse.user;
      if (user != null) {
        final userId = user.id;
        final profileExists = await AppSupabase.client
            .from('profiles')
            .select('user_role') // Just fetch the role column
            .eq('id', userId)
            .maybeSingle();

        if (profileExists == null) {
          // If profile is missing (first time login/signup failed profile completion),
          // insert a default user profile.
          await AppSupabase.client.from('profiles').insert({
            'id': userId,
            'full_name': user.email?.split('@').first ?? 'User',
            'total_points': 0,
            'user_role': 'user', // Default role for new users
          });
        }
      }

      // 2. Successful Login: Navigate to Homepage
      if (authResponse.session != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  HomeShell(toggleTheme: widget.onThemeToggle ?? () {})),
        );
      }
    } on AuthException catch (e) {
      // 3. Catch Supabase errors and show user-friendly message
      setState(() => _error = _mapAuthError(e.message ?? e.toString()));
    } catch (e) {
      // 4. Catch general exceptions
      setState(() => _error = _mapAuthError(e.toString()));
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

  // Widget: Professional Error Display
  Widget _buildErrorBox(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade400, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
                colors: [
                  Colors.teal.shade800,
                  Colors.green.shade700,
                  Colors.green.shade900,
                ],
              ),
            ),
          ),

          // 2. Thematic Elements Layer (Blobs)
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
                    BoxShadow(
                        color: Colors.blue.withOpacity(0.2), blurRadius: 40)
                  ]),
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
                  boxShadow: [
                    BoxShadow(
                        color: Colors.yellow.shade700.withOpacity(0.2),
                        blurRadius: 30)
                  ]),
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
                  shape: BoxShape.circle),
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
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Email is required to log in.';
                              }
                              if (v.length < 5 || !v.contains('@')) {
                                return 'Please ensure the input resembles an email.';
                              }
                              return null;
                            },
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
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Password is required to log in.'
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

                          // Enhanced Error Display
                          if (_error != null) _buildErrorBox(context, _error!),

                          const SizedBox(height: 16),
                          // Login Button
                          FilledButton(
                            onPressed: _busy ? null : _login,
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
