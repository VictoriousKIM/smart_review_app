# 포인트 입출금 시스템 구현 로드맵

## 📋 현재 데이터베이스 구조 분석

### 기존 테이블
- `wallets`: 통합 지갑 테이블 (id PK, company_id 또는 user_id FK, 둘 중 하나 필수)
- `user_point_logs`: 개인 포인트 거래 내역 (삭제 예정)
- `company_point_logs`: 회사 포인트 거래 내역 (삭제 예정)
- `campaign_events`: 캠페인 이벤트 (참고 패턴)
- `campaign_user_status`: 캠페인 사용자 상태 (참고 패턴)
- `company_users`: 회사-사용자 관계 (role: owner, manager)

### 지갑 테이블 통합
- `user_wallets`와 `company_wallets`가 `wallets`로 통합됨
- `wallets` 테이블은 `id` (UUID)를 PK로 사용
- `company_id`와 `user_id`는 FK이며, 둘 중 하나는 반드시 있어야 함 (CHECK 제약조건)
- 기존 데이터는 모두 마이그레이션되어 보존됨

### 참고 패턴
캠페인 시스템은 `campaign_events`(이벤트 로그)와 `campaign_user_status`(현재 상태)로 분리되어 있어, 이벤트 기반 아키텍처를 따르고 있습니다.

---

## 🎯 구현 목표

1. **회사 입금/출금**: owner만 가능, 계좌입금만 지원
2. **회사 포인트 소비(spend)**: owner 또는 manager 가능 (캠페인 생성 시 등)
3. **유저 출금**: 본인만 가능
4. **트랜잭션 아토믹 필수** (원자성 보장)
5. **이벤트 기반 아키텍처**: 캠페인 패턴과 일관성 유지
6. **Admin 승인 프로세스**: 신청 → admin 확인 → 승인 → 포인트 변동

---

## 📐 데이터베이스 설계

### 0. 통합 지갑 테이블 (wallets)

```sql
-- 통합 지갑 테이블 (이미 마이그레이션으로 생성됨)
CREATE TABLE wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 지갑 소유자 정보 (FK) - 둘 중 하나는 반드시 있어야 함
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- 포인트 정보
    current_points INTEGER DEFAULT 0 NOT NULL CHECK (current_points >= 0),
    
    -- 계좌 정보 (출금용)
    withdraw_bank_name TEXT,
    withdraw_account_number TEXT,
    withdraw_account_holder TEXT,
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- 제약조건: company_id 또는 user_id 중 하나는 반드시 있어야 함
    CONSTRAINT wallets_owner_check CHECK (
        (company_id IS NOT NULL AND user_id IS NULL) OR
        (company_id IS NULL AND user_id IS NOT NULL)
    )
);

-- 인덱스
CREATE INDEX idx_wallets_company_id ON wallets(company_id) WHERE company_id IS NOT NULL;
CREATE INDEX idx_wallets_user_id ON wallets(user_id) WHERE user_id IS NOT NULL;
```

**참고**: `user_wallets`와 `company_wallets`는 이미 `wallets`로 통합되었습니다. 
마이그레이션 스크립트: `supabase/migrations/20250107000000_unify_wallets.sql`

### 0-1. 회사 지갑 계좌 변경 로그 테이블 (Company Wallet Account Change Logs) - 선택사항

```sql
CREATE TABLE company_wallet_account_change_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 지갑 참조 (FK) - wallets.id 사용
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    -- 또는 company_id로 직접 참조 (하위 호환성)
    company_id UUID, -- wallets.company_id와 동기화
    
    -- 변경 필드 정보
    old_value JSONB, -- 예: {"withdraw_bank_name": "하나은행", "withdraw_account_number": "123-456-7890", "withdraw_account_holder": "홍길동"}
    new_value JSONB, -- 예: {"withdraw_bank_name": "신한은행", "withdraw_account_number": "222-333-4444", "withdraw_account_holder": "홍길동"}
    -- 변경자 정보
    changed_by UUID REFERENCES users(id),
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 인덱스
CREATE INDEX idx_company_wallet_account_change_logs_company_id ON company_wallet_account_change_logs(company_id);
CREATE INDEX idx_company_wallet_account_change_logs_created_at ON company_wallet_account_change_logs(created_at DESC);
CREATE INDEX idx_company_wallet_account_change_logs_changed_by ON company_wallet_account_change_logs(changed_by);
```

### 0-2. 유저 지갑 계좌 변경 로그 테이블 (User Wallet Account Change Logs)

```sql
CREATE TABLE user_wallet_account_change_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 지갑 정보 (wallets.id 참조)
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    user_id UUID, -- wallets.user_id와 동기화 (하위 호환성)
    
    -- 변경 필드 정보
    old_value JSONB, -- 예: {"withdraw_bank_name": "하나은행", "withdraw_account_number": "123-456-7890", "withdraw_account_holder": "홍길동"}
    new_value JSONB, -- 예: {"withdraw_bank_name": "신한은행", "withdraw_account_number": "222-333-4444", "withdraw_account_holder": "홍길동"}
    
    -- 변경자 정보
    changed_by UUID REFERENCES users(id),
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 인덱스
CREATE INDEX idx_user_wallet_account_change_logs_user_id ON user_wallet_account_change_logs(user_id);
CREATE INDEX idx_user_wallet_account_change_logs_created_at ON user_wallet_account_change_logs(created_at DESC);
CREATE INDEX idx_user_wallet_account_change_logs_changed_by ON user_wallet_account_change_logs(changed_by);
```

### 1. 회사 포인트 이벤트 테이블 (Company Point Events)

