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

  /// 세션 캐시 (반복 호출 방지)
  SessionInfo? _cachedSession;
  DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(seconds: 5); // 5초간 캐시 유지

  /// 현재 활성 세션을 가져옵니다
  /// 여러 세션 제공자 중 가장 우선순위가 높은 세션을 반환합니다
  /// 캐싱을 통해 반복 호출 방지
  Future<SessionInfo?> getActiveSession({bool forceRefresh = false}) async {
    // 캐시가 유효하면 캐시된 세션 반환
    if (!forceRefresh &&
        _cachedSession != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration &&
        !_cachedSession!.isExpired) {
      return _cachedSession;
    }

    // 캐시가 없거나 만료되었으면 새로 조회
    for (var provider in _providers) {
      try {
        final session = await provider.getSession();
        if (session != null && !session.isExpired) {
          // 캐시에 저장
          _cachedSession = session;
          _cacheTimestamp = DateTime.now();
          return session;
        }
      } catch (e) {
        debugPrint('⚠️ ${provider.providerName} 세션 조회 중 에러: $e');
      }
    }

    // 세션이 없으면 캐시 초기화
    _cachedSession = null;
    _cacheTimestamp = null;
    return null;
  }

  /// 세션이 존재하는지 확인합니다
  Future<bool> hasActiveSession() async {
    final session = await getActiveSession();
    return session != null;
  }

  /// 세션 캐시 초기화 (세션 변경 시 호출)
  void clearCache() {
    _cachedSession = null;
    _cacheTimestamp = null;
  }

  /// 모든 세션을 삭제합니다
  Future<void> clearAllSessions() async {
    // 캐시 초기화
    clearCache();
    
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
    // 캐시 초기화
    clearCache();
    
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

