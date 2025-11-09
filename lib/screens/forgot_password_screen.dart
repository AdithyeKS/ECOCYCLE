import 'package:flutter/material.dart';
import 'package:ecocycle_1/core/supabase_config.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _msg;

  Future<void> _sendReset() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await AppSupabase.client.auth.resetPasswordForEmail(
        _email.text.trim(),
      );
      _msg = 'Password reset link sent to your email (check inbox/spam).';
    } catch (e) {
      _msg = e.toString();
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
                              Text('Forgot Password',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('Enter your email to reset your password',
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: theme.hintColor)),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),

                        // Email
                        TextField(
                          controller: _email,
                          decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined)),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),

                        if (_msg != null) ...[
                          const SizedBox(height: 8),
                          Text(_msg!,
                              style: TextStyle(
                                  color: _msg!.contains('sent')
                                      ? Colors.green
                                      : Colors.red),
                              textAlign: TextAlign.center),
                        ],

                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _busy ? null : _sendReset,
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Send Reset Link',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                        ),

                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          child: const Text('Back to Login'),
                        ),
                      ],
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
