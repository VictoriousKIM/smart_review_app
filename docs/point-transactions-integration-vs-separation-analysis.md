# 포인트 거래 테이블 통합 vs 분리 분석
## 캠페인 거래 vs 현금 입출금

## 📊 두 가지 접근 방식 비교

### 옵션 A: 통합 테이블 (현재 설계)
**`point_transactions`** 하나의 테이블에 모든 포인트 거래 포함

### 옵션 B: 분리 테이블
- **`point_transactions`**: 캠페인 관련 포인트 거래 (사용/획득)
- **`point_cash_transactions`**: 현금 입출금 거래

---

## 🔍 상세 비교 분석

### 1. 비즈니스 로직 차이점

#### 캠페인 거래
- **처리 방식**: 즉시 처리 (자동 완료)
- **승인 프로세스**: 불필요 (시스템 자동 처리)
- **상태**: 대부분 `completed`
- **트리거**: 캠페인 생성/리뷰 완료 시 자동 발생
- **관련 엔티티**: `campaign_id` 필수/선택

#### 현금 입출금
- **처리 방식**: 승인 필요 (수동 처리)
- **승인 프로세스**: Admin 승인 필수 (`pending` → `approved` → `completed`)
- **상태**: `pending`, `approved`, `rejected`, `completed`
- **트리거**: 사용자 요청 → Admin 승인 → 처리
- **관련 엔티티**: `campaign_id` 없음 (캠페인과 무관)

**결론**: 비즈니스 로직이 **근본적으로 다름** → 분리 고려 필요

---

### 2. 데이터 구조 차이점

#### 캠페인 거래에 필요한 필드
```sql
- campaign_id (필수/선택)
- related_entity_type ('review', 'campaign')
- related_entity_id (review_id 등)
- 즉시 완료되므로 approval 관련 필드 불필요
```

#### 현금 입출금에 필요한 필드
```sql
- bank_name, account_number, account_holder (출금 계좌 정보)
- approval_required (항상 true)
- approved_by, rejected_by, rejection_reason
- payment_method (입금 방식)
- cash_amount (현금 금액, 포인트와 환율 적용)
- campaign_id 불필요
```

**결론**: 필요한 필드가 **상당히 다름** → 분리 시 각각 최적화 가능

---

### 3. 쿼리 패턴 차이점

#### 캠페인 거래 쿼리 패턴
```sql
-- 캠페인별 포인트 사용 내역
SELECT * FROM point_transactions 
WHERE campaign_id = ? AND transaction_type = 'spend';

-- 사용자별 캠페인 포인트 획득 내역
SELECT * FROM point_transactions 
WHERE user_id = ? AND transaction_type = 'earn' AND campaign_id IS NOT NULL;

-- 캠페인 통계
SELECT campaign_id, SUM(amount) 
FROM point_transactions 
WHERE campaign_id IS NOT NULL 
GROUP BY campaign_id;
```

#### 현금 입출금 쿼리 패턴
```sql
-- 승인 대기 중인 출금 요청
SELECT * FROM point_transactions 
WHERE status = 'pending' AND transaction_type IN ('deposit', 'withdraw');

-- 사용자별 출금 내역
SELECT * FROM point_transactions 
WHERE user_id = ? AND transaction_type = 'withdraw';

-- 월별 입출금 통계
SELECT DATE_TRUNC('month', created_at), SUM(amount)
FROM point_transactions 
WHERE transaction_type IN ('deposit', 'withdraw')
GROUP BY DATE_TRUNC('month', created_at);
```

**결론**: 쿼리 패턴이 **거의 겹치지 않음** → 분리 시 인덱스 최적화 용이

---

### 4. 성능 고려사항

#### 통합 테이블
- ✅ 단일 테이블 조회 (JOIN 불필요)
- ❌ WHERE 조건이 복잡해짐 (`campaign_id IS NOT NULL`, `status = 'pending'` 등)
- ❌ 인덱스가 비효율적 (모든 거래 타입에 대한 인덱스 필요)
- ❌ 테이블 크기가 커질수록 성능 저하

