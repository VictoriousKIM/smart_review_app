# `/mypage/reviewer` 새로고침 시 홈으로 이동하는 문제 해결 로드맵

**작성일**: 2025-11-21  
**문제**: 새로고침 시 `/mypage/reviewer` → `/loading` → `/home`으로 리다이렉트됨

---

## 🔍 문제 분석

### 로그 분석

```
[GoRouter] setting initial location null
[GoRouter] redirecting to RouteMatchList#e50d8(uri: /loading, ...)
[GoRouter] going to /home
```

### 문제 시나리오

1. **새로고침 발생** → 브라우저 URL: `/mypage/reviewer`
2. **GoRouter 초기화** → `initialLocation: null` (브라우저 URL 사용)
3. **전역 redirect 실행** → `/loading`으로 리다이렉트 ❌
4. **LoadingScreen 실행** → 사용자 확인 후 `/home`으로 리다이렉트 ❌

### 근본 원인

#### 1. 전역 redirect가 `/loading`으로 리다이렉트하는 이유

현재 전역 redirect 로직:
- 루트 경로(`/`)일 때만 `/loading`으로 리다이렉트하도록 되어 있음
- 하지만 새로고침 시 `/mypage/reviewer`에서도 `/loading`으로 가는 것으로 보아:
  - **가설 1**: 전역 redirect가 로컬 redirect보다 먼저 실행되어 예외 처리가 작동하지 않음
  - **가설 2**: 새로고침 시 `state.matchedLocation`이 예상과 다르게 동작
  - **가설 3**: 다른 경로에서 `/loading`으로 리다이렉트하는 로직이 있음

#### 2. LoadingScreen이 원래 경로를 기억하지 못함

`LoadingScreen`의 현재 로직:
```dart
// 인증 상태에 따라 적절한 페이지로 리다이렉트
if (user != null) {
  context.go('/home');  // ❌ 항상 /home으로 이동
} else {
  context.go('/login');
}
```

**문제점**:
- 원래 가려던 경로(`/mypage/reviewer`)를 기억하지 못함
- 항상 `/home`으로 리다이렉트함

---

## 🎯 해결 방안

### 전략 1: LoadingScreen 제거 + 전역 redirect에서 직접 처리 (권장)

**장점**:
- 중간 단계(`/loading`) 제거로 리다이렉트 체인 단순화
- 원래 경로 유지 가능
- 코드 단순화

**단점**:
- 전역 redirect 로직이 복잡해질 수 있음

### 전략 2: LoadingScreen이 원래 경로를 기억하도록 수정

**장점**:
- 기존 구조 유지
- 로딩 화면 표시 가능

**단점**:
- 추가 상태 관리 필요
- 리다이렉트 체인이 여전히 존재

### 전략 3: 전역 redirect에서 로컬 redirect 경로 완전히 제외

**장점**:
- 로컬 redirect가 독립적으로 작동
- 전역 redirect 간섭 최소화

**단점**:
- 전역 redirect 로직이 복잡해질 수 있음

---

## 📋 권장 해결 로드맵 (전략 1 + 전략 3 조합)

### Phase 1: 전역 redirect 로직 개선

**목표**: 로컬 redirect가 처리하는 경로는 전역 redirect에서 완전히 제외

**작업 내용**:
1. 전역 redirect에서 로컬 redirect 경로 체크를 가장 먼저 수행
2. 로컬 redirect 경로일 경우 즉시 `return null`
3. 로딩 상태 확인을 전역 redirect에서 직접 처리

**수정 위치**: `lib/config/app_router.dart` - 전역 redirect 함수

**예상 코드**:
```dart
redirect: (context, state) async {
  final matchedLocation = state.matchedLocation;
  
  // 1. 로컬 redirect에서 처리하는 경로들은 가장 먼저 체크
  final isMypageReviewer = matchedLocation == '/mypage/reviewer';
  final isMypageAdvertiser = matchedLocation == '/mypage/advertiser';
  final isMypage = matchedLocation == '/mypage';
  final isMypageAdmin = matchedLocation.startsWith('/mypage/admin');
  
  if (isMypageReviewer || isMypageAdvertiser || isMypage || isMypageAdmin) {
    return null; // 로컬 redirect에서 처리 - 전역 redirect 개입 금지
  }
  
  // 2. 로딩 페이지는 항상 허용
  if (matchedLocation == '/loading') {
    return null;
  }
  
  // 3. 나머지 경로에 대한 전역 redirect 로직
  // ...
}
```

