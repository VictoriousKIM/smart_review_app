-- cash_transactions 테이블의 amount 필드를 point_amount로 변경

-- 1. 새 컬럼 추가
ALTER TABLE "public"."cash_transactions"
ADD COLUMN "point_amount" integer;

-- 2. 기존 데이터 마이그레이션
UPDATE "public"."cash_transactions"
SET "point_amount" = "amount";

-- 3. NOT NULL 제약조건 추가
ALTER TABLE "public"."cash_transactions"
ALTER COLUMN "point_amount" SET NOT NULL;

-- 4. 기존 제약조건 삭제
ALTER TABLE "public"."cash_transactions"
DROP CONSTRAINT IF EXISTS "cash_transactions_amount_check";

-- 5. 새 제약조건 추가
ALTER TABLE "public"."cash_transactions"
ADD CONSTRAINT "cash_transactions_point_amount_check" CHECK (("point_amount" <> 0));

-- 6. 기존 함수 삭제 (파라미터 이름 변경을 위해)
DROP FUNCTION IF EXISTS "public"."create_cash_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_amount" integer, "p_cash_amount" numeric, "p_payment_method" "text", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text", "p_description" "text", "p_created_by_user_id" "uuid");

-- 7. 기존 컬럼 삭제
ALTER TABLE "public"."cash_transactions"
DROP COLUMN "amount";

