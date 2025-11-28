import 'package:flutter/material.dart';
import 'package:ecocycle_1/app_theme.dart';
import 'package:ecocycle_1/core/supabase_config.dart';
import 'package:ecocycle_1/screens/home_shell.dart';
import 'package:ecocycle_1/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // ✅ Proper Supabase initialization with persistent login session
  await AppSupabase.init();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'), // English
        Locale('hi'), // Hindi
        Locale('ml'), // Malayalam
      ],
      path: 'assets/translations', // Make sure this folder exists
      fallbackLocale: const Locale('en'),
      child: const EcoCycleApp(),
    ),
  );
}

class EcoCycleApp extends StatefulWidget {
  const EcoCycleApp({super.key});

  @override
  State<EcoCycleApp> createState() => _EcoCycleAppState();
}

class _EcoCycleAppState extends State<EcoCycleApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: tr('app_title'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      // ✅ Automatically show login or home based on saved Supabase session
      home: session == null
          ? LoginScreen(onThemeToggle: _toggleTheme)
          : HomeShell(toggleTheme: _toggleTheme),
    );
  }
}
