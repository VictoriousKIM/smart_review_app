# 포인트 거래 테이블 분리 최종 로드맵
## 분리 테이블 구조: `point_transactions` + `point_cash_transactions` (각각 로그 테이블 포함)

## 📋 목표

기존의 `user_point_logs`와 `company_point_logs` 테이블을 분리된 구조로 마이그레이션:

### 최종 테이블 구조
1. **`point_transactions`**: 캠페인 관련 포인트 거래 (earn, spend)
   - `point_transaction_logs`: 캠페인 거래 변경 이력
2. **`point_cash_transactions`**: 현금 입출금 거래 (deposit, withdraw)
   - `point_cash_transaction_logs`: 현금 거래 변경 이력

### 통합 조회
- **`all_point_transactions` View**: 두 테이블을 통합하여 조회
- **RPC 함수**: `get_user_point_history_unified`, `get_company_point_history_unified`

---

## 🎯 설계 원칙

### 1. 책임 분리
- **캠페인 거래**: 즉시 처리, 승인 불필요, `campaign_id` 필수/선택
- **현금 거래**: 승인 필요, 계좌 정보 필요, `campaign_id` 없음

### 2. 각 테이블별 로그
- 각 거래 테이블마다 독립적인 로그 테이블
- 변경 이력 추적 및 감사 목적

### 3. 통합 조회 지원
- View와 RPC 함수를 통한 통합 조회
- 사용자 경험 유지

---

## 📐 최종 테이블 구조

### 1. point_transactions (캠페인 거래)

```sql
CREATE TABLE point_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 소유자 정보
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    
    -- 지갑 참조
    wallet_id UUID REFERENCES wallets(id) ON DELETE CASCADE,
    
    -- 거래 정보
    transaction_type TEXT NOT NULL CHECK (
        transaction_type IN ('earn', 'spend')
    ),
    amount INTEGER NOT NULL CHECK (amount != 0),
    
    -- 캠페인 정보
    campaign_id UUID REFERENCES campaigns(id) ON DELETE SET NULL,
    
    -- 관련 엔티티
    related_entity_type TEXT, -- 'review', 'campaign', 'refund'
    related_entity_id UUID,
    
    -- 메타데이터
    description TEXT,
    created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ DEFAULT NOW(), -- 즉시 완료
    
    -- 제약조건
    CONSTRAINT point_transactions_owner_check CHECK (
        (user_id IS NOT NULL AND company_id IS NULL) OR
        (user_id IS NULL AND company_id IS NOT NULL)
    ),
    
    -- company spend는 campaign_id 필수
    CONSTRAINT point_transactions_campaign_check CHECK (
        (company_id IS NOT NULL AND transaction_type = 'spend' AND campaign_id IS NOT NULL) OR
        (NOT (company_id IS NOT NULL AND transaction_type = 'spend'))
    )
);

-- 인덱스
CREATE INDEX idx_point_transactions_user_id ON point_transactions(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_point_transactions_company_id ON point_transactions(company_id) WHERE company_id IS NOT NULL;
CREATE INDEX idx_point_transactions_wallet_id ON point_transactions(wallet_id);
CREATE INDEX idx_point_transactions_campaign_id ON point_transactions(campaign_id) WHERE campaign_id IS NOT NULL;
CREATE INDEX idx_point_transactions_type ON point_transactions(transaction_type);
CREATE INDEX idx_point_transactions_created_at ON point_transactions(created_at DESC);
CREATE INDEX idx_point_transactions_related_entity ON point_transactions(related_entity_type, related_entity_id) WHERE related_entity_type IS NOT NULL;

-- 코멘트
COMMENT ON TABLE point_transactions IS '캠페인 관련 포인트 거래 테이블 (earn, spend)';
COMMENT ON COLUMN point_transactions.transaction_type IS '거래 타입: earn(적립), spend(사용)';
COMMENT ON COLUMN point_transactions.campaign_id IS '캠페인 ID (company spend는 필수, user earn은 선택)';
```

### 2. point_transaction_logs (캠페인 거래 로그)

```sql
CREATE TABLE point_transaction_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 원본 거래 참조
    transaction_id UUID NOT NULL REFERENCES point_transactions(id) ON DELETE CASCADE,
    
    -- 변경 이력 정보
    action TEXT NOT NULL CHECK (
        action IN ('created', 'updated', 'cancelled', 'refunded')
    ),
    old_data JSONB, -- 변경 전 데이터 스냅샷
    new_data JSONB, -- 변경 후 데이터 스냅샷
    changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 변경 내용 상세
    change_details JSONB,
    change_reason TEXT,
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 인덱스
CREATE INDEX idx_point_transaction_logs_transaction_id ON point_transaction_logs(transaction_id);
CREATE INDEX idx_point_transaction_logs_created_at ON point_transaction_logs(created_at DESC);
CREATE INDEX idx_point_transaction_logs_changed_by ON point_transaction_logs(changed_by);
CREATE INDEX idx_point_transaction_logs_action ON point_transaction_logs(action);

COMMENT ON TABLE point_transaction_logs IS '캠페인 포인트 거래 변경 이력 감사 로그';
```

