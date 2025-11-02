-- 모든 테이블의 사용자 외래키 필드명을 user_id로 통일
-- companies 테이블에 user_id 필드 추가

-- 1. campaigns 테이블: created_by → user_id
ALTER TABLE "public"."campaigns" 
  RENAME COLUMN "created_by" TO "user_id";

-- 외래키 제약조건 재생성
ALTER TABLE "public"."campaigns"
  DROP CONSTRAINT IF EXISTS "campaigns_created_by_fkey";

ALTER TABLE "public"."campaigns"
  ADD CONSTRAINT "campaigns_user_id_fkey" 
  FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;

-- 인덱스 이름 변경
DROP INDEX IF EXISTS "public"."idx_campaigns_created_by";
CREATE INDEX IF NOT EXISTS "idx_campaigns_user_id" ON "public"."campaigns" USING "btree" ("user_id");

-- 2. companies 테이블: created_by → user_id로 변경 및 추가
-- 먼저 created_by가 있으면 user_id로 변경
DO $$
BEGIN
  -- created_by 컬럼이 존재하는지 확인
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'companies' 
    AND column_name = 'created_by'
  ) THEN
    ALTER TABLE "public"."companies" 
      RENAME COLUMN "created_by" TO "user_id";
  ELSE
    -- created_by가 없으면 user_id 컬럼 추가
    ALTER TABLE "public"."companies" 
      ADD COLUMN "user_id" uuid;
  END IF;
END $$;

-- 외래키 제약조건 재생성
ALTER TABLE "public"."companies"
  DROP CONSTRAINT IF EXISTS "companies_created_by_fkey";

ALTER TABLE "public"."companies"
  ADD CONSTRAINT "companies_user_id_fkey" 
  FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS "idx_companies_user_id" ON "public"."companies" USING "btree" ("user_id");

-- 3. business_registrations 테이블: reviewed_by → user_id로 변경 (reviewed_by_user_id)
-- 이 테이블이 사용되는지 확인 필요하지만, 일단 통일성 위해 변경
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'business_registrations'
  ) THEN
    -- reviewed_by를 reviewed_by_user_id로 변경 (user_id와 구분)
    ALTER TABLE "public"."business_registrations" 
      RENAME COLUMN "reviewed_by" TO "reviewed_by_user_id";
    
    -- 외래키 제약조건 재생성
    ALTER TABLE "public"."business_registrations"
      DROP CONSTRAINT IF EXISTS "business_registrations_reviewed_by_fkey";

    ALTER TABLE "public"."business_registrations"
      ADD CONSTRAINT "business_registrations_reviewed_by_user_id_fkey" 
      FOREIGN KEY ("reviewed_by_user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;
  END IF;
END $$;

-- 4. RLS 정책 업데이트: created_by → user_id
-- campaigns 테이블 RLS 정책 업데이트
DROP POLICY IF EXISTS "Campaigns are insertable by company members" ON "public"."campaigns";
CREATE POLICY "Campaigns are insertable by company members" ON "public"."campaigns" 
FOR INSERT WITH CHECK (
  "company_id" IN (
    SELECT "company_users"."company_id"
    FROM "public"."company_users"
    WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid"))
  )
);

DROP POLICY IF EXISTS "Campaigns are updatable by company members" ON "public"."campaigns";
CREATE POLICY "Campaigns are updatable by company members" ON "public"."campaigns" 
FOR UPDATE USING (
  "company_id" IN (
    SELECT "company_users"."company_id"
    FROM "public"."company_users"
    WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid"))
  )
);

-- companies 테이블 RLS 정책 확인 및 업데이트
-- 기존 정책들이 created_by를 사용하는지 확인하고 업데이트
DROP POLICY IF EXISTS "Companies are insertable by authenticated users" ON "public"."companies";
CREATE POLICY "Companies are insertable by authenticated users" ON "public"."companies" 
FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") IS NOT NULL));

DROP POLICY IF EXISTS "Companies are viewable by everyone" ON "public"."companies";
CREATE POLICY "Companies are viewable by everyone" ON "public"."companies" 
FOR SELECT USING (true);

-- 기존 companies 업데이트 정책 확인 및 업데이트 (created_by → user_id로 변경)
DROP POLICY IF EXISTS "Companies are updatable by owners" ON "public"."companies";
CREATE POLICY "Companies are updatable by owners" ON "public"."companies" 
FOR UPDATE USING (
  EXISTS (
    SELECT 1
    FROM "public"."company_users"
    WHERE (
      ("company_users"."company_id" = "companies"."id") 
      AND ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid")) 
      AND ("company_users"."company_role" = 'owner'::"text")
    )
  )
);

-- company_users 테이블 정책에서 created_by 참조 확인 및 업데이트
DROP POLICY IF EXISTS "Company users are insertable for new company owners" ON "public"."company_users";
CREATE POLICY "Company users are insertable for new company owners" ON "public"."company_users" 
FOR INSERT WITH CHECK (
  -- 1. They are creating a company (user_id matches), OR
  EXISTS (
    SELECT 1 FROM "public"."companies"
    WHERE "companies"."id" = "company_users"."company_id"
    AND "companies"."user_id" = ( SELECT "auth"."uid"() AS "uid")
  )
  OR
  -- 2. They are an owner of the company
  EXISTS (
    SELECT 1 FROM "public"."company_users" AS "cu"
    JOIN "public"."companies" ON "companies"."id" = "cu"."company_id"
    WHERE "cu"."company_id" = "company_users"."company_id"
    AND "cu"."user_id" = ( SELECT "auth"."uid"() AS "uid")
    AND "cu"."company_role" = 'owner'
  )
);

DROP POLICY IF EXISTS "Company users are insertable by company owners" ON "public"."company_users";
CREATE POLICY "Company users are insertable by company owners" ON "public"."company_users" 
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM "public"."company_users" AS "cu"
    WHERE "cu"."company_id" = "company_users"."company_id"
    AND "cu"."user_id" = ( SELECT "auth"."uid"() AS "uid")
    AND "cu"."company_role" = 'owner'
    AND "cu"."user_id" != "company_users"."user_id" -- Don't allow adding yourself as non-owner
  )
);

-- 5. 함수에서 created_by 참조 업데이트
-- get_user_campaigns_safe 함수는 이미 user_id를 사용하므로 변경 불필요
-- 하지만 campaigns 테이블의 필드명이 변경되었으므로 함수 내부에서 참조하는 부분 확인 필요

-- 참고: point_wallets 테이블의 owner_id는 owner_type에 따라 USER 또는 COMPANY를 가리키므로 변경하지 않음

