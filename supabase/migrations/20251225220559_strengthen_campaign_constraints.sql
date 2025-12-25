-- Campaigns 테이블 제약 강화
-- 1. platform: '쿠팡', 'N스토어'만 허용, NOT NULL
-- 2. payment_method: 이미 제약 있음 ('platform', 'direct')
-- 3. product_provision_type: NOT NULL (값 제한 없음, 사용자 입력 텍스트 허용)

-- 1. 기존 NULL 값 처리
-- platform 필드: NULL 또는 빈 문자열을 '쿠팡'으로 설정
UPDATE "public"."campaigns"
SET "platform" = '쿠팡'
WHERE "platform" IS NULL OR "platform" = '';

-- product_provision_type 필드: NULL을 '실배송'으로 설정
UPDATE "public"."campaigns"
SET "product_provision_type" = '실배송'
WHERE "product_provision_type" IS NULL;

-- 2. platform 필드 제약 추가
-- CHECK 제약: '쿠팡', 'N스토어'만 허용
ALTER TABLE "public"."campaigns"
DROP CONSTRAINT IF EXISTS "campaigns_platform_check";

ALTER TABLE "public"."campaigns"
ADD CONSTRAINT "campaigns_platform_check" CHECK (
    "platform" = ANY (ARRAY['쿠팡'::"text", 'N스토어'::"text"])
);

-- NOT NULL 제약 및 기본값 설정
ALTER TABLE "public"."campaigns"
ALTER COLUMN "platform" SET NOT NULL,
ALTER COLUMN "platform" SET DEFAULT '쿠팡';

-- 3. product_provision_type 필드 NOT NULL 제약 추가
ALTER TABLE "public"."campaigns"
ALTER COLUMN "product_provision_type" SET NOT NULL;

-- 4. payment_method 필드 NOT NULL 제약 추가 (이미 기본값이 있지만 명시적으로)
ALTER TABLE "public"."campaigns"
ALTER COLUMN "payment_method" SET NOT NULL;

-- 5. 코멘트 업데이트
COMMENT ON COLUMN "public"."campaigns"."platform" IS '플랫폼 (쿠팡, N스토어)';
COMMENT ON COLUMN "public"."campaigns"."product_provision_type" IS '상품 제공 방법: 실배송, 회수, 또는 사용자 입력 텍스트(5글자 이내)';
COMMENT ON COLUMN "public"."campaigns"."payment_method" IS '지급 방법 (platform: 플랫폼지급, direct: 광고사지급)';

