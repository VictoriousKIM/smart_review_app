-- Migration: Fix update_user_profile_safe function
-- Description: users 테이블에 company_id 컬럼이 없으므로 제거
-- 기존 오버로딩된 함수들을 모두 삭제하고 단일 함수로 재생성

-- 기존 함수들 삭제 (모든 오버로딩 버전)
DROP FUNCTION IF EXISTS "public"."update_user_profile_safe"("uuid", "text", "uuid");
DROP FUNCTION IF EXISTS "public"."update_user_profile_safe"("uuid", "text");

-- update_user_profile_safe 함수 재생성 (company_id 제거)
CREATE OR REPLACE FUNCTION "public"."update_user_profile_safe"(
  "p_user_id" "uuid",
  "p_display_name" "text" DEFAULT NULL::"text"
) RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
  v_profile jsonb;
BEGIN
  -- 자신의 프로필만 업데이트 가능
  IF p_user_id != (SELECT auth.uid()) THEN
    RAISE EXCEPTION 'You can only update your own profile';
  END IF;
  
  -- 프로필 업데이트 (display_name만)
  UPDATE public.users 
  SET 
    display_name = COALESCE(p_display_name, display_name),
    updated_at = NOW()
  WHERE id = p_user_id
  RETURNING to_jsonb(users.*) INTO v_profile;
  
  IF v_profile IS NULL THEN
    RAISE EXCEPTION 'User profile not found';
  END IF;
  
  RETURN v_profile;
END;
$$;

-- 함수 권한 부여
GRANT EXECUTE ON FUNCTION "public"."update_user_profile_safe"("uuid", "text") TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."update_user_profile_safe"("uuid", "text") TO "anon";
GRANT EXECUTE ON FUNCTION "public"."update_user_profile_safe"("uuid", "text") TO "service_role";

