# `/mypage/reviewer` 새로고침 시 홈으로 이동하는 문제 분석 보고서

**작성일**: 2025-11-21  
**문제**: `http://localhost:3001/mypage/reviewer`에서 새로고침 시 홈(`/home`)으로 이동

---

## 🔍 문제 분석

### 현재 구현 코드

```dart
GoRoute(
  path: '/mypage/reviewer',
  name: 'mypage-reviewer',
  redirect: (context, state) {
    // 동기 처리 - await 사용 금지
    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;  // ⚠️ 문제 발생 지점
    
    if (user == null) {
      return '/login';
    }
    
    // 모든 로그인한 유저는 리뷰어 페이지 접근 가능
    return null; // 접근 허용
  },
  builder: (context, state) => const ReviewerMyPageScreen(),
),
```

### 문제 원인

#### 1. `AsyncValue.value`의 동작 방식

`currentUserProvider`는 `Future<app_user.User?>`를 반환하므로, `ref.read(currentUserProvider)`는 `AsyncValue<app_user.User?>`를 반환합니다.

`AsyncValue.value` getter의 동작:
- ✅ **`data` 상태**: 실제 값을 반환
- ❌ **`loading` 상태**: `null` 반환
- ❌ **`error` 상태**: `null` 반환

#### 2. 새로고침 시 발생하는 시나리오

1. **새로고침 발생** → 페이지가 다시 로드됨
2. **`currentUserProvider` 초기화** → `AsyncValue.loading()` 상태
3. **`/mypage/reviewer` redirect 실행** → `userAsync.value`는 `null` (로딩 중)
4. **`user == null` 체크** → `true`가 되어 `/login`으로 리다이렉트 시도
5. **전역 redirect 실행** → `await authService.currentUser`로 실제 사용자 확인
6. **사용자가 로그인되어 있음** → 전역 redirect가 `/home`으로 리다이렉트

#### 3. 전역 redirect의 영향

```dart
redirect: (context, state) async {
  // ...
  try {
    final user = await authService.currentUser;  // 비동기로 실제 사용자 확인
    final isLoggedIn = user != null;

    // 로그인되지 않은 상태에서 보호된 경로 접근 시 로그인 페이지로 리다이렉트
    if (!isLoggedIn && !isLoggingIn && !isLoading) {
      return '/login';
    }
    // ...
  }
}
```

전역 redirect는 비동기로 실제 사용자를 확인하므로, 로컬 redirect에서 `null`을 반환하면 전역 redirect가 실행되어 홈으로 이동할 수 있습니다.

---

## 🐛 근본 원인

### 문제점 1: `AsyncValue.value`의 한계

- 로딩 중일 때 `null`을 반환하여 로그인되지 않은 것으로 오인
- 에러 상태에서도 `null`을 반환하여 오류 처리 불가

### 문제점 2: 동기 처리와 비동기 상태의 불일치

- redirect 함수는 동기적으로 처리해야 하지만
- `currentUserProvider`는 비동기 상태(`AsyncValue`)를 반환
- 로딩 중 상태를 제대로 처리하지 못함

### 문제점 3: 전역 redirect와 로컬 redirect의 충돌

- 로컬 redirect에서 `/login`으로 리다이렉트 시도
- 전역 redirect가 먼저 실행되어 다른 경로로 리다이렉트

---

## ✅ 해결 방안

### 해결책 1: `AsyncValue.when()` 사용 (권장)

`AsyncValue`의 상태를 명시적으로 처리:

```dart
GoRoute(
  path: '/mypage/reviewer',
  name: 'mypage-reviewer',
  redirect: (context, state) {
    final userAsync = ref.read(currentUserProvider);
    
    return userAsync.when(
      data: (user) {
        if (user == null) {
          return '/login';
        }
        // 모든 로그인한 유저는 리뷰어 페이지 접근 가능
        return null; // 접근 허용
      },
      loading: () {
        // 로딩 중일 때는 리다이렉트하지 않음 (현재 경로 유지)
        // 또는 로딩 화면으로 이동
        return null; // 현재 경로 유지, builder에서 로딩 처리
      },
      error: (error, stackTrace) {
        // 에러 발생 시 로그인 페이지로 이동
        return '/login';
      },
    );
  },
  builder: (context, state) => const ReviewerMyPageScreen(),
),
```

