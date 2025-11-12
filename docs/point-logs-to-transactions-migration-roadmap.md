# 포인트 로그 테이블 마이그레이션 로드맵
## `user_point_logs` & `company_point_logs` → `point_transactions` & `point_transaction_logs`

## 📋 목표

기존의 `user_point_logs`와 `company_point_logs` 테이블을 새로운 명명 규칙에 맞게 변경:
- `user_point_logs` → `point_transactions` (또는 통합)
- `company_point_logs` → `point_transactions` (또는 통합)
- 선택적으로 `point_transaction_logs` 테이블 추가 (감사 로그용)

## 🎯 설계 결정 사항

### ⚠️ 중요 결정: 통합 vs 분리

**질문**: 캠페인 거래(사용/획득)와 현금 입출금을 같은 테이블에 넣을지 분리할지?

#### 옵션 A: 통합 테이블
- **`point_transactions`**: 모든 포인트 거래를 하나의 테이블로 통합
  - 캠페인 거래 + 현금 입출금 모두 포함
  - `user_id`와 `company_id`를 모두 포함 (FK)
  - 둘 중 하나만 NULL이 아니어야 함 (CHECK 제약조건)

#### 옵션 B: 분리 테이블 ⭐ 권장
- **`point_transactions`**: 캠페인 관련 포인트 거래만
  - `transaction_type`: 'earn', 'spend'
  - `campaign_id` 필수/선택
  - 즉시 처리 (승인 불필요)
- **`point_cash_transactions`**: 현금 입출금 거래만
  - `transaction_type`: 'deposit', 'withdraw'
  - Admin 승인 필요 (`pending` → `approved` → `completed`)
  - 계좌 정보, 현금 금액 등 추가 필드

**상세 분석**: `docs/point-transactions-integration-vs-separation-analysis.md` 참고

**권장: 옵션 B (분리 테이블)** - 비즈니스 로직, 필드, 쿼리 패턴이 다르므로 분리 권장

---

### 옵션 2-A: 통합 테이블 (user_id, company_id FK 방식)
- **`point_transactions`**: 통합된 거래 테이블
  - `user_id`와 `company_id`를 모두 포함 (FK)
  - 둘 중 하나만 NULL이 아니어야 함 (CHECK 제약조건)
- **`point_transaction_logs`**: 감사 로그/히스토리 테이블

### 옵션 2-B: 분리 테이블 (user_id, company_id FK 방식) ✅ 최종 선택
- **`point_transactions`**: 캠페인 거래만
- **`point_cash_transactions`**: 현금 입출금만
- **`point_transaction_logs`**: 감사 로그/히스토리 테이블 (선택사항)

**선택: 옵션 2-B (분리 테이블)** - 명확한 책임 분리와 성능 최적화

---

## 📐 새로운 테이블 구조 설계

### 1. point_transactions (캠페인 거래 테이블)

```sql
CREATE TABLE point_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 소유자 정보 (user_id와 company_id 중 하나만 NULL이 아니어야 함)
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    
    -- 지갑 참조 (wallets 테이블과 연결)
    wallet_id UUID REFERENCES wallets(id) ON DELETE CASCADE,
    
    -- 거래 정보 (캠페인 관련만)
    transaction_type TEXT NOT NULL CHECK (
        transaction_type IN ('earn', 'spend')  -- 캠페인 거래만
    ),
    amount INTEGER NOT NULL CHECK (amount != 0),
    
    -- 거래 메타데이터
    description TEXT,
    related_entity_type TEXT, -- 'campaign', 'review', 'refund', etc.
    related_entity_id UUID,
    
    -- 캠페인 참조 (spend 트랜잭션은 필수, earn 트랜잭션은 선택)
    -- - company spend: 캠페인 생성 시 포인트 사용 (필수)
    -- - user earn: 리뷰 완료 시 캠페인에서 포인트 획득 (선택, 캠페인과 연결된 경우)
    campaign_id UUID REFERENCES campaigns(id) ON DELETE SET NULL,
    
    -- 사용자 정보
    created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 상태 정보 (캠페인 거래는 항상 즉시 완료)
    -- status 필드 없음 (항상 completed로 간주)
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    
    -- 제약조건: user_id와 company_id 중 하나만 NULL이 아니어야 함
    CONSTRAINT point_transactions_owner_check CHECK (
        (user_id IS NOT NULL AND company_id IS NULL) OR
        (user_id IS NULL AND company_id IS NOT NULL)
    ),
    
    -- 제약조건: company의 spend 트랜잭션일 때만 campaign_id 필수
    -- user의 earn 트랜잭션은 campaign_id가 선택적 (캠페인과 연결된 경우에만)
    CONSTRAINT point_transactions_campaign_check CHECK (
        -- company spend는 반드시 campaign_id 필요
        (company_id IS NOT NULL AND transaction_type = 'spend' AND campaign_id IS NOT NULL) OR
        -- 그 외의 경우는 campaign_id 선택적
        (NOT (company_id IS NOT NULL AND transaction_type = 'spend'))
    )
);

-- 인덱스
CREATE INDEX idx_point_transactions_user_id ON point_transactions(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_point_transactions_company_id ON point_transactions(company_id) WHERE company_id IS NOT NULL;
CREATE INDEX idx_point_transactions_wallet_id ON point_transactions(wallet_id);
CREATE INDEX idx_point_transactions_type ON point_transactions(transaction_type);
CREATE INDEX idx_point_transactions_status ON point_transactions(status);
CREATE INDEX idx_point_transactions_created_at ON point_transactions(created_at DESC);
CREATE INDEX idx_point_transactions_campaign_id ON point_transactions(campaign_id) WHERE campaign_id IS NOT NULL;
CREATE INDEX idx_point_transactions_related_entity ON point_transactions(related_entity_type, related_entity_id) WHERE related_entity_type IS NOT NULL;

-- 코멘트
COMMENT ON TABLE point_transactions IS '캠페인 관련 포인트 거래 내역 테이블 (캠페인 생성/리뷰 완료 시 발생)';
COMMENT ON COLUMN point_transactions.user_id IS '사용자 ID (user 거래인 경우 - earn)';
COMMENT ON COLUMN point_transactions.company_id IS '회사 ID (company 거래인 경우 - spend)';
COMMENT ON COLUMN point_transactions.wallet_id IS '지갑 ID (wallets 테이블 참조)';
COMMENT ON COLUMN point_transactions.campaign_id IS '캠페인 ID (company spend는 필수, user earn은 선택)';
COMMENT ON COLUMN point_transactions.transaction_type IS '거래 타입: earn(리뷰어 획득), spend(사업자 사용)';
COMMENT ON COLUMN point_transactions.amount IS '거래 금액 (양수: earn, 음수: spend)';
```

