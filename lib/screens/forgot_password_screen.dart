import 'package:flutter/material.dart';
import 'package:ecocycle/app_theme.dart';
import 'package:ecocycle/core/supabase_config.dart';
import 'package:ecocycle/screens/update_password_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();

  bool _busy = false;
  bool _isTokenSent = false;
  String? _msg;

  static final _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  // Step 1: Send the 8-digit token to the user's email
  Future<void> _sendResetToken() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _msg = null;
    });

    try {
      await AppSupabase.client.auth
          .resetPasswordForEmail(_emailController.text.trim());
      setState(() {
        _isTokenSent = true;
        _msg = 'An 8-digit token has been sent to your email.';
      });
    } catch (e) {
      setState(() => _msg = 'Error: Could not send token. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Step 2: Verify the 8-digit token entered by the user
  Future<void> _verifyToken() async {
    if (_tokenController.text.length < 8) {
      setState(() => _msg = "Please enter the full 8-digit code.");
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });

    try {
      // Verifies token using 'recovery' type for password resets
      await AppSupabase.client.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: _tokenController.text.trim(),
        type: OtpType.recovery,
      );

      if (mounted) {
        // Navigate to the Update Password Screen once verified
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UpdatePasswordScreen()),
        );
      }
    } catch (e) {
      setState(
          () => _msg = "Invalid token. Please check your email and try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // FORCE LIGHT THEME
    final theme = AppTheme.light;

    return Theme(
      data: theme,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade800, Colors.green.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  elevation: 20,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  color: Colors.white.withValues(alpha: 0.95),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/images/ecocycle.png', height: 70),
                          const SizedBox(height: 20),
                          Text(
                            _isTokenSent ? 'Verify Code' : 'Reset Password',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isTokenSent
                                ? 'Enter the 8-digit code sent to your email.'
                                : 'Enter your email to receive a reset token.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 25),
                          if (!_isTokenSent)
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (v) =>
                                  (v == null || !_emailRegex.hasMatch(v.trim()))
                                      ? 'Enter a valid email'
                                      : null,
                            )
                          else
                            TextFormField(
                              controller: _tokenController,
                              keyboardType: TextInputType.number,
                              maxLength: 8, // Set to 8 digits
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                letterSpacing: 6,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                hintText: '00000000', // 8 placeholders
                              ),
                            ),
                          if (_msg != null) ...[
                            const SizedBox(height: 15),
                            Text(
                              _msg!,
                              style: TextStyle(
                                color: _msg!.contains('sent')
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: FilledButton(
                              onPressed: _busy
                                  ? null
                                  : (_isTokenSent
                                      ? _verifyToken
                                      : _sendResetToken),
                              style: FilledButton.styleFrom(
                                backgroundColor: _isTokenSent
                                    ? Colors.green.shade700
                                    : Colors.red.shade400,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _busy
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : Text(
                                      _isTokenSent
                                          ? 'Confirm Code'
                                          : 'Get Token',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Back to Login'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
