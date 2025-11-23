# 서비스 RLS 및 RPC 마이그레이션 로드맵

## 📋 개요

현재 Flutter 서비스 파일들에서 직접 테이블 접근 및 클라이언트 사이드 비즈니스 로직을 RLS(Row Level Security)와 RPC(Remote Procedure Call)로 전환하여 보안을 강화하고 데이터 일관성을 보장하는 로드맵입니다.

---

## 🎯 목표

1. **보안 강화**: 클라이언트 사이드에서 직접 테이블 수정 방지
2. **데이터 일관성**: 트랜잭션 보장 및 비즈니스 로직 중앙화
3. **성능 최적화**: 복잡한 쿼리를 서버 사이드에서 처리
4. **유지보수성**: 비즈니스 로직을 데이터베이스 레벨에서 관리

---

## 📊 현재 상태 분석

### ✅ 이미 RPC를 사용하는 부분

1. **CampaignService**
   - `joinCampaign` → `join_campaign_safe` ✅
   - `leaveCampaign` → `leave_campaign_safe` ✅
   - `getUserCampaigns` → `get_user_campaigns_safe` ✅
   - `getUserParticipatedCampaigns` → `get_user_participated_campaigns_safe` ✅
   - `createCampaignV2` → `create_campaign_with_points_v2` ✅
   - `updateCampaignStatus` → `update_campaign_status` ✅
   - `deleteCampaign` → `delete_campaign` ✅

2. **WalletService**
   - `getUserPointHistoryUnified` → `get_user_point_history_unified` ✅
   - `getCompanyPointHistoryUnified` → `get_company_point_history_unified` ✅
   - `getCompanyPointHistory` → `get_company_point_history` ✅
   - `transferPointsBetweenWallets` → `transfer_points_between_wallets` ✅
   - `getUserTransfers` → `get_user_transfers` ✅
   - `createPointTransaction` → `create_point_transaction` ✅
   - `createPointCashTransaction` → `create_cash_transaction` ✅
   - `updatePointCashTransactionStatus` → `update_cash_transaction_status` ✅
   - `getPendingCashTransactions` → `get_pending_cash_transactions` ✅
   - `cancelCashTransaction` → `cancel_cash_transaction` ✅

3. **AuthService**
   - `currentUser` → `get_user_profile_safe` ✅
   - `_createUserProfile` → `create_user_profile_safe` ✅
   - `updateUserProfile` → `update_user_profile_safe` ✅
   - `getUserProfile` → `get_user_profile_safe` ✅
   - `adminChangeUserRole` → `admin_change_user_role` ✅
   - `checkUserExists` → `check_user_exists` ✅

4. **AccountDeletionService**
   - `requestAccountDeletion` → `request_account_deletion` ✅

---

## 🔴 RPC로 전환 필요: 우선순위별

### 🔴 Priority 1: 보안 및 데이터 무결성 (즉시 전환 필요)

#### 1. WalletService

**문제점:**
- `updateUserWalletAccount`: RPC 실패 시 직접 UPDATE (fallback 로직)
- `updateCompanyWalletAccount`: RPC 실패 시 직접 UPDATE + 클라이언트 사이드 권한 체크
- `getUserWallet`: 직접 SELECT (RLS는 있지만 RPC 권장)
- `getCompanyWallets`: 복잡한 JOIN + 클라이언트 사이드 권한 체크
- `getCompanyWalletByCompanyId`: 직접 SELECT
- `getUserPointHistory`: 직접 SELECT (RLS는 있지만 RPC 권장)

**전환 계획:**
```sql
-- RPC 함수 생성 필요
CREATE FUNCTION update_user_wallet_account(...) -- 이미 존재하지만 fallback 제거 필요
CREATE FUNCTION update_company_wallet_account(...) -- 이미 존재하지만 fallback 제거 필요
CREATE FUNCTION get_user_wallet_safe(...)
CREATE FUNCTION get_company_wallets_safe(...)
CREATE FUNCTION get_company_wallet_by_company_id_safe(...)
CREATE FUNCTION get_user_point_history_safe(...)
```