```sql
CREATE TABLE company_point_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 상태 참조 (FK) - status가 생성/수정될 때마다 event 생성
    status_id UUID NOT NULL UNIQUE REFERENCES company_point_status(id) ON DELETE CASCADE,
    
    -- 지갑 참조 (FK) - wallets.id 사용
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    -- 또는 company_id로 직접 참조 (하위 호환성)
    company_id UUID, -- wallets.company_id와 동기화
    
    -- 거래 정보
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('deposit', 'withdraw', 'spend')),
    amount INTEGER NOT NULL CHECK (amount > 0),
    
    -- 이벤트 메타데이터
    description TEXT,
    related_entity_type TEXT, -- 'campaign', 'refund', etc.
    related_entity_id UUID,
    
    -- 캠페인 참조 (FK) - spend 트랜잭션 전용
    -- 입금/출금에서는 NULL (정상), spend에서는 필수
    campaign_id UUID REFERENCES campaigns(id) ON DELETE SET NULL,
    
    -- 사용자 정보
    requested_by UUID REFERENCES users(id), -- owner (입금/출금), owner 또는 manager (소비)
    approved_by UUID REFERENCES users(id), -- admin
    rejected_by UUID REFERENCES users(id),
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- 인덱스
CREATE INDEX idx_company_point_events_status_id ON company_point_events(status_id);
CREATE INDEX idx_company_point_events_company_id ON company_point_events(company_id);
CREATE INDEX idx_company_point_events_type ON company_point_events(transaction_type);
CREATE INDEX idx_company_point_events_created_at ON company_point_events(created_at DESC);
CREATE INDEX idx_company_point_events_requested_by ON company_point_events(requested_by);
CREATE INDEX idx_company_point_events_campaign_id ON company_point_events(campaign_id) WHERE campaign_id IS NOT NULL;
```

### 2. 회사 포인트 상태 테이블 (Company Point Status)

```sql
CREATE TABLE company_point_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 지갑 참조 (FK) - wallets.id 사용
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    -- 또는 company_id로 직접 참조 (하위 호환성)
    company_id UUID, -- wallets.company_id와 동기화
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('deposit', 'withdraw', 'spend')),
    
    -- 상태 정보
    status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected', 'completed', 'cancelled')),
    
    -- 거래 정보 (status 생성 시 필요)
    amount INTEGER NOT NULL CHECK (amount > 0),
    description TEXT,
    related_entity_type TEXT,
    related_entity_id UUID,
    
    -- 캠페인 참조 (FK) - spend 트랜잭션 전용
    -- 입금/출금에서는 NULL (정상), spend에서는 필수
    campaign_id UUID REFERENCES campaigns(id) ON DELETE SET NULL,
    
    -- 사용자 정보
    requested_by UUID REFERENCES users(id),
    approved_by UUID REFERENCES users(id),
    rejected_by UUID REFERENCES users(id),
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 제약조건: spend 트랜잭션일 때만 campaign_id 필수
-- 입금/출금에서는 campaign_id가 NULL (정상, FK 제약조건은 NULL을 허용)
ALTER TABLE company_point_status
ADD CONSTRAINT check_spend_has_campaign 
CHECK (
  (transaction_type = 'spend' AND campaign_id IS NOT NULL) OR
  (transaction_type != 'spend' AND campaign_id IS NULL)
);
COMMENT ON CONSTRAINT check_spend_has_campaign ON company_point_status IS 
'입금/출금에서는 campaign_id가 NULL이어야 하고, spend에서는 NOT NULL이어야 함. NULL은 FK 제약조건 검증을 건너뛰므로 정상 동작함.';

-- 인덱스
CREATE INDEX idx_company_point_status_company_id ON company_point_status(company_id);
CREATE INDEX idx_company_point_status_status ON company_point_status(status);
CREATE INDEX idx_company_point_status_type ON company_point_status(transaction_type);
CREATE INDEX idx_company_point_status_created_at ON company_point_status(created_at DESC);
CREATE INDEX idx_company_point_status_campaign_id ON company_point_status(campaign_id) WHERE campaign_id IS NOT NULL;
```

### 3. 유저 포인트 이벤트 테이블 (User Point Events)

```sql
CREATE TABLE user_point_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 상태 참조 (FK) - status가 생성/수정될 때마다 event 생성
    status_id UUID NOT NULL UNIQUE REFERENCES user_point_status(id) ON DELETE CASCADE,
    
    -- 지갑 참조 (FK) - wallets.id 사용
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    -- 또는 user_id로 직접 참조 (하위 호환성)
    user_id UUID, -- wallets.user_id와 동기화
    
    -- 거래 정보
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('withdraw', 'spend')),
    amount INTEGER NOT NULL CHECK (amount > 0),
    
    -- 이벤트 메타데이터
    description TEXT,
    related_entity_type TEXT, -- 'campaign', 'refund', etc.
    related_entity_id UUID,
    
    -- 사용자 정보
    requested_by UUID REFERENCES users(id), -- 본인
    approved_by UUID REFERENCES users(id), -- admin
    rejected_by UUID REFERENCES users(id),
    rejection_reason TEXT,
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- 인덱스
CREATE INDEX idx_user_point_events_status_id ON user_point_events(status_id);
CREATE INDEX idx_user_point_events_user_id ON user_point_events(user_id);
CREATE INDEX idx_user_point_events_type ON user_point_events(transaction_type);
CREATE INDEX idx_user_point_events_created_at ON user_point_events(created_at DESC);
CREATE INDEX idx_user_point_events_requested_by ON user_point_events(requested_by);
```

### 4. 유저 포인트 상태 테이블 (User Point Status)

```sql
CREATE TABLE user_point_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 지갑 정보
    user_id UUID NOT NULL REFERENCES user_wallets(user_id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('withdraw', 'spend')),
    
    -- 상태 정보
    status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected', 'completed', 'cancelled')),
    
    -- 거래 정보 (status 생성 시 필요)
    amount INTEGER NOT NULL CHECK (amount > 0),
    description TEXT,
    related_entity_type TEXT,
    related_entity_id UUID,
    
    -- 사용자 정보
    requested_by UUID REFERENCES users(id),
    approved_by UUID REFERENCES users(id),
    rejected_by UUID REFERENCES users(id),
    rejection_reason TEXT,
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 인덱스
CREATE INDEX idx_user_point_status_user_id ON user_point_status(user_id);
CREATE INDEX idx_user_point_status_status ON user_point_status(status);
CREATE INDEX idx_user_point_status_type ON user_point_status(transaction_type);
CREATE INDEX idx_user_point_status_created_at ON user_point_status(created_at DESC);
```

---

## 🔄 트리거 함수 (포인트 자동 변동)

### 1. 회사 포인트 상태 트리거 (Company Point Status Trigger)

