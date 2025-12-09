# Custom JWT 세션 미지원 RPC 함수 목록

**작성일**: 2025년 12월 09일  
**상태**: 아직 Custom JWT 세션을 지원하지 않는 함수들

---

## 🔴 즉시 수정 필요 (Flutter에서 사용 중)

### 1. `activate_manager_role`
- **위치**: `lib/services/company_user_service.dart:110`
- **문제**: `auth.uid()` 직접 사용
- **수정 방법**: `p_current_user_id uuid DEFAULT NULL` 파라미터 추가

### 2. `activate_reviewer_role`
- **위치**: `lib/screens/mypage/advertiser/advertiser_reviewer_screen.dart:243`
- **문제**: `auth.uid()` 직접 사용
- **수정 방법**: `p_current_user_id uuid DEFAULT NULL` 파라미터 추가

### 3. `approve_reviewer_role`
- **위치**: `lib/screens/mypage/advertiser/advertiser_reviewer_screen.dart:113`
- **문제**: `auth.uid()` 직접 사용
- **수정 방법**: `p_current_user_id uuid DEFAULT NULL` 파라미터 추가

### 4. `deactivate_manager_role`
- **위치**: `lib/services/company_user_service.dart:86`
- **문제**: `auth.uid()` 직접 사용
- **수정 방법**: `p_current_user_id uuid DEFAULT NULL` 파라미터 추가

### 5. `deactivate_reviewer_role`
- **위치**: `lib/screens/mypage/advertiser/advertiser_reviewer_screen.dart:209`
- **문제**: `auth.uid()` 직접 사용
- **수정 방법**: `p_current_user_id uuid DEFAULT NULL` 파라미터 추가

---

## 🟡 수정 권장 (사용 가능성 있음)

### 6. `create_campaign_with_points`
- **문제**: `auth.uid()` 직접 사용
- **수정 방법**: `p_user_id uuid DEFAULT NULL` 파라미터 추가

### 7. `create_campaign_with_points_v2` (모든 버전)
- **문제**: `auth.uid()` 직접 사용
- **수정 방법**: `p_user_id uuid DEFAULT NULL` 파라미터 추가

### 8. `delete_company`
- **문제**: `auth.uid()` 직접 사용
- **수정 방법**: `p_user_id uuid DEFAULT NULL` 파라미터 추가

### 9. `cancel_cash_transaction`
- **문제**: `auth.uid()` 직접 사용
- **수정 방법**: `p_user_id uuid DEFAULT NULL` 파라미터 추가

### 10. `cancel_deletion_request_safe`
- **문제**: `auth.uid()` 직접 사용
- **수정 방법**: `p_user_id uuid DEFAULT NULL` 파라미터 추가

### 11. `check_deletion_eligibility_safe`
- **문제**: `auth.uid()` 직접 사용
- **수정 방법**: `p_user_id uuid DEFAULT NULL` 파라미터 추가

### 12. `backup_user_data_safe`
- **문제**: `auth.uid()` 직접 사용
- **수정 방법**: `p_user_id uuid DEFAULT NULL` 파라미터 추가

### 13. `can_convert_to_advertiser_safe()` (파라미터 없음 버전)
- **문제**: `auth.uid()` 직접 사용, 오버로딩 충돌 가능성
- **수정 방법**: 기존 함수 DROP 후 파라미터 있는 버전만 유지

---

## 🟢 우선순위 낮음 (관리자 전용)

### 14. `admin_change_user_role`
- **문제**: `auth.uid()` 직접 사용
- **참고**: 관리자 전용 함수이므로 Custom JWT 필요 없을 수도 있음

### 15. `admin_get_users`
- **문제**: `auth.uid()` 직접 사용
- **참고**: 관리자 전용 함수이므로 Custom JWT 필요 없을 수도 있음

### 16. `admin_get_users_count`
- **문제**: `auth.uid()` 직접 사용
- **참고**: 관리자 전용 함수이므로 Custom JWT 필요 없을 수도 있음

### 17. `admin_update_user_status`
- **문제**: `auth.uid()` 직접 사용
- **참고**: 관리자 전용 함수이므로 Custom JWT 필요 없을 수도 있음

---

## 📝 수정 패턴

### 패턴 1: 권한 체크가 필요한 함수 (activate/deactivate/approve)

```sql
CREATE OR REPLACE FUNCTION "public"."activate_manager_role"(
    "p_company_id" "uuid", 
    "p_user_id" "uuid",
    "p_current_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
...
DECLARE
  v_current_user_id uuid;
  v_result jsonb;
BEGIN
  -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
  v_current_user_id := COALESCE(p_current_user_id, (SELECT auth.uid()));
  
  IF v_current_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Must be logged in';
  END IF;
  
  -- 권한 확인: 회사 소유자만 활성화 가능
  IF NOT EXISTS (
    SELECT 1 FROM public.company_users cu
    WHERE cu.company_id = p_company_id
      AND cu.user_id = v_current_user_id
      AND cu.company_role = 'owner'
      AND cu.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Only company owners can activate managers';
  END IF;
  ...
```

### 패턴 2: 사용자 ID만 필요한 함수 (create/delete)

```sql
CREATE OR REPLACE FUNCTION "public"."create_campaign_with_points"(
    ...,
    "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
...
DECLARE
  v_user_id UUID;
  ...
BEGIN
  -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
  v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  ...
```

---

## ✅ 이미 지원하는 함수들

- `get_company_reviewers` ✅ (방금 수정 완료)
- `get_company_wallet_by_company_id_safe` ✅
- `get_company_point_history_unified` ✅
- `get_user_profile_safe` ✅
- `get_user_wallet_current_safe` ✅
- `get_company_wallets_safe` ✅
- `get_user_company_id_safe` ✅
- `get_user_company_role_safe` ✅
- `get_user_reviewer_requests` ✅
- `get_user_applications_safe` ✅
- `get_user_reviews_safe` ✅
- `get_user_point_history_safe` ✅
- `apply_to_campaign_safe` ✅
- `cancel_application_safe` ✅
- `cancel_manager_request_safe` ✅
- `create_review_safe` ✅
- `delete_review_safe` ✅
- `delete_campaign` ✅
- `update_application_status_safe` ✅
- `update_review_safe` ✅
- `get_campaign_applications_safe` ✅
- `get_user_campaigns_safe` ✅
- `get_advertiser_company_by_user_id` ✅
- `get_company_by_user_id_safe` ✅
- `get_company_managers` ✅
- `get_pending_manager_request_safe` ✅
- `approve_manager` ✅ (이미 `p_current_user_id` 지원)

---

## 🎯 다음 단계

1. **즉시 수정 필요 함수들 (1-5번)** 수정
2. **수정 권장 함수들 (6-13번)** 수정
3. **관리자 전용 함수들 (14-17번)** 검토 후 필요시 수정

