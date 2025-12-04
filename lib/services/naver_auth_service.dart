import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../config/supabase_config.dart';

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
/// Cloudflare Workers를 통해 Supabase 인증 처리
class NaverAuthService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  
  // 전역 해시 변경 리스너 (웹에서만 사용)
  static StreamSubscription<html.Event>? _globalHashSubscription;
  static bool _isListening = false;
  
  /// 웹에서 해시 변경 감지 시작 (앱 시작 시 또는 로그인 버튼 클릭 시 호출)
  static void startListeningForHashChange() {
    if (!kIsWeb) return;
    
    // 이미 리스닝 중이면 중지 후 재시작
    if (_isListening) {
      stopListeningForHashChange();
    }
    
    _isListening = true;
    
    // 해시 변경 이벤트 리스너
    _globalHashSubscription = html.window.onHashChange.listen((html.Event event) {
      final hash = html.window.location.hash;
      if (hash.isNotEmpty) {
        final hashParams = Uri.splitQueryString(hash.substring(1));
        final accessToken = hashParams['access_token'];
        if (accessToken != null) {
          debugPrint('전역 해시 변경 감지: 네이버 로그인 토큰 발견');
          _processHashFromGlobalListener(accessToken);
        }
      }
    });
    
    // 현재 해시 즉시 확인
    _checkCurrentHash();
    
    // 주기적으로 해시 확인 (Flutter 앱 리로드 후 해시 복구)
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isListening) {
        timer.cancel();
        return;
      }
      _checkCurrentHash();
    });
  }
  
  /// 현재 해시 확인
  static void _checkCurrentHash() {
    if (!kIsWeb) return;
    
    final currentHash = html.window.location.hash;
    if (currentHash.isNotEmpty) {
      final hashParams = Uri.splitQueryString(currentHash.substring(1));
      final accessToken = hashParams['access_token'];
      if (accessToken != null) {
        debugPrint('전역 해시 확인: 네이버 로그인 토큰 발견');
        _processHashFromGlobalListener(accessToken);
      }
    }
  }
  
  /// 전역 리스너에서 해시 처리
  static Future<void> _processHashFromGlobalListener(String accessToken) async {
    try {
      final service = NaverAuthService();
      final authResponse = await service.handleNaverCallback(accessToken);
      if (authResponse?.user != null) {
        debugPrint('전역 리스너: 네이버 로그인 성공');
        // 로그인 성공 시 세션이 설정되면 authStateChanges가 자동으로 홈으로 리다이렉트
        // GoRouter의 redirect 로직에서 처리됨
      }
    } catch (e) {
      debugPrint('전역 리스너: 네이버 로그인 처리 오류: $e');
    }
  }
  
  /// 해시 변경 감지 중지
  static void stopListeningForHashChange() {
    _globalHashSubscription?.cancel();
    _globalHashSubscription = null;
    _isListening = false;
  }

  /// 네이버 로그인 전체 플로우
  Future<AuthResponse?> signInWithNaver() async {
    try {
      if (kIsWeb) {
        // 웹에서는 네이버 JavaScript SDK 사용
        return await _signInWithNaverWeb();
      } else {
        // 모바일에서는 네이티브 SDK 사용
        return await _signInWithNaverMobile();
      }
    } catch (e) {
      debugPrint('네이버 로그인 에러: $e');
      rethrow;
    }
  }

  /// 네이버 로그인 (웹)
  Future<AuthResponse?> _signInWithNaverWeb() async {
    try {
      // 네이버 JavaScript SDK 로드
      if (html.document.getElementById('naver-login-script') == null) {
        final script = html.ScriptElement()
          ..id = 'naver-login-script'
          ..src = 'https://static.nid.naver.com/js/naveridlogin_js_sdk_2.0.2.js'
          ..type = 'text/javascript';
        html.document.head!.append(script);
        await script.onLoad.first;
      }

      // 네이버 로그인: 직접 OAuth URL로 리다이렉트
      // SDK를 사용하지 않고 직접 OAuth 인증 페이지로 이동
      final callbackUrl = html.window.location.origin + '/loading';
      const clientId = 'Gx2IIkdRCTg32kobQj7J'; // TODO: 환경 변수로 관리
      
      // 네이버 OAuth 인증 URL 생성
      final redirectUri = Uri.encodeComponent(callbackUrl);
      final state = DateTime.now().millisecondsSinceEpoch.toString();
      final authUrl = 'https://nid.naver.com/oauth2.0/authorize?response_type=token&client_id=$clientId&redirect_uri=$redirectUri&state=$state';
      
      // 네이버 로그인 페이지로 리다이렉트
      html.window.location.href = authUrl;
      
      // 리다이렉트되므로 여기서는 대기만 함
      await Future.delayed(const Duration(seconds: 1));

      // 해시에서 직접 토큰 확인
      if (html.window.location.hash.isNotEmpty) {
        final hash = html.window.location.hash.substring(1);
        final params = Uri.splitQueryString(hash);
        final accessToken = params['access_token'];
        if (accessToken != null) {
          return await handleNaverCallback(accessToken);
        }
      }

      // 해시 변경 감지로 토큰 수신 대기
      final completer = Completer<String>();
      StreamSubscription<html.Event>? hashSubscription;

      hashSubscription = html.window.onHashChange.listen((html.Event event) {
        final hash = html.window.location.hash;
        if (hash.isNotEmpty) {
          final hashParams = Uri.splitQueryString(hash.substring(1));
          final accessToken = hashParams['access_token'];
          if (accessToken != null && !completer.isCompleted) {
            hashSubscription?.cancel();
                  completer.complete(accessToken);
                }
              }
            });

            // 타임아웃 설정 (5분)
            try {
              final token = await completer.future.timeout(
                const Duration(minutes: 5),
                onTimeout: () {
                  hashSubscription?.cancel();
                  throw Exception('네이버 로그인 타임아웃');
                },
              );
              return await handleNaverCallback(token);
      } finally {
        hashSubscription.cancel();
      }
    } catch (e) {
      debugPrint('네이버 로그인 웹 에러: $e');
      rethrow;
    }
  }

  /// 네이버 로그인 (모바일)
  @pragma('vm:entry-point')
  Future<AuthResponse?> _signInWithNaverMobile() async {
    // 웹에서는 호출되지 않음 (kIsWeb 체크로 보호됨)
    if (kIsWeb) {
      throw UnsupportedError('모바일 전용 메서드입니다');
    }

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
    return await handleNaverCallback(token.accessToken);
  }

  /// 네이버 콜백 처리 (Workers API 호출)
  /// 외부에서도 사용할 수 있도록 public으로 변경
  Future<AuthResponse?> handleNaverCallback(String accessToken) async {
    try {
      // Cloudflare Workers API로 토큰 전달
      final response = await http.post(
        Uri.parse('${SupabaseConfig.workersApiUrl}/api/auth/callback/naver'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'accessToken': accessToken}),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['error'] ?? '인증 실패');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      
      if (data['success'] != true) {
        throw Exception(data['error'] ?? '네이버 로그인 실패');
      }

      final email = data['email'] as String?;
      final isNewUser = data['isNewUser'] as bool? ?? false;
      final refreshToken = data['refreshToken'] as String?;

      debugPrint('네이버 로그인 성공: email=$email, isNewUser=$isNewUser');

      // 세션 토큰으로 직접 세션 설정 (비밀번호 사용하지 않음)
      if (refreshToken != null) {
        // refreshToken으로 세션 설정
        final sessionResponse = await _supabase.auth.setSession(refreshToken);
        if (sessionResponse.session != null) {
          debugPrint('네이버 로그인 세션 생성 완료 (토큰 방식)');
          return sessionResponse;
        }
      }

      // 폴백: 세션 토큰이 없는 경우 (이전 버전 호환성)
      final fallback = data['fallback'] as Map<String, dynamic>?;
      if (fallback != null && fallback['usePasswordLogin'] == true) {
        final tempPassword = fallback['tempPassword'] as String?;
        if (tempPassword != null && email != null) {
          debugPrint('네이버 로그인 폴백: 비밀번호 방식 사용');
          final authResponse = await _supabase.auth.signInWithPassword(
            email: email,
            password: tempPassword,
          );
          debugPrint('네이버 로그인 세션 생성 완료 (폴백)');
          return authResponse;
        }
      }

      throw Exception('세션 생성에 필요한 정보가 없습니다');
    } catch (e) {
      debugPrint('네이버 콜백 처리 에러: $e');
      rethrow;
    }
  }

  /// 네이버 로그아웃
  Future<void> signOut() async {
    if (!kIsWeb) {
      await FlutterNaverLogin.logOut();
    }
    await _supabase.auth.signOut();
  }
}
