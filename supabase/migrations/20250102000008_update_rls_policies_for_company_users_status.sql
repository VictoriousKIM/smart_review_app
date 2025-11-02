-- ============================================================================
-- Migration: 20250102000008_update_rls_policies_for_company_users_status.sql
-- ============================================================================
-- Description: company_users 테이블 조회 시 status='active' 조건 추가
-- ============================================================================

-- RLS 정책에서 company_users 조회 시 status='active' 조건 추가

-- 1. Point logs 정책 업데이트 (company_users에 status='active' 조건 추가)
DROP POLICY IF EXISTS "Point logs are viewable by wallet owner" ON "public"."point_logs";
CREATE POLICY "Point logs are viewable by wallet owner" ON "public"."point_logs" FOR SELECT USING ((
  "wallet_id" IN (
    SELECT "point_wallets"."id"
    FROM "public"."point_wallets"
    WHERE (
      (("point_wallets"."wallet_type" = 'reviewer'::"text") AND ("point_wallets"."user_id" = (SELECT auth.uid())))
      OR
      (("point_wallets"."wallet_type" = 'company'::"text") AND ("point_wallets"."user_id" IN (
        SELECT "company_users"."company_id"
        FROM "public"."company_users"
        WHERE (
          "company_users"."user_id" = (SELECT auth.uid())
          AND "company_users"."status" = 'active'::text
        )
      )))
    )
  )
));

-- 2. Point wallets 업데이트 정책 (company_users에 status='active' 조건 추가)
DROP POLICY IF EXISTS "Point wallets are updatable by owner" ON "public"."point_wallets";
CREATE POLICY "Point wallets are updatable by owner" ON "public"."point_wallets" FOR UPDATE USING ((
  (("wallet_type" = 'reviewer'::"text") AND ("user_id" = (SELECT auth.uid())))
  OR
  (("wallet_type" = 'company'::"text") AND ("user_id" IN (
    SELECT "company_users"."company_id"
    FROM "public"."company_users"
    WHERE (
      "company_users"."user_id" = (SELECT auth.uid())
      AND "company_users"."status" = 'active'::text
    )
  )))
));

-- 3. Point wallets 조회 정책 (company_users에 status='active' 조건 추가)
DROP POLICY IF EXISTS "Point wallets are viewable by owner" ON "public"."point_wallets";
CREATE POLICY "Point wallets are viewable by owner" ON "public"."point_wallets" FOR SELECT USING ((
  (("wallet_type" = 'reviewer'::"text") AND ("user_id" = (SELECT auth.uid())))
  OR
  (("wallet_type" = 'company'::"text") AND ("user_id" IN (
    SELECT "company_users"."company_id"
    FROM "public"."company_users"
    WHERE (
      "company_users"."user_id" = (SELECT auth.uid())
      AND "company_users"."status" = 'active'::text
    )
  )))
));

-- 3. Companies 업데이트 정책 (이미 owner 체크에 포함되어 있을 수 있지만 명시적으로 추가)
DROP POLICY IF EXISTS "Companies are updatable by owners" ON "public"."companies";
CREATE POLICY "Companies are updatable by owners" ON "public"."companies" FOR UPDATE USING ((
  EXISTS (
    SELECT 1
    FROM "public"."company_users"
    WHERE (
      "company_users"."company_id" = "companies"."id"
      AND "company_users"."user_id" = (SELECT auth.uid())
      AND "company_users"."company_role" = 'owner'::text
      AND "company_users"."status" = 'active'::text
    )
  )
));

-- 4. Company users 삽입 정책 (owner 체크 시 status 조건 추가)
DROP POLICY IF EXISTS "Company users are insertable by company owners" ON "public"."company_users";
CREATE POLICY "Company users are insertable by company owners" ON "public"."company_users" FOR INSERT WITH CHECK ((
  EXISTS (
    SELECT 1
    FROM "public"."company_users" AS "cu"
    WHERE (
      "cu"."company_id" = "company_users"."company_id"
      AND "cu"."user_id" = (SELECT auth.uid())
      AND "cu"."company_role" = 'owner'::text
      AND "cu"."status" = 'active'::text
    )
  )
));

-- ============================================================================
-- End of Migration: 20250102000008_update_rls_policies_for_company_users_status.sql
-- ============================================================================

