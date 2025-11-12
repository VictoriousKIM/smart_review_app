# 포인트 지갑 간 이동(Transfer) 기능 로드맵
## 회사 소유자(Owner)의 개인 포인트 ↔ 회사 포인트 이동

## 📋 목표

회사 소유자(owner)가 자신의 개인 지갑과 회사 지갑 간에 포인트를 이동할 수 있는 기능 구현:
- 개인 포인트 → 회사 포인트 (충전)
- 회사 포인트 → 개인 포인트 (인출)

## 🎯 설계 결정 사항

### 옵션 1: point_transactions에 transfer 타입 추가 ⭐ 권장
- **장점**: 
  - 기존 구조 활용
  - 통합 조회 가능
  - 간단한 구현
- **단점**: 
  - transfer는 캠페인과 무관하지만 같은 테이블에 존재
- **구조**: `transaction_type`에 'transfer' 추가

### 옵션 2: 별도 point_transfers 테이블 생성
- **장점**: 
  - 명확한 책임 분리
  - transfer 전용 필드 추가 가능
- **단점**: 
  - 별도 조회 필요
  - 복잡도 증가

**권장: 옵션 1** - 기존 구조 활용, 통합 조회 가능

---

## 📐 데이터베이스 설계

### 1. point_transactions 테이블 수정

```sql
-- transaction_type에 'transfer' 추가
ALTER TABLE point_transactions
    DROP CONSTRAINT IF EXISTS point_transactions_transaction_type_check;

ALTER TABLE point_transactions
    ADD CONSTRAINT point_transactions_transaction_type_check CHECK (
        transaction_type IN ('earn', 'spend', 'transfer')
    );

-- transfer 전용 필드 추가
ALTER TABLE point_transactions
    ADD COLUMN IF NOT EXISTS transfer_to_wallet_id UUID REFERENCES wallets(id) ON DELETE SET NULL;

-- 코멘트
COMMENT ON COLUMN point_transactions.transfer_to_wallet_id IS '이동 대상 지갑 ID (transfer 타입일 때만 사용)';
```

### 2. Transfer 거래 구조

**Transfer 거래는 두 개의 레코드로 기록:**
- **출발 지갑**: `amount` 음수 (차감)
- **도착 지갑**: `amount` 양수 (증가)

**또는 단일 레코드로 기록:**
- **출발 지갑**: `transaction_type = 'transfer'`, `amount` 음수
- **도착 지갑**: `transfer_to_wallet_id` 참조, 별도 레코드 생성

**권장: 단일 레코드 방식** - 출발 지갑에만 기록하고, 도착 지갑은 별도 레코드로 생성

---

## 🔄 Transfer 거래 시나리오

### 시나리오 1: 개인 포인트 → 회사 포인트 (10,000P)

```sql
-- 1. 출발 지갑 (개인) - 차감
INSERT INTO point_transactions (
    wallet_id,
    transaction_type,
    amount,  -- -10000
    transfer_to_wallet_id,  -- 회사 지갑 ID
    description,
    created_by_user_id,
    completed_at
) VALUES (
    'user-wallet-id',
    'transfer',
    -10000,
    'company-wallet-id',
    '개인 포인트 → 회사 포인트 이동',
    'user-id',
    NOW()
);

-- 2. 도착 지갑 (회사) - 증가
INSERT INTO point_transactions (
    wallet_id,
    transaction_type,
    amount,  -- +10000
    transfer_to_wallet_id,  -- NULL (도착 지갑이므로)
    related_entity_type,  -- 'transfer'
    related_entity_id,  -- 출발 거래 ID
    description,
    created_by_user_id,
    completed_at
) VALUES (
    'company-wallet-id',
    'transfer',
    10000,
    NULL,
    'transfer',
    '출발-거래-id',  -- 첫 번째 INSERT의 id
    '개인 포인트 → 회사 포인트 이동',
    'user-id',
    NOW()
);
```

### 시나리오 2: 회사 포인트 → 개인 포인트 (5,000P)

```sql
-- 1. 출발 지갑 (회사) - 차감
INSERT INTO point_transactions (
    wallet_id,
    transaction_type,
    amount,  -- -5000
    transfer_to_wallet_id,  -- 개인 지갑 ID
    description,
    created_by_user_id,
    completed_at
) VALUES (
    'company-wallet-id',
    'transfer',
    -5000,
    'user-wallet-id',
    '회사 포인트 → 개인 포인트 이동',
    'user-id',
    NOW()
);

-- 2. 도착 지갑 (개인) - 증가
INSERT INTO point_transactions (
    wallet_id,
    transaction_type,
    amount,  -- +5000
    transfer_to_wallet_id,  -- NULL
    related_entity_type,  -- 'transfer'
    related_entity_id,  -- 출발 거래 ID
    description,
    created_by_user_id,
    completed_at
) VALUES (
    'user-wallet-id',
    'transfer',
    5000,
    NULL,
    'transfer',
    '출발-거래-id',
    '회사 포인트 → 개인 포인트 이동',
    'user-id',
    NOW()
);
```

