# 광고주/리뷰어 라우트 접근 제어 개선 로드맵

## 🎯 핵심 개선사항 요약

이 문서는 실무적인 관점에서 성능, 사용자 경험, 아키텍처를 고려하여 작성되었습니다.

### ✅ 주요 개선 포인트

1. **동기 처리 보장**: redirect 함수는 반드시 동기적으로 처리 (비동기 DB 호출 금지)
2. **무한 리다이렉트 방지**: Fallback 경로(`/home`) 추가로 안전장치 구현
3. **Riverpod Provider 활용**: static Map 캐싱 제거, 상태 관리 자동화
4. **라우터 레벨 방어 강화**: 화면 레벨 체크 제거, 라우터 가드에 집중
5. **Enum 및 ShellRoute 활용**: 타입 안정성 및 구조적 개선

### 📊 예상 효과

- **성능**: Navigation Blocking 제거로 즉각적인 화면 전환
- **사용자 경험**: 깜빡임 현상 제거, 부드러운 네비게이션
- **유지보수성**: 중앙 집중식 상태 관리, 코드 중복 제거
- **안정성**: 무한 리다이렉트 방지, 메모리 누수 방지

---

## 📋 문제 분석

### 현재 문제점

1. **직접 URL 접근 가능**
   - 광고주가 아닌 사용자가 `/mypage/advertiser` URL을 직접 입력하면 접근 가능
   - 리뷰어가 아닌 사용자가 `/mypage/reviewer` URL을 직접 입력하면 접근 가능

2. **라우터 레벨 접근 제어 부재**
   - `/mypage` 경로에는 redirect가 있지만, 하위 경로(`/mypage/advertiser`, `/mypage/reviewer`)에는 redirect가 없음
   - 광고주 하위 경로들(`/mypage/advertiser/*`)에도 접근 제어가 없음

3. **일관성 없는 권한 체크**
   - 관리자 페이지는 화면 레벨에서 권한 체크를 하고 있음
   - 광고주/리뷰어 페이지는 화면 레벨 권한 체크가 없음

### 현재 코드 구조

```dart
// app_router.dart
GoRoute(
  path: '/mypage/advertiser',
  name: 'mypage-advertiser',
  builder: (context, state) => const AdvertiserMyPageScreen(), // redirect 없음
),
```

---

## 🎯 해결 목표

1. **라우터 레벨 접근 제어 구현**
   - 광고주 전용 경로에 접근 제어 추가
   - 리뷰어 전용 경로에 접근 제어 추가
   - 관리자도 접근할 수 있도록 허용 (선택사항)

2. **일관성 있는 권한 체크**
   - 모든 보호된 경로에 동일한 접근 제어 패턴 적용
   - UserTypeHelper를 사용하여 사용자 타입 확인

3. **사용자 경험 개선**
   - 권한이 없는 사용자에게 적절한 리다이렉트
   - 명확한 오류 메시지 제공

---

## ⚠️ 중요: 성능 및 아키텍처 고려사항

### 🚨 핵심 원칙

1. **redirect는 반드시 동기(Synchronous)적으로 처리**
   - redirect 함수 내부에서 비동기 DB 호출(`await`)을 절대 사용하지 않음
   - Navigation Blocking을 방지하여 사용자 경험 보호
   - 모든 권한 정보는 앱 시작 시 Provider에 미리 로드

2. **무한 리다이렉트 방지**
   - 상호 리다이렉트(Reviewer ↔ Advertiser) 대신 Fallback 경로 사용
   - 권한이 명확하지 않은 경우 `/home` 또는 `/unauthorized`로 이동

3. **Riverpod Provider 기반 상태 관리**
   - static Map 캐싱 대신 Riverpod Provider 활용
   - 상태 동기화 및 메모리 관리 자동화

---

## 📝 구현 계획

### Phase 0: 사용자 권한 정보 Provider 구축 (우선순위: 최우선)

#### 0.1 User 모델 확장

**파일**: `lib/models/user.dart`

**변경 사항**:
- User 모델에 `isAdvertiser`, `isReviewer` 필드 추가
- 로그인 시 한 번에 모든 권한 정보 로드

**구현 코드**:
```dart
class User {
  // ... 기존 필드들
  final bool isAdvertiser;  // 추가
  final bool isReviewer;    // 추가
  
  User({
    // ... 기존 파라미터들
    required this.isAdvertiser,
    required this.isReviewer,
  });
  
  factory User.fromDatabaseProfile(
    Map<String, dynamic> profileData,
    supabase.User supabaseUser,
  ) async {
    // 로그인 시 한 번에 권한 정보 조회
    final userId = supabaseUser.id;
    final companyRole = await CompanyUserService.getUserCompanyRole(userId);
    
    final isAdvertiser = companyRole == 'owner' || companyRole == 'manager';
    final isReviewer = companyRole == null || companyRole == 'reviewer';
    
    return User(
      // ... 기존 필드들
      isAdvertiser: isAdvertiser,
      isReviewer: isReviewer,
    );
  }
}
```

#### 0.2 UserRoleProvider 생성

**파일**: `lib/providers/user_role_provider.dart` (신규 생성)

