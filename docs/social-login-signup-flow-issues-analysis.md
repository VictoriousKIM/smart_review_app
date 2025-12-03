# 소셜 로그인 → Signup 플로우 문제점 분석

**작성일**: 2025년 12월 03일  
**목적**: 소셜 로그인 버튼 클릭 시 auth가 없을 때 signup 로직의 문제점을 상세히 분석하고 개선 방안 제시

---

## 📋 목차

1. [전체 플로우 개요](#전체-플로우-개요)
2. [현재 구현 분석](#현재-구현-분석)
3. [발견된 문제점](#발견된-문제점)
4. [문제점 상세 분석](#문제점-상세-분석)
5. [개선 방안](#개선-방안)
6. [권장 사항](#권장-사항)

---

## 전체 플로우 개요

### 현재 플로우 다이어그램

```
[1] 사용자 클릭: "Kakao로 로그인" / "Google로 로그인"
    ↓
[2] LoginScreen._signInWithKakao() / _signInWithGoogle()
    ↓
[3] AuthProvider.signInWithKakao() / signInWithGoogle()
    ↓
[4] AuthService.signInWithKakao() / signInWithGoogle()
    ↓
[5] Supabase OAuth 인증 시작 (signInWithOAuth)
    ↓
[6] 외부 브라우저/앱으로 이동 → 사용자 인증
    ↓
[7] OAuth 인증 완료 → Supabase로 콜백
    ↓
[8] Supabase가 auth.users에 사용자 생성 (자동)
    ↓
[9] 세션 생성 (임시 세션)
    ↓
[10] authStateChanges 스트림 트리거
    ↓
[11] AuthService.authStateChanges에서 프로필 확인
    ↓
[12] get_user_profile_safe RPC 호출
    ↓
[13] 프로필 없음 감지 → null 반환
    ↓
[14] app_router.dart redirect 실행
    ↓
[15] currentUser 호출 → 프로필 재확인 (중복 체크)
    ↓
[16] 프로필 없음 감지 → 임시 세션 확인
    ↓
[17] /signup?type=oauth&provider={provider}로 리다이렉트
    ↓
[18] SignupScreen 표시
```

---

## 현재 구현 분석

### 1. LoginScreen (lib/screens/auth/login_screen.dart)

**역할**: 소셜 로그인 버튼 UI 및 클릭 처리

```dart
// 소셜 로그인 버튼 클릭 시
Future<void> _signInWithKakao() async {
  await _handleSocialSignIn(
    () => ref.read(authProvider.notifier).signInWithKakao(),
    false,
  );
}
```

**특징**:
- 로딩 상태 관리
- authStateChanges를 통한 로그인 완료 감지
- 에러 처리 (SnackBar 표시)

**문제점**: 없음 (정상 동작)

---

### 2. AuthProvider (lib/providers/auth_provider.dart)

**역할**: AuthService 래핑 및 상태 관리

```dart
Future<void> signInWithKakao() async {
  state = const AsyncValue.loading();
  try {
    await _authService.signInWithKakao();
    // 성공 시 상태는 authStateChanges에서 자동으로 업데이트됨
  } catch (e, stackTrace) {
    state = AsyncValue.error(e, stackTrace);
  }
}
```

**특징**:
- authStateChanges 스트림을 통한 자동 상태 업데이트
- 에러 상태 관리

**문제점**: 없음 (정상 동작)

---

### 3. AuthService (lib/services/auth_service.dart)

**역할**: 실제 OAuth 인증 및 프로필 관리

#### 3.1 OAuth 로그인 메서드

```dart
Future<app_user.User?> signInWithKakao() async {
  try {
    if (kIsWeb) {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.kakao,
        authScreenLaunchMode: LaunchMode.inAppWebView,
      );
      return await currentUser; // ⚠️ 문제점 1: 즉시 currentUser 호출
    }
    // ...
  } catch (e) {
    throw Exception('Kakao 로그인 실패: $e');
  }
}
```

**문제점 1**: OAuth 인증이 완료되기 전에 `currentUser`를 호출
- 웹에서는 `signInWithOAuth`가 비동기로 완료되지만, 실제 세션 생성은 콜백 후에 발생
- 즉시 `currentUser`를 호출하면 세션이 아직 생성되지 않아 `null` 반환 가능

#### 3.2 currentUser Getter

```dart
Future<app_user.User?> get currentUser async {
  final session = _supabase.auth.currentSession;
  final user = session?.user;
  if (user != null) {
    try {
      // 세션 만료 확인 및 토큰 갱신
      if (session!.isExpired) {
        // ... 토큰 갱신 로직
      }

      // RPC 함수 호출로 안전한 프로필 조회
      final profileResponse = await _supabase.rpc(
        'get_user_profile_safe',
        params: {'p_user_id': user.id},
      );
      // ... 프로필 파싱 및 반환
    } catch (e) {
      // 프로필이 없는 경우 null 반환
      final isProfileNotFound = /* ... */;
      if (isProfileNotFound) {
        debugPrint('프로필이 없습니다. 회원가입이 필요합니다: ${user.id}');
        return null; // ⚠️ 문제점 2: 프로필 없을 때 null 반환
      }
      return null;
    }
  }
  return null;
}
```

**문제점 2**: 프로필이 없을 때 단순히 `null` 반환
- 세션은 존재하지만 프로필이 없는 상태를 구분하지 못함
- 네트워크 에러와 프로필 없음을 구분하지 못함

#### 3.3 authStateChanges Stream

```dart
Stream<app_user.User?> get authStateChanges {
  return _supabase.auth.onAuthStateChange.asyncMap((authState) async {
    final user = authState.session?.user;
    if (user != null) {
      try {
        final profileResponse = await _supabase.rpc(
          'get_user_profile_safe',
          params: {'p_user_id': user.id},
        );
        // ... 프로필 파싱 및 반환
      } catch (e) {
        // 프로필이 없는 경우 null 반환
        final isProfileNotFound = /* ... */;
        if (isProfileNotFound) {
          debugPrint('프로필이 없습니다. 회원가입이 필요합니다: ${user.id}');
          return null; // ⚠️ 문제점 3: 프로필 없을 때 null 반환
        }
        return null;
      }
    }
    return null;
  });
}
```

**문제점 3**: 프로필이 없을 때 `null` 반환
- 세션이 있는데 프로필이 없는 상태를 구분하지 못함
- 라우터에서 임시 세션을 다시 확인해야 함 (중복 체크)

---

### 4. AppRouter (lib/config/app_router.dart)

**역할**: 라우팅 및 리다이렉트 로직

#### 4.1 전역 Redirect 로직

```dart
redirect: (context, state) async {
  final matchedLocation = state.matchedLocation;
  final isLoggingIn = matchedLocation == '/login';
  final isRoot = matchedLocation == '/';
  final isMyPage = matchedLocation.startsWith('/mypage');

  // 1. 마이페이지 경로는 전역 redirect에서 특별 처리
  if (isMyPage) {
    final user = await authService.currentUser;
    if (user == null) {
      return '/login';
    }
    return null;
  }

  // 2. 세션 확인 (비동기)
  final user = await authService.currentUser; // ⚠️ 문제점 4: 중복 체크
  final isLoggedIn = user != null;

  // 2-1. 프로필이 없는 임시 세션 확인 (OAuth 로그인 후)
  if (!isLoggedIn) {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null && session.user != null) {
      // 프로필이 없는 경우 signup으로 리다이렉트
      try {
        await SupabaseConfig.client.rpc(
          'get_user_profile_safe',
          params: {'p_user_id': session.user!.id},
        );
      } catch (e) {
        // 프로필 없음 → signup으로 리다이렉트
        final isProfileNotFound = /* ... */;
        if (isProfileNotFound) {
          // OAuth 제공자 확인
          final provider =
              session.user!.appMetadata['provider'] ?? // ⚠️ 문제점 5: provider 추출 불안정
              session.user!.identities?.firstOrNull?.provider ??
              'unknown';
          return '/signup?type=oauth&provider=$provider';
        }
      }
    }
  }

  // 3. 비로그인 상태
  if (!isLoggedIn) {
    final isSigningUp = matchedLocation == '/signup';
    if (isLoggingIn || isSigningUp) return null;
    return '/login';
  }

  // 4. 로그인 상태
  if (isLoggedIn) {
    if (isLoggingIn || isRoot) return '/home';
  }

  return null;
}
```

**문제점 4**: 중복 프로필 체크
- `currentUser`에서 이미 프로필 체크를 했는데, redirect에서 다시 체크
- 성능 저하 및 불필요한 RPC 호출

**문제점 5**: Provider 정보 추출 불안정
- `appMetadata['provider']`는 항상 존재하지 않음
- `identities`에서 추출하는 로직이 복잡하고 불안정
- `'unknown'`으로 fallback하는 경우가 많음

**문제점 6**: Signup 화면에서도 redirect 실행
- `/signup` 경로에서도 redirect가 실행되어 무한 루프 가능성
- 현재는 `isSigningUp` 체크로 방지하지만, 경로가 변경되면 문제 발생 가능

---

## 발견된 문제점

### 🔴 심각한 문제

1. **중복 프로필 체크**
   - `currentUser`와 `redirect`에서 모두 프로필 체크
   - 불필요한 RPC 호출로 인한 성능 저하

2. **타이밍 문제**
   - OAuth 콜백 후 세션 생성과 프로필 체크 사이의 타이밍 이슈
   - `signInWithOAuth` 직후 `currentUser` 호출 시 세션이 아직 생성되지 않을 수 있음

3. **Provider 정보 추출 불안정**
   - `appMetadata['provider']`가 항상 존재하지 않음
   - `identities`에서 추출하는 로직이 복잡하고 불안정

### 🟡 중간 문제

4. **에러 처리 부족**
   - 네트워크 에러와 프로필 없음을 구분하지 못함
   - 프로필 체크 실패 시 재시도 로직 없음

5. **세션 상태 불일치**
   - 세션은 있지만 프로필이 없는 상태를 명확히 구분하지 못함
   - 임시 세션 상태를 별도로 관리하지 않음

6. **Signup 화면 접근 제어**
   - Signup 화면에서도 redirect가 실행되어 무한 루프 가능성
   - 현재는 `isSigningUp` 체크로 방지하지만, 경로 변경 시 문제 발생 가능

### 🟢 경미한 문제

7. **로딩 상태 관리**
   - OAuth 인증 중 로딩 상태가 명확하지 않음
   - 사용자가 인증 완료를 기다리는 동안 피드백 부족

8. **에러 메시지**
   - 프로필 없음 에러 메시지가 사용자에게 표시되지 않음
   - 디버그 로그만 출력

---

## 문제점 상세 분석

### 문제 1: 중복 프로필 체크

**현재 동작**:
1. `authStateChanges`에서 프로필 체크 → `null` 반환
2. `redirect`에서 `currentUser` 호출 → 프로필 재체크 → `null` 반환
3. `redirect`에서 임시 세션 확인 → 프로필 재재체크 → signup으로 리다이렉트

**문제점**:
- 같은 프로필을 3번 체크 (불필요한 RPC 호출)
- 성능 저하 및 서버 부하 증가

**영향도**: 🔴 높음

---

### 문제 2: 타이밍 문제

**현재 동작**:
```dart
await _supabase.auth.signInWithOAuth(...);
return await currentUser; // ⚠️ 세션이 아직 생성되지 않았을 수 있음
```

**문제점**:
- 웹에서 `signInWithOAuth`는 비동기로 완료되지만, 실제 세션 생성은 콜백 후에 발생
- 즉시 `currentUser`를 호출하면 세션이 아직 생성되지 않아 `null` 반환
- `authStateChanges`에서 나중에 처리되지만, 초기 호출은 실패

**영향도**: 🔴 높음

**재현 시나리오**:
1. 사용자가 "Kakao로 로그인" 버튼 클릭
2. `signInWithOAuth` 호출 → 즉시 완료 (웹)
3. `currentUser` 호출 → 세션 없음 → `null` 반환
4. 나중에 OAuth 콜백 → 세션 생성 → `authStateChanges` 트리거

---

### 문제 3: Provider 정보 추출 불안정

**현재 동작**:
```dart
final provider =
    session.user!.appMetadata['provider'] ??  // ⚠️ 항상 존재하지 않음
    session.user!.identities?.firstOrNull?.provider ??
    'unknown';
```

**문제점**:
- `appMetadata['provider']`는 Supabase가 자동으로 설정하지 않음
- `identities`에서 추출하는 로직이 복잡하고 불안정
- `'unknown'`으로 fallback하는 경우가 많음

**영향도**: 🔴 높음

**실제 동작 확인 필요**:
- OAuth 로그인 후 `appMetadata`와 `identities`의 실제 구조 확인
- Provider 정보가 어디에 저장되는지 확인

---

### 문제 4: 에러 처리 부족

**현재 동작**:
```dart
catch (e) {
  final isProfileNotFound = /* ... */;
  if (isProfileNotFound) {
    return null;
  } else {
    // 다른 에러인 경우
    debugPrint('사용자 프로필 조회 실패: $e');
    return null; // ⚠️ 네트워크 에러도 null 반환
  }
}
```

**문제점**:
- 네트워크 에러와 프로필 없음을 구분하지 못함
- 프로필 체크 실패 시 재시도 로직 없음
- 사용자에게 에러 메시지 표시 안 함

**영향도**: 🟡 중간

---

### 문제 5: 세션 상태 불일치

**현재 동작**:
- 세션은 있지만 프로필이 없는 상태를 명확히 구분하지 못함
- 임시 세션 상태를 별도로 관리하지 않음

**문제점**:
- 세션과 프로필의 불일치 상태를 명확히 표현하지 못함
- 임시 세션 상태를 별도로 관리하지 않아 혼란 발생

**영향도**: 🟡 중간

---

### 문제 6: Signup 화면 접근 제어

**현재 동작**:
```dart
if (!isLoggedIn) {
  final isSigningUp = matchedLocation == '/signup';
  if (isLoggingIn || isSigningUp) return null;
  return '/login';
}
```

**문제점**:
- Signup 화면에서도 redirect가 실행되어 무한 루프 가능성
- 현재는 `isSigningUp` 체크로 방지하지만, 경로 변경 시 문제 발생 가능

**영향도**: 🟡 중간

---

## 개선 방안

### 개선 1: 중복 프로필 체크 제거

**방안**: `currentUser`에서 프로필 없음 상태를 명확히 구분

```dart
// AuthService에 새로운 상태 추가
enum UserState {
  notLoggedIn,      // 세션 없음
  loggedIn,         // 세션 있고 프로필 있음
  tempSession,      // 세션 있지만 프로필 없음 (OAuth 회원가입 필요)
}

// currentUser 대신 getUserState 사용
Future<UserState> getUserState() async {
  final session = _supabase.auth.currentSession;
  if (session == null || session.user == null) {
    return UserState.notLoggedIn;
  }

  try {
    await _supabase.rpc('get_user_profile_safe', 
      params: {'p_user_id': session.user!.id});
    return UserState.loggedIn;
  } catch (e) {
    final isProfileNotFound = /* ... */;
    if (isProfileNotFound) {
      return UserState.tempSession;
    }
    // 네트워크 에러 등은 loggedIn으로 간주 (재시도)
    return UserState.loggedIn;
  }
}
```

**redirect에서 사용**:
```dart
redirect: (context, state) async {
  final userState = await authService.getUserState();
  
  if (userState == UserState.tempSession) {
    final session = SupabaseConfig.client.auth.currentSession;
    final provider = _extractProvider(session!.user!);
    return '/signup?type=oauth&provider=$provider';
  }
  
  if (userState == UserState.notLoggedIn) {
    final isSigningUp = state.matchedLocation == '/signup';
    if (isSigningUp) return null;
    return '/login';
  }
  
  // loggedIn 상태
  return null;
}
```

---

### 개선 2: 타이밍 문제 해결

**방안**: `signInWithOAuth` 직후 `currentUser` 호출 제거

```dart
Future<void> signInWithKakao() async {
  try {
    if (kIsWeb) {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.kakao,
        authScreenLaunchMode: LaunchMode.inAppWebView,
      );
      // ⚠️ currentUser 호출 제거
      // authStateChanges에서 자동으로 처리됨
      return;
    }
    // ...
  } catch (e) {
    throw Exception('Kakao 로그인 실패: $e');
  }
}
```

**반환 타입 변경**:
```dart
// Future<app_user.User?> → Future<void>
Future<void> signInWithKakao() async { /* ... */ }
```

---

### 개선 3: Provider 정보 추출 개선

**방안**: OAuth 로그인 후 Provider 정보를 명확히 추출

```dart
String _extractProvider(User user) {
  // 1. identities에서 provider 추출 (가장 신뢰할 수 있음)
  if (user.identities != null && user.identities!.isNotEmpty) {
    final identity = user.identities!.firstWhere(
      (i) => i.provider != 'email',
      orElse: () => user.identities!.first,
    );
    if (identity.provider != 'email') {
      return identity.provider;
    }
  }
  
  // 2. appMetadata에서 추출
  final metadata = user.appMetadata;
  if (metadata.containsKey('provider')) {
    return metadata['provider'] as String;
  }
  
  // 3. userMetadata에서 추출
  final userMetadata = user.userMetadata;
  if (userMetadata != null && userMetadata.containsKey('provider')) {
    return userMetadata['provider'] as String;
  }
  
  // 4. email 도메인으로 추정 (google.com → google)
  if (user.email != null) {
    final domain = user.email!.split('@')[1];
    if (domain == 'gmail.com' || domain.contains('google')) {
      return 'google';
    }
  }
  
  // 5. fallback
  return 'unknown';
}
```

---

### 개선 4: 에러 처리 개선

**방안**: 네트워크 에러와 프로필 없음을 구분

```dart
Future<UserState> getUserState() async {
  final session = _supabase.auth.currentSession;
  if (session == null || session.user == null) {
    return UserState.notLoggedIn;
  }

  try {
    await _supabase.rpc('get_user_profile_safe', 
      params: {'p_user_id': session.user!.id});
    return UserState.loggedIn;
  } catch (e) {
    // 네트워크 에러 확인
    if (e is SocketException || e is TimeoutException) {
      // 네트워크 에러는 재시도 가능하므로 loggedIn으로 간주
      debugPrint('네트워크 에러 발생, 재시도 필요: $e');
      return UserState.loggedIn; // 또는 별도 상태 추가
    }
    
    // 프로필 없음 확인
    final isProfileNotFound = /* ... */;
    if (isProfileNotFound) {
      return UserState.tempSession;
    }
    
    // 기타 에러는 로그인 상태로 간주 (재시도)
    debugPrint('프로필 조회 실패: $e');
    return UserState.loggedIn;
  }
}
```

---

### 개선 5: 세션 상태 명확화

**방안**: 임시 세션 상태를 명확히 구분

```dart
// UserState enum 사용 (개선 1 참조)
enum UserState {
  notLoggedIn,      // 세션 없음
  loggedIn,         // 세션 있고 프로필 있음
  tempSession,      // 세션 있지만 프로필 없음 (OAuth 회원가입 필요)
}
```

**사용 예시**:
```dart
// redirect에서
if (userState == UserState.tempSession) {
  // 임시 세션 → signup으로 리다이렉트
  return '/signup?type=oauth&provider=$provider';
}
```

---

### 개선 6: Signup 화면 접근 제어 개선

**방안**: Signup 화면에서 redirect 제외

```dart
redirect: (context, state) async {
  final matchedLocation = state.matchedLocation;
  
  // Signup 관련 경로는 redirect 제외
  if (matchedLocation.startsWith('/signup')) {
    return null;
  }
  
  // ... 기존 로직
}
```

---

## 권장 사항

### 즉시 적용 가능한 개선

1. **중복 프로필 체크 제거**
   - `getUserState()` 메서드 추가
   - redirect에서 중복 체크 제거

2. **타이밍 문제 해결**
   - `signInWithOAuth` 직후 `currentUser` 호출 제거
   - 반환 타입을 `Future<void>`로 변경

3. **Provider 정보 추출 개선**
   - `_extractProvider()` 메서드 추가
   - 여러 소스에서 provider 정보 추출

### 중장기 개선

4. **에러 처리 개선**
   - 네트워크 에러와 프로필 없음 구분
   - 재시도 로직 추가

5. **세션 상태 명확화**
   - `UserState` enum 사용
   - 임시 세션 상태 명확히 구분

6. **로딩 상태 개선**
   - OAuth 인증 중 명확한 로딩 상태 표시
   - 사용자 피드백 개선

---

## 결론

현재 소셜 로그인 → Signup 플로우는 기본적으로 동작하지만, 다음과 같은 문제점이 있습니다:

1. **중복 프로필 체크**로 인한 성능 저하
2. **타이밍 문제**로 인한 초기 호출 실패
3. **Provider 정보 추출 불안정**으로 인한 'unknown' fallback
4. **에러 처리 부족**으로 인한 네트워크 에러와 프로필 없음 구분 불가
5. **세션 상태 불명확**으로 인한 혼란

**우선순위**:
1. 🔴 높음: 중복 프로필 체크 제거, 타이밍 문제 해결, Provider 정보 추출 개선
2. 🟡 중간: 에러 처리 개선, 세션 상태 명확화
3. 🟢 낮음: 로딩 상태 개선, 에러 메시지 개선

**다음 단계**:
1. `getUserState()` 메서드 구현
2. `_extractProvider()` 메서드 구현
3. redirect 로직 개선
4. 테스트 및 검증