-- 8. RPC 함수 재생성: create_cash_transaction (새 파라미터 이름으로)
CREATE FUNCTION "public"."create_cash_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_point_amount" integer, "p_cash_amount" numeric DEFAULT NULL::numeric, "p_payment_method" "text" DEFAULT NULL::"text", "p_bank_name" "text" DEFAULT NULL::"text", "p_account_number" "text" DEFAULT NULL::"text", "p_account_holder" "text" DEFAULT NULL::"text", "p_description" "text" DEFAULT NULL::"text", "p_created_by_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_transaction_id UUID;
BEGIN
    -- wallet 존재 확인
    IF NOT EXISTS (SELECT 1 FROM public.wallets WHERE id = p_wallet_id) THEN
        RAISE EXCEPTION 'Wallet not found';
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
    INSERT INTO public.cash_transactions (
        wallet_id,
        transaction_type,
        point_amount,
        cash_amount,
        payment_method,
        bank_name,
        account_number,
        account_holder,
        description,
        created_by_user_id
    ) VALUES (
        p_wallet_id,
        p_transaction_type,
        p_point_amount,
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

ALTER FUNCTION "public"."create_cash_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_point_amount" integer, "p_cash_amount" numeric, "p_payment_method" "text", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text", "p_description" "text", "p_created_by_user_id" "uuid") OWNER TO "postgres";

-- 권한 부여
GRANT ALL ON FUNCTION "public"."create_cash_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_point_amount" integer, "p_cash_amount" numeric, "p_payment_method" "text", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text", "p_description" "text", "p_created_by_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_cash_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_point_amount" integer, "p_cash_amount" numeric, "p_payment_method" "text", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text", "p_description" "text", "p_created_by_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_cash_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_point_amount" integer, "p_cash_amount" numeric, "p_payment_method" "text", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text", "p_description" "text", "p_created_by_user_id" "uuid") TO "service_role";

-- 9. 트리거 함수 업데이트: update_wallet_balance_on_cash_transaction
CREATE OR REPLACE FUNCTION "public"."update_wallet_balance_on_cash_transaction"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    -- completed 상태로 변경될 때만 잔액 업데이트
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        UPDATE public.wallets
        SET current_points = current_points + NEW.point_amount,
            updated_at = NOW()
        WHERE id = NEW.wallet_id;
    END IF;
    RETURN NEW;
END;
$$;

-- 10. 통합 포인트 내역 조회 함수 업데이트: get_user_point_history_unified
CREATE OR REPLACE FUNCTION "public"."get_user_point_history_unified"("p_user_id" "uuid", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_result jsonb;
BEGIN
    WITH sorted_transactions AS (
        -- 캠페인 거래
        SELECT 
            pt.id,
            w.user_id,
            w.company_id,
            pt.wallet_id,
            pt.transaction_type,
            pt.amount,
            pt.campaign_id,
            pt.related_entity_type,
            pt.related_entity_id,
            pt.description,
            'completed' AS status,
            NULL::uuid AS approved_by,
            NULL::uuid AS rejected_by,
            NULL::text AS rejection_reason,
            pt.created_by_user_id,
            pt.created_at,
            pt.updated_at,
            pt.completed_at,
            'campaign' AS transaction_category,
            NULL::numeric AS cash_amount,
            NULL::text AS payment_method,
            NULL::text AS bank_name,
            NULL::text AS account_number,
            NULL::text AS account_holder
        FROM public.point_transactions pt
        JOIN public.wallets w ON w.id = pt.wallet_id
        WHERE w.user_id = p_user_id
        
        UNION ALL
        
        -- 현금 거래
        SELECT 
            pt.id,
            w.user_id,
            w.company_id,
            pt.wallet_id,
            pt.transaction_type,
            pt.point_amount AS amount,
            NULL::uuid AS campaign_id,
            NULL::text AS related_entity_type,
            NULL::uuid AS related_entity_id,
            pt.description,
            pt.status,
            pt.approved_by,
            pt.rejected_by,
            pt.rejection_reason,
            pt.created_by_user_id,
            pt.created_at,
            pt.updated_at,
            pt.completed_at,
            'cash' AS transaction_category,
            pt.cash_amount,
            pt.payment_method,
            pt.bank_name,
            pt.account_number,
            pt.account_holder
        FROM public.cash_transactions pt
        JOIN public.wallets w ON w.id = pt.wallet_id
        WHERE w.user_id = p_user_id
    ),
    limited_transactions AS (
        SELECT *
        FROM sorted_transactions
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset
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
    FROM limited_transactions;
    
    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- 11. 통합 포인트 내역 조회 함수 업데이트: get_company_point_history_unified
CREATE OR REPLACE FUNCTION "public"."get_company_point_history_unified"("p_company_id" "uuid", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_result jsonb;
    v_user_id UUID;
BEGIN
    -- 권한 확인: 회사 멤버만 조회 가능
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM public.company_users
        WHERE company_id = p_company_id
        AND user_id = v_user_id
        AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'You do not have permission to view this company point history';
    END IF;
    
    WITH sorted_transactions AS (
        -- 캠페인 거래
        SELECT 
            pt.id,
            w.user_id,
            w.company_id,
            pt.wallet_id,
            pt.transaction_type,
            pt.amount,
            pt.campaign_id,
            pt.related_entity_type,
            pt.related_entity_id,
            pt.description,
            'completed' AS status,
            NULL::uuid AS approved_by,
            NULL::uuid AS rejected_by,
            NULL::text AS rejection_reason,
            pt.created_by_user_id,
            pt.created_at,
            pt.updated_at,
            pt.completed_at,
            'campaign' AS transaction_category,
            NULL::numeric AS cash_amount,
            NULL::text AS payment_method,
            NULL::text AS bank_name,
            NULL::text AS account_number,
            NULL::text AS account_holder
        FROM public.point_transactions pt
        JOIN public.wallets w ON w.id = pt.wallet_id
        WHERE w.company_id = p_company_id
        
        UNION ALL
        
        -- 현금 거래
        SELECT 
            pt.id,
            w.user_id,
            w.company_id,
            pt.wallet_id,
            pt.transaction_type,
            pt.point_amount AS amount,
            NULL::uuid AS campaign_id,
            NULL::text AS related_entity_type,
            NULL::uuid AS related_entity_id,
            pt.description,
            pt.status,
            pt.approved_by,
            pt.rejected_by,
            pt.rejection_reason,
            pt.created_by_user_id,
            pt.created_at,
            pt.updated_at,
            pt.completed_at,
            'cash' AS transaction_category,
            pt.cash_amount,
            pt.payment_method,
            pt.bank_name,
            pt.account_number,
            pt.account_holder
        FROM public.cash_transactions pt
        JOIN public.wallets w ON w.id = pt.wallet_id
        WHERE w.company_id = p_company_id
    ),
    limited_transactions AS (
        SELECT *
        FROM sorted_transactions
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset
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
    FROM limited_transactions;
    
    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

