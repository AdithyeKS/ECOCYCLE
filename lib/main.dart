import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zqrzstbhvteaxkosirnk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxcnpzdGJodnRlYXhrb3Npcm5rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIzNjM5ODksImV4cCI6MjA3NzkzOTk4OX0.kjl__LsXiIj7RtVItYLxsUAD1ktTXNuYCGwc6uc9vR0',
  );

  runApp(const EcoCycleApp());
}

class EcoCycleApp extends StatelessWidget {
  const EcoCycleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoCycle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: const SplashScreen(),
    );
  }
}
