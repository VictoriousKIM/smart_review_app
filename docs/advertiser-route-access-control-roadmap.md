# 광고주/리뷰어 라우트 접근 제어 개선 로드맵

## 🎯 핵심 개선사항 요약

### ✅ 주요 개선 포인트

1. **동기 처리 보장**: redirect 함수는 반드시 동기적으로 처리 (비동기 DB 호출 금지)
2. **비즈니스 로직 반영**: 모든 유저는 리뷰어, 광고주는 사업자 인증한 owner/manager만
3. **기존 로직 활용**: User 모델의 `companyRole` 필드 직접 확인

### 📌 비즈니스 로직 정리

- **모든 유저는 기본적으로 리뷰어**: 리뷰어 페이지는 접근 제어 불필요
- **광고주는 사업자 인증한 owner/manager만**: 광고주 페이지는 접근 제어 필요
- **광고주도 리뷰어 기능 사용 가능**: 광고주는 리뷰어 페이지와 광고주 페이지 모두 접근 가능

---

## 📋 문제 분석

### 현재 문제점

1. **직접 URL 접근 가능**
   - 광고주가 아닌 사용자(일반 리뷰어)가 `/mypage/advertiser` URL을 직접 입력하면 접근 가능

2. **라우터 레벨 접근 제어 부재**
   - `/mypage` 경로에는 redirect가 있지만, 하위 경로(`/mypage/advertiser`)에는 redirect가 없음
   - 광고주 하위 경로들(`/mypage/advertiser/*`)에도 접근 제어가 없음

3. **기존 `/mypage` redirect 로직의 문제**
   - `user.companyId != null`로 판단하는데, 이건 `companyRole`이 'reviewer'일 수도 있음
   - 비동기로 `await authService.currentUser`를 호출하고 있어서 성능 문제

---

## 🎯 해결 목표

1. **라우터 레벨 접근 제어 구현**
   - 광고주 전용 경로에 접근 제어 추가 (owner/manager만 접근)
   - 리뷰어 경로는 모든 유저 접근 가능 (접근 제어 불필요)
   - 관리자도 접근할 수 있도록 허용

2. **기존 로직 활용**
   - User 모델에 `isAdvertiser` getter 추가 (기존 `companyRole` 필드 활용)
   - 기존 `currentUserProvider` 활용하여 동기 처리

---

## ⚠️ 중요: 성능 및 아키텍처 고려사항

### 🚨 핵심 원칙

1. **redirect는 반드시 동기(Synchronous)적으로 처리**
   - redirect 함수 내부에서 비동기 DB 호출(`await`)을 절대 사용하지 않음
   - Navigation Blocking을 방지하여 사용자 경험 보호
   - 기존 `currentUserProvider`를 활용하여 이미 로드된 User 객체 사용

2. **무한 리다이렉트 방지**
   - 모든 유저는 리뷰어이므로 리뷰어 페이지는 항상 접근 가능
   - 광고주가 아닌 경우만 리뷰어 페이지로 리다이렉트 (단방향)
   - 무한 리다이렉트 위험 없음

---

## 📝 구현 계획

### Phase 0: User 모델에 getter 추가 (필수)

#### 0.1 User 모델에 계산된 getter 추가

**파일**: `lib/models/user.dart`

**변경 사항**:
- `isAdvertiser` getter 추가 (기존 `companyRole` 필드 활용)
- `isReviewer` getter 추가 (항상 true, 모든 유저는 리뷰어)
- **필드 추가 없이 기존 필드만 활용**

**구현 코드**:
```dart
class User {
  // ... 기존 필드들 (companyId, companyRole 이미 존재)
  
  /// 광고주 여부 확인 (동기 처리)
  /// companyRole이 'owner' 또는 'manager'인 경우 true
  bool get isAdvertiser {
    return companyRole == CompanyRole.owner || 
           companyRole == CompanyRole.manager;
  }
  
  /// 리뷰어 여부 확인 (동기 처리)
  /// 모든 유저는 기본적으로 리뷰어
  bool get isReviewer => true;
}
```

