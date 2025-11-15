# UserType 사용 현황 분석 문서

## 개요

현재 코드베이스에서 `userType`이 어떻게 사용되고 있는지, 그리고 명확한 구분 방식을 정의한 문서입니다.

## 1. UserType Enum 정의

### 위치
- `lib/models/user.dart`

### 정의
```dart
enum UserType {
  user,  // 일반 사용자 (리뷰어 또는 광고주, company_users로 구분)
  admin, // 시스템 관리자 (전역 권한)
}
```

### 데이터베이스 스키마
- 테이블: `public.users`
- 컬럼: `user_type` (text, default: 'user')
- 가능한 값: `'user'`, `'admin'`

**용도**: 시스템 전역 권한 레벨만 담당
- `user`: 일반 사용자 (리뷰어 또는 광고주 모두 포함)
- `admin`: 시스템 관리자 (모든 권한)

## 2. CompanyRole 정의

### 위치
- `lib/models/user.dart` (현재는 `owner`, `manager`만 있음)
- 데이터베이스: `public.company_users` 테이블

### 정의 (확장 필요)
```dart
enum CompanyRole {
  owner,    // 회사 소유자 (광고주)
  manager,  // 회사 관리자 (광고주)
  reviewer, // 리뷰어 (회사에 속한 리뷰어)
}
```

### 데이터베이스 스키마 (확장 필요)
- 테이블: `public.company_users`
- 컬럼: `company_role` (text, NOT NULL)
- **가능한 값**: `'owner'`, `'manager'`, `'reviewer'`
- 현재 제약조건: `CHECK (company_role IN ('owner', 'manager'))` → **확장 필요**

### CompanyRole의 역할

#### A. 광고주 역할
- **`owner`**: 회사 소유자
  - 회사 지갑 관리 권한 (충전/출금)
  - 회사 설정 변경 권한
  - 회사 멤버 관리 권한
  
- **`manager`**: 회사 관리자
  - 회사 지갑 조회 권한 (읽기 전용)
  - 캠페인 관리 권한
  - 회사 멤버 조회 권한

#### B. 리뷰어 역할
- **`reviewer`**: 회사에 속한 리뷰어
  - 개인 지갑만 사용
  - 회사 캠페인 참여 가능
  - 회사 정보 조회 제한

## 3. 리뷰어/광고주 구분 로직

### 3.1 기본 구분 원칙

#### 리뷰어 (Reviewer)
다음 중 하나라도 해당하면 리뷰어:
1. `company_users` 테이블에 레코드가 없는 경우
2. `company_users` 테이블에 레코드가 있지만 `status != 'active'`인 경우
3. `company_users.company_role = 'reviewer'`이고 `status = 'active'`인 경우

#### 광고주 (Advertiser)
다음 조건을 모두 만족해야 광고주:
1. `company_users` 테이블에 레코드가 있고
2. `status = 'active'`이고
3. `company_role IN ('owner', 'manager')`인 경우

### 3.2 구분 로직 플로우차트

```
사용자 확인
    │
    ├─→ company_users 테이블 조회
    │
    ├─→ 레코드 없음? ──→ 리뷰어
    │
    ├─→ status != 'active'? ──→ 리뷰어
    │
    ├─→ company_role = 'reviewer'? ──→ 리뷰어
    │
    ├─→ company_role = 'owner'? ──→ 광고주 (owner)
    │
    └─→ company_role = 'manager'? ──→ 광고주 (manager)
```

### 3.3 포인트 지갑 접근 권한

#### 리뷰어
- **지갑**: 개인 지갑만 사용
- **충전**: 불가능 (개인 지갑은 충전 불가)
- **출금**: 가능 (개인 지갑 출금)

#### 광고주 (owner)
- **지갑**: 회사 지갑 사용
- **충전**: 가능 (회사 지갑 충전)
- **출금**: 가능 (회사 지갑 출금)

#### 광고주 (manager)
- **지갑**: 개인 지갑 사용 (읽기 전용)
- **충전**: 불가능 (권한 없음)
- **출금**: 불가능 (권한 없음)

## 4. 현재 사용 방식의 혼란점

### 문제점 1: 두 가지 다른 타입 시스템 혼재

