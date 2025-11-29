import 'package:flutter/material.dart';
import 'package:ecocycle_1/core/supabase_config.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // ADD: Form key for validation
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  String? _msg;
  
  // Regex for general email validation
  static final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  Future<void> _sendReset() async {
    // ADD: Validation check before proceeding
    if (!_formKey.currentState!.validate()) return;

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

  // Custom Input Decoration for the sleek look
  InputDecoration _customInputDecoration({
    required String labelText, 
    required IconData prefixIcon, 
    Widget? suffixIcon
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(prefixIcon, color: Theme.of(context).colorScheme.primary),
      suffixIcon: suffixIcon,
      fillColor: Theme.of(context).cardColor.withOpacity(0.8), // Slightly transparent background
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none, // Remove border for a cleaner look
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Gradient Background Layer (PWASE Theme)
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
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15), 
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 40)],
              ),
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
                boxShadow: [BoxShadow(color: Colors.yellow.shade700.withOpacity(0.2), blurRadius: 30)],
              ),
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
                    // WRAP: Wrap content in a Form widget
                    child: Form(
                      key: _formKey, // ASSIGN: Assign the form key
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
                                Text('Forgot Password',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                                const SizedBox(height: 8),
                                Text('Enter your email to receive a reset link.',
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
                            // ADD: Validator for required email format
                            validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Email is required';
                                }
                                if (!_emailRegex.hasMatch(v.trim())) {
                                  return 'Enter a valid email format';
                                }
                                return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          if (_msg != null) ...[
                            const SizedBox(height: 8),
                            Text(_msg!,
                                style: TextStyle(
                                    color: _msg!.contains('sent')
                                        ? Colors.green
                                        : Colors.red),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                          ],

                          FilledButton(
                            onPressed: _busy ? null : _sendReset,
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade400, // Using red for danger/reset
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: _busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Send Reset Link',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),

                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: theme.colorScheme.primary),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: Text('Back to Login', style: TextStyle(color: theme.colorScheme.primary, fontSize: 16)),
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