# 최근 변경사항 요약 문서

## 개요

마지막 깃푸시 이후부터 현재까지 진행된 모든 변경사항을 정리한 문서입니다.

## 변경 기간

- 시작: 마지막 깃푸시 시점
- 종료: 현재 시점

---

## 1. 포인트 스크린 UI/UX 개선

### 1.1 리뷰어 출금 버튼만 표시

**파일**: `lib/screens/mypage/common/points_screen.dart`

**변경 내용**:
- 리뷰어(`userType == 'reviewer'`)는 출금 버튼만 표시
- 광고주는 충전/출금 버튼 모두 표시

**코드 변경**:
```dart
Widget _buildActionButtons() {
  // 리뷰어는 출금 버튼만 표시
  if (widget.userType == 'reviewer') {
    return CustomButton(
      text: '포인트 출금',
      // ...
    );
  }
  
  // 광고주는 충전/출금 모두 표시
  return Row(
    children: [
      // 출금 버튼
      // 충전 버튼
    ],
  );
}
```

### 1.2 포인트 표시 문제 해결

**문제**: 포인트가 늘어났는데 포인트 스크린 상단에 표시가 안되는 문제

**원인**: `PointService.getUserWallets()`를 사용하여 포인트를 조회했지만, 최신 포인트가 반영되지 않음

**해결**:
- `PointService.getUserWallets()` → `WalletService.getUserWallet()`로 변경
- `wallets` 테이블에서 직접 조회하여 최신 포인트 표시
- 포인트 내역도 `WalletService.getUserPointHistory()`로 변경

**파일**: `lib/screens/mypage/common/points_screen.dart`

**변경 내용**:
```dart
// 변경 전
final wallets = await PointService.getUserWallets(user.uid);
final personalWallet = wallets.firstWhere(...);
_currentPoints = personalWallet?.points ?? 0;

// 변경 후
final wallet = await WalletService.getUserWallet();
_currentPoints = wallet?.currentPoints ?? 0;
```

---

## 2. 포인트 스크린 지갑 구분 로직 구현

### 2.1 리뷰어/광고주 지갑 구분

**요구사항**:
- 리뷰어: `user_id`의 개인 월렛 정보 표시
- 사업자이면서 owner: `company_id`의 회사 월렛 정보 표시
- owner가 아니면 입금, 출금 권한 없음

**파일**: `lib/screens/mypage/common/points_screen.dart`

**변경 내용**:
- `_isOwner` 필드 추가: owner 여부 (입금/출금 권한)
- `_walletId` 필드 추가: 현재 사용 중인 지갑 ID (개인 또는 회사)
- `_loadPointsData()` 메서드 수정:
  - 리뷰어: 개인 지갑 조회
  - 광고주 owner: 회사 지갑 조회
  - 광고주 manager: 개인 지갑 조회 (읽기 전용)

**코드 변경**:
```dart
if (widget.userType == 'reviewer') {
  // 리뷰어: 개인 지갑 조회
  final wallet = await WalletService.getUserWallet();
  _isOwner = true; // 리뷰어는 항상 자신의 지갑에 대한 권한이 있음
} else if (widget.userType == 'advertiser') {
  // 사업자: owner 여부 확인 후 회사 지갑 조회
  final companyId = await CompanyUserService.getUserCompanyId(user.uid);
  final companyRole = await CompanyUserService.getUserCompanyRole(user.uid);
  final isOwner = companyRole == 'owner';
  
  if (companyId != null && isOwner) {
    // owner인 경우 회사 지갑 조회
    final companyWallet = await WalletService.getCompanyWalletByCompanyId(companyId);
  } else {
    // owner가 아닌 경우 개인 지갑 조회 (읽기 전용)
    final wallet = await WalletService.getUserWallet();
    _isOwner = false; // owner가 아니면 입금/출금 권한 없음
  }
}
```

### 2.2 입금/출금 권한 UI 표시

**파일**: `lib/screens/mypage/common/points_screen.dart`

**변경 내용**:
- `_buildActionButtons()` 메서드 수정
- `_isOwner`가 `false`일 때 버튼 숨김 및 안내 메시지 표시