**장점**:
- 로딩 상태를 명시적으로 처리
- 에러 상태도 처리 가능
- 상태별로 다른 동작 가능

**단점**:
- 로딩 중일 때 현재 경로를 유지하면 화면이 빈 상태일 수 있음

### 해결책 2: 로딩 중일 때 로딩 화면 표시

로딩 중일 때는 로딩 화면으로 이동:

```dart
GoRoute(
  path: '/mypage/reviewer',
  name: 'mypage-reviewer',
  redirect: (context, state) {
    final userAsync = ref.read(currentUserProvider);
    
    return userAsync.when(
      data: (user) {
        if (user == null) {
          return '/login';
        }
        return null; // 접근 허용
      },
      loading: () {
        // 로딩 중일 때는 로딩 화면으로 이동
        return '/loading';
      },
      error: (error, stackTrace) {
        return '/login';
      },
    );
  },
  builder: (context, state) => const ReviewerMyPageScreen(),
),
```

**장점**:
- 사용자에게 로딩 상태를 명확히 표시
- 일관된 사용자 경험

**단점**:
- 로딩 화면으로 이동했다가 다시 돌아와야 함

### 해결책 3: 전역 redirect에서 처리 (권장하지 않음)

전역 redirect에서 `/mypage/reviewer` 경로를 예외 처리:

```dart
redirect: (context, state) async {
  // ...
  // /mypage/reviewer는 로컬 redirect에서 처리하도록 예외
  if (state.matchedLocation == '/mypage/reviewer') {
    return null;
  }
  // ...
}
```

**단점**:
- 전역 redirect 로직이 복잡해짐
- 각 경로마다 예외 처리가 필요

---

## 🎯 권장 해결책

### 최종 권장: 해결책 1 + 로딩 상태 처리

로딩 중일 때는 현재 경로를 유지하되, builder에서 로딩 상태를 처리:

```dart
GoRoute(
  path: '/mypage/reviewer',
  name: 'mypage-reviewer',
  redirect: (context, state) {
    final userAsync = ref.read(currentUserProvider);
    
    return userAsync.when(
      data: (user) {
        if (user == null) {
          return '/login';
        }
        // 모든 로그인한 유저는 리뷰어 페이지 접근 가능
        return null; // 접근 허용
      },
      loading: () {
        // 로딩 중일 때는 현재 경로 유지
        // builder에서 AsyncValue를 watch하여 로딩 UI 표시
        return null;
      },
      error: (error, stackTrace) {
        // 에러 발생 시 로그인 페이지로 이동
        return '/login';
      },
    );
  },
  builder: (context, state) {
    // builder에서 currentUserProvider를 watch하여 로딩 상태 처리
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      data: (user) {
        if (user == null) {
          // 이 경우는 redirect에서 처리되므로 도달하지 않음
          return const Center(child: Text('로그인이 필요합니다'));
        }
        return const ReviewerMyPageScreen();
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Center(child: Text('오류가 발생했습니다')),
    );
  },
),
```

**장점**:
- 로딩 상태를 명확히 처리
- 사용자 경험 향상 (로딩 중에도 현재 경로 유지)
- 에러 처리 포함

---

## 📝 수정이 필요한 파일

1. **`lib/config/app_router.dart`**
   - `/mypage/reviewer` redirect 수정
   - `/mypage/advertiser` redirect 수정 (동일한 문제)
   - `/mypage` redirect 수정 (동일한 문제)

---

## 🔄 수정 후 예상 동작

### 새로고침 시나리오

1. **새로고침 발생** → 페이지가 다시 로드됨
2. **`currentUserProvider` 초기화** → `AsyncValue.loading()` 상태
3. **`/mypage/reviewer` redirect 실행** → `loading` 상태 감지
4. **`return null`** → 현재 경로 유지
5. **builder 실행** → `AsyncValue.when()`으로 로딩 UI 표시
6. **사용자 정보 로드 완료** → `data` 상태로 변경
7. **builder 재실행** → `ReviewerMyPageScreen` 표시

---

## ⚠️ 주의사항

