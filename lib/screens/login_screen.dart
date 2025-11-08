import 'package:flutter/material.dart';
import 'package:ecocycle_1/core/supabase_config.dart';
import 'package:ecocycle_1/screens/forgot_password_screen.dart';
import 'package:ecocycle_1/screens/home_shell.dart';
import 'package:ecocycle_1/screens/signup_screen.dart';

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

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await AppSupabase.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      // Force verified email only
      if (res.session?.user.emailConfirmedAt == null) {
        await AppSupabase.client.auth.signOut();
        throw 'Please verify your email from your inbox before logging in.';
      }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background image with dark overlay
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/ecocycle.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.55), BlendMode.darken),
              ),
            ),
          ),
          // Centered card with form
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  elevation: 12,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  color: theme.cardColor.withOpacity(0.95),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
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
                                    height: 84),
                                const SizedBox(height: 12),
                                Text('Welcome Back',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text('Sign in to continue',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: theme.hintColor)),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),

                          // Email
                          TextFormField(
                            controller: _email,
                            decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined)),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Enter a valid email'
                                : null,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),

                          // Password
                          TextFormField(
                            controller: _password,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  transitionBuilder: (child, animation) =>
                                      ScaleTransition(
                                          scale: animation, child: child),
                                  child: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    key: ValueKey<bool>(_obscurePassword),
                                  ),
                                ),
                              ),
                            ),
                            obscureText: _obscurePassword,
                            validator: (v) => (v == null || v.length < 8)
                                ? 'Min 8 characters'
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
                            const SizedBox(height: 8),
                            Text(_error!,
                                style: const TextStyle(color: Colors.red)),
                          ],

                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _busy ? null : _login,
                            style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            child: _busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Text('Login',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                          ),

                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const SignupScreen())),
                            style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            child: const Text('Create account'),
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
