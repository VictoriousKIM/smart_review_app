# 포인트 중복 차감 문제 상세 분석 및 해결책

## 📋 문제 요약

**증상**: 
- 캠페인 생성 시 `total_cost`가 153,000인데 지갑에서는 306,000이 차감됨 (2배 차감)
- 지갑 ID: `da5d8db7-62f2-4d5c-bdf1-bce3f38c175e`

**영향**: 
- 사용자 포인트가 실제보다 2배 더 많이 차감되어 심각한 문제
- 재현 가능성이 높으면 많은 사용자에게 영향

---

## 🔍 원인 분석

### 가능한 원인 시나리오

#### 1. RPC 함수가 두 번 호출됨 (가장 유력)

**증상**:
- 클라이언트에서 `createCampaignV2`가 중복 호출됨
- 버튼 더블 클릭 또는 네트워크 재시도로 인한 중복 호출

**확인 방법**:
- Flutter 코드에서 중복 호출 방지 로직 확인
- `_isCreatingCampaign` 플래그가 제대로 작동하는지 확인
- 네트워크 에러 시 재시도 로직 확인

**현재 코드 상태**:
```dart
// lib/screens/campaign/campaign_creation_screen.dart
bool _isCreatingCampaign = false;

Future<void> _createCampaign() async {
  if (_isCreatingCampaign) return;  // 중복 호출 방지
  
  setState(() {
    _isCreatingCampaign = true;
  });
  
  try {
    // ... 캠페인 생성 로직 ...
  } finally {
    setState(() {
      _isCreatingCampaign = false;
    });
  }
}
```

**문제점**:
- `setState`는 비동기적으로 작동하므로, 빠른 연속 클릭 시 `_isCreatingCampaign`이 `true`로 설정되기 전에 두 번째 호출이 들어올 수 있음
- 네트워크 타임아웃 후 재시도 시 중복 호출 가능

---

#### 2. 트랜잭션 롤백 실패

**증상**:
- 첫 번째 호출이 실패했지만 포인트는 차감됨
- 두 번째 호출이 성공하여 다시 차감됨

**확인 방법**:
- `point_transactions` 테이블에서 동일한 `campaign_id`에 대한 중복 레코드 확인
- `created_at` 시간 차이 확인

**현재 RPC 함수 상태**:
```sql
-- supabase/migrations/20251116094855_fix_critical_campaign_issues.sql
BEGIN
  -- 포인트 차감
  UPDATE public.wallets
  SET current_points = current_points - v_total_cost
  WHERE id = v_wallet_id;
  
  -- 캠페인 생성
  INSERT INTO public.campaigns (...);
  
  -- 포인트 로그 기록
  INSERT INTO public.point_transactions (...);
  
  RETURN v_result;
EXCEPTION WHEN OTHERS THEN
  RAISE;  -- 롤백은 자동으로 됨
END;
```

**문제점**:
- PostgreSQL 함수는 자동으로 트랜잭션으로 실행되지만, 명시적인 `BEGIN ... COMMIT`이 없음
- 에러 발생 시 롤백이 되지만, 클라이언트에서 에러를 받지 못하면 재시도 가능

---

#### 3. 낙관적 잠금이 제대로 작동하지 않음

**현재 코드**:
```sql
-- 포인트 차감 전 잔액 저장
v_points_before_deduction := v_current_points;

-- 포인트 차감 (낙관적 잠금)
UPDATE public.wallets
SET current_points = current_points - v_total_cost
WHERE id = v_wallet_id
  AND current_points = v_points_before_deduction;  -- 낙관적 잠금

IF NOT FOUND THEN
  RAISE EXCEPTION '포인트 잔액이 변경되었습니다...';
END IF;
```

**문제점**:
- 두 개의 동시 요청이 같은 `v_points_before_deduction` 값을 읽으면 둘 다 업데이트 성공 가능
- `FOR UPDATE`를 사용했지만, 실제 UPDATE 시점에는 잠금이 해제됨

---

#### 4. 마이그레이션 파일 중복 적용

**확인 필요**:
- `20251116094855_fix_critical_campaign_issues.sql`과 `20251116095027_add_product_name_price_remove_payment_amount.sql`에서 포인트 차감 로직이 중복되어 있는지 확인
- 두 마이그레이션 모두 `create_campaign_with_points_v2` 함수를 재정의하는지 확인

