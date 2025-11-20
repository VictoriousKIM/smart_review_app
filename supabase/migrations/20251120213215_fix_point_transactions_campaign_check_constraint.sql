-- 마이그레이션: point_transactions_campaign_check 제약 조건 수정
-- 날짜: 2025-11-20
-- 설명: 'refund' 타입 추가에 따른 campaign_check 제약 조건 수정
--       'refund' 타입은 campaign_id가 NULL이어도 됨 (캠페인 삭제 후 NULL로 변경될 수 있음)

-- 1. 기존 제약 조건 제거
ALTER TABLE public.point_transactions
  DROP CONSTRAINT IF EXISTS point_transactions_campaign_check;

-- 2. 새로운 제약 조건 추가
-- 'spend' 타입만 campaign_id가 필수, 'earn'과 'refund'는 선택적
ALTER TABLE public.point_transactions
  ADD CONSTRAINT point_transactions_campaign_check 
  CHECK (
    (transaction_type <> 'spend'::text) OR 
    ((transaction_type = 'spend'::text) AND (campaign_id IS NOT NULL))
  );

COMMENT ON CONSTRAINT point_transactions_campaign_check ON public.point_transactions 
IS '캠페인 ID 제약: spend 타입만 campaign_id 필수, earn/refund는 선택적';

