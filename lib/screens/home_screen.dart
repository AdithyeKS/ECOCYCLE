import 'package:flutter/material.dart';
import 'add_ewaste_screen.dart';
import 'view_ewaste_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EcoCycle Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/ecocycle.png', height: 100),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add E-Waste'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, padding: const EdgeInsets.all(15)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEwasteScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.view_list),
              label: const Text('View My E-Waste'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, padding: const EdgeInsets.all(15)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ViewEwasteScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
