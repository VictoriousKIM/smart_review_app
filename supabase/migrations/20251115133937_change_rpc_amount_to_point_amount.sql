-- RPC 함수에서 amount를 point_amount로 변경하여 DB 스키마와 일관성 유지

-- 1. get_company_point_history_unified 함수 수정
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
            NULL::integer AS point_amount,
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
            NULL::integer AS amount,
            pt.point_amount,
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
            NULL::timestamp with time zone AS completed_at,
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
            'point_amount', COALESCE(point_amount, amount),
            'amount', COALESCE(point_amount, amount), -- 하위 호환성을 위해 유지
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

-- 2. get_pending_cash_transactions 함수 수정
CREATE OR REPLACE FUNCTION "public"."get_pending_cash_transactions"("p_status" "text" DEFAULT 'pending'::"text", "p_transaction_type" "text" DEFAULT NULL::"text", "p_user_type" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_result JSONB;
    v_user_id UUID;
    v_user_type TEXT;
BEGIN
    -- 권한 확인: 관리자만 조회 가능
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 사용자 타입 확인
    SELECT user_type INTO v_user_type
    FROM public.users
    WHERE id = v_user_id;
    
    IF v_user_type != 'admin' THEN
        RAISE EXCEPTION 'Unauthorized: Only admins can view pending cash transactions';
    END IF;
    
    -- 상태 유효성 검사
    IF p_status IS NOT NULL AND p_status NOT IN ('pending', 'approved', 'rejected', 'cancelled') THEN
        RAISE EXCEPTION 'Invalid status. Must be one of: pending, approved, rejected, cancelled';
    END IF;
    
    -- 거래 타입 유효성 검사
    IF p_transaction_type IS NOT NULL AND p_transaction_type NOT IN ('deposit', 'withdraw') THEN
        RAISE EXCEPTION 'Invalid transaction_type. Must be deposit or withdraw';
    END IF;
    
    -- 사용자 타입 유효성 검사
    IF p_user_type IS NOT NULL AND p_user_type NOT IN ('advertiser', 'reviewer') THEN
        RAISE EXCEPTION 'Invalid user_type. Must be advertiser or reviewer';
    END IF;
    
    -- 거래 목록 조회
    WITH filtered_transactions AS (
        SELECT 
            ct.id,
            ct.wallet_id,
            ct.transaction_type,
            ct.point_amount,
            ct.cash_amount,
            ct.payment_method,
            ct.bank_name,
            ct.account_number,
            ct.account_holder,
            ct.status,
            ct.description,
            ct.approved_by,
            ct.rejected_by,
            ct.rejection_reason,
            ct.created_by_user_id,
            ct.created_at,
            ct.updated_at,
            w.user_id,
            w.company_id,
            u.display_name AS user_name,
            au.email AS user_email,
            NULL::text AS user_phone,
            c.business_name AS company_name,
            c.business_number AS company_business_number
        FROM public.cash_transactions ct
        JOIN public.wallets w ON w.id = ct.wallet_id
        LEFT JOIN public.users u ON u.id = w.user_id
        LEFT JOIN auth.users au ON au.id = w.user_id
        LEFT JOIN public.companies c ON c.id = w.company_id
        WHERE 
            (p_status IS NULL OR ct.status = p_status)
            AND (p_transaction_type IS NULL OR ct.transaction_type = p_transaction_type)
            AND (
                p_user_type IS NULL 
                OR (p_user_type = 'advertiser' AND w.company_id IS NOT NULL)
                OR (p_user_type = 'reviewer' AND w.company_id IS NULL)
            )
    ),
    limited_transactions AS (
        SELECT *
        FROM filtered_transactions
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'wallet_id', wallet_id,
            'transaction_type', transaction_type,
            'point_amount', point_amount,
            'amount', point_amount, -- 하위 호환성을 위해 유지
            'cash_amount', cash_amount,
            'payment_method', payment_method,
            'bank_name', bank_name,
            'account_number', account_number,
            'account_holder', account_holder,
            'status', status,
            'description', description,
            'approved_by', approved_by,
            'rejected_by', rejected_by,
            'rejection_reason', rejection_reason,
            'created_by_user_id', created_by_user_id,
            'created_at', created_at,
            'updated_at', updated_at,
            'user_id', user_id,
            'company_id', company_id,
            'user_name', user_name,
            'user_email', user_email,
            'user_phone', user_phone,
            'company_name', company_name,
            'company_business_number', company_business_number,
            'user_type', CASE 
                WHEN company_id IS NOT NULL THEN 'advertiser'
                ELSE 'reviewer'
            END
        )
    )
    INTO v_result
    FROM limited_transactions;
    
    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- 3. get_user_point_history_unified 함수 수정
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
            NULL::integer AS point_amount,
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
            NULL::integer AS amount,
            pt.point_amount,
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
            NULL::timestamp with time zone AS completed_at,
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
            'point_amount', COALESCE(point_amount, amount),
            'amount', COALESCE(point_amount, amount), -- 하위 호환성을 위해 유지
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

