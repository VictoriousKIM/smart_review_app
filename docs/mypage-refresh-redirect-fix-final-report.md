# 마이페이지 새로고침 리다이렉트 문제 최종 해결 보고서

## 📋 개요

**작업 일시**: 2024년 (최종 수정 완료)  
**문제**: 리뷰어/광고주 마이페이지 새로고침 시 홈으로 리다이렉트되는 문제  
**최종 해결 방법**: 전역 redirect 특별 처리 + Builder 위젯 분리

## 🔴 문제 재발견

초기 수정 후에도 여전히 문제가 발생:
- ✅ 어드민: 새로고침 시 경로 유지 (정상)
- ❌ 리뷰어: 여전히 새로고침 시 홈으로 리다이렉트
- ❌ 광고주: 여전히 새로고침 시 홈으로 리다이렉트

## 🔍 근본 원인 분석

### 문제의 핵심

1. **Builder에서 `ref.watch()` 사용**
   - `ref.watch()`는 상태 변경 시 위젯을 재빌드
   - 재빌드 과정에서 GoRouter가 재평가될 수 있음
   - 어드민은 Builder가 단순하여 재평가가 발생하지 않음

2. **전역 redirect의 일반 처리**
   - 마이페이지 경로가 다른 경로와 동일하게 처리됨
   - 새로고침 시 재평가 과정에서 경로 변경 가능

## 🔧 최종 해결 방법

### 1. 전역 Redirect에서 마이페이지 특별 처리

**변경 전:**
```dart
redirect: (context, state) async {
  final matchedLocation = state.matchedLocation;
  final isLoggingIn = matchedLocation == '/login';
  final isRoot = matchedLocation == '/';
  
  final user = await authService.currentUser;
  final isLoggedIn = user != null;
  
  if (!isLoggedIn) {
    if (isLoggingIn) return null;
    return '/login';
  }
  
  if (isLoggedIn) {
    if (isLoggingIn || isRoot) return '/home';
  }
  
  return null;
},
```

**변경 후:**
```dart
redirect: (context, state) async {
  final matchedLocation = state.matchedLocation;
  final isLoggingIn = matchedLocation == '/login';
  final isRoot = matchedLocation == '/';
  final isMyPage = matchedLocation.startsWith('/mypage');

  // 1. 마이페이지 경로는 전역 redirect에서 특별 처리 (새로고침 시 경로 유지)
  // Builder에서 권한 체크를 수행하므로 여기서는 로그인 체크만
  if (isMyPage) {
    final user = await authService.currentUser;
    if (user == null) {
      // 비로그인 시에만 로그인으로 리다이렉트
      return '/login';
    }
    // 로그인 상태면 경로 유지 (null 반환)
    return null;
  }

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
    if (isLoggingIn || isRoot) return '/home';
  }

  return null;
},
```

**효과:**
- 마이페이지 경로는 전역 redirect에서 명시적으로 처리
- 로그인 상태면 경로 유지 (null 반환)
- 새로고침 시 경로가 변경되지 않음

### 2. Builder를 별도 위젯으로 분리

**변경 전:**
```dart
builder: (context, state) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    // ... 복잡한 로직
  );
},
```

**변경 후:**
```dart
// lib/widgets/mypage_route_wrapper.dart
class MyPageRouteWrapper extends ConsumerWidget {
  final String routeType; // 'reviewer' or 'advertiser'

  const MyPageRouteWrapper({
    super.key,
    required this.routeType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    // ... 로직
  }
}

// lib/config/app_router.dart
builder: (context, state) => const MyPageRouteWrapper(routeType: 'reviewer'),
```

**효과:**
- Builder가 단순해져서 GoRouter 재평가에 영향 감소
- `ref.watch()`가 위젯 내부에서만 사용되어 재평가 최소화
- 어드민과 유사한 구조 (단순 Builder)

## 📊 변경 사항 요약

### 변경된 파일

