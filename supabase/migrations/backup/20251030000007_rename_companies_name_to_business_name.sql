-- companies 테이블의 name 필드를 business_name으로 변경

-- 1. 컬럼명 변경
ALTER TABLE "public"."companies" 
  RENAME COLUMN "name" TO "business_name";

-- 2. 인덱스 업데이트
DROP INDEX IF EXISTS "public"."idx_companies_name";
CREATE INDEX IF NOT EXISTS "idx_companies_business_name" 
ON "public"."companies" 
USING "gin" ("to_tsvector"('"english"'::"regconfig", "business_name"));

-- 3. 코멘트 추가 (명확성을 위해)
COMMENT ON COLUMN "public"."companies"."business_name" IS '상호명 (사업자등록증의 상호명)';

