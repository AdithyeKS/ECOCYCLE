import 'package:flutter/material.dart';
import 'package:ecocycle_1/core/supabase_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';

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

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _msg = null; });

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
      setState(() { _msg = e.toString(); });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
              Theme.of(context).colorScheme.secondary.withOpacity(0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
            child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Hero(
                tag: 'logo',
                child: Image.asset('assets/images/ecocycle.png', height: 100)
              ).animate().fade().scale(),
              const SizedBox(height: 24),
              Text(
                tr('create_account_title'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 32),
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: InputDecoration(
                          labelText: tr('full_name'),
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) => (v==null||v.trim().length<3) ? tr('enter_valid_name') : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phone,
                        decoration: InputDecoration(
                          labelText: tr('phone'),
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v==null||v.trim().length<8) ? tr('enter_valid_phone') : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _email,
                        decoration: InputDecoration(
                          labelText: tr('email'),
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) => (v==null||!v.contains('@')) ? tr('enter_valid_email') : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        decoration: InputDecoration(
                          labelText: tr('password'),
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.length < 8) return tr('min_8_characters');
                          if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
                            return tr('use_letters_and_numbers');
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ).animate().slideX(delay: 400.ms),
              const SizedBox(height: 24),
              if (_msg != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _msg!.contains('Verification') 
                      ? Colors.green.withOpacity(0.1) 
                      : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _msg!.contains('Verification') 
                          ? Icons.check_circle_outline 
                          : Icons.error_outline,
                        color: _msg!.contains('Verification') 
                          ? Colors.green 
                          : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _msg!,
                          style: TextStyle(
                            color: _msg!.contains('Verification') 
                              ? Colors.green 
                              : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().shake(),
                const SizedBox(height: 24),
              ],
              FilledButton(
                onPressed: _busy ? null : _signup,
                style: FilledButton.styleFrom(
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
                        tr('sign_up'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _busy 
                    ? null 
                    : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_back, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      tr('back_to_login'),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms),
                    ],
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
    )
  }
}
