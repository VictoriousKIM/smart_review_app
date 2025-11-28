-- "리뷰어" → "스토어" 변경 마이그레이션
-- 기존 'reviewer' 값을 'store'로 변경

-- 1. campaigns 테이블의 CHECK 제약조건 제거
ALTER TABLE campaigns DROP CONSTRAINT IF EXISTS campaigns_campaign_type_check;

-- 2. 기존 데이터 업데이트
UPDATE campaigns SET campaign_type = 'store' WHERE campaign_type = 'reviewer';

-- 3. campaigns 테이블의 CHECK 제약조건 재추가
ALTER TABLE campaigns ADD CONSTRAINT campaigns_campaign_type_check 
  CHECK (campaign_type = ANY (ARRAY['store'::text, 'journalist'::text, 'visit'::text]));

-- 4. campaigns 테이블의 기본값 변경
ALTER TABLE campaigns ALTER COLUMN campaign_type SET DEFAULT 'store'::text;