### 2. point_cash_transactions (현금 입출금 테이블)

```sql
CREATE TABLE point_cash_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 소유자 정보 (user_id와 company_id 중 하나만 NULL이 아니어야 함)
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    
    -- 지갑 참조 (wallets 테이블과 연결)
    wallet_id UUID REFERENCES wallets(id) ON DELETE CASCADE,
    
    -- 거래 정보 (현금 입출금만)
    transaction_type TEXT NOT NULL CHECK (
        transaction_type IN ('deposit', 'withdraw')
    ),
    amount INTEGER NOT NULL CHECK (amount != 0),
    
    -- 현금 정보
    cash_amount DECIMAL(10, 2), -- 현금 금액 (입금 시, 포인트와 환율 적용)
    payment_method TEXT, -- 'bank_transfer', 'card', etc.
    
    -- 계좌 정보 (출금 시 필수)
    bank_name TEXT,
    account_number TEXT,
    account_holder TEXT,
    
    -- 승인 정보 (Admin 승인 필요)
    status TEXT DEFAULT 'pending' CHECK (
        status IN ('pending', 'approved', 'rejected', 'completed', 'cancelled')
    ),
    approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
    rejected_by UUID REFERENCES users(id) ON DELETE SET NULL,
    rejection_reason TEXT,
    
    -- 메타데이터
    description TEXT,
    created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    
    -- 제약조건: user_id와 company_id 중 하나만 NULL이 아니어야 함
    CONSTRAINT point_cash_transactions_owner_check CHECK (
        (user_id IS NOT NULL AND company_id IS NULL) OR
        (user_id IS NULL AND company_id IS NOT NULL)
    ),
    
    -- 제약조건: 출금 시 계좌 정보 필수
    CONSTRAINT point_cash_transactions_withdraw_account_check CHECK (
        (transaction_type = 'withdraw' AND 
         bank_name IS NOT NULL AND 
         account_number IS NOT NULL AND 
         account_holder IS NOT NULL) OR
        (transaction_type != 'withdraw')
    )
);

-- 인덱스
CREATE INDEX idx_point_cash_transactions_user_id ON point_cash_transactions(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_point_cash_transactions_company_id ON point_cash_transactions(company_id) WHERE company_id IS NOT NULL;
CREATE INDEX idx_point_cash_transactions_status ON point_cash_transactions(status);
CREATE INDEX idx_point_cash_transactions_created_at ON point_cash_transactions(created_at DESC);
CREATE INDEX idx_point_cash_transactions_pending ON point_cash_transactions(status) WHERE status = 'pending';

-- 코멘트
COMMENT ON TABLE point_cash_transactions IS '현금 입출금 거래 내역 테이블 (Admin 승인 필요)';
COMMENT ON COLUMN point_cash_transactions.user_id IS '사용자 ID (user 출금인 경우)';
COMMENT ON COLUMN point_cash_transactions.company_id IS '회사 ID (company 입출금인 경우)';
COMMENT ON COLUMN point_cash_transactions.transaction_type IS '거래 타입: deposit(입금), withdraw(출금)';
COMMENT ON COLUMN point_cash_transactions.amount IS '거래 금액 (양수: deposit, 음수: withdraw)';
COMMENT ON COLUMN point_cash_transactions.status IS '승인 상태: pending → approved → completed';
```

### 3. point_transaction_logs (감사 로그 테이블 - 선택사항)

