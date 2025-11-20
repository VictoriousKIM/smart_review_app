-- 마이그레이션: 캠페인 Status 제약 조건 변경 및 expiration_date 필드 추가
-- 날짜: 2025-01-16
-- 설명: 
--   1. Status 제약 조건을 'active', 'inactive'만 허용하도록 변경
--   2. expiration_date 필드 추가 (캠페인 만료일)
--   3. 기존 데이터 마이그레이션 (completed/cancelled -> inactive, expiration_date 기본값 설정)

-- 1. 기존 데이터 마이그레이션: completed/cancelled -> inactive
UPDATE public.campaigns
SET status = 'inactive'
WHERE status IN ('completed', 'cancelled');

-- 2. Status 제약 조건 변경
ALTER TABLE public.campaigns 
DROP CONSTRAINT IF EXISTS campaigns_status_check;

ALTER TABLE public.campaigns 
ADD CONSTRAINT campaigns_status_check 
CHECK (status = ANY (ARRAY['active'::text, 'inactive'::text]));

-- 3. expiration_date 필드 추가
ALTER TABLE public.campaigns 
ADD COLUMN IF NOT EXISTS expiration_date timestamp with time zone;

COMMENT ON COLUMN public.campaigns.expiration_date IS '캠페인 만료일 (종료일 이후 리뷰 등록 기간)';

-- 4. 기존 데이터의 expiration_date 기본값 설정 (end_date + 30일)
UPDATE public.campaigns
SET expiration_date = end_date + INTERVAL '30 days'
WHERE expiration_date IS NULL AND end_date IS NOT NULL;

-- 5. end_date가 없는 경우 created_at + 60일로 설정 (안전장치)
UPDATE public.campaigns
SET expiration_date = created_at + INTERVAL '60 days'
WHERE expiration_date IS NULL;