**코드 변경**:
```dart
Widget _buildActionButtons() {
  // owner가 아니면 버튼 숨김
  if (!_isOwner) {
    return Container(
      // "입금/출금 권한이 없습니다. (owner만 가능)" 메시지 표시
    );
  }
  
  // 리뷰어는 출금 버튼만 표시
  if (widget.userType == 'reviewer') {
    return CustomButton(text: '포인트 출금', ...);
  }
  
  // 광고주는 충전/출금 모두 표시
  return Row(children: [...]);
}
```

---

## 3. 포인트 충전/출금 신청 RPC 연동

### 3.1 포인트 충전 스크린 수정

**파일**: `lib/screens/mypage/common/point_charge_screen.dart`

**변경 내용**:
- `_loadCurrentPoints()` 메서드 수정: 리뷰어/광고주 구분 로직 추가
- `_submitCharge()` 메서드: 올바른 `walletId`로 RPC 호출

**코드 변경**:
```dart
Future<void> _loadCurrentPoints() async {
  if (widget.userType == 'reviewer') {
    // 리뷰어: 개인 지갑 조회
    final wallet = await WalletService.getUserWallet();
    _walletId = wallet?.id;
  } else if (widget.userType == 'advertiser') {
    // 사업자: owner 여부 확인 후 회사 지갑 조회
    final companyId = await CompanyUserService.getUserCompanyId(user.uid);
    final companyRole = await CompanyUserService.getUserCompanyRole(user.uid);
    final isOwner = companyRole == 'owner';
    
    if (companyId != null && isOwner) {
      // owner인 경우 회사 지갑 조회
      final companyWallet = await WalletService.getCompanyWalletByCompanyId(companyId);
      _walletId = companyWallet?.id;
    } else {
      // owner가 아닌 경우 개인 지갑 조회
      final wallet = await WalletService.getUserWallet();
      _walletId = wallet?.id;
    }
  }
}

Future<void> _submitCharge() async {
  // RPC 함수 호출하여 현금 거래 생성
  await WalletService.createPointCashTransaction(
    walletId: _walletId!,
    transactionType: 'deposit',
    pointAmount: _selectedAmount!,
    cashAmount: cashAmount,
    description: '포인트 충전 요청',
  );
}
```

### 3.2 포인트 출금 스크린 수정

**파일**: `lib/screens/mypage/common/point_refund_screen.dart`

**변경 내용**:
- `_loadWalletInfo()` 메서드 수정: 리뷰어/광고주 구분 로직 추가
- `_submitRefund()` 메서드: 올바른 `walletId`와 계좌 정보로 RPC 호출
- 회사 지갑과 개인 지갑 모두 지원

**코드 변경**:
```dart
Future<void> _loadWalletInfo() async {
  if (widget.userType == 'reviewer') {
    // 리뷰어: 개인 지갑 조회
    final wallet = await WalletService.getUserWallet();
    _userWallet = wallet;
    _walletId = wallet?.id;
    _isCompanyWallet = false;
  } else if (widget.userType == 'advertiser') {
    // 사업자: owner 여부 확인 후 회사 지갑 조회
    final companyId = await CompanyUserService.getUserCompanyId(user.uid);
    final companyRole = await CompanyUserService.getUserCompanyRole(user.uid);
    final isOwner = companyRole == 'owner';
    
    if (companyId != null && isOwner) {
      // owner인 경우 회사 지갑 조회
      final companyWallet = await WalletService.getCompanyWalletByCompanyId(companyId);
      _companyWallet = companyWallet;
      _walletId = companyWallet?.id;
      _isCompanyWallet = true;
    } else {
      // owner가 아닌 경우 개인 지갑 조회
      final wallet = await WalletService.getUserWallet();
      _userWallet = wallet;
      _walletId = wallet?.id;
      _isCompanyWallet = false;
    }
  }
}

Future<void> _submitRefund() async {
  // 계좌 정보 가져오기
  String? bankName, accountNumber, accountHolder;
  
  if (_isCompanyWallet && _companyWallet != null) {
    bankName = _companyWallet!.withdrawBankName;
    accountNumber = _companyWallet!.withdrawAccountNumber;
    accountHolder = _companyWallet!.withdrawAccountHolder;
  } else if (_userWallet != null) {
    bankName = _userWallet!.withdrawBankName;
    accountNumber = _userWallet!.withdrawAccountNumber;
    accountHolder = _userWallet!.withdrawAccountHolder;
  }
  
  // RPC 함수 호출하여 현금 거래 생성
  await WalletService.createPointCashTransaction(
    walletId: _walletId!,
    transactionType: 'withdraw',
    pointAmount: amount,
    bankName: bankName,
    accountNumber: accountNumber,
    accountHolder: accountHolder,
    description: '포인트 환급 요청',
  );
}
```

