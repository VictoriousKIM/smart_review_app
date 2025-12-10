# 프론트엔드 하드코딩 보안 로직 전수조사 보고서

**작성일**: 2025년 12월 10일  
**작업 기간**: 2025년 12월 10일

## 📋 개요

프론트엔드에서 하드코딩된 보안/필터링 로직을 전수조사하여 데이터베이스 레벨로 이동해야 하는 항목들을 식별했습니다.

## ⚠️ 보안 원칙

**프론트엔드에서의 보안 체크는 UI/UX 목적으로만 사용해야 하며, 실제 데이터 접근 제어는 반드시 데이터베이스 레벨(RLS 정책 및 RPC 함수)에서 처리해야 합니다.**

## 🔍 조사 결과

### 1. 프론트엔드에서 역할 체크 후 필터링하는 경우

#### 1.1 `CompanyService.getAdvertiserCompanyByUserId()`

**위치**: `lib/services/company_service.dart:9-52`

**문제점**:
```dart
// 1. 사용자 역할 확인 (기존 작동하는 RPC 사용)
final companyRole = await supabase.rpc(
  'get_user_company_role_safe',
  params: {'p_user_id': userId},
) as String?;

// owner 또는 manager가 아니면 null 반환
if (companyRole != 'owner' && companyRole != 'manager') {
  return null;  // ❌ 프론트엔드에서 필터링
}

// 2. 회사 ID 조회
final companyId = await supabase.rpc(
  'get_user_company_id_safe',
  params: {'p_user_id': userId},
) as String?;

// 3. 회사 정보 조회 (RLS 정책이 있으므로 안전)
final companyData = await supabase
  .from('companies')
  .select()
  .eq('id', companyId)
  .maybeSingle();
```

**권장 해결 방법**:
- `get_advertiser_company_by_user_id` RPC 함수를 직접 사용
- 이미 존재하는 RPC 함수이므로 이를 활용

**현재 상태**: ⚠️ 부분적으로 수정됨 (`getCompanyByUserId()`는 이미 수정됨)

---

### 2. 직접 데이터베이스 쿼리하는 경우

#### 2.1 `CompanyService.getPendingManagerRequest()`

**위치**: `lib/services/company_service.dart:122-167`

**문제점**:
```dart
// company_users 테이블에서 pending 또는 rejected 상태의 manager 역할 조회
// RLS 정책이 있으므로 안전
final companyUserResponse = await supabase
  .from('company_users')
  .select('company_id, status, created_at')
  .eq('user_id', userId)
  .inFilter('status', ['pending', 'rejected'])
  .eq('company_role', 'manager')  // ❌ 프론트엔드에서 필터링
  .maybeSingle();

// 회사 정보 조회 (RLS 정책이 있으므로 안전)
final companyData = await supabase
  .from('companies')
  .select()
  .eq('id', companyId)
  .maybeSingle();
```

**권장 해결 방법**:
- RPC 함수 생성: `get_pending_manager_request_safe(p_user_id)`
- RPC 함수 내에서 역할 및 상태 필터링

**현재 상태**: ⚠️ RLS 정책에 의존하지만 RPC 함수로 이동 권장

---

#### 2.2 `CompanyService.cancelManagerRequest()`

**위치**: `lib/services/company_service.dart:169-186`

**문제점**:
```dart
// pending 상태의 manager 역할 삭제
// RLS 정책이 있으므로 안전 (사용자 본인의 요청만 삭제 가능)
await supabase
  .from('company_users')
  .delete()
  .eq('user_id', userId)
  .eq('status', 'pending')
  .eq('company_role', 'manager');  // ❌ 프론트엔드에서 필터링
```

**권장 해결 방법**:
- RPC 함수 생성: `cancel_manager_request_safe(p_user_id)`
- RPC 함수 내에서 역할 및 상태 확인 후 삭제

**현재 상태**: ⚠️ RLS 정책에 의존하지만 RPC 함수로 이동 권장

---

#### 2.3 `ProfileScreen` - 회사 검색