### 3. point_cash_transactions (현금 입출금)

```sql
CREATE TABLE point_cash_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 소유자 정보
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    
    -- 지갑 참조
    wallet_id UUID REFERENCES wallets(id) ON DELETE CASCADE,
    
    -- 거래 정보
    transaction_type TEXT NOT NULL CHECK (
        transaction_type IN ('deposit', 'withdraw')
    ),
    amount INTEGER NOT NULL CHECK (amount != 0),
    
    -- 현금 정보
    cash_amount DECIMAL(10, 2), -- 현금 금액 (입금 시)
    payment_method TEXT, -- 'bank_transfer', 'card', 'cash', etc.
    
    -- 계좌 정보 (출금 시 필수)
    bank_name TEXT,
    account_number TEXT,
    account_holder TEXT,
    
    -- 승인 정보
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
    
    -- 제약조건
    CONSTRAINT point_cash_transactions_owner_check CHECK (
        (user_id IS NOT NULL AND company_id IS NULL) OR
        (user_id IS NULL AND company_id IS NOT NULL)
    ),
    
    -- 출금 시 계좌 정보 필수
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
CREATE INDEX idx_point_cash_transactions_wallet_id ON point_cash_transactions(wallet_id);
CREATE INDEX idx_point_cash_transactions_status ON point_cash_transactions(status);
CREATE INDEX idx_point_cash_transactions_type ON point_cash_transactions(transaction_type);
CREATE INDEX idx_point_cash_transactions_created_at ON point_cash_transactions(created_at DESC);
CREATE INDEX idx_point_cash_transactions_pending ON point_cash_transactions(status) WHERE status = 'pending';

COMMENT ON TABLE point_cash_transactions IS '현금 입출금 거래 테이블 (deposit, withdraw)';
COMMENT ON COLUMN point_cash_transactions.status IS '거래 상태: pending(대기) → approved(승인) → completed(완료)';
```

### 4. point_cash_transaction_logs (현금 거래 로그)

```sql
CREATE TABLE point_cash_transaction_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 원본 거래 참조
    transaction_id UUID NOT NULL REFERENCES point_cash_transactions(id) ON DELETE CASCADE,
    
    -- 변경 이력 정보
    action TEXT NOT NULL CHECK (
        action IN ('created', 'updated', 'status_changed', 'approved', 'rejected', 'cancelled', 'completed')
    ),
    old_status TEXT,
    new_status TEXT,
    old_data JSONB, -- 변경 전 데이터 스냅샷
    new_data JSONB, -- 변경 후 데이터 스냅샷
    changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 변경 내용 상세
    change_details JSONB,
    change_reason TEXT,
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 인덱스
CREATE INDEX idx_point_cash_transaction_logs_transaction_id ON point_cash_transaction_logs(transaction_id);
CREATE INDEX idx_point_cash_transaction_logs_created_at ON point_cash_transaction_logs(created_at DESC);
CREATE INDEX idx_point_cash_transaction_logs_changed_by ON point_cash_transaction_logs(changed_by);
CREATE INDEX idx_point_cash_transaction_logs_action ON point_cash_transaction_logs(action);
CREATE INDEX idx_point_cash_transaction_logs_status_change ON point_cash_transaction_logs(old_status, new_status) WHERE old_status IS NOT NULL;

COMMENT ON TABLE point_cash_transaction_logs IS '현금 입출금 거래 변경 이력 감사 로그';
```

### 5. all_point_transactions View (통합 조회용)

```sql
CREATE VIEW all_point_transactions AS
SELECT 
    id,
    user_id,
    company_id,
    wallet_id,
    transaction_type,
    amount,
    NULL AS campaign_id,
    NULL AS related_entity_type,
    NULL AS related_entity_id,
    description,
    status,
    approved_by,
    rejected_by,
    rejection_reason,
    created_by_user_id,
    created_at,
    updated_at,
    completed_at,
    'cash' AS transaction_category,
    -- 현금 거래 전용 필드
    cash_amount,
    payment_method,
    bank_name,
    account_number,
    account_holder
FROM point_cash_transactions

UNION ALL

SELECT 
    id,
    user_id,
    company_id,
    wallet_id,
    transaction_type,
    amount,
    campaign_id,
    related_entity_type,
    related_entity_id,
    description,
    'completed' AS status, -- 캠페인 거래는 항상 완료
    NULL AS approved_by,
    NULL AS rejected_by,
    NULL AS rejection_reason,
    created_by_user_id,
    created_at,
    updated_at,
    completed_at,
    'campaign' AS transaction_category,
    -- 캠페인 거래에는 현금 필드 없음
    NULL AS cash_amount,
    NULL AS payment_method,
    NULL AS bank_name,
    NULL AS account_number,
    NULL AS account_holder
FROM point_transactions;

COMMENT ON VIEW all_point_transactions IS '모든 포인트 거래 통합 뷰 (캠페인 + 현금)';
```