---

## 4. UserType 분석 및 문서화

### 4.1 UserType 분석 문서 작성

**파일**: `docs/user-type-analysis.md`

**내용**:
- `UserType` enum 정의 및 용도 (`user`, `admin`)
- `CompanyRole` enum 정의 및 용도 (`owner`, `manager`, `reviewer`)
- 리뷰어/광고주 구분 로직 상세 설명
- 현재 사용 방식의 혼란점 분석
- 구현 방안 제시

**핵심 내용**:
- **UserType Enum**: 권한 레벨만 담당 (`user`, `admin`)
- **CompanyRole Enum**: 역할 구분 (`owner`, `manager`, `reviewer`)
- **리뷰어/광고주 구분**: `company_users` 테이블의 `company_role`과 `status`로 판단

---

## 5. UserTypeHelper 구현 및 통합

### 5.1 UserTypeHelper 클래스 생성

**파일**: `lib/utils/user_type_helper.dart` (신규 생성)

**기능**:
- 리뷰어/광고주 판단 로직 중앙화
- 일관성 있는 역할 확인 메서드 제공

**주요 메서드**:
```dart
class UserTypeHelper {
  /// 리뷰어 확인
  static Future<bool> isReviewer(String userId)
  
  /// 광고주 확인
  static Future<bool> isAdvertiser(String userId)
  
  /// 광고주 owner 확인
  static Future<bool> isAdvertiserOwner(String userId)
  
  /// 광고주 manager 확인
  static Future<bool> isAdvertiserManager(String userId)
  
  /// company_role 반환
  static Future<String?> getCompanyRole(String userId)
  
  /// 라우팅 경로에서 userType 문자열 추출
  static String getUserTypeFromPath(String path)
}
```

**리뷰어 판단 조건**:
1. `company_users` 테이블에 레코드가 없음
2. `company_users.status != 'active'`
3. `company_users.company_role = 'reviewer'` AND `status = 'active'`

**광고주 판단 조건**:
1. `company_users` 테이블에 레코드가 있음
2. `company_users.status = 'active'`
3. `company_users.company_role IN ('owner', 'manager')`

### 5.2 포인트 스크린 로직 업데이트

**파일**: `lib/screens/mypage/common/points_screen.dart`

**변경 내용**:
- `widget.userType` 문자열 기반 판단 → `UserTypeHelper` 사용
- 실제 DB 상태 기반으로 리뷰어/광고주 구분

**코드 변경**:
```dart
// 변경 전
if (widget.userType == 'reviewer') {
  // ...
} else if (widget.userType == 'advertiser') {
  final companyRole = await CompanyUserService.getUserCompanyRole(user.uid);
  final isOwner = companyRole == 'owner';
  // ...
}

// 변경 후
final isReviewer = await UserTypeHelper.isReviewer(user.uid);
final isOwner = await UserTypeHelper.isAdvertiserOwner(user.uid);

if (isReviewer) {
  // 리뷰어: 개인 지갑 조회
} else if (isOwner) {
  // 광고주 owner: 회사 지갑 조회
} else {
  // 광고주 manager 또는 기타: 개인 지갑 조회 (읽기 전용)
}
```

### 5.3 포인트 충전/출금 스크린 로직 업데이트

**파일**: 
- `lib/screens/mypage/common/point_charge_screen.dart`
- `lib/screens/mypage/common/point_refund_screen.dart`

**변경 내용**:
- `UserTypeHelper`를 사용하여 리뷰어/광고주 구분
- 실제 DB 상태 기반으로 지갑 조회

### 5.4 MyPageScreen 로직 업데이트

**파일**: `lib/screens/mypage/mypage_screen.dart`