**위치**: `lib/screens/mypage/common/profile_screen.dart:1625-1630`

**문제점**:
```dart
// 여러 결과 반환 (maybeSingle() 대신 select() 사용)
final response = await supabase
  .from('companies')
  .select(
    'id, business_name, business_number, representative_name, address',
  )
  .eq('business_name', businessName);  // ❌ 직접 쿼리
```

**권장 해결 방법**:
- RPC 함수 생성: `search_companies_by_name(p_business_name, p_user_id)`
- RPC 함수 내에서 권한 체크 및 검색 수행

**현재 상태**: ⚠️ RLS 정책에 의존하지만 RPC 함수로 이동 권장

---

#### 2.4 `AdvertiserMyCampaignsScreen` - 대체 로직

**위치**: `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart:605-625`

**문제점**:
```dart
// RPC 실패 또는 결과가 비어있으면 대체 로직 실행
// 1. 사용자의 회사 ID 조회
final companyResult = await SupabaseConfig.client
  .from('company_users')
  .select('company_id')
  .eq('user_id', userId)
  .eq('status', 'active')  // ❌ 프론트엔드에서 필터링
  .maybeSingle();

// 2. 회사의 캠페인 조회
final directResult = await SupabaseConfig.client
  .from('campaigns')
  .select()
  .eq('company_id', companyId)
  .order('created_at', ascending: false);
```

**권장 해결 방법**:
- RPC 함수가 실패하는 원인을 해결
- 대체 로직 제거하고 RPC 함수만 사용

**현재 상태**: ⚠️ 대체 로직이므로 제거 권장

---

#### 2.5 `AdvertiserManagerScreen` - 매니저 제거

**위치**: `lib/screens/mypage/advertiser/advertiser_manager_screen.dart:833-837`

**문제점**:
```dart
// company_users 테이블에서 레코드 삭제 (복합 키 사용)
await supabase
  .from('company_users')
  .delete()
  .eq('company_id', manager['company_id'])
  .eq('user_id', manager['user_id'])
  .eq('company_role', 'manager');  // ❌ 프론트엔드에서 필터링
```

**권장 해결 방법**:
- RPC 함수 생성: `remove_manager_safe(p_company_id, p_user_id, p_current_user_id)`
- RPC 함수 내에서 권한 체크 (owner만 가능) 및 역할 확인

**현재 상태**: ⚠️ RLS 정책에 의존하지만 RPC 함수로 이동 권장

---

#### 2.6 Admin 화면들 - 직접 쿼리

**위치들**:
- `lib/screens/mypage/admin/admin_campaigns_screen.dart:38`
- `lib/screens/mypage/admin/admin_companies_screen.dart:38`
- `lib/screens/mypage/admin/admin_dashboard_screen.dart:50, 55`
- `lib/screens/mypage/admin/admin_statistics_screen.dart:37, 42`

**문제점**:
```dart
// Admin 화면에서 직접 쿼리
var query = SupabaseConfig.client.from('campaigns').select();
var query = SupabaseConfig.client.from('companies').select();
```

**권장 해결 방법**:
- Admin 전용 RPC 함수 사용
- 또는 Admin 역할 확인 후 RLS 정책에서 허용

**현재 상태**: ⚠️ Admin 전용이므로 RLS 정책으로 충분할 수 있음

---

### 3. 프론트엔드에서 UI 표시 제어 (허용 가능)

다음 항목들은 **UI/UX 목적**이므로 프론트엔드에서 체크하는 것이 허용됩니다. 다만, 실제 데이터 접근은 데이터베이스 레벨에서 제어되어야 합니다.

#### 3.1 `ProfileScreen._buildBusinessTab()`

**위치**: `lib/screens/mypage/common/profile_screen.dart:795, 815`

**코드**:
```dart
// 오너에게만 표시되는 정보
if (_isOwner == true && !_isLoadingOwner) ...[
  // 계좌정보 섹션 (오너만)
  AccountRegistrationForm(...),
  // 리뷰어 자동승인 설정 표시 (오너만)
  if (_existingCompanyData != null) ...[
    _buildAutoApproveReviewersToggle(),
  ],
],
```