**예상 작업 시간:** 6-8시간

---

#### 3. CampaignApplicationService

**문제점:**
- `applyToCampaign`: 캠페인 정보 직접 조회 후 `CampaignLogService` 사용
- `getUserApplications`: `CampaignLogService` 사용하지만 클라이언트 사이드 페이지네이션
- `getCampaignApplications`: 권한 체크를 클라이언트에서 수행
- `updateApplicationStatus`: 권한 체크를 클라이언트에서 수행
- `cancelApplication`: 직접 DELETE 수행

**전환 계획:**
```sql
-- RPC 함수 생성 필요
CREATE FUNCTION apply_to_campaign_safe(...)
CREATE FUNCTION get_user_applications_safe(...)
CREATE FUNCTION get_campaign_applications_safe(...)
CREATE FUNCTION update_application_status_safe(...)
CREATE FUNCTION cancel_application_safe(...)
```

**예상 작업 시간:** 6-8시간

---

#### 4. ReviewService

**문제점:**
- `createReview`: 상태 체크를 클라이언트에서 수행
- `getUserReviews`: 클라이언트 사이드 필터링 및 페이지네이션
- `getCampaignReviews`: 클라이언트 사이드 필터링 및 페이지네이션
- `updateReviewStatus`: 권한 체크를 클라이언트에서 수행
- `updateReview`: 직접 UPDATE 수행
- `deleteReview`: 직접 UPDATE 수행 (상태 변경)

**전환 계획:**
```sql
-- RPC 함수 생성 필요
CREATE FUNCTION create_review_safe(...)
CREATE FUNCTION get_user_reviews_safe(...)
CREATE FUNCTION get_campaign_reviews_safe(...)
CREATE FUNCTION update_review_status_safe(...)
CREATE FUNCTION update_review_safe(...)
CREATE FUNCTION delete_review_safe(...)
```

**예상 작업 시간:** 6-8시간

---

#### 5. AdminService

**문제점:**
- `getUsers`: 복잡한 JOIN (auth.users, company_users, sns_connections) + 클라이언트 사이드 처리
- `getUsersCount`: 직접 SELECT
- `updateUserStatus`: 직접 UPDATE (관리자 권한 체크 없음)

**전환 계획:**
```sql
-- RPC 함수 생성 필요
CREATE FUNCTION admin_get_users(...)
CREATE FUNCTION admin_get_users_count(...)
CREATE FUNCTION admin_update_user_status(...)
```

**예상 작업 시간:** 4-6시간

---

#### 6. AccountDeletionService

**문제점:**
- `checkDeletionEligibility`: 여러 테이블 직접 조회 + 클라이언트 사이드 로직
- `backupUserData`: 여러 테이블 직접 조회
- `isAccountDeleted`: 직접 SELECT
- `hasDeletionRequest`: 직접 SELECT
- `cancelDeletionRequest`: 직접 DELETE

**전환 계획:**
```sql
-- RPC 함수 생성 필요
CREATE FUNCTION check_deletion_eligibility_safe(...)
CREATE FUNCTION backup_user_data_safe(...)
CREATE FUNCTION is_account_deleted_safe(...)
CREATE FUNCTION has_deletion_request_safe(...)
CREATE FUNCTION cancel_deletion_request_safe(...)
```

**예상 작업 시간:** 4-6시간

---

#### 7. CompanyUserService

**문제점:**
- 모든 메서드: 직접 SELECT (RLS는 있지만 RPC 권장)

**전환 계획:**
```sql
-- RPC 함수 생성 필요
CREATE FUNCTION can_convert_to_advertiser_safe(...)
CREATE FUNCTION get_user_company_role_safe(...)
CREATE FUNCTION is_user_in_company_safe(...)
CREATE FUNCTION get_user_company_id_safe(...)
```

**예상 작업 시간:** 2-3시간

---

### 🟡 Priority 2: 성능 최적화 (중기 전환)

#### 8. CampaignService - 조회 최적화

