-- 현금 거래 취소 RPC 함수
-- pending 상태의 거래만 취소 가능하며, 거래와 관련 로그를 모두 삭제합니다.
CREATE OR REPLACE FUNCTION "public"."cancel_cash_transaction"("p_transaction_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_current_status TEXT;
    v_wallet_id UUID;
    v_user_id UUID;
BEGIN
    -- 사용자 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 현재 상태 및 지갑 ID 확인
    SELECT status, wallet_id INTO v_current_status, v_wallet_id
    FROM public.cash_transactions
    WHERE id = p_transaction_id;

    IF v_current_status IS NULL THEN
        RAISE EXCEPTION 'Transaction not found';
    END IF;

    -- pending 상태가 아니면 취소 불가
    IF v_current_status != 'pending' THEN
        RAISE EXCEPTION 'Only pending transactions can be cancelled';
    END IF;

    -- 권한 확인: 거래를 생성한 사용자만 취소 가능
    -- wallet을 통해 user_id 또는 company_id 확인
    IF EXISTS (
        SELECT 1 FROM public.wallets w
        WHERE w.id = v_wallet_id
        AND (
            w.user_id = v_user_id
            OR EXISTS (
                SELECT 1 FROM public.company_users cu
                WHERE cu.company_id = w.company_id
                AND cu.user_id = v_user_id
                AND cu.status = 'active'
            )
        )
    ) THEN
        -- 관련 로그 삭제
        DELETE FROM public.cash_transaction_logs
        WHERE transaction_id = p_transaction_id;

        -- 거래 삭제
        DELETE FROM public.cash_transactions
        WHERE id = p_transaction_id;

        RETURN TRUE;
    ELSE
        RAISE EXCEPTION 'You do not have permission to cancel this transaction';
    END IF;
END;
$$;

ALTER FUNCTION "public"."cancel_cash_transaction"("p_transaction_id" "uuid") OWNER TO "postgres";

