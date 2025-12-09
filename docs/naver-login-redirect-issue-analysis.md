# 네이버 소셜 로그인 리다이렉트 문제 분석 및 해결 방안

**작성일**: 2025년 12월 09일  
**작업 기간**: 2025년 12월 09일

## 📋 문제 요약

네이버 소셜 로그인 시 토큰 확인 단계에서 로그인 스크린으로 갔다가 다음 스크린으로 넘어가는 문제가 발생합니다. 반면 카카오 로그인은 토큰 확인 단계에서 바로 다음 스크린으로 이동합니다.

### 증상
1. 네이버 로그인 버튼 클릭
2. 네이버 OAuth 페이지에서 로그인 완료
3. `/loading?code=xxx`로 리다이렉트
4. **문제**: 로그인 스크린으로 잠깐 이동한 후 홈/회원가입 화면으로 이동
5. 카카오 로그인은 3단계 후 바로 홈/회원가입 화면으로 이동

---

## 🔍 원인 분석

### 1. 카카오 로그인 플로우 (정상 동작)

```
1. 카카오 로그인 버튼 클릭
   ↓
2. Supabase OAuth 사용 (signInWithOAuth)
   ↓
3. 카카오 OAuth 페이지에서 로그인 완료
   ↓
4. `/` 경로로 리다이렉트 (code 파라미터 포함)
   ↓
5. GoRoute의 redirect에서 exchangeCodeForSession 호출
   ↓
6. Supabase 세션이 즉시 생성됨
   ↓
7. authStateChanges 스트림이 변경됨 (Supabase 세션 변경 감지)
   ↓
8. GoRouter의 refreshListenable이 변경을 감지
   ↓
9. 전역 redirect가 실행되어 getUserState() 호출
   ↓
10. 프로필 확인 후 /home 또는 /signup으로 리다이렉트
```

**핵심 포인트:**
- Supabase OAuth 사용 → Supabase 세션 생성
- `authStateChanges` 스트림이 변경됨 → GoRouter가 자동으로 리다이렉트

### 2. 네이버 로그인 플로우 (문제 발생)

```
1. 네이버 로그인 버튼 클릭
   ↓
2. 네이버 OAuth 페이지로 직접 이동 (html.window.location.href)
   ↓
3. 네이버 OAuth 페이지에서 로그인 완료
   ↓
4. `/loading?code=xxx`로 리다이렉트
   ↓
5. GoRoute의 redirect에서 handleNaverCallback 호출
   ↓
6. Workers API 호출하여 Custom JWT 토큰 받음
   ↓
7. CustomJwtSessionProvider.saveSession() 호출하여 세션 저장
   ↓
8. getUserState() 호출하여 프로필 확인
   ↓
9. /home 또는 /signup으로 리다이렉트
   ↓
10. [문제] 전역 redirect가 먼저 실행되어 로그인 스크린으로 이동
```

**핵심 포인트:**
- Custom JWT 세션 사용 → Supabase 세션이 아님
- `authStateChanges` 스트림이 변경되지 않음 (Supabase 세션 변경 없음)
- GoRouter가 자동으로 리다이렉트하지 않음
- 세션 저장 후 `getUserState()` 호출 시 타이밍 문제 발생 가능

### 3. 코드 분석

#### 3-1. 카카오 로그인 처리 (app_router.dart)

```dart
// 루트 경로에서 OAuth 콜백 처리
GoRoute(
  path: '/',
  name: 'root',
  redirect: (context, state) async {
    final code = state.uri.queryParameters['code'];
    
    if (code != null && kIsWeb) {
      // Supabase OAuth 세션 교환
      final response = await supabase.auth.exchangeCodeForSession(code);
      
      // 프로필 확인 후 적절한 경로로 리다이렉트
      final userState = await authService.getUserState();
      if (userState == UserState.tempSession) {
        return '/signup?type=oauth&provider=$provider';
      } else if (userState == UserState.loggedIn) {
        return '/home';
      }
    }
  },
)
```

**특징:**
- `exchangeCodeForSession`이 Supabase 세션을 즉시 생성
- 세션 생성 후 `getUserState()` 호출 시 세션이 이미 존재
- 전역 redirect가 실행되기 전에 GoRoute의 redirect가 완료됨

#### 3-2. 네이버 로그인 처리 (app_router.dart)