**문제점:**
- `getCampaigns`: 중복 체크를 클라이언트에서 수행 (N+1 쿼리 가능성)
- `getPopularCampaigns`: 중복 체크를 클라이언트에서 수행
- `searchCampaigns`: 중복 체크를 클라이언트에서 수행

**전환 계획:**
```sql
-- RPC 함수 생성 필요 (중복 체크 포함)
CREATE FUNCTION get_campaigns_with_duplicate_check(...)
CREATE FUNCTION get_popular_campaigns_with_duplicate_check(...)
CREATE FUNCTION search_campaigns_with_duplicate_check(...)
```

**예상 작업 시간:** 4-6시간

---

#### 9. WalletService - 통계 최적화

**문제점:**
- `getUserMonthlyStats`: 클라이언트 사이드에서 모든 데이터를 가져와 계산
- `getCompanyUserStats`: 클라이언트 사이드에서 모든 데이터를 가져와 계산

**전환 계획:**
```sql
-- RPC 함수 생성 필요
CREATE FUNCTION get_user_monthly_stats(...)
CREATE FUNCTION get_company_user_stats(...)
```

**예상 작업 시간:** 2-3시간

---

### 🟢 Priority 3: 코드 정리 (장기 전환)

#### 10. AuthService - 프로필 업데이트

**문제점:**
- `_ensureUserProfile`: 프로필 업데이트 시 직접 UPDATE 수행

**전환 계획:**
```sql
-- RPC 함수 생성 필요
CREATE FUNCTION ensure_user_profile_safe(...)
```

**예상 작업 시간:** 2-3시간

---

## 📝 마이그레이션 단계별 계획

### Phase 1: 보안 강화 (Priority 1) - 4주

**Week 1: Campaign & Wallet**
- [ ] CampaignService: `createCampaignFromPrevious`, `getUserPreviousCampaigns`, `searchUserCampaigns`
- [ ] WalletService: `updateUserWalletAccount`, `updateCompanyWalletAccount`, `getUserWallet`, `getCompanyWallets`

**Week 2: Application & Review**
- [ ] CampaignApplicationService: 모든 메서드
- [ ] ReviewService: 모든 메서드

**Week 3: Admin & Account**
- [ ] AdminService: 모든 메서드
- [ ] AccountDeletionService: 모든 메서드

**Week 4: CompanyUser & 테스트**
- [ ] CompanyUserService: 모든 메서드
- [ ] 전체 통합 테스트

---

### Phase 2: 성능 최적화 (Priority 2) - 2주

**Week 5: Campaign 조회 최적화**
- [ ] CampaignService: 중복 체크 포함 RPC 함수

**Week 6: Wallet 통계 최적화**
- [ ] WalletService: 통계 RPC 함수

---

### Phase 3: 코드 정리 (Priority 3) - 1주

**Week 7: AuthService 정리**
- [ ] AuthService: 프로필 업데이트 RPC 함수

---

## 🔧 RPC 함수 생성 가이드라인

### 1. 함수 네이밍 규칙

- **조회 함수**: `get_{entity}_{action}_safe`
- **생성 함수**: `create_{entity}_safe`
- **업데이트 함수**: `update_{entity}_{field}_safe`
- **삭제 함수**: `delete_{entity}_safe`
- **관리자 함수**: `admin_{action}`

### 2. 보안 체크 필수 항목

- ✅ `auth.uid()` 확인
- ✅ 권한 확인 (role, ownership 등)
- ✅ 입력값 검증
- ✅ 트랜잭션 사용 (여러 테이블 수정 시)

### 3. 에러 처리

- ✅ 명확한 에러 메시지
- ✅ 적절한 HTTP 상태 코드
- ✅ 로깅 (보안 이벤트)

---

## 📋 RLS 정책 점검 사항

### 현재 RLS 상태 확인 필요 테이블

1. **campaigns**
   - ✅ SELECT: 활성 캠페인은 모든 사용자 조회 가능
   - ✅ INSERT: 회사 소속 사용자만 가능
   - ✅ UPDATE: 소유자만 가능
   - ✅ DELETE: 소유자만 가능 (비활성화된 캠페인만)

