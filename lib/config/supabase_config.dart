import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // 로컬 개발 환경 설정
  static const String supabaseUrl = 'http://127.0.0.1:54321';
  static const String supabaseAnonKey =
      'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';

  // 프로덕션 환경 설정 (주석 처리)
  // static const String supabaseUrl = 'https://ythmnhadeyfusmfhcgdr.supabase.co';
  // static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0aG1uaGFkZXlmdXNtZmhjZ2RyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwMDU4MDQsImV4cCI6MjA3MzU4MTgwNH0.BzTELGjnSewXprm_3mjJnOXusvp5Sw5jagpmKUYEM50';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
}