```sql
CREATE TABLE point_transaction_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 원본 거래 참조
    transaction_id UUID NOT NULL REFERENCES point_transactions(id) ON DELETE CASCADE,
    
    -- 변경 이력 정보
    action TEXT NOT NULL CHECK (action IN ('created', 'updated', 'status_changed', 'approved', 'rejected', 'cancelled')),
    old_status TEXT,
    new_status TEXT,
    changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 변경 내용 (JSONB)
    change_details JSONB,
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 인덱스
CREATE INDEX idx_point_transaction_logs_transaction_id ON point_transaction_logs(transaction_id);
CREATE INDEX idx_point_transaction_logs_created_at ON point_transaction_logs(created_at DESC);
CREATE INDEX idx_point_transaction_logs_changed_by ON point_transaction_logs(changed_by);

COMMENT ON TABLE point_transaction_logs IS '포인트 거래 변경 이력 감사 로그';
```

---

## 📊 시나리오별 사용 예시

### 시나리오 1: 사업자가 캠페인에서 사용하는 포인트 ✅

**상황**: 회사가 캠페인을 생성할 때 포인트를 사용

```sql
-- 캠페인 생성 시 포인트 차감
INSERT INTO point_transactions (
    company_id,
    wallet_id,
    transaction_type,
    amount,  -- 음수 (예: -10000)
    campaign_id,  -- 필수
    description,
    status,
    created_by_user_id
) VALUES (
    'company-uuid',
    'wallet-uuid',
    'spend',
    -10000,  -- 캠페인 생성 비용
    'campaign-uuid',  -- 필수
    '캠페인 생성: 상품 리뷰 캠페인',
    'completed',
    'user-uuid'
);
```

**특징**:
- `company_id` 필수
- `transaction_type = 'spend'`
- `campaign_id` 필수 (CHECK 제약조건)
- `amount`는 음수

---

### 시나리오 2: 리뷰어가 캠페인에서 얻는 포인트 ✅

**상황**: 리뷰어가 리뷰를 완료하여 포인트를 획득

```sql
-- 리뷰 완료 시 포인트 적립
INSERT INTO point_transactions (
    user_id,
    wallet_id,
    transaction_type,
    amount,  -- 양수 (예: 1000)
    campaign_id,  -- 선택 (캠페인과 연결된 경우)
    description,
    related_entity_type,
    related_entity_id,
    status,
    created_by_user_id
) VALUES (
    'user-uuid',
    'wallet-uuid',
    'earn',
    1000,  -- 리뷰 보상
    'campaign-uuid',  -- 선택 (캠페인과 연결된 경우)
    '리뷰 완료 보상',
    'review',
    'review-uuid',
    'completed',
    'user-uuid'
);
```

**특징**:
- `user_id` 필수
- `transaction_type = 'earn'`
- `campaign_id` 선택적 (캠페인과 연결된 경우에만)
- `amount`는 양수
- `related_entity_type = 'review'`로 리뷰와 연결 가능

---

### 시나리오 3: 포인트 현금 입출금 ✅

#### 3-1. 회사 포인트 입금 (현금 → 포인트)

```sql
-- 회사 포인트 입금 요청 (point_cash_transactions 테이블 사용)
INSERT INTO point_cash_transactions (
    company_id,
    wallet_id,
    transaction_type,
    amount,  -- 양수 (예: 100000)
    cash_amount,  -- 현금 금액 (예: 100000.00)
    payment_method,  -- 'bank_transfer'
    description,
    status,  -- 'pending' → admin 승인 → 'completed'
    created_by_user_id
) VALUES (
    'company-uuid',
    'wallet-uuid',
    'deposit',
    100000,
    100000.00,
    'bank_transfer',
    '계좌입금: 100,000원',
    'pending',  -- admin 승인 대기
    'user-uuid'
);
```

#### 3-2. 회사 포인트 출금 (포인트 → 현금)

```sql
-- 회사 포인트 출금 요청 (point_cash_transactions 테이블 사용)
INSERT INTO point_cash_transactions (
    company_id,
    wallet_id,
    transaction_type,
    amount,  -- 음수 (예: -50000)
    bank_name,  -- '하나은행'
    account_number,  -- '123-456-7890'
    account_holder,  -- '홍길동'
    description,
    status,  -- 'pending' → admin 승인 → 'completed'
    created_by_user_id
) VALUES (
    'company-uuid',
    'wallet-uuid',
    'withdraw',
    -50000,
    '하나은행',
    '123-456-7890',
    '홍길동',
    '출금 요청: 50,000원',
    'pending',
    'user-uuid'
);
```

#### 3-3. 사용자 포인트 출금 (포인트 → 현금)

```sql
-- 사용자 포인트 출금 요청 (point_cash_transactions 테이블 사용)
INSERT INTO point_cash_transactions (
    user_id,
    wallet_id,
    transaction_type,
    amount,  -- 음수 (예: -20000)
    bank_name,  -- '신한은행'
    account_number,  -- '987-654-3210'
    account_holder,  -- '김철수'
    description,
    status,  -- 'pending' → admin 승인 → 'completed'
    created_by_user_id
) VALUES (
    'user-uuid',
    'wallet-uuid',
    'withdraw',
    -20000,
    '신한은행',
    '987-654-3210',
    '김철수',
    '출금 요청: 20,000원',
    'pending',
    'user-uuid'
);
```

**특징**:
- **테이블**: `point_cash_transactions` 사용 (캠페인 거래와 분리)
- 입금: `transaction_type = 'deposit'`, `amount` 양수, `cash_amount` 포함
- 출금: `transaction_type = 'withdraw'`, `amount` 음수, 계좌 정보 필수
- `status = 'pending'` → admin 승인 필요
- `campaign_id` 없음 (캠페인과 무관)

