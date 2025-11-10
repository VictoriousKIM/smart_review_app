# 포인트 이벤트 테이블 통합 방안 연구

## 📋 현재 구조

### 분리된 구조 (현재)
- `company_point_events`: 회사 포인트 이벤트
- `user_point_events`: 유저 포인트 이벤트
- `company_point_status`: 회사 포인트 상태
- `user_point_status`: 유저 포인트 상태

### 문제점
- 테이블이 4개로 분리되어 관리 복잡
- 유사한 구조의 중복 코드
- 통합 쿼리 시 UNION 필요

---

## 🔍 통합 방안: 단일 테이블 구조

### 방안: `point_events`와 `point_status` 통합 테이블

#### 구조 설계

```sql
-- 통합 포인트 이벤트 테이블
CREATE TABLE point_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 상태 참조 (FK)
    status_id UUID NOT NULL UNIQUE REFERENCES point_status(id) ON DELETE CASCADE,
    
    -- 지갑 참조 (FK) - 한쪽만 필수
    company_id UUID REFERENCES company_wallets(company_id) ON DELETE CASCADE,
    user_id UUID REFERENCES user_wallets(user_id) ON DELETE CASCADE,
    
    -- 거래 정보
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('deposit', 'withdraw', 'spend')),
    amount INTEGER NOT NULL CHECK (amount > 0),
    
    -- 이벤트 메타데이터
    description TEXT,
    related_entity_type TEXT,
    related_entity_id UUID,
    
    -- 캠페인 참조 (FK) - spend 트랜잭션 전용
    campaign_id UUID REFERENCES campaigns(id) ON DELETE SET NULL,
    
    -- 사용자 정보
    requested_by UUID REFERENCES users(id),
    approved_by UUID REFERENCES users(id),
    rejected_by UUID REFERENCES users(id),
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- 제약조건: company_id 또는 user_id 중 하나는 반드시 있어야 함
ALTER TABLE point_events
ADD CONSTRAINT check_wallet_reference
CHECK (
    (company_id IS NOT NULL AND user_id IS NULL) OR
    (company_id IS NULL AND user_id IS NOT NULL)
);

-- 통합 포인트 상태 테이블
CREATE TABLE point_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 지갑 정보 - 한쪽만 필수
    company_id UUID REFERENCES company_wallets(company_id) ON DELETE CASCADE,
    user_id UUID REFERENCES user_wallets(user_id) ON DELETE CASCADE,
    
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('deposit', 'withdraw', 'spend')),
    
    -- 상태 정보
    status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected', 'completed', 'cancelled')),
    
    -- 거래 정보
    amount INTEGER NOT NULL CHECK (amount > 0),
    description TEXT,
    related_entity_type TEXT,
    related_entity_id UUID,
    
    -- 캠페인 참조 (FK) - spend 트랜잭션 전용
    campaign_id UUID REFERENCES campaigns(id) ON DELETE SET NULL,
    
    -- 사용자 정보
    requested_by UUID REFERENCES users(id),
    approved_by UUID REFERENCES users(id),
    rejected_by UUID REFERENCES users(id),
    rejection_reason TEXT,
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 제약조건들
ALTER TABLE point_status
ADD CONSTRAINT check_wallet_reference
CHECK (
    (company_id IS NOT NULL AND user_id IS NULL) OR
    (company_id IS NULL AND user_id IS NOT NULL)
);

ALTER TABLE point_status
ADD CONSTRAINT check_spend_has_campaign 
CHECK (
  (transaction_type = 'spend' AND campaign_id IS NOT NULL) OR
  (transaction_type != 'spend' AND campaign_id IS NULL)
);

-- 인덱스
CREATE INDEX idx_point_events_status_id ON point_events(status_id);
CREATE INDEX idx_point_events_company_id ON point_events(company_id) WHERE company_id IS NOT NULL;
CREATE INDEX idx_point_events_user_id ON point_events(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_point_events_type ON point_events(transaction_type);
CREATE INDEX idx_point_events_created_at ON point_events(created_at DESC);
CREATE INDEX idx_point_events_campaign_id ON point_events(campaign_id) WHERE campaign_id IS NOT NULL;

CREATE INDEX idx_point_status_company_id ON point_status(company_id) WHERE company_id IS NOT NULL;
CREATE INDEX idx_point_status_user_id ON point_status(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_point_status_status ON point_status(status);
CREATE INDEX idx_point_status_type ON point_status(transaction_type);
CREATE INDEX idx_point_status_created_at ON point_status(created_at DESC);
CREATE INDEX idx_point_status_campaign_id ON point_status(campaign_id) WHERE campaign_id IS NOT NULL;
```

