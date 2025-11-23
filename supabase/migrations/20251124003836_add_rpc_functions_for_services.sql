-- 서비스 RLS 및 RPC 마이그레이션
-- Priority 1: 보안 및 데이터 무결성 강화

-- ============================================
-- 1. WalletService RPC 함수
-- ============================================

-- 회사 지갑 목록 조회
CREATE OR REPLACE FUNCTION "public"."get_company_wallets_safe"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_result jsonb;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- company_users를 통해 접근 가능한 회사 조회
    WITH company_access AS (
        SELECT cu.company_id, cu.company_role, cu.status
        FROM public.company_users cu
        WHERE cu.user_id = v_user_id
        AND cu.status = 'active'
        AND cu.company_role IN ('owner', 'manager')
    ),
    wallets_data AS (
        SELECT 
            w.id,
            w.company_id,
            w.current_points,
            w.withdraw_bank_name,
            w.withdraw_account_number,
            w.withdraw_account_holder,
            c.business_name AS company_name,
            c.business_number AS company_business_number,
            ca.company_role AS user_role,
            ca.status
        FROM public.wallets w
        INNER JOIN company_access ca ON ca.company_id = w.company_id
        LEFT JOIN public.companies c ON c.id = w.company_id
        WHERE w.company_id IS NOT NULL
        AND w.user_id IS NULL
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'wallet_id', id,
            'id', id,
            'company_id', company_id,
            'company_name', company_name,
            'current_points', current_points,
            'user_role', user_role,
            'status', status,
            'withdraw_bank_name', withdraw_bank_name,
            'withdraw_account_number', withdraw_account_number,
            'withdraw_account_holder', withdraw_account_holder
        )
    )
    INTO v_result
    FROM wallets_data;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- 특정 회사의 지갑 조회
CREATE OR REPLACE FUNCTION "public"."get_company_wallet_by_company_id_safe"("p_company_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_result jsonb;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 회사 접근 권한 확인
    IF NOT EXISTS (
        SELECT 1 FROM public.company_users
        WHERE company_id = p_company_id
        AND user_id = v_user_id
        AND status = 'active'
        AND company_role IN ('owner', 'manager')
    ) THEN
        RAISE EXCEPTION 'You do not have permission to view this company wallet';
    END IF;

    -- 지갑 조회
    SELECT jsonb_build_object(
        'wallet_id', w.id,
        'id', w.id,
        'company_id', w.company_id,
        'company_name', c.business_name,
        'current_points', w.current_points,
        'withdraw_bank_name', w.withdraw_bank_name,
        'withdraw_account_number', w.withdraw_account_number,
        'withdraw_account_holder', w.withdraw_account_holder
    )
    INTO v_result
    FROM public.wallets w
    LEFT JOIN public.companies c ON c.id = w.company_id
    WHERE w.company_id = p_company_id
    AND w.user_id IS NULL
    LIMIT 1;

    IF v_result IS NULL THEN
        RAISE EXCEPTION 'Company wallet not found';
    END IF;

    RETURN v_result;
END;
$$;

-- 개인 지갑 조회 (현재 사용자용)
CREATE OR REPLACE FUNCTION "public"."get_user_wallet_current_safe"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_result jsonb;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 지갑 조회
    SELECT jsonb_build_object(
        'wallet_id', id,
        'id', id,
        'user_id', user_id,
        'current_points', current_points,
        'withdraw_bank_name', withdraw_bank_name,
        'withdraw_account_number', withdraw_account_number,
        'withdraw_account_holder', withdraw_account_holder,
        'created_at', created_at,
        'updated_at', updated_at
    )
    INTO v_result
    FROM public.wallets
    WHERE user_id = v_user_id
    AND company_id IS NULL
    LIMIT 1;

    RETURN v_result;
END;
$$;

-- 개인 포인트 내역 조회 (point_transactions 테이블)
CREATE OR REPLACE FUNCTION "public"."get_user_point_history_safe"("p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_wallet_id UUID;
    v_result jsonb;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 지갑 조회
    SELECT id INTO v_wallet_id
    FROM public.wallets
    WHERE user_id = v_user_id
    AND company_id IS NULL
    LIMIT 1;

    IF v_wallet_id IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    -- 포인트 내역 조회
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', pt.id,
            'wallet_id', pt.wallet_id,
            'transaction_type', pt.transaction_type,
            'amount', pt.amount,
            'campaign_id', pt.campaign_id,
            'related_entity_type', pt.related_entity_type,
            'related_entity_id', pt.related_entity_id,
            'description', pt.description,
            'created_by_user_id', pt.created_by_user_id,
            'created_at', pt.created_at
        )
        ORDER BY pt.created_at DESC
    )
    INTO v_result
    FROM public.point_transactions pt
    WHERE pt.wallet_id = v_wallet_id
    ORDER BY pt.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ============================================