---

## 🔄 마이그레이션 단계

### Phase 1: 준비 단계 (1일)

#### 1.1 현재 데이터 백업
```sql
-- 기존 데이터 백업
CREATE TABLE user_point_logs_backup AS SELECT * FROM user_point_logs;
CREATE TABLE company_point_logs_backup AS SELECT * FROM company_point_logs;
```

#### 1.2 의존성 분석
- [ ] `user_point_logs`를 참조하는 모든 함수/트리거 확인
- [ ] `company_point_logs`를 참조하는 모든 함수/트리거 확인
- [ ] Flutter 앱에서 사용하는 모든 쿼리 확인
- [ ] RPC 함수 목록 작성

#### 1.3 영향받는 파일 목록 작성
**데이터베이스:**
- `supabase/migrations/20250107000006_replace_trigger_with_rpc.sql`
- 기타 마이그레이션 파일들

**Flutter 코드:**
- `lib/models/wallet_models.dart` (UserPointLog, CompanyPointLog)
- `lib/services/wallet_service.dart` (getUserPointHistory, getCompanyPointHistory)
- `lib/services/point_service.dart`
- `lib/screens/mypage/common/points_screen.dart`
- 기타 포인트 로그를 사용하는 모든 화면

**RPC 함수:**
- `get_user_point_logs_safe`
- `get_company_point_history`
- `get_user_point_history`
- 기타 포인트 로그 관련 함수들

---

### Phase 2: 새 테이블 생성 (1일)

#### 2.1 point_transactions 테이블 생성 (캠페인 거래)
```sql
-- 마이그레이션 파일: YYYYMMDDHHMMSS_create_point_transactions.sql
-- 위의 CREATE TABLE 문 실행
```

#### 2.2 point_cash_transactions 테이블 생성 (현금 입출금)
```sql
-- 마이그레이션 파일: YYYYMMDDHHMMSS_create_point_cash_transactions.sql
-- 위의 CREATE TABLE 문 실행
```

#### 2.3 point_transaction_logs 테이블 생성 (선택사항)
```sql
-- 마이그레이션 파일: YYYYMMDDHHMMSS_create_point_transaction_logs.sql
-- 위의 CREATE TABLE 문 실행
```

#### 2.4 데이터 마이그레이션 스크립트 작성

**중요**: 기존 데이터를 캠페인 거래와 현금 거래로 구분하여 각각의 테이블로 마이그레이션

```sql
-- ============================================
-- 1. user_point_logs → point_transactions (캠페인 거래만)
-- ============================================
-- earn 타입만 캠페인 거래로 분류 (campaign과 관련된 경우)
INSERT INTO point_transactions (
    id,
    user_id,
    company_id,
    wallet_id,
    transaction_type,
    amount,
    description,
    related_entity_type,
    related_entity_id,
    campaign_id,
    created_by_user_id,
    created_at,
    updated_at
)
SELECT 
    id,
    user_id,
    NULL AS company_id,
    (SELECT id FROM wallets WHERE user_id = upl.user_id LIMIT 1) AS wallet_id,
    transaction_type, -- 'earn'
    amount,
    description,
    related_entity_type,
    related_entity_id,
    CASE 
        WHEN related_entity_type = 'campaign' THEN related_entity_id::UUID
        ELSE NULL
    END AS campaign_id,
    NULL AS created_by_user_id, -- 기존 데이터에는 없음
    created_at,
    created_at AS updated_at
FROM user_point_logs upl
WHERE transaction_type = 'earn'; -- 캠페인 관련 적립만

-- ============================================
-- 2. user_point_logs → point_cash_transactions (현금 거래)
-- ============================================
-- withdraw 타입은 현금 거래로 분류
INSERT INTO point_cash_transactions (
    id,
    user_id,
    company_id,
    wallet_id,
    transaction_type,
    amount,
    description,
    status,
    created_by_user_id,
    created_at,
    updated_at,
    completed_at
)
SELECT 
    id,
    user_id,
    NULL AS company_id,
    (SELECT id FROM wallets WHERE user_id = upl.user_id LIMIT 1) AS wallet_id,
    'withdraw' AS transaction_type,
    amount, -- 이미 음수일 것
    description,
    'completed' AS status, -- 기존 데이터는 모두 완료된 것으로 간주
    NULL AS created_by_user_id,
    created_at,
    created_at AS updated_at,
    created_at AS completed_at
FROM user_point_logs upl
WHERE transaction_type = 'withdraw';

-- ============================================
-- 3. company_point_logs → point_transactions (캠페인 거래)
-- ============================================
-- spend 타입은 캠페인 거래로 분류 (campaign과 관련된 경우)
INSERT INTO point_transactions (
    id,
    user_id,
    company_id,
    wallet_id,
    transaction_type,
    amount,
    description,
    related_entity_type,
    related_entity_id,
    campaign_id,
    created_by_user_id,
    created_at,
    updated_at
)
SELECT 
    id,
    NULL AS user_id,
    company_id,
    (SELECT id FROM wallets WHERE company_id = cpl.company_id LIMIT 1) AS wallet_id,
    transaction_type, -- 'spend'
    amount,
    description,
    related_entity_type,
    related_entity_id,
    CASE 
        WHEN related_entity_type = 'campaign' THEN related_entity_id::UUID
        ELSE NULL
    END AS campaign_id,
    created_by_user_id,
    created_at,
    created_at AS updated_at
FROM company_point_logs cpl
WHERE transaction_type = 'spend' 
  AND related_entity_type = 'campaign'; -- 캠페인 관련 사용만

-- ============================================
-- 4. company_point_logs → point_cash_transactions (현금 거래)
-- ============================================
-- charge(deposit), withdraw 타입은 현금 거래로 분류
INSERT INTO point_cash_transactions (
    id,
    user_id,
    company_id,
    wallet_id,
    transaction_type,
    amount,
    description,
    status,
    created_by_user_id,
    created_at,
    updated_at,
    completed_at
)
SELECT 
    id,
    NULL AS user_id,
    company_id,
    (SELECT id FROM wallets WHERE company_id = cpl.company_id LIMIT 1) AS wallet_id,
    CASE 
        WHEN transaction_type = 'charge' THEN 'deposit'
        WHEN transaction_type = 'withdraw' THEN 'withdraw'
    END AS transaction_type,
    amount,
    description,
    'completed' AS status, -- 기존 데이터는 모두 완료된 것으로 간주
    created_by_user_id,
    created_at,
    created_at AS updated_at,
    created_at AS completed_at
FROM company_point_logs cpl
WHERE transaction_type IN ('charge', 'withdraw');
```