```sql
CREATE OR REPLACE FUNCTION sync_company_point_event_on_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_event_id UUID;
BEGIN
    -- 1. company_point_events 테이블에 새 이벤트 생성 (status가 생성/수정될 때마다)
        INSERT INTO company_point_events (
        status_id,
        company_id,
        transaction_type,
        amount,
        description,
        campaign_id, -- status의 campaign_id 복사
        related_entity_type,
        related_entity_id,
        requested_by,
        approved_by,
        rejected_by,
        created_at,
        updated_at,
        completed_at
    )
    VALUES (
        NEW.id,
        NEW.company_id,
        NEW.transaction_type,
        NEW.amount,
        NEW.description,
        NEW.campaign_id, -- status의 campaign_id 복사
        NEW.related_entity_type,
        NEW.related_entity_id,
        NEW.requested_by,
        NEW.approved_by,
        NEW.rejected_by,
        NEW.created_at,
        NEW.updated_at,
        CASE WHEN NEW.status = 'completed' THEN NOW() ELSE NULL END
    )
    ON CONFLICT (status_id)
    DO UPDATE SET
        amount = EXCLUDED.amount,
        description = EXCLUDED.description,
        campaign_id = EXCLUDED.campaign_id, -- campaign_id도 업데이트
        related_entity_type = EXCLUDED.related_entity_type,
        related_entity_id = EXCLUDED.related_entity_id,
        approved_by = EXCLUDED.approved_by,
        rejected_by = EXCLUDED.rejected_by,
        updated_at = EXCLUDED.updated_at,
        completed_at = CASE WHEN NEW.status = 'completed' THEN NOW() ELSE company_point_events.completed_at END
    RETURNING id INTO v_event_id;
    
    -- 2. status가 'completed'인 경우 포인트 변동
    IF NEW.status = 'completed' THEN
        IF NEW.transaction_type = 'deposit' THEN
            -- 입금: 포인트 추가
            UPDATE company_wallets
            SET current_points = current_points + NEW.amount,
                updated_at = NOW()
            WHERE company_id = NEW.company_id;
            
        ELSIF NEW.transaction_type = 'withdraw' THEN
            -- 출금: 포인트 차감
            UPDATE company_wallets
            SET current_points = current_points - NEW.amount,
                updated_at = NOW()
            WHERE company_id = NEW.company_id
            AND current_points >= NEW.amount; -- 잔액 확인
            
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Insufficient points for withdrawal';
            END IF;
            
        ELSIF NEW.transaction_type = 'spend' THEN
            -- 사용: 포인트 차감
            UPDATE company_wallets
            SET current_points = current_points - NEW.amount,
                updated_at = NOW()
            WHERE company_id = NEW.company_id
            AND current_points >= NEW.amount; -- 잔액 확인
            
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Insufficient points for spending';
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER sync_company_point_event_trigger
    AFTER INSERT OR UPDATE ON company_point_status
    FOR EACH ROW
    EXECUTE FUNCTION sync_company_point_event_on_status();
```

### 2. 유저 포인트 상태 트리거 (User Point Status Trigger)

```sql
CREATE OR REPLACE FUNCTION sync_user_point_event_on_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_event_id UUID;
BEGIN
    -- 1. user_point_events 테이블에 새 이벤트 생성 (status가 생성/수정될 때마다)
    INSERT INTO user_point_events (
        status_id,
        user_id,
        transaction_type,
        amount,
        description,
        related_entity_type,
        related_entity_id,
        requested_by,
        approved_by,
        rejected_by,
        rejection_reason,
        created_at,
        updated_at,
        completed_at
    )
    VALUES (
        NEW.id,
        NEW.user_id,
        NEW.transaction_type,
        NEW.amount,
        NEW.description,
        NEW.related_entity_type,
        NEW.related_entity_id,
        NEW.requested_by,
        NEW.approved_by,
        NEW.rejected_by,
        NEW.rejection_reason,
        NEW.created_at,
        NEW.updated_at,
        CASE WHEN NEW.status = 'completed' THEN NOW() ELSE NULL END
    )
    ON CONFLICT (status_id)
    DO UPDATE SET
        amount = EXCLUDED.amount,
        description = EXCLUDED.description,
        related_entity_type = EXCLUDED.related_entity_type,
        related_entity_id = EXCLUDED.related_entity_id,
        approved_by = EXCLUDED.approved_by,
        rejected_by = EXCLUDED.rejected_by,
        rejection_reason = EXCLUDED.rejection_reason,
        updated_at = EXCLUDED.updated_at,
        completed_at = CASE WHEN NEW.status = 'completed' THEN NOW() ELSE user_point_events.completed_at END
    RETURNING id INTO v_event_id;
    
    -- 2. status가 'completed'인 경우 포인트 변동
    IF NEW.status = 'completed' THEN
        IF NEW.transaction_type = 'withdraw' THEN
            -- 출금: 포인트 차감
            UPDATE user_wallets
            SET current_points = current_points - NEW.amount,
                updated_at = NOW()
            WHERE user_id = NEW.user_id
            AND current_points >= NEW.amount; -- 잔액 확인
            
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Insufficient points for withdrawal';
            END IF;
            
        ELSIF NEW.transaction_type = 'spend' THEN
            -- 사용: 포인트 차감
            UPDATE user_wallets
            SET current_points = current_points - NEW.amount,
                updated_at = NOW()
            WHERE user_id = NEW.user_id
            AND current_points >= NEW.amount; -- 잔액 확인
            
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Insufficient points for spending';
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER sync_user_point_event_trigger
    AFTER INSERT OR UPDATE ON user_point_status
    FOR EACH ROW
    EXECUTE FUNCTION sync_user_point_event_on_status();
```

---

## 🔧 RPC 함수 설계

### 1. 회사 포인트 입금 요청 (Company Deposit Request)