---

## 🔧 RPC 함수 설계

### 1. Transfer 거래 생성 함수

```sql
CREATE OR REPLACE FUNCTION transfer_points_between_wallets(
    p_from_wallet_id UUID,
    p_to_wallet_id UUID,
    p_amount INTEGER,
    p_description TEXT DEFAULT NULL,
    p_created_by_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_from_wallet RECORD;
    v_to_wallet RECORD;
    v_user_id UUID;
    v_from_transaction_id UUID;
    v_to_transaction_id UUID;
    v_result JSONB;
BEGIN
    -- 현재 사용자 확인
    v_user_id := COALESCE(p_created_by_user_id, auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 출발 지갑 정보 조회
    SELECT id, user_id, company_id, current_points INTO v_from_wallet
    FROM wallets
    WHERE id = p_from_wallet_id;
    
    IF v_from_wallet IS NULL THEN
        RAISE EXCEPTION 'From wallet not found';
    END IF;
    
    -- 도착 지갑 정보 조회
    SELECT id, user_id, company_id INTO v_to_wallet
    FROM wallets
    WHERE id = p_to_wallet_id;
    
    IF v_to_wallet IS NULL THEN
        RAISE EXCEPTION 'To wallet not found';
    END IF;
    
    -- 금액 검증
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be positive';
    END IF;
    
    -- 잔액 검증
    IF v_from_wallet.current_points < p_amount THEN
        RAISE EXCEPTION 'Insufficient balance';
    END IF;
    
    -- 권한 검증: 회사 소유자만 이동 가능
    -- 케이스 1: 개인 → 회사
    IF v_from_wallet.user_id = v_user_id AND v_to_wallet.company_id IS NOT NULL THEN
        -- 사용자가 해당 회사의 owner인지 확인
        IF NOT EXISTS (
            SELECT 1 FROM company_users
            WHERE company_id = v_to_wallet.company_id
            AND user_id = v_user_id
            AND company_role = 'owner'
            AND status = 'active'
        ) THEN
            RAISE EXCEPTION 'Only company owner can transfer points to company wallet';
        END IF;
    -- 케이스 2: 회사 → 개인
    ELSIF v_from_wallet.company_id IS NOT NULL AND v_to_wallet.user_id = v_user_id THEN
        -- 사용자가 해당 회사의 owner인지 확인
        IF NOT EXISTS (
            SELECT 1 FROM company_users
            WHERE company_id = v_from_wallet.company_id
            AND user_id = v_user_id
            AND company_role = 'owner'
            AND status = 'active'
        ) THEN
            RAISE EXCEPTION 'Only company owner can transfer points from company wallet';
        END IF;
    ELSE
        RAISE EXCEPTION 'Invalid transfer: must be between user wallet and company wallet owned by the user';
    END IF;
    
    -- 출발 지갑 거래 생성 (차감)
    INSERT INTO point_transactions (
        wallet_id,
        transaction_type,
        amount,
        transfer_to_wallet_id,
        related_entity_type,
        description,
        created_by_user_id,
        completed_at
    ) VALUES (
        p_from_wallet_id,
        'transfer',
        -p_amount,  -- 음수 (차감)
        p_to_wallet_id,
        'transfer',
        COALESCE(p_description, '포인트 이동'),
        v_user_id,
        NOW()
    )
    RETURNING id INTO v_from_transaction_id;
    
    -- 도착 지갑 거래 생성 (증가)
    INSERT INTO point_transactions (
        wallet_id,
        transaction_type,
        amount,
        transfer_to_wallet_id,
        related_entity_type,
        related_entity_id,
        description,
        created_by_user_id,
        completed_at
    ) VALUES (
        p_to_wallet_id,
        'transfer',
        p_amount,  -- 양수 (증가)
        NULL,  -- 도착 지갑이므로 NULL
        'transfer',
        v_from_transaction_id,  -- 출발 거래 ID 참조
        COALESCE(p_description, '포인트 이동'),
        v_user_id,
        NOW()
    )
    RETURNING id INTO v_to_transaction_id;
    
    -- 결과 반환
    v_result := jsonb_build_object(
        'from_transaction_id', v_from_transaction_id,
        'to_transaction_id', v_to_transaction_id,
        'from_wallet_id', p_from_wallet_id,
        'to_wallet_id', p_to_wallet_id,
        'amount', p_amount
    );
    
    RETURN v_result;
END;
$$;
```

