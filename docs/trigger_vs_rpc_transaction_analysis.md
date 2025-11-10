# 트리거 삭제 + RPC 트랜잭션 처리 분석

## 현재 상황

### 문제점
- 트리거가 `wallets` 업데이트 시 `wallet_histories`에 INSERT 시도
- `wallet_histories` 테이블이 없어서 에러 발생
- 애플리케이션 코드에서도 `wallet_histories`에 INSERT 시도 (try-catch로 감싸져 있음)

### 제안: 트리거 삭제 + RPC 트랜잭션

---

## 방법 비교

### 현재 방식 (트리거 사용)
```sql
-- 트리거가 자동으로 wallet_histories에 기록
CREATE TRIGGER log_wallet_account_change_trigger
    AFTER UPDATE ON wallets
    FOR EACH ROW
    WHEN (...)
    EXECUTE FUNCTION log_wallet_account_change();
```

**문제점:**
- 트리거가 테이블 존재 여부를 확인하지 못함
- 에러 발생 시 전체 트랜잭션 롤백
- 디버깅 어려움

### 제안 방식 (RPC 트랜잭션)
```sql
-- RPC 함수로 wallets 업데이트 + wallet_histories 기록을 원자적으로 처리
CREATE OR REPLACE FUNCTION update_user_wallet_account(
    p_wallet_id UUID,
    p_bank_name TEXT,
    p_account_number TEXT,
    p_account_holder TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_old_bank_name TEXT;
    v_old_account_number TEXT;
    v_old_account_holder TEXT;
BEGIN
    -- 트랜잭션 시작 (PostgreSQL 함수는 자동으로 트랜잭션 블록)
    BEGIN
        -- 이전 계좌정보 조회
        SELECT withdraw_bank_name, withdraw_account_number, withdraw_account_holder
        INTO v_old_bank_name, v_old_account_number, v_old_account_holder
        FROM wallets
        WHERE id = p_wallet_id
        FOR UPDATE; -- 행 잠금으로 동시성 제어
        
        -- wallets 테이블 업데이트
        UPDATE wallets
        SET 
            withdraw_bank_name = p_bank_name,
            withdraw_account_number = p_account_number,
            withdraw_account_holder = p_account_holder,
            updated_at = NOW()
        WHERE id = p_wallet_id;
        
        -- 변경이 있었으면 wallet_histories에 기록
        IF (v_old_bank_name IS DISTINCT FROM p_bank_name) OR
           (v_old_account_number IS DISTINCT FROM p_account_number) OR
           (v_old_account_holder IS DISTINCT FROM p_account_holder) THEN
            
            -- wallet_histories 테이블이 없어도 에러 처리
            BEGIN
                INSERT INTO wallet_histories (
                    wallet_id,
                    old_bank_name,
                    old_account_number,
                    old_account_holder,
                    new_bank_name,
                    new_account_number,
                    new_account_holder,
                    changed_by,
                    created_at
                ) VALUES (
                    p_wallet_id,
                    v_old_bank_name,
                    v_old_account_number,
                    v_old_account_holder,
                    p_bank_name,
                    p_account_number,
                    p_account_holder,
                    auth.uid(),
                    NOW()
                );
            EXCEPTION WHEN OTHERS THEN
                -- wallet_histories 테이블이 없어도 계좌정보 업데이트는 성공
                RAISE WARNING 'Failed to insert wallet_histories: %', SQLERRM;
            END;
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        -- 에러 발생 시 자동으로 롤백됨
        RAISE;
    END;
END;
$$;
```

---

## 장단점 분석

### 트리거 삭제 + RPC 트랜잭션의 장점 ✅

1. **명시적 제어**
   - 애플리케이션 코드에서 명확하게 호출
   - 에러 처리 로직을 함수 내부에서 관리

2. **트랜잭션 보장**
   - PostgreSQL 함수는 자동으로 트랜잭션 블록
   - `BEGIN...EXCEPTION` 블록으로 에러 처리 강화
   - `FOR UPDATE`로 동시성 제어

3. **에러 처리 유연성**
   - `wallet_histories` 테이블이 없어도 계좌정보 업데이트는 성공
   - `RAISE WARNING`으로 로그만 남기고 계속 진행

4. **디버깅 용이**
   - RPC 함수 호출 시 에러 메시지 명확
   - 함수 내부에서 단계별 처리 가능

5. **일관성**
   - 다른 서비스들(`point_service`, `campaign_service`)도 RPC 사용
   - 코드베이스 전체의 일관성 유지

6. **테스트 용이**
   - RPC 함수를 직접 테스트 가능
   - 트리거보다 테스트하기 쉬움