```dart
// 로딩 경로에서 네이버 콜백 처리
GoRoute(
  path: '/loading',
  name: 'loading',
  redirect: (context, state) async {
    final code = state.uri.queryParameters['code'];
    
    if (code != null && kIsWeb) {
      // Workers API 호출하여 Custom JWT 토큰 받음
      final authResponse = await naverAuthService
          .handleNaverCallback(code, stateParam);
      
      if (authResponse?.user != null && authResponse?.session != null) {
        // 프로필 확인 후 적절한 경로로 리다이렉트
        final userState = await authService.getUserState();
        if (userState == UserState.tempSession) {
          return '/signup?type=oauth&provider=naver';
        } else if (userState == UserState.loggedIn) {
          return '/home';
        }
      }
    }
  },
)
```

**문제점:**
- `handleNaverCallback`에서 세션 저장 후 `getUserState()` 호출
- 세션 저장이 완료되기 전에 전역 redirect가 실행될 수 있음
- `authStateChanges` 스트림이 변경되지 않아 GoRouter가 자동으로 리다이렉트하지 않음

#### 3-3. 전역 Redirect 로직 (app_router.dart)

```dart
redirect: (context, state) async {
  final isLoading = matchedLocation == '/loading' || fullPath == '/loading';
  
  // Loading 경로는 redirect 제외
  if (isLoading) {
    return null; // GoRoute의 redirect가 실행되도록 null 반환
  }
  
  // 사용자 상태 확인
  final userState = await authService.getUserState();
  
  // 비로그인 상태
  if (userState == UserState.notLoggedIn) {
    if (isLoggingIn) return null;
    return '/login'; // ← 여기서 로그인 스크린으로 이동
  }
  
  // 로그인 상태
  if (userState == UserState.loggedIn) {
    if (isLoggingIn || isRoot) return '/home';
    return null;
  }
}
```

**문제점:**
- `/loading` 경로는 전역 redirect에서 제외되지만, 세션 저장 후 리다이렉트 시 전역 redirect가 먼저 실행될 수 있음
- 세션 저장이 완료되기 전에 `getUserState()`가 호출되면 `notLoggedIn` 상태로 판단되어 `/login`으로 리다이렉트

#### 3-4. 세션 저장 로직 (naver_auth_service.dart)

```dart
// Custom JWT 저장
await CustomJwtSessionProvider.saveSession(
  token: customAccessToken,
  userId: user.id,
  email: user.email,
  provider: 'naver',
);

// 세션 저장 후 바로 getUserState() 호출
final userState = await authService.getUserState();
```

**문제점:**
- `saveSession`은 비동기 작업이지만, 저장 완료를 보장하지 않음
- Secure Storage에 저장하는 작업이 완료되기 전에 `getUserState()`가 호출될 수 있음

#### 3-5. 세션 조회 로직 (unified_session_manager.dart)

```dart
Future<SessionInfo?> getActiveSession() async {
  for (var provider in _providers) {
    try {
      final session = await provider.getSession();
      if (session != null && !session.isExpired) {
        return session;
      }
    } catch (e) {
      // 에러 처리
    }
  }
  return null;
}
```

**문제점:**
- `CustomJwtSessionProvider.getSession()`이 Secure Storage에서 읽는 작업이 완료되기 전에 호출될 수 있음
- 비동기 작업의 타이밍 문제

---

## 💡 해결 방안

### 방안 1: 세션 저장 후 명시적 확인 (추천)

세션 저장 후 저장이 완료되었는지 명시적으로 확인한 후 `getUserState()`를 호출합니다.

**수정 위치**: `lib/config/app_router.dart`

```dart
// /loading 경로의 redirect에서
if (authResponse?.user != null && authResponse?.session != null) {
  debugPrint('✅ 네이버 로그인 성공');
  
  // 세션 저장 완료 대기 (명시적 확인)
  await Future.delayed(const Duration(milliseconds: 100));
  
  // 세션이 저장되었는지 확인
  final sessionManager = UnifiedSessionManager();
  final hasSession = await sessionManager.hasActiveSession();
  
  if (!hasSession) {
    debugPrint('⚠️ 세션 저장이 완료되지 않았습니다. 재시도...');
    await Future.delayed(const Duration(milliseconds: 200));
  }
  
  // 프로필 확인 후 적절한 경로로 리다이렉트
  final userState = await authService.getUserState();
  // ...
}
```

