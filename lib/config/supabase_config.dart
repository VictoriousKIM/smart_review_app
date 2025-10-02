import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // 개발 모드에서는 로컬 Supabase 사용, 프로덕션에서는 원격 Supabase 사용
  static const String supabaseUrl = kDebugMode
      ? 'http://127.0.0.1:54321' // 로컬 개발 환경
      : 'https://ythmnhadeyfusmfhcgdr.supabase.co'; // 프로덕션 환경

  static const String supabaseAnonKey = kDebugMode
      ? 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH' // 로컬 개발 키
      : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0aG1uaGFkZXlmdXNtZmhjZ2RyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwMDU4MDQsImV4cCI6MjA3MzU4MTgwNH0.BzTELGjnSewXprm_3mjJnOXusvp5Sw5jagpmKUYEM50'; // 프로덕션 키

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
}