---

## 🛠️ 해결 방안

### 해결책 1: 클라이언트 측 중복 호출 방지 강화 (즉시 적용)

**목표**: 버튼 클릭 시 중복 호출을 완전히 방지

**구현**:

```dart
// lib/screens/campaign/campaign_creation_screen.dart
bool _isCreatingCampaign = false;
String? _lastCampaignCreationId;  // ✅ 추가: 마지막 생성 시도 ID

Future<void> _createCampaign() async {
  // ✅ 즉시 체크 (setState 전에)
  if (_isCreatingCampaign) {
    debugPrint('⚠️ 캠페인 생성이 이미 진행 중입니다.');
    return;
  }
  
  // ✅ 생성 시도 ID 생성 (중복 방지용)
  final creationId = DateTime.now().millisecondsSinceEpoch.toString();
  if (_lastCampaignCreationId == creationId) {
    debugPrint('⚠️ 동일한 생성 시도가 감지되었습니다.');
    return;
  }
  _lastCampaignCreationId = creationId;
  
  // ✅ 즉시 플래그 설정 (setState 전에)
  _isCreatingCampaign = true;
  
  setState(() {
    _isCreatingCampaign = true;
    _errorMessage = null;
  });
  
  try {
    // ... 캠페인 생성 로직 ...
    
    if (response.success) {
      // ✅ 성공 시 즉시 플래그 해제
      _isCreatingCampaign = false;
      _lastCampaignCreationId = null;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? '캠페인이 생성되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/mypage/advertiser/my-campaigns?refresh=true');
      }
    }
  } catch (e) {
    // ✅ 에러 시에도 플래그 해제
    _isCreatingCampaign = false;
    _lastCategoryCreationId = null;
    
    setState(() {
      _errorMessage = '예상치 못한 오류: $e';
    });
  } finally {
    // ✅ 최종적으로 플래그 해제
    if (mounted) {
      setState(() {
        _isCreatingCampaign = false;
      });
    }
  }
}

// ✅ 버튼 비활성화 강화
bool _canCreateCampaign() {
  return !_isCreatingCampaign &&  // 생성 중이 아니어야 함
         !_isUploadingImage &&     // 이미지 업로드 중이 아니어야 함
         // ... 기존 검증 로직 ...
}
```

**추가 개선**:
- 버튼에 `AbsorbPointer` 또는 `IgnorePointer` 위젯 사용
- 디바운싱 적용 (500ms 이내 중복 클릭 무시)

---

### 해결책 2: RPC 함수에 Idempotency Key 추가 (권장)

**목표**: 동일한 요청이 두 번 실행되어도 한 번만 차감되도록 보장

**구현**:

```sql
-- supabase/migrations/YYYYMMDDHHMMSS_add_idempotency_to_campaign_creation.sql

-- Idempotency 테이블 생성 (선택사항)
CREATE TABLE IF NOT EXISTS public.campaign_creation_requests (
  idempotency_key TEXT PRIMARY KEY,
  campaign_id UUID,
  wallet_id UUID,
  amount INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '1 hour'
);

-- 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_campaign_creation_requests_expires_at 
ON public.campaign_creation_requests(expires_at);

-- 만료된 레코드 정리 함수 (선택사항)
CREATE OR REPLACE FUNCTION public.cleanup_expired_idempotency_keys()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM public.campaign_creation_requests
  WHERE expires_at < NOW();
END;
$$;

-- RPC 함수 수정
CREATE OR REPLACE FUNCTION "public"."create_campaign_with_points_v2"(
  -- ... 기존 파라미터들 ...
  "p_idempotency_key" TEXT DEFAULT NULL  -- ✅ 추가
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  -- ... 기존 변수들 ...
  v_existing_campaign_id UUID;
BEGIN
  -- ✅ Idempotency 체크
  IF p_idempotency_key IS NOT NULL THEN
    SELECT campaign_id INTO v_existing_campaign_id
    FROM public.campaign_creation_requests
    WHERE idempotency_key = p_idempotency_key
      AND expires_at > NOW();
    
    IF v_existing_campaign_id IS NOT NULL THEN
      -- 이미 처리된 요청이면 기존 결과 반환
      SELECT jsonb_build_object(
        'success', true,
        'campaign_id', v_existing_campaign_id,
        'message', '이미 처리된 요청입니다.',
        'is_duplicate', true
      ) INTO v_result;
      RETURN v_result;
    END IF;
  END IF;
  
  -- ... 기존 로직 ...
  
  -- ✅ Idempotency 키 저장 (성공 시)
  IF p_idempotency_key IS NOT NULL THEN
    INSERT INTO public.campaign_creation_requests (
      idempotency_key, campaign_id, wallet_id, amount
    ) VALUES (
      p_idempotency_key, v_campaign_id, v_wallet_id, v_total_cost
    ) ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;
  
  RETURN v_result;
  
EXCEPTION WHEN OTHERS THEN
  RAISE;
END;
$$;
```

