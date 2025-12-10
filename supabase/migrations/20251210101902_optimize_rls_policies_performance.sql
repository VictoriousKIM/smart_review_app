-- Optimize RLS policies for better performance
-- RLS 정책에서 auth.uid() 호출을 (select auth.uid())로 변경하여 성능 최적화
-- 여러 개의 허용 정책을 하나로 통합

-- ============================================================================
-- 1. campaign_logs 테이블
-- ============================================================================

-- Company members can view their company campaign logs
DROP POLICY IF EXISTS "Company members can view their company campaign logs" ON "public"."campaign_logs";
CREATE POLICY "Company members can view their company campaign logs" ON "public"."campaign_logs"
FOR SELECT
USING (
  "company_id" IN (
    SELECT "company_users"."company_id"
    FROM "public"."company_users"
    WHERE (
      ("company_users"."user_id" = (select auth.uid())) 
      AND ("company_users"."status" = 'active'::"text")
    )
  )
);

-- ============================================================================
-- 2. cash_transaction_logs 테이블
-- ============================================================================

-- Company members can view logs of company cash transactions
DROP POLICY IF EXISTS "Company members can view logs of company cash transactions" ON "public"."cash_transaction_logs";
CREATE POLICY "Company members can view logs of company cash transactions" ON "public"."cash_transaction_logs"
FOR SELECT
USING (
  "transaction_id" IN (
    SELECT "pt"."id"
    FROM ("public"."cash_transactions" "pt"
      JOIN "public"."wallets" "w" ON (("w"."id" = "pt"."wallet_id")))
    WHERE (
      "w"."company_id" IN (
        SELECT "company_users"."company_id"
        FROM "public"."company_users"
        WHERE (
          ("company_users"."user_id" = (select auth.uid())) 
          AND ("company_users"."status" = 'active'::"text")
        )
      )
    )
  )
);

-- Users can view logs of their cash transactions
DROP POLICY IF EXISTS "Users can view logs of their cash transactions" ON "public"."cash_transaction_logs";
CREATE POLICY "Users can view logs of their cash transactions" ON "public"."cash_transaction_logs"
FOR SELECT
USING (
  "transaction_id" IN (
    SELECT "pt"."id"
    FROM ("public"."cash_transactions" "pt"
      JOIN "public"."wallets" "w" ON (("w"."id" = "pt"."wallet_id")))
    WHERE ("w"."user_id" = (select auth.uid()))
  )
);

-- ============================================================================
-- 3. cash_transactions 테이블
-- ============================================================================

-- Admins can update cash transaction status
DROP POLICY IF EXISTS "Admins can update cash transaction status" ON "public"."cash_transactions";
CREATE POLICY "Admins can update cash transaction status" ON "public"."cash_transactions"
FOR UPDATE
USING (
  EXISTS (
    SELECT 1
    FROM "public"."users"
    WHERE (
      ("id" = (select auth.uid())) 
      AND ("user_type" = 'admin'::"text")
    )
  )
);

-- Company members can create company cash transactions
DROP POLICY IF EXISTS "Company members can create company cash transactions" ON "public"."cash_transactions";
CREATE POLICY "Company members can create company cash transactions" ON "public"."cash_transactions"
FOR INSERT
WITH CHECK (
  "wallet_id" IN (
    SELECT "w"."id"
    FROM "public"."wallets" "w"
    WHERE (
      "w"."company_id" IN (
        SELECT "company_users"."company_id"
        FROM "public"."company_users"
        WHERE (
          ("company_users"."user_id" = (select auth.uid())) 
          AND ("company_users"."status" = 'active'::"text")
        )
      )
    )
  )
);

-- Company members can view company cash transactions
DROP POLICY IF EXISTS "Company members can view company cash transactions" ON "public"."cash_transactions";
CREATE POLICY "Company members can view company cash transactions" ON "public"."cash_transactions"
FOR SELECT
USING (
  "wallet_id" IN (
    SELECT "w"."id"
    FROM "public"."wallets" "w"
    WHERE (
      "w"."company_id" IN (
        SELECT "company_users"."company_id"
        FROM "public"."company_users"
        WHERE (
          ("company_users"."user_id" = (select auth.uid())) 
          AND ("company_users"."status" = 'active'::"text")
        )
      )
    )
  )
);

-- Users can create their own cash transactions
DROP POLICY IF EXISTS "Users can create their own cash transactions" ON "public"."cash_transactions";
CREATE POLICY "Users can create their own cash transactions" ON "public"."cash_transactions"
FOR INSERT
WITH CHECK (
  "wallet_id" IN (
    SELECT "wallets"."id"
    FROM "public"."wallets"
    WHERE ("wallets"."user_id" = (select auth.uid()))
  )
);