#### 분리 테이블
- ✅ 각 테이블이 작아서 인덱스 효율적
- ✅ 필요한 필드만 포함하여 저장 공간 절약
- ✅ 쿼리 최적화 용이
- ❌ 통합 조회 시 UNION 필요 (하지만 빈도 낮음)

**결론**: 분리 테이블이 **성능상 유리**

---

### 5. 확장성 고려사항

#### 통합 테이블
- ❌ 새로운 거래 타입 추가 시 모든 거래에 영향
- ❌ 필드가 계속 늘어날 수 있음 (NULL 값 증가)
- ❌ 제약조건이 복잡해짐

#### 분리 테이블
- ✅ 각 테이블이 독립적으로 확장 가능
- ✅ 새로운 거래 타입 추가 시 해당 테이블만 수정
- ✅ 제약조건이 명확함

**결론**: 분리 테이블이 **확장성 면에서 유리**

---

### 6. 코드 유지보수성

#### 통합 테이블
- ✅ 단일 모델 클래스
- ✅ 단일 서비스 함수
- ❌ 조건문이 많아짐 (`if transaction_type == 'spend' && campaign_id`)
- ❌ 비즈니스 로직이 섞임

#### 분리 테이블
- ✅ 각각의 명확한 책임
- ✅ 비즈니스 로직 분리
- ❌ 모델 클래스 2개 필요
- ❌ 서비스 함수 중복 가능성 (하지만 공통 함수로 해결 가능)

**결론**: 분리 테이블이 **유지보수성 면에서 유리**

---

## 🎯 권장안: 분리 테이블 (옵션 B)

### 이유
1. **비즈니스 로직이 근본적으로 다름**
   - 캠페인: 자동 처리, 즉시 완료
   - 현금: 승인 필요, 수동 처리

2. **필요한 필드가 다름**
   - 캠페인: `campaign_id`, `related_entity_type`
   - 현금: `bank_name`, `account_number`, `approval` 관련 필드

3. **쿼리 패턴이 다름**
   - 캠페인: `campaign_id` 기반 조회
   - 현금: `status`, `transaction_type` 기반 조회

4. **성능 최적화**
   - 각 테이블이 작아서 인덱스 효율적

5. **확장성**
   - 각 테이블이 독립적으로 진화 가능

---

## 📐 분리 테이블 설계안

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
        transaction_type IN ('earn', 'spend')  -- 캠페인 관련만
    ),
    amount INTEGER NOT NULL CHECK (amount != 0),
    
    -- 캠페인 정보
    campaign_id UUID REFERENCES campaigns(id) ON DELETE SET NULL,
    
    -- 관련 엔티티
    related_entity_type TEXT, -- 'review', 'campaign'
    related_entity_id UUID,
    
    -- 메타데이터
    description TEXT,
    created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 타임스탬프
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
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
CREATE INDEX idx_point_transactions_campaign_id ON point_transactions(campaign_id) WHERE campaign_id IS NOT NULL;
CREATE INDEX idx_point_transactions_created_at ON point_transactions(created_at DESC);
```

### 2. point_cash_transactions (현금 입출금)

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
    payment_method TEXT, -- 'bank_transfer', 'card', etc.
    
    -- 계좌 정보 (출금 시)
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
CREATE INDEX idx_point_cash_transactions_status ON point_cash_transactions(status);
CREATE INDEX idx_point_cash_transactions_created_at ON point_cash_transactions(created_at DESC);
CREATE INDEX idx_point_cash_transactions_pending ON point_cash_transactions(status) WHERE status = 'pending';
```

---

## 🔄 통합 조회가 필요한 경우

사용자가 포인트 로그를 볼 때는 캠페인 거래와 현금 거래를 한번에 보는 것이 자연스럽습니다. 분리 테이블에서 이를 해결하는 방법들:

---

### 방법 1: 통합 View 생성 (권장) ⭐