**구현 코드**:
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/user.dart' as app_user;
import '../providers/auth_provider.dart';

part 'user_role_provider.g.dart';

/// 사용자 역할 정보 Provider
/// User Provider를 기반으로 역할 정보를 제공
@riverpod
class UserRole extends _$UserRole {
  @override
  UserRoleState build() {
    final user = ref.watch(currentUserProvider).value;
    
    if (user == null) {
      return const UserRoleState(
        isAdvertiser: false,
        isReviewer: false,
        isAdmin: false,
      );
    }
    
    return UserRoleState(
      isAdvertiser: user.isAdvertiser,
      isReviewer: user.isReviewer,
      isAdmin: user.userType == app_user.UserType.admin,
    );
  }
}

/// 사용자 역할 상태
class UserRoleState {
  final bool isAdvertiser;
  final bool isReviewer;
  final bool isAdmin;
  
  const UserRoleState({
    required this.isAdvertiser,
    required this.isReviewer,
    required this.isAdmin,
  });
  
  /// 권한이 명확히 정의되어 있는지 확인
  bool get hasDefinedRole => isAdvertiser || isReviewer || isAdmin;
}
```

---

### Phase 1: 핵심 라우트 접근 제어 (우선순위: 높음)

#### 1.1 `/mypage/advertiser` 경로 접근 제어

**파일**: `lib/config/app_router.dart`

**변경 사항**:
- `redirect` 함수 추가 (동기 처리)
- `UserRoleProvider`를 사용하여 메모리에서 즉시 확인
- 무한 리다이렉트 방지를 위한 Fallback 경로 추가

**구현 코드**:
```dart
GoRoute(
  path: '/mypage/advertiser',
  name: 'mypage-advertiser',
  redirect: (context, state) {
    // 동기 처리 - await 사용 금지
    final userRole = ref.read(userRoleProvider);
    
    // 로그인 체크
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      return '/login';
    }
    
    // 관리자는 접근 가능
    if (userRole.isAdmin) {
      return null; // 접근 허용
    }
    
    // 광고주가 아닌 경우
    if (!userRole.isAdvertiser) {
      // 권한이 명확하지 않은 경우 홈으로, 그 외는 리뷰어로
      if (!userRole.hasDefinedRole) {
        return '/home'; // Fallback: 무한 리다이렉트 방지
      }
      return '/mypage/reviewer';
    }
    
    return null; // 접근 허용
  },
  builder: (context, state) => const AdvertiserMyPageScreen(),
),
```

#### 1.2 `/mypage/reviewer` 경로 접근 제어

**파일**: `lib/config/app_router.dart`

**변경 사항**:
- `redirect` 함수 추가 (동기 처리)
- `UserRoleProvider`를 사용하여 메모리에서 즉시 확인
- 무한 리다이렉트 방지를 위한 Fallback 경로 추가

**구현 코드**:
```dart
GoRoute(
  path: '/mypage/reviewer',
  name: 'mypage-reviewer',
  redirect: (context, state) {
    // 동기 처리 - await 사용 금지
    final userRole = ref.read(userRoleProvider);
    
    // 로그인 체크
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      return '/login';
    }
    
    // 관리자는 접근 가능
    if (userRole.isAdmin) {
      return null; // 접근 허용
    }
    
    // 리뷰어가 아닌 경우
    if (!userRole.isReviewer) {
      // 권한이 명확하지 않은 경우 홈으로, 그 외는 광고주로
      if (!userRole.hasDefinedRole) {
        return '/home'; // Fallback: 무한 리다이렉트 방지
      }
      return '/mypage/advertiser';
    }
    
    return null; // 접근 허용
  },
  builder: (context, state) => const ReviewerMyPageScreen(),
),
```

---

### Phase 2: 광고주 하위 경로 접근 제어 (우선순위: 중간)

#### 2.1 광고주 하위 경로 그룹화

**파일**: `lib/config/app_router.dart`

**변경 사항**:
- 광고주 하위 경로들을 하나의 부모 경로로 그룹화
- 부모 경로에 접근 제어 추가

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
  redirect: (context, state) async {
    // 접근 제어 로직 (Phase 1.1과 동일)
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
      routes: [
        // ...
      ],
    ),
    // ...
  ],
),
```

---

### Phase 3: 리뷰어 하위 경로 접근 제어 (우선순위: 중간)

#### 3.1 리뷰어 하위 경로 그룹화

**파일**: `lib/config/app_router.dart`

**변경 사항**:
- 리뷰어 하위 경로들을 하나의 부모 경로로 그룹화
- 부모 경로에 접근 제어 추가

**영향받는 경로**:
- `/mypage/reviewer/my-campaigns`
- `/mypage/reviewer/reviews`
- `/mypage/reviewer/points`
- `/mypage/reviewer/sns`

**구현 방법**: Phase 2.1과 동일한 패턴 적용

---

### Phase 4: 접근 제어 헬퍼 함수 생성 (우선순위: 낮음)

#### 4.1 라우터 접근 제어 헬퍼 함수

**파일**: `lib/utils/route_access_helper.dart` (신규 생성)

