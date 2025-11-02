-- ============================================================================
-- Migration: 20250102000002_create_register_company_rpc.sql
-- ============================================================================

-- 회사 정보 저장 RPC 함수 (중복 체크 및 트랜잭션 포함)
CREATE OR REPLACE FUNCTION "public"."register_company"(
  "p_user_id" "uuid",
  "p_business_name" "text",
  "p_business_number" "text",
  "p_address" "text",
  "p_representative_name" "text",
  "p_business_type" "text",
  "p_registration_file_url" "text"
) RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
  v_company_id uuid;
  v_result jsonb;
  v_cleaned_business_number text;
BEGIN
  -- 권한 확인: 자신의 데이터만 저장 가능
  IF p_user_id != (SELECT auth.uid()) THEN
    RAISE EXCEPTION 'Unauthorized: Can only register company for yourself';
  END IF;

  -- 사업자번호 정리 (하이픈 제거)
  v_cleaned_business_number := REPLACE(p_business_number, '-', '');

  -- 중복 체크 (트랜잭션 내에서)
  IF EXISTS (
    SELECT 1 FROM public.companies 
    WHERE business_number = v_cleaned_business_number
  ) THEN
    RAISE EXCEPTION '이미 등록된 사업자번호입니다.';
  END IF;

  -- 회사 정보 저장
  INSERT INTO public.companies (
    user_id,
    business_name,
    business_number,
    address,
    representative_name,
    business_type,
    registration_file_url,
    created_at,
    updated_at
  ) VALUES (
    p_user_id,
    p_business_name,
    v_cleaned_business_number,
    p_address,
    p_representative_name,
    p_business_type,
    p_registration_file_url,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_company_id;

  -- company_users 관계 추가 (중복 체크 후)
  IF NOT EXISTS (
    SELECT 1 FROM public.company_users 
    WHERE company_id = v_company_id 
    AND user_id = p_user_id
  ) THEN
    INSERT INTO public.company_users (
      company_id,
      user_id,
      company_role,
      created_at
    ) VALUES (
      v_company_id,
      p_user_id,
      'owner',
      NOW()
    );
  END IF;

  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'company_id', v_company_id,
    'business_number', v_cleaned_business_number
  ) INTO v_result;

  RETURN v_result;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION '이미 등록된 사업자번호입니다.';
  WHEN OTHERS THEN
    RAISE EXCEPTION '회사 등록 실패: %', SQLERRM;
END;
$$;

-- 회사 정보 삭제 RPC 함수 (롤백용)
CREATE OR REPLACE FUNCTION "public"."delete_company"(
  "p_company_id" "uuid"
) RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
  v_result jsonb;
  v_user_id uuid;
BEGIN
  -- 현재 사용자 ID 가져오기
  v_user_id := (SELECT auth.uid());
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Must be logged in';
  END IF;

  -- 권한 확인: 자신의 회사만 삭제 가능
  IF NOT EXISTS (
    SELECT 1 FROM public.companies 
    WHERE id = p_company_id 
    AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Can only delete your own company';
  END IF;

  -- company_users 관계 삭제
  DELETE FROM public.company_users 
  WHERE company_id = p_company_id;

  -- 회사 정보 삭제
  DELETE FROM public.companies 
  WHERE id = p_company_id;

  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'company_id', p_company_id
  ) INTO v_result;

  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION '회사 삭제 실패: %', SQLERRM;
END;
$$;

-- RPC 함수 권한 부여
GRANT EXECUTE ON FUNCTION "public"."register_company" TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."delete_company" TO "authenticated";

-- ============================================================================
-- End of Migration: 20250102000002_create_register_company_rpc.sql
-- ============================================================================