```sql
CREATE OR REPLACE FUNCTION request_company_point_deposit(
    p_company_id UUID,
    p_amount INTEGER,
    p_description TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_company_role TEXT;
    v_status_id UUID;
    v_result JSONB;
BEGIN
    -- 1. 인증 확인
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 2. 회사 지갑 존재 확인
    IF NOT EXISTS (SELECT 1 FROM company_wallets WHERE company_id = p_company_id) THEN
        RAISE EXCEPTION 'Company wallet not found';
    END IF;
    
    -- 3. 권한 확인: owner만 가능
    SELECT company_role INTO v_company_role
    FROM company_users
    WHERE company_id = p_company_id
    AND user_id = v_user_id
    AND status = 'active'
    AND company_role = 'owner'
    LIMIT 1;
    
    IF v_company_role IS NULL THEN
        RAISE EXCEPTION 'Only company owner can request deposit';
    END IF;
    
    -- 4. 트랜잭션 시작 (원자성 보장)
    BEGIN
        -- 4-1. status 생성 (트리거가 자동으로 event 생성)
        INSERT INTO company_point_status (
            company_id,
            transaction_type,
            status,
            amount,
            description,
            requested_by,
            created_at,
            updated_at
        ) VALUES (
            p_company_id,
            'deposit',
            'pending',
            p_amount,
            p_description,
            v_user_id,
            NOW(),
            NOW()
        ) RETURNING id INTO v_status_id;
        
        -- 4-2. 결과 반환
        SELECT jsonb_build_object(
            'success', true,
            'status_id', v_status_id,
            'status', 'pending',
            'amount', p_amount
        ) INTO v_result;
        
        RETURN v_result;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE;
    END;
END;
$$;
```

### 2. 회사 포인트 입금 승인 (Company Deposit Approve)

```sql
CREATE OR REPLACE FUNCTION approve_company_point_deposit(
    p_status_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_user_type TEXT;
    v_status RECORD;
    v_result JSONB;
BEGIN
    -- 1. 인증 확인
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 2. Admin 권한 확인
    SELECT user_type INTO v_user_type
    FROM users
    WHERE id = v_user_id;
    
    IF v_user_type NOT IN ('admin', 'ADMIN') THEN
        RAISE EXCEPTION 'Only admin can approve deposits';
    END IF;
    
    -- 3. status 조회 및 잠금
    SELECT * INTO v_status
    FROM company_point_status
    WHERE id = p_status_id
    FOR UPDATE;
    
    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Status not found';
    END IF;
    
    IF v_status.status != 'pending' THEN
        RAISE EXCEPTION 'Status is not in pending state: %', v_status.status;
    END IF;
    
    -- 4. 트랜잭션 시작
    BEGIN
        -- 4-1. 상태를 completed로 변경 (트리거가 포인트 자동 추가 및 event 생성/업데이트)
        UPDATE company_point_status
        SET status = 'completed',
            approved_by = v_user_id,
            updated_at = NOW()
        WHERE id = p_status_id;
        
        -- 4-2. 결과 반환
        SELECT jsonb_build_object(
            'success', true,
            'status_id', p_status_id,
            'status', 'completed',
            'amount', v_status.amount,
            'company_id', v_status.company_id
        ) INTO v_result;
        
        RETURN v_result;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE;
    END;
END;
$$;
```

### 3. 회사 포인트 출금 요청 (Company Withdraw Request)

```sql
CREATE OR REPLACE FUNCTION request_company_point_withdraw(
    p_company_id UUID,
    p_amount INTEGER,
    p_description TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_company_role TEXT;
    v_current_points INTEGER;
    v_event_id UUID;
    v_result JSONB;
BEGIN
    -- 1. 인증 확인
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 2. 회사 지갑 조회 및 잠금
    SELECT current_points INTO v_current_points
    FROM company_wallets
    WHERE company_id = p_company_id
    FOR UPDATE;
    
    IF v_current_points IS NULL THEN
        RAISE EXCEPTION 'Company wallet not found';
    END IF;
    
    -- 3. 잔액 확인
    IF v_current_points < p_amount THEN
        RAISE EXCEPTION 'Insufficient points (available: %, requested: %)', 
            v_current_points, p_amount;
    END IF;
    
    -- 4. 권한 확인: owner만 가능
    SELECT company_role INTO v_company_role
    FROM company_users
    WHERE company_id = p_company_id
    AND user_id = v_user_id
    AND status = 'active'
    AND company_role = 'owner'
    LIMIT 1;
    
    IF v_company_role IS NULL THEN
        RAISE EXCEPTION 'Only company owner can request withdrawal';
    END IF;
    
    -- 5. 지갑에서 출금 계좌 정보 확인
    IF NOT EXISTS (
        SELECT 1 FROM company_wallets 
        WHERE company_id = p_company_id 
        AND withdraw_bank_name IS NOT NULL 
        AND withdraw_account_number IS NOT NULL
        AND withdraw_account_holder IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Withdrawal account information not set in wallet. Please set withdrawal account first.';
    END IF;
    
    -- 6. 트랜잭션 시작
    BEGIN
        -- 6-1. status 생성 (트리거가 자동으로 event 생성)
        INSERT INTO company_point_status (
            company_id,
            transaction_type,
            status,
            amount,
            description,
            requested_by,
            created_at,
            updated_at
        ) VALUES (
            p_company_id,
            'withdraw',
            'pending',
            p_amount,
            p_description,
            v_user_id,
            NOW(),
            NOW()
        ) RETURNING id INTO v_status_id;
        
        -- 6-2. 결과 반환
        SELECT jsonb_build_object(
            'success', true,
            'status_id', v_status_id,
            'status', 'pending',
            'amount', p_amount,
            'current_balance', v_current_points
        ) INTO v_result;
        
        RETURN v_result;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE;
    END;
END;
$$;
```

### 4. 회사 포인트 출금 승인 (Company Withdraw Approve)