---

## 📊 장단점 비교

### ✅ 장점

1. **단일 테이블 관리**
   - 테이블 수 감소 (4개 → 2개)
   - 스키마 단순화
   - 마이그레이션 관리 용이

2. **통합 쿼리 용이**
   ```sql
   -- 모든 포인트 이벤트 조회 (UNION 불필요)
   SELECT * FROM point_events 
   WHERE (company_id = $1 OR user_id = $1)
   ORDER BY created_at DESC;
   ```

3. **코드 중복 감소**
   - RPC 함수 통합 가능
   - 트리거 함수 통합 가능
   - 공통 로직 재사용

4. **일관된 데이터 구조**
   - 동일한 필드 구조
   - 동일한 인덱스 전략
   - 동일한 RLS 정책 패턴

### ❌ 단점

1. **스키마 복잡도 증가**
   - 두 개의 FK 필드 (company_id, user_id)
   - CHECK 제약조건 복잡도 증가
   - 항상 NULL 체크 필요

2. **쿼리 성능 고려사항**
   ```sql
   -- 항상 NULL 체크 필요
   WHERE company_id = $1 OR user_id = $1
   -- 인덱스 활용이 제한적일 수 있음
   ```

3. **RLS 정책 복잡도**
   ```sql
   -- RLS 정책이 복잡해짐
   CREATE POLICY "Users can view their own events"
   ON point_events FOR SELECT
   USING (
       (company_id IS NOT NULL AND EXISTS (
           SELECT 1 FROM company_users
           WHERE company_id = point_events.company_id
           AND user_id = auth.uid()
       )) OR
       (user_id IS NOT NULL AND user_id = auth.uid())
   );
   ```

4. **트랜잭션 타입 제약**
   - 회사는 deposit/withdraw/spend 모두 가능
   - 유저는 withdraw/spend만 가능
   - CHECK 제약조건이 더 복잡해짐

5. **확장성 제한**
   - 나중에 다른 엔티티 타입 추가 시 복잡도 증가
   - 각 엔티티별로 FK 필드 추가 필요

---

## 🔍 상세 분석

### 1. CHECK 제약조건 복잡도

#### 분리된 구조 (현재)
```sql
-- company_point_status
CHECK (transaction_type IN ('deposit', 'withdraw', 'spend'))

-- user_point_status  
CHECK (transaction_type IN ('withdraw', 'spend'))
```

#### 통합 구조
```sql
-- point_status
CHECK (
    -- 지갑 참조 제약
    (company_id IS NOT NULL AND user_id IS NULL) OR
    (company_id IS NULL AND user_id IS NOT NULL)
)
AND
-- 트랜잭션 타입 제약
(
    (company_id IS NOT NULL AND transaction_type IN ('deposit', 'withdraw', 'spend')) OR
    (user_id IS NOT NULL AND transaction_type IN ('withdraw', 'spend'))
)
AND
-- 캠페인 제약
(
    (transaction_type = 'spend' AND campaign_id IS NOT NULL) OR
    (transaction_type != 'spend' AND campaign_id IS NULL)
)
```

**복잡도**: 통합 구조가 훨씬 복잡함

---

### 2. 쿼리 성능 비교

#### 분리된 구조
```sql
-- 회사 이벤트 조회
SELECT * FROM company_point_events 
WHERE company_id = $1;  -- 인덱스 직접 활용

-- 유저 이벤트 조회
SELECT * FROM user_point_events 
WHERE user_id = $1;  -- 인덱스 직접 활용

-- 통합 조회 (필요시)
SELECT * FROM company_point_events WHERE company_id = $1
UNION ALL
SELECT * FROM user_point_events WHERE user_id = $1;
```

#### 통합 구조
```sql
-- 회사 이벤트 조회
SELECT * FROM point_events 
WHERE company_id = $1;  -- 부분 인덱스 활용

-- 유저 이벤트 조회
SELECT * FROM point_events 
WHERE user_id = $1;  -- 부분 인덱스 활용

-- 통합 조회
SELECT * FROM point_events 
WHERE company_id = $1 OR user_id = $1;  -- 인덱스 활용 제한적
```

**성능**: 분리된 구조가 더 효율적 (특히 통합 조회 시)

---

### 3. RLS 정책 복잡도

