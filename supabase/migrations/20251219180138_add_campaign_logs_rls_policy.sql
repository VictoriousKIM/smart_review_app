-- campaign_logs 테이블에 RLS 정책 추가
-- 회사 멤버만 자신의 회사 캠페인 로그를 조회할 수 있도록 설정

-- RLS 활성화 (이미 활성화되어 있을 수 있지만 안전하게 재설정)
ALTER TABLE "public"."campaign_logs" ENABLE ROW LEVEL SECURITY;

-- 기존 정책 삭제 (있다면)
DROP POLICY IF EXISTS "Campaign logs are viewable by company members" ON "public"."campaign_logs";

-- SELECT 정책: 회사 멤버만 자신의 회사 캠페인 로그를 조회 가능
CREATE POLICY "Campaign logs are viewable by company members" 
ON "public"."campaign_logs" 
FOR SELECT 
USING (
  "campaign_id" IN (
    SELECT "campaigns"."id"
    FROM "public"."campaigns"
    WHERE "campaigns"."company_id" IN (
      SELECT "company_users"."company_id"
      FROM "public"."company_users"
      WHERE (
        "company_users"."user_id" = (SELECT auth.uid())
        AND "company_users"."status" = 'active'::text
      )
    )
  )
);

-- INSERT 정책: 함수에서만 삽입하므로 SECURITY DEFINER 함수가 자동으로 처리
-- 하지만 안전을 위해 회사 멤버만 삽입 가능하도록 설정
DROP POLICY IF EXISTS "Campaign logs are insertable by company members" ON "public"."campaign_logs";

CREATE POLICY "Campaign logs are insertable by company members" 
ON "public"."campaign_logs" 
FOR INSERT 
WITH CHECK (
  "campaign_id" IN (
    SELECT "campaigns"."id"
    FROM "public"."campaigns"
    WHERE "campaigns"."company_id" IN (
      SELECT "company_users"."company_id"
      FROM "public"."company_users"
      WHERE (
        "company_users"."user_id" = (SELECT auth.uid())
        AND "company_users"."status" = 'active'::text
      )
    )
  )
  AND "user_id" = (SELECT auth.uid())
);

-- UPDATE/DELETE 정책: 로그는 읽기 전용이므로 정책 없음 (기본적으로 거부)