```sql
CREATE OR REPLACE FUNCTION approve_company_point_withdraw(
    p_status_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_user_type TEXT;
    v_status RECORD;
    v_current_points INTEGER;
    v_result JSONB;
BEGIN
    -- 1. 인증 확인
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 2. Admin 권한 확인
    SELECT user_type INTO v_user_type
    FROM users
    WHERE id = v_user_id;
    
    IF v_user_type NOT IN ('admin', 'ADMIN') THEN
        RAISE EXCEPTION 'Only admin can approve withdrawals';
    END IF;
    
    -- 3. status 조회 및 잠금
    SELECT * INTO v_status
    FROM company_point_status
    WHERE id = p_status_id
    FOR UPDATE;
    
    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Status not found';
    END IF;
    
    IF v_status.status != 'pending' THEN
        RAISE EXCEPTION 'Status is not in pending state: %', v_status.status;
    END IF;
    
    -- 4. 잔액 재확인
    SELECT current_points INTO v_current_points
    FROM company_wallets
    WHERE company_id = v_status.company_id
    FOR UPDATE;
    
    IF v_current_points < v_status.amount THEN
        RAISE EXCEPTION 'Insufficient points (available: %, requested: %)', 
            v_current_points, v_status.amount;
    END IF;
    
    -- 5. 트랜잭션 시작
    BEGIN
        -- 5-1. 상태를 completed로 변경 (트리거가 포인트 자동 차감 및 event 생성/업데이트)
        UPDATE company_point_status
        SET status = 'completed',
            approved_by = v_user_id,
            updated_at = NOW()
        WHERE id = p_status_id;
        
        -- 5-2. 결과 반환
        SELECT jsonb_build_object(
            'success', true,
            'status_id', p_status_id,
            'status', 'completed',
            'amount', v_status.amount,
            'new_balance', v_current_points - v_status.amount
        ) INTO v_result;
        
        RETURN v_result;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE;
    END;
END;
$$;
```

### 5. 유저 포인트 출금 요청 (User Withdraw Request)

```sql
CREATE OR REPLACE FUNCTION request_user_point_withdraw(
    p_user_id UUID,
    p_amount INTEGER,
    p_description TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_current_points INTEGER;
    v_status_id UUID;
    v_result JSONB;
BEGIN
    -- 1. 인증 확인
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 2. 본인 확인
    IF p_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only withdraw from your own wallet';
    END IF;
    
    -- 3. 지갑 조회 및 잠금
    SELECT current_points INTO v_current_points
    FROM user_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;
    
    IF v_current_points IS NULL THEN
        RAISE EXCEPTION 'User wallet not found';
    END IF;
    
    -- 4. 잔액 확인
    IF v_current_points < p_amount THEN
        RAISE EXCEPTION 'Insufficient points (available: %, requested: %)', 
            v_current_points, p_amount;
    END IF;
    
    -- 5. 지갑에서 출금 계좌 정보 확인
    IF NOT EXISTS (
        SELECT 1 FROM user_wallets 
        WHERE user_id = p_user_id 
        AND withdraw_bank_name IS NOT NULL 
        AND withdraw_account_number IS NOT NULL
        AND withdraw_account_holder IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Withdrawal account information not set in wallet. Please set withdrawal account first.';
    END IF;
    
    -- 6. 트랜잭션 시작
    BEGIN
        -- 6-1. status 생성 (트리거가 자동으로 event 생성)
        INSERT INTO user_point_status (
            user_id,
            transaction_type,
            status,
            amount,
            description,
            requested_by,
            created_at,
            updated_at
        ) VALUES (
            p_user_id,
            'withdraw',
            'pending',
            p_amount,
            p_description,
            v_user_id,
            NOW(),
            NOW()
        ) RETURNING id INTO v_status_id;
        
        -- 6-2. 결과 반환
        SELECT jsonb_build_object(
            'success', true,
            'status_id', v_status_id,
            'status', 'pending',
            'amount', p_amount,
            'current_balance', v_current_points
        ) INTO v_result;
        
        RETURN v_result;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE;
    END;
END;
$$;
```

### 6. 유저 포인트 출금 승인 (User Withdraw Approve)

```sql
CREATE OR REPLACE FUNCTION approve_user_point_withdraw(
    p_status_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_user_type TEXT;
    v_status RECORD;
    v_current_points INTEGER;
    v_result JSONB;
BEGIN
    -- 1. 인증 확인
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 2. Admin 권한 확인
    SELECT user_type INTO v_user_type
    FROM users
    WHERE id = v_user_id;
    
    IF v_user_type NOT IN ('admin', 'ADMIN') THEN
        RAISE EXCEPTION 'Only admin can approve withdrawals';
    END IF;
    
    -- 3. status 조회 및 잠금
    SELECT * INTO v_status
    FROM user_point_status
    WHERE id = p_status_id
    FOR UPDATE;
    
    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Status not found';
    END IF;
    
    IF v_status.status != 'pending' THEN
        RAISE EXCEPTION 'Status is not in pending state: %', v_status.status;
    END IF;
    
    -- 4. 잔액 재확인
    SELECT current_points INTO v_current_points
    FROM user_wallets
    WHERE user_id = v_status.user_id
    FOR UPDATE;
    
    IF v_current_points < v_status.amount THEN
        RAISE EXCEPTION 'Insufficient points (available: %, requested: %)', 
            v_current_points, v_status.amount;
    END IF;
    
    -- 5. 트랜잭션 시작
    BEGIN
        -- 5-1. 상태를 completed로 변경 (트리거가 포인트 자동 차감 및 event 생성/업데이트)
        UPDATE user_point_status
        SET status = 'completed',
            approved_by = v_user_id,
            updated_at = NOW()
        WHERE id = p_status_id;
        
        -- 5-2. 결과 반환
        SELECT jsonb_build_object(
            'success', true,
            'status_id', p_status_id,
            'status', 'completed',
            'amount', v_status.amount,
            'new_balance', v_current_points - v_status.amount
        ) INTO v_result;
        
        RETURN v_result;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE;
    END;
END;
$$;
```

### 7. 회사 포인트 소비 (Company Point Spend) - 캠페인 생성 시

