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
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Enter your name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Mobile number'),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().length < 8)
                    ? 'Enter a valid number'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(
                    labelText: 'Password (min 8, 1 number, 1 letter)'),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.length < 8) return 'Min 8 characters';
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
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Sign up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
