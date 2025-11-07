import 'package:supabase_flutter/supabase_flutter.dart';

class AppSupabase {
  static const String url = 'https://zqrzstbhvteaxkosirnk.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxcnpzdGJodnRlYXhrb3Npcm5rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIzNjM5ODksImV4cCI6MjA3NzkzOTk4OX0.kjl__LsXiIj7RtVItYLxsUAD1ktTXNuYCGwc6uc9vR0';

  static Future<void> init() async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
