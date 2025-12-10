-- Add RPC functions for manager request operations
-- 프론트엔드에서 직접 쿼리하는 대신 RPC 함수를 사용하도록 변경

-- 1. 매니저 등록 요청 상태 조회 RPC 함수
-- 기존 함수는 TABLE을 반환하지만, jsonb로 통일하기 위해 수정
-- 기존 함수를 삭제하고 새로 생성
DROP FUNCTION IF EXISTS "public"."get_pending_manager_request_safe"("p_user_id" "uuid");

CREATE OR REPLACE FUNCTION "public"."get_pending_manager_request_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_company_id UUID;
    v_result jsonb;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
    
    IF v_user_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- company_users 테이블에서 pending 또는 rejected 상태의 manager 역할 조회
    SELECT company_id INTO v_company_id
    FROM public.company_users
    WHERE user_id = v_user_id
      AND status IN ('pending', 'rejected')
      AND company_role = 'manager'
    LIMIT 1;

    IF v_company_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- 회사 정보 조회
    SELECT jsonb_build_object(
        'id', c.id,
        'business_name', c.business_name,
        'business_number', c.business_number,
        'address', c.address,
        'representative_name', c.representative_name,
        'business_type', c.business_type,
        'registration_file_url', c.registration_file_url,
        'auto_approve_reviewers', c.auto_approve_reviewers,
        'created_at', c.created_at,
        'updated_at', c.updated_at,
        'status', cu.status,
        'requested_at', cu.created_at
    )
    INTO v_result
    FROM public.companies c
    JOIN public.company_users cu ON cu.company_id = c.id
    WHERE c.id = v_company_id
      AND cu.user_id = v_user_id
      AND cu.status IN ('pending', 'rejected')
      AND cu.company_role = 'manager'
    LIMIT 1;

    RETURN v_result;
END;
$$;

COMMENT ON FUNCTION "public"."get_pending_manager_request_safe"("p_user_id" "uuid") IS '매니저 등록 요청 상태 조회 (pending 또는 rejected 상태)';

-- 2. 매니저 등록 요청 삭제 RPC 함수
-- 기존 함수는 jsonb를 반환하지만, void로 통일하기 위해 수정
-- 기존 함수를 삭제하고 새로 생성
DROP FUNCTION IF EXISTS "public"."cancel_manager_request_safe"("p_user_id" "uuid");

CREATE OR REPLACE FUNCTION "public"."cancel_manager_request_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_deleted_count INTEGER;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: Must be logged in';
    END IF;

    -- pending 상태의 manager 역할 삭제
    -- 사용자 본인의 요청만 삭제 가능 (RLS 정책으로 보호됨)
    DELETE FROM public.company_users
    WHERE user_id = v_user_id
      AND status = 'pending'
      AND company_role = 'manager';

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    IF v_deleted_count = 0 THEN
        RAISE EXCEPTION 'No pending manager request found';
    END IF;
END;
$$;

COMMENT ON FUNCTION "public"."cancel_manager_request_safe"("p_user_id" "uuid") IS '매니저 등록 요청 삭제 (pending 상태만)';

-- 3. 매니저 제거 RPC 함수
CREATE OR REPLACE FUNCTION "public"."remove_manager_safe"("p_company_id" "uuid", "p_manager_user_id" "uuid", "p_current_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_current_user_id UUID;
    v_deleted_count INTEGER;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_current_user_id := COALESCE(p_current_user_id, (SELECT auth.uid()));
    
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: Must be logged in';
    END IF;

    -- 권한 확인: owner만 매니저를 제거할 수 있음
    IF NOT EXISTS (
        SELECT 1
        FROM public.company_users cu
        WHERE cu.company_id = p_company_id
          AND cu.user_id = v_current_user_id
          AND cu.company_role = 'owner'
          AND cu.status = 'active'
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Only company owners can remove managers';
    END IF;

    -- 매니저 제거 (company_role = 'manager'인 경우만)
    DELETE FROM public.company_users
    WHERE company_id = p_company_id
      AND user_id = p_manager_user_id
      AND company_role = 'manager';

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    IF v_deleted_count = 0 THEN
        RAISE EXCEPTION 'Manager not found or already removed';
    END IF;
END;
$$;

COMMENT ON FUNCTION "public"."remove_manager_safe"("p_company_id" "uuid", "p_manager_user_id" "uuid", "p_current_user_id" "uuid") IS '매니저 제거 (owner만 가능)';

-- 권한 부여
GRANT ALL ON FUNCTION "public"."get_pending_manager_request_safe"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_pending_manager_request_safe"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_pending_manager_request_safe"("p_user_id" "uuid") TO "service_role";

GRANT ALL ON FUNCTION "public"."cancel_manager_request_safe"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."cancel_manager_request_safe"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_manager_request_safe"("p_user_id" "uuid") TO "service_role";

GRANT ALL ON FUNCTION "public"."remove_manager_safe"("p_company_id" "uuid", "p_manager_user_id" "uuid", "p_current_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."remove_manager_safe"("p_company_id" "uuid", "p_manager_user_id" "uuid", "p_current_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_manager_safe"("p_company_id" "uuid", "p_manager_user_id" "uuid", "p_current_user_id" "uuid") TO "service_role";