**변경 내용**:
- `user.companyId != null` 기반 판단 → `UserTypeHelper.isAdvertiser()` 사용
- `FutureBuilder`를 사용하여 비동기 판단

**코드 변경**:
```dart
// 변경 전
if (user.companyId != null) {
  return AdvertiserMyPageScreen(user: user);
} else {
  return ReviewerMyPageScreen(user: user);
}

// 변경 후
return FutureBuilder<bool>(
  future: UserTypeHelper.isAdvertiser(user.uid),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final isAdvertiser = snapshot.data ?? false;
    
    if (isAdvertiser) {
      return AdvertiserMyPageScreen(user: user);
    } else {
      return ReviewerMyPageScreen(user: user);
    }
  },
);
```

---

## 6. 데이터베이스 스키마 변경

### 6.1 CompanyRole 제약조건 확장

**파일**: `supabase/migrations/20251114075636_add_reviewer_to_company_role.sql` (신규 생성)

**변경 내용**:
- `company_users.company_role` 제약조건에 `'reviewer'` 추가
- 기존: `CHECK (company_role IN ('owner', 'manager'))`
- 변경 후: `CHECK (company_role IN ('owner', 'manager', 'reviewer'))`

**SQL**:
```sql
-- 기존 제약조건 삭제
ALTER TABLE "public"."company_users" 
DROP CONSTRAINT IF EXISTS "company_users_company_role_check";

-- 새로운 제약조건 추가 (owner, manager, reviewer 포함)
ALTER TABLE "public"."company_users" 
ADD CONSTRAINT "company_users_company_role_check" 
CHECK (("company_role" = ANY (ARRAY['owner'::"text", 'manager'::"text", 'reviewer'::"text"])));

COMMENT ON CONSTRAINT "company_users_company_role_check" ON "public"."company_users" IS 
'company_role은 owner(회사 소유자), manager(회사 관리자), reviewer(리뷰어) 중 하나여야 합니다. owner와 manager는 광고주, reviewer는 리뷰어입니다.';
```

### 6.2 CompanyRole Enum 확장

**파일**: `lib/models/user.dart`

**변경 내용**:
- `CompanyRole` enum에 `reviewer` 추가

**코드 변경**:
```dart
// 변경 전
enum CompanyRole {
  owner,    // 회사 소유자
  manager,  // 회사 관리자
}

// 변경 후
enum CompanyRole {
  owner,    // 회사 소유자 (광고주)
  manager,  // 회사 관리자 (광고주)
  reviewer, // 리뷰어 (회사에 속한 리뷰어)
}
```

---

## 7. 변경된 파일 목록

### 7.1 신규 생성 파일

1. `lib/utils/user_type_helper.dart`
   - 사용자 타입 및 역할 판단 헬퍼 클래스

2. `supabase/migrations/20251114075636_add_reviewer_to_company_role.sql`
   - `company_role` 제약조건에 `'reviewer'` 추가 마이그레이션

3. `docs/user-type-analysis.md`
   - UserType 사용 현황 분석 문서

4. `docs/recent-changes-summary.md`
   - 최근 변경사항 요약 문서 (본 문서)

### 7.2 수정된 파일

1. `lib/models/user.dart`
   - `CompanyRole` enum에 `reviewer` 추가

2. `lib/screens/mypage/common/points_screen.dart`
   - 리뷰어는 출금 버튼만 표시
   - 포인트 조회 로직 개선 (`WalletService.getUserWallet()` 사용)
   - 리뷰어/광고주 지갑 구분 로직 추가
   - `UserTypeHelper` 사용
   - owner 권한 체크 및 UI 표시

3. `lib/screens/mypage/common/point_charge_screen.dart`
   - 리뷰어/광고주 지갑 구분 로직 추가
   - `UserTypeHelper` 사용
   - 올바른 `walletId`로 RPC 호출

4. `lib/screens/mypage/common/point_refund_screen.dart`
   - 리뷰어/광고주 지갑 구분 로직 추가
   - 회사 지갑과 개인 지갑 모두 지원
   - `UserTypeHelper` 사용
   - 올바른 `walletId`와 계좌 정보로 RPC 호출

5. `lib/screens/mypage/mypage_screen.dart`
   - `UserTypeHelper.isAdvertiser()` 사용
   - `FutureBuilder`를 사용한 비동기 판단

