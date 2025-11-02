-- ============================================================================
-- Migration: 20250102000014_create_approve_reject_manager_rpc.sql
-- ============================================================================
-- Description: 매니저 승인/거절을 위한 RPC 함수 생성
-- ============================================================================

-- 매니저 승인 RPC 함수
CREATE OR REPLACE FUNCTION "public"."approve_manager"("p_company_user_id" "uuid")
RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
  v_company_id uuid;
  v_result jsonb;
BEGIN
  -- company_user_id로 company_id 조회
  SELECT company_id INTO v_company_id
  FROM public.company_users
  WHERE id = p_company_user_id;
  
  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'Company user not found';
  END IF;
  
  -- 권한 확인: 회사 소유자 또는 활성 매니저만 승인 가능
  IF NOT EXISTS (
    SELECT 1 FROM public.company_users cu
    WHERE cu.company_id = v_company_id
      AND cu.user_id = (SELECT auth.uid())
      AND cu.company_role IN ('owner', 'manager')
      AND cu.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Only company owners and active managers can approve managers';
  END IF;
  
  -- status를 'active'로 업데이트
  UPDATE public.company_users
  SET status = 'active'
  WHERE id = p_company_user_id
    AND status = 'pending'
    AND company_role = 'manager';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Manager request not found or already processed';
  END IF;
  
  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'company_user_id', p_company_user_id,
    'status', 'active'
  ) INTO v_result;
  
  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$$;

-- 매니저 거절 RPC 함수
CREATE OR REPLACE FUNCTION "public"."reject_manager"("p_company_user_id" "uuid")
RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
  v_company_id uuid;
  v_result jsonb;
BEGIN
  -- company_user_id로 company_id 조회
  SELECT company_id INTO v_company_id
  FROM public.company_users
  WHERE id = p_company_user_id;
  
  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'Company user not found';
  END IF;
  
  -- 권한 확인: 회사 소유자 또는 활성 매니저만 거절 가능
  IF NOT EXISTS (
    SELECT 1 FROM public.company_users cu
    WHERE cu.company_id = v_company_id
      AND cu.user_id = (SELECT auth.uid())
      AND cu.company_role IN ('owner', 'manager')
      AND cu.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Only company owners and active managers can reject managers';
  END IF;
  
  -- status를 'rejected'로 업데이트
  UPDATE public.company_users
  SET status = 'rejected'
  WHERE id = p_company_user_id
    AND status = 'pending'
    AND company_role = 'manager';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Manager request not found or already processed';
  END IF;
  
  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'company_user_id', p_company_user_id,
    'status', 'rejected'
  ) INTO v_result;
  
  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$$;

-- RPC 함수 권한 부여
GRANT EXECUTE ON FUNCTION "public"."approve_manager"("p_company_user_id" "uuid") TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."reject_manager"("p_company_user_id" "uuid") TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."approve_manager"("p_company_user_id" "uuid") TO "service_role";
GRANT EXECUTE ON FUNCTION "public"."reject_manager"("p_company_user_id" "uuid") TO "service_role";

-- ============================================================================
-- End of Migration: 20250102000014_create_approve_reject_manager_rpc.sql
-- ============================================================================

