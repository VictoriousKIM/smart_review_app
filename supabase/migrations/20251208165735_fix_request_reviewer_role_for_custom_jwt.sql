-- request_reviewer_role 함수에 p_user_id 파라미터 추가하여 Custom JWT 세션 지원
-- 기존 함수 삭제
DROP FUNCTION IF EXISTS "public"."request_reviewer_role"("p_company_id" "uuid");

-- 새 함수 생성 (p_user_id 파라미터 추가)
CREATE OR REPLACE FUNCTION "public"."request_reviewer_role"(
  "p_company_id" "uuid",
  "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_user_id uuid;
  v_result jsonb;
BEGIN
  -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
  v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Must be logged in';
  END IF;

  -- 회사 존재 여부 확인
  IF NOT EXISTS (
    SELECT 1 FROM public.companies
    WHERE id = p_company_id
  ) THEN
    RAISE EXCEPTION '회사를 찾을 수 없습니다.';
  END IF;

  -- 이미 등록된 관계가 있는지 확인
  IF EXISTS (
    SELECT 1 FROM public.company_users
    WHERE company_id = p_company_id
      AND user_id = v_user_id
      AND company_role = 'reviewer'
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION '이미 등록된 리뷰어입니다.';
  END IF;

  -- 이미 pending 요청이 있는지 확인
  IF EXISTS (
    SELECT 1 FROM public.company_users
    WHERE company_id = p_company_id
      AND user_id = v_user_id
      AND company_role = 'reviewer'
      AND status = 'pending'
  ) THEN
    RAISE EXCEPTION '이미 요청한 광고사입니다. 승인 대기 중입니다.';
  END IF;

  -- 기존 요청이 있으면 status를 pending으로 업데이트
  IF EXISTS (
    SELECT 1 FROM public.company_users
    WHERE company_id = p_company_id
      AND user_id = v_user_id
      AND company_role = 'reviewer'
  ) THEN
    UPDATE public.company_users
    SET status = 'pending',
        created_at = NOW()
    WHERE company_id = p_company_id
      AND user_id = v_user_id
      AND company_role = 'reviewer';
  ELSE
    -- 없으면 새로 추가
    INSERT INTO public.company_users (
      company_id,
      user_id,
      company_role,
      status,
      created_at
    ) VALUES (
      p_company_id,
      v_user_id,
      'reviewer',
      'pending',
      NOW()
    );
  END IF;

  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'company_id', p_company_id,
    'message', '리뷰어 등록 요청이 완료되었습니다. 승인 대기 중입니다.'
  ) INTO v_result;

  RETURN v_result;

EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$$;

ALTER FUNCTION "public"."request_reviewer_role"("p_company_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";

COMMENT ON FUNCTION "public"."request_reviewer_role"("p_company_id" "uuid", "p_user_id" "uuid") IS '리뷰어 등록 요청 (Custom JWT 세션 지원)';