**장점**:
- 코드 가독성 향상: `user.isAdvertiser`가 `user.companyRole == CompanyRole.owner || user.companyRole == CompanyRole.manager`보다 명확
- 재사용성: 여러 곳에서 동일한 로직 사용 시 중복 제거
- 유지보수성: 로직 변경 시 한 곳만 수정

---

### Phase 1: 핵심 라우트 접근 제어 (필수)

#### 1.1 `/mypage/advertiser` 경로 접근 제어

**파일**: `lib/config/app_router.dart`

**구현 코드**:
```dart
GoRoute(
  path: '/mypage/advertiser',
  name: 'mypage-advertiser',
  redirect: (context, state) {
    // 동기 처리 - await 사용 금지
    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    
    if (user == null) {
      return '/login';
    }
    
    // 관리자는 접근 가능
    if (user.userType == app_user.UserType.admin) {
      return null; // 접근 허용
    }
    
    // User 모델의 isAdvertiser getter 사용 (가독성 향상)
    if (user.isAdvertiser) {
      return null; // 접근 허용
    }
    
    // 광고주가 아닌 경우 리뷰어 페이지로 리다이렉트
    return '/mypage/reviewer';
  },
  builder: (context, state) => const AdvertiserMyPageScreen(),
),
```

#### 1.2 `/mypage/reviewer` 경로 접근 제어

**파일**: `lib/config/app_router.dart`

**구현 코드**:
```dart
GoRoute(
  path: '/mypage/reviewer',
  name: 'mypage-reviewer',
  redirect: (context, state) {
    // 동기 처리 - await 사용 금지
    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    
    if (user == null) {
      return '/login';
    }
    
    // 모든 로그인한 유저는 리뷰어 페이지 접근 가능
    return null; // 접근 허용
  },
  builder: (context, state) => const ReviewerMyPageScreen(),
),
```

#### 1.3 기존 `/mypage` redirect 로직 수정

**파일**: `lib/config/app_router.dart`

**수정 전**:
```dart
redirect: (context, state) async {
  // ...
  // 광고주 인증 여부에 따라 적절한 페이지로 리다이렉트
  if (user.companyId != null) {  // ❌ 부정확
    return '/mypage/advertiser';
  } else {
    return '/mypage/reviewer';
  }
},
```

**수정 후**:
```dart
redirect: (context, state) {
  // 동기 처리 - await 제거
  final userAsync = ref.read(currentUserProvider);
  final user = userAsync.value;
  
  if (user == null) {
    return '/login';
  }
  
  // 관리자인 경우 어드민 대시보드로 리다이렉트
  if (user.userType == app_user.UserType.admin) {
    return '/mypage/admin';
  }
  
  // User 모델의 isAdvertiser getter 사용 (가독성 향상)
  if (user.isAdvertiser) {
    return '/mypage/advertiser';
  } else {
    return '/mypage/reviewer';
  }
},
```

---

### Phase 2: 광고주 하위 경로 접근 제어 (권장)

#### 2.1 광고주 하위 경로 그룹화

**파일**: `lib/config/app_router.dart`

**영향받는 경로**:
- `/mypage/advertiser/my-campaigns`
- `/mypage/advertiser/analytics`
- `/mypage/advertiser/participants`
- `/mypage/advertiser/managers`
- `/mypage/advertiser/penalties`
- `/mypage/advertiser/points`

**구현 방법**:
```dart
// 광고주 하위 경로를 하나의 GoRoute로 그룹화
GoRoute(
  path: '/mypage/advertiser',
  name: 'mypage-advertiser',
  redirect: (context, state) {
    // Phase 1.1과 동일한 접근 제어 로직
    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    
    if (user == null) {
      return '/login';
    }
    
    if (user.userType == app_user.UserType.admin) {
      return null;
    }
    
    // User 모델의 isAdvertiser getter 사용
    if (user.isAdvertiser) {
      return null;
    }
    
    return '/mypage/reviewer';
  },
  routes: [
    // 메인 광고주 페이지
    GoRoute(
      path: '',
      name: 'mypage-advertiser-main',
      builder: (context, state) => const AdvertiserMyPageScreen(),
    ),
    // 하위 경로들
    GoRoute(
      path: 'my-campaigns',
      name: 'advertiser-my-campaigns',
      builder: (context, state) {
        final initialTab = state.uri.queryParameters['tab'];
        return AdvertiserMyCampaignsScreen(initialTab: initialTab);
      },
    ),
    // ... 나머지 하위 경로들
  ],
),
```

