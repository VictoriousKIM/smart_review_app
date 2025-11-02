-- ============================================================================
-- Migration: 20250102000007_create_request_manager_role_rpc.sql
-- ============================================================================
-- Description: 매니저 등록 요청 RPC 함수 (사업자번호 체크 및 company_users에 pending 등록)
-- Note: manager_request_attempts 테이블은 20250102000011 마이그레이션에서 제거됨
-- ============================================================================

-- 매니저 등록 요청 RPC 함수
CREATE OR REPLACE FUNCTION "public"."request_manager_role"(
  "p_business_name" "text",
  "p_business_number" "text"
) RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
  v_user_id uuid;
  v_company_id uuid;
  v_result jsonb;
  v_cleaned_business_number text;
BEGIN
  -- 현재 사용자 ID 가져오기
  v_user_id := (SELECT auth.uid());
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Must be logged in';
  END IF;

  -- 사업자번호 정리 (하이픈 제거)
  v_cleaned_business_number := REPLACE(p_business_number, '-', '');

  -- 회사 존재 여부 확인
  SELECT id INTO v_company_id
  FROM public.companies
  WHERE business_number = v_cleaned_business_number
    AND business_name = p_business_name
  LIMIT 1;

  -- 회사가 존재하지 않으면 에러
  IF v_company_id IS NULL THEN
    RAISE EXCEPTION '등록된 사업자정보가 없습니다.';
  END IF;

  -- 이미 등록된 관계가 있는지 확인
  IF EXISTS (
    SELECT 1 FROM public.company_users
    WHERE company_id = v_company_id
      AND user_id = v_user_id
  ) THEN
    -- 이미 존재하면 status를 pending으로 업데이트
    UPDATE public.company_users
    SET status = 'pending',
        company_role = 'manager',
        created_at = NOW()
    WHERE company_id = v_company_id
      AND user_id = v_user_id;
  ELSE
    -- 없으면 새로 추가
    INSERT INTO public.company_users (
      company_id,
      user_id,
      company_role,
      status,
      created_at
    ) VALUES (
      v_company_id,
      v_user_id,
      'manager',
      'pending',
      NOW()
    );
  END IF;

  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'company_id', v_company_id,
    'business_name', p_business_name,
    'business_number', v_cleaned_business_number,
    'message', '매니저 등록 요청이 완료되었습니다. 승인 대기 중입니다.'
  ) INTO v_result;

  RETURN v_result;

EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$$;

-- RPC 함수 권한 부여
GRANT EXECUTE ON FUNCTION "public"."request_manager_role"("p_business_name" "text", "p_business_number" "text") TO "authenticated";

-- ============================================================================
-- End of Migration: 20250102000007_create_request_manager_role_rpc.sql
-- ============================================================================

