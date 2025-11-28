import 'package:supabase_flutter/supabase_flutter.dart';

class AppSupabase {
  // 👇 Your project URL (this is correct)
  static const String url = 'https://zqrzstbhvteaxkosirnk.supabase.co';

  // 👇 PASTE your real anon public key from Supabase here (only once!)
  static const String anonKey =
      '';

  // 🔥 Initialize Supabase (simple & compatible with your version)
  static Future<void> init() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      debug: true, // optional, but useful while developing
    );
  }

  // Easy access to the client
  static SupabaseClient get client => Supabase.instance.client;
}