**장점:**
- 간단한 수정
- 세션 저장 완료를 보장

**단점:**
- 지연 시간이 필요 (사용자 경험 저하 가능)

### 방안 2: 세션 저장 완료를 보장하는 메서드 추가 (추천)

`CustomJwtSessionProvider`에 세션 저장 완료를 보장하는 메서드를 추가합니다.

**수정 위치**: `lib/services/session/custom_jwt_session_provider.dart`

```dart
/// Custom JWT 세션 저장 (저장 완료 보장)
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
      debugPrint('✅ 세션 저장 완료 확인됨');
      return;
    }
    
    // 저장이 완료되지 않았으면 잠시 대기 후 재시도
    await Future.delayed(const Duration(milliseconds: 50));
  }
  
  throw Exception('세션 저장 확인 실패');
}
```

**수정 위치**: `lib/services/naver_auth_service.dart`

```dart
// CustomJwtSessionProvider.saveSession 대신 saveSessionAndVerify 사용
await CustomJwtSessionProvider.saveSessionAndVerify(
  token: customAccessToken,
  userId: user.id,
  email: user.email,
  provider: 'naver',
);
```

**장점:**
- 세션 저장 완료를 보장
- 재시도 로직으로 안정성 향상

**단점:**
- 코드 수정 범위가 큼

### 방안 3: 전역 redirect에서 /loading 경로 처리 개선 (추천)

전역 redirect에서 `/loading` 경로를 더 명확하게 제외하고, 세션 저장 중임을 표시하는 플래그를 사용합니다.

**수정 위치**: `lib/config/app_router.dart`

```dart
redirect: (context, state) async {
  final isLoading = matchedLocation == '/loading' || fullPath == '/loading';
  
  // Loading 경로는 redirect 제외 (네이버 로그인 콜백 처리 중)
  if (isLoading) {
    debugPrint('Redirect: /loading 경로는 전역 redirect 제외');
    return null;
  }
  
  // 네이버 로그인 콜백 처리 중인지 확인 (code 파라미터가 있으면 제외)
  final hasNaverCode = state.uri.queryParameters.containsKey('code') &&
      state.uri.path == '/loading';
  if (hasNaverCode) {
    debugPrint('Redirect: 네이버 로그인 콜백 처리 중 (전역 redirect 제외)');
    return null;
  }
  
  // 사용자 상태 확인
  final userState = await authService.getUserState();
  // ...
}
```

**장점:**
- 전역 redirect에서 명확하게 제외
- 추가 지연 시간 불필요

**단점:**
- 이미 `/loading` 경로는 제외되어 있음 (추가 효과 제한적)

### 방안 4: 세션 저장 후 즉시 리다이렉트

세션 저장 후 `getUserState()`를 호출하지 않고, 바로 적절한 경로로 리다이렉트합니다. 전역 redirect가 세션을 확인하여 처리하도록 합니다.

**수정 위치**: `lib/config/app_router.dart`

```dart
// /loading 경로의 redirect에서
if (authResponse?.user != null && authResponse?.session != null) {
  debugPrint('✅ 네이버 로그인 성공');
  
  // 세션 저장 완료 대기
  await Future.delayed(const Duration(milliseconds: 150));
  
  // 세션이 저장되었는지 확인
  final sessionManager = UnifiedSessionManager();
  final hasSession = await sessionManager.hasActiveSession();
  
  if (!hasSession) {
    debugPrint('⚠️ 세션 저장 실패');
    throw Exception('세션 저장 실패');
  }
  
  // 프로필 확인을 위해 잠시 대기 후 리다이렉트
  // 전역 redirect가 세션을 확인하여 처리하도록 함
  await Future.delayed(const Duration(milliseconds: 100));
  
  // 프로필 확인 후 적절한 경로로 리다이렉트
  final userState = await authService.getUserState();
  if (userState == UserState.tempSession) {
    return '/signup?type=oauth&provider=naver';
  } else if (userState == UserState.loggedIn) {
    return '/home';
  }
  
  // 기본적으로 홈으로 리다이렉트
  return '/home';
}
```

**장점:**
- 세션 저장 완료를 보장
- 프로필 확인 후 적절한 경로로 리다이렉트

**단점:**
- 약간의 지연 시간 필요 (사용자 경험에 큰 영향 없음)