---

### Phase 3: RPC 함수 업데이트 (2일)

#### 3.1 기존 함수 수정
```sql
-- get_point_transactions (통합 함수)
CREATE OR REPLACE FUNCTION get_point_transactions(
    p_user_id UUID DEFAULT NULL,
    p_company_id UUID DEFAULT NULL,
    p_transaction_type TEXT DEFAULT 'all',
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- user_id와 company_id 중 하나만 제공되어야 함
    IF (p_user_id IS NULL AND p_company_id IS NULL) OR 
       (p_user_id IS NOT NULL AND p_company_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Either user_id or company_id must be provided, but not both';
    END IF;
    
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'user_id', user_id,
            'company_id', company_id,
            'wallet_id', wallet_id,
            'transaction_type', transaction_type,
            'amount', amount,
            'description', description,
            'related_entity_type', related_entity_type,
            'related_entity_id', related_entity_id,
            'campaign_id', campaign_id,
            'created_by_user_id', created_by_user_id,
            'status', status,
            'approved_by', approved_by,
            'rejected_by', rejected_by,
            'rejection_reason', rejection_reason,
            'created_at', created_at,
            'updated_at', updated_at,
            'completed_at', completed_at
        )
    )
    INTO v_result
    FROM point_transactions
    WHERE (p_user_id IS NOT NULL AND user_id = p_user_id) OR
          (p_company_id IS NOT NULL AND company_id = p_company_id)
    AND (p_transaction_type = 'all' OR transaction_type = p_transaction_type)
    ORDER BY created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
    
    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- 하위 호환성을 위한 래퍼 함수
CREATE OR REPLACE FUNCTION get_user_point_logs_safe(
    p_user_id UUID,
    p_transaction_type TEXT DEFAULT 'all',
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN get_point_transactions(
        p_user_id => p_user_id,
        p_company_id => NULL,
        p_transaction_type => p_transaction_type,
        p_limit => p_limit,
        p_offset => p_offset
    );
END;
$$;

CREATE OR REPLACE FUNCTION get_company_point_history(
    p_company_id UUID,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN get_point_transactions(
        p_user_id => NULL,
        p_company_id => p_company_id,
        p_transaction_type => 'all',
        p_limit => p_limit,
        p_offset => p_offset
    );
END;
$$;
```

#### 3.2 통합 조회 함수 생성 (중요!)

**사용자가 포인트 로그를 볼 때는 캠페인 거래와 현금 거래를 한번에 봐야 함**

