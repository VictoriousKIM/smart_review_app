import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'session_info.dart';
import 'session_provider.dart';

/// Custom JWT 세션 제공자
/// 네이버 로그인 등 Custom JWT를 사용하는 세션을 관리합니다
class CustomJwtSessionProvider implements SessionProvider {
  // Secure Storage 인스턴스 (웹/모바일 모두 지원)
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    // 웹에서는 Web Crypto API를 사용하여 암호화
  );

  static const String _tokenKey = 'custom_jwt_token';
  static const String _userIdKey = 'custom_jwt_user_id';
  static const String _emailKey = 'custom_jwt_user_email';
  static const String _providerKey = 'custom_jwt_provider';

  @override
  String get providerName => 'Custom JWT';

  @override
  Future<SessionInfo?> getSession() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final userId = await _storage.read(key: _userIdKey);
      final email = await _storage.read(key: _emailKey);
      final provider = await _storage.read(key: _providerKey);

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
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userIdKey);
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _providerKey);
      await _storage.delete(key: 'custom_jwt_user_name');
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
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _userIdKey, value: userId);
      if (email != null) {
        await _storage.write(key: _emailKey, value: email);
      }
      if (provider != null) {
        await _storage.write(key: _providerKey, value: provider);
      }
    } catch (e) {
      debugPrint('⚠️ Custom JWT 세션 저장 실패: $e');
    }
  }

  /// Custom JWT 세션 저장 및 저장 완료 확인 (저장 완료 보장)
  /// 세션 저장 후 저장이 완료되었는지 확인하여 안정성을 보장합니다
  static Future<void> saveSessionAndVerify({
    required String token,
    required String userId,
    String? email,
    String? provider,
  }) async {
    // 세션 저장
    await saveSession(
      token: token,
      userId: userId,
      email: email,
      provider: provider,
    );

    // 저장 완료 확인 (최대 3회 재시도)
    for (int i = 0; i < 3; i++) {
      final savedToken = await _storage.read(key: _tokenKey);
      final savedUserId = await _storage.read(key: _userIdKey);

      if (savedToken == token && savedUserId == userId) {
        debugPrint('✅ Custom JWT 세션 저장 완료 확인됨 (시도 ${i + 1}/3)');
        return;
      }

      // 저장이 완료되지 않았으면 잠시 대기 후 재시도
      if (i < 2) {
        debugPrint('⚠️ 세션 저장 확인 실패, 재시도 중... (시도 ${i + 1}/3)');
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    // 최종 확인 실패 시 에러 발생
    final finalToken = await _storage.read(key: _tokenKey);
    final finalUserId = await _storage.read(key: _userIdKey);
    if (finalToken != token || finalUserId != userId) {
      throw Exception(
        'Custom JWT 세션 저장 확인 실패: 저장된 값이 예상과 다릅니다',
      );
    }
  }
}