**목적**:
- 라우터 접근 제어 로직을 재사용 가능한 함수로 추출
- 코드 중복 제거
- 유지보수성 향상
- **동기 처리 보장** (비동기 호출 금지)

**구현 코드**:
```dart
import '../providers/user_role_provider.dart';
import '../providers/auth_provider.dart';
import '../config/route_paths.dart';

class RouteAccessHelper {
  /// 광고주 경로 접근 권한 확인 (동기 처리)
  /// 
  /// 반환값:
  /// - null: 접근 허용
  /// - String: 리다이렉트할 경로
  static String? checkAdvertiserAccess(WidgetRef ref) {
    final userRole = ref.read(userRoleProvider);
    final user = ref.read(currentUserProvider).value;
    
    if (user == null) {
      return RoutePaths.login;
    }
    
    // 관리자는 접근 가능
    if (userRole.isAdmin) {
      return null;
    }
    
    // 광고주가 아닌 경우
    if (!userRole.isAdvertiser) {
      // 권한이 명확하지 않은 경우 홈으로
      if (!userRole.hasDefinedRole) {
        return RoutePaths.home; // Fallback
      }
      return RoutePaths.reviewer;
    }
    
    return null;
  }
  
  /// 리뷰어 경로 접근 권한 확인 (동기 처리)
  /// 
  /// 반환값:
  /// - null: 접근 허용
  /// - String: 리다이렉트할 경로
  static String? checkReviewerAccess(WidgetRef ref) {
    final userRole = ref.read(userRoleProvider);
    final user = ref.read(currentUserProvider).value;
    
    if (user == null) {
      return RoutePaths.login;
    }
    
    // 관리자는 접근 가능
    if (userRole.isAdmin) {
      return null;
    }
    
    // 리뷰어가 아닌 경우
    if (!userRole.isReviewer) {
      // 권한이 명확하지 않은 경우 홈으로
      if (!userRole.hasDefinedRole) {
        return RoutePaths.home; // Fallback
      }
      return RoutePaths.advertiser;
    }
    
    return null;
  }
  
  /// 관리자 경로 접근 권한 확인 (동기 처리)
  /// 
  /// 반환값:
  /// - null: 접근 허용
  /// - String: 리다이렉트할 경로
  static String? checkAdminAccess(WidgetRef ref) {
    final userRole = ref.read(userRoleProvider);
    final user = ref.read(currentUserProvider).value;
    
    if (user == null) {
      return RoutePaths.login;
    }
    
    if (!userRole.isAdmin) {
      // 관리자가 아닌 경우 사용자 타입에 따라 리다이렉트
      if (userRole.isAdvertiser) {
        return RoutePaths.advertiser;
      } else if (userRole.isReviewer) {
        return RoutePaths.reviewer;
      } else {
        return RoutePaths.home; // Fallback
      }
    }
    
    return null;
  }
}
```

**사용 예시**:
```dart
GoRoute(
  path: '/mypage/advertiser',
  name: 'mypage-advertiser',
  redirect: (context, state) {
    // 동기 처리 - await 없음
    return RouteAccessHelper.checkAdvertiserAccess(ref);
  },
  builder: (context, state) => const AdvertiserMyPageScreen(),
),
```

---

### Phase 5: 화면 레벨 권한 체크 (제거 권장)

#### 5.1 Phase 5 제거 이유

**문제점**:
- 라우터 레벨에서 이미 접근 제어가 완료되었는데 화면에서 다시 체크하는 것은 중복
- 사용자 경험 저하: CircularProgressIndicator가 잠깐 돌다가 튕겨 나가는 "깜빡임" 현상
- 코드 분산으로 유지보수 어려움

**결론**:
- **Phase 5는 제거하고 라우터 레벨의 방어 로직을 강화하는 데 집중**
- 라우터 가드(Guard)를 완벽하게 구현하여 화면까지 진입하지 못하도록 차단
- 정말 예외적인 상황(권한이 실시간으로 박탈된 경우)은 Global Error Handling으로 처리

**대안: Global Error Handling** (필요 시)
```dart
// lib/utils/global_error_handler.dart
class GlobalErrorHandler {
  static void handleUnauthorizedAccess(BuildContext context) {
    // 권한이 없는 접근 시도 시 처리
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('접근 권한이 없습니다'),
        backgroundColor: Colors.red,
      ),
    );
    context.go(RoutePaths.home);
  }
}
```

---

## 🔄 구현 순서

### 0단계: Phase 0 구현 (최우선 - 필수)
- [ ] User 모델에 `isAdvertiser`, `isReviewer` 필드 추가
- [ ] 로그인 시 권한 정보 한 번에 로드
- [ ] `UserRoleProvider` 생성 및 구현
- [ ] 테스트: 로그인 후 권한 정보가 Provider에 정상 로드되는지 확인

### 1단계: Phase 1 구현 (필수)
- [ ] `/mypage/advertiser` 경로에 redirect 추가 (동기 처리)
- [ ] `/mypage/reviewer` 경로에 redirect 추가 (동기 처리)
- [ ] Fallback 경로(`/home`) 추가로 무한 리다이렉트 방지
- [ ] 테스트: 광고주가 아닌 사용자가 `/mypage/advertiser` 접근 시도
- [ ] 테스트: 리뷰어가 아닌 사용자가 `/mypage/reviewer` 접근 시도
- [ ] 테스트: 권한이 없는 사용자(신규 가입 직후) 접근 시도

