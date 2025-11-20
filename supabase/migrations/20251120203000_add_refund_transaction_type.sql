-- 마이그레이션: 포인트 트랜잭션 타입에 'refund' 추가
-- 날짜: 2025-11-20
-- 설명: 캠페인 삭제 시 포인트 환불을 위한 'refund' 타입 추가

-- 1. 기존 제약 조건 제거
ALTER TABLE public.point_transactions
  DROP CONSTRAINT IF EXISTS point_transactions_transaction_type_check;

-- 2. 새로운 제약 조건 추가 (refund 포함)
ALTER TABLE public.point_transactions
  ADD CONSTRAINT point_transactions_transaction_type_check 
  CHECK (transaction_type = ANY (ARRAY['earn'::text, 'spend'::text, 'refund'::text]));

COMMENT ON COLUMN public.point_transactions.transaction_type IS '거래 타입: earn(적립), spend(사용), refund(환불)';

-- 참고: point_transactions_campaign_check 제약 조건은 이미 refund 타입을 허용하도록 설정되어 있음
-- (transaction_type <> 'spend'이면 campaign_id가 NULL이어도 됨)

