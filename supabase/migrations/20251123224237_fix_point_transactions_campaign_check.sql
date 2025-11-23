-- 캠페인 삭제 시 제약 조건 위반 오류 해결
-- 캠페인이 삭제되면 더 이상 볼 필요가 없으므로, 기존 'spend' 트랜잭션의 campaign_id가 NULL로 변경되어도 문제 없음
-- 애플리케이션 레벨 검증(create_point_transaction 함수)으로 새로 생성되는 트랜잭션의 무결성 보장

-- 기존 제약 조건 삭제
ALTER TABLE public.point_transactions 
DROP CONSTRAINT IF EXISTS point_transactions_campaign_check;

-- 제약 조건 완전 제거
-- 새로 생성되는 'spend' 트랜잭션은 create_point_transaction 함수에서 campaign_id 필수로 검증됨
-- 캠페인 삭제로 인한 기존 트랜잭션의 campaign_id NULL 변경은 허용

COMMENT ON TABLE public.point_transactions IS 
'포인트 거래 테이블 (earn, spend, refund). 새로 생성되는 company spend는 create_point_transaction 함수에서 campaign_id 필수로 검증됨';