#### 분리된 구조
```sql
-- company_point_events RLS
CREATE POLICY "Company members can view events"
ON company_point_events FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM company_users
        WHERE company_id = company_point_events.company_id
        AND user_id = auth.uid()
    )
);

-- user_point_events RLS
CREATE POLICY "Users can view their own events"
ON user_point_events FOR SELECT
USING (user_id = auth.uid());
```

#### 통합 구조
```sql
-- point_events RLS
CREATE POLICY "Users can view their events"
ON point_events FOR SELECT
USING (
    (company_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM company_users
        WHERE company_id = point_events.company_id
        AND user_id = auth.uid()
        AND status = 'active'
    )) OR
    (user_id IS NOT NULL AND user_id = auth.uid())
);
```

**복잡도**: 통합 구조가 더 복잡함

---

### 4. 트리거 함수 복잡도

#### 분리된 구조
```sql
-- 회사 트리거
CREATE TRIGGER sync_company_point_event_trigger
AFTER INSERT OR UPDATE ON company_point_status
FOR EACH ROW
EXECUTE FUNCTION sync_company_point_event_on_status();

-- 유저 트리거
CREATE TRIGGER sync_user_point_event_trigger
AFTER INSERT OR UPDATE ON user_point_status
FOR EACH ROW
EXECUTE FUNCTION sync_user_point_event_on_status();
```

#### 통합 구조
```sql
-- 통합 트리거
CREATE TRIGGER sync_point_event_trigger
AFTER INSERT OR UPDATE ON point_status
FOR EACH ROW
EXECUTE FUNCTION sync_point_event_on_status();

-- 함수 내부에서 분기 처리 필요
CREATE OR REPLACE FUNCTION sync_point_event_on_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.company_id IS NOT NULL THEN
        -- 회사 지갑 업데이트 로직
    ELSIF NEW.user_id IS NOT NULL THEN
        -- 유저 지갑 업데이트 로직
    END IF;
    -- ...
END;
$$;
```

**복잡도**: 통합 구조가 더 복잡함 (분기 로직 필요)

---

## 📊 비교표

| 항목 | 분리된 구조 | 통합 구조 |
|------|------------|----------|
| **테이블 수** | 4개 | 2개 |
| **스키마 복잡도** | ⭐⭐⭐⭐ | ⭐⭐ |
| **CHECK 제약조건** | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **쿼리 성능** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **인덱스 효율** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **RLS 정책** | ⭐⭐⭐⭐ | ⭐⭐ |
| **트리거 함수** | ⭐⭐⭐⭐ | ⭐⭐ |
| **코드 중복** | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **유지보수성** | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **확장성** | ⭐⭐⭐⭐ | ⭐⭐⭐ |

---

## 🎯 최종 권장안

### 분리된 구조 유지 (현재 구조) ⭐ 추천

#### 이유

1. **명확성과 단순성**
   - 각 테이블의 목적이 명확함
   - CHECK 제약조건이 단순함
   - 쿼리가 직관적임

2. **성능 최적화**
   - 인덱스 활용이 효율적
   - NULL 체크 불필요
   - 부분 인덱스로 최적화 가능

3. **보안 (RLS)**
   - RLS 정책이 단순하고 명확
   - 각 테이블별로 독립적인 정책 적용 가능

4. **확장성**
   - 각 엔티티 타입별로 독립적 확장 가능
   - 나중에 다른 엔티티 추가 시 영향 최소화

5. **PostgreSQL 모범 사례**
   - 엔티티 타입별로 테이블 분리는 일반적인 패턴
   - 예: `orders`, `order_items` 분리
   - 예: `posts`, `comments` 분리

#### 통합 구조가 적합한 경우

통합 구조는 다음 경우에만 고려:
- ✅ 엔티티 타입이 매우 유사하고 거의 동일한 로직
- ✅ 통합 쿼리가 매우 빈번함
- ✅ 테이블 수를 최소화해야 하는 제약
- ✅ 코드 중복이 심각한 문제

하지만 현재 경우:
- ❌ 회사와 유저의 트랜잭션 타입이 다름 (deposit 차이)
- ❌ 권한 구조가 다름 (owner/manager vs 본인)
- ❌ RLS 정책이 다름
- ❌ 통합 쿼리 빈도가 낮음

---

## 💡 절충안: 공통 함수 활용

분리된 구조를 유지하되, 공통 로직은 함수로 추출:

