-- ============================================================================
-- Migration: 20250102000009_update_get_user_profile_safe_with_company_role.sql
-- ============================================================================
-- Description: get_user_profile_safe 함수에 company_role과 company_id 추가
-- ============================================================================

-- get_user_profile_safe 함수 업데이트 (company_users 테이블과 조인)
CREATE OR REPLACE FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") 
RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
  v_profile jsonb;
  v_current_user_type text;
  v_target_user_id uuid;
  v_company_role text;
  v_company_id uuid;
BEGIN
  -- 기본값은 현재 사용자
  v_target_user_id := COALESCE(p_user_id, (select auth.uid()));
  
  -- 권한 확인: 자신의 프로필이거나 관리자
  IF v_target_user_id != (select auth.uid()) THEN
    SELECT user_type INTO v_current_user_type
    FROM public.users 
    WHERE id = (select auth.uid());
    
    IF v_current_user_type != 'admin' THEN
      RAISE EXCEPTION 'You can only view your own profile';
    END IF;
  END IF;
  
  -- company_users 테이블에서 company_role과 company_id 조회 (status='active'만)
  SELECT cu.company_role, cu.company_id
  INTO v_company_role, v_company_id
  FROM public.company_users cu
  WHERE cu.user_id = v_target_user_id
    AND cu.status = 'active'
  LIMIT 1;
  
  -- 프로필 조회 및 company_role, company_id 추가
  SELECT jsonb_build_object(
    'id', u.id,
    'created_at', u.created_at,
    'updated_at', u.updated_at,
    'display_name', u.display_name,
    'user_type', u.user_type,
    'status', u.status,
    'company_id', v_company_id,
    'company_role', v_company_role
  ) INTO v_profile
  FROM public.users u
  WHERE u.id = v_target_user_id;
  
  IF v_profile IS NULL THEN
    RAISE EXCEPTION 'User profile not found';
  END IF;
  
  RETURN v_profile;
END;
$$;

-- RPC 함수 권한 부여 (기존 권한 유지)
GRANT EXECUTE ON FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") TO "anon";
GRANT EXECUTE ON FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") TO "service_role";

-- ============================================================================
-- End of Migration: 20250102000009_update_get_user_profile_safe_with_company_role.sql
-- ============================================================================