### Phase 2: LoadingScreen 제거 또는 수정

**목표**: 원래 경로를 유지하도록 수정

**옵션 A: LoadingScreen 제거 (권장)**
- 전역 redirect에서 직접 인증 상태 확인
- 로딩 중일 때는 builder에서 로딩 UI 표시

**옵션 B: LoadingScreen이 원래 경로 기억**
- `state.uri` 또는 `state.fullPath`를 사용하여 원래 경로 저장
- 인증 확인 후 원래 경로로 리다이렉트

**작업 내용**:
1. `LoadingScreen` 수정 또는 제거
2. 전역 redirect에서 로딩 상태 처리

**수정 위치**: 
- `lib/widgets/loading_screen.dart` (수정 또는 제거)
- `lib/config/app_router.dart` (전역 redirect 수정)

### Phase 3: 로컬 redirect 로직 검증

**목표**: 로컬 redirect가 제대로 작동하는지 확인

**작업 내용**:
1. `/mypage/reviewer` redirect 로직 검증
2. `/mypage/advertiser` redirect 로직 검증
3. 로딩 상태 처리 확인

**검증 항목**:
- ✅ 로딩 중일 때 현재 경로 유지
- ✅ 사용자 정보 로드 후 접근 허용
- ✅ 로그인되지 않은 경우 `/login`으로 리다이렉트

### Phase 4: 테스트 및 검증

**목표**: 모든 시나리오에서 정상 작동 확인

**테스트 시나리오**:
1. ✅ 로그인 상태에서 `/mypage/reviewer` 새로고침 → `/mypage/reviewer` 유지
2. ✅ 로그인 상태에서 `/mypage/advertiser` 새로고침 → `/mypage/advertiser` 유지
3. ✅ 로그아웃 상태에서 `/mypage/reviewer` 접근 → `/login`으로 리다이렉트
4. ✅ 루트 경로(`/`) 접근 → 적절한 페이지로 리다이렉트
5. ✅ 직접 URL 입력 → 정상 작동

---

## 🔧 상세 구현 계획

### Phase 1: 전역 redirect 로직 개선

#### 1.1 로컬 redirect 경로 체크를 최우선으로 이동

```dart
redirect: (context, state) async {
  final matchedLocation = state.matchedLocation;
  
  // ⭐ 최우선: 로컬 redirect에서 처리하는 경로는 전역 redirect에서 건드리지 않음
  if (matchedLocation == '/mypage/reviewer' ||
      matchedLocation == '/mypage/advertiser' ||
      matchedLocation == '/mypage' ||
      matchedLocation.startsWith('/mypage/admin')) {
    return null; // 로컬 redirect에서 처리
  }
  
  // 로딩 페이지는 항상 허용
  if (matchedLocation == '/loading') {
    return null;
  }
  
  // 나머지 로직...
}
```

#### 1.2 전역 redirect에서 로딩 상태 직접 처리

로컬 redirect 경로가 아닌 경우에만 전역 redirect에서 인증 상태 확인:

```dart
try {
  final user = await authService.currentUser;
  final isLoggedIn = user != null;
  
  // 루트 경로만 /loading으로 리다이렉트
  if (matchedLocation == '/') {
    return '/loading';
  }
  
  // 로그인되지 않은 경우
  if (!isLoggedIn && matchedLocation != '/login') {
    return '/login';
  }
  
  // 로그인된 상태에서 로그인 페이지 접근
  if (isLoggedIn && matchedLocation == '/login') {
    return '/home';
  }
} catch (e) {
  // 에러 처리
}
```

### Phase 2: LoadingScreen 수정

#### 옵션 A: LoadingScreen 제거 (권장)

전역 redirect에서 직접 처리:

```dart
// /loading 경로 제거 또는 단순화
GoRoute(
  path: '/loading',
  name: 'loading',
  builder: (context, state) {
    // 전역 redirect에서 이미 인증 상태 확인 후 리다이렉트
    // 여기 도달하는 경우는 거의 없음
    return const Center(child: CircularProgressIndicator());
  },
),
```

#### 옵션 B: LoadingScreen이 원래 경로 기억

