-- delete_company 함수 수정: company_users 수동 삭제 제거
-- CASCADE 제약조건이 자동으로 company_users를 삭제하므로 수동 삭제 불필요

CREATE OR REPLACE FUNCTION "public"."delete_company"("p_company_id" "uuid") RETURNS "jsonb"
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

  -- 회사 정보 삭제 (CASCADE가 자동으로 company_users도 삭제)
  -- company_users는 외래키 CASCADE 제약조건에 의해 자동 삭제됨
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

COMMENT ON FUNCTION "public"."delete_company"("p_company_id" "uuid") IS 
'회사 삭제 함수. company_users는 외래키 CASCADE 제약조건에 의해 자동으로 삭제됩니다.';