**장점**: 
- 단일 쿼리로 모든 거래 조회 가능
- 데이터베이스 레벨에서 최적화
- Flutter 코드가 단순해짐

**단점**:
- View는 읽기 전용 (INSERT/UPDATE 불가, 하지만 로그 조회에는 문제없음)

```sql
-- 모든 포인트 거래 통합 뷰
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
    created_at AS completed_at, -- 즉시 완료
    'campaign' AS transaction_category,
    -- 캠페인 거래에는 현금 필드 없음
    NULL AS cash_amount,
    NULL AS payment_method,
    NULL AS bank_name,
    NULL AS account_number,
    NULL AS account_holder
FROM point_transactions;

-- 인덱스는 원본 테이블에 있으므로 View 조회 시 자동 활용됨
```

**사용 예시**:
```sql
-- 사용자별 전체 포인트 내역 조회
SELECT * FROM all_point_transactions 
WHERE user_id = 'user-uuid'
ORDER BY created_at DESC
LIMIT 50;

-- 회사별 전체 포인트 내역 조회
SELECT * FROM all_point_transactions 
WHERE company_id = 'company-uuid'
ORDER BY created_at DESC
LIMIT 50;
```

---

### 방법 2: RPC 함수로 통합 조회

**장점**:
- 비즈니스 로직을 데이터베이스에 캡슐화
- 권한 검사 등 추가 로직 포함 가능
- Flutter 코드가 매우 단순해짐

**단점**:
- 함수 유지보수 필요

```sql
-- 사용자 포인트 내역 통합 조회 함수
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
            -- 현금 거래 필드
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

-- 회사 포인트 내역 통합 조회 함수
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
BEGIN
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
            -- 현금 거래 필드
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

---

### 방법 3: Flutter에서 두 테이블 조회 후 합치기

**장점**:
- 데이터베이스 변경 없음
- 클라이언트에서 필터링/정렬 가능

**단점**:
- 두 번의 쿼리 필요
- 클라이언트에서 정렬/병합 로직 필요
- 네트워크 오버헤드

```dart
// Flutter 서비스 예시
static Future<List<UnifiedPointTransaction>> getUserPointHistoryUnified({
  required String userId,
  int limit = 50,
  int offset = 0,
}) async {
  try {
    // 두 테이블을 병렬로 조회
    final campaignFuture = _supabase
        .from('point_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit)
        .offset(offset);
    
    final cashFuture = _supabase
        .from('point_cash_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit)
        .offset(offset);
    
    // 병렬 실행
    final results = await Future.wait([campaignFuture, cashFuture]);
    final campaignTransactions = results[0] as List;
    final cashTransactions = results[1] as List;
    
    // 합치고 정렬
    final allTransactions = [
      ...campaignTransactions.map((t) => UnifiedPointTransaction.fromCampaign(t)),
      ...cashTransactions.map((t) => UnifiedPointTransaction.fromCash(t)),
    ];
    
    // 날짜순 정렬
    allTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return allTransactions.take(limit).toList();
  } catch (e) {
    print('Error getting unified point history: $e');
    rethrow;
  }
}
```

---

### 방법 4: RPC 함수에서 UNION 직접 사용 (성능 최적화)

**장점**:
- View 없이 직접 조회 (더 빠를 수 있음)
- 필요한 필드만 선택 가능

**단점**:
- 쿼리가 복잡해짐

```sql
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
    WITH unified_transactions AS (
        -- 현금 거래
        SELECT 
            id,
            user_id,
            company_id,
            wallet_id,
            transaction_type,
            amount,
            NULL::UUID AS campaign_id,
            NULL::TEXT AS related_entity_type,
            NULL::UUID AS related_entity_id,
            description,
            status,
            approved_by,
            rejected_by,
            rejection_reason,
            created_by_user_id,
            created_at,
            updated_at,
            completed_at,
            'cash' AS transaction_category
        FROM point_cash_transactions
        WHERE user_id = p_user_id
        
        UNION ALL
        
        -- 캠페인 거래
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
            'completed' AS status,
            NULL::UUID AS approved_by,
            NULL::UUID AS rejected_by,
            NULL::TEXT AS rejection_reason,
            created_by_user_id,
            created_at,
            updated_at,
            created_at AS completed_at,
            'campaign' AS transaction_category
        FROM point_transactions
        WHERE user_id = p_user_id
    )
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
            'transaction_category', transaction_category,
            'created_at', created_at,
            'updated_at', updated_at,
            'completed_at', completed_at
        )
    )
    INTO v_result
    FROM unified_transactions
    ORDER BY created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
    
    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;