---

## 🔄 마이그레이션 단계별 계획

### Phase 1: 준비 단계 (1일)

#### 1.1 현재 데이터 백업
```sql
-- 백업 테이블 생성
CREATE TABLE user_point_logs_backup AS SELECT * FROM user_point_logs;
CREATE TABLE company_point_logs_backup AS SELECT * FROM company_point_logs;

-- 백업 확인
SELECT COUNT(*) FROM user_point_logs_backup;
SELECT COUNT(*) FROM company_point_logs_backup;
```

#### 1.2 의존성 분석
- 기존 테이블을 참조하는 함수/트리거/뷰 목록 작성
- Flutter 코드에서 사용하는 쿼리 패턴 분석
- RPC 함수 의존성 확인

---

### Phase 2: 새 테이블 생성 (1일)

#### 2.1 캠페인 거래 테이블 생성
```sql
-- point_transactions 테이블 생성
-- point_transaction_logs 테이블 생성
-- 인덱스 생성
```

#### 2.2 현금 거래 테이블 생성
```sql
-- point_cash_transactions 테이블 생성
-- point_cash_transaction_logs 테이블 생성
-- 인덱스 생성
```

#### 2.3 통합 View 생성
```sql
-- all_point_transactions View 생성
```

---

### Phase 3: 데이터 마이그레이션 (1일)

#### 3.1 캠페인 거래 데이터 마이그레이션

```sql
-- user_point_logs → point_transactions (earn 거래만)
INSERT INTO point_transactions (
    id,
    user_id,
    wallet_id,
    transaction_type,
    amount,
    campaign_id,
    related_entity_type,
    related_entity_id,
    description,
    created_by_user_id,
    created_at,
    updated_at,
    completed_at
)
SELECT 
    id,
    user_id,
    wallet_id,
    transaction_type, -- 'earn'
    amount,
    campaign_id,
    related_entity_type,
    related_entity_id,
    description,
    created_by_user_id,
    created_at,
    updated_at,
    COALESCE(completed_at, created_at) AS completed_at
FROM user_point_logs
WHERE transaction_type = 'earn'
  AND campaign_id IS NOT NULL; -- 캠페인 관련만

-- company_point_logs → point_transactions (spend 거래만)
INSERT INTO point_transactions (
    id,
    company_id,
    wallet_id,
    transaction_type,
    amount,
    campaign_id,
    related_entity_type,
    related_entity_id,
    description,
    created_by_user_id,
    created_at,
    updated_at,
    completed_at
)
SELECT 
    id,
    company_id,
    wallet_id,
    transaction_type, -- 'spend'
    amount,
    campaign_id,
    related_entity_type,
    related_entity_id,
    description,
    created_by_user_id,
    created_at,
    updated_at,
    COALESCE(completed_at, created_at) AS completed_at
FROM company_point_logs
WHERE transaction_type = 'spend'
  AND campaign_id IS NOT NULL; -- 캠페인 관련만
```

#### 3.2 현금 거래 데이터 마이그레이션

```sql
-- user_point_logs → point_cash_transactions (withdraw 거래만)
INSERT INTO point_cash_transactions (
    id,
    user_id,
    wallet_id,
    transaction_type,
    amount,
    status,
    description,
    created_by_user_id,
    created_at,
    updated_at,
    completed_at
)
SELECT 
    id,
    user_id,
    wallet_id,
    transaction_type, -- 'withdraw'
    amount,
    COALESCE(status, 'completed') AS status,
    description,
    created_by_user_id,
    created_at,
    updated_at,
    completed_at
FROM user_point_logs
WHERE transaction_type = 'withdraw'
  AND campaign_id IS NULL; -- 캠페인과 무관한 출금

-- company_point_logs → point_cash_transactions (deposit, withdraw, charge)
INSERT INTO point_cash_transactions (
    id,
    company_id,
    wallet_id,
    transaction_type,
    amount,
    cash_amount,
    payment_method,
    status,
    approved_by,
    rejected_by,
    rejection_reason,
    description,
    created_by_user_id,
    created_at,
    updated_at,
    completed_at
)
SELECT 
    id,
    company_id,
    wallet_id,
    CASE 
        WHEN transaction_type = 'charge' THEN 'deposit'
        ELSE transaction_type
    END AS transaction_type,
    amount,
    cash_amount,
    payment_method,
    COALESCE(status, 'completed') AS status,
    approved_by,
    rejected_by,
    rejection_reason,
    description,
    created_by_user_id,
    created_at,
    updated_at,
    completed_at
FROM company_point_logs
WHERE transaction_type IN ('deposit', 'withdraw', 'charge')
  AND campaign_id IS NULL; -- 캠페인과 무관한 현금 거래
```

#### 3.3 마이그레이션 검증