**Flutter 코드 수정**:

```dart
// lib/services/campaign_service.dart
Future<ApiResponse<Campaign>> createCampaignV2({
  // ... 기존 파라미터들 ...
  String? idempotencyKey,  // ✅ 추가
}) async {
  // Idempotency 키 생성 (없으면 자동 생성)
  final key = idempotencyKey ?? 
    '${user.id}_${DateTime.now().millisecondsSinceEpoch}';
  
  final response = await _supabase.rpc(
    'create_campaign_with_points_v2',
    params: {
      // ... 기존 파라미터들 ...
      'p_idempotency_key': key,  // ✅ 추가
    },
  );
  
  // 중복 요청인 경우 처리
  if (response['is_duplicate'] == true) {
    final campaignId = response['campaign_id'];
    // 기존 캠페인 조회
    final campaignData = await _supabase
        .from('campaigns')
        .select()
        .eq('id', campaignId)
        .single();
    
    return ApiResponse<Campaign>(
      success: true,
      data: Campaign.fromJson(campaignData),
      message: '이미 생성된 캠페인입니다.',
    );
  }
  
  // ... 기존 로직 ...
}
```

---

### 해결책 3: RPC 함수에 명시적 트랜잭션 및 더 강력한 잠금 (권장)

**목표**: 데이터베이스 레벨에서 중복 차감 방지

**구현**:

```sql
-- supabase/migrations/YYYYMMDDHHMMSS_improve_point_deduction_atomicity.sql

CREATE OR REPLACE FUNCTION "public"."create_campaign_with_points_v2"(
  -- ... 기존 파라미터들 ...
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  -- ... 기존 변수들 ...
  v_points_after_deduction INTEGER;
BEGIN
  -- ✅ 명시적 트랜잭션 시작
  BEGIN
    -- 1. 현재 사용자
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
      RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 2. 사용자의 활성 회사 조회
    SELECT cu.company_id INTO v_company_id
    FROM public.company_users cu
    WHERE cu.user_id = v_user_id
      AND cu.status = 'active'
      AND cu.company_role IN ('owner', 'manager')
    LIMIT 1;
    
    IF v_company_id IS NULL THEN
      RAISE EXCEPTION '회사에 소속되지 않았습니다';
    END IF;
    
    -- 3. 총 비용 계산
    v_total_cost := public.calculate_campaign_cost(
      p_payment_method,
      COALESCE(p_product_price, 0),
      p_review_reward,
      p_max_participants
    );
    
    -- 4. 회사 지갑 조회 및 잠금 (FOR UPDATE로 배타적 잠금)
    SELECT cw.id, cw.current_points 
    INTO v_wallet_id, v_current_points
    FROM public.wallets AS cw
    WHERE cw.company_id = v_company_id
      AND cw.user_id IS NULL
    FOR UPDATE NOWAIT;  -- ✅ NOWAIT: 잠금 대기하지 않고 즉시 실패
    
    IF v_wallet_id IS NULL OR v_current_points IS NULL THEN
      RAISE EXCEPTION '회사 지갑이 없습니다';
    END IF;
    
    -- 5. 잔액 확인
    IF v_current_points < v_total_cost THEN
      RAISE EXCEPTION '포인트가 부족합니다 (필요: %, 보유: %)', 
        v_total_cost, v_current_points;
    END IF;
    
    -- 6. 포인트 차감 (원자적 연산)
    UPDATE public.wallets
    SET current_points = current_points - v_total_cost,
        updated_at = NOW()
    WHERE id = v_wallet_id;
    
    -- ✅ 차감 후 잔액 확인 (검증)
    SELECT current_points INTO v_points_after_deduction
    FROM public.wallets
    WHERE id = v_wallet_id;
    
    -- ✅ 차감이 정확히 한 번만 되었는지 확인
    IF v_points_after_deduction != (v_current_points - v_total_cost) THEN
      RAISE EXCEPTION '포인트 차감이 정확하지 않습니다. (예상: %, 실제: %)', 
        v_current_points - v_total_cost, v_points_after_deduction;
    END IF;
    
    -- 7. 캠페인 생성
    INSERT INTO public.campaigns (
      -- ... 기존 컬럼들 ...
      product_name, product_price,  -- ✅ payment_amount 제거
      -- ...
    ) VALUES (
      -- ... 기존 값들 ...
      p_product_name, p_product_price,  -- ✅ payment_amount 제거
      -- ...
    ) RETURNING id INTO v_campaign_id;
    
    -- 8. 포인트 로그 기록 (한 번만)
    INSERT INTO public.point_transactions (
      wallet_id, transaction_type, amount,
      campaign_id, description,
      created_by_user_id, created_at
    ) VALUES (
      v_wallet_id, 'spend', -v_total_cost,
      v_campaign_id, '캠페인 생성: ' || p_title,
      v_user_id, NOW()
    );
    
    -- 9. 결과 반환
    SELECT jsonb_build_object(
      'success', true,
      'campaign_id', v_campaign_id,
      'total_cost', v_total_cost,
      'points_spent', v_total_cost,
      'remaining_points', v_points_after_deduction,
      'points_before', v_current_points,
      'points_after', v_points_after_deduction
    ) INTO v_result;
    
    -- ✅ 명시적 커밋 (함수는 자동으로 커밋되지만 명시적으로 표시)
    RETURN v_result;
    
  EXCEPTION
    WHEN lock_not_available THEN
      -- ✅ 잠금 실패 시 재시도 안내
      RAISE EXCEPTION '다른 요청이 처리 중입니다. 잠시 후 다시 시도해주세요.';
    WHEN OTHERS THEN
      -- ✅ 에러 발생 시 롤백 (자동)
      RAISE;
  END;
END;
$$;
```

