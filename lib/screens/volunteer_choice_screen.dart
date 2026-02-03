import 'package:flutter/material.dart';
import 'package:EcoCycle/screens/home_shell.dart';

class VolunteerChoiceScreen extends StatelessWidget {
  final VoidCallback? onThemeToggle;

  const VolunteerChoiceScreen({super.key, this.onThemeToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
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
          Center(
            child: Card(
              elevation: 20,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              color: theme.cardColor.withAlpha((0.95 * 255).round()),
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Image.asset('assets/images/ecocycle.png', height: 80),
                          const SizedBox(height: 16),
                          Text('Choose Your Role',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary)),
                          const SizedBox(height: 8),
                          Text(
                              'You are registered as a volunteer. How would you like to continue?',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HomeShell(
                              toggleTheme: onThemeToggle ?? () {},
                              forcedRole: 'volunteer',
                            ),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('Continue as Volunteer',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HomeShell(
                              toggleTheme: onThemeToggle ?? () {},
                              forcedRole: 'user',
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: theme.colorScheme.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Text('Continue as User',
                          style: TextStyle(
                              color: theme.colorScheme.primary, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
