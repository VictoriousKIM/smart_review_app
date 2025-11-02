-- ============================================================================
-- Migration: 20250102000012_add_rejected_status_to_company_users.sql
-- ============================================================================
-- Description: company_users 테이블의 status에 'rejected' 값 추가
-- ============================================================================

-- status check constraint에 'rejected' 추가
ALTER TABLE "public"."company_users"
  DROP CONSTRAINT IF EXISTS "company_users_status_check";

ALTER TABLE "public"."company_users"
  ADD CONSTRAINT "company_users_status_check" 
  CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'pending'::"text", 'suspended'::"text", 'rejected'::"text"])));

-- 코멘트 업데이트
COMMENT ON COLUMN "public"."company_users"."status" IS '회사-사용자 관계 상태: active(활성), inactive(비활성), pending(대기), suspended(정지), rejected(거절)';

-- ============================================================================
-- End of Migration: 20250102000012_add_rejected_status_to_company_users.sql
-- ============================================================================

