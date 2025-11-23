# 서비스 RLS 및 RPC 마이그레이션 구현 보고서

## 📋 개요

서비스 레이어의 보안 및 데이터 무결성을 강화하기 위해 Priority 1 항목들을 RPC 함수로 전환하는 작업을 완료했습니다.

**작업 일자:** 2025-11-24  
**마이그레이션 파일:** `supabase/migrations/20251124003836_add_rpc_functions_for_services.sql`

---

## ✅ 완료된 작업

### 1. WalletService RPC 전환

#### 생성된 RPC 함수
- `get_company_wallets_safe()`: 회사 지갑 목록 조회
- `get_company_wallet_by_company_id_safe(p_company_id)`: 특정 회사 지갑 조회
- `get_user_wallet_current_safe()`: 현재 사용자 개인 지갑 조회
- `get_user_point_history_safe(p_limit, p_offset)`: 개인 포인트 내역 조회

#### 수정된 Flutter 메서드
- `getUserWallet()`: RPC 함수 사용으로 변경
- `getCompanyWallets()`: RPC 함수 사용으로 변경
- `getCompanyWalletByCompanyId()`: RPC 함수 사용으로 변경
- `getUserPointHistory()`: RPC 함수 사용으로 변경
- `updateUserWalletAccount()`: fallback 제거, RPC만 사용
- `updateCompanyWalletAccount()`: fallback 제거, RPC만 사용

**보안 개선:**
- 모든 지갑 조회 시 권한 체크가 서버 측에서 수행됨
- 회사 지갑 조회 시 `company_users` 테이블을 통한 접근 권한 확인
- 계좌정보 업데이트 시 권한 체크가 RPC 함수 내부에서 수행됨

---

### 2. CampaignApplicationService RPC 전환

#### 생성된 RPC 함수
- `apply_to_campaign_safe(p_campaign_id, p_application_message)`: 캠페인 신청
- `get_user_applications_safe(p_status, p_limit, p_offset)`: 사용자 신청 내역 조회
- `get_campaign_applications_safe(p_campaign_id, p_status, p_limit, p_offset)`: 캠페인 신청자 목록 조회
- `update_application_status_safe(p_application_id, p_status, p_rejection_reason)`: 신청 상태 업데이트
- `cancel_application_safe(p_application_id)`: 신청 취소

#### 수정된 Flutter 메서드
- `applyToCampaign()`: RPC 함수 사용으로 변경
- `getUserApplications()`: RPC 함수 사용으로 변경, 페이지네이션 서버 측 처리
- `getCampaignApplications()`: RPC 함수 사용으로 변경, 권한 체크 서버 측 처리
- `updateApplicationStatus()`: RPC 함수 사용으로 변경
- `cancelApplication()`: RPC 함수 사용으로 변경

**보안 개선:**
- 캠페인 신청 시 중복 신청 체크가 서버 측에서 수행됨
- 신청 상태 업데이트 시 캠페인 소유자 권한 체크가 서버 측에서 수행됨
- 신청 취소 시 본인 확인이 서버 측에서 수행됨

---

### 3. ReviewService RPC 전환

#### 생성된 RPC 함수
- `create_review_safe(p_campaign_id, p_title, p_content, p_rating, p_review_url)`: 리뷰 작성
- `get_user_reviews_safe(p_status, p_limit, p_offset)`: 사용자 리뷰 목록 조회
- `get_campaign_reviews_safe(p_campaign_id, p_status, p_limit, p_offset)`: 캠페인 리뷰 목록 조회
- `update_review_status_safe(p_review_id, p_status, p_rejection_reason)`: 리뷰 상태 업데이트
- `update_review_safe(p_review_id, p_title, p_content, p_rating, p_review_url)`: 리뷰 수정
- `delete_review_safe(p_review_id)`: 리뷰 삭제

#### 수정된 Flutter 메서드
- `createReview()`: RPC 함수 사용으로 변경, 상태 체크 서버 측 처리
- `getUserReviews()`: RPC 함수 사용으로 변경, 페이지네이션 서버 측 처리
- `getCampaignReviews()`: RPC 함수 사용으로 변경
- `updateReviewStatus()`: RPC 함수 사용으로 변경, 권한 체크 서버 측 처리
- `updateReview()`: RPC 함수 사용으로 변경, 권한 체크 및 승인 상태 체크 서버 측 처리
- `deleteReview()`: RPC 함수 사용으로 변경, 권한 체크 및 승인 상태 체크 서버 측 처리