1. **동기 처리 원칙 유지**: redirect 함수는 여전히 동기적으로 처리되지만, `AsyncValue.when()`을 사용하여 상태를 명시적으로 처리
2. **로딩 상태 처리**: 로딩 중일 때 사용자에게 적절한 피드백 제공
3. **에러 처리**: 에러 발생 시 적절한 처리 (로그인 페이지로 이동 등)

---

## 📊 영향도 분석

### 영향받는 경로

- `/mypage/reviewer` - 수정 필요
- `/mypage/advertiser` - 동일한 문제 발생 가능
- `/mypage` - 동일한 문제 발생 가능

### 테스트 시나리오

1. ✅ 로그인 상태에서 `/mypage/reviewer` 접근 → 정상 접근
2. ✅ 로그아웃 상태에서 `/mypage/reviewer` 접근 → `/login`으로 리다이렉트
3. ✅ 새로고침 시 → 로딩 UI 표시 후 정상 접근
4. ✅ 네트워크 에러 시 → 에러 처리

---

## ✅ 수정 완료

### 수정된 파일
- `lib/config/app_router.dart`

### 수정 내용

1. **`/mypage/reviewer` redirect 및 builder 수정**
   - `AsyncValue.value` 대신 `AsyncValue.when()` 사용
   - 로딩 상태 명시적 처리
   - builder에서 로딩 UI 표시
   - builder에서 user를 화면에 전달

2. **`/mypage/advertiser` redirect 및 builder 수정**
   - 동일한 패턴 적용
   - builder에서 user를 화면에 전달

3. **`/mypage` redirect 수정**
   - 동일한 패턴 적용

### 수정 후 동작

- ✅ 새로고침 시 로딩 UI 표시 후 정상 접근
- ✅ 로딩 중에도 현재 경로 유지
- ✅ 에러 발생 시 적절한 처리
- ✅ 사용자 정보가 로드되면 화면에 전달

### 수정된 코드 예시

```dart
GoRoute(
  path: '/mypage/reviewer',
  name: 'mypage-reviewer',
  redirect: (context, state) {
    final userAsync = ref.read(currentUserProvider);
    
    return userAsync.when(
      data: (user) {
        if (user == null) {
          return '/login';
        }
        return null; // 접근 허용
      },
      loading: () => null, // 현재 경로 유지
      error: (error, stackTrace) => '/login',
    );
  },
  builder: (context, state) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Center(child: Text('로그인이 필요합니다'));
        }
        return ReviewerMyPageScreen(user: user); // user 전달
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Center(child: Text('오류가 발생했습니다')),
    );
  },
),
```

---

## 🔧 추가 수정 사항

### 문제: `initialLocation`으로 인한 브라우저 URL 무시

`initialLocation: '/loading'`이 설정되어 있어서, 새로고침 시 브라우저 URL이 무시되고 항상 `/loading`으로 이동하는 문제가 발생했습니다.

### 해결책

1. **`initialLocation` 제거**: 브라우저 URL을 유지하도록 `initialLocation` 제거
2. **루트 경로만 `/loading`으로 리다이렉트**: 전역 redirect에서 루트 경로(`/`)일 때만 `/loading`으로 리다이렉트

```dart
return GoRouter(
  debugLogDiagnostics: true,
  // initialLocation 제거 - 브라우저 URL을 유지하도록 함
  refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
  redirect: (context, state) async {
    // ...
    // 루트 경로 접근 시 로딩 화면으로 이동 (초기 로딩 처리)
    if (isRoot) {
      return '/loading';
    }
    // ...
  },
);
```

### 전역 redirect에서 mypage 경로 예외 처리

전역 redirect가 `/mypage/reviewer`, `/mypage/advertiser` 등의 경로를 건드리지 않도록 예외 처리:

```dart
// 로컬 redirect에서 처리하는 경로들은 전역 redirect에서 건드리지 않음
final isMypageReviewer = state.matchedLocation == '/mypage/reviewer';
final isMypageAdvertiser = state.matchedLocation == '/mypage/advertiser';
final isMypage = state.matchedLocation == '/mypage';
final isMypageAdmin = state.matchedLocation.startsWith('/mypage/admin');

if (isMypageReviewer || isMypageAdvertiser || isMypage || isMypageAdmin) {
  return null; // 로컬 redirect에서 처리
}
```

---

**작성일**: 2025-11-21  
**버전**: 1.2 (추가 수정 완료)

