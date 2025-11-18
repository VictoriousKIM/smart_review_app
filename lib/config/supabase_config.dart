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

  // Cloudflare Workers API URL
  // 프로덕션 환경만 사용 (로컬 개발도 프로덕션 Workers 사용)
  static const String workersApiUrl =
      'https://smart-review-api.nightkille.workers.dev';

  // R2 Public URL
  static const String r2PublicUrl =
      'https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com/smart-review-files';

  static SupabaseClient get client {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('Supabase 클라이언트 가져오기 실패: $e');
      // 클라이언트가 없으면 재초기화 시도
      throw StateError('Supabase가 초기화되지 않았습니다. initialize()를 먼저 호출하세요.');
    }
  }

  static Future<void> initialize() async {
    // Supabase.initialize는 이미 초기화된 경우 안전하게 처리됩니다
    // 웹 환경에서는 세션 복원이 자동으로 처리됩니다
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      debugPrint('Supabase 초기화 완료');
    } catch (e) {
      // 이미 초기화된 경우나 다른 에러가 발생할 수 있음
      debugPrint('Supabase 초기화 중 에러 발생 (무시 가능): $e');
      // 에러가 발생해도 클라이언트가 사용 가능한지 확인
      try {
        // 클라이언트 접근 시도 (유효성 검증)
        Supabase.instance.client;
        debugPrint('Supabase 클라이언트는 사용 가능합니다.');
      } catch (clientError) {
        debugPrint('Supabase 클라이언트 사용 불가: $clientError');
        rethrow; // 클라이언트를 사용할 수 없으면 에러를 다시 던짐
      }
    }
  }
}
