import 'package:flutter/material.dart';
import 'dart:math';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<RainDrop> _rainDrops = [];
  final Random _random = Random();

  final List<String> _ecoTips = [
    "Turn off lights when not in use.",
    "Recycle paper, plastic, and glass.",
    "Use reusable bags instead of plastic.",
    "Save water by fixing leaks promptly.",
    "Plant a tree to help the environment.",
    "Choose public transport or carpool.",
    "Compost food scraps to reduce waste.",
    "Support local and eco-friendly products.",
    "Reduce, Reuse, Recycle!",
    "Bring your own bottle to avoid single-use plastic.",
  ];

  late String _randomTip;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1), // Cycle duration for rain update
      vsync: this,
    )..repeat();

    _randomTip = _ecoTips[_random.nextInt(_ecoTips.length)];

    // Initialize rain drops
    for (int i = 0; i < 20; i++) {
      _rainDrops.add(_generateRainDrop());
    }

    _controller.addListener(() {
      setState(() {
        for (var drop in _rainDrops) {
          drop.y += drop.speed;
          if (drop.y > 1.1) {
            // Reset if it goes below screen
            var newDrop = _generateRainDrop();
            drop.y = newDrop.y - 0.2; // Start slightly above
            drop.x = newDrop.x;
            drop.speed = newDrop.speed;
          }
        }
      });
    });
  }

  RainDrop _generateRainDrop() {
    return RainDrop(
      x: _random.nextDouble(),
      y: _random.nextDouble() - 1.0, // Start above the screen initially
      speed: 0.005 + _random.nextDouble() * 0.015,
      length: 0.02 + _random.nextDouble() * 0.03,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.green[900]!,
                  Colors.green[700]!
                ], // Darker gradient
              ),
            ),
          ),

          // Rain Animation
          CustomPaint(
            painter: RainPainter(_rainDrops),
            child: Container(),
          ),

          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ]),
                  child: Image.asset(
                    'assets/images/ecocycle.png',
                    width: 100,
                    height: 100,
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Loading EcoCycle...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Building a Greener Future',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 60),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    '"$_randomTip"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RainDrop {
  double x;
  double y;
  double speed;
  double length;

  RainDrop(
      {required this.x,
      required this.y,
      required this.speed,
      required this.length});
}

class RainPainter extends CustomPainter {
  final List<RainDrop> drops;

  RainPainter(this.drops);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (var drop in drops) {
      final start = Offset(drop.x * size.width, drop.y * size.height);
      final end =
          Offset(drop.x * size.width, (drop.y + drop.length) * size.height);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