```sql
-- 데이터 개수 확인
SELECT 
    'user_point_logs (earn)' AS source,
    COUNT(*) AS count
FROM user_point_logs
WHERE transaction_type = 'earn' AND campaign_id IS NOT NULL
UNION ALL
SELECT 
    'point_transactions (user earn)' AS source,
    COUNT(*) AS count
FROM point_transactions
WHERE user_id IS NOT NULL AND transaction_type = 'earn'
UNION ALL
SELECT 
    'company_point_logs (spend)' AS source,
    COUNT(*) AS count
FROM company_point_logs
WHERE transaction_type = 'spend' AND campaign_id IS NOT NULL
UNION ALL
SELECT 
    'point_transactions (company spend)' AS source,
    COUNT(*) AS count
FROM point_transactions
WHERE company_id IS NOT NULL AND transaction_type = 'spend';

-- 금액 합계 확인
SELECT 
    'user_point_logs (earn)' AS source,
    SUM(amount) AS total_amount
FROM user_point_logs
WHERE transaction_type = 'earn' AND campaign_id IS NOT NULL
UNION ALL
SELECT 
    'point_transactions (user earn)' AS source,
    SUM(amount) AS total_amount
FROM point_transactions
WHERE user_id IS NOT NULL AND transaction_type = 'earn';
```

---

### Phase 4: 트리거 및 함수 생성 (2일)

#### 4.1 캠페인 거래 트리거

```sql
-- point_transactions 변경 시 로그 자동 생성
CREATE OR REPLACE FUNCTION log_point_transaction_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO point_transaction_logs (
            transaction_id,
            action,
            new_data,
            changed_by
        ) VALUES (
            NEW.id,
            'created',
            row_to_json(NEW)::jsonb,
            NEW.created_by_user_id
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO point_transaction_logs (
            transaction_id,
            action,
            old_data,
            new_data,
            changed_by,
            change_details
        ) VALUES (
            NEW.id,
            'updated',
            row_to_json(OLD)::jsonb,
            row_to_json(NEW)::jsonb,
            NEW.created_by_user_id,
            jsonb_build_object(
                'changed_fields', (
                    SELECT jsonb_object_agg(key, value)
                    FROM jsonb_each(row_to_json(NEW)::jsonb)
                    WHERE value IS DISTINCT FROM (row_to_json(OLD)::jsonb)->key
                )
            )
        );
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER point_transactions_log_trigger
    AFTER INSERT OR UPDATE ON point_transactions
    FOR EACH ROW
    EXECUTE FUNCTION log_point_transaction_change();
```

#### 4.2 현금 거래 트리거

```sql
-- point_cash_transactions 변경 시 로그 자동 생성
CREATE OR REPLACE FUNCTION log_point_cash_transaction_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO point_cash_transaction_logs (
            transaction_id,
            action,
            new_status,
            new_data,
            changed_by
        ) VALUES (
            NEW.id,
            'created',
            NEW.status,
            row_to_json(NEW)::jsonb,
            NEW.created_by_user_id
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        -- 상태 변경 추적
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            INSERT INTO point_cash_transaction_logs (
                transaction_id,
                action,
                old_status,
                new_status,
                old_data,
                new_data,
                changed_by,
                change_reason
            ) VALUES (
                NEW.id,
                'status_changed',
                OLD.status,
                NEW.status,
                row_to_json(OLD)::jsonb,
                row_to_json(NEW)::jsonb,
                COALESCE(NEW.approved_by, NEW.rejected_by, NEW.created_by_user_id),
                CASE 
                    WHEN NEW.status = 'rejected' THEN NEW.rejection_reason
                    ELSE NULL
                END
            );
        ELSE
            INSERT INTO point_cash_transaction_logs (
                transaction_id,
                action,
                old_data,
                new_data,
                changed_by
            ) VALUES (
                NEW.id,
                'updated',
                row_to_json(OLD)::jsonb,
                row_to_json(NEW)::jsonb,
                NEW.created_by_user_id
            );
        END IF;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER point_cash_transactions_log_trigger
    AFTER INSERT OR UPDATE ON point_cash_transactions
    FOR EACH ROW
    EXECUTE FUNCTION log_point_cash_transaction_change();
```

#### 4.3 지갑 잔액 업데이트 트리거

```sql
-- point_transactions 생성 시 지갑 잔액 업데이트
CREATE OR REPLACE FUNCTION update_wallet_balance_on_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE wallets
    SET balance = balance + NEW.amount,
        updated_at = NOW()
    WHERE id = NEW.wallet_id;
    RETURN NEW;
END;
$$;

CREATE TRIGGER point_transactions_wallet_balance_trigger
    AFTER INSERT ON point_transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_wallet_balance_on_transaction();

-- point_cash_transactions는 승인 후 완료 시에만 잔액 업데이트
CREATE OR REPLACE FUNCTION update_wallet_balance_on_cash_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- completed 상태로 변경될 때만 잔액 업데이트
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        UPDATE wallets
        SET balance = balance + NEW.amount,
            updated_at = NOW()
        WHERE id = NEW.wallet_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER point_cash_transactions_wallet_balance_trigger
    AFTER INSERT OR UPDATE ON point_cash_transactions
    FOR EACH ROW
    WHEN (NEW.status = 'completed')
    EXECUTE FUNCTION update_wallet_balance_on_cash_transaction();
```