**평가**: ✅ **허용 가능** - UI 표시 제어만 수행하며, 실제 데이터 접근은 RPC 함수에서 제어됨

---

#### 3.2 `PointsScreen` - 버튼 표시 제어

**위치**: `lib/screens/mypage/common/points_screen.dart:90, 318`

**코드**:
```dart
if (!_isOwner) {
  return Container(
    child: Text('입금/출금 권한이 없습니다. (대표만 가능)'),
  );
}
```

**평가**: ✅ **허용 가능** - UI 표시 제어만 수행하며, 실제 포인트 입출금은 RPC 함수에서 권한 체크

---

#### 3.3 `PointChargeScreen`, `PointRefundScreen`

**위치**:
- `lib/screens/mypage/common/point_charge_screen.dart:139`
- `lib/screens/mypage/common/point_refund_screen.dart:61`

**코드**:
```dart
final isOwner = await UserTypeHelper.isAdvertiserOwner(user.uid);
if (isOwner) {
  // owner인 경우에만 특정 로직 실행
}
```

**평가**: ✅ **허용 가능** - UI 로직 제어이며, 실제 포인트 입출금은 RPC 함수에서 권한 체크

---

#### 3.4 `MyPageRouteWrapper` - 라우팅 제어

**위치**: `lib/widgets/mypage_route_wrapper.dart:40`

**코드**:
```dart
if (user.userType != app_user.UserType.admin && !user.isAdvertiser) {
  // 광고주가 아니면 리뷰어로 리다이렉트
  context.go('/mypage/reviewer');
}
```

**평가**: ✅ **허용 가능** - 라우팅 제어만 수행하며, 실제 페이지 접근은 RPC 함수에서 권한 체크

---

#### 3.5 `AdvertiserDrawer` - 메뉴 표시 제어

**위치**: `lib/widgets/drawer/advertiser_drawer.dart:78, 90`

**코드**:
```dart
// 매니저 관리 (owner만 표시)
if (user.companyRole?.name == 'owner')
  _buildMenuItem(...),

// 리뷰어 관리 (owner만 표시)
if (user.companyRole?.name == 'owner')
  _buildMenuItem(...),
```

**평가**: ✅ **허용 가능** - UI 메뉴 표시 제어만 수행하며, 실제 페이지 접근은 RPC 함수에서 권한 체크

---

#### 3.6 `AppRouter` - 라우팅 제어

**위치**: `lib/config/app_router.dart:835`

**코드**:
```dart
} else if (user.isAdvertiser) {
  // 광고주 라우팅
}
```

**평가**: ✅ **허용 가능** - 라우팅 제어만 수행하며, 실제 페이지 접근은 RPC 함수에서 권한 체크

---

## 📊 요약

### 🔴 수정 필요 (데이터베이스 레벨로 이동)

| 항목 | 위치 | 우선순위 | 상태 |
|------|------|---------|------|
| `CompanyService.getAdvertiserCompanyByUserId()` | `lib/services/company_service.dart:9` | 높음 | ⚠️ 부분 수정 |
| `CompanyService.getPendingManagerRequest()` | `lib/services/company_service.dart:122` | 중간 | ⚠️ RLS 의존 |
| `CompanyService.cancelManagerRequest()` | `lib/services/company_service.dart:169` | 중간 | ⚠️ RLS 의존 |
| `ProfileScreen` 회사 검색 | `lib/screens/mypage/common/profile_screen.dart:1625` | 낮음 | ⚠️ RLS 의존 |
| `AdvertiserMyCampaignsScreen` 대체 로직 | `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart:605` | 높음 | ⚠️ 제거 권장 |
| `AdvertiserManagerScreen` 매니저 제거 | `lib/screens/mypage/advertiser/advertiser_manager_screen.dart:833` | 중간 | ⚠️ RLS 의존 |
| Admin 화면 직접 쿼리 | 여러 파일 | 낮음 | ⚠️ 검토 필요 |