---

## 🎯 최종 해결 방안

**방안 5 (세션 저장 중 플래그 사용)**를 추천합니다. 이유:

1. **안정성**: 플래그 기반으로 정확한 타이밍 제어
2. **성능**: 지연 시간 없이 안정적으로 동작
3. **명확성**: 전역 redirect에서 명확하게 제외
4. **근본적 해결**: 타이밍 문제를 근본적으로 해결

### 구현 단계

1. **세션 저장 완료 확인 로직 추가**
   - `CustomJwtSessionProvider`에 `saveSessionAndVerify` 메서드 추가
   - 세션 저장 후 저장 완료를 확인

2. **세션 저장 중 플래그 관리**
   - 세션 저장 시작 시 `naver_session_saving` 플래그 설정
   - 전역 redirect에서 플래그 확인하여 제외
   - 세션 저장 완료 시 플래그 제거

3. **/loading 경로의 redirect 수정**
   - 세션 저장 후 저장 완료 확인
   - 프로필 확인 후 적절한 경로로 리다이렉트
   - 플래그 제거로 전역 redirect 활성화

4. **테스트**
   - 네이버 로그인 플로우 테스트
   - 로그인 스크린으로 이동하지 않는지 확인

---

## 📊 비교표

| 방안 | 구현 난이도 | 안정성 | 사용자 경험 | 추천도 |
|------|------------|--------|------------|--------|
| 방안 1 | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| 방안 2 | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 방안 3 | ⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| 방안 4 | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 방안 5 | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## 🔧 추가 개선 사항

### 1. authStateChanges 스트림 개선

Custom JWT 세션도 `authStateChanges` 스트림에서 감지하도록 개선할 수 있습니다.

**현재 문제:**
- `authStateChanges`는 Supabase의 `onAuthStateChange`만 감지
- Custom JWT 세션 변경은 감지하지 않음

**개선 방안:**
- Custom JWT 세션 변경을 감지하는 별도 스트림 추가
- `authStateChanges`와 병합하여 통합 스트림 생성

세션 저장 중임을 표시하는 플래그를 사용하여 전역 redirect에서 제외합니다.

**수정 위치**: `lib/config/app_router.dart`

```dart
// 전역 redirect에서
final prefs = await SharedPreferences.getInstance();
final isNaverSessionSaving = prefs.getBool('naver_session_saving') ?? false;
if (isNaverSessionSaving) {
  debugPrint('Redirect: 네이버 세션 저장 중 (전역 redirect 제외)');
  return null; // 세션 저장이 완료될 때까지 전역 redirect 제외
}

// /loading 경로의 redirect에서
// 세션 저장 시작 시
await prefs.setBool('naver_session_saving', true);

// 세션 저장 완료 시
await prefs.setBool('naver_session_saving', false);
```

**장점:**
- 지연 시간 없이 안정적으로 동작
- 전역 redirect에서 명확하게 제외
- 타이밍 문제를 근본적으로 해결
- 구현이 간단하고 명확함

**단점:**
- 플래그 관리 필요 (에러 처리 시에도 제거 필요)

**구현 완료:**
- ✅ 세션 저장 시작 시 플래그 설정
- ✅ 전역 redirect에서 플래그 확인하여 제외
- ✅ 세션 저장 완료 시 플래그 제거
- ✅ 에러 처리 시 플래그 제거

---

## 📝 참고 자료

- [app_router.dart](../lib/config/app_router.dart) - 라우터 설정
- [naver_auth_service.dart](../lib/services/naver_auth_service.dart) - 네이버 인증 서비스
- [custom_jwt_session_provider.dart](../lib/services/session/custom_jwt_session_provider.dart) - Custom JWT 세션 제공자
- [unified_session_manager.dart](../lib/services/session/unified_session_manager.dart) - 통합 세션 관리자
- [auth_service.dart](../lib/services/auth_service.dart) - 인증 서비스

---

## ✅ 체크리스트

- [ ] 세션 저장 완료 확인 로직 추가
- [ ] /loading 경로의 redirect 수정
- [ ] 네이버 로그인 플로우 테스트
- [ ] 로그인 스크린으로 이동하지 않는지 확인
- [ ] 프로필이 있는 경우 홈으로 이동하는지 확인
- [ ] 프로필이 없는 경우 회원가입으로 이동하는지 확인

