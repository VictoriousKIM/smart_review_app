-- Include inactive reviewer requests in get_user_reviewer_requests function
-- 비활성화된 리뷰어도 신청 내역에 표시되도록 수정

CREATE OR REPLACE FUNCTION "public"."get_user_reviewer_requests"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("company_id" "uuid", "company_name" "text", "business_number" "text", "status" "text", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
  v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Must be logged in';
  END IF;

  RETURN QUERY
  SELECT 
    cu.company_id,
    COALESCE(c.business_name, '알 수 없음') as company_name,  -- NULL 처리
    COALESCE(c.business_number, '') as business_number,      -- NULL 처리
    cu.status,
    cu.created_at
  FROM public.company_users cu
  LEFT JOIN public.companies c ON c.id = cu.company_id  -- LEFT JOIN으로 변경
  WHERE cu.user_id = v_user_id
    AND cu.company_role = 'reviewer'
    AND cu.status IN ('pending', 'active', 'inactive', 'rejected')  -- inactive 상태 추가
  ORDER BY cu.created_at DESC;
END;
$$;

COMMENT ON FUNCTION "public"."get_user_reviewer_requests"("p_user_id" "uuid") IS '사용자가 신청한 리뷰어 요청 목록 조회 (pending, active, inactive, rejected 상태 포함)';

