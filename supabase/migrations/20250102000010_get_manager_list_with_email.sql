-- ============================================================================
-- Migration: 20250102000010_get_manager_list_with_email.sql
-- ============================================================================
-- Description: 매니저 목록을 가져올 때 이메일도 함께 반환하는 RPC 함수
-- ============================================================================

-- 회사의 매니저 목록 조회 (이메일 포함)
CREATE OR REPLACE FUNCTION "public"."get_company_managers"("p_company_id" "uuid")
RETURNS TABLE (
  "id" uuid,
  "user_id" uuid,
  "status" text,
  "created_at" timestamp with time zone,
  "email" character varying(255),  -- auth.users.email과 타입 일치
  "display_name" text
)
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$
BEGIN
  -- 권한 확인: 회사 소유자 또는 관리자만 조회 가능
  IF NOT EXISTS (
    SELECT 1 FROM public.company_users cu
    WHERE cu.company_id = p_company_id
      AND cu.user_id = (SELECT auth.uid())
      AND cu.company_role IN ('owner', 'manager')
      AND cu.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Only company owners and managers can view manager list';
  END IF;

  -- 매니저 목록 조회 (auth.users의 email 포함)
  RETURN QUERY
  SELECT 
    cu.id,
    cu.user_id,
    cu.status,
    cu.created_at,
    au.email,  -- character varying(255) 타입 그대로 반환
    COALESCE(u.display_name, '이름 없음')::text as display_name
  FROM public.company_users cu
  LEFT JOIN public.users u ON u.id = cu.user_id
  LEFT JOIN auth.users au ON au.id = cu.user_id
  WHERE cu.company_id = p_company_id
    AND cu.company_role = 'manager'
    AND cu.status IN ('pending', 'active')  -- rejected 상태는 제외
  ORDER BY 
    CASE cu.status
      WHEN 'pending' THEN 1
      WHEN 'active' THEN 2
      ELSE 3
    END,
    cu.created_at DESC;
END;
$$;

-- RPC 함수 권한 부여
GRANT EXECUTE ON FUNCTION "public"."get_company_managers"("p_company_id" "uuid") TO "anon";
GRANT EXECUTE ON FUNCTION "public"."get_company_managers"("p_company_id" "uuid") TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."get_company_managers"("p_company_id" "uuid") TO "service_role";

-- ============================================================================
-- End of Migration: 20250102000010_get_manager_list_with_email.sql
-- ============================================================================

