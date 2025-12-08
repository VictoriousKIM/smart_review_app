import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_info.dart';
import 'session_provider.dart';

/// Custom JWT 세션 제공자
/// 네이버 로그인 등 Custom JWT를 사용하는 세션을 관리합니다
class CustomJwtSessionProvider implements SessionProvider {
  static const String _tokenKey = 'custom_jwt_token';
  static const String _userIdKey = 'custom_jwt_user_id';
  static const String _emailKey = 'custom_jwt_user_email';
  static const String _providerKey = 'custom_jwt_provider';

  @override
  String get providerName => 'Custom JWT';

  @override
  Future<SessionInfo?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userId = prefs.getString(_userIdKey);
      final email = prefs.getString(_emailKey);
      final provider = prefs.getString(_providerKey);

      if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
        return null;
      }

      // Custom JWT는 만료 시간을 정확히 알 수 없으므로 null로 설정
      // 실제 만료는 API 호출 시 에러로 감지
      return SessionInfo(
        userId: userId,
        email: email,
        provider: provider ?? 'naver',
        userMetadata: {
          'email': email,
        },
        expiresAt: null, // Custom JWT는 만료 시간을 알 수 없음
      );
    } catch (e) {
      debugPrint('⚠️ Custom JWT 세션 조회 실패: $e');
      return null;
    }
  }

  @override
  Future<bool> hasSession() async {
    final session = await getSession();
    return session != null;
  }

  @override
  bool hasSessionSync() {
    // SharedPreferences는 동기적으로 접근 가능하지만,
    // Future를 반환하는 메서드와 일관성을 위해 비동기로 처리
    // 동기적으로 확인하려면 try-catch로 처리
    try {
      // SharedPreferences.getInstance()는 비동기이므로
      // 동기적으로는 확인할 수 없음
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_emailKey);
      await prefs.remove(_providerKey);
      await prefs.remove('custom_jwt_user_name');
    } catch (e) {
      debugPrint('⚠️ Custom JWT 세션 삭제 실패: $e');
    }
  }

  /// Custom JWT 세션 저장 (NaverAuthService에서 사용)
  static Future<void> saveSession({
    required String token,
    required String userId,
    String? email,
    String? provider,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userIdKey, userId);
      if (email != null) {
        await prefs.setString(_emailKey, email);
      }
      if (provider != null) {
        await prefs.setString(_providerKey, provider);
      }
    } catch (e) {
      debugPrint('⚠️ Custom JWT 세션 저장 실패: $e');
    }
  }
}

