import 'package:flutter/material.dart';
import 'package:ecocycle_1/app_theme.dart';
import 'package:ecocycle_1/core/supabase_config.dart';
import 'package:ecocycle_1/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSupabase.init(); // Initialize Supabase before app runs
  runApp(const EcoCycleApp());
}

class EcoCycleApp extends StatelessWidget {
  const EcoCycleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoCycle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light, // Your custom light theme
      home: const SplashScreen(), // First screen after launch
    );
  }
}
