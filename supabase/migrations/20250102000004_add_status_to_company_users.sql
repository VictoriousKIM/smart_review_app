-- Migration: Add status field to company_users table
-- Description: 회사-사용자 관계의 상태를 관리하기 위한 status 필드 추가

-- status 필드 추가 (기본값: 'active')
ALTER TABLE "public"."company_users"
  ADD COLUMN IF NOT EXISTS "status" text DEFAULT 'active' NOT NULL;

-- status 값 제약 조건 추가 (active, inactive, pending, suspended)
ALTER TABLE "public"."company_users"
  ADD CONSTRAINT "company_users_status_check" 
  CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'pending'::"text", 'suspended'::"text"])));

-- 기존 레코드의 status를 'active'로 설정 (NULL인 경우 대비)
UPDATE "public"."company_users"
SET "status" = 'active'
WHERE "status" IS NULL;

-- 코멘트 추가
COMMENT ON COLUMN "public"."company_users"."status" IS '회사-사용자 관계 상태: active(활성), inactive(비활성), pending(대기), suspended(정지)';