---

## 🔐 RLS 정책 업데이트

Transfer 거래는 기존 RLS 정책으로 충분합니다:
- `wallet_id`를 통해 wallets JOIN으로 권한 확인
- 회사 소유자 권한은 RPC 함수 내에서 검증

---

## 📱 Flutter 코드 업데이트

### 1. WalletService에 Transfer 함수 추가

```dart
/// 포인트 지갑 간 이동 (회사 소유자만 가능)
static Future<Map<String, dynamic>> transferPointsBetweenWallets({
  required String fromWalletId,
  required String toWalletId,
  required int amount,
  String? description,
}) async {
  try {
    final response = await _supabase.rpc(
      'transfer_points_between_wallets',
      params: {
        'p_from_wallet_id': fromWalletId,
        'p_to_wallet_id': toWalletId,
        'p_amount': amount,
        'p_description': description,
      },
    ) as Map<String, dynamic>;
    
    print('✅ 포인트 이동 성공: $amount P');
    return response;
  } catch (e) {
    print('❌ 포인트 이동 실패: $e');
    rethrow;
  }
}
```

### 2. UnifiedPointTransaction 모델 업데이트

```dart
// wallet_models.dart에 추가
bool get isTransfer => transactionType == 'transfer';
String? get transferToWalletId; // transfer_to_wallet_id 필드 추가
```

---

## 📊 마이그레이션 단계별 계획

### Phase 1: 테이블 구조 수정 (1일)

1. `point_transactions.transaction_type` CHECK 제약조건 수정
2. `transfer_to_wallet_id` 컬럼 추가
3. 인덱스 추가 (필요시)

### Phase 2: RPC 함수 생성 (1일)

1. `transfer_points_between_wallets` 함수 생성
2. 권한 검증 로직 구현
3. 두 지갑 거래 생성 로직 구현

### Phase 3: Flutter 코드 업데이트 (1일)

1. `WalletService.transferPointsBetweenWallets()` 추가
2. `UnifiedPointTransaction` 모델 업데이트
3. UI 화면 추가 (선택사항)

### Phase 4: 테스트 및 검증 (1일)

1. 권한 검증 테스트
2. 잔액 검증 테스트
3. 거래 기록 확인

---

## ✅ 체크리스트

### 데이터베이스
- [ ] `point_transactions.transaction_type`에 'transfer' 추가
- [ ] `transfer_to_wallet_id` 컬럼 추가
- [ ] `transfer_points_between_wallets` RPC 함수 생성
- [ ] 권한 검증 로직 구현
- [ ] 잔액 검증 로직 구현
- [ ] 두 지갑 거래 생성 로직 구현

### Flutter 코드
- [ ] `WalletService.transferPointsBetweenWallets()` 추가
- [ ] `UnifiedPointTransaction` 모델에 `transferToWalletId` 추가
- [ ] Transfer 거래 표시 UI (선택사항)

### 테스트
- [ ] 회사 소유자 권한 검증 테스트
- [ ] 잔액 부족 시 에러 처리 테스트
- [ ] 거래 기록 정확성 검증

---

## ⚠️ 주의사항

1. **원자성 보장**: 두 거래는 트랜잭션으로 묶어야 함 (RPC 함수 내에서 처리)
2. **잔액 검증**: 출발 지갑 잔액 확인 필수
3. **권한 검증**: 회사 소유자만 이동 가능
4. **거래 기록**: 출발/도착 지갑 모두에 거래 기록
5. **관계 추적**: `related_entity_id`로 출발/도착 거래 연결

---

## 📊 예상 소요 시간

- **Phase 1**: 1일 (테이블 수정)
- **Phase 2**: 1일 (RPC 함수)
- **Phase 3**: 1일 (Flutter 코드)
- **Phase 4**: 1일 (테스트)

**총 예상 시간: 4일**

---

## 🔄 향후 확장 가능성

1. **Transfer 한도 설정**: 일일/월별 이동 한도
2. **Transfer 이력 조회**: 전용 조회 함수
3. **Transfer 승인 프로세스**: 대량 이동 시 승인 필요
4. **Transfer 수수료**: 이동 시 수수료 차감

