# RPC 함수 Custom JWT 세션 지원 분석 보고서

**작성일**: 2025년 12월 06일  
**작업자**: AI Assistant

---

## 📋 문제 개요

Custom JWT 세션을 사용하는 경우 (네이버 로그인), Supabase의 `auth.uid()`가 `NULL`이 되어 많은 RPC 함수들이 `Unauthorized` 에러를 발생시킵니다.

### 근본 원인

1. **함수 오버로딩 충돌**
   - 기존 함수: `get_user_wallet_current_safe()` (파라미터 없음)
   - 새 함수: `get_user_wallet_current_safe(p_user_id uuid DEFAULT NULL)` (파라미터 있음)
   - PostgreSQL은 DEFAULT 파라미터가 있어도 함수 시그니처가 다르면 오버로딩으로 인식하여 충돌 발생

2. **`auth.uid()` 의존성**
   - Custom JWT 세션에서는 Supabase의 `auth.uid()`가 `NULL`
   - `auth.uid()`를 사용하는 모든 RPC 함수가 Custom JWT 세션에서 작동하지 않음

---

## 🔍 문제가 있는 RPC 함수 분석

### 1. 즉시 수정 필요 (오버로딩 충돌)

#### 1.1 `get_user_wallet_current_safe()`
- **현재 상태**: 파라미터 없음 → `auth.uid()` 사용
- **문제**: 함수 오버로딩 충돌
- **사용 위치**: `lib/services/wallet_service.dart:24`
- **해결 방법**: 기존 함수 DROP 후 새 함수 CREATE

```sql
-- 기존 함수 삭제
DROP FUNCTION IF EXISTS "public"."get_user_wallet_current_safe"();

-- 새 함수 생성 (p_user_id 파라미터 추가)
CREATE OR REPLACE FUNCTION "public"."get_user_wallet_current_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") ...
```

---

### 2. Custom JWT 세션 지원 필요 (파라미터 없음)

#### 2.1 `get_company_wallets_safe()`
- **현재 상태**: 파라미터 없음 → `auth.uid()` 사용
- **문제**: Custom JWT 세션에서 `Unauthorized` 에러
- **사용 위치**: `lib/services/wallet_service.dart:65`
- **해결 방법**: `p_user_id` 파라미터 추가

```sql
CREATE OR REPLACE FUNCTION "public"."get_company_wallets_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") ...
```

#### 2.2 `get_user_company_id_safe()`
- **현재 상태**: 파라미터 없음 → `auth.uid()` 사용
- **문제**: Custom JWT 세션에서 `NULL` 반환
- **사용 위치**: `lib/services/company_user_service.dart:59`
- **해결 방법**: `p_user_id` 파라미터 추가

```sql
CREATE OR REPLACE FUNCTION "public"."get_user_company_id_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") ...
```

#### 2.3 `get_user_company_role_safe()`
- **현재 상태**: 파라미터 없음 → `auth.uid()` 사용
- **문제**: Custom JWT 세션에서 `NULL` 반환
- **사용 위치**: `lib/services/company_user_service.dart:28`
- **해결 방법**: `p_user_id` 파라미터 추가

```sql
CREATE OR REPLACE FUNCTION "public"."get_user_company_role_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") ...
```

#### 2.4 `get_user_reviewer_requests()`
- **현재 상태**: 파라미터 없음 → `auth.uid()` 사용
- **문제**: Custom JWT 세션에서 `Unauthorized` 에러
- **사용 위치**: `lib/services/company_service.dart:140`
- **해결 방법**: `p_user_id` 파라미터 추가

```sql
CREATE OR REPLACE FUNCTION "public"."get_user_reviewer_requests"("p_user_id" "uuid" DEFAULT NULL::"uuid") ...
```

---

### 3. Custom JWT 세션 지원 필요 (파라미터 있지만 `auth.uid()` 사용)

#### 3.1 `get_user_applications_safe(p_status, p_limit, p_offset)`
- **현재 상태**: `auth.uid()`로 사용자 ID 확인
- **문제**: Custom JWT 세션에서 `Unauthorized` 에러
- **사용 위치**: `lib/services/campaign_application_service.dart:70`
- **해결 방법**: `p_user_id` 파라미터 추가

```sql
CREATE OR REPLACE FUNCTION "public"."get_user_applications_safe"(
    "p_user_id" "uuid" DEFAULT NULL::"uuid",
    "p_status" "text" DEFAULT NULL::"text",
    "p_limit" integer DEFAULT 20,
    "p_offset" integer DEFAULT 0
) ...
```

#### 3.2 `get_user_reviews_safe(p_status, p_limit, p_offset)`
- **현재 상태**: `auth.uid()`로 사용자 ID 확인
- **문제**: Custom JWT 세션에서 `Unauthorized` 에러
- **사용 위치**: `lib/services/review_service.dart:75`
- **해결 방법**: `p_user_id` 파라미터 추가

