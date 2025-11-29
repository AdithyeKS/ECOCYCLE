import 'package:supabase_flutter/supabase_flutter.dart';

class AppSupabase {
  // 👇 Your project URL (this is correct)
  static const String url = 'https://zqrzstbhvteaxkosirnk.supabase.co';

  // 👇 PASTE your real anon public key from Supabase here (only once!)
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxcnpzdGJodnRlYXhrb3Npcm5rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIzNjM5ODksImV4cCI6MjA3NzkzOTk4OX0.kjl__LsXiIj7RtVItYLxsUAD1ktTXNuYCGwc6uc9vR0';

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