```

---

## 🎯 권장 방법: View + RPC 함수 조합

### 1단계: View 생성
- `all_point_transactions` View 생성
- 통합 조회의 기반 제공

### 2단계: RPC 함수 생성
- `get_user_point_history_unified`: 사용자 통합 내역
- `get_company_point_history_unified`: 회사 통합 내역
- View를 사용하여 간단하게 구현

### 3단계: Flutter 코드
```dart
// 단일 RPC 호출로 모든 거래 조회
static Future<List<UnifiedPointTransaction>> getUserPointHistory({
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
      .map((e) => UnifiedPointTransaction.fromJson(e))
      .toList();
}
```

---

## 📊 방법별 비교

| 방법 | 성능 | 구현 복잡도 | 유지보수 | 권장도 |
|------|------|------------|---------|--------|
| **View + RPC** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ **최고** |
| **RPC 직접 UNION** | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ✅ 좋음 |
| **Flutter 병합** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⚠️ 비권장 |

**결론**: **View + RPC 함수 조합**이 가장 효율적이고 유지보수하기 좋습니다.

---

## 📊 최종 비교표

| 항목 | 통합 테이블 | 분리 테이블 |
|------|------------|------------|
| **비즈니스 로직** | ❌ 섞임 | ✅ 명확히 분리 |
| **필드 최적화** | ❌ NULL 많음 | ✅ 필요한 필드만 |
| **쿼리 성능** | ⚠️ 복잡한 WHERE | ✅ 최적화 용이 |
| **인덱스 효율** | ❌ 비효율적 | ✅ 효율적 |
| **확장성** | ❌ 제약 많음 | ✅ 독립적 확장 |
| **유지보수** | ⚠️ 조건문 많음 | ✅ 명확한 책임 |
| **통합 조회** | ✅ 단순 | ⚠️ UNION 필요 (View로 해결) |
| **코드 중복** | ✅ 없음 | ⚠️ 약간 있음 (공통 함수로 해결) |

---

## 🎯 최종 권장사항

### **분리 테이블 (옵션 B) 권장** ✅

**이유:**
1. 비즈니스 로직이 근본적으로 다름
2. 필요한 필드가 다름
3. 쿼리 패턴이 다름
4. 성능과 확장성 면에서 유리
5. 통합 조회가 필요한 경우 View로 해결 가능

**구현 전략:**
- `point_transactions`: 캠페인 거래만 (earn, spend)
- `point_cash_transactions`: 현금 입출금만 (deposit, withdraw)
- **통합 조회**: `all_point_transactions` View + RPC 함수 조합 사용
  - 사용자가 포인트 로그를 볼 때는 View를 통해 한번에 조회
  - RPC 함수로 권한 검사 및 비즈니스 로직 처리

---

## 📝 마이그레이션 영향

### 기존 테이블 매핑
- `user_point_logs` → `point_transactions` (earn) + `point_cash_transactions` (withdraw)
- `company_point_logs` → `point_transactions` (spend) + `point_cash_transactions` (deposit, withdraw)

### 데이터 분리 기준
```sql
-- 캠페인 거래로 분류
- transaction_type IN ('earn', 'spend') AND campaign_id IS NOT NULL
- transaction_type = 'spend' AND company_id IS NOT NULL

-- 현금 거래로 분류
- transaction_type IN ('deposit', 'withdraw')
- transaction_type = 'charge' (회사 입금)
```

