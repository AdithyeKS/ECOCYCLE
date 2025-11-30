import 'package:flutter/material.dart';
import 'package:EcoCycle/screens/login_screen.dart'; // FIX: Corrected import path
import 'package:flutter_animate/flutter_animate.dart'; // Import for animations

class SplashScreen extends StatefulWidget {
  // FIX: Change type of toggleTheme to simple VoidCallback,
  // as the LoginScreen expects a simple function to trigger the theme change.
  final VoidCallback? toggleTheme;
  final bool? isDark; // optional

  const SplashScreen({super.key, this.toggleTheme, this.isDark});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // This traditional splash screen is typically used for initial branding,
    // but in Flutter with Supabase, the real authentication check happens
    // in main.dart's StreamBuilder. We keep this minimal.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          // FIX: Correctly pass the toggleTheme function to the LoginScreen
          MaterialPageRoute(
              builder: (_) => LoginScreen(onThemeToggle: widget.toggleTheme)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine the size for the round icon and loading indicator
    const double iconSize = 150.0;
    const double indicatorPadding = 8.0;

    return Scaffold(
      // Use Container with gradient for modern look
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // Use Theme colors for seamless light/dark mode transition
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.9),
              Theme.of(context).colorScheme.secondary.withOpacity(0.7),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // NEW: Round Icon and Loading Indicator Stack
              Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Round Icon (Image.asset wrapped in ClipOval)
                  ClipOval(
                    child: Image.asset(
                      'assets/images/ecocycle.png',
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.cover,
                    ).animate().fade(duration: 800.ms),
                  ),

                  // 2. Circular Progress Indicator (Larger, placed around the icon)
                  SizedBox(
                    width: iconSize +
                        indicatorPadding * 2, // Make indicator larger than icon
                    height: iconSize + indicatorPadding * 2,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
              // END NEW ROUND ICON STACK

              const SizedBox(height: 20),

              const Text(
                'EcoCycle',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.5, end: 0.0),

              // Removed the standalone CircularProgressIndicator below
              // The indicator is now inside the Stack with the icon.
            ],
          ),
        ),
      ),
    );
  }
}
