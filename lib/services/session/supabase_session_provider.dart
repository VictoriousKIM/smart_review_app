import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import 'session_info.dart';
import 'session_provider.dart';

/// Supabase 세션 제공자
/// 카카오, 구글 등 Supabase OAuth를 사용하는 세션을 관리합니다
class SupabaseSessionProvider implements SessionProvider {
  final SupabaseClient _supabase = SupabaseConfig.client;

  @override
  String get providerName => 'Supabase';

  @override
  Future<SessionInfo?> getSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        return null;
      }

      // 세션 만료 확인 및 갱신
      if (session.isExpired) {
        try {
          final refreshedSession = await _supabase.auth.refreshSession();
          if (refreshedSession.session == null) {
            return null;
          }
          return _createSessionInfo(refreshedSession.session!);
        } catch (e) {
          debugPrint('⚠️ Supabase 세션 갱신 실패: $e');
          // 갱신 실패해도 현재 세션 정보 반환
          return _createSessionInfo(session);
        }
      }

      return _createSessionInfo(session);
    } catch (e) {
      debugPrint('⚠️ Supabase 세션 조회 실패: $e');
      return null;
    }
  }

  @override
  Future<bool> hasSession() async {
    final session = await getSession();
    return session != null && !session.isExpired;
  }

  @override
  bool hasSessionSync() {
    try {
      final session = _supabase.auth.currentSession;
      return session != null && !session.isExpired;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('⚠️ Supabase 세션 삭제 실패: $e');
    }
  }

  /// Supabase Session을 SessionInfo로 변환
  SessionInfo _createSessionInfo(Session session) {
    final user = session.user;
    final expiresAt = session.expiresAt != null
        ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
        : null;

    return SessionInfo(
      userId: user.id,
      email: user.email,
      provider: user.appMetadata['provider'] as String?,
      userMetadata: user.userMetadata,
      expiresAt: expiresAt,
    );
  }
}

