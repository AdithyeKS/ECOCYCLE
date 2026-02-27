import 'package:flutter/material.dart';
import 'package:ecocycle/screens/home_shell.dart';

class VolunteerChoiceScreen extends StatelessWidget {
  final VoidCallback? onThemeToggle;

  const VolunteerChoiceScreen({super.key, this.onThemeToggle});

  @override
  Widget build(BuildContext context) {
    // FORCE LIGHT THEME values explicitly for consistent branding
    const cardBgColor = Colors.white;
    const secondaryTextColor = Colors.black54;
    const greenPrimary = Color(0xFF2E7D32);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Gradient Background Layer (Teal/Green signature)
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

          // 2. Thematic Elements Layer (Blobs)
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.2),
                        blurRadius: 40)
                  ]),
            ),
          ),
          Positioned(
            bottom: -30,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                  color: Colors.yellow.shade700.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.yellow.shade700.withValues(alpha: 0.2),
                        blurRadius: 30)
                  ]),
            ),
          ),
          Positioned(
            top: 200,
            right: 10,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  color: Colors.lightGreenAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
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
                  color: cardBgColor.withValues(alpha: 0.95),
                  child: Padding(
                    padding: const EdgeInsets.all(30),
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
                              Text('Choose Your Role',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 28, // More prominent
                                      color: greenPrimary)),
                              const SizedBox(height: 8),
                              Text(
                                  'You are registered as a volunteer. How would you like to continue?',
                                  style: TextStyle(
                                      color: secondaryTextColor, fontSize: 14),
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
                              backgroundColor: greenPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: const Text('Continue as Volunteer',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white)),
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
                              side: const BorderSide(color: greenPrimary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: const Text('Continue as User',
                              style:
                                  TextStyle(color: greenPrimary, fontSize: 16)),
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