---

## 🧪 테스트 시나리오

### 시나리오 1: 광고주가 아닌 사용자가 광고주 페이지 접근
1. 일반 리뷰어 계정으로 로그인 (사업자 인증 안 함)
2. 브라우저에서 `/mypage/advertiser` 직접 입력
3. **예상 결과**: `/mypage/reviewer`로 자동 리다이렉트

### 시나리오 2: 광고주가 리뷰어 페이지 접근
1. 광고주 계정으로 로그인 (owner 또는 manager)
2. 브라우저에서 `/mypage/reviewer` 직접 입력
3. **예상 결과**: 정상적으로 페이지 접근 가능 (모든 유저는 리뷰어)

### 시나리오 3: 관리자가 광고주/리뷰어 페이지 접근
1. 관리자 계정으로 로그인
2. 브라우저에서 `/mypage/advertiser` 또는 `/mypage/reviewer` 직접 입력
3. **예상 결과**: 정상적으로 페이지 접근 가능

### 시나리오 4: 로그인하지 않은 사용자가 접근
1. 로그아웃 상태
2. 브라우저에서 `/mypage/advertiser` 또는 `/mypage/reviewer` 직접 입력
3. **예상 결과**: `/login`으로 자동 리다이렉트

### 시나리오 5: 광고주 하위 경로 접근
1. 일반 리뷰어 계정으로 로그인 (사업자 인증 안 함)
2. 브라우저에서 `/mypage/advertiser/my-campaigns` 직접 입력
3. **예상 결과**: `/mypage/reviewer`로 자동 리다이렉트

---

## ✅ 체크리스트

### Phase 0 (필수)
- [ ] User 모델에 `isAdvertiser`, `isReviewer` getter 추가
- [ ] 테스트 완료

### Phase 1 (필수)
- [ ] `/mypage/advertiser` redirect 구현 (동기 처리, `user.isAdvertiser` getter 사용)
- [ ] `/mypage/reviewer` redirect 구현 (로그인 체크만, 모든 유저 접근 가능)
- [ ] 기존 `/mypage` redirect 로직 수정 (`companyId != null` 대신 `user.isAdvertiser` getter 사용)
- [ ] 테스트 완료

### Phase 2 (권장)
- [ ] 광고주 하위 경로 그룹화
- [ ] 부모 경로에 접근 제어 적용
- [ ] 테스트 완료

---

## 📚 참고 자료

- [GoRouter 공식 문서](https://pub.dev/documentation/go_router/latest/)
- `lib/models/user.dart` - User 모델 (companyId, companyRole 필드 이미 존재)
- `lib/providers/auth_provider.dart` - currentUserProvider (기존 Provider 활용)
- `lib/services/auth_service.dart` - get_user_profile_safe RPC 호출 (companyRole 이미 로드)
- `lib/config/app_router.dart` - 현재 라우터 설정

---

## 📝 수정 이력

### 버전 3.0 (2025-11-21)
- **문서 간소화 및 핵심만 정리**
  - Phase 0 추가: User 모델에 getter 추가 (코드 가독성 및 재사용성 향상)
  - Phase 3-10 제거 (선택사항이므로 필요 시 추가)
  - 추천 방법(`isAdvertiser` getter 사용)으로 통일
  - 중복 설명 제거, 가시성 향상

### 버전 2.3 (2025-11-21)
- 기존 로직 분석 및 활용

### 버전 2.2 (2025-11-21)
- 비즈니스 로직 정확성 개선

### 버전 2.1 (2025-11-21)
- 성능 및 아키텍처 개선사항 반영

---

**작성일**: 2025-11-21  
**작성자**: 개발팀  
**버전**: 3.0 (문서 간소화 및 핵심 정리)