```sql
-- 공통 포인트 변동 함수
CREATE OR REPLACE FUNCTION update_wallet_points(
    p_wallet_type TEXT, -- 'company' or 'user'
    p_wallet_id UUID,
    p_transaction_type TEXT,
    p_amount INTEGER
)
RETURNS VOID AS $$
BEGIN
    IF p_wallet_type = 'company' THEN
        IF p_transaction_type = 'deposit' THEN
            UPDATE company_wallets
            SET current_points = current_points + p_amount
            WHERE company_id = p_wallet_id;
        ELSIF p_transaction_type IN ('withdraw', 'spend') THEN
            UPDATE company_wallets
            SET current_points = current_points - p_amount
            WHERE company_id = p_wallet_id;
        END IF;
    ELSIF p_wallet_type = 'user' THEN
        IF p_transaction_type IN ('withdraw', 'spend') THEN
            UPDATE user_wallets
            SET current_points = current_points - p_amount
            WHERE user_id = p_wallet_id;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;
```

이렇게 하면:
- ✅ 테이블은 분리 (명확성, 성능)
- ✅ 공통 로직은 재사용 (코드 중복 감소)
- ✅ 최적의 절충안

---

## ✅ 결론

**분리된 구조를 유지하는 것을 권장합니다.**

이유:
1. 명확성과 단순성
2. 성능 최적화
3. 보안 정책 단순화
4. 확장성
5. PostgreSQL 모범 사례 준수

통합 구조는 코드 중복 감소라는 장점이 있지만, 복잡도 증가와 성능 저하라는 단점이 더 큽니다.

**대안**: 공통 함수를 활용하여 코드 중복을 줄이면서도 테이블은 분리된 상태를 유지하는 것이 최선입니다.

---

## 🔧 통합 구조 구현 예시 (참고용)

만약 통합 구조를 선택한다면, 다음과 같이 구현할 수 있습니다:

### 통합 트리거 함수

```sql
CREATE OR REPLACE FUNCTION sync_point_event_on_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_event_id UUID;
BEGIN
    -- 1. point_events 테이블에 새 이벤트 생성
    INSERT INTO point_events (
        status_id,
        company_id,
        user_id,
        transaction_type,
        amount,
        description,
        campaign_id,
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
        NEW.company_id,
        NEW.user_id,
        NEW.transaction_type,
        NEW.amount,
        NEW.description,
        NEW.campaign_id,
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
        campaign_id = EXCLUDED.campaign_id,
        related_entity_type = EXCLUDED.related_entity_type,
        related_entity_id = EXCLUDED.related_entity_id,
        approved_by = EXCLUDED.approved_by,
        rejected_by = EXCLUDED.rejected_by,
        rejection_reason = EXCLUDED.rejection_reason,
        updated_at = EXCLUDED.updated_at,
        completed_at = CASE WHEN NEW.status = 'completed' THEN NOW() ELSE point_events.completed_at END
    RETURNING id INTO v_event_id;
    
    -- 2. status가 'completed'인 경우 포인트 변동 (분기 처리)
    IF NEW.status = 'completed' THEN
        IF NEW.company_id IS NOT NULL THEN
            -- 회사 지갑 업데이트
            IF NEW.transaction_type = 'deposit' THEN
                UPDATE company_wallets
                SET current_points = current_points + NEW.amount,
                    updated_at = NOW()
                WHERE company_id = NEW.company_id;
                
            ELSIF NEW.transaction_type IN ('withdraw', 'spend') THEN
                UPDATE company_wallets
                SET current_points = current_points - NEW.amount,
                    updated_at = NOW()
                WHERE company_id = NEW.company_id
                AND current_points >= NEW.amount;
                
                IF NOT FOUND THEN
                    RAISE EXCEPTION 'Insufficient points';
                END IF;
            END IF;
            
        ELSIF NEW.user_id IS NOT NULL THEN
            -- 유저 지갑 업데이트
            IF NEW.transaction_type IN ('withdraw', 'spend') THEN
                UPDATE user_wallets
                SET current_points = current_points - NEW.amount,
                    updated_at = NOW()
                WHERE user_id = NEW.user_id
                AND current_points >= NEW.amount;
                
                IF NOT FOUND THEN
                    RAISE EXCEPTION 'Insufficient points';
                END IF;
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;
```

### 통합 RPC 함수 예시

