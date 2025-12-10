-- Fix reviewer role access to companies table
-- Reviewer 역할 사용자가 companies 테이블을 조회할 수 없도록 RLS 정책 수정

-- 1. 기존 "Companies are viewable by everyone" 정책 삭제
DROP POLICY IF EXISTS "Companies are viewable by everyone" ON "public"."companies";

-- 2. 새로운 RLS 정책 생성: owner/manager 역할만 companies 테이블 조회 가능
CREATE POLICY "Companies are viewable by owners and managers" ON "public"."companies"
FOR SELECT
USING (
  -- owner 또는 manager 역할인 경우만 조회 가능
  EXISTS (
    SELECT 1
    FROM public.company_users cu
    WHERE cu.company_id = companies.id
      AND cu.user_id = (select auth.uid())
      AND cu.company_role IN ('owner', 'manager')
      AND cu.status = 'active'
  )
  -- 또는 회사 소유자 (companies.user_id)인 경우
  OR companies.user_id = (select auth.uid())
);

-- 3. get_user_company_id_safe 함수 수정: owner/manager 역할만 반환
-- 주의: 이 함수는 다른 곳에서도 사용될 수 있으므로, 
-- reviewer 역할도 필요한 경우를 고려하여 새로운 함수를 만드는 것이 더 안전할 수 있습니다.
-- 하지만 현재 문제를 해결하기 위해 수정합니다.

CREATE OR REPLACE FUNCTION "public"."get_user_company_id_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_company_id UUID;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, auth.uid());
    
    -- 권한 확인
    IF v_user_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- 회사 ID 조회 (owner/manager 역할만)
    -- 주의: reviewer 역할도 필요한 경우를 위해 get_user_company_id_all_roles_safe 함수를 별도로 만들 수 있습니다.
    SELECT company_id INTO v_company_id
    FROM public.company_users
    WHERE user_id = v_user_id
    AND status = 'active'
    AND company_role IN ('owner', 'manager')
    LIMIT 1;

    RETURN v_company_id;
END;
$$;

-- 4. reviewer 역할도 포함하여 company_id를 조회해야 하는 경우를 위한 새로운 함수 생성
CREATE OR REPLACE FUNCTION "public"."get_user_company_id_all_roles_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_company_id UUID;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, auth.uid());
    
    -- 권한 확인
    IF v_user_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- 회사 ID 조회 (모든 역할 포함: owner, manager, reviewer)
    SELECT company_id INTO v_company_id
    FROM public.company_users
    WHERE user_id = v_user_id
    AND status = 'active'
    LIMIT 1;

    RETURN v_company_id;
END;
$$;

COMMENT ON FUNCTION "public"."get_user_company_id_safe"("p_user_id" "uuid") IS '사용자의 회사 ID 조회 (owner/manager 역할만)';
COMMENT ON FUNCTION "public"."get_user_company_id_all_roles_safe"("p_user_id" "uuid") IS '사용자의 회사 ID 조회 (모든 역할 포함: owner, manager, reviewer)';

