import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AppSupabase {
  static const String url = 'https://zqrzstbhvteaxkosirnk.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxcnpzdGJodnRlYXhrb3Npcm5rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIzNjM5ODksImV4cCI6MjA3NzkzOTk4OX0.kjl__LsXiIj7RtVItYLxsUAD1ktTXNuYCGwc6uc9vR0';

  /// Initialize Supabase (called in main.dart)
  static Future<void> init() async {
    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );

      if (kDebugMode) {
        print('✅ Supabase initialized successfully!');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize Supabase: $e');
      }
    }
  }

  /// Access the Supabase client anywhere in the app
  static SupabaseClient get client => Supabase.instance.client;
}