---

## 8. 주요 개선사항

### 8.1 코드 일관성 향상

- **이전**: 여러 곳에서 서로 다른 방식으로 리뷰어/광고주 판단
- **개선**: `UserTypeHelper`를 통한 중앙화된 판단 로직

### 8.2 정확성 향상

- **이전**: `widget.userType` 문자열 기반 판단 (라우팅 경로 기반)
- **개선**: 실제 DB 상태 기반 판단 (`company_users` 테이블 조회)

### 8.3 권한 관리 명확화

- **이전**: `companyId` 존재 여부로 광고주 판단
- **개선**: `company_role`과 `status`를 모두 고려한 정확한 판단

### 8.4 포인트 지갑 접근 권한

- **리뷰어**: 개인 지갑만 사용 (출금만 가능)
- **광고주 owner**: 회사 지갑 사용 (충전/출금 가능)
- **광고주 manager**: 개인 지갑 사용 (읽기 전용, 충전/출금 불가)

---

## 9. 다음 단계

### 9.1 마이그레이션 적용

마이그레이션 파일이 생성되었지만 아직 적용되지 않았습니다. 다음 중 하나를 진행해야 합니다:

1. **DB 리셋 후 마이그레이션 재적용** (개발 환경 권장)
   ```bash
   npx supabase db reset
   ```

2. **마이그레이션 히스토리 수정 후 적용** (프로덕션 환경)
   ```bash
   npx supabase migration repair --status reverted [마이그레이션 ID들]
   npx supabase migration up
   ```

### 9.2 테스트 필요 항목

- [ ] 리뷰어 (company_users 없음) 테스트
- [ ] 리뷰어 (company_role = 'reviewer') 테스트
- [ ] 광고주 owner 테스트
- [ ] 광고주 manager 테스트
- [ ] 포인트 지갑 접근 권한 테스트
- [ ] 포인트 충전/출금 신청 RPC 테스트

---

## 10. 기술적 세부사항

### 10.1 리뷰어 판단 로직

```dart
// UserTypeHelper.isReviewer()
1. company_users 테이블 조회 (status='active'만)
2. 레코드가 없으면 → 리뷰어
3. company_role = 'reviewer'이면 → 리뷰어
4. 그 외 → 광고주
```

### 10.2 광고주 판단 로직

```dart
// UserTypeHelper.isAdvertiser()
1. company_users 테이블 조회 (status='active'만)
2. 레코드가 없으면 → 리뷰어
3. company_role IN ('owner', 'manager')이면 → 광고주
4. 그 외 → 리뷰어
```

### 10.3 포인트 지갑 접근 로직

```dart
// PointsScreen._loadPointsData()
1. isReviewer 확인
   - true → 개인 지갑 조회, _isOwner = true
2. isOwner 확인
   - true → 회사 지갑 조회, _isOwner = true
3. 그 외
   - 개인 지갑 조회, _isOwner = false (읽기 전용)
```

---

## 11. 참고 문서

- `docs/user-type-analysis.md`: UserType 사용 현황 상세 분석
- `docs/admin-points-management-roadmap.md`: 어드민 포인트 관리 로드맵
- `docs/point-charge-test-roadmap.md`: 포인트 충전 테스트 로드맵

---

## 12. 요약

### 주요 변경사항

1. ✅ 포인트 스크린 UI 개선 (리뷰어는 출금 버튼만)
2. ✅ 포인트 표시 문제 해결 (최신 포인트 반영)
3. ✅ 리뷰어/광고주 지갑 구분 로직 구현
4. ✅ owner 권한 체크 및 UI 표시
5. ✅ 포인트 충전/출금 신청 RPC 연동
6. ✅ UserType 분석 문서 작성
7. ✅ UserTypeHelper 클래스 생성 및 통합
8. ✅ CompanyRole enum 확장 (reviewer 추가)
9. ✅ DB 마이그레이션 파일 생성

### 아직 완료되지 않은 작업

- [ ] 마이그레이션 적용 (DB 리셋 또는 수동 적용 필요)
- [ ] 전체 기능 테스트

---

**작성일**: 2025-11-14  
**작성자**: AI Assistant

