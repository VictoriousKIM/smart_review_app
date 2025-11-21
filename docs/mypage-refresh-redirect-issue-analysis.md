# 마이페이지 새로고침 시 홈으로 리다이렉트되는 문제 분석 및 해결 방안

## 📋 문제 개요

마이페이지에서 새로고침(페이지 리로드)을 하면 마이페이지가 유지되지 않고 홈(`/home`)으로 리다이렉트되는 문제가 발생합니다.

## 🔍 문제 분석

### 현재 라우팅 구조

```97:126:lib/config/app_router.dart
    // [1] 전역 Redirect
    redirect: (context, state) async {
      final matchedLocation = state.matchedLocation;

      // 1. 마이페이지 및 하위 경로는 전역 로직 무시 (Local Redirect에 위임)
      if (matchedLocation.startsWith('/mypage')) {
        return null;
      }

      final isLoggingIn = matchedLocation == '/login';
      final isRoot = matchedLocation == '/';

      // 2. 세션 확인 (비동기)
      final user = await authService.currentUser;
      final isLoggedIn = user != null;

      // 3. 비로그인 상태
      if (!isLoggedIn) {
        if (isLoggingIn) return null;
        return '/login';
      }

      // 4. 로그인 상태
      if (isLoggedIn) {
        // 로그인 페이지나 루트 접근 시 홈으로
        // 주의: 위에서 /mypage는 이미 return null로 빠져나갔으므로 여기서는 안전함
        if (isLoggingIn || isRoot) return '/home';
      }

      return null;
    },
```

### 문제의 원인

1. **마이페이지 경로의 특별 처리로 인한 불일치**
   - 현재 마이페이지(`/mypage`)는 전역 redirect에서 `null`을 반환하여 무시됨
   - 반면 `/home`, `/campaigns`, `/guide` 등은 전역 redirect를 통과함
   - 이로 인해 새로고침 시 라우팅 로직이 일관되지 않게 동작할 수 있음

2. **새로고침 시 `authStateChanges` 스트림 트리거**
   - 새로고침 시 Supabase의 `onAuthStateChange`가 트리거됨
   - `GoRouterRefreshStream`이 이를 감지하여 `notifyListeners()` 호출
   - GoRouter가 전체 라우팅 로직을 재평가

3. **전역 Redirect의 비동기 처리 타이밍 이슈**
   - 전역 redirect는 `async` 함수이지만, 새로고침 직후 `authService.currentUser`가 아직 완전히 로드되지 않았을 수 있음
   - 마이페이지가 전역 redirect에서 무시되면서, 로컬 redirect만 실행되는데 이때 타이밍 문제가 발생할 수 있음

## 🛠️ 해결 방안

### 권장 해결 방법: 마이페이지도 일반 경로처럼 처리

마이페이지를 캠페인이나 가이드처럼 전역 redirect에서 특별히 처리하지 않고, 일반 경로처럼 두는 것이 가장 간단하고 일관성 있는 해결책입니다.

#### 장점

1. **일관성**: 모든 ShellRoute 내 경로가 동일한 방식으로 처리됨
2. **단순성**: 특별한 예외 처리가 없어 코드가 더 간단해짐
3. **안정성**: 전역 redirect에서 로그인 체크가 먼저 이루어지고, 그 다음 로컬 redirect가 실행되어 더 안정적

#### 수정된 전역 Redirect

```dart
// [1] 전역 Redirect
redirect: (context, state) async {
  final matchedLocation = state.matchedLocation;

  final isLoggingIn = matchedLocation == '/login';
  final isRoot = matchedLocation == '/';

  // 1. 세션 확인 (비동기)
  final user = await authService.currentUser;
  final isLoggedIn = user != null;

  // 2. 비로그인 상태
  if (!isLoggedIn) {
    if (isLoggingIn) return null;
    // 마이페이지도 로컬 redirect에서 처리하므로 전역에서는 로그인 체크만
    return '/login';
  }

  // 3. 로그인 상태
  if (isLoggedIn) {
    // 로그인 페이지나 루트 접근 시 홈으로
    if (isLoggingIn || isRoot) return '/home';
  }

  return null;
},
```

#### 동작 방식

1. **비로그인 상태에서 마이페이지 접근**
   - 전역 redirect: `/login`으로 리다이렉트
   - 로컬 redirect: 실행되지 않음

2. **로그인 상태에서 마이페이지 접근**
   - 전역 redirect: 통과 (`null` 반환)
   - 로컬 redirect: 사용자 타입에 따라 적절한 마이페이지로 리다이렉트
     - `/mypage` → `/mypage/reviewer` 또는 `/mypage/advertiser` 또는 `/mypage/admin`
     - `/mypage/reviewer` → 로그인 체크 후 통과

3. **새로고침 시**
   - 전역 redirect: 로그인 상태 확인 후 통과
   - 로컬 redirect: 사용자 타입에 따라 적절한 마이페이지로 리다이렉트
   - 현재 경로가 이미 적절한 마이페이지라면 유지됨

## 🔧 구현 단계

### 1단계: 전역 Redirect 수정

