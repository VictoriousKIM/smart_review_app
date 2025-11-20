-- 캠페인 중복 체크 성능 최적화를 위한 인덱스 추가

-- campaign_action_logs 테이블 인덱스
-- 사용자별 상태별 조회 최적화
CREATE INDEX IF NOT EXISTS idx_campaign_action_logs_user_status 
ON campaign_action_logs(user_id, status);

-- 캠페인별 사용자별 조회 최적화
CREATE INDEX IF NOT EXISTS idx_campaign_action_logs_campaign_user 
ON campaign_action_logs(campaign_id, user_id);

-- campaigns 테이블 인덱스
-- 상품 중복 체크를 위한 title 인덱스
CREATE INDEX IF NOT EXISTS idx_campaigns_title 
ON campaigns(title) WHERE title IS NOT NULL;

-- 스토어 중복 체크를 위한 seller 인덱스
CREATE INDEX IF NOT EXISTS idx_campaigns_seller 
ON campaigns(seller) WHERE seller IS NOT NULL;

-- 중복 금지 설정이 있는 캠페인 조회 최적화
CREATE INDEX IF NOT EXISTS idx_campaigns_duplicate_prevent 
ON campaigns(prevent_product_duplicate, prevent_store_duplicate) 
WHERE prevent_product_duplicate = true OR prevent_store_duplicate = true;

