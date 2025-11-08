import 'package:flutter/material.dart';
import 'package:ecocycle_1/core/supabase_config.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

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
        emailRedirectTo: null, // uses site url; optional deep link
      );

      // Supabase will send a verification email automatically (if Confirm Email is ON).
      setState(() {
        _msg = (res.user != null)
            ? 'Verification email sent to ${_email.text}. Please verify and then login.'
            : 'Sign-up failed, try again.';
      });
    } catch (e) {
      setState(() {
        _msg = e.toString();
      });
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
                                Text('Create Account',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text('Sign up to continue',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: theme.hintColor)),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),

                          // Full name
                          TextFormField(
                            controller: _name,
                            decoration: const InputDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icon(Icons.person_outline)),
                            validator: (v) => (v == null || v.trim().length < 3)
                                ? 'Enter your name'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Mobile number
                          TextFormField(
                            controller: _phone,
                            decoration: const InputDecoration(
                                labelText: 'Mobile number',
                                prefixIcon: Icon(Icons.phone_outlined)),
                            keyboardType: TextInputType.phone,
                            validator: (v) => (v == null || v.trim().length < 8)
                                ? 'Enter a valid number'
                                : null,
                          ),
                          const SizedBox(height: 12),

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
                            decoration: const InputDecoration(
                              labelText: 'Password (min 8, 1 number, 1 letter)',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                            validator: (v) {
                              if (v == null || v.length < 8)
                                return 'Min 8 characters';
                              if (!RegExp(r'[A-Za-z]').hasMatch(v) ||
                                  !RegExp(r'\d').hasMatch(v)) {
                                return 'Use letters and numbers';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          if (_msg != null) ...[
                            Text(_msg!, textAlign: TextAlign.center),
                            const SizedBox(height: 10),
                          ],

                          FilledButton(
                            onPressed: _busy ? null : _signup,
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
                                : const Text('Sign up',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                          ),

                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed:
                                _busy ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
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
