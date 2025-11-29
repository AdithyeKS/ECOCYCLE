import 'package:flutter/material.dart';
import 'package:EcoCycle/app_theme.dart';
import 'package:EcoCycle/core/supabase_config.dart';
import 'package:EcoCycle/screens/home_shell.dart';
import 'package:EcoCycle/screens/login_screen.dart';
import 'package:EcoCycle/screens/update_password_screen.dart';
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
    // 🔄 Use StreamBuilder to listen for real-time auth state changes (like deep links)
    return StreamBuilder<AuthState>(
      stream: AppSupabase.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // FIX: Show a loading indicator until the initial authentication state is resolved.
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Return a minimal MaterialApp with a loading screen while Supabase checks the session.
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.green[700],
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Uses the app logo from the assets
                    Image.asset('assets/images/ecocycle.png', width: 150),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(color: Colors.white),
                  ],
                ),
              ),
            ),
          );
        }

        final session = snapshot.data?.session;
        final event = snapshot.data?.event;

        Widget initialHome;

        // 1. Check if the event is a password recovery deep link
        if (event == AuthChangeEvent.passwordRecovery) {
          initialHome = const UpdatePasswordScreen();
        }
        // 2. Check for an active session
        else if (session != null) {
          initialHome = HomeShell(toggleTheme: _toggleTheme);
        }
        // 3. Default to login
        else {
          initialHome = LoginScreen(onThemeToggle: _toggleTheme);
        }

        return MaterialApp(
          title: tr('app_title'),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeMode,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          // Use the determined home screen
          home: initialHome,
        );
      },
    );
  }
}
