# wallet_histories 테이블 문제 해결 방법 비교 분석

## 현재 상황

### 문제점
- `wallets` 테이블 업데이트 시 `wallet_histories` 테이블이 없다는 에러 발생
- 에러 메시지: `relation "wallet_histories" does not exist`
- 트리거가 `SECURITY DEFINER`로 실행되지만 테이블 접근 실패

### 현재 구조
1. **마이그레이션 파일들**:
   - `20250107000002`: `CREATE TABLE IF NOT EXISTS wallet_histories` (누적 로그 방식)
   - `20250107000005`: `DROP TABLE IF EXISTS` 후 재생성 (RLS 정책 포함)

2. **트리거**:
   - `log_wallet_account_change_trigger`: `wallets` 업데이트 시 자동 실행
   - 함수: `log_wallet_account_change()` (SECURITY DEFINER)

3. **RLS 정책** (20250107000005):
   - SELECT: 사용자는 자신의 지갑 이력만 조회
   - INSERT: 사용자는 자신의 지갑 이력을 기록

4. **애플리케이션 코드**:
   - `wallet_service.dart`에서 `wallet_histories`에 직접 INSERT 시도 (try-catch로 감싸짐)

---

## 해결 방법 비교

### 방법 1: 트리거 일시 비활성화

#### 구현 방법
```sql
-- 트리거 비활성화
ALTER TABLE wallets DISABLE TRIGGER log_wallet_account_change_trigger;

-- 또는 트리거 삭제
DROP TRIGGER IF EXISTS log_wallet_account_change_trigger ON wallets;
```

#### 장점 ✅
1. **즉시 해결**: 빠르게 문제 해결 가능
2. **간단함**: 복잡한 디버깅 불필요
3. **애플리케이션 코드 활용**: `wallet_service.dart`의 try-catch로 이미 처리 중
4. **유연성**: 나중에 트리거 재활성화 가능

#### 단점 ❌
1. **이중 기록 위험**: 트리거와 애플리케이션 코드 모두에서 기록 시 중복 가능
2. **데이터 일관성**: 트리거가 비활성화되면 다른 경로로 업데이트 시 기록 누락
3. **임시방편**: 근본 원인 해결 아님
4. **유지보수**: 나중에 트리거 재활성화 시점을 놓칠 수 있음

#### 적합한 경우
- ✅ 빠른 해결이 필요한 경우
- ✅ 애플리케이션 코드에서 이미 처리하고 있는 경우
- ✅ 단기간 임시 조치가 필요한 경우

---

### 방법 2: wallet_histories 테이블 생성 여부 확인 및 RLS 정책 점검

#### 구현 방법
```sql
-- 1. 테이블 존재 확인
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'wallet_histories'
);

-- 2. 테이블이 없으면 생성
CREATE TABLE IF NOT EXISTS wallet_histories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    old_bank_name TEXT,
    old_account_number TEXT,
    old_account_holder TEXT,
    new_bank_name TEXT,
    new_account_number TEXT,
    new_account_holder TEXT,
    changed_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. RLS 정책 확인 및 수정
-- SECURITY DEFINER 함수는 RLS를 우회하므로, 트리거 함수에 대한 별도 정책 불필요
-- 하지만 애플리케이션에서 직접 INSERT 시에는 RLS 정책 필요

-- 4. 트리거 함수에 에러 처리 추가
CREATE OR REPLACE FUNCTION log_wallet_account_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- 계좌 정보가 변경된 경우에만 기록
    IF (OLD.withdraw_bank_name IS DISTINCT FROM NEW.withdraw_bank_name) OR
       (OLD.withdraw_account_number IS DISTINCT FROM NEW.withdraw_account_number) OR
       (OLD.withdraw_account_holder IS DISTINCT FROM NEW.withdraw_account_holder) THEN
        
        BEGIN
            INSERT INTO wallet_histories (
                wallet_id, old_bank_name, old_account_number, old_account_holder,
                new_bank_name, new_account_number, new_account_holder,
                changed_by, created_at
            ) VALUES (
                NEW.id,
                OLD.withdraw_bank_name, OLD.withdraw_account_number, OLD.withdraw_account_holder,
                NEW.withdraw_bank_name, NEW.withdraw_account_number, NEW.withdraw_account_holder,
                (SELECT auth.uid()), NOW()
            );
        EXCEPTION WHEN OTHERS THEN
            -- 에러 발생 시 로그만 남기고 계속 진행
            RAISE WARNING 'Failed to insert wallet_histories: %', SQLERRM;
        END;
    END IF;
    
    RETURN NEW;
END;
$$;
```

#### 장점 ✅
1. **근본 원인 해결**: 테이블 생성 문제를 확실히 해결
2. **데이터 무결성**: 트리거를 통한 자동 기록 보장
3. **에러 처리 강화**: 트리거 함수 내부에서 에러 처리
4. **장기적 안정성**: 근본적인 해결책
5. **RLS 정책 유지**: 보안 정책 유지 가능

#### 단점 ❌
1. **복잡함**: 더 많은 디버깅과 테스트 필요
2. **시간 소요**: 문제 원인 파악에 시간 필요
3. **마이그레이션 순서**: 마이그레이션 실행 순서 확인 필요

#### 적합한 경우
- ✅ 장기적 안정성이 중요한 경우
- ✅ 데이터 무결성이 중요한 경우
- ✅ 근본 원인을 해결하고 싶은 경우

---

## 권장 사항

### 단기적 해결 (즉시 적용)
**방법 1: 트리거 일시 비활성화**
- 빠르게 문제 해결
- 애플리케이션 코드에서 이미 처리 중이므로 안전

### 장기적 해결 (근본 원인 해결)
**방법 2: 테이블 생성 확인 및 RLS 정책 점검**
- 마이그레이션 실행 순서 확인
- 테이블이 실제로 생성되었는지 확인
- 트리거 함수에 에러 처리 추가

### 하이브리드 접근 (권장)
1. **즉시**: 트리거 비활성화로 문제 해결
2. **동시에**: 마이그레이션 파일 확인 및 테이블 생성 상태 점검
3. **수정**: 트리거 함수에 에러 처리 추가
4. **재활성화**: 문제 해결 후 트리거 재활성화

---

## 추가 고려사항

### 마이그레이션 순서 문제
- `20250107000002`: `CREATE TABLE IF NOT EXISTS` (테이블 생성)
- `20250107000005`: `DROP TABLE IF EXISTS` 후 재생성 (RLS 정책 포함)

**문제점**: 
- `20250107000005`에서 테이블을 삭제하고 재생성하는데, 이 과정에서 트리거가 깨질 수 있음
- 트리거가 `20250107000002`에서 생성되었는데, 테이블이 `20250107000005`에서 재생성되면 참조가 깨질 수 있음

### 해결책
1. 마이그레이션 파일 통합 또는 순서 조정
2. 트리거 생성 시점을 테이블 재생성 이후로 이동
3. 트리거 함수에 에러 처리 추가로 안정성 확보

---

## 결론

**즉시 적용**: 방법 1 (트리거 비활성화)
**장기적 해결**: 방법 2 (테이블 확인 및 RLS 정책 점검)
**최종 권장**: 하이브리드 접근 (단기 해결 + 근본 원인 해결)