### 트리거 삭제 + RPC 트랜잭션의 단점 ❌

1. **애플리케이션 코드 수정 필요**
   - `wallet_service.dart`에서 직접 UPDATE 대신 RPC 호출로 변경
   - 두 곳 수정 필요: `updateUserWalletAccount`, `updateCompanyWalletAccount`

2. **다른 경로로 업데이트 시 누락**
   - SQL Editor나 다른 도구로 직접 UPDATE 시 이력 기록 안 됨
   - 하지만 이는 애플리케이션에서만 업데이트하므로 문제 없음

3. **코드 복잡도 증가**
   - RPC 함수 작성 및 유지보수 필요
   - 하지만 다른 서비스들과 일관성 있음

---

## 구현 방법

### 1. 마이그레이션 파일 생성

```sql
-- supabase/migrations/20250107000006_replace_trigger_with_rpc.sql

-- 1. 트리거 삭제
DROP TRIGGER IF EXISTS log_wallet_account_change_trigger ON wallets;
DROP TRIGGER IF EXISTS trigger_log_wallet_account_change ON wallets;

-- 2. 트리거 함수는 유지 (다른 곳에서 사용할 수 있으므로)
-- 또는 삭제: DROP FUNCTION IF EXISTS log_wallet_account_change();

-- 3. RPC 함수: 개인 지갑 계좌정보 업데이트
CREATE OR REPLACE FUNCTION update_user_wallet_account(
    p_wallet_id UUID,
    p_bank_name TEXT,
    p_account_number TEXT,
    p_account_holder TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_old_bank_name TEXT;
    v_old_account_number TEXT;
    v_old_account_holder TEXT;
    v_user_id UUID;
BEGIN
    -- 사용자 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION '로그인이 필요합니다';
    END IF;
    
    -- 트랜잭션 시작
    BEGIN
        -- 이전 계좌정보 조회 (행 잠금)
        SELECT withdraw_bank_name, withdraw_account_number, withdraw_account_holder
        INTO v_old_bank_name, v_old_account_number, v_old_account_holder
        FROM wallets
        WHERE id = p_wallet_id
        AND user_id = v_user_id
        FOR UPDATE;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION '지갑을 찾을 수 없습니다';
        END IF;
        
        -- wallets 테이블 업데이트
        UPDATE wallets
        SET 
            withdraw_bank_name = p_bank_name,
            withdraw_account_number = p_account_number,
            withdraw_account_holder = p_account_holder,
            updated_at = NOW()
        WHERE id = p_wallet_id
        AND user_id = v_user_id;
        
        -- 변경이 있었으면 wallet_histories에 기록
        IF (v_old_bank_name IS DISTINCT FROM p_bank_name) OR
           (v_old_account_number IS DISTINCT FROM p_account_number) OR
           (v_old_account_holder IS DISTINCT FROM p_account_holder) THEN
            
            BEGIN
                INSERT INTO wallet_histories (
                    wallet_id,
                    old_bank_name,
                    old_account_number,
                    old_account_holder,
                    new_bank_name,
                    new_account_number,
                    new_account_holder,
                    changed_by,
                    created_at
                ) VALUES (
                    p_wallet_id,
                    v_old_bank_name,
                    v_old_account_number,
                    v_old_account_holder,
                    p_bank_name,
                    p_account_number,
                    p_account_holder,
                    v_user_id,
                    NOW()
                );
            EXCEPTION WHEN OTHERS THEN
                -- wallet_histories 테이블이 없어도 계좌정보 업데이트는 성공
                RAISE WARNING 'Failed to insert wallet_histories: %', SQLERRM;
            END;
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE;
    END;
END;
$$;

-- 4. RPC 함수: 회사 지갑 계좌정보 업데이트
CREATE OR REPLACE FUNCTION update_company_wallet_account(
    p_wallet_id UUID,
    p_company_id UUID,
    p_bank_name TEXT,
    p_account_number TEXT,
    p_account_holder TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_old_bank_name TEXT;
    v_old_account_number TEXT;
    v_old_account_holder TEXT;
    v_user_id UUID;
BEGIN
    -- 사용자 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION '로그인이 필요합니다';
    END IF;
    
    -- 권한 확인: owner만 가능
    IF NOT EXISTS (
        SELECT 1 FROM company_users
        WHERE company_id = p_company_id
        AND user_id = v_user_id
        AND company_role = 'owner'
        AND status = 'active'
    ) THEN
        RAISE EXCEPTION '회사 소유자만 계좌정보를 수정할 수 있습니다';
    END IF;
    
    -- 트랜잭션 시작
    BEGIN
        -- 이전 계좌정보 조회 (행 잠금)
        SELECT withdraw_bank_name, withdraw_account_number, withdraw_account_holder
        INTO v_old_bank_name, v_old_account_number, v_old_account_holder
        FROM wallets
        WHERE id = p_wallet_id
        AND company_id = p_company_id
        FOR UPDATE;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION '회사 지갑을 찾을 수 없습니다';
        END IF;
        
        -- wallets 테이블 업데이트
        UPDATE wallets
        SET 
            withdraw_bank_name = p_bank_name,
            withdraw_account_number = p_account_number,
            withdraw_account_holder = p_account_holder,
            updated_at = NOW()
        WHERE id = p_wallet_id
        AND company_id = p_company_id;
        
        -- 변경이 있었으면 wallet_histories에 기록
        IF (v_old_bank_name IS DISTINCT FROM p_bank_name) OR
           (v_old_account_number IS DISTINCT FROM p_account_number) OR
           (v_old_account_holder IS DISTINCT FROM p_account_holder) THEN
            
            BEGIN
                INSERT INTO wallet_histories (
                    wallet_id,
                    old_bank_name,
                    old_account_number,
                    old_account_holder,
                    new_bank_name,
                    new_account_number,
                    new_account_holder,
                    changed_by,
                    created_at
                ) VALUES (
                    p_wallet_id,
                    v_old_bank_name,
                    v_old_account_number,
                    v_old_account_holder,
                    p_bank_name,
                    p_account_number,
                    p_account_holder,
                    v_user_id,
                    NOW()
                );
            EXCEPTION WHEN OTHERS THEN
                -- wallet_histories 테이블이 없어도 계좌정보 업데이트는 성공
                RAISE WARNING 'Failed to insert wallet_histories: %', SQLERRM;
            END;
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE;
    END;
END;
$$;
```