```sql
CREATE OR REPLACE FUNCTION spend_company_points(
    p_company_id UUID,
    p_amount INTEGER,
    p_campaign_id UUID, -- 필수: spend 트랜잭션은 항상 캠페인과 연결
    p_description TEXT,
    p_related_entity_type TEXT DEFAULT NULL,
    p_related_entity_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_company_role TEXT;
    v_current_points INTEGER;
    v_status_id UUID;
    v_result JSONB;
BEGIN
    -- 1. 인증 확인
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 2. 회사 지갑 조회 및 잠금
    SELECT current_points INTO v_current_points
    FROM company_wallets
    WHERE company_id = p_company_id
    FOR UPDATE;
    
    IF v_current_points IS NULL THEN
        RAISE EXCEPTION 'Company wallet not found';
    END IF;
    
    -- 3. 잔액 확인
    IF v_current_points < p_amount THEN
        RAISE EXCEPTION 'Insufficient points (available: %, requested: %)', 
            v_current_points, p_amount;
    END IF;
    
    -- 4. 권한 확인: owner 또는 manager 가능
    SELECT company_role INTO v_company_role
    FROM company_users
    WHERE company_id = p_company_id
    AND user_id = v_user_id
    AND status = 'active'
    AND company_role IN ('owner', 'manager')
    LIMIT 1;
    
    IF v_company_role IS NULL THEN
        RAISE EXCEPTION 'Only company owner or manager can spend points';
    END IF;
    
    -- 5. 캠페인 존재 확인 (FK 제약조건으로도 검증되지만 명시적으로 확인)
    IF NOT EXISTS (SELECT 1 FROM campaigns WHERE id = p_campaign_id) THEN
        RAISE EXCEPTION 'Campaign not found: %', p_campaign_id;
    END IF;
    
    -- 6. 트랜잭션 시작
    BEGIN
        -- 6-1. status 생성 (status를 바로 'completed'로 설정 - 즉시 처리, 트리거가 자동으로 event 생성 및 포인트 차감)
        INSERT INTO company_point_status (
            company_id,
            transaction_type,
            status,
            amount,
            description,
            campaign_id, -- FK 제약조건으로 검증됨
            requested_by,
            related_entity_type,
            related_entity_id,
            created_at,
            updated_at
        ) VALUES (
            p_company_id,
            'spend',
            'completed', -- 즉시 완료 (admin 승인 불필요)
            p_amount,
            p_description,
            p_campaign_id, -- FK로 캠페인과 명시적 연결
            v_user_id,
            p_related_entity_type,
            p_related_entity_id,
            NOW(),
            NOW()
        ) RETURNING id INTO v_status_id;
        
        -- 트리거가 자동으로 포인트 차감 처리 및 event 생성
        
        -- 6-2. 결과 반환
        SELECT jsonb_build_object(
            'success', true,
            'status_id', v_status_id,
            'status', 'completed',
            'amount', p_amount,
            'new_balance', v_current_points - p_amount
        ) INTO v_result;
        
        RETURN v_result;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE;
    END;
END;
$$;
```

**참고**: 
- 기존 `create_campaign_with_points_v2` 함수를 수정하여 이 함수를 호출하거나, 직접 `company_point_status`에 기록하도록 변경해야 합니다.
- `campaign_id`는 FK 제약조건으로 데이터 무결성이 보장되며, spend 트랜잭션에서만 필수입니다.
- 자세한 연구 내용은 `docs/campaign-fk-research.md`를 참고하세요.

### 8. 지갑 계좌 정보 업데이트 함수

```sql
-- 회사 지갑 계좌 정보 업데이트 (출금 계좌만)
CREATE OR REPLACE FUNCTION update_company_wallet_account(
    p_company_id UUID,
    p_bank_name TEXT,
    p_account_number TEXT,
    p_account_holder TEXT,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_company_role TEXT;
    v_old_bank_name TEXT;
    v_old_account_number TEXT;
    v_old_account_holder TEXT;
    v_result JSONB;
BEGIN
    -- 1. 인증 확인
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 2. 권한 확인: owner만 가능
    SELECT company_role INTO v_company_role
    FROM company_users
    WHERE company_id = p_company_id
    AND user_id = v_user_id
    AND status = 'active'
    AND company_role = 'owner'
    LIMIT 1;
    
    IF v_company_role IS NULL THEN
        RAISE EXCEPTION 'Only company owner can update account information';
    END IF;
    
    -- 3. 이전 계좌 정보 조회 (UPDATE 전에)
    SELECT withdraw_bank_name, withdraw_account_number, withdraw_account_holder
    INTO v_old_bank_name, v_old_account_number, v_old_account_holder
    FROM company_wallets
    WHERE company_id = p_company_id;
    
    -- 4. 트랜잭션 시작
    BEGIN
        -- 출금 계좌 업데이트
        UPDATE company_wallets
        SET withdraw_bank_name = p_bank_name,
            withdraw_account_number = p_account_number,
            withdraw_account_holder = p_account_holder,
            updated_at = NOW()
        WHERE company_id = p_company_id;
        
        -- company_wallet_account_change_logs에 기록 (선택사항)
        INSERT INTO company_wallet_account_change_logs (
            company_id,
            old_value,
            new_value,
            changed_by,
            created_at
        ) VALUES (
            p_company_id,
            jsonb_build_object(
                'withdraw_bank_name', v_old_bank_name,
                'withdraw_account_number', v_old_account_number,
                'withdraw_account_holder', v_old_account_holder
            ),
            jsonb_build_object(
                'withdraw_bank_name', p_bank_name,
                'withdraw_account_number', p_account_number,
                'withdraw_account_holder', p_account_holder
            ),
            v_user_id,
            NOW()
        );
        
        SELECT jsonb_build_object(
            'success', true,
            'company_id', p_company_id,
            'updated', true
        ) INTO v_result;
        
        RETURN v_result;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE;
    END;
END;
$$;

-- 유저 지갑 계좌 정보 업데이트
CREATE OR REPLACE FUNCTION update_user_wallet_account(
    p_user_id UUID,
    p_bank_name TEXT,
    p_account_number TEXT,
    p_account_holder TEXT,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_old_bank_name TEXT;
    v_old_account_number TEXT;
    v_old_account_holder TEXT;
    v_result JSONB;
BEGIN
    -- 1. 인증 확인
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 2. 본인 확인
    IF p_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only update your own wallet account';
    END IF;
    
    -- 3. 이전 계좌 정보 조회 (UPDATE 전에)
    SELECT withdraw_bank_name, withdraw_account_number, withdraw_account_holder
    INTO v_old_bank_name, v_old_account_number, v_old_account_holder
    FROM user_wallets
    WHERE user_id = p_user_id;
    
    -- 4. 트랜잭션 시작
    BEGIN
        -- 출금 계좌 업데이트
        UPDATE user_wallets
        SET withdraw_bank_name = p_bank_name,
            withdraw_account_number = p_account_number,
            withdraw_account_holder = p_account_holder,
            updated_at = NOW()
        WHERE user_id = p_user_id;
        
        -- user_wallet_account_change_logs에 기록 (선택사항)
        INSERT INTO user_wallet_account_change_logs (
            user_id,
            old_value,
            new_value,
            changed_by,
            created_at
        ) VALUES (
            p_user_id,
            jsonb_build_object(
                'withdraw_bank_name', v_old_bank_name,
                'withdraw_account_number', v_old_account_number,
                'withdraw_account_holder', v_old_account_holder
            ),
            jsonb_build_object(
                'withdraw_bank_name', p_bank_name,
                'withdraw_account_number', p_account_number,
                'withdraw_account_holder', p_account_holder
            ),
            v_user_id,
            NOW()
        );
        
        SELECT jsonb_build_object(
            'success', true,
            'user_id', p_user_id,
            'updated', true
        ) INTO v_result;
        
        RETURN v_result;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE;
    END;
END;
$$;
```