-- 2. CampaignApplicationService RPC 함수
-- ============================================

-- 캠페인 신청
CREATE OR REPLACE FUNCTION "public"."apply_to_campaign_safe"("p_campaign_id" "uuid", "p_application_message" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_campaign_status TEXT;
    v_log_id UUID;
    v_result jsonb;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 캠페인 상태 확인
    SELECT status INTO v_campaign_status
    FROM public.campaigns
    WHERE id = p_campaign_id
    FOR UPDATE;

    IF v_campaign_status IS NULL THEN
        RAISE EXCEPTION 'Campaign not found';
    END IF;

    IF v_campaign_status != 'active' THEN
        RAISE EXCEPTION 'Only active campaigns can be applied to';
    END IF;

    -- 이미 신청했는지 확인
    IF EXISTS (
        SELECT 1 FROM public.campaign_action_logs
        WHERE campaign_id = p_campaign_id
        AND user_id = v_user_id
    ) THEN
        RAISE EXCEPTION 'You have already applied to this campaign';
    END IF;

    -- 신청 처리
    INSERT INTO public.campaign_action_logs (
        campaign_id,
        user_id,
        action,
        application_message,
        status
    ) VALUES (
        p_campaign_id,
        v_user_id,
        jsonb_build_object('type', 'join'),
        p_application_message,
        'pending'
    )
    RETURNING id INTO v_log_id;

    -- 결과 반환
    SELECT jsonb_build_object(
        'id', v_log_id,
        'campaign_id', p_campaign_id,
        'user_id', v_user_id,
        'status', 'pending',
        'applied_at', NOW(),
        'application_message', p_application_message
    ) INTO v_result;

    RETURN v_result;
END;
$$;

-- 사용자의 캠페인 신청 내역 조회
CREATE OR REPLACE FUNCTION "public"."get_user_applications_safe"("p_status" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_result jsonb;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 신청 내역 조회
    WITH applications AS (
        SELECT 
            cal.id,
            cal.campaign_id,
            cal.user_id,
            cal.status,
            cal.created_at AS applied_at,
            cal.application_message,
            jsonb_build_object(
                'id', c.id,
                'title', c.title,
                'description', c.description,
                'product_image_url', c.product_image_url,
                'platform', c.platform,
                'product_price', c.product_price,
                'campaign_reward', c.campaign_reward,
                'start_date', c.start_date,
                'end_date', c.end_date,
                'max_participants', c.max_participants,
                'current_participants', c.current_participants,
                'status', c.status
            ) AS campaigns
        FROM public.campaign_action_logs cal
        INNER JOIN public.campaigns c ON c.id = cal.campaign_id
        WHERE cal.user_id = v_user_id
        AND (p_status IS NULL OR cal.status = p_status)
        ORDER BY cal.created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'campaign_id', campaign_id,
            'user_id', user_id,
            'status', status,
            'applied_at', applied_at,
            'application_message', application_message,
            'campaigns', campaigns
        )
    )
    INTO v_result
    FROM applications;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- 캠페인의 신청자 목록 조회 (광고주용)
CREATE OR REPLACE FUNCTION "public"."get_campaign_applications_safe"("p_campaign_id" "uuid", "p_status" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_campaign_user_id UUID;
    v_result jsonb;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 캠페인 소유자 확인
    SELECT user_id INTO v_campaign_user_id
    FROM public.campaigns
    WHERE id = p_campaign_id;

    IF v_campaign_user_id IS NULL THEN
        RAISE EXCEPTION 'Campaign not found';
    END IF;

    IF v_campaign_user_id != v_user_id THEN
        RAISE EXCEPTION 'You do not have permission to view applications for this campaign';
    END IF;

    -- 신청자 목록 조회
    WITH applications AS (
        SELECT 
            cal.id,
            cal.campaign_id,
            cal.user_id,
            cal.status,
            cal.created_at AS applied_at,
            cal.application_message,
            jsonb_build_object(
                'id', u.id,
                'display_name', u.display_name,
                'email', au.email,
                'review_count', u.review_count,
                'level', u.level
            ) AS users
        FROM public.campaign_action_logs cal
        INNER JOIN public.users u ON u.id = cal.user_id
        LEFT JOIN auth.users au ON au.id = u.id
        WHERE cal.campaign_id = p_campaign_id
        AND (p_status IS NULL OR cal.status = p_status)
        ORDER BY cal.created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'campaign_id', campaign_id,
            'user_id', user_id,
            'status', status,
            'applied_at', applied_at,
            'application_message', application_message,
            'users', users
        )
    )
    INTO v_result
    FROM applications;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- 신청 상태 업데이트 (광고주용)
CREATE OR REPLACE FUNCTION "public"."update_application_status_safe"("p_application_id" "uuid", "p_status" "text", "p_rejection_reason" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_campaign_user_id UUID;
    v_current_status TEXT;
    v_result jsonb;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 신청 정보 및 캠페인 소유자 확인
    SELECT c.user_id, cal.status
    INTO v_campaign_user_id, v_current_status
    FROM public.campaign_action_logs cal
    INNER JOIN public.campaigns c ON c.id = cal.campaign_id
    WHERE cal.id = p_application_id
    FOR UPDATE;

    IF v_campaign_user_id IS NULL THEN
        RAISE EXCEPTION 'Application not found';
    END IF;

    IF v_campaign_user_id != v_user_id THEN
        RAISE EXCEPTION 'You do not have permission to update this application';
    END IF;

    -- 상태 업데이트
    UPDATE public.campaign_action_logs
    SET 
        status = p_status,
        updated_at = NOW()
    WHERE id = p_application_id
    RETURNING to_jsonb(campaign_action_logs.*) INTO v_result;

    RETURN v_result;
END;
$$;

-- 신청 취소 (사용자용)
CREATE OR REPLACE FUNCTION "public"."cancel_application_safe"("p_application_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_application_user_id UUID;
    v_current_status TEXT;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 신청 정보 및 권한 확인
    SELECT user_id, status
    INTO v_application_user_id, v_current_status
    FROM public.campaign_action_logs
    WHERE id = p_application_id
    FOR UPDATE;

    IF v_application_user_id IS NULL THEN
        RAISE EXCEPTION 'Application not found';
    END IF;

    IF v_application_user_id != v_user_id THEN
        RAISE EXCEPTION 'You do not have permission to cancel this application';
    END IF;

    IF v_current_status != 'pending' THEN
        RAISE EXCEPTION 'Only pending applications can be cancelled';
    END IF;

    -- 신청 삭제
    DELETE FROM public.campaign_action_logs
    WHERE id = p_application_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================
-- 3. ReviewService RPC 함수
-- ============================================

-- 리뷰 작성
CREATE OR REPLACE FUNCTION "public"."create_review_safe"("p_campaign_id" "uuid", "p_title" "text", "p_content" "text", "p_rating" integer, "p_review_url" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_log_id UUID;
    v_log_status TEXT;
    v_result jsonb;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 캠페인 로그 조회 및 상태 확인
    SELECT id, status INTO v_log_id, v_log_status
    FROM public.campaign_action_logs
    WHERE campaign_id = p_campaign_id
    AND user_id = v_user_id
    FOR UPDATE;

    IF v_log_id IS NULL THEN
        RAISE EXCEPTION 'Campaign application not found';
    END IF;

    IF v_log_status != 'approved' THEN
        RAISE EXCEPTION 'Only approved campaigns can have reviews';
    END IF;

    -- 리뷰 제출 (상태 업데이트)
    -- action JSONB 필드에 리뷰 정보 저장
    UPDATE public.campaign_action_logs
    SET 
        status = 'completed',
        action = jsonb_build_object(
            'type', 'review_submit',
            'data', jsonb_build_object(
                'title', p_title,
                'content', p_content,
                'rating', p_rating,
                'review_url', COALESCE(p_review_url, ''),
                'submitted_at', NOW()::text
            )
        ),
        updated_at = NOW()
    WHERE id = v_log_id
    RETURNING to_jsonb(campaign_action_logs.*) INTO v_result;

    RETURN jsonb_build_object(
        'id', v_log_id,
        'campaign_id', p_campaign_id,
        'user_id', v_user_id,
        'title', p_title,
        'content', p_content,
        'rating', p_rating,
        'review_url', p_review_url,
        'status', 'completed',
        'submitted_at', NOW()
    );
END;
$$;

-- 사용자의 리뷰 목록 조회
CREATE OR REPLACE FUNCTION "public"."get_user_reviews_safe"("p_status" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_result jsonb;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 리뷰 목록 조회 (action JSONB에서 리뷰 정보 추출)
    WITH reviews AS (
        SELECT 
            cal.id,
            cal.campaign_id,
            cal.user_id,
            cal.action->'data'->>'title' AS title,
            cal.action->'data'->>'content' AS content,
            (cal.action->'data'->>'rating')::integer AS rating,
            cal.action->'data'->>'review_url' AS review_url,
            cal.status,
            cal.updated_at AS submitted_at,
            cal.updated_at AS approved_at,
            jsonb_build_object(
                'id', c.id,
                'title', c.title,
                'description', c.description,
                'product_image_url', c.product_image_url,
                'platform', c.platform,
                'product_price', c.product_price,
                'campaign_reward', c.campaign_reward
            ) AS campaigns
        FROM public.campaign_action_logs cal
        INNER JOIN public.campaigns c ON c.id = cal.campaign_id
        WHERE cal.user_id = v_user_id
        AND cal.action->>'type' = 'review_submit'
        AND (p_status IS NULL OR cal.status = p_status)
        ORDER BY cal.updated_at DESC, cal.created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'campaign_id', campaign_id,
            'user_id', user_id,
            'title', title,
            'content', content,
            'rating', rating,
            'review_url', review_url,
            'status', status,
            'submitted_at', submitted_at,
            'approved_at', approved_at,
            'campaigns', campaigns
        )
    )
    INTO v_result
    FROM reviews;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- 캠페인의 리뷰 목록 조회
CREATE OR REPLACE FUNCTION "public"."get_campaign_reviews_safe"("p_campaign_id" "uuid", "p_status" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_result jsonb;
BEGIN
    -- 리뷰 목록 조회 (공개 정보, action JSONB에서 리뷰 정보 추출)
    WITH reviews AS (
        SELECT 
            cal.id,
            cal.campaign_id,
            cal.user_id,
            cal.action->'data'->>'title' AS title,
            cal.action->'data'->>'content' AS content,
            (cal.action->'data'->>'rating')::integer AS rating,
            cal.action->'data'->>'review_url' AS review_url,
            cal.status,
            cal.updated_at AS submitted_at,
            cal.updated_at AS approved_at,
            jsonb_build_object(
                'id', u.id,
                'display_name', u.display_name,
                'level', u.level,
                'review_count', u.review_count
            ) AS users
        FROM public.campaign_action_logs cal
        INNER JOIN public.users u ON u.id = cal.user_id
        WHERE cal.campaign_id = p_campaign_id
        AND cal.action->>'type' = 'review_submit'
        AND (p_status IS NULL OR cal.status = p_status)
        ORDER BY cal.updated_at DESC, cal.created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'campaign_id', campaign_id,
            'user_id', user_id,
            'title', title,
            'content', content,
            'rating', rating,
            'review_url', review_url,
            'status', status,
            'submitted_at', submitted_at,
            'approved_at', approved_at,
            'users', users
        )
    )
    INTO v_result
    FROM reviews;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- 리뷰 상태 업데이트 (광고주용)
CREATE OR REPLACE FUNCTION "public"."update_review_status_safe"("p_review_id" "uuid", "p_status" "text", "p_rejection_reason" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_campaign_user_id UUID;
    v_result jsonb;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 리뷰 정보 및 캠페인 소유자 확인
    SELECT c.user_id
    INTO v_campaign_user_id
    FROM public.campaign_action_logs cal
    INNER JOIN public.campaigns c ON c.id = cal.campaign_id
    WHERE cal.id = p_review_id
    FOR UPDATE;

    IF v_campaign_user_id IS NULL THEN
        RAISE EXCEPTION 'Review not found';
    END IF;

    IF v_campaign_user_id != v_user_id THEN
        RAISE EXCEPTION 'You do not have permission to update this review';
    END IF;

    -- 상태 업데이트
    UPDATE public.campaign_action_logs
    SET 
        status = CASE 
            WHEN p_status = 'review_approved' THEN 'completed'
            ELSE status
        END,
        action = CASE 
            WHEN p_status = 'review_approved' THEN 
                jsonb_set(
                    action,
                    '{data,approved_at}',
                    to_jsonb(NOW()::text)
                )
            ELSE action
        END,
        updated_at = NOW()
    WHERE id = p_review_id
    RETURNING to_jsonb(campaign_action_logs.*) INTO v_result;

    RETURN v_result;
END;
$$;

-- 리뷰 수정
CREATE OR REPLACE FUNCTION "public"."update_review_safe"("p_review_id" "uuid", "p_title" "text", "p_content" "text", "p_rating" integer, "p_review_url" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_review_user_id UUID;
    v_current_status TEXT;
    v_result jsonb;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 리뷰 정보 및 권한 확인
    SELECT user_id, status
    INTO v_review_user_id, v_current_status
    FROM public.campaign_action_logs
    WHERE id = p_review_id
    FOR UPDATE;

    IF v_review_user_id IS NULL THEN
        RAISE EXCEPTION 'Review not found';
    END IF;

    IF v_review_user_id != v_user_id THEN
        RAISE EXCEPTION 'You do not have permission to update this review';
    END IF;

    IF v_current_status = 'completed' AND (action->'data'->>'approved_at') IS NOT NULL THEN
        RAISE EXCEPTION 'Approved reviews cannot be updated';
    END IF;

    -- 리뷰 업데이트 (action JSONB 필드 업데이트)
    UPDATE public.campaign_action_logs
    SET 
        action = jsonb_set(
            jsonb_set(
                jsonb_set(
                    jsonb_set(
                        action,
                        '{data,title}',
                        to_jsonb(p_title)
                    ),
                    '{data,content}',
                    to_jsonb(p_content)
                ),
                '{data,rating}',
                to_jsonb(p_rating)
            ),
            '{data,review_url}',
            to_jsonb(COALESCE(p_review_url, ''))
        ),
        updated_at = NOW()
    WHERE id = p_review_id
    RETURNING jsonb_build_object(
        'id', id,
        'title', action->'data'->>'title',
        'content', action->'data'->>'content',
        'rating', (action->'data'->>'rating')::integer,
        'review_url', action->'data'->>'review_url',
        'updated_at', updated_at
    ) INTO v_result;

    RETURN v_result;
END;
$$;

-- 리뷰 삭제
CREATE OR REPLACE FUNCTION "public"."delete_review_safe"("p_review_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_review_user_id UUID;
    v_current_status TEXT;
    v_previous_status TEXT;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 리뷰 정보 및 권한 확인
    SELECT user_id, status
    INTO v_review_user_id, v_current_status
    FROM public.campaign_action_logs
    WHERE id = p_review_id
    FOR UPDATE;

    IF v_review_user_id IS NULL THEN
        RAISE EXCEPTION 'Review not found';
    END IF;

    IF v_review_user_id != v_user_id THEN
        RAISE EXCEPTION 'You do not have permission to delete this review';
    END IF;

    IF v_current_status = 'completed' AND (action->'data'->>'approved_at') IS NOT NULL THEN
        RAISE EXCEPTION 'Approved reviews cannot be deleted';
    END IF;

    -- 이전 상태로 되돌리기 (action JSONB에서 리뷰 정보 제거)
    UPDATE public.campaign_action_logs
    SET 
        status = 'approved',
        action = jsonb_build_object('type', 'join'),
        updated_at = NOW()
    WHERE id = p_review_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================
-- 4. AdminService RPC 함수
-- ============================================

-- 관리자 전용: 사용자 목록 조회
CREATE OR REPLACE FUNCTION "public"."admin_get_users"("p_search_query" "text" DEFAULT NULL::"text", "p_user_type_filter" "text" DEFAULT NULL::"text", "p_status_filter" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_user_type TEXT;
    v_result jsonb;
BEGIN
    -- 권한 확인: 관리자만
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    SELECT user_type INTO v_user_type
    FROM public.users
    WHERE id = v_user_id;

    IF v_user_type NOT IN ('admin', 'ADMIN') THEN
        RAISE EXCEPTION 'Only admins can access this function';
    END IF;

    -- 사용자 목록 조회
    WITH users_data AS (
        SELECT 
            u.id,
            u.display_name,
            u.user_type,
            u.status,
            u.level,
            u.review_count,
            u.created_at,
            u.updated_at,
            au.email,
            jsonb_agg(
                DISTINCT jsonb_build_object(
                    'company_id', cu.company_id,
                    'company_role', cu.company_role,
                    'status', cu.status
                )
            ) FILTER (WHERE cu.company_id IS NOT NULL) AS company_users,
            jsonb_agg(
                DISTINCT jsonb_build_object(
                    'platform', sc.platform,
                    'connected_at', sc.connected_at
                )
            ) FILTER (WHERE sc.id IS NOT NULL) AS sns_connections
        FROM public.users u
        LEFT JOIN auth.users au ON au.id = u.id
        LEFT JOIN public.company_users cu ON cu.user_id = u.id AND cu.status = 'active'
        LEFT JOIN public.sns_connections sc ON sc.user_id = u.id
        WHERE (p_search_query IS NULL OR 
               u.display_name ILIKE '%' || p_search_query || '%' OR
               au.email ILIKE '%' || p_search_query || '%')
        AND (p_user_type_filter IS NULL OR u.user_type = p_user_type_filter)
        AND (p_status_filter IS NULL OR u.status = p_status_filter)
        GROUP BY u.id, u.display_name, u.user_type, u.status, u.level, u.review_count, u.created_at, u.updated_at, au.email
        ORDER BY u.created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'uid', id,
            'email', email,
            'display_name', display_name,
            'created_at', created_at,
            'updated_at', updated_at,
            'level', level,
            'review_count', review_count,
            'user_type', user_type,
            'status', status,
            'company_users', company_users,
            'sns_connections', sns_connections
        )
    )
    INTO v_result
    FROM users_data;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- 관리자 전용: 사용자 총 개수 조회
CREATE OR REPLACE FUNCTION "public"."admin_get_users_count"("p_search_query" "text" DEFAULT NULL::"text", "p_user_type_filter" "text" DEFAULT NULL::"text", "p_status_filter" "text" DEFAULT NULL::"text") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_user_type TEXT;
    v_count integer;
BEGIN
    -- 권한 확인: 관리자만
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    SELECT user_type INTO v_user_type
    FROM public.users
    WHERE id = v_user_id;

    IF v_user_type NOT IN ('admin', 'ADMIN') THEN
        RAISE EXCEPTION 'Only admins can access this function';
    END IF;

    -- 사용자 개수 조회
    SELECT COUNT(*)
    INTO v_count
    FROM public.users u
    LEFT JOIN auth.users au ON au.id = u.id
    WHERE (p_search_query IS NULL OR 
           u.display_name ILIKE '%' || p_search_query || '%' OR
           au.email ILIKE '%' || p_search_query || '%')
    AND (p_user_type_filter IS NULL OR u.user_type = p_user_type_filter)
    AND (p_status_filter IS NULL OR u.status = p_status_filter);

    RETURN v_count;
END;
$$;

-- 관리자 전용: 사용자 상태 변경
CREATE OR REPLACE FUNCTION "public"."admin_update_user_status"("p_target_user_id" "uuid", "p_status" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_user_type TEXT;
    v_result jsonb;
BEGIN
    -- 권한 확인: 관리자만
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    SELECT user_type INTO v_user_type
    FROM public.users
    WHERE id = v_user_id;

    IF v_user_type NOT IN ('admin', 'ADMIN') THEN
        RAISE EXCEPTION 'Only admins can update user status';
    END IF;

    -- 상태 업데이트
    UPDATE public.users
    SET 
        status = p_status,
        updated_at = NOW()
    WHERE id = p_target_user_id
    RETURNING to_jsonb(users.*) INTO v_result;

    IF v_result IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    RETURN v_result;
END;
$$;

-- ============================================
-- 5. AccountDeletionService RPC 함수
-- ============================================

-- 계정 삭제 가능 여부 확인
CREATE OR REPLACE FUNCTION "public"."check_deletion_eligibility_safe"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_user_type TEXT;
    v_company_id UUID;
    v_personal_points integer := 0;
    v_company_points integer := 0;
    v_active_campaigns integer := 0;
    v_other_owners_count integer := 0;
    v_has_deletion_request boolean := false;
    v_result jsonb;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 사용자 정보 조회
    SELECT user_type INTO v_user_type
    FROM public.users
    WHERE id = v_user_id;

    -- 회사 정보 조회
    SELECT company_id INTO v_company_id
    FROM public.company_users
    WHERE user_id = v_user_id
    AND status = 'active'
    LIMIT 1;

    -- 삭제 요청 상태 확인
    SELECT EXISTS(
        SELECT 1 FROM public.deleted_users
        WHERE deleted_users.user_id = v_user_id
    ) INTO v_has_deletion_request;

    -- 포인트 정보 조회
    SELECT COALESCE(SUM(current_points), 0)
    INTO v_personal_points
    FROM public.wallets
    WHERE user_id = v_user_id
    AND company_id IS NULL;

    IF v_company_id IS NOT NULL THEN
        SELECT COALESCE(SUM(current_points), 0)
        INTO v_company_points
        FROM public.wallets
        WHERE company_id = v_company_id
        AND user_id IS NULL;
    END IF;

    -- 활성 캠페인 조회
    SELECT COUNT(*)
    INTO v_active_campaigns
    FROM public.campaigns
    WHERE user_id = v_user_id
    AND status = 'active';

    -- 회사 오너 수 확인
    IF v_company_id IS NOT NULL THEN
        SELECT COUNT(*)
        INTO v_other_owners_count
        FROM public.company_users cu
        INNER JOIN public.users u ON u.id = cu.user_id
        WHERE cu.company_id = v_company_id
        AND cu.user_id != v_user_id
        AND cu.company_role = 'owner'
        AND cu.status = 'active'
        AND NOT EXISTS (
            SELECT 1 FROM public.deleted_users du
            WHERE du.user_id = cu.user_id
        );
    END IF;

    -- 결과 반환
    SELECT jsonb_build_object(
        'canDelete', true,
        'hasDeletionRequest', v_has_deletion_request,
        'userType', v_user_type,
        'companyId', v_company_id,
        'personalPoints', v_personal_points,
        'companyPoints', v_company_points,
        'activeCampaigns', v_active_campaigns,
        'otherOwnersCount', v_other_owners_count,
        'warnings', ARRAY[]::text[],
        'errors', ARRAY[]::text[]
    ) INTO v_result;

    RETURN v_result;
END;
$$;

-- 계정 삭제 전 사용자 데이터 백업
CREATE OR REPLACE FUNCTION "public"."backup_user_data_safe"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_result jsonb;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 사용자 데이터 백업
    WITH user_data AS (
        SELECT to_jsonb(u.*) AS user
        FROM public.users u
        WHERE u.id = v_user_id
    ),
    wallets_data AS (
        SELECT jsonb_agg(to_jsonb(w.*)) AS wallets
        FROM public.wallets w
        WHERE w.user_id = v_user_id
    ),
    campaigns_data AS (
        SELECT jsonb_agg(to_jsonb(c.*)) AS campaigns
        FROM public.campaigns c
        WHERE c.user_id = v_user_id
    ),
    campaign_logs_data AS (
        SELECT jsonb_agg(to_jsonb(cal.*)) AS campaign_logs
        FROM public.campaign_action_logs cal
        WHERE cal.user_id = v_user_id
    ),
    notifications_data AS (
        SELECT jsonb_agg(to_jsonb(n.*)) AS notifications
        FROM public.notifications n
        WHERE n.user_id = v_user_id
    )
    SELECT jsonb_build_object(
        'user', (SELECT user FROM user_data),
        'wallets', (SELECT wallets FROM wallets_data),
        'campaigns', (SELECT campaigns FROM campaigns_data),
        'campaignLogs', (SELECT campaign_logs FROM campaign_logs_data),
        'notifications', (SELECT notifications FROM notifications_data),
        'backupDate', NOW()
    ) INTO v_result;

    RETURN v_result;
END;
$$;

-- 계정 삭제 상태 확인
CREATE OR REPLACE FUNCTION "public"."is_account_deleted_safe"() RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_deleted boolean;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN false;
    END IF;

    -- 삭제 상태 확인
    SELECT EXISTS(
        SELECT 1 FROM public.deleted_users
        WHERE deleted_users.user_id = v_user_id
    ) INTO v_deleted;

    RETURN v_deleted;
END;
$$;

-- 삭제 요청 상태 확인
CREATE OR REPLACE FUNCTION "public"."has_deletion_request_safe"() RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_has_request boolean;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN false;
    END IF;

    -- 삭제 요청 상태 확인
    SELECT EXISTS(
        SELECT 1 FROM public.deleted_users
        WHERE deleted_users.user_id = v_user_id
    ) INTO v_has_request;

    RETURN v_has_request;
END;
$$;

-- 계정 삭제 요청 취소
CREATE OR REPLACE FUNCTION "public"."cancel_deletion_request_safe"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 삭제 요청 취소
    DELETE FROM public.deleted_users
    WHERE deleted_users.user_id = v_user_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================
-- 6. CompanyUserService RPC 함수
-- ============================================

-- 광고주로 전환할 수 있는 권한 확인
CREATE OR REPLACE FUNCTION "public"."can_convert_to_advertiser_safe"() RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_has_permission boolean;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN false;
    END IF;

    -- 회사 역할 확인
    SELECT EXISTS(
        SELECT 1 FROM public.company_users
        WHERE user_id = v_user_id
        AND status = 'active'
        AND company_role IN ('owner', 'manager')
    ) INTO v_has_permission;

    RETURN v_has_permission;
END;
$$;

-- 사용자의 회사 역할 조회
CREATE OR REPLACE FUNCTION "public"."get_user_company_role_safe"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_role TEXT;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- 회사 역할 조회
    SELECT company_role INTO v_role
    FROM public.company_users
    WHERE user_id = v_user_id
    AND status = 'active'
    LIMIT 1;

    RETURN v_role;
END;
$$;

-- 사용자가 회사에 속해있는지 확인
CREATE OR REPLACE FUNCTION "public"."is_user_in_company_safe"() RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_in_company boolean;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN false;
    END IF;

    -- 회사 소속 확인
    SELECT EXISTS(
        SELECT 1 FROM public.company_users
        WHERE user_id = v_user_id
        AND status = 'active'
    ) INTO v_in_company;

    RETURN v_in_company;
END;
$$;

-- 사용자의 회사 ID 조회
CREATE OR REPLACE FUNCTION "public"."get_user_company_id_safe"() RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_company_id UUID;
BEGIN
    -- 권한 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- 회사 ID 조회
    SELECT company_id INTO v_company_id
    FROM public.company_users
    WHERE user_id = v_user_id
    AND status = 'active'
    LIMIT 1;

    RETURN v_company_id;
END;
$$;

-- 권한 부여
GRANT ALL ON FUNCTION "public"."get_company_wallets_safe"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_company_wallets_safe"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_company_wallets_safe"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_company_wallet_by_company_id_safe"("p_company_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_company_wallet_by_company_id_safe"("p_company_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_company_wallet_by_company_id_safe"("p_company_id" "uuid") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_user_wallet_current_safe"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_wallet_current_safe"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_wallet_current_safe"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_user_point_history_safe"("p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_point_history_safe"("p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_point_history_safe"("p_limit" integer, "p_offset" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."apply_to_campaign_safe"("p_campaign_id" "uuid", "p_application_message" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."apply_to_campaign_safe"("p_campaign_id" "uuid", "p_application_message" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."apply_to_campaign_safe"("p_campaign_id" "uuid", "p_application_message" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_user_applications_safe"("p_status" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_applications_safe"("p_status" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_applications_safe"("p_status" "text", "p_limit" integer, "p_offset" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_campaign_applications_safe"("p_campaign_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_campaign_applications_safe"("p_campaign_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_campaign_applications_safe"("p_campaign_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."update_application_status_safe"("p_application_id" "uuid", "p_status" "text", "p_rejection_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_application_status_safe"("p_application_id" "uuid", "p_status" "text", "p_rejection_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_application_status_safe"("p_application_id" "uuid", "p_status" "text", "p_rejection_reason" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."cancel_application_safe"("p_application_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."cancel_application_safe"("p_application_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_application_safe"("p_application_id" "uuid") TO "service_role";

GRANT ALL ON FUNCTION "public"."create_review_safe"("p_campaign_id" "uuid", "p_title" "text", "p_content" "text", "p_rating" integer, "p_review_url" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_review_safe"("p_campaign_id" "uuid", "p_title" "text", "p_content" "text", "p_rating" integer, "p_review_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_review_safe"("p_campaign_id" "uuid", "p_title" "text", "p_content" "text", "p_rating" integer, "p_review_url" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_user_reviews_safe"("p_status" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_reviews_safe"("p_status" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_reviews_safe"("p_status" "text", "p_limit" integer, "p_offset" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_campaign_reviews_safe"("p_campaign_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_campaign_reviews_safe"("p_campaign_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_campaign_reviews_safe"("p_campaign_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."update_review_status_safe"("p_review_id" "uuid", "p_status" "text", "p_rejection_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_review_status_safe"("p_review_id" "uuid", "p_status" "text", "p_rejection_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_review_status_safe"("p_review_id" "uuid", "p_status" "text", "p_rejection_reason" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."update_review_safe"("p_review_id" "uuid", "p_title" "text", "p_content" "text", "p_rating" integer, "p_review_url" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_review_safe"("p_review_id" "uuid", "p_title" "text", "p_content" "text", "p_rating" integer, "p_review_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_review_safe"("p_review_id" "uuid", "p_title" "text", "p_content" "text", "p_rating" integer, "p_review_url" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."delete_review_safe"("p_review_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_review_safe"("p_review_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_review_safe"("p_review_id" "uuid") TO "service_role";

GRANT ALL ON FUNCTION "public"."admin_get_users"("p_search_query" "text", "p_user_type_filter" "text", "p_status_filter" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."admin_get_users"("p_search_query" "text", "p_user_type_filter" "text", "p_status_filter" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_get_users"("p_search_query" "text", "p_user_type_filter" "text", "p_status_filter" "text", "p_limit" integer, "p_offset" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."admin_get_users_count"("p_search_query" "text", "p_user_type_filter" "text", "p_status_filter" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_get_users_count"("p_search_query" "text", "p_user_type_filter" "text", "p_status_filter" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_get_users_count"("p_search_query" "text", "p_user_type_filter" "text", "p_status_filter" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."admin_update_user_status"("p_target_user_id" "uuid", "p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_update_user_status"("p_target_user_id" "uuid", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_update_user_status"("p_target_user_id" "uuid", "p_status" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."check_deletion_eligibility_safe"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_deletion_eligibility_safe"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_deletion_eligibility_safe"() TO "service_role";

GRANT ALL ON FUNCTION "public"."backup_user_data_safe"() TO "anon";
GRANT ALL ON FUNCTION "public"."backup_user_data_safe"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."backup_user_data_safe"() TO "service_role";

GRANT ALL ON FUNCTION "public"."is_account_deleted_safe"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_account_deleted_safe"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_account_deleted_safe"() TO "service_role";

GRANT ALL ON FUNCTION "public"."has_deletion_request_safe"() TO "anon";
GRANT ALL ON FUNCTION "public"."has_deletion_request_safe"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."has_deletion_request_safe"() TO "service_role";

GRANT ALL ON FUNCTION "public"."cancel_deletion_request_safe"() TO "anon";
GRANT ALL ON FUNCTION "public"."cancel_deletion_request_safe"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_deletion_request_safe"() TO "service_role";

GRANT ALL ON FUNCTION "public"."can_convert_to_advertiser_safe"() TO "anon";
GRANT ALL ON FUNCTION "public"."can_convert_to_advertiser_safe"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_convert_to_advertiser_safe"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_user_company_role_safe"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_company_role_safe"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_company_role_safe"() TO "service_role";

GRANT ALL ON FUNCTION "public"."is_user_in_company_safe"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_user_in_company_safe"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_user_in_company_safe"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_user_company_id_safe"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_company_id_safe"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_company_id_safe"() TO "service_role";