### 2단계: Phase 2 구현 (권장)
- [ ] 광고주 하위 경로 그룹화
- [ ] 부모 경로에 접근 제어 적용
- [ ] 테스트: 광고주 하위 경로 접근 제어 확인

### 3단계: Phase 3 구현 (권장)
- [ ] 리뷰어 하위 경로 그룹화
- [ ] 부모 경로에 접근 제어 적용
- [ ] 테스트: 리뷰어 하위 경로 접근 제어 확인

### 4단계: Phase 4 구현 (권장)
- [ ] `RouteAccessHelper` 클래스 생성 (동기 처리)
- [ ] 기존 redirect 로직을 헬퍼 함수로 리팩토링
- [ ] 테스트: 리팩토링 후 동작 확인

### 5단계: Phase 5 (제거)
- [ ] Phase 5는 제거 - 라우터 레벨 방어에 집중
- [ ] 필요 시 Global Error Handling만 추가

---

## 🧪 테스트 시나리오

### 시나리오 1: 광고주가 아닌 사용자가 광고주 페이지 접근
1. 리뷰어 계정으로 로그인
2. 브라우저에서 `/mypage/advertiser` 직접 입력
3. **예상 결과**: `/mypage/reviewer`로 자동 리다이렉트

### 시나리오 2: 리뷰어가 아닌 사용자가 리뷰어 페이지 접근
1. 광고주 계정으로 로그인
2. 브라우저에서 `/mypage/reviewer` 직접 입력
3. **예상 결과**: `/mypage/advertiser`로 자동 리다이렉트

### 시나리오 3: 관리자가 광고주/리뷰어 페이지 접근
1. 관리자 계정으로 로그인
2. 브라우저에서 `/mypage/advertiser` 또는 `/mypage/reviewer` 직접 입력
3. **예상 결과**: 정상적으로 페이지 접근 가능

### 시나리오 4: 로그인하지 않은 사용자가 접근
1. 로그아웃 상태
2. 브라우저에서 `/mypage/advertiser` 또는 `/mypage/reviewer` 직접 입력
3. **예상 결과**: `/login`으로 자동 리다이렉트

### 시나리오 5: 광고주 하위 경로 접근
1. 리뷰어 계정으로 로그인
2. 브라우저에서 `/mypage/advertiser/my-campaigns` 직접 입력
3. **예상 결과**: `/mypage/reviewer`로 자동 리다이렉트

---

## 📊 영향도 분석

### 영향받는 파일

1. **필수 변경 파일**
   - `lib/config/app_router.dart` - 라우터 설정 수정

2. **선택 변경 파일**
   - `lib/utils/route_access_helper.dart` - 신규 생성 (Phase 4)
   - `lib/screens/mypage/advertiser/advertiser_mypage_screen.dart` - 화면 레벨 체크 추가 (Phase 5)
   - `lib/screens/mypage/reviewer/reviewer_mypage_screen.dart` - 화면 레벨 체크 추가 (Phase 5)

### 영향받는 기능

- **라우팅**: 모든 마이페이지 관련 라우팅
- **사용자 경험**: 권한이 없는 사용자의 접근 시도 처리
- **보안**: 권한 없는 접근 방지

---

## ⚠️ 주의사항

1. **🚨 redirect는 반드시 동기 처리**
   - redirect 함수 내부에서 `await` 사용 절대 금지
   - 비동기 DB 호출은 Navigation Blocking을 유발하여 사용자 경험 저하
   - 모든 권한 정보는 앱 시작 시 Provider에 미리 로드

2. **🔄 무한 리다이렉트 방지**
   - 상호 리다이렉트(Reviewer ↔ Advertiser) 대신 Fallback 경로 사용
   - 권한이 명확하지 않은 경우 `/home` 또는 `/unauthorized`로 이동
   - `hasDefinedRole` 체크로 안전장치 추가

3. **💾 Riverpod Provider 활용**
   - static Map 캐싱 사용 금지 (메모리 누수 및 상태 동기화 문제)
   - Riverpod Provider의 자동 캐싱 및 상태 관리 활용
   - `ref.read`는 메모리에서 즉시 반환 (동기)

4. **🧩 화면 레벨 체크 제거**
   - Phase 5는 제거하고 라우터 레벨 방어에 집중
   - 이중 체크는 사용자 경험 저하 (깜빡임 현상)
   - 예외 상황은 Global Error Handling으로 처리

5. **관리자 접근**
   - 관리자는 모든 페이지에 접근 가능하도록 설계
   - 필요에 따라 관리자 접근 제한 가능

---

## 📚 참고 자료