```sql
-- 1. 통합 View 생성 (먼저 생성 필요)
CREATE VIEW all_point_transactions AS
SELECT 
    id, user_id, company_id, wallet_id,
    transaction_type, amount,
    NULL AS campaign_id,
    NULL AS related_entity_type,
    NULL AS related_entity_id,
    description,
    status, approved_by, rejected_by, rejection_reason,
    created_by_user_id,
    created_at, updated_at, completed_at,
    'cash' AS transaction_category,
    cash_amount, payment_method,
    bank_name, account_number, account_holder
FROM point_cash_transactions

UNION ALL

SELECT 
    id, user_id, company_id, wallet_id,
    transaction_type, amount,
    campaign_id,
    related_entity_type,
    related_entity_id,
    description,
    'completed' AS status,
    NULL AS approved_by,
    NULL AS rejected_by,
    NULL AS rejection_reason,
    created_by_user_id,
    created_at, updated_at, created_at AS completed_at,
    'campaign' AS transaction_category,
    NULL AS cash_amount,
    NULL AS payment_method,
    NULL AS bank_name,
    NULL AS account_number,
    NULL AS account_holder
FROM point_transactions;

-- 2. 사용자 포인트 내역 통합 조회 함수
CREATE OR REPLACE FUNCTION get_user_point_history_unified(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- 권한 확인: 본인만 조회 가능
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'You can only view your own point history';
    END IF;
    
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'user_id', user_id,
            'company_id', company_id,
            'wallet_id', wallet_id,
            'transaction_type', transaction_type,
            'amount', amount,
            'campaign_id', campaign_id,
            'related_entity_type', related_entity_type,
            'related_entity_id', related_entity_id,
            'description', description,
            'status', status,
            'approved_by', approved_by,
            'rejected_by', rejected_by,
            'rejection_reason', rejection_reason,
            'created_by_user_id', created_by_user_id,
            'created_at', created_at,
            'updated_at', updated_at,
            'completed_at', completed_at,
            'transaction_category', transaction_category,
            'cash_amount', cash_amount,
            'payment_method', payment_method,
            'bank_name', bank_name,
            'account_number', account_number,
            'account_holder', account_holder
        )
    )
    INTO v_result
    FROM all_point_transactions
    WHERE user_id = p_user_id
    ORDER BY created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
    
    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- 3. 회사 포인트 내역 통합 조회 함수
CREATE OR REPLACE FUNCTION get_company_point_history_unified(
    p_company_id UUID,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_result JSONB;
    v_user_id UUID;
BEGIN
    -- 권한 확인: 회사 멤버만 조회 가능
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM company_users
        WHERE company_id = p_company_id
        AND user_id = v_user_id
        AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'You do not have permission to view this company point history';
    END IF;
    
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'user_id', user_id,
            'company_id', company_id,
            'wallet_id', wallet_id,
            'transaction_type', transaction_type,
            'amount', amount,
            'campaign_id', campaign_id,
            'related_entity_type', related_entity_type,
            'related_entity_id', related_entity_id,
            'description', description,
            'status', status,
            'approved_by', approved_by,
            'rejected_by', rejected_by,
            'rejection_reason', rejection_reason,
            'created_by_user_id', created_by_user_id,
            'created_at', created_at,
            'updated_at', updated_at,
            'completed_at', completed_at,
            'transaction_category', transaction_category,
            'cash_amount', cash_amount,
            'payment_method', payment_method,
            'bank_name', bank_name,
            'account_number', account_number,
            'account_holder', account_holder
        )
    )
    INTO v_result
    FROM all_point_transactions
    WHERE company_id = p_company_id
    ORDER BY created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
    
    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;
```

#### 3.3 기타 함수 생성
- `create_point_transaction`: 새 캠페인 거래 생성
- `create_point_cash_transaction`: 새 현금 거래 생성
- `update_point_cash_transaction_status`: 현금 거래 상태 업데이트 (승인/거절)
- `get_point_transaction_by_id`: 거래 상세 조회 (통합)

---

### Phase 4: 트리거 및 함수 업데이트 (1일)

#### 4.1 기존 트리거 수정
- `user_point_logs`에 INSERT하는 모든 트리거를 `point_transactions`로 변경
- `company_point_logs`에 INSERT하는 모든 트리거를 `point_transactions`로 변경

#### 4.2 새 트리거 생성 (선택사항)
```sql
-- point_transactions 변경 시 로그 기록
CREATE OR REPLACE FUNCTION log_point_transaction_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO point_transaction_logs (
            transaction_id,
            action,
            new_status,
            changed_by,
            change_details
        ) VALUES (
            NEW.id,
            'created',
            NEW.status,
            NEW.created_by_user_id,
            row_to_json(NEW)::jsonb
        );
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.status != NEW.status THEN
            INSERT INTO point_transaction_logs (
                transaction_id,
                action,
                old_status,
                new_status,
                changed_by,
                change_details
            ) VALUES (
                NEW.id,
                'status_changed',
                OLD.status,
                NEW.status,
                NEW.approved_by,
                jsonb_build_object(
                    'old', row_to_json(OLD)::jsonb,
                    'new', row_to_json(NEW)::jsonb
                )
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER point_transaction_log_trigger
    AFTER INSERT OR UPDATE ON point_transactions
    FOR EACH ROW
    EXECUTE FUNCTION log_point_transaction_change();
```

---

### Phase 5: RLS 정책 업데이트 (0.5일)

#### 5.1 point_transactions RLS
```sql
ALTER TABLE point_transactions ENABLE ROW LEVEL SECURITY;

-- User는 자신의 거래만 조회 가능
CREATE POLICY "Users can view their own transactions"
ON point_transactions FOR SELECT
USING (
    (user_id = auth.uid())
);

-- Company 멤버는 회사 거래 조회 가능
CREATE POLICY "Company members can view company transactions"
ON point_transactions FOR SELECT
USING (
    (company_id IS NOT NULL AND 
     EXISTS (
         SELECT 1 FROM company_users
         WHERE company_id = point_transactions.company_id
         AND user_id = auth.uid()
         AND status = 'active'
     ))
);

-- System은 모든 거래 삽입 가능
CREATE POLICY "System can insert transactions"
ON point_transactions FOR INSERT
WITH CHECK (true);
```

---

### Phase 6: Flutter 코드 업데이트 (2-3일)

#### 6.1 모델 클래스 업데이트
**파일: `lib/models/wallet_models.dart`**

