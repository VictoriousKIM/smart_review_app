# 리뷰어 회원가입 리다이렉트 에러 해결 로드맵

**작성일**: 2025년 12월 03일  
**목적**: "리뷰어로 시작하기" 버튼 클릭 시 발생하는 리다이렉트 무한 루프 문제 해결

---

## 📋 목차

1. [문제 분석](#문제-분석)
2. [원인 파악](#원인-파악)
3. [해결 방안](#해결-방안)
4. [구현 단계](#구현-단계)
5. [테스트 계획](#테스트-계획)

---

## 문제 분석

### 발생한 에러

```
1. 사용자가 "리뷰어로 시작하기" 버튼 클릭
   ↓
2. /signup/reviewer로 라우팅 시도
   ↓
3. GoRouterRefreshStream이 authStateChanges를 감지
   ↓
4. 전역 redirect 함수 실행
   ↓
5. getUserState() 호출 → UserState.tempSession 반환 (프로필 없음)
   ↓
6. /signup?type=oauth&provider=kakao로 리다이렉트
   ↓
7. 다시 원래 화면으로 돌아옴 (무한 루프)
```

### 콘솔 로그

```
[LOG] GoRouter: INFO: pushing /signup/reviewer
[ERROR] Failed to load resource: the server responded with a status of 400 (Bad Request)
[LOG] 프로필이 없습니다. 회원가입이 필요합니다: 63309845-c879-4405-9b15-95fa310dbaa9
[LOG] GoRouter: INFO: redirecting to RouteMatchList#8348b(uri: /signup?type=oauth&provider=kakao, ...)
```

### 현재 코드 상태

**파일**: `lib/config/app_router.dart`

```dart
// [1] 전역 Redirect
redirect: (context, state) async {
  final matchedLocation = state.matchedLocation;

  // Signup 관련 경로는 redirect 제외 (무한 루프 방지)
  if (matchedLocation.startsWith('/signup')) {
    return null;
  }

  // ... 나머지 로직
  // 3. 임시 세션 (프로필 없음) → signup으로 리다이렉트
  if (userState == UserState.tempSession) {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      final provider = _extractProvider(session.user);
      return '/signup?type=oauth&provider=$provider';
    }
  }
}
```

**문제점**:
- `/signup`으로 시작하는 경로는 제외하지만, `GoRouterRefreshStream`이 `authStateChanges`를 감지할 때마다 redirect가 다시 실행됨
- `authStateChanges`가 `null`을 emit할 때 (프로필 없음) redirect가 트리거됨
- `/signup/reviewer`로 이동한 후에도 `authStateChanges`가 계속 `null`을 emit하여 redirect가 반복됨

---

## 원인 파악

### 1. GoRouterRefreshStream 동작 방식

**파일**: `lib/config/app_router.dart`

```dart
refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
```

**동작**:
- `authStateChanges` 스트림이 새로운 값을 emit할 때마다 `notifyListeners()` 호출
- `GoRouter`가 리빌드되면서 `redirect` 함수가 다시 실행됨
- 프로필이 없는 상태에서는 `authStateChanges`가 계속 `null`을 emit할 수 있음

### 2. authStateChanges 스트림 동작

**파일**: `lib/services/auth_service.dart`

```dart
Stream<app_user.User?> get authStateChanges {
  return _supabase.auth.onAuthStateChange.asyncMap((authState) async {
    final user = authState.session?.user;
    if (user != null) {
      try {
        // 프로필 조회
        final profileResponse = await _supabase.rpc(
          'get_user_profile_safe',
          params: {'p_user_id': user.id},
        );
        // ...
      } catch (e) {
        if (isProfileNotFound) {
          debugPrint('프로필이 없습니다. 회원가입이 필요합니다: ${user.id}');
          return null; // ← 여기서 null 반환
        }
      }
    }
    return null;
  });
}
```

**문제점**:
- 프로필이 없을 때 `null`을 반환
- `GoRouterRefreshStream`이 `null`을 감지하여 redirect 트리거
- `/signup/reviewer` 화면에서도 프로필이 없으므로 계속 `null` 반환

### 3. Redirect 로직의 한계

**현재 로직**:
```dart
if (matchedLocation.startsWith('/signup')) {
  return null; // redirect 제외
}
```

**문제점**:
- `matchedLocation`은 현재 매칭된 경로만 확인
- `GoRouterRefreshStream`이 트리거될 때 `state`가 변경될 수 있음
- `/signup/reviewer`로 이동한 직후에도 redirect가 실행될 수 있음

---

## 해결 방안

### 방안 1: authStateChanges에서 signup 경로일 때 null 반환 방지 (권장)

**장점**:
- 근본적인 해결
- 다른 화면에서도 동일한 문제 방지
- 코드 변경 최소화

**단점**:
- `authStateChanges`에서 현재 경로를 확인해야 함 (의존성 추가 필요)

**구현**:
```dart
// authStateChanges에서 현재 경로 확인
// signup 경로일 때는 null을 emit하지 않고 특별한 값 반환
```

### 방안 2: GoRouterRefreshStream에서 signup 경로 필터링

**장점**:
- `authStateChanges` 수정 불필요
- 라우터 레벨에서 해결

**단점**:
- `GoRouterRefreshStream` 커스터마이징 필요
- 현재 경로 확인 로직 추가 필요

**구현**:
```dart
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream, {this.ignorePaths}) {
    _subscription = stream.asBroadcastStream().listen((_) {
      // ignorePaths에 포함된 경로는 무시
      if (_shouldIgnore()) return;
      notifyListeners();
    });
  }
  
  final List<String>? ignorePaths;
  String? _currentPath;
  
  bool _shouldIgnore() {
    if (ignorePaths == null) return false;
    return ignorePaths!.any((path) => _currentPath?.startsWith(path) ?? false);
  }
}
```

### 방안 3: ReviewerSignupScreen에서 세션 체크 제거

**장점**:
- 간단한 해결
- 특정 화면에만 적용

**단점**:
- 근본적인 해결 아님
- 다른 signup 화면에서도 동일한 문제 발생 가능

**구현**:
```dart
// ReviewerSignupScreen에서 프로필 체크 제거
// 세션이 있으면 바로 회원가입 진행
```

### 방안 4: Redirect 로직 개선 (현재 경로 확인 강화)

**장점**:
- 기존 로직 개선
- 명확한 경로 제외

**단점**:
- `GoRouterRefreshStream` 트리거 시점 문제 해결 안 됨

**구현**:
```dart
redirect: (context, state) async {
  final matchedLocation = state.matchedLocation;
  final fullPath = state.uri.path;
  
  // Signup 관련 경로는 redirect 제외 (더 명확하게)
  if (matchedLocation.startsWith('/signup') || 
      fullPath.startsWith('/signup')) {
    return null;
  }
  
  // ...
}
```

---

## 구현 단계

### ✅ Phase 1: 문제 확인 및 분석 (완료)

- [x] 에러 재현
- [x] 콘솔 로그 확인
- [x] 코드 분석
- [x] 원인 파악

### 🔄 Phase 2: 해결 방안 선택 및 구현

**선택한 방안**: **방안 1 + 방안 4 조합**

**이유**:
1. 방안 1: `authStateChanges`에서 signup 경로일 때는 특별한 처리를 하여 불필요한 redirect 방지
2. 방안 4: Redirect 로직을 더 명확하게 개선하여 이중 방어

#### 2.1 GoRouterRefreshStream 개선

**파일**: `lib/config/app_router.dart`

**변경 사항**:
- `GoRouterRefreshStream`에 현재 경로 추적 기능 추가
- signup 경로일 때는 `notifyListeners()` 호출 제한

**구현**:
```dart
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream, {this.router}) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 200), () {
        // 현재 경로가 signup으로 시작하면 무시
        final currentPath = router?.routerDelegate.currentConfiguration.uri.path ?? '';
        if (currentPath.startsWith('/signup')) {
          return; // signup 경로에서는 redirect 트리거하지 않음
        }
        notifyListeners();
      });
    });
  }

  final GoRouter? router;
  // ... 나머지 코드
}
```

#### 2.2 Redirect 로직 개선

**파일**: `lib/config/app_router.dart`

**변경 사항**:
- `state.uri.path`도 확인하여 더 명확하게 signup 경로 제외
- 디버그 로그 추가

**구현**:
```dart
redirect: (context, state) async {
  final matchedLocation = state.matchedLocation;
  final fullPath = state.uri.path;

  // Signup 관련 경로는 redirect 제외 (무한 루프 방지)
  // matchedLocation과 fullPath 모두 확인하여 이중 방어
  if (matchedLocation.startsWith('/signup') || 
      fullPath.startsWith('/signup')) {
    debugPrint('Signup 경로는 redirect 제외: $matchedLocation, $fullPath');
    return null;
  }

  // ... 나머지 로직
}
```

#### 2.3 authStateChanges 개선 (선택사항)

**파일**: `lib/services/auth_service.dart`

**변경 사항**:
- 프로필이 없을 때도 특정 상황에서는 null을 emit하지 않도록 개선
- 하지만 이 방법은 복잡하므로 Phase 2에서는 제외

### 🔄 Phase 3: 테스트 및 검증

#### 3.1 단위 테스트

- [ ] `GoRouterRefreshStream` 테스트
- [ ] Redirect 로직 테스트
- [ ] Signup 경로 제외 테스트

#### 3.2 통합 테스트

- [ ] "리뷰어로 시작하기" 버튼 클릭 테스트
- [ ] "광고주로 시작하기" 버튼 클릭 테스트
- [ ] 회원가입 완료 후 홈 화면 이동 테스트

#### 3.3 시나리오 테스트

**시나리오 1: 리뷰어 회원가입 플로우**
```
1. OAuth 로그인 (Kakao)
   ↓
2. /signup?type=oauth&provider=kakao 화면 표시
   ↓
3. "리뷰어로 시작하기" 버튼 클릭
   ↓
4. /signup/reviewer 화면으로 이동 (리다이렉트 없음)
   ↓
5. 프로필 입력 → SNS 연결 → 회사 선택
   ↓
6. 회원가입 완료
   ↓
7. /home 화면으로 이동
```

**시나리오 2: 광고주 회원가입 플로우**
```
1. OAuth 로그인 (Google)
   ↓
2. /signup?type=oauth&provider=google 화면 표시
   ↓
3. "광고주로 시작하기" 버튼 클릭
   ↓
4. /signup/advertiser 화면으로 이동 (리다이렉트 없음)
   ↓
5. 사업자 인증 → 입출금통장 → 회원가입
   ↓
6. 회원가입 완료
   ↓
7. /home 화면으로 이동
```

**시나리오 3: 이미 로그인한 사용자가 signup 경로 접근**
```
1. 이미 로그인한 상태
   ↓
2. /signup/reviewer 직접 접근 시도
   ↓
3. 프로필이 있으면 /home으로 리다이렉트
   ↓
4. 프로필이 없으면 회원가입 진행 허용
```

---

## 테스트 계획

### 테스트 케이스

#### TC-1: 리뷰어 회원가입 플로우 정상 동작

**전제 조건**:
- OAuth 로그인 완료 (프로필 없음)
- `/signup?type=oauth&provider=kakao` 화면 표시

**실행 단계**:
1. "리뷰어로 시작하기" 버튼 클릭
2. `/signup/reviewer` 화면으로 이동 확인
3. 리다이렉트 없이 화면 유지 확인
4. 프로필 입력 완료
5. SNS 연결 완료 (또는 건너뛰기)
6. 회사 선택 완료 (또는 건너뛰기)
7. 회원가입 완료 버튼 클릭
8. `/home` 화면으로 이동 확인

**예상 결과**:
- ✅ `/signup/reviewer` 화면으로 정상 이동
- ✅ 리다이렉트 무한 루프 없음
- ✅ 회원가입 완료 후 홈 화면 이동

#### TC-2: 광고주 회원가입 플로우 정상 동작

**전제 조건**:
- OAuth 로그인 완료 (프로필 없음)
- `/signup?type=oauth&provider=google` 화면 표시

**실행 단계**:
1. "광고주로 시작하기" 버튼 클릭
2. `/signup/advertiser` 화면으로 이동 확인
3. 리다이렉트 없이 화면 유지 확인
4. 회원가입 진행

**예상 결과**:
- ✅ `/signup/advertiser` 화면으로 정상 이동
- ✅ 리다이렉트 무한 루프 없음

#### TC-3: 이미 로그인한 사용자 signup 경로 접근

**전제 조건**:
- 이미 로그인 완료 (프로필 있음)
- `/home` 화면 표시

**실행 단계**:
1. `/signup/reviewer` 직접 접근 시도
2. 리다이렉트 동작 확인

**예상 결과**:
- ✅ `/home`으로 리다이렉트 (프로필이 있으므로)

#### TC-4: 네트워크 에러 상황

**전제 조건**:
- OAuth 로그인 완료 (프로필 없음)
- 네트워크 연결 불안정

**실행 단계**:
1. "리뷰어로 시작하기" 버튼 클릭
2. 네트워크 에러 발생 시뮬레이션
3. 에러 처리 확인

**예상 결과**:
- ✅ 적절한 에러 메시지 표시
- ✅ 리다이렉트 무한 루프 없음

---

## 예상 작업 시간

- **Phase 2 (구현)**: 2-3시간
  - GoRouterRefreshStream 개선: 1시간
  - Redirect 로직 개선: 30분
  - 테스트 및 디버깅: 1-1.5시간

- **Phase 3 (테스트)**: 1-2시간
  - 단위 테스트: 30분
  - 통합 테스트: 30분
  - 시나리오 테스트: 30분-1시간

**총 예상 시간**: 3-5시간

---

## 참고 사항

### 관련 문서
- `docs/social-login-signup-flow-fix-implementation-report.md`
- `docs/social-login-signup-flow-fix-roadmap.md`
- `docs/social-login-signup-flow-issues-analysis.md`

### 관련 파일
- `lib/config/app_router.dart`
- `lib/services/auth_service.dart`
- `lib/screens/auth/signup_screen.dart`
- `lib/screens/auth/reviewer_signup_screen.dart`

### 주의사항
1. **GoRouterRefreshStream 수정 시**: 기존 동작에 영향을 주지 않도록 주의
2. **Redirect 로직 수정 시**: 다른 경로의 리다이렉트 동작 확인 필요
3. **테스트 시**: 다양한 시나리오로 테스트하여 회귀 버그 방지

---

## 다음 단계

1. ✅ Phase 1 완료 (문제 분석)
2. 🔄 Phase 2 진행 (구현)
3. ⏳ Phase 3 대기 (테스트)

**우선순위**: 높음 (사용자 회원가입 플로우의 핵심 기능)