#### A. UserType Enum (DB 기반)
- **값**: `UserType.user`, `UserType.admin`
- **용도**: 데이터베이스에 저장되는 실제 사용자 타입 (권한 레벨)
- **사용 위치**:
  - `User` 모델의 `userType` 필드
  - 권한 체크 (`user.userType == UserType.admin`)
  - 어드민 페이지 접근 제어

#### B. 문자열 기반 userType (라우팅/UI용)
- **값**: `'reviewer'`, `'advertiser'`
- **용도**: 라우팅 경로와 UI 구분
- **사용 위치**:
  - `PointsScreen(userType: 'reviewer')`
  - `PointChargeScreen(userType: 'advertiser')`
  - `PointRefundScreen(userType: 'reviewer')`
  - `app_router.dart`의 라우트 정의

**문제**: `UserType` enum에는 `user`, `admin`만 있는데, 실제로는 `company_users` 테이블의 `company_role`로 리뷰어/광고주를 구분하고 있습니다.

### 문제점 2: CompanyRole enum에 reviewer 없음

현재 `CompanyRole` enum:
```dart
enum CompanyRole {
  owner,    // 회사 소유자
  manager,  // 회사 관리자
  // reviewer 없음!
}
```

**문제**: `reviewer` 역할이 enum에 정의되어 있지 않아, 리뷰어는 `company_users` 테이블에 레코드가 없는 경우로만 판단하고 있습니다.

## 5. 현재 userType 사용 위치

### 5.1 UserType Enum 사용 (DB 기반)

#### 권한 체크
```dart
// 어드민 권한 체크
if (user.userType == app_user.UserType.admin) {
  // 어드민 전용 기능
}
```

**사용 파일들**:
- `lib/screens/mypage/admin/*.dart` (모든 어드민 스크린)
- `lib/screens/mypage/mypage_screen.dart`
- `lib/config/app_router.dart` (라우팅 가드)
- `lib/widgets/main_shell.dart`
- `lib/widgets/drawer/*.dart`

### 5.2 문자열 기반 userType 사용 (라우팅/UI)

#### 포인트 관련 스크린
```dart
// app_router.dart
GoRoute(
  path: '/mypage/reviewer/points',
  builder: (context, state) => const PointsScreen(userType: 'reviewer'),
),
GoRoute(
  path: '/mypage/advertiser/points',
  builder: (context, state) => const PointsScreen(userType: 'advertiser'),
),
```

**사용 파일들**:
- `lib/screens/mypage/common/points_screen.dart`
- `lib/screens/mypage/common/point_charge_screen.dart`
- `lib/screens/mypage/common/point_refund_screen.dart`
- `lib/config/app_router.dart`

**사용 목적**:
- 리뷰어는 개인 지갑 사용
- 광고주(owner)는 회사 지갑 사용
- 버튼 표시 로직 구분 (리뷰어는 출금만, 광고주는 충전/출금 모두)

## 6. 구현 방안: 현재 구조 유지 + 명확한 구분

### 6.1 기본 원칙

#### A. UserType Enum은 그대로 유지
- `user`: 일반 사용자 (리뷰어 또는 광고주 모두 포함)
- `admin`: 시스템 관리자

#### B. CompanyRole Enum 확장
```dart
enum CompanyRole {
  owner,    // 회사 소유자 (광고주)
  manager,  // 회사 관리자 (광고주)
  reviewer, // 리뷰어 (회사에 속한 리뷰어)
}
```

#### C. 리뷰어/광고주 구분은 company_users 테이블로 처리

**리뷰어 판단 조건**:
1. `company_users` 테이블에 레코드가 없음
2. `company_users.status != 'active'`
3. `company_users.company_role = 'reviewer'` AND `status = 'active'`

**광고주 판단 조건**:
1. `company_users` 테이블에 레코드가 있음
2. `company_users.status = 'active'`
3. `company_users.company_role IN ('owner', 'manager')`

**광고주 owner 판단 조건**:
1. 위 광고주 조건을 만족하고
2. `company_users.company_role = 'owner'`

**광고주 manager 판단 조건**:
1. 위 광고주 조건을 만족하고
2. `company_users.company_role = 'manager'`

### 6.2 헬퍼 함수 구현

