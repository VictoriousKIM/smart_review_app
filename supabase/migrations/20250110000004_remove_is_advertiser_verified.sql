-- is_advertiser_verified 컬럼 제거
-- company_id가 있으면 광고주로 판단하도록 변경

-- users 테이블에서 is_advertiser_verified 컬럼 제거
ALTER TABLE "public"."users" DROP COLUMN IF EXISTS "is_advertiser_verified";

-- 기존 데이터 정리 (company_id가 있으면 광고주로 간주)
-- 이미 company_id로 판단하므로 별도 작업 불필요