---

### Phase 5: RPC 함수 생성 (2일)

#### 5.1 통합 조회 함수

```sql
-- 사용자 포인트 내역 통합 조회
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

-- 회사 포인트 내역 통합 조회
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

#### 5.2 캠페인 거래 함수

```sql
-- 캠페인 거래 생성
CREATE OR REPLACE FUNCTION create_point_transaction(
    p_user_id UUID DEFAULT NULL,
    p_company_id UUID DEFAULT NULL,
    p_wallet_id UUID,
    p_transaction_type TEXT,
    p_amount INTEGER,
    p_campaign_id UUID DEFAULT NULL,
    p_related_entity_type TEXT DEFAULT NULL,
    p_related_entity_id UUID DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_created_by_user_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_transaction_id UUID;
BEGIN
    -- 제약조건 검증
    IF (p_user_id IS NULL AND p_company_id IS NULL) OR
       (p_user_id IS NOT NULL AND p_company_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Either user_id or company_id must be provided, but not both';
    END IF;
    
    IF p_transaction_type NOT IN ('earn', 'spend') THEN
        RAISE EXCEPTION 'Invalid transaction_type. Must be earn or spend';
    END IF;
    
    -- company spend는 campaign_id 필수
    IF p_company_id IS NOT NULL AND p_transaction_type = 'spend' AND p_campaign_id IS NULL THEN
        RAISE EXCEPTION 'campaign_id is required for company spend transactions';
    END IF;
    
    -- 거래 생성
    INSERT INTO point_transactions (
        user_id,
        company_id,
        wallet_id,
        transaction_type,
        amount,
        campaign_id,
        related_entity_type,
        related_entity_id,
        description,
        created_by_user_id,
        completed_at
    ) VALUES (
        p_user_id,
        p_company_id,
        p_wallet_id,
        p_transaction_type,
        p_amount,
        p_campaign_id,
        p_related_entity_type,
        p_related_entity_id,
        p_description,
        COALESCE(p_created_by_user_id, auth.uid()),
        NOW()
    )
    RETURNING id INTO v_transaction_id;
    
    RETURN v_transaction_id;
END;
$$;
```

#### 5.3 현금 거래 함수

```sql
-- 현금 거래 생성
CREATE OR REPLACE FUNCTION create_point_cash_transaction(
    p_user_id UUID DEFAULT NULL,
    p_company_id UUID DEFAULT NULL,
    p_wallet_id UUID,
    p_transaction_type TEXT,
    p_amount INTEGER,
    p_cash_amount DECIMAL DEFAULT NULL,
    p_payment_method TEXT DEFAULT NULL,
    p_bank_name TEXT DEFAULT NULL,
    p_account_number TEXT DEFAULT NULL,
    p_account_holder TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_created_by_user_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_transaction_id UUID;
BEGIN
    -- 제약조건 검증
    IF (p_user_id IS NULL AND p_company_id IS NULL) OR
       (p_user_id IS NOT NULL AND p_company_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Either user_id or company_id must be provided, but not both';
    END IF;
    
    IF p_transaction_type NOT IN ('deposit', 'withdraw') THEN
        RAISE EXCEPTION 'Invalid transaction_type. Must be deposit or withdraw';
    END IF;
    
    -- 출금 시 계좌 정보 필수
    IF p_transaction_type = 'withdraw' AND (
        p_bank_name IS NULL OR 
        p_account_number IS NULL OR 
        p_account_holder IS NULL
    ) THEN
        RAISE EXCEPTION 'Bank account information is required for withdraw transactions';
    END IF;
    
    -- 거래 생성 (status는 기본값 'pending')
    INSERT INTO point_cash_transactions (
        user_id,
        company_id,
        wallet_id,
        transaction_type,
        amount,
        cash_amount,
        payment_method,
        bank_name,
        account_number,
        account_holder,
        description,
        created_by_user_id
    ) VALUES (
        p_user_id,
        p_company_id,
        p_wallet_id,
        p_transaction_type,
        p_amount,
        p_cash_amount,
        p_payment_method,
        p_bank_name,
        p_account_number,
        p_account_holder,
        p_description,
        COALESCE(p_created_by_user_id, auth.uid())
    )
    RETURNING id INTO v_transaction_id;
    
    RETURN v_transaction_id;
END;
$$;

-- 현금 거래 상태 업데이트 (승인/거절)
CREATE OR REPLACE FUNCTION update_point_cash_transaction_status(
    p_transaction_id UUID,
    p_status TEXT,
    p_rejection_reason TEXT DEFAULT NULL,
    p_updated_by_user_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_current_status TEXT;
BEGIN
    -- 현재 상태 확인
    SELECT status INTO v_current_status
    FROM point_cash_transactions
    WHERE id = p_transaction_id;
    
    IF v_current_status IS NULL THEN
        RAISE EXCEPTION 'Transaction not found';
    END IF;
    
    IF v_current_status = 'completed' THEN
        RAISE EXCEPTION 'Cannot update completed transaction';
    END IF;
    
    -- 상태 업데이트
    UPDATE point_cash_transactions
    SET 
        status = p_status,
        approved_by = CASE WHEN p_status = 'approved' THEN COALESCE(p_updated_by_user_id, auth.uid()) ELSE approved_by END,
        rejected_by = CASE WHEN p_status = 'rejected' THEN COALESCE(p_updated_by_user_id, auth.uid()) ELSE rejected_by END,
        rejection_reason = CASE WHEN p_status = 'rejected' THEN p_rejection_reason ELSE rejection_reason END,
        completed_at = CASE WHEN p_status = 'completed' THEN NOW() ELSE completed_at END,
        updated_at = NOW()
    WHERE id = p_transaction_id;
    
    RETURN TRUE;
END;
$$;
```

---

### Phase 6: RLS 정책 설정 (1일)

#### 6.1 point_transactions RLS

```sql
-- RLS 활성화
ALTER TABLE point_transactions ENABLE ROW LEVEL SECURITY;

-- 사용자는 본인의 거래만 조회 가능
CREATE POLICY "Users can view their own transactions"
    ON point_transactions
    FOR SELECT
    USING (user_id = auth.uid());

-- 회사 멤버는 회사 거래 조회 가능
CREATE POLICY "Company members can view company transactions"
    ON point_transactions
    FOR SELECT
    USING (
        company_id IN (
            SELECT company_id FROM company_users
            WHERE user_id = auth.uid() AND status = 'active'
        )
    );

-- 시스템이 거래 생성 가능 (트리거/함수에서)
CREATE POLICY "System can insert transactions"
    ON point_transactions
    FOR INSERT
    WITH CHECK (true);
```

#### 6.2 point_cash_transactions RLS

```sql
-- RLS 활성화
ALTER TABLE point_cash_transactions ENABLE ROW LEVEL SECURITY;

-- 사용자는 본인의 거래만 조회 가능
CREATE POLICY "Users can view their own cash transactions"
    ON point_cash_transactions
    FOR SELECT
    USING (user_id = auth.uid());

-- 회사 멤버는 회사 거래 조회 가능
CREATE POLICY "Company members can view company cash transactions"
    ON point_cash_transactions
    FOR SELECT
    USING (
        company_id IN (
            SELECT company_id FROM company_users
            WHERE user_id = auth.uid() AND status = 'active'
        )
    );

-- 사용자는 본인의 거래 생성 가능
CREATE POLICY "Users can create their own cash transactions"
    ON point_cash_transactions
    FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- 회사 멤버는 회사 거래 생성 가능
CREATE POLICY "Company members can create company cash transactions"
    ON point_cash_transactions
    FOR INSERT
    WITH CHECK (
        company_id IN (
            SELECT company_id FROM company_users
            WHERE user_id = auth.uid() AND status = 'active'
        )
    );

-- Admin만 상태 업데이트 가능
CREATE POLICY "Admins can update cash transaction status"
    ON point_cash_transactions
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE id = auth.uid() AND role = 'admin'
        )
    );
```

#### 6.3 로그 테이블 RLS

```sql
-- point_transaction_logs RLS
ALTER TABLE point_transaction_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view logs of their transactions"
    ON point_transaction_logs
    FOR SELECT
    USING (
        transaction_id IN (
            SELECT id FROM point_transactions
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Company members can view logs of company transactions"
    ON point_transaction_logs
    FOR SELECT
    USING (
        transaction_id IN (
            SELECT id FROM point_transactions
            WHERE company_id IN (
                SELECT company_id FROM company_users
                WHERE user_id = auth.uid() AND status = 'active'
            )
        )
    );

-- point_cash_transaction_logs RLS
ALTER TABLE point_cash_transaction_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view logs of their cash transactions"
    ON point_cash_transaction_logs
    FOR SELECT
    USING (
        transaction_id IN (
            SELECT id FROM point_cash_transactions
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Company members can view logs of company cash transactions"
    ON point_cash_transaction_logs
    FOR SELECT
    USING (
        transaction_id IN (
            SELECT id FROM point_cash_transactions
            WHERE company_id IN (
                SELECT company_id FROM company_users
                WHERE user_id = auth.uid() AND status = 'active'
            )
        )
    );
```

---

### Phase 7: Flutter 코드 업데이트 (2-3일)

#### 7.1 모델 클래스 생성

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

  UnifiedPointTransaction({
    required this.id,
    this.userId,
    this.companyId,
    this.walletId,
    required this.transactionType,
    required this.amount,
    this.description,
    this.relatedEntityType,
    this.relatedEntityId,
    this.campaignId,
    this.createdByUserId,
    required this.status,
    this.approvedBy,
    this.rejectedBy,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    required this.transactionCategory,
    this.cashAmount,
    this.paymentMethod,
    this.bankName,
    this.accountNumber,
    this.accountHolder,
  });

  // 편의 getter
  bool get isUserTransaction => userId != null;
  bool get isCompanyTransaction => companyId != null;
  bool get isCampaignTransaction => transactionCategory == 'campaign';
  bool get isCashTransaction => transactionCategory == 'cash';
  bool get isEarn => transactionType == 'earn';
  bool get isSpend => transactionType == 'spend';
  bool get isDeposit => transactionType == 'deposit';
  bool get isWithdraw => transactionType == 'withdraw';
  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  
  factory UnifiedPointTransaction.fromJson(Map<String, dynamic> json) {
    return UnifiedPointTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      companyId: json['company_id'] as String?,
      walletId: json['wallet_id'] as String?,
      transactionType: json['transaction_type'] as String,
      amount: json['amount'] as int,
      description: json['description'] as String?,
      relatedEntityType: json['related_entity_type'] as String?,
      relatedEntityId: json['related_entity_id'] as String?,
      campaignId: json['campaign_id'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      status: json['status'] as String,
      approvedBy: json['approved_by'] as String?,
      rejectedBy: json['rejected_by'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'] as String) 
          : null,
      transactionCategory: json['transaction_category'] as String,
      cashAmount: json['cash_amount'] != null 
          ? (json['cash_amount'] as num).toDouble() 
          : null,
      paymentMethod: json['payment_method'] as String?,
      bankName: json['bank_name'] as String?,
      accountNumber: json['account_number'] as String?,
      accountHolder: json['account_holder'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'company_id': companyId,
      'wallet_id': walletId,
      'transaction_type': transactionType,
      'amount': amount,
      'description': description,
      'related_entity_type': relatedEntityType,
      'related_entity_id': relatedEntityId,
      'campaign_id': campaignId,
      'created_by_user_id': createdByUserId,
      'status': status,
      'approved_by': approvedBy,
      'rejected_by': rejectedBy,
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'transaction_category': transactionCategory,
      'cash_amount': cashAmount,
      'payment_method': paymentMethod,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_holder': accountHolder,
    };
  }
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
  final DateTime? completedAt;
  
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
```

#### 7.2 서비스 클래스 업데이트

**파일: `lib/services/wallet_service.dart`**

```dart
// 통합 조회 함수 (캠페인 + 현금 거래 모두)
static Future<List<UnifiedPointTransaction>> getUserPointHistoryUnified({
  int limit = 50,
  int offset = 0,
}) async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) return [];
  
  try {
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
  } catch (e) {
    print('Error getting unified point history: $e');
    rethrow;
  }
}

// 회사 통합 조회
static Future<List<UnifiedPointTransaction>> getCompanyPointHistoryUnified({
  required String companyId,
  int limit = 50,
  int offset = 0,
}) async {
  try {
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
  } catch (e) {
    print('Error getting company unified point history: $e');
    rethrow;
  }
}

// 캠페인 거래 생성
static Future<String> createPointTransaction({
  String? userId,
  String? companyId,
  required String walletId,
  required String transactionType, // 'earn' or 'spend'
  required int amount,
  String? campaignId,
  String? relatedEntityType,
  String? relatedEntityId,
  String? description,
}) async {
  try {
    final response = await _supabase.rpc(
      'create_point_transaction',
      params: {
        'p_user_id': userId,
        'p_company_id': companyId,
        'p_wallet_id': walletId,
        'p_transaction_type': transactionType,
        'p_amount': amount,
        'p_campaign_id': campaignId,
        'p_related_entity_type': relatedEntityType,
        'p_related_entity_id': relatedEntityId,
        'p_description': description,
      },
    );
    
    return response as String;
  } catch (e) {
    print('Error creating point transaction: $e');
    rethrow;
  }
}

// 현금 거래 생성
static Future<String> createPointCashTransaction({
  String? userId,
  String? companyId,
  required String walletId,
  required String transactionType, // 'deposit' or 'withdraw'
  required int amount,
  double? cashAmount,
  String? paymentMethod,
  String? bankName,
  String? accountNumber,
  String? accountHolder,
  String? description,
}) async {
  try {
    final response = await _supabase.rpc(
      'create_point_cash_transaction',
      params: {
        'p_user_id': userId,
        'p_company_id': companyId,
        'p_wallet_id': walletId,
        'p_transaction_type': transactionType,
        'p_amount': amount,
        'p_cash_amount': cashAmount,
        'p_payment_method': paymentMethod,
        'p_bank_name': bankName,
        'p_account_number': accountNumber,
        'p_account_holder': accountHolder,
        'p_description': description,
      },
    );
    
    return response as String;
  } catch (e) {
    print('Error creating point cash transaction: $e');
    rethrow;
  }
}

// 현금 거래 상태 업데이트 (Admin 전용)
static Future<bool> updatePointCashTransactionStatus({
  required String transactionId,
  required String status, // 'approved', 'rejected', 'completed'
  String? rejectionReason,
}) async {
  try {
    final response = await _supabase.rpc(
      'update_point_cash_transaction_status',
      params: {
        'p_transaction_id': transactionId,
        'p_status': status,
        'p_rejection_reason': rejectionReason,
      },
    );
    
    return response as bool;
  } catch (e) {
    print('Error updating point cash transaction status: $e');
    rethrow;
  }
}
```

---

### Phase 8: 기존 테이블 제거 (1일)

#### 8.1 의존성 제거 확인

```sql
-- 기존 테이블을 참조하는 모든 객체 확인
SELECT 
    schemaname,
    tablename,
    indexname
FROM pg_indexes
WHERE tablename IN ('user_point_logs', 'company_point_logs');

-- 기존 테이블을 참조하는 함수 확인
SELECT 
    routine_name,
    routine_definition
FROM information_schema.routines
WHERE routine_definition LIKE '%user_point_logs%'
   OR routine_definition LIKE '%company_point_logs%';
```

#### 8.2 기존 테이블 제거

```sql
-- 기존 테이블 제거 (주의: 백업 확인 후 진행)
DROP TABLE IF EXISTS user_point_logs CASCADE;
DROP TABLE IF EXISTS company_point_logs CASCADE;

-- 백업 테이블은 유지 (필요시 나중에 삭제)
-- DROP TABLE IF EXISTS user_point_logs_backup;
-- DROP TABLE IF EXISTS company_point_logs_backup;
```

---

## 📝 마이그레이션 파일 구조

```
supabase/migrations/
  YYYYMMDDHHMMSS_backup_point_logs.sql
  YYYYMMDDHHMMSS_create_point_transactions.sql
  YYYYMMDDHHMMSS_create_point_transaction_logs.sql
  YYYYMMDDHHMMSS_create_point_cash_transactions.sql
  YYYYMMDDHHMMSS_create_point_cash_transaction_logs.sql
  YYYYMMDDHHMMSS_create_all_point_transactions_view.sql
  YYYYMMDDHHMMSS_migrate_campaign_transactions.sql
  YYYYMMDDHHMMSS_migrate_cash_transactions.sql
  YYYYMMDDHHMMSS_create_triggers.sql
  YYYYMMDDHHMMSS_create_rpc_functions.sql
  YYYYMMDDHHMMSS_create_rls_policies.sql
  YYYYMMDDHHMMSS_drop_old_tables.sql
```

---

## ✅ 체크리스트

### 데이터베이스
- [ ] 기존 데이터 백업
- [ ] `point_transactions` 테이블 생성
- [ ] `point_transaction_logs` 테이블 생성
- [ ] `point_cash_transactions` 테이블 생성
- [ ] `point_cash_transaction_logs` 테이블 생성
- [ ] `all_point_transactions` View 생성
- [ ] 캠페인 거래 데이터 마이그레이션
- [ ] 현금 거래 데이터 마이그레이션
- [ ] 트리거 생성 (로그 자동 생성, 지갑 잔액 업데이트)
- [ ] 통합 조회 RPC 함수 생성
- [ ] 캠페인 거래 RPC 함수 생성
- [ ] 현금 거래 RPC 함수 생성
- [ ] RLS 정책 설정
- [ ] 인덱스 최적화
- [ ] 기존 테이블 제거

### Flutter 코드
- [ ] `UnifiedPointTransaction` 모델 클래스 생성
- [ ] `PointTransaction` 모델 클래스 생성
- [ ] `PointCashTransaction` 모델 클래스 생성
- [ ] `wallet_service.dart` 통합 조회 함수 추가
- [ ] `wallet_service.dart` 캠페인 거래 함수 추가
- [ ] `wallet_service.dart` 현금 거래 함수 추가
- [ ] UI 화면 업데이트 (통합 내역 표시)
- [ ] 테스트 코드 업데이트

### 문서화
- [ ] API 문서 업데이트
- [ ] 데이터베이스 스키마 문서 업데이트
- [ ] 개발자 가이드 업데이트

---

## ⚠️ 주의사항

1. **데이터 마이그레이션 전 백업 필수**
2. **트랜잭션 사용**: 마이그레이션은 트랜잭션으로 감싸서 실행
3. **단계별 검증**: 각 단계마다 데이터 검증 수행
4. **롤백 계획**: 문제 발생 시 롤백 방법 준비
5. **다운타임 최소화**: 가능한 한 단계적으로 마이그레이션

---

## 📊 예상 소요 시간

- **Phase 1**: 1일 (준비)
- **Phase 2**: 1일 (테이블 생성)
- **Phase 3**: 1일 (데이터 마이그레이션)
- **Phase 4**: 2일 (트리거/함수)
- **Phase 5**: 2일 (RPC 함수)
- **Phase 6**: 1일 (RLS)
- **Phase 7**: 2-3일 (Flutter 코드)
- **Phase 8**: 1일 (정리)

**총 예상 시간: 11-12일**