```dart
// 통합 포인트 거래 모델 (캠페인 + 현금 거래 모두 포함)
class UnifiedPointTransaction {
  final String id;
  final String? userId;
  final String? companyId;
  final String? walletId;
  final String transactionType;
  final int amount;
  final String? description;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final String? campaignId;
  final String? createdByUserId;
  final String status;
  final String? approvedBy;
  final String? rejectedBy;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  
  // 거래 카테고리
  final String transactionCategory; // 'campaign' or 'cash'
  
  // 현금 거래 전용 필드
  final double? cashAmount;
  final String? paymentMethod;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolder;

  // 편의 getter
  bool get isUserTransaction => userId != null;
  bool get isCompanyTransaction => companyId != null;
  bool get isCampaignTransaction => transactionCategory == 'campaign';
  bool get isCashTransaction => transactionCategory == 'cash';
  bool get isEarn => transactionType == 'earn';
  bool get isSpend => transactionType == 'spend';
  bool get isDeposit => transactionType == 'deposit';
  bool get isWithdraw => transactionType == 'withdraw';
  
  // ... fromJson, toJson 메서드
}

// 캠페인 거래 전용 모델
class PointTransaction {
  final String id;
  final String? userId;
  final String? companyId;
  final String? walletId;
  final String transactionType; // 'earn', 'spend'
  final int amount;
  final String? description;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final String? campaignId;
  final String? createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // ... fromJson, toJson 메서드
}

// 현금 거래 전용 모델
class PointCashTransaction {
  final String id;
  final String? userId;
  final String? companyId;
  final String? walletId;
  final String transactionType; // 'deposit', 'withdraw'
  final int amount;
  final String? description;
  final String status;
  final String? approvedBy;
  final String? rejectedBy;
  final String? rejectionReason;
  final String? createdByUserId;
  final double? cashAmount;
  final String? paymentMethod;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  
  // ... fromJson, toJson 메서드
}

// 하위 호환성을 위한 래퍼 클래스 (선택사항)
class UserPointLog {
  final PointTransaction transaction;
  // ... 기존 인터페이스 유지
}
```

#### 6.2 서비스 클래스 업데이트
**파일: `lib/services/wallet_service.dart`**

```dart
// 통합 조회 함수 (캠페인 + 현금 거래 모두)
static Future<List<UnifiedPointTransaction>> getUserPointHistoryUnified({
  int limit = 50,
  int offset = 0,
}) async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) return [];
  
  final response = await _supabase.rpc(
    'get_user_point_history_unified',
    params: {
      'p_user_id': userId,
      'p_limit': limit,
      'p_offset': offset,
    },
  ) as List;
  
  return response
      .map((e) => UnifiedPointTransaction.fromJson(e as Map<String, dynamic>))
      .toList();
}

// 회사 통합 조회
static Future<List<UnifiedPointTransaction>> getCompanyPointHistoryUnified({
  required String companyId,
  int limit = 50,
  int offset = 0,
}) async {
  final response = await _supabase.rpc(
    'get_company_point_history_unified',
    params: {
      'p_company_id': companyId,
      'p_limit': limit,
      'p_offset': offset,
    },
  ) as List;
  
  return response
      .map((e) => UnifiedPointTransaction.fromJson(e as Map<String, dynamic>))
      .toList();
}

// 하위 호환성 유지 (기존 함수는 통합 함수를 사용)
static Future<List<UserPointLog>> getUserPointHistory({
  int limit = 50,
  int offset = 0,
}) async {
  final unified = await getUserPointHistoryUnified(
    limit: limit,
    offset: offset,
  );
  // UnifiedPointTransaction을 UserPointLog로 변환
  return unified
      .where((t) => t.userId != null)
      .map((t) => UserPointLog.fromUnified(t))
      .toList();
}
```

#### 6.3 UI 화면 업데이트
- `lib/screens/mypage/common/points_screen.dart`
- 기타 포인트 로그를 표시하는 모든 화면

---

### Phase 7: 기존 테이블 제거 (1일)

#### 7.1 데이터 검증
```sql
-- 마이그레이션된 데이터 검증
SELECT 
    -- 기존 데이터
    (SELECT COUNT(*) FROM user_point_logs) AS old_user_logs_count,
    (SELECT COUNT(*) FROM company_point_logs) AS old_company_logs_count,
    
    -- 캠페인 거래 (point_transactions)
    (SELECT COUNT(*) FROM point_transactions WHERE user_id IS NOT NULL) AS new_user_campaign_count,
    (SELECT COUNT(*) FROM point_transactions WHERE company_id IS NOT NULL) AS new_company_campaign_count,
    
    -- 현금 거래 (point_cash_transactions)
    (SELECT COUNT(*) FROM point_cash_transactions WHERE user_id IS NOT NULL) AS new_user_cash_count,
    (SELECT COUNT(*) FROM point_cash_transactions WHERE company_id IS NOT NULL) AS new_company_cash_count,
    
    -- 총합 검증
    (SELECT COUNT(*) FROM user_point_logs) AS total_old,
    (
        (SELECT COUNT(*) FROM point_transactions WHERE user_id IS NOT NULL) +
        (SELECT COUNT(*) FROM point_cash_transactions WHERE user_id IS NOT NULL) +
        (SELECT COUNT(*) FROM point_transactions WHERE company_id IS NOT NULL) +
        (SELECT COUNT(*) FROM point_cash_transactions WHERE company_id IS NOT NULL)
    ) AS total_new;
```

