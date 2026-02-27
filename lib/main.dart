import 'package:flutter/material.dart';
import 'package:ecocycle/app_theme.dart';
import 'package:ecocycle/core/supabase_config.dart';
import 'package:ecocycle/screens/home_shell.dart';
import 'package:ecocycle/screens/login_screen.dart';
import 'package:ecocycle/screens/splash_screen.dart';
import 'package:ecocycle/screens/update_password_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  ThemeMode _themeMode = ThemeMode.system; // Default to system initially
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    // Force splash screen to show for at least 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('is_dark_mode');
      if (mounted && isDark != null) {
        setState(() {
          _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
        });
      }
    } catch (e) {
      // print(...);
    }
  }

  void _toggleTheme() async {
    final newMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setState(() {
      _themeMode = newMode;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', newMode == ThemeMode.dark);
    } catch (e) {
      // print(...);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔄 Use StreamBuilder to listen for real-time auth state changes
    return StreamBuilder<AuthState>(
      stream: AppSupabase.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Show Splash Screen if timer hasn't finished OR auth is still waiting
        if (_showSplash ||
            snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: const SplashScreen(),
          );
        }

        final session = snapshot.data?.session;
        final event = snapshot.data?.event;

        Widget initialHome;

        // 1. Password recovery deep link
        if (event == AuthChangeEvent.passwordRecovery) {
          initialHome = const UpdatePasswordScreen();
        }
        // 2. Active session
        else if (session != null) {
          // Pass the toggleTheme function to HomeShell
          initialHome = HomeShell(toggleTheme: _toggleTheme);
        }
        // 3. Login
        else {
          initialHome = LoginScreen(onThemeToggle: _toggleTheme);
        }

        return MaterialApp(
          title: 'EcoCycle',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeMode,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: initialHome,
        );
      },
    );
  }
}
