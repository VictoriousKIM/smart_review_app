-- product_provision_type 필드 COMMENT 업데이트
-- 한글로 저장: '실배송', '회수', 또는 사용자 입력 텍스트(5글자 이내)

COMMENT ON COLUMN "public"."campaigns"."product_provision_type" IS '상품 제공 방법: 실배송, 회수, 또는 사용자 입력 텍스트(5글자 이내)';

-- 기존 영어 데이터를 한글로 변환 (기존 데이터 마이그레이션)
UPDATE "public"."campaigns"
SET "product_provision_type" = CASE
  WHEN "product_provision_type" = 'delivery' THEN '실배송'
  WHEN "product_provision_type" = 'return' THEN '회수'
  WHEN "product_provision_type" = 'other' THEN '그외'
  ELSE "product_provision_type"  -- 이미 한글이거나 사용자 입력값인 경우 그대로 유지
END
WHERE "product_provision_type" IN ('delivery', 'return', 'other');

