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
    setState(() { _busy = true; _msg = null; });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _sendReset,
            child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Send link'),
          ),
          if (_msg != null) ...[
            const SizedBox(height: 12),
            Text(_msg!, textAlign: TextAlign.center),
          ]
        ]),
      ),
    );
  }
}
