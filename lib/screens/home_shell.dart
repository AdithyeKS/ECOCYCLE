import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ecocycle_1/screens/home_screen.dart';
import 'package:ecocycle_1/screens/map_screen.dart';
import 'package:ecocycle_1/screens/settings_screen.dart';

class HomeShell extends StatefulWidget {
  final VoidCallback toggleTheme;
  const HomeShell({super.key, required this.toggleTheme});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(toggleTheme: widget.toggleTheme),
      const MapScreen(), // Map Screen (OpenStreetMap)
      const Placeholder(), // Rewards Screen (future feature)
      SettingsScreen(toggleTheme: widget.toggleTheme),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: tr('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.map_outlined),
            label: tr('map'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.star_outline),
            label: tr('rewards'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: tr('settings'),
          ),
        ],
      ),
    );
  }
}