```dart
// lib/utils/user_type_helper.dart
class UserTypeHelper {
  /// 현재 사용자가 리뷰어인지 확인
  /// 
  /// 리뷰어 조건:
  /// 1. company_users 테이블에 레코드가 없음
  /// 2. company_users.status != 'active'
  /// 3. company_users.company_role = 'reviewer' AND status = 'active'
  static Future<bool> isReviewer(String userId) async {
    try {
      final companyRole = await CompanyUserService.getUserCompanyRole(userId);
      
      // 레코드가 없거나 status != 'active'인 경우
      if (companyRole == null) {
        return true;
      }
      
      // company_role = 'reviewer'인 경우
      if (companyRole == 'reviewer') {
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ 리뷰어 확인 실패: $e');
      return false;
    }
  }
  
  /// 현재 사용자가 광고주인지 확인
  /// 
  /// 광고주 조건:
  /// 1. company_users 테이블에 레코드가 있음
  /// 2. company_users.status = 'active'
  /// 3. company_users.company_role IN ('owner', 'manager')
  static Future<bool> isAdvertiser(String userId) async {
    try {
      final companyRole = await CompanyUserService.getUserCompanyRole(userId);
      
      // 레코드가 없거나 status != 'active'인 경우
      if (companyRole == null) {
        return false;
      }
      
      // company_role이 'owner' 또는 'manager'인 경우
      return companyRole == 'owner' || companyRole == 'manager';
    } catch (e) {
      print('❌ 광고주 확인 실패: $e');
      return false;
    }
  }
  
  /// 현재 사용자가 광고주 owner인지 확인
  static Future<bool> isAdvertiserOwner(String userId) async {
    try {
      final companyRole = await CompanyUserService.getUserCompanyRole(userId);
      return companyRole == 'owner';
    } catch (e) {
      print('❌ 광고주 owner 확인 실패: $e');
      return false;
    }
  }
  
  /// 현재 사용자가 광고주 manager인지 확인
  static Future<bool> isAdvertiserManager(String userId) async {
    try {
      final companyRole = await CompanyUserService.getUserCompanyRole(userId);
      return companyRole == 'manager';
    } catch (e) {
      print('❌ 광고주 manager 확인 실패: $e');
      return false;
    }
  }
  
  /// 현재 사용자의 company_role 반환
  /// 
  /// 반환값:
  /// - 'owner': 광고주 owner
  /// - 'manager': 광고주 manager
  /// - 'reviewer': 리뷰어 (회사에 속한)
  /// - null: 리뷰어 (회사에 속하지 않은)
  static Future<String?> getCompanyRole(String userId) async {
    return await CompanyUserService.getUserCompanyRole(userId);
  }
  
  /// 라우팅 경로에서 userType 문자열 추출
  static String getUserTypeFromPath(String path) {
    if (path.contains('/reviewer/')) return 'reviewer';
    if (path.contains('/advertiser/')) return 'advertiser';
    return 'user';
  }
}
```

### 6.3 포인트 스크린에서의 사용 예시

```dart
// points_screen.dart
Future<void> _loadPointsData() async {
  final user = await _authService.currentUser;
  if (user == null) return;
  
  // 리뷰어인지 확인
  final isReviewer = await UserTypeHelper.isReviewer(user.uid);
  
  if (isReviewer) {
    // 리뷰어: 개인 지갑 조회
    final wallet = await WalletService.getUserWallet();
    // ...
  } else {
    // 광고주: owner 여부 확인
    final isOwner = await UserTypeHelper.isAdvertiserOwner(user.uid);
    
    if (isOwner) {
      // owner: 회사 지갑 조회
      final companyId = await CompanyUserService.getUserCompanyId(user.uid);
      final companyWallet = await WalletService.getCompanyWalletByCompanyId(companyId!);
      // ...
    } else {
      // manager: 개인 지갑 조회 (읽기 전용)
      final wallet = await WalletService.getUserWallet();
      // ...
    }
  }
}
```

## 7. 데이터베이스 스키마 변경 필요사항

### 7.1 company_users 테이블 제약조건 변경

**현재 제약조건**:
```sql
CONSTRAINT "company_users_company_role_check" 
CHECK (("company_role" = ANY (ARRAY['owner'::"text", 'manager'::"text"])))
```

**변경 후**:
```sql
CONSTRAINT "company_users_company_role_check" 
CHECK (("company_role" = ANY (ARRAY['owner'::"text", 'manager'::"text", 'reviewer'::"text"])))
```

### 7.2 CompanyRole Enum 확장

**현재**:
```dart
enum CompanyRole {
  owner,    // 회사 소유자
  manager,  // 회사 관리자
}
```