```dart
class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  String? _originalPath; // 원래 경로 저장
  
  @override
  void initState() {
    super.initState();
    // 원래 경로 저장 (state.uri 또는 다른 방법)
    final router = GoRouter.of(context);
    _originalPath = router.routerDelegate.currentConfiguration.uri.path;
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _checkAuthAndRedirect();
      }
    });
  }
  
  Future<void> _checkAuthAndRedirect() async {
    // ...
    if (user != null) {
      // 원래 경로로 리다이렉트 (또는 적절한 기본 경로)
      context.go(_originalPath ?? '/home');
    } else {
      context.go('/login');
    }
  }
}
```

**⚠️ 주의**: 옵션 B는 복잡하고, GoRouter의 상태 관리와 충돌할 수 있음. 옵션 A 권장.

### Phase 3: 로컬 redirect 로직 검증

현재 로컬 redirect 로직은 이미 `AsyncValue.when()`을 사용하여 로딩 상태를 처리하고 있음:

```dart
GoRoute(
  path: '/mypage/reviewer',
  redirect: (context, state) {
    final userAsync = ref.read(currentUserProvider);
    
    return userAsync.when(
      data: (user) {
        if (user == null) return '/login';
        return null; // 접근 허용
      },
      loading: () => null, // 현재 경로 유지
      error: (error, stackTrace) => '/login',
    );
  },
  builder: (context, state) {
    // 로딩 UI 표시
  },
),
```

**확인 사항**:
- ✅ 로딩 중일 때 `return null`로 현재 경로 유지
- ✅ builder에서 로딩 UI 표시
- ✅ 사용자 정보 로드 후 정상 접근

---

## 🚨 주의사항

### 1. GoRouter redirect 실행 순서

GoRouter의 redirect 실행 순서:
1. **전역 redirect** (GoRouter의 `redirect` 파라미터)
2. **로컬 redirect** (각 GoRoute의 `redirect` 파라미터)

따라서 전역 redirect에서 로컬 redirect 경로를 건드리지 않도록 **가장 먼저** 체크해야 함.

### 2. AsyncValue.when() 사용

로컬 redirect에서 `AsyncValue.value` 대신 `AsyncValue.when()`을 사용하여:
- 로딩 상태 명시적 처리
- 에러 상태 처리
- 현재 경로 유지

### 3. 브라우저 URL 유지

새로고침 시 브라우저 URL을 유지하려면:
- `initialLocation` 제거 (이미 완료)
- 전역 redirect에서 원래 경로 보존

---

## 📊 예상 결과

### 수정 전
```
새로고침 (/mypage/reviewer)
  → 전역 redirect: /loading
  → LoadingScreen: /home
  ❌ 원래 경로 손실
```

### 수정 후
```
새로고침 (/mypage/reviewer)
  → 전역 redirect: null (로컬 redirect에서 처리)
  → 로컬 redirect: null (로딩 중, 현재 경로 유지)
  → builder: 로딩 UI 표시
  → 사용자 정보 로드 완료
  → builder: ReviewerMyPageScreen 표시
  ✅ 원래 경로 유지
```

---

## ✅ 체크리스트

### Phase 1: 전역 redirect 로직 개선
- [ ] 로컬 redirect 경로 체크를 최우선으로 이동
- [ ] 전역 redirect에서 로컬 redirect 경로 완전히 제외
- [ ] 루트 경로(`/`)만 `/loading`으로 리다이렉트

### Phase 2: LoadingScreen 수정
- [ ] LoadingScreen 제거 또는 수정
- [ ] 전역 redirect에서 로딩 상태 직접 처리

### Phase 3: 로컬 redirect 로직 검증
- [ ] `/mypage/reviewer` redirect 로직 확인
- [ ] `/mypage/advertiser` redirect 로직 확인
- [ ] 로딩 상태 처리 확인

### Phase 4: 테스트 및 검증
- [ ] 로그인 상태에서 `/mypage/reviewer` 새로고침 테스트
- [ ] 로그인 상태에서 `/mypage/advertiser` 새로고침 테스트
- [ ] 로그아웃 상태에서 접근 테스트
- [ ] 루트 경로 접근 테스트
- [ ] 직접 URL 입력 테스트

---

**작성일**: 2025-11-21  
**버전**: 1.0