**보안 개선:**
- 리뷰 작성 시 캠페인 신청 상태 확인이 서버 측에서 수행됨
- 리뷰 수정/삭제 시 본인 확인 및 승인 상태 체크가 서버 측에서 수행됨
- 리뷰 상태 업데이트 시 캠페인 소유자 권한 체크가 서버 측에서 수행됨
- 리뷰 정보는 `action` JSONB 필드에 저장되어 스키마 변경 없이 확장 가능

---

### 4. AdminService RPC 전환

#### 생성된 RPC 함수
- `admin_get_users(p_search_query, p_user_type_filter, p_status_filter, p_limit, p_offset)`: 사용자 목록 조회
- `admin_get_users_count(p_search_query, p_user_type_filter, p_status_filter)`: 사용자 총 개수 조회
- `admin_update_user_status(p_target_user_id, p_status)`: 사용자 상태 변경

#### 수정된 Flutter 메서드
- `getUsers()`: RPC 함수 사용으로 변경, 복잡한 JOIN 쿼리 서버 측 처리
- `getUsersCount()`: RPC 함수 사용으로 변경
- `updateUserStatus()`: RPC 함수 사용으로 변경, 관리자 권한 체크 서버 측 처리

**보안 개선:**
- 모든 관리자 기능에 대해 관리자 권한 체크가 서버 측에서 수행됨
- 복잡한 JOIN 쿼리(`users`, `auth.users`, `company_users`, `sns_connections`)가 서버 측에서 처리되어 클라이언트 코드 단순화
- 검색 및 필터링 로직이 서버 측에서 처리되어 성능 향상

---

### 5. AccountDeletionService RPC 전환

#### 생성된 RPC 함수
- `check_deletion_eligibility_safe()`: 계정 삭제 가능 여부 확인
- `backup_user_data_safe()`: 계정 삭제 전 사용자 데이터 백업
- `is_account_deleted_safe()`: 계정 삭제 상태 확인
- `has_deletion_request_safe()`: 삭제 요청 상태 확인
- `cancel_deletion_request_safe()`: 계정 삭제 요청 취소

#### 수정된 Flutter 메서드
- `checkDeletionEligibility()`: RPC 함수 사용으로 변경
- `backupUserData()`: RPC 함수 사용으로 변경
- `isAccountDeleted()`: RPC 함수 사용으로 변경
- `hasDeletionRequest()`: RPC 함수 사용으로 변경
- `cancelDeletionRequest()`: RPC 함수 사용으로 변경

**보안 개선:**
- 계정 삭제 관련 모든 로직이 서버 측에서 처리됨
- 복잡한 데이터 조회 로직이 서버 측에서 처리되어 클라이언트 코드 단순화
- 데이터 백업 시 모든 관련 테이블 조회가 서버 측에서 수행됨

---

### 6. CompanyUserService RPC 전환

#### 생성된 RPC 함수
- `can_convert_to_advertiser_safe()`: 광고주 전환 권한 확인
- `get_user_company_role_safe()`: 사용자 회사 역할 조회
- `is_user_in_company_safe()`: 사용자 회사 소속 확인
- `get_user_company_id_safe()`: 사용자 회사 ID 조회

#### 수정된 Flutter 메서드
- `canConvertToAdvertiser()`: RPC 함수 사용으로 변경
- `getUserCompanyRole()`: RPC 함수 사용으로 변경
- `isUserInCompany()`: RPC 함수 사용으로 변경
- `getUserCompanyId()`: RPC 함수 사용으로 변경

**보안 개선:**
- 모든 회사 관련 권한 체크가 서버 측에서 수행됨
- `status='active'` 필터링이 서버 측에서 처리됨
- 현재 사용자 ID는 `auth.uid()`로 자동 확인되어 클라이언트에서 전달할 필요 없음

---

## 🔧 기술적 세부사항

### RPC 함수 설계 원칙

1. **SECURITY DEFINER**: 모든 RPC 함수는 `SECURITY DEFINER`로 설정하여 권한 체크를 서버 측에서 수행
2. **search_path 보호**: `SET "search_path" TO ''`로 SQL injection 공격 방지
3. **권한 체크**: 모든 함수에서 `auth.uid()`를 사용하여 현재 사용자 확인
4. **행 잠금**: UPDATE/DELETE 작업 시 `FOR UPDATE`를 사용하여 동시성 제어
5. **에러 처리**: 명확한 에러 메시지 반환