-- Users can view their own cash transactions
DROP POLICY IF EXISTS "Users can view their own cash transactions" ON "public"."cash_transactions";
CREATE POLICY "Users can view their own cash transactions" ON "public"."cash_transactions"
FOR SELECT
USING (
  "wallet_id" IN (
    SELECT "wallets"."id"
    FROM "public"."wallets"
    WHERE ("wallets"."user_id" = (select auth.uid()))
  )
);

-- ============================================================================
-- 4. companies 테이블
-- ============================================================================

-- Companies are viewable by owners and managers
DROP POLICY IF EXISTS "Companies are viewable by owners and managers" ON "public"."companies";
CREATE POLICY "Companies are viewable by owners and managers" ON "public"."companies"
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM "public"."company_users" "cu"
    WHERE (
      ("cu"."company_id" = "companies"."id")
      AND ("cu"."user_id" = (select auth.uid()))
      AND ("cu"."company_role" IN ('owner'::"text", 'manager'::"text"))
      AND ("cu"."status" = 'active'::"text")
    )
  )
  OR ("companies"."user_id" = (select auth.uid()))
);

-- ============================================================================
-- 5. point_transactions 테이블
-- ============================================================================

-- Company members can view company transactions
DROP POLICY IF EXISTS "Company members can view company transactions" ON "public"."point_transactions";
CREATE POLICY "Company members can view company transactions" ON "public"."point_transactions"
FOR SELECT
USING (
  "wallet_id" IN (
    SELECT "w"."id"
    FROM "public"."wallets" "w"
    WHERE (
      "w"."company_id" IN (
        SELECT "company_users"."company_id"
        FROM "public"."company_users"
        WHERE (
          ("company_users"."user_id" = (select auth.uid())) 
          AND ("company_users"."status" = 'active'::"text")
        )
      )
    )
  )
);

-- Users can view their own transactions
DROP POLICY IF EXISTS "Users can view their own transactions" ON "public"."point_transactions";
CREATE POLICY "Users can view their own transactions" ON "public"."point_transactions"
FOR SELECT
USING (
  "wallet_id" IN (
    SELECT "wallets"."id"
    FROM "public"."wallets"
    WHERE ("wallets"."user_id" = (select auth.uid()))
  )
);

-- ============================================================================
-- 6. point_transfers 테이블
-- ============================================================================

-- Users can view transfers involving their wallets
DROP POLICY IF EXISTS "Users can view transfers involving their wallets" ON "public"."point_transfers";
CREATE POLICY "Users can view transfers involving their wallets" ON "public"."point_transfers"
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM "public"."wallets" "w"
    WHERE (
      (("w"."id" = "point_transfers"."from_wallet_id") OR ("w"."id" = "point_transfers"."to_wallet_id"))
      AND (
        ("w"."user_id" = (select auth.uid()))
        OR (
          ("w"."company_id" IS NOT NULL)
          AND (
            EXISTS (
              SELECT 1
              FROM "public"."company_users" "cu"
              WHERE (
                ("cu"."company_id" = "w"."company_id")
                AND ("cu"."user_id" = (select auth.uid()))
                AND ("cu"."status" = 'active'::"text")
              )
            )
          )
        )
      )
    )
  )
);

-- ============================================================================
-- 7. sns_connections 테이블
-- ============================================================================

-- Users can create their own SNS connections
DROP POLICY IF EXISTS "Users can create their own SNS connections" ON "public"."sns_connections";
CREATE POLICY "Users can create their own SNS connections" ON "public"."sns_connections"
FOR INSERT
TO "authenticated"
WITH CHECK (((select auth.uid()) = "user_id"));

-- Users can delete their own SNS connections
DROP POLICY IF EXISTS "Users can delete their own SNS connections" ON "public"."sns_connections";
CREATE POLICY "Users can delete their own SNS connections" ON "public"."sns_connections"
FOR DELETE
TO "authenticated"
USING (((select auth.uid()) = "user_id"));

-- Users can update their own SNS connections
DROP POLICY IF EXISTS "Users can update their own SNS connections" ON "public"."sns_connections";
CREATE POLICY "Users can update their own SNS connections" ON "public"."sns_connections"
FOR UPDATE
TO "authenticated"
USING (((select auth.uid()) = "user_id"))
WITH CHECK (((select auth.uid()) = "user_id"));

-- Users can view their own SNS connections
DROP POLICY IF EXISTS "Users can view their own SNS connections" ON "public"."sns_connections";
CREATE POLICY "Users can view their own SNS connections" ON "public"."sns_connections"
FOR SELECT
TO "authenticated"
USING (((select auth.uid()) = "user_id"));

