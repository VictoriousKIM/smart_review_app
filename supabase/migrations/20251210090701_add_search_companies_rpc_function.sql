-- Add RPC function for searching companies by business name
-- 프론트엔드에서 직접 쿼리하는 대신 RPC 함수를 사용하도록 변경

-- 회사 검색 RPC 함수 (사업자명으로 검색)
CREATE OR REPLACE FUNCTION "public"."search_companies_by_name"("p_business_name" "text", "p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("id" "uuid", "business_name" "text", "business_number" "text", "representative_name" "text", "address" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    -- 사업자명이 비어있으면 빈 결과 반환
    IF p_business_name IS NULL OR TRIM(p_business_name) = '' THEN
        RETURN;
    END IF;

    -- 회사 검색 (정확히 일치하는 사업자명)
    -- RLS 정책에 따라 접근 가능한 회사만 반환됨
    RETURN QUERY
    SELECT 
        c.id,
        c.business_name,
        c.business_number,
        c.representative_name,
        c.address
    FROM public.companies c
    WHERE c.business_name = TRIM(p_business_name)
    ORDER BY c.created_at DESC;
END;
$$;

COMMENT ON FUNCTION "public"."search_companies_by_name"("p_business_name" "text", "p_user_id" "uuid") IS '사업자명으로 회사 검색 (정확히 일치하는 경우만)';

-- 권한 부여
GRANT ALL ON FUNCTION "public"."search_companies_by_name"("p_business_name" "text", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."search_companies_by_name"("p_business_name" "text", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_companies_by_name"("p_business_name" "text", "p_user_id" "uuid") TO "service_role";