```sql
CREATE OR REPLACE FUNCTION "public"."get_user_reviews_safe"(
    "p_user_id" "uuid" DEFAULT NULL::"uuid",
    "p_status" "text" DEFAULT NULL::"text",
    "p_limit" integer DEFAULT 20,
    "p_offset" integer DEFAULT 0
) ...
```

#### 3.3 `get_user_point_history_safe(p_limit, p_offset)`
- **현재 상태**: `auth.uid()`로 사용자 ID 확인
- **문제**: Custom JWT 세션에서 `Unauthorized` 에러
- **사용 위치**: `lib/services/wallet_service.dart:164`
- **해결 방법**: `p_user_id` 파라미터 추가

```sql
CREATE OR REPLACE FUNCTION "public"."get_user_point_history_safe"(
    "p_user_id" "uuid" DEFAULT NULL::"uuid",
    "p_limit" integer DEFAULT 50,
    "p_offset" integer DEFAULT 0
) ...
```

---

### 4. 권한 체크에서 `auth.uid()` 사용 (부분 수정 필요)

#### 4.1 `get_user_profile_safe(p_user_id)`
- **현재 상태**: `p_user_id` 파라미터 있음, 권한 체크에서 `auth.uid()` 사용
- **문제**: Custom JWT 세션에서 권한 체크 실패
- **사용 위치**: `lib/services/auth_service.dart:54, 96, 153, 446, 604`
- **해결 방법**: Custom JWT 세션인 경우 권한 체크 건너뛰기 (이미 수정됨)

#### 4.2 `get_user_campaigns_safe(p_user_id, ...)`
- **현재 상태**: `p_user_id` 파라미터 있음, 권한 체크에서 `auth.uid()` 사용
- **문제**: Custom JWT 세션에서 권한 체크 실패
- **사용 위치**: `lib/services/campaign_service.dart:403`
- **해결 방법**: Custom JWT 세션인 경우 권한 체크 건너뛰기

#### 4.3 `get_user_point_logs_safe(p_user_id, ...)`
- **현재 상태**: `p_user_id` 파라미터 있음, 권한 체크에서 `auth.uid()` 사용
- **문제**: Custom JWT 세션에서 권한 체크 실패
- **사용 위치**: 직접 사용 안 함 (확인 필요)
- **해결 방법**: Custom JWT 세션인 경우 권한 체크 건너뛰기

#### 4.4 `get_user_wallet_safe(p_user_id)`
- **현재 상태**: `p_user_id` 파라미터 있음, 권한 체크에서 `auth.uid()` 사용
- **문제**: Custom JWT 세션에서 권한 체크 실패
- **사용 위치**: 직접 사용 안 함 (확인 필요)
- **해결 방법**: Custom JWT 세션인 경우 권한 체크 건너뛰기

---

### 5. 기타 함수들 (우선순위 낮음)

#### 5.1 `get_company_wallet_by_company_id_safe(p_company_id)`
- **현재 상태**: `auth.uid()`로 권한 확인
- **문제**: Custom JWT 세션에서 `Unauthorized` 에러
- **사용 위치**: `lib/services/wallet_service.dart:96`
- **해결 방법**: `p_user_id` 파라미터 추가

#### 5.2 `is_account_deleted_safe()`
- **현재 상태**: 파라미터 없음 → `auth.uid()` 사용
- **문제**: Custom JWT 세션에서 `false` 반환 (에러는 없음)
- **사용 위치**: `lib/services/account_deletion_service.dart:92`
- **해결 방법**: `p_user_id` 파라미터 추가

#### 5.3 `has_deletion_request_safe()`
- **현재 상태**: 파라미터 없음 → `auth.uid()` 사용
- **문제**: Custom JWT 세션에서 `false` 반환 (에러는 없음)
- **사용 위치**: `lib/services/account_deletion_service.dart:110`
- **해결 방법**: `p_user_id` 파라미터 추가

#### 5.4 `is_user_in_company_safe()`
- **현재 상태**: 파라미터 없음 → `auth.uid()` 사용
- **문제**: Custom JWT 세션에서 `false` 반환 (에러는 없음)
- **사용 위치**: `lib/services/company_user_service.dart:43`
- **해결 방법**: `p_user_id` 파라미터 추가

#### 5.5 `can_convert_to_advertiser_safe()`
- **현재 상태**: 파라미터 없음 → `auth.uid()` 사용
- **문제**: Custom JWT 세션에서 에러 가능성
- **사용 위치**: `lib/services/company_user_service.dart:12`
- **해결 방법**: `p_user_id` 파라미터 추가

#### 5.6 `check_deletion_eligibility_safe()`
- **현재 상태**: 파라미터 없음 → `auth.uid()` 사용
- **문제**: Custom JWT 세션에서 에러 가능성
- **사용 위치**: `lib/services/account_deletion_service.dart:43`
- **해결 방법**: `p_user_id` 파라미터 추가

#### 5.7 `backup_user_data_safe()`
- **현재 상태**: 파라미터 없음 → `auth.uid()` 사용
- **문제**: Custom JWT 세션에서 에러 가능성
- **사용 위치**: `lib/services/account_deletion_service.dart:70`
- **해결 방법**: `p_user_id` 파라미터 추가

