import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
import '../models/user.dart' as app_user;
import '../config/supabase_config.dart';
import '../utils/error_handler.dart';
import 'user_service.dart';
import 'naver_auth_service.dart';
import '../utils/date_time_utils.dart';

/// 사용자 인증 상태
enum UserState {
  notLoggedIn, // 세션 없음
  loggedIn, // 세션 있고 프로필 있음
  tempSession, // 세션 있지만 프로필 없음 (OAuth 회원가입 필요)
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final UserService _userService = UserService();
  // GoogleSignIn 인스턴스 생성 방식 변경 (v7 API)
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // 사용자 상태 확인 (중복 프로필 체크 제거)
  Future<UserState> getUserState() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      return UserState.notLoggedIn;
    }

    try {
      // 세션 만료 확인 및 토큰 갱신
      if (session.isExpired) {
        try {
          final refreshedSession = await _supabase.auth.refreshSession();
          if (refreshedSession.session == null) {
            return UserState.notLoggedIn;
          }
        } catch (refreshError) {
          // 토큰 갱신 실패 시 로그아웃 처리
          if (ErrorHandler.isMissingDestinationScopesError(refreshError) ||
              ErrorHandler.isOAuthClientIdError(refreshError)) {
            await _supabase.auth.signOut();
            return UserState.notLoggedIn;
          }
          // 네트워크 에러 등은 재시도 가능하므로 현재 상태 유지
          // 세션이 만료되었지만 갱신 실패 시에도 프로필 체크는 진행
        }
      }

      // RPC 함수 호출로 안전한 프로필 조회
      await _supabase.rpc(
        'get_user_profile_safe',
        params: {'p_user_id': session.user.id},
      );

      return UserState.loggedIn;
    } catch (e) {
      // 네트워크 에러 확인
      if (e is SocketException || e is TimeoutException) {
        // 네트워크 에러는 재시도 가능하므로 loggedIn으로 간주
        debugPrint('네트워크 에러 발생, 재시도 필요: $e');
        return UserState.loggedIn;
      }

      // 프로필 없음 확인
      final isProfileNotFound =
          e.toString().contains('User profile not found') ||
          (e is PostgrestException &&
              (e.code == 'PGRST116' || e.message.contains('No rows returned')));

      if (isProfileNotFound) {
        return UserState.tempSession;
      }

      // 기타 에러는 로그인 상태로 간주 (재시도)
      debugPrint('프로필 조회 실패: $e');
      return UserState.loggedIn;
    }
  }

  // 현재 사용자 가져오기 (RPC 사용 - 보안 강화)
  Future<app_user.User?> get currentUser async {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    if (user != null) {
      try {
        // 세션 만료 확인 및 토큰 갱신 시도
        if (session!.isExpired) {
          debugPrint('세션이 만료되었습니다. 토큰 갱신 시도...');
          try {
            final refreshedSession = await _supabase.auth.refreshSession();
            if (refreshedSession.session == null) {
              debugPrint('토큰 갱신 실패. 로그아웃 처리');
              await _supabase.auth.signOut();
              return null;
            }
          } catch (refreshError) {
            debugPrint('토큰 갱신 중 에러 발생: $refreshError');

            // "missing destination name scopes" 에러인 경우 손상된 세션으로 간주
            if (ErrorHandler.isMissingDestinationScopesError(refreshError)) {
              debugPrint(
                '손상된 세션 감지 (missing destination name scopes). 로그아웃 처리',
              );
              ErrorHandler.handleAuthError(
                refreshError,
                context: {
                  'action': 'refreshSession',
                  'error_type': 'missing_destination_scopes',
                  'user_id': session.user.id,
                  'expires_at': session.expiresAt != null
                      ? DateTime.fromMillisecondsSinceEpoch(
                          session.expiresAt! * 1000,
                        ).toIso8601String()
                      : null,
                },
              );
              try {
                await _supabase.auth.signOut();
              } catch (_) {
                // 로그아웃 실패는 무시
              }
              return null;
            }

            // oauth_client_id 관련 에러인 경우 손상된 세션으로 간주
            if (ErrorHandler.isOAuthClientIdError(refreshError)) {
              debugPrint('손상된 세션 감지 (oauth_client_id 에러). 로그아웃 처리');
              try {
                await _supabase.auth.signOut();
              } catch (_) {
                // 로그아웃 실패는 무시
              }
            }
            return null;
          }
        }

        // RPC 함수 호출로 안전한 프로필 조회
        final profileResponse = await _supabase.rpc(
          'get_user_profile_safe',
          params: {'p_user_id': user.id},
        );

        // 데이터베이스 프로필 정보로 User 객체 생성
        final userProfile = app_user.User.fromDatabaseProfile(
          profileResponse,
          user,
        );

        // 사용자 통계 계산 (level, reviewCount)
        final stats = await _userService.getUserStats(userProfile.uid);

        return userProfile.copyWith(
          level: stats['level'],
          reviewCount: stats['reviewCount'],
        );
      } catch (e) {
        // oauth_client_id 관련 에러인 경우 손상된 세션으로 간주
        if (ErrorHandler.isOAuthClientIdError(e)) {
          debugPrint('손상된 세션 감지 (oauth_client_id 에러). 로그아웃 처리');
          ErrorHandler.handleAuthError(
            e,
            context: {'action': 'currentUser', 'error_type': 'oauth_client_id'},
          );
          try {
            await _supabase.auth.signOut();
          } catch (_) {
            // 로그아웃 실패는 무시
          }
          return null;
        }

        // 프로필이 없는 경우 null 반환 (자동 생성 제거)
        final isProfileNotFound =
            e.toString().contains('User profile not found') ||
            (e is PostgrestException &&
                (e.code == 'PGRST116' ||
                    e.message.contains('No rows returned')));

        if (isProfileNotFound) {
          // 프로필 없음 → null 반환 (signup으로 리다이렉트)
          debugPrint('프로필이 없습니다. 회원가입이 필요합니다: ${user.id}');
          return null;
        } else {
          // 다른 에러인 경우
          debugPrint('사용자 프로필 조회 실패: $e');
          return null;
        }
      }
    }
    return null;
  }

  // 인증 상태 스트림 (RPC 사용 - 보안 강화)
  Stream<app_user.User?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.asyncMap((authState) async {
      final user = authState.session?.user;
      if (user != null) {
        try {
          // RPC 함수 호출로 안전한 프로필 조회
          final profileResponse = await _supabase.rpc(
            'get_user_profile_safe',
            params: {'p_user_id': user.id},
          );

          // 데이터베이스 프로필 정보로 User 객체 생성
          final userProfile = app_user.User.fromDatabaseProfile(
            profileResponse,
            user,
          );

          // 사용자 통계 계산 (level, reviewCount)
          final stats = await _userService.getUserStats(user.id);

          return userProfile.copyWith(
            level: stats['level'],
            reviewCount: stats['reviewCount'],
          );
        } catch (e) {
          // 프로필이 없는 경우 null 반환 (자동 생성 제거)
          final isProfileNotFound =
              e.toString().contains('User profile not found') ||
              (e is PostgrestException &&
                  (e.code == 'PGRST116' ||
                      e.message.contains('No rows returned')));

          if (isProfileNotFound) {
            // 프로필 없음 → null 반환 (signup으로 리다이렉트)
            debugPrint('프로필이 없습니다. 회원가입이 필요합니다: ${user.id}');
            return null;
          } else {
            // 다른 에러인 경우
            debugPrint('사용자 프로필 조회 실패: $e');
            return null;
          }
        }
      }
      return null;
    });
  }

  // Google 로그인
  Future<void> signInWithGoogle() async {
    try {
      // 웹 플랫폼용 Google Client ID는 Supabase 대시보드에서 설정해야 합니다.
      // initialize 호출 추가 (v7 API)
      await _googleSignIn.initialize(
        clientId: kIsWeb
            ? 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com'
            : null,
      );

      // 모바일 앱에서는 커스텀 URL 스킴으로 리다이렉트
      final redirectTo = kIsWeb
          ? null // 웹에서는 기본값 사용
          : 'com.smart-grow.smart-review://login-callback';

      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.inAppWebView
            : LaunchMode.externalApplication,
        redirectTo: redirectTo,
        queryParams: {'access_type': 'offline', 'prompt': 'consent'},
      );

      // 로그인 성공 시 프로필 관리는 authStateChanges에서 자동으로 처리됨
      // currentUser 호출 제거 (타이밍 문제 해결)
    } catch (e) {
      throw Exception('Google 로그인 실패: $e');
    }
  }

  // 이메일/비밀번호 로그인
  Future<app_user.User?> signInWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // 로그인 성공 시 프로필 관리는 authStateChanges와 currentUser에서 처리
      // 중복 호출을 방지하기 위해 여기서는 _ensureUserProfile을 호출하지 않음
      if (response.user != null) {
        return await currentUser;
      }
      return null;
    } catch (e) {
      throw Exception('이메일 로그인 실패: $e');
    }
  }

  // 이메일/비밀번호 회원가입 (개발용)
  Future<app_user.User?> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      debugPrint('회원가입 시작: $email, displayName: $displayName');

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );

      debugPrint('Supabase 회원가입 응답: ${response.user?.id}');

      if (response.user != null) {
        debugPrint('회원가입 성공, 프로필 생성 시도: ${response.user!.id}');

        // 회원가입 후 프로필 생성 (isSignUp=true로 표시)
        await _ensureUserProfile(
          response.user!,
          displayName,
          app_user.UserType.user, // 기본값 설정
          isSignUp: true, // 회원가입 중임을 표시
        );

        debugPrint('프로필 생성 완료: ${response.user!.id}');
        // DB에서 최신 프로필 가져오기 (company_id 등 포함)
        return await currentUser;
      }
      return null;
    } catch (e) {
      debugPrint('이메일 회원가입 실패: $e');
      throw Exception('이메일 회원가입 실패: $e');
    }
  }

  // Kakao 로그인
  Future<void> signInWithKakao() async {
    try {
      if (kIsWeb) {
        // 웹에서는 Supabase OAuth 사용
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.kakao,
          authScreenLaunchMode: LaunchMode.inAppWebView,
        );

        // 로그인 성공 시 프로필 관리는 authStateChanges에서 자동으로 처리됨
        // currentUser 호출 제거 (타이밍 문제 해결)
      } else {
        // 모바일에서는 Supabase OAuth 사용 (카카오톡 앱 의존성 제거)
        final redirectTo = 'com.smart-grow.smart-review://login-callback';

        await _supabase.auth.signInWithOAuth(
          OAuthProvider.kakao,
          authScreenLaunchMode: LaunchMode.externalApplication,
          redirectTo: redirectTo,
        );

        // 로그인 성공 시 프로필 관리는 authStateChanges에서 자동으로 처리됨
        // currentUser 호출 제거 (타이밍 문제 해결)
      }
    } catch (e) {
      throw Exception('Kakao 로그인 실패: $e');
    }
  }

  // 네이버 로그인
  Future<void> signInWithNaver() async {
    try {
      // 새로운 NaverAuthService 사용 (Workers 기반)
      final naverAuthService = NaverAuthService();
      final result = await naverAuthService.signInWithNaver();

      if (result?.user == null) {
        throw Exception('네이버 로그인 실패: 사용자 정보를 가져올 수 없습니다');
      }

      // 로그인 성공 시 프로필 관리 (authStateChanges에서 자동으로 처리됨)
      final user = result!.user;
      debugPrint('네이버 로그인 성공: ${user?.email ?? user?.id ?? 'unknown'}');
    } catch (e) {
      debugPrint('네이버 로그인 에러: $e');
      throw Exception('Naver 로그인 실패: $e');
    }
  }

  // 네이버 로그인 (웹)
  Future<void> _signInWithNaverWeb() async {
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

      // 네이버 로그인 초기화 및 버튼 생성
      final callbackUrl = html.window.location.origin + '/loading';

      // JavaScript 코드 실행을 위한 스크립트 태그 생성
      final initScript = html.ScriptElement()
        ..text =
            '''
        (function() {
          if (!window.naverLoginInstance) {
            window.naverLoginInstance = new naver.LoginWithNaverId({
              clientId: "Gx2IIkdRCTg32kobQj7J",
              callbackUrl: "$callbackUrl",
              callbackHandle: true,
              isPopup: false,
              loginButton: { color: "green", type: 1, height: "60" }
            });
            window.naverLoginInstance.init();
          }
          
          // 콜백 처리
          window.naverLoginCallback = function() {
            const hash = window.location.hash.substring(1);
            const params = new URLSearchParams(hash);
            const accessToken = params.get("access_token");
            if (accessToken) {
              window.naverAccessToken = accessToken;
              const event = new CustomEvent('naver-login-token', { detail: accessToken });
              window.dispatchEvent(event);
            }
          };
          
          // 해시 변경 감지
          if (window.location.hash) {
            window.naverLoginCallback();
          }
          window.addEventListener('hashchange', window.naverLoginCallback);
        })();
        ''';
      html.document.head!.append(initScript);
      await Future.delayed(const Duration(milliseconds: 100));

      // 네이버 로그인 버튼 클릭 트리거
      await Future.delayed(const Duration(milliseconds: 500)); // SDK 초기화 대기
      final clickScript = html.ScriptElement()
        ..text =
            '''
        (function() {
          const loginButton = document.getElementById("naverIdLogin_loginButton");
          if (loginButton) {
            loginButton.click();
          } else {
            // 버튼이 없으면 직접 로그인 페이지로 이동
            const clientId = "Gx2IIkdRCTg32kobQj7J";
            const redirectUri = encodeURIComponent("$callbackUrl");
            const state = Math.random().toString(36).substring(2, 15);
            const url = "https://nid.naver.com/oauth2.0/authorize?response_type=token&client_id=" + clientId + "&redirect_uri=" + redirectUri + "&state=" + state;
            window.location.href = url;
          }
        })();
        ''';
      html.document.head!.append(clickScript);
      await Future.delayed(const Duration(milliseconds: 100));

      // 해시에서 직접 토큰 확인
      if (html.window.location.hash.isNotEmpty) {
        final hash = html.window.location.hash.substring(1);
        final params = Uri.splitQueryString(hash);
        final accessToken = params['access_token'];
        if (accessToken != null) {
          await _handleNaverCallback(accessToken);
          return;
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
        await _handleNaverCallback(token);
      } finally {
        hashSubscription.cancel();
      }
    } catch (e) {
      debugPrint('네이버 로그인 웹 에러: $e');
      rethrow;
    }
  }

  // 네이버 콜백 처리
  Future<void> _handleNaverCallback(String accessToken) async {
    try {
      debugPrint('네이버 로그인 콜백 처리 시작: $accessToken');

      // Cloudflare Workers API로 토큰 전달
      final response = await http.post(
        Uri.parse('${SupabaseConfig.workersApiUrl}/api/auth/callback/naver'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'accessToken': accessToken}),
      );

      debugPrint('Workers API 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final email = data['email'] as String?;
        final isNewUser = data['isNewUser'] as bool? ?? false;
        final accessToken = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;
        final usePasswordLogin = data['usePasswordLogin'] as bool? ?? false;
        final password = data['password'] as String?;

        debugPrint('네이버 로그인 성공: email=$email, isNewUser=$isNewUser');

        // 세션 생성
        if (accessToken != null && refreshToken != null) {
          // Magic Link로 생성된 토큰 사용
          // Supabase Flutter SDK의 setSession은 refreshToken만 받음
          final sessionResponse = await _supabase.auth.setSession(refreshToken);
          if (sessionResponse.session != null) {
            debugPrint('네이버 로그인 세션 생성 완료 (Magic Link)');
          } else {
            throw Exception('세션 생성 실패');
          }
        } else if (usePasswordLogin && password != null && email != null) {
          // 비밀번호로 로그인 (임시 방법)
          await _supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
          debugPrint('네이버 로그인 세션 생성 완료 (Password)');
        } else {
          throw Exception('세션 생성에 필요한 정보가 없습니다');
        }

        // 프로필 생성 확인 및 생성
        final user = _supabase.auth.currentUser;
        if (user != null) {
          await _ensureUserProfile(
            user,
            data['name'] as String? ?? email ?? 'User',
            app_user.UserType.user,
            isSignUp: isNewUser,
          );
        }
      } else {
        final errorBody = response.body;
        debugPrint('Workers API 에러: $errorBody');
        throw Exception('네이버 로그인 콜백 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('네이버 로그인 콜백 처리 실패: $e');
      rethrow;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      // Google 로그아웃
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Google 로그아웃 실패: $e');
      }

      // Kakao 로그아웃 (초기화된 경우에만)
      try {
        if (await kakao.isKakaoTalkInstalled()) {
          await kakao.UserApi.instance.logout();
        }
      } catch (e) {
        debugPrint('Kakao 로그아웃 실패: $e');
      }

      // Supabase 로그아웃
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('로그아웃 실패: $e');
    }
  }

  // 사용자 프로필 생성 (RPC 사용 - 보안 강화)
  // [isSignUp] true인 경우 회원가입 중이므로 프로필 생성 실패 시 에러만 throw
  // false인 경우 로그인 중이므로 프로필 생성 실패해도 에러를 숨김 (이미 로그인된 사용자이므로)
  Future<void> _createUserProfile(
    User user,
    String displayName,
    app_user.UserType userType, {
    bool isSignUp = false,
  }) async {
    try {
      debugPrint(
        '_createUserProfile 시작: ${user.id}, displayName: $displayName, userType: ${userType.name}, isSignUp: $isSignUp',
      );

      // 회원가입 시 기본적으로 user 타입으로 생성 (admin은 관리자만 생성 가능)
      final actualUserType = userType == app_user.UserType.user
          ? app_user.UserType.user
          : userType;

      debugPrint('실제 사용자 타입: ${actualUserType.name} (원본: ${userType.name})');

      // RPC 함수 호출로 안전한 사용자 프로필 생성
      final response = await _supabase.rpc(
        'create_user_profile_safe',
        params: {
          'p_user_id': user.id,
          'p_display_name': displayName,
          'p_user_type': actualUserType.name,
        },
      );

      debugPrint('사용자 프로필 및 포인트 지갑 생성 성공: ${user.id}');
      debugPrint('생성된 프로필: $response');
    } catch (e) {
      ErrorHandler.handleDatabaseError(
        e,
        context: {
          'user_id': user.id,
          'display_name': displayName,
          'user_type': userType.name,
          'operation': 'create_user_profile',
          'is_sign_up': isSignUp.toString(),
        },
      );

      // 중요: 클라이언트에서는 auth.admin.deleteUser를 호출할 수 없음 (관리자 권한 필요)
      // 회원가입 실패 시에도 orphaned user를 생성하지 않도록 에러만 throw
      // 실제 롤백은 서버 사이드(Edge Function)에서 처리하거나,
      // 데이터베이스 트랜잭션으로 처리해야 함

      if (isSignUp) {
        debugPrint(
          '⚠️ 회원가입 중 프로필 생성 실패: ${user.id}. '
          'auth.users에는 사용자가 생성되었지만 public.users에는 프로필이 없을 수 있습니다. '
          '서버 사이드에서 정리 작업이 필요할 수 있습니다.',
        );
      } else {
        debugPrint(
          '⚠️ 로그인 중 프로필 생성 실패: ${user.id}. '
          '프로필이 없어도 로그인은 유지됩니다.',
        );
      }

      // 회원가입 중일 때만 에러를 throw (로그인 중일 때는 에러를 숨김)
      if (isSignUp) {
        rethrow; // 에러를 상위로 전파하여 회원가입 실패 처리
      }
      // 로그인 중일 때는 에러를 숨김 (이미 로그인된 사용자이므로)
    }
  }

  // 사용자 프로필 확인 및 생성
  Future<void> _ensureUserProfile(
    User user,
    String displayName,
    app_user.UserType userType, {
    bool isSignUp = false,
  }) async {
    try {
      debugPrint(
        '_ensureUserProfile 시작: ${user.id}, displayName: $displayName, isSignUp: $isSignUp',
      );

      // RPC 함수로 안전하게 프로필 조회 (SECURITY DEFINER로 RLS 우회)
      final profileResponse = await _supabase.rpc(
        'get_user_profile_safe',
        params: {'p_user_id': user.id},
      );

      debugPrint('사용자 프로필이 이미 존재함: ${user.id}');

      // 프로필이 존재하면 업데이트 (필요 시)
      // display_name이 변경되었을 때만 업데이트
      if (profileResponse != null &&
          profileResponse['display_name'] != displayName &&
          displayName.isNotEmpty) {
        await _supabase
            .from('users')
            .update({
              'display_name': displayName,
              'updated_at': DateTimeUtils.toIso8601StringKST(
                DateTimeUtils.nowKST(),
              ),
            })
            .eq('id', user.id);

        debugPrint('사용자 프로필 업데이트 완료: ${user.id}');
      } else {
        debugPrint('사용자 프로필 업데이트 불필요: ${user.id}');
      }
    } catch (e) {
      // RPC 함수가 'User profile not found' 에러를 던지면 프로필이 없는 것
      final isProfileNotFound =
          e.toString().contains('User profile not found') ||
          (e is PostgrestException &&
              (e.code == 'PGRST116' || e.message.contains('No rows returned')));

      if (isProfileNotFound) {
        // OAuth 로그인 시에도 프로필 생성 허용 (isSignUp=false이지만 프로필 생성 필요)
        // 이메일 로그인만 프로필 생성하지 않음
        final isOAuthUser =
            user.identities != null &&
            user.identities!.isNotEmpty &&
            user.identities!.any((identity) => identity.provider != 'email');

        if (!isSignUp && !isOAuthUser) {
          debugPrint(
            '⚠️ 이메일 로그인 시 프로필이 없습니다. 회원가입을 통해 프로필을 생성해주세요: ${user.id}',
          );
          return;
        }

        // 프로필이 없다고 판단되기 전에 실제로 존재하는지 직접 확인
        // 네트워크 에러 등으로 인한 오판을 방지하기 위함
        try {
          final directCheck = await _supabase
              .from('users')
              .select('id')
              .eq('id', user.id)
              .maybeSingle();

          if (directCheck != null) {
            // 프로필이 실제로 존재함 - 중복 생성 방지
            debugPrint('프로필이 실제로 존재함 (직접 확인됨): ${user.id}');
            return;
          }
        } catch (checkError) {
          // 직접 확인 중 에러가 발생해도 프로필 생성은 시도
          debugPrint('프로필 직접 확인 중 에러 발생: $checkError');
        }

        if (isSignUp) {
          debugPrint('회원가입 중: 사용자 프로필 생성 시도: ${user.id}');
        } else {
          debugPrint('OAuth 로그인: 사용자 프로필 생성 시도: ${user.id}');
        }
        // 회원가입 또는 OAuth 로그인 시 프로필 생성
        await _createUserProfile(
          user,
          displayName,
          userType,
          isSignUp: isSignUp, // 회원가입 여부에 따라 에러 처리 다름
        );
      } else {
        // 다른 에러(네트워크, 권한 등)는 로그만 출력
        // 프로필이 실제로 존재할 수 있으므로 생성 시도하지 않음
        debugPrint('프로필 조회 중 예상치 못한 에러 발생: ${user.id}, 에러: $e');
        if (isSignUp) {
          rethrow; // 회원가입 중일 때는 에러를 throw
        }
        // 로그인 중일 때는 에러를 숨김 (프로필이 없어도 로그인은 유지)
      }
    }
  }

  // 사용자 프로필 업데이트 (RPC 사용 - 보안 강화)
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      final user = await currentUser;
      if (user == null) throw Exception('로그인이 필요합니다.');

      // RPC 함수 호출로 안전한 프로필 업데이트
      final response = await _supabase.rpc(
        'update_user_profile_safe',
        params: {
          'p_user_id': user.uid,
          'p_display_name': updates['display_name'],
        },
      );

      debugPrint('프로필 업데이트 성공: ${user.uid}');
      debugPrint('업데이트된 프로필: $response');
    } catch (e) {
      debugPrint('프로필 업데이트 실패: $e');
      throw Exception('프로필 업데이트 실패: $e');
    }
  }

  // 사용자 프로필 가져오기 (RPC 사용 - 보안 강화)
  Future<app_user.User?> getUserProfile(String userId) async {
    try {
      // RPC 함수 호출로 안전한 프로필 조회
      final response = await _supabase.rpc(
        'get_user_profile_safe',
        params: {'p_user_id': userId},
      );

      return app_user.User.fromJson(response);
    } catch (e) {
      debugPrint('사용자 프로필 가져오기 실패: $e');
      return null;
    }
  }

  // 관리자 전용 사용자 권한 변경 (RPC 사용 - 보안 강화)
  Future<void> adminChangeUserRole(String userId, String newRole) async {
    try {
      await _supabase.rpc(
        'admin_change_user_role',
        params: {'p_target_user_id': userId, 'p_new_role': newRole},
      );

      debugPrint('사용자 권한 변경 성공: $userId -> $newRole');
    } catch (e) {
      debugPrint('사용자 권한 변경 실패: $e');
      throw Exception('사용자 권한 변경 실패: $e');
    }
  }

  // 사용자 존재 확인 (RPC 사용)
  Future<bool> checkUserExists(String userId) async {
    try {
      final response = await _supabase.rpc(
        'check_user_exists',
        params: {'p_user_id': userId},
      );

      return response as bool;
    } catch (e) {
      debugPrint('사용자 존재 확인 실패: $e');
      return false;
    }
  }
}
