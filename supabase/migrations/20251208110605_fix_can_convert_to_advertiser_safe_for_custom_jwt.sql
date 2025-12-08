-- Custom JWT 세션 지원을 위해 can_convert_to_advertiser_safe와 is_user_in_company_safe 함수 수정
-- p_user_id 파라미터를 추가하여 Custom JWT 세션에서도 작동하도록 수정

-- can_convert_to_advertiser_safe 함수 수정
CREATE OR REPLACE FUNCTION "public"."can_convert_to_advertiser_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_has_permission boolean;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, auth.uid());
    IF v_user_id IS NULL THEN
        RETURN false;
    END IF;

    -- 회사 역할 확인
    SELECT EXISTS(
        SELECT 1 FROM public.company_users
        WHERE user_id = v_user_id
        AND status = 'active'
        AND company_role IN ('owner', 'manager')
    ) INTO v_has_permission;

    RETURN v_has_permission;
END;
$$;

ALTER FUNCTION "public"."can_convert_to_advertiser_safe"("p_user_id" "uuid") OWNER TO "postgres";

COMMENT ON FUNCTION "public"."can_convert_to_advertiser_safe"("p_user_id" "uuid") IS '사용자가 광고주로 전환할 수 있는 권한이 있는지 확인 (Custom JWT 세션 지원)';

-- is_user_in_company_safe 함수 수정
CREATE OR REPLACE FUNCTION "public"."is_user_in_company_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_in_company boolean;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, auth.uid());
    IF v_user_id IS NULL THEN
        RETURN false;
    END IF;

    -- 회사 소속 확인
    SELECT EXISTS(
        SELECT 1 FROM public.company_users
        WHERE user_id = v_user_id
        AND status = 'active'
    ) INTO v_in_company;

    RETURN v_in_company;
END;
$$;

ALTER FUNCTION "public"."is_user_in_company_safe"("p_user_id" "uuid") OWNER TO "postgres";

COMMENT ON FUNCTION "public"."is_user_in_company_safe"("p_user_id" "uuid") IS '사용자가 회사에 속해있는지 확인 (Custom JWT 세션 지원)';

-- 권한 부여
GRANT ALL ON FUNCTION "public"."can_convert_to_advertiser_safe"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_convert_to_advertiser_safe"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_convert_to_advertiser_safe"("p_user_id" "uuid") TO "service_role";

GRANT ALL ON FUNCTION "public"."is_user_in_company_safe"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_user_in_company_safe"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_user_in_company_safe"("p_user_id" "uuid") TO "service_role";