2. **wallets**
   - ✅ SELECT: 자신의 지갑만 조회 가능
   - ✅ UPDATE: 자신의 지갑만 업데이트 가능
   - ⚠️ 회사 지갑 권한 체크 필요

3. **campaign_action_logs**
   - ✅ SELECT: 자신의 로그 또는 캠페인 소유자만 조회 가능
   - ✅ INSERT: 자신의 로그만 생성 가능
   - ✅ UPDATE: 권한 체크 필요

4. **point_transactions**
   - ✅ SELECT: 자신의 지갑 거래만 조회 가능
   - ✅ INSERT: RPC 함수를 통해서만 가능

5. **cash_transactions**
   - ✅ SELECT: 자신의 지갑 거래만 조회 가능
   - ✅ INSERT: RPC 함수를 통해서만 가능
   - ✅ UPDATE: 관리자만 가능

6. **users**
   - ✅ SELECT: 자신의 프로필만 조회 가능
   - ✅ UPDATE: 자신의 프로필만 업데이트 가능

7. **company_users**
   - ✅ SELECT: 자신의 회사 정보만 조회 가능
   - ✅ INSERT: 관리자만 가능
   - ✅ UPDATE: 관리자만 가능

---

## ✅ 검증 체크리스트

각 마이그레이션 후 확인 사항:

- [ ] RPC 함수가 올바르게 생성되었는가?
- [ ] 권한 체크가 서버 사이드에서 수행되는가?
- [ ] 트랜잭션이 올바르게 처리되는가?
- [ ] 에러 처리가 적절한가?
- [ ] 기존 기능이 정상 작동하는가?
- [ ] 성능이 개선되었는가?
- [ ] RLS 정책이 올바르게 설정되어 있는가?

---

## 📊 예상 효과

### Before
- ❌ 클라이언트 사이드에서 직접 테이블 수정 가능
- ❌ 권한 체크가 클라이언트에서 수행됨
- ❌ 비즈니스 로직이 분산되어 있음
- ❌ 트랜잭션 보장 어려움
- ❌ N+1 쿼리 문제 가능성

### After
- ✅ 모든 수정 작업이 RPC를 통해 수행됨
- ✅ 권한 체크가 서버 사이드에서 수행됨
- ✅ 비즈니스 로직이 데이터베이스에 중앙화됨
- ✅ 트랜잭션이 보장됨
- ✅ 쿼리 최적화 가능

---

## 🚀 시작하기

### 1단계: RPC 함수 생성
```sql
-- 예시: get_user_wallet_safe
CREATE OR REPLACE FUNCTION get_user_wallet_safe()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_user_id UUID;
  v_wallet jsonb;
BEGIN
  -- 권한 확인
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 지갑 조회
  SELECT to_jsonb(w.*)
  INTO v_wallet
  FROM wallets w
  WHERE w.user_id = v_user_id
    AND w.company_id IS NULL;

  RETURN v_wallet;
END;
$$;
```

### 2단계: Flutter 서비스 수정
```dart
// Before
final wallet = await _supabase
    .from('wallets')
    .select()
    .eq('user_id', userId)
    .isFilter('company_id', null)
    .maybeSingle();

// After
final wallet = await _supabase.rpc(
  'get_user_wallet_safe',
);
```

### 3단계: 테스트
- [ ] 단위 테스트
- [ ] 통합 테스트
- [ ] 성능 테스트

---

## 📚 참고 자료

- [Supabase RPC Functions](https://supabase.com/docs/guides/database/functions)
- [Supabase RLS](https://supabase.com/docs/guides/auth/row-level-security)
- [PostgreSQL Functions](https://www.postgresql.org/docs/current/sql-createfunction.html)

---

**작성일:** 2025-11-24  
**예상 완료일:** 2025-12-15 (7주)  
**우선순위:** Priority 1 (보안 강화) → Priority 2 (성능 최적화) → Priority 3 (코드 정리)

