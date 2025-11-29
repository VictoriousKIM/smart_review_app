-- 최적화된 캠페인 조회 함수 (다음 오픈 시간 포함)
-- 이그레스 비용 최소화: 미래 캠페인 데이터를 전송하지 않고, 다음 오픈 시간만 반환

-- 캠페인 응답 타입 정의
CREATE TYPE campaign_response AS (
  campaigns jsonb,           -- 현재 활성 캠페인 리스트 (JSON)
  next_open_at timestamptz   -- 다음 오픈 예정 시간 (없으면 null)
);

-- 최적화된 캠페인 조회 함수
CREATE OR REPLACE FUNCTION get_active_campaigns_optimized()
RETURNS campaign_response
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result campaign_response;
  now_ts timestamptz := now();
BEGIN
  -- 1. 현재 모집중인 캠페인만 가져오기 (이미지, 텍스트 포함)
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', id,
      'title', title,
      'description', description,
      'product_image_url', product_image_url,
      'campaign_type', campaign_type,
      'platform', platform,
      'product_price', product_price,
      'campaign_reward', campaign_reward,
      'current_participants', current_participants,
      'max_participants', max_participants,
      'created_at', created_at,
      'apply_start_date', apply_start_date,
      'apply_end_date', apply_end_date,
      'review_start_date', review_start_date,
      'review_end_date', review_end_date,
      'seller', seller,
      'prevent_product_duplicate', prevent_product_duplicate,
      'prevent_store_duplicate', prevent_store_duplicate,
      'duplicate_prevent_days', duplicate_prevent_days,
      'status', status,
      'company_id', company_id
    )
  ) INTO result.campaigns
  FROM campaigns
  WHERE status = 'active'
    AND apply_start_date <= now_ts
    AND apply_end_date > now_ts
    AND (max_participants IS NULL OR current_participants < max_participants);
    -- Phase 3 진행 시: apply_start_date <= now_ts + interval '1 hour' 로 변경 필요

  -- 2. 가장 가까운 "오픈 예정" 시간 계산 (데이터는 안 가져옴, 시간만!)
  SELECT MIN(apply_start_date) INTO result.next_open_at
  FROM campaigns
  WHERE status = 'active'
    AND apply_start_date > now_ts;

  RETURN result;
END;
$$;

-- 함수 설명 추가
COMMENT ON FUNCTION get_active_campaigns_optimized() IS 
'현재 활성화된 캠페인 리스트와 다음 오픈 예정 시간을 반환합니다. 이그레스 비용 최소화를 위해 미래 캠페인 데이터는 전송하지 않고 시간만 반환합니다.';

