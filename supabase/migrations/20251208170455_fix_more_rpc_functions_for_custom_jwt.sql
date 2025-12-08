-- Custom JWT 세션 지원을 위한 추가 RPC 함수 수정

-- 1. update_application_status_safe - 신청 상태 업데이트
DROP FUNCTION IF EXISTS "public"."update_application_status_safe"("p_application_id" "uuid", "p_status" "text", "p_rejection_reason" "text");

CREATE OR REPLACE FUNCTION "public"."update_application_status_safe"(
  "p_application_id" "uuid",
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
    v_current_status TEXT;
    v_result jsonb;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
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

    -- Custom JWT 세션인 경우 (p_user_id가 전달되고 auth.uid()가 NULL) 권한 체크 건너뛰기
    -- 일반 세션인 경우에만 권한 체크
    IF p_user_id IS NULL AND v_campaign_user_id != v_user_id THEN
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

ALTER FUNCTION "public"."update_application_status_safe"("p_application_id" "uuid", "p_status" "text", "p_rejection_reason" "text", "p_user_id" "uuid") OWNER TO "postgres";

-- 2. get_company_managers - 회사 매니저 목록 조회
DROP FUNCTION IF EXISTS "public"."get_company_managers"("p_company_id" "uuid");

CREATE OR REPLACE FUNCTION "public"."get_company_managers"(
  "p_company_id" "uuid",
  "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS TABLE("company_id" "uuid", "user_id" "uuid", "status" "text", "created_at" timestamp with time zone, "email" character varying, "display_name" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
  v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
  
  -- Custom JWT 세션인 경우 (p_user_id가 전달되고 auth.uid()가 NULL) 권한 체크 건너뛰기
  -- 일반 세션인 경우에만 권한 체크
  IF p_user_id IS NULL THEN
    -- 권한 확인: 회사 소유자 또는 관리자만 조회 가능
    IF NOT EXISTS (
      SELECT 1 FROM public.company_users cu
      WHERE cu.company_id = p_company_id
        AND cu.user_id = v_user_id
        AND cu.company_role IN ('owner', 'manager')
        AND cu.status = 'active'
    ) THEN
      RAISE EXCEPTION 'Unauthorized: Only company owners and managers can view manager list';
    END IF;
  END IF;

  -- 매니저 목록 조회 (auth.users의 email 포함)
  RETURN QUERY
  SELECT 
    cu.company_id,
    cu.user_id,
    cu.status,
    cu.created_at,
    au.email,
    COALESCE(u.display_name, '이름 없음')::text as display_name
  FROM public.company_users cu
  LEFT JOIN public.users u ON u.id = cu.user_id
  LEFT JOIN auth.users au ON au.id = cu.user_id
  WHERE cu.company_id = p_company_id
    AND cu.company_role = 'manager'
    AND cu.status IN ('pending', 'active')
  ORDER BY 
    CASE cu.status
      WHEN 'pending' THEN 1
      WHEN 'active' THEN 2
      ELSE 3
    END,
    cu.created_at DESC;
END;
$$;

ALTER FUNCTION "public"."get_company_managers"("p_company_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";

-- 3. approve_manager - 매니저 승인
DROP FUNCTION IF EXISTS "public"."approve_manager"("p_company_id" "uuid", "p_user_id" "uuid");

CREATE OR REPLACE FUNCTION "public"."approve_manager"(
  "p_company_id" "uuid",
  "p_user_id" "uuid",
  "p_current_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_current_user_id uuid;
  v_result jsonb;
BEGIN
  -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
  v_current_user_id := COALESCE(p_current_user_id, (SELECT auth.uid()));
  
  -- Custom JWT 세션인 경우 (p_current_user_id가 전달되고 auth.uid()가 NULL) 권한 체크 건너뛰기
  -- 일반 세션인 경우에만 권한 체크
  IF p_current_user_id IS NULL THEN
    -- 권한 확인: 회사 소유자 또는 활성 매니저만 승인 가능
    IF NOT EXISTS (
      SELECT 1 FROM public.company_users cu
      WHERE cu.company_id = p_company_id
        AND cu.user_id = v_current_user_id
        AND cu.company_role IN ('owner', 'manager')
        AND cu.status = 'active'
    ) THEN
      RAISE EXCEPTION 'Unauthorized: Only company owners and active managers can approve managers';
    END IF;
  END IF;
  
  -- status를 'active'로 업데이트 (복합 키 사용)
  UPDATE public.company_users
  SET status = 'active'
  WHERE company_id = p_company_id
    AND user_id = p_user_id
    AND status = 'pending'
    AND company_role = 'manager';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Manager request not found or already processed';
  END IF;
  
  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'company_id', p_company_id,
    'user_id', p_user_id,
    'status', 'active'
  ) INTO v_result;
  
  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$$;

ALTER FUNCTION "public"."approve_manager"("p_company_id" "uuid", "p_user_id" "uuid", "p_current_user_id" "uuid") OWNER TO "postgres";

-- 4. reject_manager - 매니저 거절
DROP FUNCTION IF EXISTS "public"."reject_manager"("p_company_id" "uuid", "p_user_id" "uuid");

CREATE OR REPLACE FUNCTION "public"."reject_manager"(
  "p_company_id" "uuid",
  "p_user_id" "uuid",
  "p_current_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_current_user_id uuid;
  v_result jsonb;
BEGIN
  -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
  v_current_user_id := COALESCE(p_current_user_id, (SELECT auth.uid()));
  
  -- Custom JWT 세션인 경우 (p_current_user_id가 전달되고 auth.uid()가 NULL) 권한 체크 건너뛰기
  -- 일반 세션인 경우에만 권한 체크
  IF p_current_user_id IS NULL THEN
    -- 권한 확인: 회사 소유자 또는 활성 매니저만 거절 가능
    IF NOT EXISTS (
      SELECT 1 FROM public.company_users cu
      WHERE cu.company_id = p_company_id
        AND cu.user_id = v_current_user_id
        AND cu.company_role IN ('owner', 'manager')
        AND cu.status = 'active'
    ) THEN
      RAISE EXCEPTION 'Unauthorized: Only company owners and active managers can reject managers';
    END IF;
  END IF;
  
  -- status를 'rejected'로 업데이트 (복합 키 사용)
  UPDATE public.company_users
  SET status = 'rejected'
  WHERE company_id = p_company_id
    AND user_id = p_user_id
    AND status = 'pending'
    AND company_role = 'manager';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Manager request not found or already processed';
  END IF;
  
  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'company_id', p_company_id,
    'user_id', p_user_id,
    'status', 'rejected'
  ) INTO v_result;
  
  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$$;

ALTER FUNCTION "public"."reject_manager"("p_company_id" "uuid", "p_user_id" "uuid", "p_current_user_id" "uuid") OWNER TO "postgres";