**개선 사항**:
1. `FOR UPDATE NOWAIT`: 잠금 대기하지 않고 즉시 실패하여 데드락 방지
2. 차감 후 잔액 검증: 차감이 정확히 한 번만 되었는지 확인
3. 명시적 트랜잭션: `BEGIN ... END` 블록으로 트랜잭션 범위 명확화

---

### 해결책 4: 데이터베이스 트리거로 중복 차감 방지 (추가 보안)

**목표**: 애플리케이션 레벨을 우회한 차감도 방지

**구현**:

```sql
-- supabase/migrations/YYYYMMDDHHMMSS_add_duplicate_deduction_trigger.sql

-- 중복 차감 감지 함수
CREATE OR REPLACE FUNCTION public.check_duplicate_point_deduction()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_recent_deduction_count INTEGER;
  v_campaign_id UUID;
BEGIN
  -- spend 타입 거래만 체크
  IF NEW.transaction_type != 'spend' THEN
    RETURN NEW;
  END IF;
  
  -- 최근 5초 이내 동일한 campaign_id에 대한 차감이 있는지 확인
  SELECT COUNT(*) INTO v_recent_deduction_count
  FROM public.point_transactions
  WHERE wallet_id = NEW.wallet_id
    AND transaction_type = 'spend'
    AND campaign_id = NEW.campaign_id
    AND created_at > NOW() - INTERVAL '5 seconds'
    AND id != NEW.id;  -- 자기 자신 제외
  
  IF v_recent_deduction_count > 0 THEN
    RAISE EXCEPTION '중복 포인트 차감이 감지되었습니다. (campaign_id: %)', NEW.campaign_id;
  END IF;
  
  RETURN NEW;
END;
$$;

-- 트리거 생성
DROP TRIGGER IF EXISTS trigger_check_duplicate_deduction ON public.point_transactions;
CREATE TRIGGER trigger_check_duplicate_deduction
  BEFORE INSERT ON public.point_transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.check_duplicate_point_deduction();
```

---

## 🎯 권장 해결 순서

1. **즉시 적용: 해결책 1 (클라이언트 측 중복 호출 방지 강화)**
   - 가장 빠르게 적용 가능
   - 대부분의 중복 호출 방지

