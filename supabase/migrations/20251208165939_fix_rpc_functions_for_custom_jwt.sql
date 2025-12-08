-- Custom JWT 세션 지원을 위한 RPC 함수 수정
-- 주요 함수들에 p_user_id 파라미터 추가

-- 1. apply_to_campaign_safe - 캠페인 신청
DROP FUNCTION IF EXISTS "public"."apply_to_campaign_safe"("p_campaign_id" "uuid", "p_application_message" "text");

CREATE OR REPLACE FUNCTION "public"."apply_to_campaign_safe"(
  "p_campaign_id" "uuid",
  "p_application_message" "text" DEFAULT NULL::"text",
  "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_campaign_status TEXT;
    v_log_id UUID;
    v_result jsonb;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
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

ALTER FUNCTION "public"."apply_to_campaign_safe"("p_campaign_id" "uuid", "p_application_message" "text", "p_user_id" "uuid") OWNER TO "postgres";

-- 2. cancel_application_safe - 신청 취소
DROP FUNCTION IF EXISTS "public"."cancel_application_safe"("p_application_id" "uuid");

CREATE OR REPLACE FUNCTION "public"."cancel_application_safe"(
  "p_application_id" "uuid",
  "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_application_user_id UUID;
    v_current_status TEXT;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
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

ALTER FUNCTION "public"."cancel_application_safe"("p_application_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";

-- 3. create_review_safe - 리뷰 작성
DROP FUNCTION IF EXISTS "public"."create_review_safe"("p_campaign_id" "uuid", "p_title" "text", "p_content" "text", "p_rating" integer, "p_review_url" "text");

CREATE OR REPLACE FUNCTION "public"."create_review_safe"(
  "p_campaign_id" "uuid",
  "p_title" "text",
  "p_content" "text",
  "p_rating" integer,
  "p_review_url" "text" DEFAULT NULL::"text",
  "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_log_id UUID;
    v_log_status TEXT;
    v_result jsonb;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
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

ALTER FUNCTION "public"."create_review_safe"("p_campaign_id" "uuid", "p_title" "text", "p_content" "text", "p_rating" integer, "p_review_url" "text", "p_user_id" "uuid") OWNER TO "postgres";

-- 4. delete_review_safe - 리뷰 삭제
DROP FUNCTION IF EXISTS "public"."delete_review_safe"("p_review_id" "uuid");

CREATE OR REPLACE FUNCTION "public"."delete_review_safe"(
  "p_review_id" "uuid",
  "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_review_user_id UUID;
    v_current_status TEXT;
    v_previous_status TEXT;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
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

ALTER FUNCTION "public"."delete_review_safe"("p_review_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";

-- 5. get_campaign_applications_safe - 캠페인 신청 목록 조회 (권한 체크용)
DROP FUNCTION IF EXISTS "public"."get_campaign_applications_safe"("p_campaign_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer);

CREATE OR REPLACE FUNCTION "public"."get_campaign_applications_safe"(
  "p_campaign_id" "uuid",
  "p_status" "text" DEFAULT NULL::"text",
  "p_limit" integer DEFAULT 20,
  "p_offset" integer DEFAULT 0,
  "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_campaign_user_id UUID;
    v_result jsonb;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
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

    -- Custom JWT 세션인 경우 (p_user_id가 전달되고 auth.uid()가 NULL) 권한 체크 건너뛰기
    -- 일반 세션인 경우에만 권한 체크
    IF p_user_id IS NULL AND v_campaign_user_id != v_user_id THEN
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

ALTER FUNCTION "public"."get_campaign_applications_safe"("p_campaign_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer, "p_user_id" "uuid") OWNER TO "postgres";

-- 6. delete_campaign - 캠페인 삭제
DROP FUNCTION IF EXISTS "public"."delete_campaign"("p_campaign_id" "uuid");

CREATE OR REPLACE FUNCTION "public"."delete_campaign"(
  "p_campaign_id" "uuid",
  "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_user_id UUID;
  v_company_id UUID;
  v_user_role TEXT;
  v_campaign_company_id UUID;
  v_campaign_status TEXT;
  v_campaign_user_id UUID;
  v_campaign_title TEXT;
  v_current_participants INTEGER;
  v_total_cost INTEGER;
  v_wallet_id UUID;
  v_current_points INTEGER;
  v_refund_amount INTEGER;
  v_rows_affected INTEGER;
BEGIN
  -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
  v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 2. 사용자의 회사 ID 및 역할 조회
  SELECT cu.company_id, cu.company_role INTO v_company_id, v_user_role
  FROM public.company_users cu
  WHERE cu.user_id = v_user_id
    AND cu.status = 'active'
    AND cu.company_role IN ('owner', 'manager')
  LIMIT 1;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION '회사에 소속되지 않았거나 권한이 없습니다';
  END IF;

  -- 3. 캠페인 정보 조회 (소유권, 상태, 참여자 수, 총 비용, 생성자, 제목)
  SELECT company_id, status, current_participants, total_cost, user_id, title
  INTO v_campaign_company_id, v_campaign_status, v_current_participants, v_total_cost, v_campaign_user_id, v_campaign_title
  FROM public.campaigns
  WHERE id = p_campaign_id
  FOR UPDATE; -- 행 잠금으로 동시성 제어

  IF v_campaign_company_id IS NULL THEN
    RAISE EXCEPTION '캠페인을 찾을 수 없습니다';
  END IF;

  IF v_campaign_company_id != v_company_id THEN
    RAISE EXCEPTION '이 캠페인을 삭제할 권한이 없습니다';
  END IF;

  -- 4. 캠페인 상태 확인 (진행 중인 캠페인은 삭제 불가)
  IF v_campaign_status = 'active' AND v_current_participants > 0 THEN
    RAISE EXCEPTION '참여자가 있는 활성 캠페인은 삭제할 수 없습니다. 먼저 캠페인을 종료해주세요.';
  END IF;

  -- 5. 회사 지갑 조회 및 포인트 확인
  SELECT id, current_points INTO v_wallet_id, v_current_points
  FROM public.wallets
  WHERE company_id = v_company_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION '회사 지갑을 찾을 수 없습니다';
  END IF;

  -- 6. 환불 금액 계산 (총 비용 - 사용된 비용)
  -- 참여자가 없으면 전체 환불, 있으면 부분 환불
  IF v_current_participants = 0 THEN
    v_refund_amount := v_total_cost;
  ELSE
    -- 참여자당 비용 계산 (총 비용 / 최대 참여자 수)
    v_refund_amount := v_total_cost - ((v_total_cost / GREATEST((SELECT max_participants FROM public.campaigns WHERE id = p_campaign_id), 1)) * v_current_participants);
  END IF;

  -- 7. 캠페인 삭제
  DELETE FROM public.campaigns
  WHERE id = p_campaign_id;
  
  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
  
  IF v_rows_affected = 0 THEN
    RAISE EXCEPTION '캠페인 삭제에 실패했습니다';
  END IF;

  -- 8. 환불 처리 (환불 금액이 0보다 큰 경우에만)
  IF v_refund_amount > 0 THEN
    -- 포인트 트랜잭션 생성 (충전)
    INSERT INTO public.point_transactions (
      wallet_id,
      transaction_type,
      amount,
      description,
      related_entity_type,
      related_entity_id,
      created_by_user_id
    ) VALUES (
      v_wallet_id,
      'charge',
      v_refund_amount,
      '캠페인 삭제 환불: ' || v_campaign_title,
      'campaign',
      p_campaign_id,
      v_user_id
    );

    -- 지갑 포인트 업데이트
    UPDATE public.wallets
    SET current_points = current_points + v_refund_amount,
        updated_at = NOW()
    WHERE id = v_wallet_id;
  END IF;

  -- 9. 결과 반환
  RETURN jsonb_build_object(
    'success', true,
    'campaign_id', p_campaign_id,
    'refund_amount', v_refund_amount,
    'message', '캠페인이 삭제되었습니다' || CASE WHEN v_refund_amount > 0 THEN '. 환불 금액: ' || v_refund_amount || 'P' ELSE '' END
  );
END;
$$;

ALTER FUNCTION "public"."delete_campaign"("p_campaign_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";

-- 7. join_campaign_safe - 캠페인 참여
DROP FUNCTION IF EXISTS "public"."join_campaign_safe"("p_campaign_id" "uuid", "p_application_message" "text");

CREATE OR REPLACE FUNCTION "public"."join_campaign_safe"(
  "p_campaign_id" "uuid",
  "p_application_message" "text" DEFAULT NULL::"text",
  "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid;
    v_campaign jsonb;
    v_log_id uuid;
    v_result jsonb;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 캠페인 정보 조회
    SELECT to_jsonb(campaigns.*) INTO v_campaign
    FROM public.campaigns 
    WHERE id = p_campaign_id AND status = 'active';
    
    IF v_campaign IS NULL THEN
        RAISE EXCEPTION 'Campaign not found or not active';
    END IF;
    
    -- 중복 신청 확인
    IF EXISTS (
        SELECT 1 FROM public.campaign_logs 
        WHERE campaign_id = p_campaign_id AND user_id = v_user_id
    ) THEN
        RAISE EXCEPTION 'Already applied to this campaign';
    END IF;
    
    -- 최대 참여자 수 확인
    IF (v_campaign->>'current_participants')::integer >= (v_campaign->>'max_participants')::integer THEN
        RAISE EXCEPTION 'Campaign is full';
    END IF;
    
    -- 캠페인 로그 생성
    INSERT INTO public.campaign_logs (
        campaign_id, user_id, action, application_message, status
    ) VALUES (
        p_campaign_id, v_user_id, 'join', p_application_message, 'pending'
    ) RETURNING id INTO v_log_id;
    
    -- 캠페인 참여자 수 증가
    UPDATE public.campaigns 
    SET current_participants = current_participants + 1,
        updated_at = NOW()
    WHERE id = p_campaign_id;
    
    -- 결과 반환
    SELECT jsonb_build_object(
        'success', true,
        'log_id', v_log_id,
        'campaign', v_campaign
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

ALTER FUNCTION "public"."join_campaign_safe"("p_campaign_id" "uuid", "p_application_message" "text", "p_user_id" "uuid") OWNER TO "postgres";

-- 8. leave_campaign_safe - 캠페인 참여 취소
DROP FUNCTION IF EXISTS "public"."leave_campaign_safe"("p_campaign_id" "uuid");

CREATE OR REPLACE FUNCTION "public"."leave_campaign_safe"(
  "p_campaign_id" "uuid",
  "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid;
    v_log_id uuid;
    v_result jsonb;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 기존 신청 확인
    SELECT id INTO v_log_id
    FROM public.campaign_logs 
    WHERE campaign_id = p_campaign_id AND user_id = v_user_id;
    
    IF v_log_id IS NULL THEN
        RAISE EXCEPTION 'No application found for this campaign';
    END IF;
    
    -- 캠페인 로그 업데이트
    UPDATE public.campaign_logs 
    SET action = 'leave', status = 'cancelled', updated_at = NOW()
    WHERE id = v_log_id;
    
    -- 캠페인 참여자 수 감소
    UPDATE public.campaigns 
    SET current_participants = GREATEST(current_participants - 1, 0),
        updated_at = NOW()
    WHERE id = p_campaign_id;
    
    -- 결과 반환
    SELECT jsonb_build_object(
        'success', true,
        'log_id', v_log_id
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

ALTER FUNCTION "public"."leave_campaign_safe"("p_campaign_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";

-- 9. update_review_safe - 리뷰 수정
DROP FUNCTION IF EXISTS "public"."update_review_safe"("p_review_id" "uuid", "p_title" "text", "p_content" "text", "p_rating" integer, "p_review_url" "text");

CREATE OR REPLACE FUNCTION "public"."update_review_safe"(
  "p_review_id" "uuid",
  "p_title" "text",
  "p_content" "text",
  "p_rating" integer,
  "p_review_url" "text" DEFAULT NULL::"text",
  "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_review_user_id UUID;
    v_current_status TEXT;
    v_result jsonb;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
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
        'status', status,
        'updated_at', updated_at
    ) INTO v_result;

    RETURN v_result;
END;
$$;

ALTER FUNCTION "public"."update_review_safe"("p_review_id" "uuid", "p_title" "text", "p_content" "text", "p_rating" integer, "p_review_url" "text", "p_user_id" "uuid") OWNER TO "postgres";

-- 10. update_review_status_safe - 리뷰 상태 업데이트 (권한 체크용)
DROP FUNCTION IF EXISTS "public"."update_review_status_safe"("p_review_id" "uuid", "p_status" "text", "p_rejection_reason" "text");

CREATE OR REPLACE FUNCTION "public"."update_review_status_safe"(
  "p_review_id" "uuid",
  "p_status" "text",
  "p_rejection_reason" "text" DEFAULT NULL::"text",
  "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_campaign_user_id UUID;
    v_result jsonb;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
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

    -- Custom JWT 세션인 경우 (p_user_id가 전달되고 auth.uid()가 NULL) 권한 체크 건너뛰기
    -- 일반 세션인 경우에만 권한 체크
    IF p_user_id IS NULL AND v_campaign_user_id != v_user_id THEN
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

ALTER FUNCTION "public"."update_review_status_safe"("p_review_id" "uuid", "p_status" "text", "p_rejection_reason" "text", "p_user_id" "uuid") OWNER TO "postgres";