### 9. 거절 함수 (Reject Functions)

```sql
-- 회사 포인트 거래 거절
CREATE OR REPLACE FUNCTION reject_company_point_transaction(
    p_status_id UUID,
    p_rejection_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_user_type TEXT;
    v_result JSONB;
BEGIN
    -- 1. 인증 및 Admin 권한 확인
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    SELECT user_type INTO v_user_type
    FROM users
    WHERE id = v_user_id;
    
    IF v_user_type NOT IN ('admin', 'ADMIN') THEN
        RAISE EXCEPTION 'Only admin can reject transactions';
    END IF;
    
    -- 2. 거절 처리 (status 업데이트, 트리거가 자동으로 event 생성/업데이트)
    UPDATE company_point_status
    SET status = 'rejected',
        rejected_by = v_user_id,
        updated_at = NOW()
    WHERE id = p_status_id
    AND status = 'pending';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Status not found or not in pending state';
    END IF;
    
    SELECT jsonb_build_object(
        'success', true,
        'status_id', p_status_id,
        'status', 'rejected'
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- 유저 포인트 거래 거절
CREATE OR REPLACE FUNCTION reject_user_point_transaction(
    p_status_id UUID,
    p_rejection_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_user_type TEXT;
    v_result JSONB;
BEGIN
    -- 1. 인증 및 Admin 권한 확인
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    SELECT user_type INTO v_user_type
    FROM users
    WHERE id = v_user_id;
    
    IF v_user_type NOT IN ('admin', 'ADMIN') THEN
        RAISE EXCEPTION 'Only admin can reject transactions';
    END IF;
    
    -- 2. 거절 처리 (status 업데이트, 트리거가 자동으로 event 생성/업데이트)
    UPDATE user_point_status
    SET status = 'rejected',
        rejected_by = v_user_id,
        rejection_reason = p_rejection_reason,
        updated_at = NOW()
    WHERE id = p_status_id
    AND status = 'pending';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Status not found or not in pending state';
    END IF;
    
    SELECT jsonb_build_object(
        'success', true,
        'status_id', p_status_id,
        'status', 'rejected'
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;
```

---

## 🗑️ 기존 테이블 삭제 및 마이그레이션

### 1. 기존 로그 테이블 삭제

```sql
-- 기존 포인트 로그 테이블 삭제 (데이터 백업 후)
DROP TABLE IF EXISTS company_point_logs CASCADE;
DROP TABLE IF EXISTS user_point_logs CASCADE;
```

### 2. 기존 함수 정리

```sql
-- 기존 포인트 관련 함수들 확인 및 필요시 삭제
-- (기존 함수들이 company_point_logs, user_point_logs를 사용한다면 수정 필요)
```

---

## 🔒 보안 고려사항

### 1. RLS (Row Level Security) 정책

```sql
-- company_point_status RLS (status가 먼저 생성되므로 status에 RLS 적용)
ALTER TABLE company_point_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Company members can view their company status"
ON company_point_status FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM company_users
        WHERE company_id = company_point_status.company_id
        AND user_id = auth.uid()
        AND status = 'active'
    )
);

-- 입금/출금은 owner만 가능
CREATE POLICY "Company owners can create deposit/withdraw status"
ON company_point_status FOR INSERT
WITH CHECK (
    (transaction_type IN ('deposit', 'withdraw') AND
    EXISTS (
        SELECT 1 FROM company_users
        WHERE company_id = company_point_status.company_id
        AND user_id = auth.uid()
        AND status = 'active'
        AND company_role = 'owner'
    ))
    OR
    -- 소비(spend)는 owner 또는 manager 가능
    (transaction_type = 'spend' AND
    EXISTS (
        SELECT 1 FROM company_users
        WHERE company_id = company_point_status.company_id
        AND user_id = auth.uid()
        AND status = 'active'
        AND company_role IN ('owner', 'manager')
    ))
);

-- company_point_events RLS (트리거로 자동 생성되지만 조회용)
ALTER TABLE company_point_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Company members can view their company events"
ON company_point_events FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM company_users
        WHERE company_id = company_point_events.company_id
        AND user_id = auth.uid()
        AND status = 'active'
    )
);

-- user_point_status RLS
ALTER TABLE user_point_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own status"
ON user_point_status FOR SELECT
USING (user_id = auth.uid());

CREATE POLICY "Users can create their own status"
ON user_point_status FOR INSERT
WITH CHECK (user_id = auth.uid());

-- user_point_events RLS (트리거로 자동 생성되지만 조회용)
ALTER TABLE user_point_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own events"
ON user_point_events FOR SELECT
USING (user_id = auth.uid());
```

---

## 🚀 구현 단계

### Phase 1: 데이터베이스 구조 생성 (1일)
1. ✅ 지갑 테이블 확장 (계좌 정보 필드 추가)
2. ✅ `company_wallet_account_change_logs` 테이블 생성 (선택사항)
3. ✅ `user_wallet_account_change_logs` 테이블 생성 (선택사항)
4. ✅ `company_point_events` 테이블 생성
5. ✅ `company_point_status` 테이블 생성
6. ✅ `user_point_events` 테이블 생성
7. ✅ `user_point_status` 테이블 생성
8. ✅ 인덱스 및 제약조건 설정