**변경 후**:
```dart
enum CompanyRole {
  owner,    // 회사 소유자 (광고주)
  manager,  // 회사 관리자 (광고주)
  reviewer, // 리뷰어 (회사에 속한 리뷰어)
}
```

## 8. 구현 체크리스트

### 8.1 데이터베이스 변경
- [ ] `company_users.company_role` 제약조건에 `'reviewer'` 추가
- [ ] 기존 데이터 마이그레이션 (필요시)

### 8.2 코드 변경
- [ ] `CompanyRole` enum에 `reviewer` 추가
- [ ] `UserTypeHelper` 클래스 생성
- [ ] 모든 리뷰어/광고주 판단 로직을 `UserTypeHelper`로 통합
- [ ] 포인트 스크린 로직 업데이트
- [ ] 기타 리뷰어/광고주 구분 로직 업데이트

### 8.3 테스트
- [ ] 리뷰어 (company_users 없음) 테스트
- [ ] 리뷰어 (company_role = 'reviewer') 테스트
- [ ] 광고주 owner 테스트
- [ ] 광고주 manager 테스트
- [ ] 포인트 지갑 접근 권한 테스트

## 9. 현재 코드에서 userType을 어떻게 "알고 있는지"

### 9.1 라우팅 경로에서 추론

```dart
// app_router.dart
GoRoute(
  path: '/mypage/reviewer/points',
  builder: (context, state) => const PointsScreen(userType: 'reviewer'),
),
```

**문제**: 하드코딩된 문자열, 경로와 실제 사용자 상태가 불일치할 수 있음

### 9.2 User 모델의 companyId로 추론

```dart
// mypage_screen.dart
if (user.companyId != null) {
  return AdvertiserMyPageScreen(user: user);
} else {
  return ReviewerMyPageScreen(user: user);
}
```

**문제**: `companyId`가 있어도 `company_users.status != 'active'`이거나 `company_role = 'reviewer'`일 수 있음

### 9.3 company_users 테이블 조회 (가장 정확)

```dart
// points_screen.dart, point_charge_screen.dart 등
final companyId = await CompanyUserService.getUserCompanyId(user.uid);
final companyRole = await CompanyUserService.getUserCompanyRole(user.uid);
```

**가장 정확한 방법**: 실제 DB 상태를 확인

## 10. 권장 사항

### 즉시 적용 가능한 개선

1. **헬퍼 함수 생성**
   - `UserTypeHelper` 클래스 생성
   - 리뷰어/광고주 판단 로직 중앙화
   - 모든 판단 로직을 헬퍼 함수로 통합

2. **CompanyRole enum 확장**
   - `reviewer` 역할 추가
   - DB 제약조건 업데이트

3. **문서화**
   - `userType` 문자열 사용 위치 명확히 문서화
   - `UserType` enum과 `CompanyRole` enum의 관계 명확히 설명
   - 리뷰어/광고주 구분 로직 문서화

4. **타입 안정성 개선**
   - 문자열 대신 enum 사용 검토
   - 또는 최소한 상수로 정의

### 장기 개선 방안

1. **라우팅 로직 개선**
   - 경로 기반이 아닌 사용자 상태 기반으로 라우팅
   - 동적 라우팅 구현
   - 사용자 상태에 따라 올바른 경로로 리다이렉트

2. **권한 시스템 강화**
   - 역할 기반 접근 제어 (RBAC) 구현
   - 각 역할별 권한 명시적 정의

## 11. 결론

### 핵심 원칙

1. **UserType Enum**: 권한 레벨만 담당 (`user`, `admin`)
2. **CompanyRole Enum**: 역할 구분 (`owner`, `manager`, `reviewer`)
3. **리뷰어/광고주 구분**: `company_users` 테이블의 `company_role`과 `status`로 판단

### 명확한 구분 기준

- **리뷰어**: `company_users` 레코드 없음 OR `status != 'active'` OR `company_role = 'reviewer'`
- **광고주**: `company_users` 레코드 있음 AND `status = 'active'` AND `company_role IN ('owner', 'manager')`
- **광고주 owner**: 위 조건 + `company_role = 'owner'`
- **광고주 manager**: 위 조건 + `company_role = 'manager'`

### 다음 단계

1. DB 스키마 변경 (제약조건 업데이트)
2. `CompanyRole` enum 확장
3. `UserTypeHelper` 클래스 구현
4. 기존 코드 리팩토링