```sql
-- 통합 포인트 입금 요청 함수
CREATE OR REPLACE FUNCTION request_point_deposit(
    p_wallet_type TEXT, -- 'company' or 'user'
    p_wallet_id UUID,
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
    v_status_id UUID;
    v_result JSONB;
BEGIN
    -- 1. 인증 확인
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 2. 지갑 타입별 검증
    IF p_wallet_type = 'company' THEN
        -- 회사 지갑 확인 및 권한 검증
        IF NOT EXISTS (
            SELECT 1 FROM company_users
            WHERE company_id = p_wallet_id
            AND user_id = v_user_id
            AND status = 'active'
            AND company_role = 'owner'
        ) THEN
            RAISE EXCEPTION 'Only company owner can request deposit';
        END IF;
        
        -- status 생성
        INSERT INTO point_status (
            company_id,
            user_id,
            transaction_type,
            status,
            amount,
            description,
            requested_by,
            created_at,
            updated_at
        ) VALUES (
            p_wallet_id,
            NULL,
            'deposit',
            'pending',
            p_amount,
            p_description,
            v_user_id,
            NOW(),
            NOW()
        ) RETURNING id INTO v_status_id;
        
    ELSIF p_wallet_type = 'user' THEN
        -- 유저는 입금 불가
        RAISE EXCEPTION 'Users cannot deposit points';
    ELSE
        RAISE EXCEPTION 'Invalid wallet type: %', p_wallet_type;
    END IF;
    
    SELECT jsonb_build_object(
        'success', true,
        'status_id', v_status_id,
        'status', 'pending',
        'amount', p_amount
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;
```

### 통합 구조의 복잡도 예시

```sql
-- 통합 조회 쿼리 (복잡함)
SELECT 
    pe.*,
    CASE 
        WHEN pe.company_id IS NOT NULL THEN 'company'
        WHEN pe.user_id IS NOT NULL THEN 'user'
    END AS wallet_type,
    CASE 
        WHEN pe.company_id IS NOT NULL THEN cw.current_points
        WHEN pe.user_id IS NOT NULL THEN uw.current_points
    END AS current_balance
FROM point_events pe
LEFT JOIN company_wallets cw ON pe.company_id = cw.company_id
LEFT JOIN user_wallets uw ON pe.user_id = uw.user_id
WHERE (pe.company_id = $1 OR pe.user_id = $1)
ORDER BY pe.created_at DESC;
```

**vs 분리된 구조 (단순함)**

```sql
-- 회사 이벤트 조회
SELECT pe.*, cw.current_points AS current_balance
FROM company_point_events pe
JOIN company_wallets cw ON pe.company_id = cw.company_id
WHERE pe.company_id = $1
ORDER BY pe.created_at DESC;

-- 유저 이벤트 조회
SELECT pe.*, uw.current_points AS current_balance
FROM user_point_events pe
JOIN user_wallets uw ON pe.user_id = uw.user_id
WHERE pe.user_id = $1
ORDER BY pe.created_at DESC;
```

---

## 📝 최종 권장사항

### 분리된 구조 유지 ⭐⭐⭐⭐⭐

**이유:**
1. ✅ 명확성: 각 테이블의 목적이 명확
2. ✅ 성능: 인덱스 활용 최적화
3. ✅ 단순성: CHECK 제약조건과 RLS 정책이 단순
4. ✅ 확장성: 각 엔티티별 독립적 확장 가능
5. ✅ PostgreSQL 모범 사례 준수

### 코드 중복 해결 방법

공통 함수를 활용하여 코드 중복을 줄이되, 테이블은 분리 유지:

```sql
-- 공통 포인트 변동 함수
CREATE OR REPLACE FUNCTION update_wallet_points(
    p_wallet_type TEXT,
    p_wallet_id UUID,
    p_transaction_type TEXT,
    p_amount INTEGER
)
RETURNS VOID AS $$
BEGIN
    IF p_wallet_type = 'company' THEN
        IF p_transaction_type = 'deposit' THEN
            UPDATE company_wallets
            SET current_points = current_points + p_amount
            WHERE company_id = p_wallet_id;
        ELSIF p_transaction_type IN ('withdraw', 'spend') THEN
            UPDATE company_wallets
            SET current_points = current_points - p_amount
            WHERE company_id = p_wallet_id;
        END IF;
    ELSIF p_wallet_type = 'user' THEN
        IF p_transaction_type IN ('withdraw', 'spend') THEN
            UPDATE user_wallets
            SET current_points = current_points - p_amount
            WHERE user_id = p_wallet_id;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;
```

이렇게 하면:
- ✅ 테이블은 분리 (명확성, 성능)
- ✅ 공통 로직은 재사용 (코드 중복 감소)
- ✅ 최적의 절충안 달성

