-- cash_transactions 트리거 조건 및 함수 수정
-- pending/approved/rejected 3가지 상태만 사용
-- 
-- 문제: 기존 트리거는 status = 'completed'일 때만 실행되어 
--       approved 상태로 변경될 때 포인트가 반영되지 않았습니다.
-- 해결: 
--   1. 트리거 조건을 제거하고 함수 내에서 상태를 체크하도록 변경
--   2. 입금(deposit): approved 상태일 때 잔액 증가
--   3. 출금(withdraw): approved 상태일 때 잔액 차감
--   4. completed 상태는 사용하지 않음

-- 트리거 함수 수정: 입금/출금 모두 approved 상태일 때만 잔액 변경
CREATE OR REPLACE FUNCTION "public"."update_wallet_balance_on_cash_transaction"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    -- 입금(deposit)과 출금(withdraw) 모두 approved 상태일 때만 잔액 변경
    IF NEW.transaction_type = 'deposit' THEN
        -- 입금: approved 상태로 변경될 때 잔액 증가
        IF NEW.status = 'approved' 
           AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
            UPDATE public.wallets
            SET current_points = current_points + NEW.point_amount,
                updated_at = NOW()
            WHERE id = NEW.wallet_id;
        -- 입금: approved에서 다른 상태로 변경될 때 잔액 차감 (롤백)
        ELSIF OLD.status = 'approved' AND NEW.status != 'approved' THEN
            UPDATE public.wallets
            SET current_points = current_points - OLD.point_amount,
                updated_at = NOW()
            WHERE id = NEW.wallet_id;
        END IF;
    ELSIF NEW.transaction_type = 'withdraw' THEN
        -- 출금: approved 상태로 변경될 때 잔액 차감
        IF NEW.status = 'approved' 
           AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
            UPDATE public.wallets
            SET current_points = current_points - NEW.point_amount,
                updated_at = NOW()
            WHERE id = NEW.wallet_id;
        -- 출금: approved에서 다른 상태로 변경될 때 잔액 증가 (롤백)
        ELSIF OLD.status = 'approved' AND NEW.status != 'approved' THEN
            UPDATE public.wallets
            SET current_points = current_points + OLD.point_amount,
                updated_at = NOW()
            WHERE id = NEW.wallet_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

-- 기존 트리거 삭제
DROP TRIGGER IF EXISTS "cash_transactions_wallet_balance_trigger" ON "public"."cash_transactions";

-- 트리거 재생성: 조건 없이 항상 실행 (함수 내에서 상태 체크)
CREATE TRIGGER "cash_transactions_wallet_balance_trigger" 
AFTER INSERT OR UPDATE ON "public"."cash_transactions" 
FOR EACH ROW 
EXECUTE FUNCTION "public"."update_wallet_balance_on_cash_transaction"();

-- 트리거 설명 추가
COMMENT ON TRIGGER "cash_transactions_wallet_balance_trigger" ON "public"."cash_transactions" IS 
'입금(deposit)과 출금(withdraw) 거래 모두 approved 상태로 변경될 때 지갑 잔액을 업데이트합니다.
입금은 approved 상태일 때 잔액 증가, 출금은 approved 상태일 때 잔액 차감.
함수 내에서 OLD와 NEW 상태를 비교하여 필요한 경우에만 잔액을 업데이트합니다.';