#### 7.2 기존 테이블 제거
```sql
-- 모든 의존성 제거 후
DROP TABLE IF EXISTS user_point_logs CASCADE;
DROP TABLE IF EXISTS company_point_logs CASCADE;

-- 백업 테이블은 유지 (나중에 삭제)
-- DROP TABLE IF EXISTS user_point_logs_backup;
-- DROP TABLE IF EXISTS company_point_logs_backup;
```

---

### Phase 8: 테스트 및 검증 (2일)

#### 8.1 단위 테스트
- [ ] 데이터 마이그레이션 검증
- [ ] RPC 함수 테스트
- [ ] 트리거 테스트
- [ ] RLS 정책 테스트

#### 8.2 통합 테스트
- [ ] Flutter 앱에서 포인트 내역 조회 테스트
- [ ] 포인트 거래 생성 테스트
- [ ] 권한 테스트 (user/company/admin)

#### 8.3 성능 테스트
- [ ] 인덱스 성능 확인
- [ ] 대량 데이터 조회 성능 테스트

---

## 📝 마이그레이션 파일 구조

```
supabase/migrations/
  YYYYMMDDHHMMSS_backup_point_logs.sql (백업)
  YYYYMMDDHHMMSS_create_point_transactions.sql (캠페인 거래 테이블)
  YYYYMMDDHHMMSS_create_point_cash_transactions.sql (현금 입출금 테이블)
  YYYYMMDDHHMMSS_create_point_transaction_logs.sql (감사 로그, 선택사항)
  YYYYMMDDHHMMSS_create_all_point_transactions_view.sql (통합 View 생성) ⭐ 중요
  YYYYMMDDHHMMSS_migrate_data_to_point_transactions.sql (캠페인 거래 마이그레이션)
  YYYYMMDDHHMMSS_migrate_data_to_point_cash_transactions.sql (현금 거래 마이그레이션)
  YYYYMMDDHHMMSS_create_unified_query_functions.sql (통합 조회 RPC 함수) ⭐ 중요
  YYYYMMDDHHMMSS_update_rpc_functions.sql (기타 RPC 함수 업데이트)
  YYYYMMDDHHMMSS_update_triggers.sql (트리거 업데이트)
  YYYYMMDDHHMMSS_create_rls_policies.sql (RLS 정책)
  YYYYMMDDHHMMSS_drop_old_tables.sql (기존 테이블 제거)
```

---

## ✅ 체크리스트

### 데이터베이스
- [ ] 기존 데이터 백업
- [ ] point_transactions 테이블 생성 (캠페인 거래)
- [ ] point_cash_transactions 테이블 생성 (현금 입출금)
- [ ] point_transaction_logs 테이블 생성 (선택사항)
- [ ] **all_point_transactions View 생성** ⭐ (통합 조회용)
- [ ] 데이터 마이그레이션 스크립트 작성 및 실행 (캠페인/현금 구분)
- [ ] **통합 조회 RPC 함수 생성** ⭐ (get_user_point_history_unified, get_company_point_history_unified)
- [ ] 기타 RPC 함수 업데이트
- [ ] 트리거 업데이트
- [ ] RLS 정책 설정
- [ ] 인덱스 최적화
- [ ] 기존 테이블 제거

### Flutter 코드
- [ ] UnifiedPointTransaction 모델 클래스 생성 ⭐ (통합 모델)
- [ ] PointTransaction 모델 클래스 생성 (캠페인 거래)
- [ ] PointCashTransaction 모델 클래스 생성 (현금 거래)
- [ ] 기존 모델 클래스 업데이트 (하위 호환성)
- [ ] wallet_service.dart 업데이트 (통합 조회 함수 추가)
- [ ] point_service.dart 업데이트
- [ ] UI 화면 업데이트 (통합 내역 표시)
- [ ] 테스트 코드 업데이트

### 문서화
- [ ] API 문서 업데이트
- [ ] 데이터베이스 스키마 문서 업데이트
- [ ] 개발자 가이드 업데이트

---

## 🚨 주의사항

1. **데이터 무결성**: 마이그레이션 전 반드시 백업
2. **하위 호환성**: 기존 API는 래퍼 함수로 유지
3. **점진적 배포**: 단계별로 배포하여 문제 발생 시 롤백 가능
4. **성능 모니터링**: 마이그레이션 후 성능 지표 모니터링
5. **테스트 환경**: 프로덕션 배포 전 스테이징 환경에서 충분한 테스트

---

## 📚 참고 자료

- 기존 로드맵: `docs/point-transaction-roadmap.md`
- 통합 테이블 연구: `docs/unified-point-events-research.md`
- 지갑 통합 마이그레이션: `supabase/migrations/20250107000000_unify_wallets.sql`

---

## 🎯 예상 소요 시간

- **Phase 1**: 1일 (준비)
- **Phase 2**: 1일 (테이블 생성)
- **Phase 3**: 2일 (RPC 함수)
- **Phase 4**: 1일 (트리거)
- **Phase 5**: 0.5일 (RLS)
- **Phase 6**: 2-3일 (Flutter 코드)
- **Phase 7**: 1일 (테이블 제거)
- **Phase 8**: 2일 (테스트)

**총 예상 시간: 10-11일**

