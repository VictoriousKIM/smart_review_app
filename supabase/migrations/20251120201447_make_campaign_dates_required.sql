-- 마이그레이션: 캠페인 날짜 필드를 필수(NOT NULL)로 변경
-- 날짜: 2025-11-20
-- 설명: 
--   1. start_date, end_date, expiration_date를 NOT NULL로 변경
--   2. 기존 NULL 데이터 처리 (기본값 설정)
--   3. 날짜 순서 검증 제약 조건 추가

-- 1. 기존 NULL 데이터 처리
-- start_date가 NULL인 경우: created_at + 1일
UPDATE public.campaigns
SET start_date = created_at + INTERVAL '1 day'
WHERE start_date IS NULL;

-- end_date가 NULL인 경우: start_date + 7일
UPDATE public.campaigns
SET end_date = start_date + INTERVAL '7 days'
WHERE end_date IS NULL;

-- expiration_date가 NULL인 경우: end_date + 30일
UPDATE public.campaigns
SET expiration_date = end_date + INTERVAL '30 days'
WHERE expiration_date IS NULL;

-- 2. NOT NULL 제약 조건 추가
ALTER TABLE public.campaigns
  ALTER COLUMN start_date SET NOT NULL,
  ALTER COLUMN end_date SET NOT NULL,
  ALTER COLUMN expiration_date SET NOT NULL;

-- 3. CHECK 제약 조건 추가 (데이터 무결성: start_date <= end_date <= expiration_date)
ALTER TABLE public.campaigns
  DROP CONSTRAINT IF EXISTS campaigns_dates_check;

ALTER TABLE public.campaigns
  ADD CONSTRAINT campaigns_dates_check 
  CHECK (start_date <= end_date AND end_date <= expiration_date);

COMMENT ON CONSTRAINT campaigns_dates_check ON public.campaigns IS '캠페인 날짜 순서 검증: 시작일 <= 종료일 <= 만료일';

