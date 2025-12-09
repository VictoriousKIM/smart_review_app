import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/supabase_config.dart';
import 'session/custom_jwt_session_provider.dart';

// 웹용
import 'package:universal_html/html.dart' as html;

// 모바일 전용 패키지 (웹에서는 사용하지 않음)
import 'package:flutter_naver_login/flutter_naver_login.dart'
    show
        FlutterNaverLogin,
        NaverLoginResult,
        NaverLoginStatus,
        NaverAccessToken;

/// 네이버 소셜 로그인 서비스
/// Cloudflare Workers를 통해 인증 처리
class NaverAuthService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // 네이버 OAuth 설정
  static const String naverClientId = 'Gx2IIkdRCTg32kobQj7J';
  static String get redirectUri {
    if (kIsWeb) {
      return '${html.window.location.origin}/loading';
    }
    return 'com.smart-grow.smart-review://login-callback';
  }

  /// 네이버 로그인 전체 플로우
  Future<AuthResponse?> signInWithNaver() async {
    try {
      if (kIsWeb) {
        return await signInWithNaverWeb();
      } else {
        return await signInWithNaverNative();
      }
    } catch (e) {
      debugPrint('네이버 로그인 에러: $e');
      rethrow;
    }
  }

  /// 네이버 로그인 (웹)
  /// Authorization Code Flow 사용
  Future<AuthResponse?> signInWithNaverWeb() async {
    try {
      // 네이버 OAuth 인증 URL 생성
      final redirectUriEncoded = Uri.encodeComponent(redirectUri);
      final state = DateTime.now().millisecondsSinceEpoch.toString();
      final authUrl =
          'https://nid.naver.com/oauth2.0/authorize'
          '?response_type=code'
          '&client_id=$naverClientId'
          '&redirect_uri=$redirectUriEncoded'
          '&state=$state';

      debugPrint('🌐 네이버 로그인 페이지로 이동: $authUrl');

      // 네이버 로그인 페이지로 리다이렉트
      html.window.location.href = authUrl;

      // 리다이렉트되므로 여기서는 null 반환
      // 실제 처리는 /loading 페이지에서 handleNaverCallback으로 수행
      return null;
    } catch (e) {
      debugPrint('네이버 로그인 웹 에러: $e');
      rethrow;
    }
  }

  /// 네이버 로그인 (모바일)
  /// 네이티브 SDK 사용
  @pragma('vm:entry-point')
  Future<AuthResponse?> signInWithNaverNative() async {
    if (kIsWeb) {
      throw UnsupportedError('모바일 전용 메서드입니다');
    }

    try {
      // 1. 네이버 SDK로 로그인
      final NaverLoginResult result = await FlutterNaverLogin.logIn();

      if (result.status != NaverLoginStatus.loggedIn) {
        throw Exception('네이버 로그인 실패: ${result.errorMessage}');
      }

      // 2. Access Token 가져오기
      final NaverAccessToken token = await FlutterNaverLogin.currentAccessToken;

      if (token.accessToken.isEmpty) {
        throw Exception('Access Token이 없습니다');
      }

      // 3. Workers API 호출하여 Supabase 인증 처리
      return await _exchangeNaverToken(
        accessToken: token.accessToken,
        platform: 'mobile',
      );
    } catch (e) {
      debugPrint('네이버 로그인 모바일 에러: $e');
      rethrow;
    }
  }

  /// 웹 콜백 처리 (리다이렉트 후)
  /// URL의 code 파라미터를 추출하여 Workers API 호출
  Future<AuthResponse?> handleNaverCallback(
    String code, [
    String? state,
  ]) async {
    try {
      debugPrint('📥 네이버 콜백 처리: code=$code');

      // Workers API 호출
      return await _exchangeNaverToken(
        code: code,
        platform: 'web',
        state: state,
      );
    } catch (e) {
      debugPrint('❌ 네이버 콜백 처리 에러: $e');
      rethrow;
    }
  }

  /// Cloudflare Workers 호출하여 Supabase 세션 생성
  ///
  /// 웹: code를 전달 (Workers에서 토큰 교환)
  /// 모바일: accessToken을 전달
  /// 
  /// 로컬/프로덕션: Cloudflare Workers 사용
  Future<AuthResponse?> _exchangeNaverToken({
    String? accessToken,
    String? code,
    required String platform,
    String? state,
  }) async {
    try {
      debugPrint('📤 네이버 토큰 교환 시작... (platform=$platform)');

      // 요청 Body 구성
      final Map<String, dynamic> body = {'platform': platform};

      if (platform == 'web' && code != null) {
        body['code'] = code;
        if (state != null) {
          body['state'] = state;
        }
      } else if (platform == 'mobile' && accessToken != null) {
        body['accessToken'] = accessToken;
      } else {
        throw Exception('웹의 경우 code가, 모바일의 경우 accessToken이 필요합니다');
      }

      // ============================================
      // Cloudflare Workers 사용 (로컬/프로덕션 모두 프로덕션 Workers 사용)
      // ============================================
      final workersUrl = SupabaseConfig.workersApiUrl;
      debugPrint('📤 Workers API 호출: $workersUrl/api/naver-auth');
      debugPrint('   - platform: $platform');
      debugPrint('   - body keys: ${body.keys.toList()}');

      final httpResponse = await http
          .post(
            Uri.parse('$workersUrl/api/naver-auth'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Workers API 호출 타임아웃 (30초 초과)');
            },
          );

      // ============================================
      // Edge Function 사용 (삭제됨 - Workers로 전환 완료)
      // ============================================
      // 이전에는 Supabase Edge Function을 사용했으나,
      // Cloudflare Workers로 완전 전환하여 제거됨

      debugPrint('📥 API 응답: status=${httpResponse.statusCode}');
      debugPrint('   - body: ${httpResponse.body}');

      if (httpResponse.statusCode != 200) {
        Map<String, dynamic>? errorData;
        try {
          errorData = jsonDecode(httpResponse.body) as Map<String, dynamic>?;
        } catch (e) {
          debugPrint('⚠️ 에러 응답 JSON 파싱 실패: $e');
        }
        final errorMessage =
            errorData?['error'] ?? errorData?['message'] ?? '인증 실패';
        debugPrint('❌ API 에러 응답: $errorMessage');
        throw Exception(errorMessage);
      }

      final data = jsonDecode(httpResponse.body) as Map<String, dynamic>;

      if (data['error'] != null) {
        debugPrint('❌ Workers API 에러: ${data['error']}');
        throw Exception(data['error']);
      }

      if (data['access_token'] == null) {
        debugPrint('❌ Workers API 응답에 access_token이 없습니다');
        debugPrint('   - 응답 데이터: $data');
        throw Exception('Workers API 응답에 access_token이 없습니다');
      }

      if (data['user'] == null) {
        debugPrint('❌ Workers API 응답에 user가 없습니다');
        debugPrint('   - 응답 데이터: $data');
        throw Exception('Workers API 응답에 user가 없습니다');
      }

      final String customAccessToken = data['access_token'] as String;
      final String customRefreshToken = data['refresh_token'] as String? ?? '';
      final userData = data['user'] as Map<String, dynamic>;

      debugPrint('✅ Workers API 응답 성공');
      debugPrint('   - User ID: ${userData['id']}');
      debugPrint('   - Email: ${userData['email']}');

      // Supabase 세션 생성
      // 주의: customRefreshToken은 실제 Supabase refresh token이 아니므로
      // setSession 대신 직접 세션 객체를 생성하여 설정
      final user = User.fromJson(userData);

      if (user == null) {
        throw Exception('사용자 정보를 파싱할 수 없습니다');
      }

      final session = Session(
        accessToken: customAccessToken,
        refreshToken: customRefreshToken,
        tokenType: data['token_type'] as String? ?? 'bearer',
        expiresIn: data['expires_in'] as int? ?? 86400,
        user: user,
      );

      // 세션 설정
      // 주의: Supabase SDK의 setSession은 refreshToken을 받지만,
      // 우리가 만든 custom JWT는 Supabase의 표준 refresh token이 아님
      // 따라서 accessToken을 직접 사용하여 세션을 설정
      // 하지만 setSession은 refreshToken만 받으므로, 다른 방법 사용 필요

      // 세션 설정 시도
      // 주의: Supabase SDK의 setSession은 표준 refresh token을 기대함
      // Custom JWT의 경우, accessToken을 직접 사용할 수 없음
      // 대안: Supabase의 내부 메서드를 사용하거나, 세션을 수동으로 저장

      // Custom JWT 세션 설정
      // 주의: Supabase SDK의 setSession은 표준 refresh token을 기대하지만,
      // Custom JWT의 refresh token은 표준 형식이 아님
      // 따라서 accessToken을 직접 사용하여 세션을 설정해야 함
      try {
        // Supabase SDK의 내부 메서드를 사용하여 accessToken으로 세션 설정
        // setSession은 refreshToken만 받지만, 우리는 accessToken을 사용해야 함
        // 대안: Supabase의 내부 메서드를 사용하거나, 세션을 수동으로 저장

        // 방법: accessToken을 사용하여 세션을 직접 설정
        // Supabase SDK는 setSession(refreshToken)만 지원하므로,
        // Custom JWT의 경우 세션을 수동으로 관리해야 함

        // Custom JWT 저장 (통합 세션 관리자 사용)
        try {
          // 이름 정보 추출 (회원가입 화면에서 사용)
          final userMetadata =
              userData['user_metadata'] as Map<String, dynamic>? ?? {};
          final fullName =
              userMetadata['full_name'] as String? ??
              userMetadata['name'] as String? ??
              userMetadata['display_name'] as String? ??
              '';
          
          // CustomJwtSessionProvider를 통해 세션 저장 (저장 완료 확인)
          await CustomJwtSessionProvider.saveSessionAndVerify(
            token: customAccessToken,
            userId: user.id,
            email: user.email,
            provider: 'naver',
          );

          // 이름 정보도 저장 (회원가입 화면에서 사용)
          // Secure Storage 사용 (CustomJwtSessionProvider와 동일한 저장소)
          if (fullName.isNotEmpty) {
            const storage = FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );
            await storage.write(key: 'custom_jwt_user_name', value: fullName);
          }

          debugPrint('✅ Custom JWT를 통합 세션 관리자에 저장했습니다');
          debugPrint('   - Email: ${user.email}');
          debugPrint('   - Name: $fullName');
        } catch (e) {
          debugPrint('⚠️ Custom JWT 세션 저장 실패: $e');
        }

        // setSession 시도 (실패할 가능성 높지만 시도)
        if (customRefreshToken.isNotEmpty) {
          try {
            await _supabase.auth.setSession(customRefreshToken);
            debugPrint('✅ setSession 성공 (refreshToken 사용)');
          } catch (setSessionError) {
            debugPrint('⚠️ setSession 실패 (예상됨): $setSessionError');
            // Custom JWT의 경우 setSession이 실패하는 것이 정상
            // localStorage에 저장한 토큰을 사용하여 세션으로 인식
          }
        }
      } catch (e) {
        debugPrint('⚠️ 세션 설정 중 에러: $e');
        // 에러가 발생해도 세션 객체는 반환
      }

      return AuthResponse(session: session, user: user);
    } catch (e) {
      debugPrint('❌ 토큰 교환 에러: $e');
      rethrow;
    }
  }

  /// 네이버 로그아웃
  Future<void> signOut() async {
    try {
      // 네이버 로그아웃 (모바일만)
      if (!kIsWeb) {
        try {
          await FlutterNaverLogin.logOut();
        } catch (e) {
          debugPrint('네이버 SDK 로그아웃 실패 (무시): $e');
        }
      }

      // Supabase 로그아웃
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('로그아웃 에러: $e');
      rethrow;
    }
  }

  /// 네이버 로그인 상태 확인 (모바일만)
  /// 앱 재시작 시 자동 로그인에 사용
  Future<bool> isNaverLoggedIn() async {
    if (kIsWeb) {
      return false; // 웹에서는 사용하지 않음
    }

    try {
      return await FlutterNaverLogin.isLoggedIn;
    } catch (e) {
      debugPrint('네이버 로그인 상태 확인 실패: $e');
      return false;
    }
  }

  /// 네이버 Access Token 가져오기 (모바일만)
  /// 앱 재시작 시 세션 복원에 사용
  Future<String?> getNaverAccessToken() async {
    if (kIsWeb) {
      return null; // 웹에서는 사용하지 않음
    }

    try {
      final token = await FlutterNaverLogin.currentAccessToken;
      return token.accessToken.isNotEmpty ? token.accessToken : null;
    } catch (e) {
      debugPrint('네이버 토큰 가져오기 실패: $e');
      return null;
    }
  }
}
