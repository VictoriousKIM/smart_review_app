-- companies 테이블에 user_id 외래키 제약조건 추가 (확인 및 재생성)

-- 1. user_id 컬럼이 없으면 추가
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'companies' 
    AND column_name = 'user_id'
  ) THEN
    ALTER TABLE "public"."companies" 
      ADD COLUMN "user_id" uuid;
  END IF;
END $$;

-- 2. 기존 외래키 제약조건 확인 및 재생성
-- 기존 제약조건 제거 (있다면)
ALTER TABLE "public"."companies"
  DROP CONSTRAINT IF EXISTS "companies_created_by_fkey";

ALTER TABLE "public"."companies"
  DROP CONSTRAINT IF EXISTS "companies_user_id_fkey";

-- 외래키 제약조건 추가
ALTER TABLE "public"."companies"
  ADD CONSTRAINT "companies_user_id_fkey" 
  FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;

-- 3. 인덱스 확인 및 생성
CREATE INDEX IF NOT EXISTS "idx_companies_user_id" ON "public"."companies" USING "btree" ("user_id");

-- 4. 코멘트 추가 (명확성을 위해)
COMMENT ON COLUMN "public"."companies"."user_id" IS '회사를 등록한 사용자 ID (외래키: users.id)';

