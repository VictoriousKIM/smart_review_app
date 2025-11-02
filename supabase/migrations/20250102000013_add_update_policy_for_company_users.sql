-- ============================================================================
-- Migration: 20250102000013_add_update_policy_for_company_users.sql
-- ============================================================================
-- Description: company_users 테이블에 UPDATE 정책 추가 (매니저 승인/거절용)
-- ============================================================================

-- Company users 업데이트 정책 추가 (회사 소유자만)
DROP POLICY IF EXISTS "Company users are updatable by company owners" ON "public"."company_users";
CREATE POLICY "Company users are updatable by company owners" 
ON "public"."company_users" 
FOR UPDATE 
USING (
  -- 현재 사용자가 해당 회사의 owner 또는 active manager인 경우
  EXISTS (
    SELECT 1
    FROM "public"."company_users" AS "cu"
    WHERE (
      "cu"."company_id" = "company_users"."company_id"
      AND "cu"."user_id" = (SELECT auth.uid())
      AND "cu"."company_role" IN ('owner', 'manager')
      AND "cu"."status" = 'active'::text
    )
  )
)
WITH CHECK (
  -- 업데이트 후에도 같은 조건 유지
  EXISTS (
    SELECT 1
    FROM "public"."company_users" AS "cu"
    WHERE (
      "cu"."company_id" = "company_users"."company_id"
      AND "cu"."user_id" = (SELECT auth.uid())
      AND "cu"."company_role" IN ('owner', 'manager')
      AND "cu"."status" = 'active'::text
    )
  )
);

-- ============================================================================
-- End of Migration: 20250102000013_add_update_policy_for_company_users.sql
-- ============================================================================