전역 redirect에서 마이페이지 특별 처리 제거:

```dart
// lib/config/app_router.dart
redirect: (context, state) async {
  final matchedLocation = state.matchedLocation;

  final isLoggingIn = matchedLocation == '/login';
  final isRoot = matchedLocation == '/';

  // 1. 세션 확인 (비동기)
  final user = await authService.currentUser;
  final isLoggedIn = user != null;

  // 2. 비로그인 상태
  if (!isLoggedIn) {
    if (isLoggingIn) return null;
    // 마이페이지도 로컬 redirect에서 처리하므로 전역에서는 로그인 체크만
    return '/login';
  }

  // 3. 로그인 상태
  if (isLoggedIn) {
    // 로그인 페이지나 루트 접근 시 홈으로
    if (isLoggingIn || isRoot) return '/home';
  }

  return null;
},
```

### 2단계: 로컬 Redirect 확인

마이페이지의 로컬 redirect는 이미 적절하게 구현되어 있습니다:

```182:200:lib/config/app_router.dart
            redirect: (context, state) {
              if (state.matchedLocation != '/mypage') return null;

              // 동기적 상태 읽기
              final userAsync = ref.read(currentUserProvider);

              return userAsync.when(
                data: (user) {
                  if (user == null) return '/login';
                  if (user.userType == app_user.UserType.admin)
                    return '/mypage/admin';
                  if (user.isAdvertiser) return '/mypage/advertiser';
                  return '/mypage/reviewer';
                },
                // 🔥 [핵심] 로딩이나 에러 시 절대 리다이렉트 하지 않음 (현재 경로 유지)
                loading: () => null,
                error: (_, __) => null,
              );
            },
```

### 3단계: 테스트

1. 마이페이지에 접속
2. 브라우저 새로고침 (F5 또는 Ctrl+R)
3. 마이페이지가 유지되는지 확인
4. 다른 마이페이지 하위 경로에서도 테스트
   - `/mypage/reviewer`
   - `/mypage/advertiser`
   - `/mypage/admin`
   - `/mypage/reviewer/points`
   - 등

## 📝 추가 고려사항

### 1. 로컬 Redirect의 로딩 상태 처리

마이페이지의 로컬 redirect는 로딩 상태일 때 `null`을 반환하여 현재 경로를 유지합니다. 이는 새로고침 시에도 경로가 유지되도록 보장합니다:

```dart
loading: () => null,  // 현재 경로 유지
error: (_, __) => null,  // 현재 경로 유지
```

### 2. Builder에서의 UI 처리

로컬 redirect가 `null`을 반환하면 Builder가 실행되어 로딩 화면을 표시합니다:

```219:232:lib/config/app_router.dart
            builder: (context, state) {
              // Builder 내에서 상태에 따라 UI 분기
              final userAsync = ref.watch(currentUserProvider);
              return userAsync.when(
                data: (user) {
                  if (user == null) return const SizedBox.shrink();
                  return ReviewerMyPageScreen(user: user);
                },
                // 로딩 중일 때 보여줄 UI
                loading: () => const LoadingScreen(),
                // 에러 났을 때 보여줄 UI (로그인으로 튕기지 않음)
                error: (err, stack) => Center(child: Text('데이터 로드 실패: $err')),
              );
            },
```

### 3. 전역 Redirect와 로컬 Redirect의 역할 분리

- **전역 Redirect**: 로그인 상태만 확인 (모든 경로에 공통 적용)
- **로컬 Redirect**: 경로별 특수 로직 처리 (사용자 타입에 따른 분기 등)

이렇게 역할을 분리하면 코드가 더 명확하고 유지보수하기 쉬워집니다.

## ✅ 검증 체크리스트

- [ ] 마이페이지에서 새로고침 시 경로 유지
- [ ] 리뷰어 마이페이지에서 새로고침 시 경로 유지
- [ ] 광고주 마이페이지에서 새로고침 시 경로 유지
- [ ] 관리자 마이페이지에서 새로고침 시 경로 유지
- [ ] 마이페이지 하위 경로에서 새로고침 시 경로 유지
- [ ] 비로그인 상태에서 마이페이지 접근 시 로그인으로 리다이렉트
- [ ] 로그인 후 마이페이지 접근 정상 작동
- [ ] 다른 페이지에서 새로고침 시 정상 작동

## 🎯 결론

마이페이지를 캠페인이나 가이드처럼 전역 redirect에서 특별히 처리하지 않는 방식으로 변경하는 것이 가장 간단하고 효과적인 해결책입니다. 이 방법은:

1. **일관성**: 모든 ShellRoute 내 경로가 동일한 방식으로 처리됨
2. **단순성**: 특별한 예외 처리가 없어 코드가 더 간단해짐
3. **안정성**: 전역 redirect에서 로그인 체크가 먼저 이루어지고, 그 다음 로컬 redirect가 실행되어 더 안정적
4. **유지보수성**: 코드 구조가 일관되어 유지보수가 쉬움

이 방법을 통해 새로고침 시에도 마이페이지 경로가 유지되도록 보장할 수 있습니다.

