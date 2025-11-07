import 'package:flutter/material.dart';
import 'package:ecocycle_1/core/supabase_config.dart';
import 'package:ecocycle_1/screens/home_shell.dart';
import 'package:ecocycle_1/screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 900));
    final session = AppSupabase.client.auth.currentSession;
    if (!mounted) return;
    if (session != null && session.user.emailConfirmedAt != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.asset('assets/images/ecocycle.png', width: 160),
          const SizedBox(height: 16),
          const Text('EcoCycle', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          const CircularProgressIndicator()
        ]),
      ),
    );
  }
}