#### 5.8 `cancel_deletion_request_safe()`
- **현재 상태**: 파라미터 없음 → `auth.uid()` 사용
- **문제**: Custom JWT 세션에서 에러 가능성
- **사용 위치**: `lib/services/account_deletion_service.dart:132`
- **해결 방법**: `p_user_id` 파라미터 추가

---

## 📊 우선순위별 수정 계획

### 🔴 긴급 (즉시 수정 필요)

1. **`get_user_wallet_current_safe()`** - 오버로딩 충돌 해결
2. **`get_company_wallets_safe()`** - 지갑 조회 실패
3. **`get_user_profile_safe()`** - 프로필 조회 실패 (이미 수정됨)

### 🟡 높음 (주요 기능 영향)

4. **`get_user_applications_safe()`** - 캠페인 신청 내역 조회
5. **`get_user_reviews_safe()`** - 리뷰 목록 조회
6. **`get_user_point_history_safe()`** - 포인트 내역 조회
7. **`get_user_company_id_safe()`** - 회사 ID 조회
8. **`get_user_company_role_safe()`** - 회사 역할 조회

### 🟢 중간 (기능 영향 있음)

9. **`get_user_reviewer_requests()`** - 리뷰어 요청 조회
10. **`get_company_wallet_by_company_id_safe()`** - 회사 지갑 조회
11. **`get_user_campaigns_safe()`** - 사용자 캠페인 조회 (권한 체크 수정)

### 🔵 낮음 (선택적 수정)

12. **`is_account_deleted_safe()`** - 계정 삭제 확인
13. **`has_deletion_request_safe()`** - 삭제 요청 확인
14. **`is_user_in_company_safe()`** - 회사 소속 확인
15. **`can_convert_to_advertiser_safe()`** - 광고주 전환 가능 여부
16. **`check_deletion_eligibility_safe()`** - 삭제 자격 확인
17. **`backup_user_data_safe()`** - 데이터 백업
18. **`cancel_deletion_request_safe()`** - 삭제 요청 취소

---

## 🔧 수정 방법

### 방법 1: 함수 오버로딩 충돌 해결

```sql
-- 기존 함수 삭제
DROP FUNCTION IF EXISTS "public"."get_user_wallet_current_safe"();

-- 새 함수 생성 (p_user_id 파라미터 추가)
CREATE OR REPLACE FUNCTION "public"."get_user_wallet_current_safe"(
    "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
...
```

### 방법 2: 파라미터 추가 및 `auth.uid()` 대체

```sql
CREATE OR REPLACE FUNCTION "public"."get_user_applications_safe"(
    "p_user_id" "uuid" DEFAULT NULL::"uuid",
    "p_status" "text" DEFAULT NULL::"text",
    "p_limit" integer DEFAULT 20,
    "p_offset" integer DEFAULT 0
) RETURNS "jsonb"
...
DECLARE
    v_user_id UUID;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    ...
```

### 방법 3: 권한 체크 로직 수정

```sql
-- Custom JWT 세션인 경우 (p_user_id가 전달되고 auth.uid()가 NULL) 권한 체크 건너뛰기
IF v_target_user_id IS NOT NULL AND v_current_user_id IS NOT NULL AND v_target_user_id != v_current_user_id THEN
    -- 권한 체크 수행
END IF;
```

---

## 📝 수정 체크리스트

### 즉시 수정 필요
- [ ] `get_user_wallet_current_safe()` - 오버로딩 충돌 해결
- [ ] `get_company_wallets_safe()` - `p_user_id` 파라미터 추가
- [x] `get_user_profile_safe()` - 권한 체크 로직 수정 (완료)

### 주요 기능
- [ ] `get_user_applications_safe()` - `p_user_id` 파라미터 추가
- [ ] `get_user_reviews_safe()` - `p_user_id` 파라미터 추가
- [ ] `get_user_point_history_safe()` - `p_user_id` 파라미터 추가
- [ ] `get_user_company_id_safe()` - `p_user_id` 파라미터 추가
- [ ] `get_user_company_role_safe()` - `p_user_id` 파라미터 추가

### 기타 함수
- [ ] `get_user_reviewer_requests()` - `p_user_id` 파라미터 추가
- [ ] `get_company_wallet_by_company_id_safe()` - `p_user_id` 파라미터 추가
- [ ] `get_user_campaigns_safe()` - 권한 체크 로직 수정
- [ ] `get_user_point_logs_safe()` - 권한 체크 로직 수정
- [ ] `get_user_wallet_safe()` - 권한 체크 로직 수정

---

## 🎯 결론

**총 18개의 RPC 함수**가 Custom JWT 세션 지원이 필요합니다.

1. **즉시 수정 필요**: 3개 (오버로딩 충돌 및 주요 기능)
2. **높은 우선순위**: 5개 (주요 기능 영향)
3. **중간 우선순위**: 3개 (기능 영향 있음)
4. **낮은 우선순위**: 7개 (선택적 수정)

모든 함수를 수정하면 Custom JWT 세션에서도 모든 기능이 정상 작동합니다.