### ✅ 허용 가능 (UI/UX 목적)

| 항목 | 위치 | 평가 |
|------|------|------|
| `ProfileScreen._buildBusinessTab()` | `lib/screens/mypage/common/profile_screen.dart:795` | ✅ UI 표시 제어 |
| `PointsScreen` 버튼 표시 | `lib/screens/mypage/common/points_screen.dart:318` | ✅ UI 표시 제어 |
| `PointChargeScreen`, `PointRefundScreen` | 각각의 파일 | ✅ UI 로직 제어 |
| `MyPageRouteWrapper` | `lib/widgets/mypage_route_wrapper.dart:40` | ✅ 라우팅 제어 |
| `AdvertiserDrawer` | `lib/widgets/drawer/advertiser_drawer.dart:78` | ✅ 메뉴 표시 제어 |
| `AppRouter` | `lib/config/app_router.dart:835` | ✅ 라우팅 제어 |

## 🎯 권장 조치사항

### 우선순위 높음

1. **`CompanyService.getAdvertiserCompanyByUserId()` 수정**
   - `get_advertiser_company_by_user_id` RPC 함수 직접 사용
   - 프론트엔드에서 역할 체크 제거

2. **`AdvertiserMyCampaignsScreen` 대체 로직 제거**
   - RPC 함수 실패 원인 해결
   - 대체 로직 완전 제거

### 우선순위 중간

3. **`CompanyService.getPendingManagerRequest()` RPC 함수화**
   - `get_pending_manager_request_safe(p_user_id)` RPC 함수 생성
   - 프론트엔드에서 직접 쿼리 제거

4. **`CompanyService.cancelManagerRequest()` RPC 함수화**
   - `cancel_manager_request_safe(p_user_id)` RPC 함수 생성
   - 프론트엔드에서 직접 삭제 제거

5. **`AdvertiserManagerScreen` 매니저 제거 RPC 함수화**
   - `remove_manager_safe(p_company_id, p_user_id, p_current_user_id)` RPC 함수 생성
   - 프론트엔드에서 직접 삭제 제거

### 우선순위 낮음

6. **`ProfileScreen` 회사 검색 RPC 함수화**
   - `search_companies_by_name(p_business_name, p_user_id)` RPC 함수 생성
   - 프론트엔드에서 직접 쿼리 제거

7. **Admin 화면 검토**
   - Admin 전용 RPC 함수 사용 검토
   - 또는 RLS 정책으로 충분한지 확인

## 📝 참고사항

### 허용 가능한 프론트엔드 체크

다음과 같은 경우는 프론트엔드에서 체크하는 것이 허용됩니다:

1. **UI 표시 제어**: 버튼, 메뉴, 섹션 표시/숨김
2. **라우팅 제어**: 페이지 접근 전 리다이렉트
3. **UX 최적화**: 불필요한 API 호출 방지

### 금지해야 하는 프론트엔드 체크

다음과 같은 경우는 반드시 데이터베이스 레벨에서 처리해야 합니다:

1. **데이터 필터링**: 역할/권한에 따른 데이터 필터링
2. **권한 체크**: 실제 데이터 접근 권한 확인
3. **직접 쿼리**: RPC 함수 없이 직접 테이블 쿼리

## 🔗 관련 문서

- [Reviewer 역할 회사 정보 표시 문제 해결](./fix-reviewer-company-info-display.md)
- [Schema 및 로직 분석](./schema-and-logic-analysis.md)
- [RPC 함수 Custom JWT 분석](./rpc-functions-custom-jwt-analysis.md)

## ✅ 체크리스트

- [x] 프론트엔드 하드코딩 로직 전수조사 완료
- [x] 문제점 식별 및 분류 완료
- [x] 권장 조치사항 정리 완료
- [ ] 우선순위 높음 항목 수정 (진행 중)
- [ ] 우선순위 중간 항목 수정
- [ ] 우선순위 낮음 항목 검토