2. **단기 적용: 해결책 3 (RPC 함수 개선)**
   - 데이터베이스 레벨 보호
   - `FOR UPDATE NOWAIT` 및 차감 후 검증 추가

3. **중기 적용: 해결책 2 (Idempotency Key)**
   - 완벽한 중복 방지
   - 네트워크 재시도 시에도 안전

4. **장기 적용: 해결책 4 (트리거)**
   - 추가 보안 레이어
   - 애플리케이션 레벨 우회 방지

---

## 🔍 데이터베이스 확인 쿼리

다음 쿼리로 중복 차감을 확인할 수 있습니다:

```sql
-- 1. 최근 포인트 거래 내역 확인
SELECT 
  pt.id,
  pt.transaction_type,
  pt.amount,
  pt.campaign_id,
  c.title as campaign_title,
  pt.description,
  pt.created_at,
  w.current_points as wallet_balance
FROM point_transactions pt
LEFT JOIN campaigns c ON c.id = pt.campaign_id
LEFT JOIN wallets w ON w.id = pt.wallet_id
WHERE pt.wallet_id = 'da5d8db7-62f2-4d5c-bdf1-bce3f38c175e'
  AND pt.created_at > NOW() - INTERVAL '1 hour'
ORDER BY pt.created_at DESC;

-- 2. 동일한 campaign_id에 대한 중복 차감 확인
SELECT 
  campaign_id,
  COUNT(*) as deduction_count,
  SUM(ABS(amount)) as total_deduced,
  MIN(created_at) as first_deduction,
  MAX(created_at) as last_deduction
FROM point_transactions
WHERE wallet_id = 'da5d8db7-62f2-4d5c-bdf1-bce3f38c175e'
  AND transaction_type = 'spend'
  AND campaign_id IS NOT NULL
  AND created_at > NOW() - INTERVAL '1 hour'
GROUP BY campaign_id
HAVING COUNT(*) > 1;

-- 3. 지갑 잔액과 거래 내역 합계 비교
SELECT 
  w.id as wallet_id,
  w.current_points as current_balance,
  COALESCE(SUM(pt.amount), 0) as total_transactions,
  w.current_points - COALESCE(SUM(pt.amount), 0) as expected_initial_balance
FROM wallets w
LEFT JOIN point_transactions pt ON pt.wallet_id = w.id
WHERE w.id = 'da5d8db7-62f2-4d5c-bdf1-bce3f38c175e'
GROUP BY w.id, w.current_points;
```

---

## 📝 즉시 적용 가능한 임시 해결책

데이터베이스에서 중복 차감된 포인트를 수동으로 복구:

```sql
-- 1. 중복 차감된 포인트 확인
SELECT 
  campaign_id,
  COUNT(*) as deduction_count,
  SUM(ABS(amount)) as total_deduced
FROM point_transactions
WHERE wallet_id = 'da5d8db7-62f2-4d5c-bdf1-bce3f38c175e'
  AND transaction_type = 'spend'
  AND campaign_id IS NOT NULL
  AND created_at > NOW() - INTERVAL '1 hour'
GROUP BY campaign_id
HAVING COUNT(*) > 1;

-- 2. 중복 차감된 포인트 복구 (주의: 실제 데이터 확인 후 실행)
-- 예: campaign_id가 'xxx'인 경우, 한 번만 차감되어야 하는데 2번 차감됨
-- UPDATE wallets
-- SET current_points = current_points + 153000  -- 중복 차감된 금액
-- WHERE id = 'da5d8db7-62f2-4d5c-bdf1-bce3f38c175e';

-- 3. 중복 거래 레코드 삭제 (주의: 가장 최근 것만 남기고 나머지 삭제)
-- DELETE FROM point_transactions
-- WHERE id IN (
--   SELECT id
--   FROM point_transactions
--   WHERE wallet_id = 'da5d8db7-62f2-4d5c-bdf1-bce3f38c175e'
--     AND campaign_id = 'xxx'  -- 실제 campaign_id로 변경
--     AND transaction_type = 'spend'
--   ORDER BY created_at DESC
--   OFFSET 1  -- 첫 번째 것만 남기고 나머지 삭제
-- );
```

---

## 📅 작성일

2025-11-16

