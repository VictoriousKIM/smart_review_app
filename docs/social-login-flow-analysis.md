# 소셜 로그인 플로우 상세 분석 문서

**작성일**: 2025년 12월 2일  
**목적**: 소셜 로그인 버튼 클릭 시 회원가입과 로그인이 어떻게 동작하는지 상세 분석

---

## 📋 목차

1. [전체 플로우 개요](#전체-플로우-개요)
2. [코드 구조](#코드-구조)
3. [상세 플로우 분석](#상세-플로우-분석)
4. [회원가입 vs 로그인 구분](#회원가입-vs-로그인-구분)
5. [프로필 자동 생성 로직](#프로필-자동-생성-로직)
6. [플랫폼별 차이점](#플랫폼별-차이점)
7. [에러 처리](#에러-처리)
8. [주요 함수 설명](#주요-함수-설명)

---

## 전체 플로우 개요

### 시퀀스 다이어그램

```
사용자 → LoginScreen → AuthProvider → AuthService → Supabase OAuth → 외부 브라우저
                                                                          ↓
                                                                    사용자 인증
                                                                          ↓
앱 ← 딥링크 ← Supabase ← OAuth Provider ← 사용자 승인
  ↓
authStateChanges 트리거
  ↓
프로필 확인/생성
  ↓
로그인 완료
```

### 단계별 요약

1. **버튼 클릭**: 사용자가 "Google로 로그인" 또는 "Kakao로 로그인" 버튼 클릭
2. **OAuth 시작**: Supabase OAuth 인증 시작
3. **외부 브라우저 이동**: 사용자가 외부 브라우저/앱으로 이동하여 인증
4. **인증 완료**: OAuth 제공자가 인증 완료
5. **딥링크 복귀**: 모바일에서는 딥링크로 앱으로 복귀
6. **세션 생성**: Supabase가 세션 생성
7. **상태 변경 감지**: `authStateChanges` 스트림이 변경 감지
8. **프로필 확인**: 사용자 프로필 확인
9. **프로필 자동 생성**: 프로필이 없으면 자동 생성 (OAuth 사용자만)
10. **로그인 완료**: UI 업데이트 및 홈 화면으로 이동

---

## 코드 구조

### 주요 파일 및 클래스

```
lib/
├── screens/
│   └── auth/
│       └── login_screen.dart          # 로그인 화면 UI
├── providers/
│   └── auth_provider.dart             # 인증 상태 관리 (Riverpod)
├── services/
│   └── auth_service.dart              # 인증 로직 (Supabase 통신)
├── config/
│   ├── app_router.dart                # 라우팅 및 인증 가드
│   └── supabase_config.dart           # Supabase 초기화
└── main.dart                          # 앱 진입점 및 딥링크 처리
```

### 클래스 관계도

```
LoginScreen (UI)
    ↓
AuthProvider (State Management)
    ↓
AuthService (Business Logic)
    ↓
SupabaseClient (Authentication)
```

---

## 상세 플로우 분석

### 1단계: 버튼 클릭 (LoginScreen)

**파일**: `lib/screens/auth/login_screen.dart`

```dart
// Google 로그인 버튼 클릭
CustomButton(
  text: 'Google로 로그인',
  onPressed: _signInWithGoogle,
  isLoading: _isGoogleLoading,
)

// 버튼 클릭 핸들러
Future<void> _signInWithGoogle() async {
  await _handleSocialSignIn(
    () => ref.read(authProvider.notifier).signInWithGoogle(),
    true, // isGoogle = true
  );
}
```

**동작**:
- 로딩 상태 설정 (`_isGoogleLoading = true`)
- `AuthProvider`의 `signInWithGoogle()` 호출
- 에러 발생 시 스낵바 표시

---

### 2단계: AuthProvider 처리

**파일**: `lib/providers/auth_provider.dart`

```dart
Future<void> signInWithGoogle() async {
  state = const AsyncValue.loading();
  try {
    await _authService.signInWithGoogle();
    // 성공 시 상태는 authStateChanges에서 자동으로 업데이트됨
  } catch (e, stackTrace) {
    state = AsyncValue.error(e, stackTrace);
  }
}
```

**동작**:
- 상태를 `loading`으로 설정
- `AuthService.signInWithGoogle()` 호출
- 에러 발생 시 상태를 `error`로 설정
- 성공 시 `authStateChanges` 스트림이 자동으로 상태 업데이트

---

### 3단계: AuthService - OAuth 시작

**파일**: `lib/services/auth_service.dart`

#### 3-1. Google 로그인

```dart
Future<app_user.User?> signInWithGoogle() async {
  try {
    // 웹 플랫폼용 Google Client ID 초기화
    await _googleSignIn.initialize(
      clientId: kIsWeb
          ? 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com'
          : null,
    );

    // 모바일 앱에서는 커스텀 URL 스킴으로 리다이렉트
    final redirectTo = kIsWeb
        ? null // 웹에서는 기본값 사용
        : 'com.smart-grow.smart-review://login-callback';

    // Supabase OAuth 시작
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.inAppWebView      // 웹: 인앱 웹뷰
          : LaunchMode.externalApplication, // 모바일: 외부 브라우저
      redirectTo: redirectTo,
      queryParams: {'access_type': 'offline', 'prompt': 'consent'},
    );

    // 로그인 성공 시 프로필 관리는 authStateChanges와 currentUser에서 처리
    return await currentUser;
  } catch (e) {
    throw Exception('Google 로그인 실패: $e');
  }
}
```

#### 3-2. Kakao 로그인

```dart
Future<app_user.User?> signInWithKakao() async {
  try {
    if (kIsWeb) {
      // 웹에서는 Supabase OAuth 사용
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.kakao,
        authScreenLaunchMode: LaunchMode.inAppWebView,
      );
      return await currentUser;
    } else {
      // 모바일에서는 Supabase OAuth 사용
      final redirectTo = 'com.smart-grow.smart-review://login-callback';
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.kakao,
        authScreenLaunchMode: LaunchMode.externalApplication,
        redirectTo: redirectTo,
      );
      return await currentUser;
    }
  } catch (e) {
    throw Exception('Kakao 로그인 실패: $e');
  }
}
```

**동작**:
- **웹**: 인앱 웹뷰에서 OAuth 인증 진행
- **모바일**: 외부 브라우저로 이동하여 OAuth 인증 진행
- `redirectTo` 파라미터로 딥링크 URL 지정 (모바일)
- OAuth 인증 완료 후 Supabase가 세션 생성

---

### 4단계: 외부 브라우저/앱 이동

**플랫폼별 동작**:

#### 웹 (kIsWeb = true)
- 인앱 웹뷰에서 Google/Kakao 로그인 페이지 표시
- 사용자가 로그인 완료하면 자동으로 콜백 처리
- 세션이 즉시 생성됨

#### 모바일 (kIsWeb = false)
- 외부 브라우저로 이동
- 사용자가 Google/Kakao 로그인 완료
- `com.smart-grow.smart-review://login-callback?code=xxx` 딥링크로 앱 복귀

---

### 5단계: 딥링크 처리 (모바일만)

**파일**: `lib/main.dart`

```dart
void _processDeepLink(Uri uri) async {
  debugPrint('🔗 딥링크 수신: $uri');

  // OAuth 콜백 딥링크 처리
  if (uri.scheme == 'com.smart-grow.smart-review' &&
      uri.host == 'login-callback') {
    final code = uri.queryParameters['code'];
    if (code != null) {
      debugPrint('✅ OAuth 코드 수신: $code');
      try {
        final supabase = SupabaseConfig.client;
        // OAuth 코드를 세션으로 교환
        final response = await supabase.auth.exchangeCodeForSession(code);
        if (response.session != null) {
          debugPrint('✅ 세션 복원 성공');
        }
      } catch (e) {
        debugPrint('❌ 세션 복원 오류: $e');
      }
    }
  }
}
```

**동작**:
- 딥링크로 앱 복귀 시 `code` 파라미터 추출
- `exchangeCodeForSession()`으로 OAuth 코드를 세션으로 교환
- 세션 생성 완료

---

### 6단계: authStateChanges 트리거

**파일**: `lib/services/auth_service.dart`

```dart
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
        // ... (자세한 내용은 아래 프로필 자동 생성 섹션 참조)
      }
    }
    return null;
  });
}
```

**동작**:
- Supabase 세션이 생성되면 `onAuthStateChange` 이벤트 발생
- `authStateChanges` 스트림이 새로운 사용자 정보를 emit
- 프로필 조회 시도
- 프로필이 없으면 자동 생성 로직 실행 (OAuth 사용자만)

---

### 7단계: 프로필 확인 및 자동 생성

**파일**: `lib/services/auth_service.dart`

#### 7-1. 프로필 조회

```dart
// RPC 함수 호출로 안전한 프로필 조회
final profileResponse = await _supabase.rpc(
  'get_user_profile_safe',
  params: {'p_user_id': user.id},
);
```

**RPC 함수**: `get_user_profile_safe`
- SECURITY DEFINER로 RLS 우회
- `public.users` 테이블에서 프로필 조회
- 프로필이 없으면 에러 반환

#### 7-2. 프로필 없음 감지

```dart
final isProfileNotFound =
    e.toString().contains('User profile not found') ||
    (e is PostgrestException &&
        (e.code == 'PGRST116' ||
            e.message.contains('No rows returned')));
```

**에러 코드**:
- `PGRST116`: PostgREST "No rows returned" 에러
- `User profile not found`: 커스텀 에러 메시지

#### 7-3. OAuth 사용자 확인

```dart
// OAuth 사용자인지 확인 (identities 배열에서 확인)
final isOAuthUser =
    user.identities != null &&
    user.identities!.isNotEmpty &&
    user.identities!.any((identity) => identity.provider != 'email');
```

**동작**:
- `user.identities` 배열에서 `provider`가 `'email'`이 아닌 항목 확인
- Google, Kakao 등 OAuth 제공자는 `provider`가 `'google'`, `'kakao'` 등

#### 7-4. Display Name 추출

```dart
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
```

**우선순위**:
1. `userMetadata['full_name']`
2. `userMetadata['name']`
3. `userMetadata['display_name']`
4. 이메일의 `@` 앞부분
5. 기본값: `'사용자'`

#### 7-5. 프로필 자동 생성

```dart
// OAuth 로그인 시 프로필 자동 생성 (isSignUp=false로 설정)
await _ensureUserProfile(
  user,
  displayName,
  app_user.UserType.user,
  isSignUp: false, // OAuth 로그인은 회원가입이 아니지만 프로필 생성 필요
);
```

**동작**:
- `_ensureUserProfile()` 호출
- `isSignUp: false`로 설정 (회원가입이 아닌 로그인)
- 프로필 생성 실패해도 에러를 throw하지 않음 (이미 로그인된 사용자이므로)

---

### 8단계: 프로필 생성 로직

**파일**: `lib/services/auth_service.dart`

#### 8-1. _ensureUserProfile()

```dart
Future<void> _ensureUserProfile(
  User user,
  String displayName,
  app_user.UserType userType, {
  bool isSignUp = false,
}) async {
  try {
    // RPC 함수로 안전하게 프로필 조회
    final profileResponse = await _supabase.rpc(
      'get_user_profile_safe',
      params: {'p_user_id': user.id},
    );

    // 프로필이 존재하면 업데이트 (필요 시)
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
    }
  } catch (e) {
    // 프로필이 없는 경우
    final isProfileNotFound = /* ... */;
    
    if (isProfileNotFound) {
      // OAuth 사용자인지 확인
      final isOAuthUser = /* ... */;
      
      // 이메일 로그인은 프로필 생성하지 않음
      if (!isSignUp && !isOAuthUser) {
        return;
      }
      
      // 프로필 생성
      await _createUserProfile(
        user,
        displayName,
        userType,
        isSignUp: isSignUp,
      );
    }
  }
}
```

**동작**:
1. 프로필 조회 시도
2. 프로필이 있으면 `display_name` 업데이트 (변경된 경우만)
3. 프로필이 없으면:
   - 이메일 로그인: 프로필 생성하지 않음 (회원가입 필요)
   - OAuth 로그인: 프로필 자동 생성
   - 회원가입: 프로필 생성

#### 8-2. _createUserProfile()

```dart
Future<void> _createUserProfile(
  User user,
  String displayName,
  app_user.UserType userType, {
  bool isSignUp = false,
}) async {
  try {
    // RPC 함수 호출로 안전한 사용자 프로필 생성
    final response = await _supabase.rpc(
      'create_user_profile_safe',
      params: {
        'p_user_id': user.id,
        'p_display_name': displayName,
        'p_user_type': actualUserType.name,
      },
    );
  } catch (e) {
    // 회원가입 중일 때만 에러를 throw
    if (isSignUp) {
      rethrow;
    }
    // 로그인 중일 때는 에러를 숨김 (이미 로그인된 사용자이므로)
  }
}
```

**RPC 함수**: `create_user_profile_safe`
- SECURITY DEFINER로 RLS 우회
- `public.users` 테이블에 프로필 생성
- `public.wallets` 테이블에 포인트 지갑 생성 (트리거로 자동 생성)

**에러 처리**:
- `isSignUp: true`: 프로필 생성 실패 시 에러 throw (회원가입 실패)
- `isSignUp: false`: 프로필 생성 실패해도 에러 숨김 (이미 로그인된 사용자)

---

### 9단계: 로그인 완료 및 UI 업데이트

#### 9-1. AuthProvider 상태 업데이트

```dart
// authStateChanges 스트림이 새로운 사용자 정보를 emit
Stream<app_user.User?> get authStateChanges {
  return _supabase.auth.onAuthStateChange.asyncMap((authState) async {
    // ... 프로필 조회 및 생성 로직
    return userProfile; // 또는 null
  });
}
```

**동작**:
- `authStateChanges` 스트림이 새로운 `User` 객체를 emit
- `AuthProvider`의 `state`가 자동으로 업데이트됨
- UI가 자동으로 리빌드됨

#### 9-2. LoginScreen 로딩 상태 해제

```dart
ref.listen<AsyncValue>(authProvider, (previous, next) {
  if (previous?.value == null && next.value != null) {
    // 로그인 성공: 로딩 상태 해제
    if (mounted) {
      setState(() {
        _isGoogleLoading = false;
        _isKakaoLoading = false;
      });
    }
  }
});
```

**동작**:
- `authProvider`의 상태가 `null`에서 `User`로 변경되면 로그인 성공
- 로딩 상태 해제

#### 9-3. 라우터 리다이렉트

**파일**: `lib/config/app_router.dart`

```dart
redirect: (context, state) async {
  final user = await authService.currentUser;
  final isLoggedIn = user != null;

  // 로그인 상태
  if (isLoggedIn) {
    // 로그인 페이지나 루트 접근 시 홈으로
    if (isLoggingIn || isRoot) return '/home';
  }

  return null;
}
```

**동작**:
- 로그인 완료 시 `/login` 또는 `/`에서 `/home`으로 리다이렉트
- `GoRouterRefreshStream`이 `authStateChanges`를 감지하여 자동 리다이렉트

---

## 회원가입 vs 로그인 구분

### Supabase의 동작 방식

**Supabase는 회원가입과 로그인을 자동으로 구분합니다:**

1. **처음 로그인하는 사용자 (회원가입)**:
   - `auth.users` 테이블에 새 레코드 생성
   - `user.created_at`이 현재 시간
   - `user.identities`에 OAuth 제공자 정보 추가

2. **이미 가입한 사용자 (로그인)**:
   - 기존 `auth.users` 레코드 사용
   - 세션만 갱신

### 애플리케이션 레벨 구분

**프로필 생성 여부로 구분:**

```dart
// OAuth 로그인 시 프로필 자동 생성
await _ensureUserProfile(
  user,
  displayName,
  app_user.UserType.user,
  isSignUp: false, // OAuth 로그인은 항상 false
);
```

**동작**:
- **프로필이 없는 경우**: 자동 생성 (첫 로그인 = 회원가입)
- **프로필이 있는 경우**: 기존 프로필 사용 (로그인)

### 이메일 로그인과의 차이

**이메일 로그인**:
- 프로필이 없으면 에러 발생
- 회원가입을 통해 프로필을 먼저 생성해야 함

**OAuth 로그인**:
- 프로필이 없으면 자동 생성
- 사용자 개입 없이 자동으로 회원가입 처리

---

## 프로필 자동 생성 로직

### 생성 조건

1. **OAuth 사용자**: `provider != 'email'`
2. **프로필 없음**: `get_user_profile_safe` RPC 함수가 에러 반환
3. **에러 코드**: `PGRST116` 또는 `User profile not found`

### 생성 과정

```dart
// 1. 프로필 조회 시도
try {
  final profileResponse = await _supabase.rpc(
    'get_user_profile_safe',
    params: {'p_user_id': user.id},
  );
} catch (e) {
  // 2. 프로필 없음 감지
  if (isProfileNotFound) {
    // 3. OAuth 사용자 확인
    if (isOAuthUser) {
      // 4. Display Name 추출
      String displayName = /* ... */;
      
      // 5. 프로필 생성
      await _createUserProfile(
        user,
        displayName,
        app_user.UserType.user,
        isSignUp: false,
      );
    }
  }
}
```

### 생성되는 데이터

**RPC 함수**: `create_user_profile_safe`

```sql
-- public.users 테이블에 프로필 생성
INSERT INTO public.users (
  id,
  display_name,
  user_type,
  created_at,
  updated_at
) VALUES (
  p_user_id,
  p_display_name,
  p_user_type,
  NOW(),
  NOW()
);

-- 트리거로 포인트 지갑 자동 생성
-- create_user_wallet_on_signup 트리거가 실행됨
```

**생성되는 레코드**:
- `public.users`: 사용자 프로필
- `public.wallets`: 포인트 지갑 (트리거로 자동 생성)

---

## 플랫폼별 차이점

### 웹 (kIsWeb = true)

**특징**:
- 인앱 웹뷰에서 OAuth 인증 진행
- 딥링크 불필요
- 세션이 즉시 생성됨

**코드**:
```dart
authScreenLaunchMode: LaunchMode.inAppWebView
redirectTo: null // 기본값 사용
```

### 모바일 (kIsWeb = false)

**특징**:
- 외부 브라우저로 이동
- 딥링크로 앱 복귀
- `exchangeCodeForSession()`으로 세션 생성

**코드**:
```dart
authScreenLaunchMode: LaunchMode.externalApplication
redirectTo: 'com.smart-grow.smart-review://login-callback'
```

**딥링크 처리**:
```dart
// main.dart에서 딥링크 처리
void _processDeepLink(Uri uri) async {
  if (uri.scheme == 'com.smart-grow.smart-review' &&
      uri.host == 'login-callback') {
    final code = uri.queryParameters['code'];
    await supabase.auth.exchangeCodeForSession(code);
  }
}
```

---

## 에러 처리

### 1. OAuth 인증 실패

**에러 발생 위치**: `signInWithOAuth()`

**처리**:
```dart
try {
  await _supabase.auth.signInWithOAuth(/* ... */);
} catch (e) {
  throw Exception('Google 로그인 실패: $e');
}
```

**UI 표시**:
```dart
catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('로그인 실패: $e'))
  );
}
```

### 2. 프로필 조회 실패

**에러 발생 위치**: `get_user_profile_safe` RPC 함수

**처리**:
```dart
try {
  final profileResponse = await _supabase.rpc(
    'get_user_profile_safe',
    params: {'p_user_id': user.id},
  );
} catch (e) {
  // 프로필 없음 감지
  if (isProfileNotFound) {
    // 자동 생성 시도
  } else {
    // 다른 에러 (네트워크, 권한 등)
    debugPrint('사용자 프로필 조회 실패: $e');
    return null;
  }
}
```

### 3. 프로필 생성 실패

**에러 발생 위치**: `create_user_profile_safe` RPC 함수

**처리**:
```dart
try {
  await _createUserProfile(/* ... */);
} catch (e) {
  if (isSignUp) {
    // 회원가입 중: 에러 throw
    rethrow;
  } else {
    // 로그인 중: 에러 숨김 (이미 로그인된 사용자)
    debugPrint('프로필 자동 생성 실패: $e');
  }
}
```

### 4. 세션 만료/손상

**에러 발생 위치**: `currentUser` getter

**처리**:
```dart
if (session.isExpired) {
  try {
    final refreshedSession = await _supabase.auth.refreshSession();
    if (refreshedSession.session == null) {
      await _supabase.auth.signOut();
      return null;
    }
  } catch (refreshError) {
    // 손상된 세션 감지
    if (ErrorHandler.isMissingDestinationScopesError(refreshError)) {
      await _supabase.auth.signOut();
      return null;
    }
  }
}
```

---

## 주요 함수 설명

### AuthService

#### `signInWithGoogle()`
- Google OAuth 인증 시작
- 웹/모바일 플랫폼별 처리
- 세션 생성 후 프로필 확인

#### `signInWithKakao()`
- Kakao OAuth 인증 시작
- 웹/모바일 플랫폼별 처리
- 세션 생성 후 프로필 확인

#### `currentUser`
- 현재 로그인한 사용자 정보 반환
- 세션 만료 확인 및 갱신
- 프로필 자동 생성 (OAuth 사용자)

#### `authStateChanges`
- 인증 상태 변경 스트림
- 프로필 조회 및 자동 생성
- UI 자동 업데이트

#### `_ensureUserProfile()`
- 프로필 존재 확인
- 프로필 없으면 자동 생성
- OAuth 사용자만 자동 생성

#### `_createUserProfile()`
- RPC 함수로 프로필 생성
- 포인트 지갑 자동 생성 (트리거)
- 에러 처리 (회원가입/로그인 구분)

### AuthProvider

#### `signInWithGoogle()`
- 상태를 `loading`으로 설정
- `AuthService.signInWithGoogle()` 호출
- 에러 처리

#### `signInWithKakao()`
- 상태를 `loading`으로 설정
- `AuthService.signInWithKakao()` 호출
- 에러 처리

### LoginScreen

#### `_handleSocialSignIn()`
- 로딩 상태 관리
- 에러 처리 및 스낵바 표시
- 웹/모바일 플랫폼별 처리

#### `_signInWithGoogle()`
- Google 로그인 버튼 핸들러
- `AuthProvider.signInWithGoogle()` 호출

#### `_signInWithKakao()`
- Kakao 로그인 버튼 핸들러
- `AuthProvider.signInWithKakao()` 호출

---

## 데이터베이스 스키마

### auth.users (Supabase 관리)

```sql
-- Supabase가 자동으로 관리하는 테이블
-- OAuth 인증 완료 시 자동으로 레코드 생성
```

**주요 필드**:
- `id`: UUID (사용자 ID)
- `email`: 이메일 주소
- `user_metadata`: OAuth 제공자에서 받은 메타데이터
- `identities`: OAuth 제공자 정보 배열
- `created_at`: 생성 시간

### public.users (애플리케이션 프로필)

```sql
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  display_name TEXT NOT NULL,
  user_type TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);
```

**생성 시점**:
- OAuth 로그인 시 자동 생성
- 이메일 회원가입 시 생성

### public.wallets (포인트 지갑)

```sql
CREATE TABLE public.wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(id),
  company_id UUID REFERENCES public.companies(id),
  current_points INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);
```

**생성 시점**:
- `create_user_wallet_on_signup` 트리거로 자동 생성
- `public.users` 레코드 생성 시 트리거 실행

---

## RPC 함수

### get_user_profile_safe

**목적**: 안전한 프로필 조회 (RLS 우회)

```sql
CREATE OR REPLACE FUNCTION get_user_profile_safe(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 프로필 조회
  -- 프로필이 없으면 에러 반환
END;
$$;
```

### create_user_profile_safe

**목적**: 안전한 프로필 생성 (RLS 우회)

```sql
CREATE OR REPLACE FUNCTION create_user_profile_safe(
  p_user_id UUID,
  p_display_name TEXT,
  p_user_type TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 프로필 생성
  -- 포인트 지갑은 트리거로 자동 생성
END;
$$;
```

---

## 요약

### 소셜 로그인 플로우 요약

1. **버튼 클릭** → `LoginScreen._signInWithGoogle/Kakao()`
2. **OAuth 시작** → `AuthService.signInWithGoogle/Kakao()`
3. **외부 브라우저 이동** → 사용자 인증
4. **딥링크 복귀** (모바일) → `main.dart._processDeepLink()`
5. **세션 생성** → Supabase가 세션 생성
6. **상태 변경 감지** → `authStateChanges` 스트림
7. **프로필 확인** → `get_user_profile_safe` RPC 함수
8. **프로필 자동 생성** (없는 경우) → `create_user_profile_safe` RPC 함수
9. **로그인 완료** → UI 업데이트 및 홈 화면 이동

### 회원가입 vs 로그인

- **Supabase 레벨**: 자동 구분 (처음 로그인 = 회원가입)
- **애플리케이션 레벨**: 프로필 존재 여부로 구분
- **OAuth 로그인**: 프로필 없으면 자동 생성 (자동 회원가입)
- **이메일 로그인**: 프로필 없으면 에러 (회원가입 필요)

### 주요 특징

- **자동 회원가입**: OAuth 로그인 시 프로필 자동 생성
- **플랫폼별 처리**: 웹/모바일 플랫폼별 OAuth 처리
- **딥링크 지원**: 모바일에서 딥링크로 앱 복귀
- **에러 처리**: 회원가입/로그인 구분하여 에러 처리
- **보안**: RPC 함수로 RLS 우회하여 안전한 프로필 관리

---

## 참고 자료

- [Supabase OAuth 문서](https://supabase.com/docs/guides/auth/social-login)
- [Flutter Deep Links 문서](https://docs.flutter.dev/development/ui/navigation/deep-linking)
- [Riverpod 문서](https://riverpod.dev/)