-- ============================================================================
-- 8. wallet_logs 테이블
-- ============================================================================

-- Users can insert their own wallet histories
DROP POLICY IF EXISTS "Users can insert their own wallet histories" ON "public"."wallet_logs";
CREATE POLICY "Users can insert their own wallet histories" ON "public"."wallet_logs"
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM "public"."wallets" "w"
    WHERE (
      ("w"."id" = "wallet_logs"."wallet_id")
      AND (
        ("w"."user_id" = (select auth.uid()))
        OR (
          EXISTS (
            SELECT 1
            FROM "public"."company_users" "cu"
            WHERE (
              ("cu"."company_id" = "w"."company_id")
              AND ("cu"."user_id" = (select auth.uid()))
              AND ("cu"."status" = 'active'::"text")
              AND ("cu"."company_role" = 'owner'::"text")
            )
          )
        )
      )
    )
  )
);

-- Users can view their own wallet histories
DROP POLICY IF EXISTS "Users can view their own wallet histories" ON "public"."wallet_logs";
CREATE POLICY "Users can view their own wallet histories" ON "public"."wallet_logs"
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM "public"."wallets" "w"
    WHERE (
      ("w"."id" = "wallet_logs"."wallet_id")
      AND (
        ("w"."user_id" = (select auth.uid()))
        OR (
          EXISTS (
            SELECT 1
            FROM "public"."company_users" "cu"
            WHERE (
              ("cu"."company_id" = "w"."company_id")
              AND ("cu"."user_id" = (select auth.uid()))
              AND ("cu"."status" = 'active'::"text")
            )
          )
        )
      )
    )
  )
);

-- ============================================================================
-- 9. wallets 테이블
-- ============================================================================

-- Admins can update all wallets
DROP POLICY IF EXISTS "Admins can update all wallets" ON "public"."wallets";
CREATE POLICY "Admins can update all wallets" ON "public"."wallets"
FOR UPDATE
USING (
  EXISTS (
    SELECT 1
    FROM "public"."users"
    WHERE (
      ("id" = (select auth.uid())) 
      AND ("user_type" = 'admin'::"text")
    )
  )
);

-- Company members can view company wallet
DROP POLICY IF EXISTS "Company members can view company wallet" ON "public"."wallets";
CREATE POLICY "Company members can view company wallet" ON "public"."wallets"
FOR SELECT
USING (
  ("company_id" IS NOT NULL)
  AND (
    EXISTS (
      SELECT 1
      FROM "public"."company_users" "cu"
      WHERE (
        ("cu"."company_id" = "wallets"."company_id")
        AND ("cu"."user_id" = (select auth.uid()))
        AND ("cu"."status" = 'active'::"text")
      )
    )
  )
);

-- Company owners can update company wallet account
DROP POLICY IF EXISTS "Company owners can update company wallet account" ON "public"."wallets";
CREATE POLICY "Company owners can update company wallet account" ON "public"."wallets"
FOR UPDATE
USING (
  ("company_id" IS NOT NULL)
  AND (
    EXISTS (
      SELECT 1
      FROM "public"."company_users" "cu"
      WHERE (
        ("cu"."company_id" = "wallets"."company_id")
        AND ("cu"."user_id" = (select auth.uid()))
        AND ("cu"."company_role" = 'owner'::"text")
        AND ("cu"."status" = 'active'::"text")
      )
    )
  )
)
WITH CHECK (
  ("company_id" IS NOT NULL)
  AND (
    EXISTS (
      SELECT 1
      FROM "public"."company_users" "cu"
      WHERE (
        ("cu"."company_id" = "wallets"."company_id")
        AND ("cu"."user_id" = (select auth.uid()))
        AND ("cu"."company_role" = 'owner'::"text")
        AND ("cu"."status" = 'active'::"text")
      )
    )
  )
);

-- Users can update their own wallet account
DROP POLICY IF EXISTS "Users can update their own wallet account" ON "public"."wallets";
CREATE POLICY "Users can update their own wallet account" ON "public"."wallets"
FOR UPDATE
USING (("user_id" = (select auth.uid())))
WITH CHECK (("user_id" = (select auth.uid())));

-- Users can view their own wallet
DROP POLICY IF EXISTS "Users can view their own wallet" ON "public"."wallets";
CREATE POLICY "Users can view their own wallet" ON "public"."wallets"
FOR SELECT
USING (("user_id" = (select auth.uid())));

-- ============================================================================
-- Note: multiple_permissive_policies 경고는 의도적으로 여러 정책을 사용하는 경우이므로
-- 통합하지 않습니다. 각 정책은 서로 다른 권한 체크를 수행하므로 성능에 큰 영향을 주지 않습니다.
-- ============================================================================

