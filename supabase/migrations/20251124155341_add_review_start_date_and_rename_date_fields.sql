-- 캠페인 날짜 필드 세분화 및 구체화
-- 1. review_start_date 컬럼 추가
-- 2. 기존 필드명 변경: start_date -> apply_start_date, end_date -> apply_end_date, expiration_date -> review_end_date
-- 3. 제약 조건 수정

-- 1. review_start_date 컬럼 추가 (NULL 허용)
ALTER TABLE public.campaigns 
ADD COLUMN IF NOT EXISTS review_start_date TIMESTAMPTZ;

-- 2. 기존 필드명 변경을 위한 새 컬럼 추가
ALTER TABLE public.campaigns 
ADD COLUMN IF NOT EXISTS apply_start_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS apply_end_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS review_end_date TIMESTAMPTZ;

-- 3. 기존 데이터 복사
UPDATE public.campaigns 
SET 
    apply_start_date = COALESCE(apply_start_date, start_date),
    apply_end_date = COALESCE(apply_end_date, end_date),
    review_start_date = COALESCE(review_start_date, end_date),  -- 기본값: 신청 종료일시 = 리뷰 시작일시
    review_end_date = COALESCE(review_end_date, expiration_date)
WHERE apply_start_date IS NULL OR apply_end_date IS NULL OR review_start_date IS NULL OR review_end_date IS NULL;

-- 4. NOT NULL 제약 조건 추가
ALTER TABLE public.campaigns 
ALTER COLUMN apply_start_date SET NOT NULL,
ALTER COLUMN apply_end_date SET NOT NULL,
ALTER COLUMN review_start_date SET NOT NULL,
ALTER COLUMN review_end_date SET NOT NULL;

-- 5. 기존 제약 조건 삭제
ALTER TABLE public.campaigns 
DROP CONSTRAINT IF EXISTS campaigns_dates_check;

-- 6. 새로운 제약 조건 추가 (4개 필드 간 검증)
ALTER TABLE public.campaigns 
ADD CONSTRAINT campaigns_dates_check CHECK (
    apply_start_date <= apply_end_date 
    AND apply_end_date <= review_start_date 
    AND review_start_date <= review_end_date
);

-- 7. 제약 조건 코멘트 업데이트
COMMENT ON CONSTRAINT campaigns_dates_check ON public.campaigns IS 
'캠페인 날짜 순서 검증: 신청 시작일시 <= 신청 종료일시 <= 리뷰 시작일시 <= 리뷰 종료일시';

-- 8. 컬럼 코멘트 추가
COMMENT ON COLUMN public.campaigns.apply_start_date IS '신청 시작일시';
COMMENT ON COLUMN public.campaigns.apply_end_date IS '신청 종료일시';
COMMENT ON COLUMN public.campaigns.review_start_date IS '리뷰 시작일시';
COMMENT ON COLUMN public.campaigns.review_end_date IS '리뷰 종료일시';