### 2. 애플리케이션 코드 수정

```dart
// lib/services/wallet_service.dart

/// 개인 지갑 계좌정보 업데이트
static Future<void> updateUserWalletAccount({
  required String bankName,
  required String accountNumber,
  required String accountHolder,
}) async {
  try {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('로그인이 필요합니다');
    }

    // 지갑 조회
    final wallet = await getUserWallet();
    if (wallet == null) {
      throw Exception('지갑을 찾을 수 없습니다');
    }

    // RPC 함수 호출로 트랜잭션 처리
    await _supabase.rpc('update_user_wallet_account', params: {
      'p_wallet_id': wallet.id,
      'p_bank_name': bankName,
      'p_account_number': accountNumber,
      'p_account_holder': accountHolder,
    });

    print('✅ 개인 지갑 계좌정보 업데이트 성공');
  } catch (e) {
    print('❌ 개인 지갑 계좌정보 업데이트 실패: $e');
    rethrow;
  }
}

/// 회사 지갑 계좌정보 업데이트
static Future<void> updateCompanyWalletAccount({
  required String companyId,
  required String bankName,
  required String accountNumber,
  required String accountHolder,
}) async {
  try {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('로그인이 필요합니다');
    }

    // 지갑 조회
    final wallet = await getCompanyWalletByCompanyId(companyId);
    if (wallet == null) {
      throw Exception('회사 지갑을 찾을 수 없습니다');
    }

    // RPC 함수 호출로 트랜잭션 처리
    await _supabase.rpc('update_company_wallet_account', params: {
      'p_wallet_id': wallet.id,
      'p_company_id': companyId,
      'p_bank_name': bankName,
      'p_account_number': accountNumber,
      'p_account_holder': accountHolder,
    });

    print('✅ 회사 지갑 계좌정보 업데이트 성공');
  } catch (e) {
    print('❌ 회사 지갑 계좌정보 업데이트 실패: $e');
    rethrow;
  }
}
```

---

## 결론

### ✅ 트리거 삭제 + RPC 트랜잭션 권장

**이유:**
1. **일관성**: 다른 서비스들과 동일한 패턴 사용
2. **에러 처리**: `wallet_histories` 테이블이 없어도 계좌정보 업데이트 성공
3. **트랜잭션 보장**: 원자적 처리 보장
4. **유지보수**: 명시적이고 테스트하기 쉬움
5. **동시성 제어**: `FOR UPDATE`로 행 잠금

**단점:**
- 애플리케이션 코드 수정 필요 (하지만 간단함)
- RPC 함수 작성 필요 (하지만 한 번만 작성)

**최종 권장: 트리거 삭제 + RPC 트랜잭션으로 구현**