### 리뷰 데이터 저장 방식

`campaign_action_logs` 테이블의 `action` JSONB 필드를 사용하여 리뷰 정보를 저장:

```json
{
  "type": "review_submit",
  "data": {
    "title": "리뷰 제목",
    "content": "리뷰 내용",
    "rating": 5,
    "review_url": "https://...",
    "submitted_at": "2025-11-24T...",
    "approved_at": "2025-11-24T..." // 승인 시 추가
  }
}
```

이 방식의 장점:
- 스키마 변경 없이 리뷰 정보 저장 가능
- 기존 `status` 필드와 호환
- 확장 가능한 구조

### 페이지네이션

모든 목록 조회 함수에 `p_limit`과 `p_offset` 파라미터를 추가하여 서버 측 페이지네이션 구현:
- 클라이언트 측 필터링 제거
- 네트워크 트래픽 감소
- 성능 향상

---

## 📊 통계

### 생성된 RPC 함수
- **총 25개** RPC 함수 생성
- **6개 서비스** 전환 완료

### 수정된 Flutter 메서드
- **WalletService**: 6개 메서드
- **CampaignApplicationService**: 5개 메서드
- **ReviewService**: 6개 메서드
- **AdminService**: 3개 메서드
- **AccountDeletionService**: 5개 메서드
- **CompanyUserService**: 4개 메서드

**총 29개 메서드** 수정

---

## 🔒 보안 개선 사항

### Before (직접 쿼리)
- 클라이언트 측에서 권한 체크 수행
- 복잡한 JOIN 쿼리를 클라이언트에서 처리
- RLS에만 의존 (일부 케이스에서 불충분)

### After (RPC 함수)
- 모든 권한 체크가 서버 측에서 수행
- 복잡한 로직이 서버 측에서 처리
- `SECURITY DEFINER`로 일관된 권한 관리
- SQL injection 공격 방지 (`search_path` 보호)

---

## 🚀 성능 개선

1. **서버 측 페이지네이션**: 불필요한 데이터 전송 감소
2. **서버 측 필터링**: 클라이언트 측 처리 제거
3. **최적화된 JOIN 쿼리**: 서버 측에서 효율적인 쿼리 실행
4. **네트워크 트래픽 감소**: 필요한 데이터만 전송

---

## 📝 주의사항

### 리뷰 관련 상태 값
- `campaign_action_logs.status`는 `'pending'`, `'approved'`, `'rejected'`, `'completed'`, `'cancelled'`만 허용
- 리뷰 제출 시 `status`는 `'completed'`로 설정
- 리뷰 승인 여부는 `action.data.approved_at` 필드로 확인

### RPC 함수 호출 시 파라미터
- 모든 RPC 함수는 현재 사용자 ID를 `auth.uid()`로 자동 확인
- Flutter 코드에서 `userId` 파라미터를 전달할 필요 없음

---

## ✅ 테스트 권장 사항

1. **권한 테스트**
   - 각 RPC 함수의 권한 체크 동작 확인
   - 권한 없는 사용자의 접근 시도 시 에러 반환 확인

2. **데이터 무결성 테스트**
   - 동시성 제어 (행 잠금) 동작 확인
   - 트랜잭션 롤백 동작 확인

3. **페이지네이션 테스트**
   - 대량 데이터에서 페이지네이션 동작 확인
   - `limit`과 `offset` 파라미터 정확성 확인

4. **리뷰 기능 테스트**
   - 리뷰 작성/수정/삭제 동작 확인
   - `action` JSONB 필드 저장/조회 동작 확인

---

## 🔄 다음 단계 (Priority 2, 3)

로드맵 문서(`docs/services-rls-rpc-migration-roadmap.md`)에 명시된 Priority 2, 3 항목들을 순차적으로 진행할 수 있습니다:

- **Priority 2**: 성능 최적화 (RLS 정책 추가, 인덱스 최적화)
- **Priority 3**: 코드 정리 (중복 코드 제거, 일관성 개선)

---

## 📚 관련 문서

- [서비스 RLS 및 RPC 마이그레이션 로드맵](./services-rls-rpc-migration-roadmap.md)
- [Supabase RLS 문서](https://supabase.com/docs/guides/auth/row-level-security)
- [PostgreSQL RPC 함수 문서](https://www.postgresql.org/docs/current/xfunc.html)

---

**작업 완료일:** 2025-11-24  
**작업자:** AI Assistant  
**검토 상태:** 완료

