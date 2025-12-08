import 'package:flutter/foundation.dart';
import 'session_info.dart';
import 'session_provider.dart';
import 'supabase_session_provider.dart';
import 'custom_jwt_session_provider.dart';

/// 통합 세션 관리자
/// 여러 세션 제공자를 통합하여 관리합니다
class UnifiedSessionManager {
  static final UnifiedSessionManager _instance = UnifiedSessionManager._internal();
  factory UnifiedSessionManager() => _instance;
  UnifiedSessionManager._internal();

  /// 세션 제공자 목록 (우선순위 순서)
  /// 먼저 확인된 세션이 활성 세션이 됩니다
  final List<SessionProvider> _providers = [
    CustomJwtSessionProvider(), // Custom JWT 우선 (네이버)
    SupabaseSessionProvider(), // Supabase 세션 (카카오, 구글)
  ];

  /// 현재 활성 세션을 가져옵니다
  /// 여러 세션 제공자 중 가장 우선순위가 높은 세션을 반환합니다
  Future<SessionInfo?> getActiveSession() async {
    for (var provider in _providers) {
      try {
        final session = await provider.getSession();
        if (session != null && !session.isExpired) {
          debugPrint('✅ 활성 세션 발견: ${provider.providerName}');
          return session;
        }
      } catch (e) {
        debugPrint('⚠️ ${provider.providerName} 세션 조회 중 에러: $e');
      }
    }
    return null;
  }

  /// 세션이 존재하는지 확인합니다
  Future<bool> hasActiveSession() async {
    final session = await getActiveSession();
    return session != null;
  }

  /// 모든 세션을 삭제합니다
  Future<void> clearAllSessions() async {
    for (var provider in _providers) {
      try {
        await provider.clearSession();
        debugPrint('✅ ${provider.providerName} 세션 삭제 완료');
      } catch (e) {
        debugPrint('⚠️ ${provider.providerName} 세션 삭제 실패: $e');
      }
    }
  }

  /// 특정 제공자의 세션만 삭제합니다
  Future<void> clearSessionByProvider(String providerName) async {
    for (var provider in _providers) {
      if (provider.providerName == providerName) {
        try {
          await provider.clearSession();
          debugPrint('✅ $providerName 세션 삭제 완료');
        } catch (e) {
          debugPrint('⚠️ $providerName 세션 삭제 실패: $e');
        }
        break;
      }
    }
  }

  /// 활성 세션의 제공자 이름을 가져옵니다
  Future<String?> getActiveProviderName() async {
    final session = await getActiveSession();
    return session?.provider;
  }
}

