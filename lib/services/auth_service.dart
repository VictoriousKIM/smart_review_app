import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import '../models/user.dart' as app_user;
import '../config/supabase_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  // GoogleSignIn 인스턴스 생성 방식 변경 (v7 API)
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // 현재 사용자 가져오기 (데이터베이스에서 실제 프로필 정보 조회)
  Future<app_user.User?> get currentUser async {
    final session = _supabase.auth.currentSession;
    if (session?.user != null) {
      try {
        // 데이터베이스에서 사용자 프로필 조회
        final profileResponse = await _supabase
            .from('users')
            .select()
            .eq('id', session!.user.id)
            .single();

        // 데이터베이스 프로필 정보로 User 객체 생성
        return app_user.User.fromDatabaseProfile(profileResponse, session.user);
      } catch (e) {
        // 프로필이 없으면 Supabase User 정보만으로 생성
        debugPrint('사용자 프로필 조회 실패: $e');
        return app_user.User.fromSupabaseUser(session!.user);
      }
    }
    return null;
  }

  // 인증 상태 스트림
  Stream<app_user.User?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.asyncMap((authState) async {
      final user = authState.session?.user;
      if (user != null) {
        try {
          // 데이터베이스에서 사용자 프로필 조회
          final profileResponse = await _supabase
              .from('users')
              .select()
              .eq('id', user.id)
              .single();

          // 데이터베이스 프로필 정보로 User 객체 생성
          return app_user.User.fromDatabaseProfile(profileResponse, user);
        } catch (e) {
          // 프로필이 없으면 Supabase User 정보만으로 생성
          debugPrint('사용자 프로필 조회 실패: $e');
          return app_user.User.fromSupabaseUser(user);
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

      final user = await currentUser;
      if (user != null) {
        // 소셜 로그인인 경우 빈 display_name으로 프로필 생성 (SignupScreen으로 리디렉션)
        await _ensureUserProfile(
          _supabase.auth.currentUser!,
          '', // 빈 display_name으로 설정하여 SignupScreen으로 리디렉션
          user.userType,
        );
      }
      return user;
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

      if (response.user != null) {
        // 이메일 로그인인 경우 프로필 확인 및 생성
        await _ensureUserProfile(
          response.user!,
          response.user!.userMetadata?['display_name'] ?? '',
          app_user.UserType.user, // 기본값 설정
        );
        return app_user.User.fromSupabaseUser(response.user!);
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
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );

      if (response.user != null) {
        // 회원가입 후 프로필 생성
        await _ensureUserProfile(
          response.user!,
          displayName,
          app_user.UserType.user, // 기본값 설정
        );
        return app_user.User.fromSupabaseUser(response.user!);
      }
      return null;
    } catch (e) {
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

        final user = await currentUser;
        if (user != null) {
          // 소셜 로그인인 경우 빈 display_name으로 프로필 생성 (SignupScreen으로 리디렉션)
          await _ensureUserProfile(
            _supabase.auth.currentUser!,
            '', // 빈 display_name으로 설정하여 SignupScreen으로 리디렉션
            app_user.UserType.user, // 기본값 설정
          );
        }
        return user;
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

        if (response.user != null) {
          // 소셜 로그인인 경우 빈 display_name으로 프로필 생성 (SignupScreen으로 리디렉션)
          await _ensureUserProfile(
            response.user!,
            '', // 빈 display_name으로 설정하여 SignupScreen으로 리디렉션
            app_user.UserType.user, // 기본값 설정
          );
          return app_user.User.fromSupabaseUser(response.user!);
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

  // 사용자 프로필 생성
  Future<void> _createUserProfile(
    User user,
    String displayName,
    app_user.UserType userType,
  ) async {
    try {
      await _supabase.from('users').insert({
        'id': user.id,
        'email': user.email,
        'display_name': displayName,
        'user_type': userType.name,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'sns_connections': {},
      });
    } catch (e) {
      // 사용자 프로필 생성 실패 - 로그만 남기고 계속 진행
      debugPrint('사용자 프로필 생성 실패: $e');
    }
  }

  // 사용자 프로필 확인 및 생성
  Future<void> _ensureUserProfile(
    User user,
    String displayName,
    app_user.UserType userType,
  ) async {
    try {
      // 프로필이 존재하는지 확인
      await _supabase.from('users').select().eq('id', user.id).single();

      // 프로필이 존재하면 업데이트 (필요 시)
      await _supabase
          .from('users')
          .update({
            'display_name': displayName,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);
    } catch (e) {
      // 프로필이 없으면 생성
      // 소셜 로그인인 경우 displayName이 비어있으면 SignupScreen으로 리디렉션되도록 함
      await _createUserProfile(user, displayName, userType);
    }
  }

  // 사용자 프로필 업데이트
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      final user = await currentUser;
      if (user == null) throw Exception('로그인이 필요합니다.');

      await _supabase
          .from('users')
          .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', user.uid);
    } catch (e) {
      throw Exception('프로필 업데이트 실패: $e');
    }
  }

  // 사용자 프로필 가져오기
  Future<app_user.User?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return app_user.User.fromJson(response);
    } catch (e) {
      // 사용자 프로필 가져오기 실패 - 로그만 남기고 null 반환
      debugPrint('사용자 프로필 가져오기 실패: $e');
      return null;
    }
  }
}