1. **lib/config/app_router.dart**
   - 전역 redirect에 마이페이지 특별 처리 추가
   - 리뷰어/광고주 마이페이지 Builder를 `MyPageRouteWrapper`로 변경

2. **lib/widgets/mypage_route_wrapper.dart** (신규)
   - 마이페이지 라우트 래퍼 위젯 생성
   - `ref.watch()` 로직을 위젯 내부로 이동

### 변경 전 vs 변경 후

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| **전역 redirect** | 마이페이지 일반 처리 | 마이페이지 특별 처리 |
| **Builder 구조** | 복잡한 로직 포함 | 단순 위젯 호출 |
| **ref.watch() 위치** | Builder 내부 | 별도 위젯 내부 |
| **재평가 영향** | 높음 | 낮음 |

## ✅ 예상 효과

1. **새로고침 시 경로 유지**
   - 전역 redirect에서 마이페이지 경로 명시적 처리
   - 로그인 상태면 경로 유지 보장

2. **재평가 최소화**
   - Builder 단순화로 재평가 영향 감소
   - `ref.watch()`가 위젯 내부에서만 사용

3. **일관성 유지**
   - 어드민과 유사한 구조 (단순 Builder)
   - 모든 마이페이지가 동일한 패턴

## 🧪 테스트 시나리오

### 테스트 1: 리뷰어 마이페이지 새로고침
1. 리뷰어 계정으로 로그인
2. `/mypage/reviewer` 접속
3. 브라우저 새로고침 (F5)
4. **예상 결과**: 경로 유지 및 화면 정상 표시

### 테스트 2: 광고주 마이페이지 새로고침
1. 광고주 계정으로 로그인
2. `/mypage/advertiser` 접속
3. 브라우저 새로고침 (F5)
4. **예상 결과**: 경로 유지 및 화면 정상 표시

### 테스트 3: 하위 경로 새로고침
1. `/mypage/reviewer/points` 접속
2. 브라우저 새로고침
3. **예상 결과**: 경로 유지

### 테스트 4: 어드민 마이페이지 (기존 동작 확인)
1. 어드민 계정으로 로그인
2. `/mypage/admin` 접속
3. 브라우저 새로고침
4. **예상 결과**: 기존과 동일하게 정상 작동

## 🔍 기술적 세부 사항

### 1. 전역 Redirect의 마이페이지 특별 처리

```dart
if (isMyPage) {
  final user = await authService.currentUser;
  if (user == null) {
    return '/login';
  }
  // 로그인 상태면 경로 유지
  return null;
}
```

**이유:**
- 마이페이지 경로를 명시적으로 처리하여 재평가 시 경로 변경 방지
- 로그인 상태면 항상 경로 유지 (null 반환)

### 2. Builder 위젯 분리

**장점:**
- Builder가 단순해져서 GoRouter 재평가에 영향 감소
- `ref.watch()`가 위젯 내부에서만 사용되어 재평가 최소화
- 코드 재사용성 향상

**구조:**
```
GoRoute Builder (단순)
  └─> MyPageRouteWrapper (복잡한 로직)
      └─> ReviewerMyPageScreen / AdvertiserMyPageScreen
```

## 📝 결론

### 해결 방법 요약

1. **전역 redirect 특별 처리**
   - 마이페이지 경로를 명시적으로 처리
   - 로그인 상태면 경로 유지 보장

2. **Builder 위젯 분리**
   - Builder 단순화
   - `ref.watch()` 재평가 영향 최소화

### 예상 결과

✅ **새로고침 시 경로 유지**
- 리뷰어/광고주 마이페이지 새로고침 시 경로 유지
- 어드민과 동일한 안정성

✅ **재평가 최소화**
- Builder 단순화로 재평가 영향 감소
- 성능 개선

✅ **코드 일관성**
- 모든 마이페이지가 유사한 구조
- 유지보수 용이

---

**작성자**: AI Assistant  
**작성 일시**: 2024년  
**버전**: 2.0 (최종 수정)  
**상태**: ✅ 구현 완료, 테스트 대기