### Phase 2: 트리거 함수 구현 (1일)
1. ✅ `sync_company_point_event_on_status` 함수 구현
2. ✅ `sync_user_point_event_on_status` 함수 구현
3. ✅ 트리거 생성

### Phase 3: RPC 함수 구현 (2일)
1. ✅ 지갑 계좌 정보 업데이트 함수
2. ✅ 회사 입금 요청/승인 함수
3. ✅ 회사 출금 요청/승인 함수
4. ✅ 회사 포인트 소비 함수 (캠페인 생성 시)
5. ✅ 유저 출금 요청/승인 함수
6. ✅ 거절 함수

### Phase 4: 기존 테이블 정리 (1일)
1. ✅ 기존 로그 테이블 데이터 백업
2. ✅ 기존 로그 테이블 삭제
3. ✅ 기존 함수 수정/삭제

### Phase 5: RLS 정책 설정 (0.5일)
1. ✅ RLS 정책 생성
2. ✅ 권한 테스트

### Phase 6: 테스트 및 검증 (1-2일)
1. ✅ 단위 테스트 작성
2. ✅ 통합 테스트 작성
3. ✅ 동시성 테스트
4. ✅ 에러 케이스 테스트

### Phase 7: Flutter 클라이언트 연동 (2-3일)
1. ✅ 모델 클래스 생성
2. ✅ 서비스 클래스 구현
3. ✅ UI 화면 구현
4. ✅ 에러 처리 및 사용자 피드백

---

## 📝 마이그레이션 파일 구조

```
supabase/migrations/
  YYYYMMDDHHMMSS_extend_wallet_tables.sql (지갑 테이블 확장)
  YYYYMMDDHHMMSS_create_company_wallet_account_change_logs.sql (선택사항)
  YYYYMMDDHHMMSS_create_user_wallet_account_change_logs.sql (선택사항)
  YYYYMMDDHHMMSS_create_company_point_events.sql
  YYYYMMDDHHMMSS_create_company_point_status.sql
  YYYYMMDDHHMMSS_create_user_point_events.sql
  YYYYMMDDHHMMSS_create_user_point_status.sql
  YYYYMMDDHHMMSS_create_company_point_status_triggers.sql
  YYYYMMDDHHMMSS_create_user_point_status_triggers.sql
  YYYYMMDDHHMMSS_create_wallet_account_functions.sql
  YYYYMMDDHHMMSS_create_point_transaction_functions.sql
  YYYYMMDDHHMMSS_drop_old_point_logs.sql
  YYYYMMDDHHMMSS_create_rls_policies.sql
```

---

## ✅ 체크리스트

- [ ] 지갑 테이블 확장 (계좌 정보 필드 추가)
- [ ] company_wallet_account_change_logs 테이블 생성 (선택사항)
- [ ] user_wallet_account_change_logs 테이블 생성 (선택사항)
- [ ] 데이터베이스 테이블 생성 (company_point_events, company_point_status, user_point_events, user_point_status)
- [ ] 트리거 함수 구현 (포인트 자동 변동)
- [ ] 지갑 계좌 정보 업데이트 함수 구현
- [ ] RPC 함수 구현 (요청/승인/거절)
- [ ] 기존 테이블 삭제 (company_point_logs, user_point_logs)
- [ ] RLS 정책 설정
- [ ] 인덱스 최적화
- [ ] 단위 테스트 작성
- [ ] 통합 테스트 작성
- [ ] Flutter 모델 클래스 생성
- [ ] Flutter 서비스 클래스 구현
- [ ] UI 화면 구현
- [ ] 에러 처리 구현
- [ ] 문서화 완료

---

## 🎯 핵심 설계 포인트

1. **이벤트 기반 아키텍처**: 캠페인 시스템과 일관된 패턴
2. **Status-First 설계**: 
   - `point_status` 테이블이 먼저 생성/수정됨
   - `point_events`는 `status_id`를 FK로 참조하며 트리거에 의해 자동 생성
   - Status가 생성/수정될 때마다 Event가 자동으로 생성/업데이트됨
3. **트리거 기반 포인트 변동**: status가 'completed'일 때 자동으로 포인트 변동
4. **트랜잭션 원자성**: 모든 함수가 단일 트랜잭션으로 실행
5. **Admin 승인 프로세스**: 신청 → pending → admin 승인 → completed
6. **계좌 정보 관리**: 
   - 계좌 정보는 지갑(wallets) 테이블에 저장 (중복 입력 방지)
   - 입출금 시마다 계좌 정보를 입력할 필요 없음
   - 계좌 변경 이력은 company_wallet_account_change_logs와 user_wallet_account_change_logs 테이블로 관리 (선택사항)
7. **권한 분리**: 
   - 회사 입금/출금: owner만
   - 회사 포인트 소비(spend): owner 또는 manager
   - 유저 출금: 본인만
8. **Optional Foreign Key 패턴**: 
   - `campaign_id`는 spend 트랜잭션에서만 필수
   - 입금/출금에서는 `campaign_id IS NULL` (정상, FK 제약조건은 NULL 허용)
   - CHECK 제약조건으로 `transaction_type`에 따라 NULL/NOT NULL 강제
   - 부분 인덱스로 NULL 값은 인덱스에서 제외하여 성능 최적화

이 로드맵을 따라 구현하면 안정적이고 확장 가능한 포인트 입출금 시스템을 구축할 수 있습니다.

---

## 📚 추가 연구 문서

### 통합 테이블 방안 연구
`company_point_events`와 `user_point_events`를 하나의 테이블로 통합하는 방안에 대한 상세 연구가 `docs/unified-point-events-research.md`에 있습니다.

**요약**: 
- **통합 구조**: `point_events`와 `point_status` 단일 테이블로 통합 가능
- **제약조건**: `company_id` 또는 `user_id` 중 하나는 반드시 있어야 함 (CHECK 제약조건)
- **권장안**: **분리된 구조 유지** (명확성, 성능, 보안 측면에서 유리)
- **절충안**: 공통 함수를 활용하여 코드 중복 감소

자세한 내용은 연구 문서를 참고하세요.
