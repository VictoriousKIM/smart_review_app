-- 마이그레이션: company_users.company_role에 'reviewer' 추가
-- 
-- 목적: company_users 테이블의 company_role 제약조건에 'reviewer' 값을 추가하여
--       회사에 속한 리뷰어를 구분할 수 있도록 함
--
-- 안전성:
-- - 기존 데이터에 영향 없음 (기존 owner, manager 값은 그대로 유지)
-- - 트랜잭션으로 감싸서 실패 시 롤백 가능
-- - 제약조건만 변경하므로 데이터 손실 없음

BEGIN;

-- 1. 기존 제약조건 삭제
ALTER TABLE "public"."company_users" 
DROP CONSTRAINT IF EXISTS "company_users_company_role_check";

-- 2. 새로운 제약조건 추가 (owner, manager, reviewer 포함)
ALTER TABLE "public"."company_users" 
ADD CONSTRAINT "company_users_company_role_check" 
CHECK (("company_role" = ANY (ARRAY['owner'::"text", 'manager'::"text", 'reviewer'::"text"])));

-- 3. 제약조건에 대한 설명 추가
COMMENT ON CONSTRAINT "company_users_company_role_check" ON "public"."company_users" IS 
'company_role은 owner(회사 소유자), manager(회사 관리자), reviewer(리뷰어) 중 하나여야 합니다. owner와 manager는 광고주, reviewer는 리뷰어입니다.';

COMMIT;

