-- campaigns 테이블에 max_per_reviewer 컬럼 추가
-- 목적: 리뷰어당 신청 가능 개수를 저장할 컬럼 추가

-- 컬럼 추가
ALTER TABLE public.campaigns 
ADD COLUMN IF NOT EXISTS max_per_reviewer INTEGER DEFAULT 1 NOT NULL;

-- 제약 조건 추가 (이미 존재하는 경우 제거 후 재추가)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'campaigns_max_per_reviewer_check'
    ) THEN
        ALTER TABLE public.campaigns DROP CONSTRAINT campaigns_max_per_reviewer_check;
    END IF;
END $$;

ALTER TABLE public.campaigns
ADD CONSTRAINT campaigns_max_per_reviewer_check 
CHECK (max_per_reviewer >= 1 AND max_per_reviewer <= max_participants);

-- 컬럼 코멘트 추가
COMMENT ON COLUMN public.campaigns.max_per_reviewer IS 
'리뷰어당 신청 가능 개수 (한 리뷰어가 해당 캠페인에 신청할 수 있는 최대 횟수)';

-- 기존 데이터 업데이트 (NULL 또는 0인 경우)
UPDATE public.campaigns 
SET max_per_reviewer = 1 
WHERE max_per_reviewer IS NULL OR max_per_reviewer < 1;