- [GoRouter 공식 문서](https://pub.dev/documentation/go_router/latest/)
- `lib/utils/user_type_helper.dart` - 사용자 타입 확인 로직
- `lib/services/company_user_service.dart` - 회사 사용자 권한 체크
- `lib/config/app_router.dart` - 현재 라우터 설정

---

## ✅ 체크리스트

### Phase 0 (최우선 - 필수)
- [ ] User 모델 확장 (isAdvertiser, isReviewer 필드)
- [ ] UserRoleProvider 생성
- [ ] 로그인 시 권한 정보 로드
- [ ] 테스트 완료

### Phase 1 (필수)
- [ ] `/mypage/advertiser` redirect 구현 (동기 처리)
- [ ] `/mypage/reviewer` redirect 구현 (동기 처리)
- [ ] Fallback 경로 추가
- [ ] 테스트 완료

### Phase 2 (권장)
- [ ] 광고주 하위 경로 그룹화
- [ ] 접근 제어 적용
- [ ] 테스트 완료

### Phase 3 (권장)
- [ ] 리뷰어 하위 경로 그룹화
- [ ] 접근 제어 적용
- [ ] 테스트 완료

### Phase 4 (권장)
- [ ] RouteAccessHelper 생성 (동기 처리)
- [ ] 리팩토링 완료
- [ ] 테스트 완료

### Phase 5 (제거)
- [ ] Phase 5 제거 - 라우터 레벨 방어에 집중

---

## 🔧 라우터 전반 리팩토링 계획

### 현재 라우터 구조의 문제점

1. **코드 구조 문제**
   - 모든 라우트가 하나의 파일에 집중되어 있음 (457줄)
   - 라우트 그룹화가 명확하지 않음
   - 중복 코드 존재 (접근 제어 로직, 경로 문자열 등)

2. **유지보수성 문제**
   - 라우트 추가/수정 시 전체 파일을 수정해야 함
   - 경로 문자열이 하드코딩되어 있음
   - 라우트 이름과 경로의 일관성 부족

3. **성능 문제**
   - 불필요한 리다이렉트 발생 가능
   - 라우트 매칭 최적화 여지

4. **확장성 문제**
   - 새로운 라우트 그룹 추가 시 구조 변경 필요
   - 접근 제어 로직이 분산되어 있음

---

### Phase 6: 라우트 구조 개선 (우선순위: 중간)

#### 6.1 라우트 경로 상수 정의 (Enum 활용)

**파일**: `lib/config/route_paths.dart` (신규 생성)

**목적**:
- 모든 라우트 경로를 타입 안전하게 관리
- Enum 활용으로 컴파일 타임 체크
- 중앙 집중식 경로 관리

**구현 코드**:
```dart
/// 애플리케이션의 모든 라우트 경로를 정의하는 Enum
enum AppRoute {
  // 인증 관련
  login('/login'),
  loading('/loading'),
  root('/'),
  
  // 메인 페이지
  home('/home'),
  campaigns('/campaigns'),
  campaignsCreate('/campaigns/create'),
  guide('/guide'),
  
  // 마이페이지
  mypage('/mypage'),
  
  // 리뷰어 관련
  reviewer('/mypage/reviewer'),
  reviewerMyCampaigns('/mypage/reviewer/my-campaigns'),
  reviewerReviews('/mypage/reviewer/reviews'),
  reviewerPoints('/mypage/reviewer/points'),
  reviewerPointsRefund('/mypage/reviewer/points/refund'),
  reviewerSns('/mypage/reviewer/sns'),
  
  // 광고주 관련
  advertiser('/mypage/advertiser'),
  advertiserMyCampaigns('/mypage/advertiser/my-campaigns'),
  advertiserMyCampaignsCreate('/mypage/advertiser/my-campaigns/create'),
  advertiserAnalytics('/mypage/advertiser/analytics'),
  advertiserParticipants('/mypage/advertiser/participants'),
  advertiserManagers('/mypage/advertiser/managers'),
  advertiserPenalties('/mypage/advertiser/penalties'),
  advertiserPoints('/mypage/advertiser/points'),
  advertiserPointsCharge('/mypage/advertiser/points/charge'),
  advertiserPointsRefund('/mypage/advertiser/points/refund'),
  
  // 관리자 관련
  admin('/mypage/admin'),
  adminUsers('/mypage/admin/users'),
  adminCompanies('/mypage/admin/companies'),
  adminCampaigns('/mypage/admin/campaigns'),
  adminReviews('/mypage/admin/reviews'),
  adminPoints('/mypage/admin/points'),
  adminStatistics('/mypage/admin/statistics'),
  adminSettings('/mypage/admin/settings'),
  
  // 공통
  profile('/mypage/profile'),
  notices('/notices'),
  events('/events'),
  inquiry('/inquiry'),
  advertisementInquiry('/advertisement-inquiry'),
  notificationSettings('/settings/notifications'),
  accountDeletion('/account-deletion'),
  
  // Fallback
  unauthorized('/unauthorized');
  
  const AppRoute(this.path);
  final String path;
  
  /// 동적 경로 생성 헬퍼 메서드
  static String campaignDetail(String id) => '/campaigns/$id';
  static String reviewerPointsDetail(String id) => '/mypage/reviewer/points/$id';
  static String advertiserCampaignDetail(String id) => '/mypage/advertiser/my-campaigns/$id';
  static String advertiserPointsDetail(String id) => '/mypage/advertiser/points/$id';
}

/// 하위 호환성을 위한 RoutePaths 클래스 (기존 코드와의 호환)
class RoutePaths {
  // AppRoute의 path를 직접 참조
  static const String login = AppRoute.login.path;
  static const String loading = AppRoute.loading.path;
  static const String root = AppRoute.root.path;
  static const String home = AppRoute.home.path;
  // ... 나머지 경로들
}
```

#### 6.2 라우트 그룹별 파일 분리 (ShellRoute 활용)

**목적**:
- 라우트를 기능별로 분리하여 관리
- ShellRoute를 활용한 레이아웃 구조화
- 코드 가독성 및 유지보수성 향상

**파일 구조**:
```
lib/config/routes/
  ├── auth_routes.dart          # 인증 관련 라우트
  ├── main_routes.dart          # 메인 페이지 라우트
  ├── reviewer_routes.dart      # 리뷰어 관련 라우트 (ShellRoute 포함)
  ├── advertiser_routes.dart    # 광고주 관련 라우트 (ShellRoute 포함)
  ├── admin_routes.dart         # 관리자 관련 라우트 (ShellRoute 포함)
  └── common_routes.dart        # 공통 라우트
```

**예시: `lib/config/routes/reviewer_routes.dart`**:
```dart
import 'package:go_router/go_router.dart';
import '../../screens/mypage/reviewer/reviewer_mypage_screen.dart';
import '../../screens/mypage/reviewer/my_campaigns_screen.dart';
import '../../screens/mypage/reviewer/reviewer_reviews_screen.dart';
import '../../screens/mypage/common/points_screen.dart';
import '../../screens/mypage/common/point_refund_screen.dart';
import '../../screens/mypage/common/point_transaction_detail_screen.dart';
import '../../screens/mypage/reviewer/sns_connection_screen.dart';
import '../../widgets/reviewer_shell.dart'; // 리뷰어 전용 Shell
import '../route_paths.dart';
import '../../utils/route_access_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 리뷰어 관련 라우트 정의 (ShellRoute로 그룹화)
RouteBase getReviewerRoutes(WidgetRef ref) {
  return ShellRoute(
    // 리뷰어 전용 레이아웃 (BottomNavigationBar 등)
    builder: (context, state, child) => ReviewerShell(child: child),
    routes: [
      GoRoute(
        path: AppRoute.reviewer.path.replaceFirst('/mypage', ''),
        name: 'mypage-reviewer',
        redirect: (context, state) {
          // 동기 처리
          return RouteAccessHelper.checkReviewerAccess(ref);
        },
        builder: (context, state) => const ReviewerMyPageScreen(),
      ),
      GoRoute(
        path: AppRoute.reviewerMyCampaigns.path.replaceFirst('/mypage', ''),
        name: 'reviewer-my-campaigns',
        builder: (context, state) {
          final initialTab = state.uri.queryParameters['tab'];
          return MyCampaignsScreen(initialTab: initialTab);
        },
      ),
      // ... 나머지 리뷰어 라우트
    ],
  );
}
```

**ShellRoute 활용 예시: `lib/widgets/reviewer_shell.dart`**:
```dart
class ReviewerShell extends StatelessWidget {
  final Widget child;
  
  const ReviewerShell({required this.child});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: ReviewerBottomNav(), // 리뷰어 전용 네비게이션
    );
  }
}
```

#### 6.3 라우터 설정 통합

**파일**: `lib/config/app_router.dart` (수정)

**변경 사항**:
- 분리된 라우트 파일들을 import하여 통합
- 코드 길이 대폭 감소
- 구조 명확화

**구현 코드**:
```dart
import 'routes/auth_routes.dart';
import 'routes/main_routes.dart';
import 'routes/reviewer_routes.dart';
import 'routes/advertiser_routes.dart';
import 'routes/admin_routes.dart';
import 'routes/common_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  ref.keepAlive();

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: RoutePaths.loading,
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    redirect: (context, state) async {
      // 전역 redirect 로직 (기존과 동일)
    },
    routes: [
      // 인증 라우트
      ...getAuthRoutes(),
      
      // 메인 앱 라우트 (ShellRoute)
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // 메인 페이지
          ...getMainRoutes(),
          
          // 리뷰어 라우트
          ...getReviewerRoutes(ref),
          
          // 광고주 라우트
          ...getAdvertiserRoutes(ref),
          
          // 관리자 라우트
          ...getAdminRoutes(ref),
          
          // 공통 라우트
          ...getCommonRoutes(),
        ],
      ),
    ],
    errorBuilder: (context, state) => _buildErrorPage(context, state),
  );
});
```

---

### Phase 7: 접근 제어 통합 및 개선 (우선순위: 중간)

#### 7.1 관리자 라우트 접근 제어 추가

**현재 문제**:
- 관리자 라우트에 접근 제어가 없음
- 화면 레벨에서만 권한 체크

**해결 방법**:
- 모든 관리자 라우트에 redirect 추가
- `RouteAccessHelper.checkAdminAccess()` 사용

**구현 코드**:
```dart
// lib/config/routes/admin_routes.dart
GoRoute(
  path: RoutePaths.admin.replaceFirst('/mypage', ''),
  name: 'admin-dashboard',
  redirect: (context, state) async {
    final authService = ref.read(authServiceProvider);
    final user = await authService.currentUser;
    return await RouteAccessHelper.checkAdminAccess(ref, user);
  },
  builder: (context, state) => const AdminDashboardScreen(),
),
```

#### 7.2 접근 제어 로직 최적화

**목적**:
- Riverpod Provider 기반 상태 관리 활용
- static Map 캐싱 제거 (메모리 누수 및 상태 동기화 문제 해결)

**구현 방법**:
```dart
// Riverpod Provider를 활용한 자동 캐싱
// 별도의 static Map이 필요 없음 - Riverpod이 자동으로 관리

// lib/providers/user_role_provider.dart
@riverpod
class UserRole extends _$UserRole {
  @override
  UserRoleState build() {
    // Riverpod이 자동으로 캐싱 및 상태 관리
    // ref.watch를 통해 자동으로 업데이트 감지
    final user = ref.watch(currentUserProvider).value;
    
    if (user == null) {
      return const UserRoleState(
        isAdvertiser: false,
        isReviewer: false,
        isAdmin: false,
      );
    }
    
    // User 모델에 이미 isAdvertiser, isReviewer가 포함되어 있음
    // 추가 DB 조회 불필요
    return UserRoleState(
      isAdvertiser: user.isAdvertiser,
      isReviewer: user.isReviewer,
      isAdmin: user.userType == app_user.UserType.admin,
    );
  }
}

// RouteAccessHelper는 단순히 Provider를 읽기만 함
// static Map 캐싱 불필요 - Riverpod이 자동 처리
class RouteAccessHelper {
  static String? checkAdvertiserAccess(WidgetRef ref) {
    // ref.read는 이미 캐싱된 값을 즉시 반환 (동기)
    final userRole = ref.read(userRoleProvider);
    // ... 나머지 로직
  }
}
```

**장점**:
- 메모리 누수 방지: Riverpod이 자동으로 상태 관리
- 상태 동기화: 로그아웃 시 자동으로 상태 초기화
- 성능: ref.read는 메모리에서 즉시 반환 (동기)
- 유지보수: 중앙 집중식 상태 관리

---

### Phase 8: 에러 처리 개선 (우선순위: 낮음)

#### 8.1 에러 타입별 처리

**목적**:
- 더 명확한 에러 메시지
- 사용자 친화적인 에러 화면

**구현 코드**:
```dart
// lib/config/app_router.dart
errorBuilder: (context, state) {
  final error = state.error;
  
  // 404 에러
  if (error is GoException && error.type == GoExceptionType.missingLocation) {
    return _build404Page(context, state);
  }
  
  // 권한 에러
  if (error is UnauthorizedException) {
    return _buildUnauthorizedPage(context, state);
  }
  
  // 일반 에러
  return _buildErrorPage(context, state);
}

Widget _build404Page(BuildContext context, GoRouterState state) {
  return Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            '페이지를 찾을 수 없습니다',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '요청하신 경로: ${state.matchedLocation}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go(RoutePaths.home),
            child: const Text('홈으로 이동'),
          ),
        ],
      ),
    ),
  );
}

Widget _buildUnauthorizedPage(BuildContext context, GoRouterState state) {
  return Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            '접근 권한이 없습니다',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('이 페이지에 접근할 권한이 없습니다.'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go(RoutePaths.mypage),
            child: const Text('마이페이지로 이동'),
          ),
        ],
      ),
    ),
  );
}
```

#### 8.2 커스텀 예외 클래스

**파일**: `lib/utils/router_exceptions.dart` (신규 생성)

**구현 코드**:
```dart
/// 라우터 관련 커스텀 예외 클래스
class UnauthorizedException implements Exception {
  final String message;
  final String? redirectPath;
  
  UnauthorizedException({
    this.message = '접근 권한이 없습니다',
    this.redirectPath,
  });
  
  @override
  String toString() => message;
}

class RouteNotFoundException implements Exception {
  final String path;
  
  RouteNotFoundException(this.path);
  
  @override
  String toString() => '경로를 찾을 수 없습니다: $path';
}
```

---

### Phase 9: 성능 최적화 (우선순위: 낮음)

#### 9.1 라우트 매칭 최적화

**목적**:
- 불필요한 리다이렉트 방지
- 라우트 매칭 성능 향상

**구현 방법**:
- 정적 경로를 동적 경로보다 먼저 배치
- 자주 사용되는 경로를 상단에 배치
- 와일드카드 경로 최소화

#### 9.2 리다이렉트 최적화

**목적**:
- 중복 리다이렉트 방지
- 리다이렉트 체인 최소화

**구현 방법**:
```dart
// 리다이렉트 체인 감지 및 방지
class RedirectChainDetector {
  static final Set<String> _redirectHistory = {};
  
  static bool isInRedirectChain(String path) {
    if (_redirectHistory.contains(path)) {
      _redirectHistory.clear();
      return true; // 순환 리다이렉트 감지
    }
    _redirectHistory.add(path);
    return false;
  }
  
  static void clear() {
    _redirectHistory.clear();
  }
}
```

---

### Phase 10: 문서화 및 테스트 (우선순위: 낮음)

#### 10.1 라우트 문서화

**목적**:
- 라우트 구조 명확화
- 개발자 온보딩 용이

**구현 방법**:
- 각 라우트 파일에 주석 추가
- 라우트 다이어그램 생성
- 접근 제어 규칙 문서화

#### 10.2 라우트 테스트

**목적**:
- 라우트 동작 검증
- 리그레션 방지

**구현 방법**:
```dart
// test/routes/router_test.dart
void main() {
  group('Router Tests', () {
    test('광고주가 아닌 사용자는 광고주 페이지 접근 불가', () async {
      // 테스트 코드
    });
    
    test('관리자는 모든 페이지 접근 가능', () async {
      // 테스트 코드
    });
  });
}
```

---

## 📊 리팩토링 영향도 분석

### 코드 메트릭 개선 예상

| 항목 | 현재 | 리팩토링 후 | 개선율 |
|------|------|------------|--------|
| app_router.dart 라인 수 | 457줄 | ~150줄 | 67% 감소 |
| 파일 수 | 1개 | 7개 | 모듈화 |
| 중복 코드 | 높음 | 낮음 | 80% 감소 |
| 유지보수성 | 낮음 | 높음 | 향상 |

### 영향받는 파일

1. **신규 생성 파일**
   - `lib/config/route_paths.dart`
   - `lib/config/routes/auth_routes.dart`
   - `lib/config/routes/main_routes.dart`
   - `lib/config/routes/reviewer_routes.dart`
   - `lib/config/routes/advertiser_routes.dart`
   - `lib/config/routes/admin_routes.dart`
   - `lib/config/routes/common_routes.dart`
   - `lib/utils/router_exceptions.dart`

2. **수정 파일**
   - `lib/config/app_router.dart` - 대폭 간소화
   - `lib/utils/route_access_helper.dart` - 캐싱 추가

3. **영향받는 기능**
   - 모든 라우팅 로직
   - 접근 제어 로직
   - 에러 처리

---

## 🔄 통합 구현 순서

### Phase 1-5: 접근 제어 구현 (기존)
- [ ] Phase 1: 핵심 라우트 접근 제어
- [ ] Phase 2: 광고주 하위 경로 접근 제어
- [ ] Phase 3: 리뷰어 하위 경로 접근 제어
- [ ] Phase 4: 접근 제어 헬퍼 함수 생성
- [ ] Phase 5: 화면 레벨 권한 체크

### Phase 6-10: 리팩토링 (신규)
- [ ] Phase 6: 라우트 구조 개선
  - [ ] 6.1: 라우트 경로 상수 정의
  - [ ] 6.2: 라우트 그룹별 파일 분리
  - [ ] 6.3: 라우터 설정 통합
- [ ] Phase 7: 접근 제어 통합 및 개선
  - [ ] 7.1: 관리자 라우트 접근 제어 추가
  - [ ] 7.2: 접근 제어 로직 최적화
- [ ] Phase 8: 에러 처리 개선
  - [ ] 8.1: 에러 타입별 처리
  - [ ] 8.2: 커스텀 예외 클래스
- [ ] Phase 9: 성능 최적화
  - [ ] 9.1: 라우트 매칭 최적화
  - [ ] 9.2: 리다이렉트 최적화
- [ ] Phase 10: 문서화 및 테스트
  - [ ] 10.1: 라우트 문서화
  - [ ] 10.2: 라우트 테스트

---

## ⚠️ 리팩토링 주의사항

1. **점진적 마이그레이션**
   - 한 번에 모든 것을 변경하지 말고 단계적으로 진행
   - 각 Phase 완료 후 테스트 필수

2. **하위 호환성**
   - 기존 라우트 경로는 유지
   - 점진적으로 새로운 구조로 마이그레이션

3. **테스트 커버리지**
   - 리팩토링 전후 동작이 동일한지 확인
   - 모든 라우트 경로 테스트

4. **성능 모니터링**
   - 리팩토링 후 성능 변화 모니터링
   - 필요 시 추가 최적화

---

---

## 📝 수정 이력

### 버전 2.1 (2025-11-21)
- **성능 및 아키텍처 개선사항 반영**
  - Phase 0 추가: 사용자 권한 정보 Provider 구축 (최우선)
  - Phase 1 수정: redirect를 동기 처리로 변경 (비동기 DB 호출 제거)
  - 무한 리다이렉트 방지: Fallback 경로(`/home`) 추가
  - Phase 5 제거: 화면 레벨 체크 제거, 라우터 레벨 방어 강화
  - Phase 7 수정: static Map 캐싱 제거, Riverpod Provider 활용
  - Phase 6 개선: Enum 활용, ShellRoute 적극 활용

### 버전 2.0 (2025-11-21)
- 라우터 리팩토링 섹션 추가 (Phase 6-10)

### 버전 1.0 (2025-11-21)
- 초기 문서 작성

---

**작성일**: 2025-11-21  
**작성자**: 개발팀  
**버전**: 2.1 (성능 및 아키텍처 개선사항 반영)

