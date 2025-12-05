import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // ============================================
  // 로컬 개발 모드 (현재 활성화)
  // ============================================
  
  // 로컬 Supabase URL
  static const String supabaseUrl = 'http://127.0.0.1:54500';
  
  // 로컬 Supabase Anon Key
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  // ============================================
  // 프로덕션 모드 (주석 처리됨)
  // ============================================
  // static const String supabaseUrl = 'https://ythmnhadeyfusmfhcgdr.supabase.co';
  // static const String supabaseAnonKey =
  //     'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0aG1uaGFkZXlmdXNtZmhjZ2RyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwMDU4MDQsImV4cCI6MjA3MzU4MTgwNH0.BzTELGjnSewXprm_3mjJnOXusvp5Sw5jagpmKUYEM50';

  // ============================================
  // Cloudflare Workers API URL
  // ============================================
  // 파일 업로드, 사업자등록증 검증, 네이버 로그인 등에 사용
  // 
  // 로컬 개발: 로컬 Workers 서버 사용 (로컬 Supabase 연결 가능)
  // 프로덕션: 프로덕션 Workers 사용
  static const String workersApiUrl = kIsWeb
      ? 'http://localhost:8787'  // 로컬 개발: 로컬 Workers 서버
      : 'https://smart-review-api.nightkille.workers.dev';  // 프로덕션: 프로덕션 Workers

  // R2 Public URL (파일 업로드용)
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
    // 웹 환경에서는 localStorage를 사용하여 세션을 자동으로 저장/복원합니다
    // F5 새로고침 후에도 로그인 상태가 유지됩니다
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        // 모바일에서 딥링크 처리를 위한 설정
        authOptions: const FlutterAuthClientOptions(
          // 딥링크 처리를 활성화
          authFlowType: AuthFlowType.pkce,
          // 모바일에서 딥링크로 리다이렉트될 때 앱이 열리도록 설정
          detectSessionInUri: true,
        ),
      );
      debugPrint('Supabase 초기화 완료');

      // 웹 환경에서 세션 복원 확인
      if (kIsWeb) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          debugPrint('✅ 웹 세션 복원 성공: ${session.user.email ?? session.user.id}');
        } else {
          debugPrint('ℹ️ 저장된 세션이 없습니다 (로그인 필요)');
        }
      }
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
