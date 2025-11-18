import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import '../models/user.dart' as app_user;
import '../config/supabase_config.dart';
import '../utils/error_handler.dart';
import 'user_service.dart';
import '../utils/date_time_utils.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final UserService _userService = UserService();
  // GoogleSignIn 인스턴스 생성 방식 변경 (v7 API)
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

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

        // 프로필이 없는 경우 자동 생성 시도 (OAuth 로그인 시)
        final isProfileNotFound =
            e.toString().contains('User profile not found') ||
            (e is PostgrestException &&
                (e.code == 'PGRST116' ||
                    e.message.contains('No rows returned')));

        if (isProfileNotFound) {
          debugPrint('currentUser: 프로필이 없어서 자동 생성 시도: ${user.id}');

          // OAuth 사용자인지 확인 (identities 배열에서 확인)
          final isOAuthUser =
              user.identities != null &&
              user.identities!.isNotEmpty &&
              user.identities!.any((identity) => identity.provider != 'email');

          if (isOAuthUser) {
            // OAuth 사용자의 이름 가져오기
            String displayName = '';
            if (user.userMetadata != null) {
              displayName =
                  user.userMetadata!['full_name'] ??
                  user.userMetadata!['name'] ??
                  user.userMetadata!['display_name'] ??
                  '';
            }

            // 이름이 없으면 이메일의 @ 앞부분 사용
            if (displayName.isEmpty && user.email != null) {
              displayName = user.email!.split('@')[0];
            }

            // 이름이 여전히 없으면 기본값 사용
            if (displayName.isEmpty) {
              displayName = '사용자';
            }

            // OAuth 로그인 시 프로필 자동 생성
            try {
              await _ensureUserProfile(
                user,
                displayName,
                app_user.UserType.user,
                isSignUp: false,
              );

              // 프로필 생성 후 다시 조회
              final profileResponse = await _supabase.rpc(
                'get_user_profile_safe',
                params: {'p_user_id': user.id},
              );

              final userProfile = app_user.User.fromDatabaseProfile(
                profileResponse,
                user,
              );
              final stats = await _userService.getUserStats(user.id);

              return userProfile.copyWith(
                level: stats['level'],
                reviewCount: stats['reviewCount'],
              );
            } catch (createError) {
              debugPrint('currentUser: 프로필 자동 생성 실패: $createError');
              return null;
            }
          } else {
            // 이메일 로그인은 프로필 생성하지 않음
            debugPrint('사용자 프로필 조회 실패: $e');
            debugPrint('프로필이 없습니다. 회원가입을 통해 프로필을 생성해주세요.');
            return null;
          }
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
          // 프로필이 없는 경우 자동 생성 시도 (OAuth 로그인 시)
          final isProfileNotFound =
              e.toString().contains('User profile not found') ||
              (e is PostgrestException &&
                  (e.code == 'PGRST116' ||
                      e.message.contains('No rows returned')));

          if (isProfileNotFound) {
            debugPrint('OAuth 로그인: 프로필이 없어서 자동 생성 시도: ${user.id}');

            // OAuth 사용자의 이름 가져오기
            String displayName = '';
            if (user.userMetadata != null) {
              displayName =
                  user.userMetadata!['full_name'] ??
                  user.userMetadata!['name'] ??
                  user.userMetadata!['display_name'] ??
                  '';
            }

            // 이름이 없으면 이메일의 @ 앞부분 사용
            if (displayName.isEmpty && user.email != null) {
              displayName = user.email!.split('@')[0];
            }

            // 이름이 여전히 없으면 기본값 사용
            if (displayName.isEmpty) {
              displayName = '사용자';
            }

            // OAuth 로그인 시 프로필 자동 생성 (isSignUp=false로 설정)
            try {
              await _ensureUserProfile(
                user,
                displayName,
                app_user.UserType.user,
                isSignUp: false, // OAuth 로그인은 회원가입이 아니지만 프로필 생성 필요
              );

              // 프로필 생성 후 다시 조회
              final profileResponse = await _supabase.rpc(
                'get_user_profile_safe',
                params: {'p_user_id': user.id},
              );

              final userProfile = app_user.User.fromDatabaseProfile(
                profileResponse,
                user,
              );
              final stats = await _userService.getUserStats(user.id);

              return userProfile.copyWith(
                level: stats['level'],
                reviewCount: stats['reviewCount'],
              );
            } catch (createError) {
              debugPrint('OAuth 로그인: 프로필 자동 생성 실패: $createError');
              // 프로필 생성 실패해도 로그인은 유지
              return null;
            }
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
  Future<app_user.User?> signInWithGoogle() async {
    try {
      // 웹 플랫폼용 Google Client ID는 Supabase 대시보드에서 설정해야 합니다.
      // initialize 호출 추가 (v7 API)
      await _googleSignIn.initialize(
        clientId: kIsWeb
            ? 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com'
            : null,
      );

      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        authScreenLaunchMode: LaunchMode.inAppWebView,
        queryParams: {'access_type': 'offline', 'prompt': 'consent'},
      );

      // 로그인 성공 시 프로필 관리는 authStateChanges와 currentUser에서 처리
      // 중복 호출을 방지하기 위해 여기서는 _ensureUserProfile을 호출하지 않음
      return await currentUser;
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
  Future<app_user.User?> signInWithKakao() async {
    try {
      if (kIsWeb) {
        // 웹에서는 Supabase OAuth 사용
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.kakao,
          authScreenLaunchMode: LaunchMode.inAppWebView,
        );

        // 로그인 성공 시 프로필 관리는 authStateChanges와 currentUser에서 처리
        // 중복 호출을 방지하기 위해 여기서는 _ensureUserProfile을 호출하지 않음
        return await currentUser;
      } else {
        // 네이티브 앱에서는 카카오 SDK 사용
        final kakao.OAuthToken token = await kakao.UserApi.instance
            .loginWithKakaoTalk();

        // Supabase에 카카오 사용자 정보로 로그인
        final response = await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.kakao,
          idToken: token.idToken!, // idToken 사용
          accessToken: token.accessToken,
        );

        // 로그인 성공 시 프로필 관리는 authStateChanges와 currentUser에서 처리
        // 중복 호출을 방지하기 위해 여기서는 _ensureUserProfile을 호출하지 않음
        if (response.user != null) {
          return await currentUser;
        }
        return null;
      }
    } catch (e) {
      throw Exception('Kakao 로그인 실패: $e');
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
