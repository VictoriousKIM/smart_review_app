-- ============================================================================
-- Migration: Enhance campaigns table with detailed product and cost info
-- ============================================================================

-- 1. 캠페인 테이블에 새 필드 추가
ALTER TABLE campaigns
  ADD COLUMN IF NOT EXISTS keyword TEXT,
  ADD COLUMN IF NOT EXISTS option TEXT,
  ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 1,
  ADD COLUMN IF NOT EXISTS seller TEXT,
  ADD COLUMN IF NOT EXISTS product_number TEXT,
  ADD COLUMN IF NOT EXISTS payment_amount INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS purchase_method TEXT DEFAULT 'mobile',
  ADD COLUMN IF NOT EXISTS product_description TEXT,
  
  -- 리뷰 설정
  ADD COLUMN IF NOT EXISTS review_type TEXT DEFAULT 'star_only',
  ADD COLUMN IF NOT EXISTS review_text_length INTEGER DEFAULT 100,
  ADD COLUMN IF NOT EXISTS review_image_count INTEGER DEFAULT 0,
  
  -- 중복 방지 설정
  ADD COLUMN IF NOT EXISTS prevent_product_duplicate BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS prevent_store_duplicate BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS duplicate_prevent_days INTEGER DEFAULT 0,
  
  -- 비용 설정
  ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'platform',
  ADD COLUMN IF NOT EXISTS total_cost INTEGER NOT NULL DEFAULT 0;

-- 2. 제약조건 추가
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'campaigns_payment_method_check'
  ) THEN
    ALTER TABLE campaigns
      ADD CONSTRAINT campaigns_payment_method_check 
      CHECK (payment_method IN ('platform', 'direct'));
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'campaigns_purchase_method_check'
  ) THEN
    ALTER TABLE campaigns
      ADD CONSTRAINT campaigns_purchase_method_check 
      CHECK (purchase_method IN ('mobile', 'pc'));
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'campaigns_review_type_check'
  ) THEN
    ALTER TABLE campaigns
      ADD CONSTRAINT campaigns_review_type_check 
      CHECK (review_type IN ('star_only', 'star_text', 'star_text_image'));
  END IF;
END $$;

-- 3. 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_campaigns_keyword ON campaigns(keyword);
CREATE INDEX IF NOT EXISTS idx_campaigns_product_number ON campaigns(product_number);
CREATE INDEX IF NOT EXISTS idx_campaigns_seller ON campaigns(seller);
CREATE INDEX IF NOT EXISTS idx_campaigns_payment_method ON campaigns(payment_method);

-- 4. 코멘트
COMMENT ON COLUMN campaigns.keyword IS '검색 키워드';
COMMENT ON COLUMN campaigns.option IS '제품 옵션 (색상, 사이즈 등)';
COMMENT ON COLUMN campaigns.quantity IS '구매 개수';
COMMENT ON COLUMN campaigns.seller IS '판매자명';
COMMENT ON COLUMN campaigns.product_number IS '상품번호';
COMMENT ON COLUMN campaigns.payment_amount IS '결제금액 (원)';
COMMENT ON COLUMN campaigns.purchase_method IS '구매방법 (mobile/pc)';
COMMENT ON COLUMN campaigns.review_text_length IS '텍스트 리뷰 길이';
COMMENT ON COLUMN campaigns.prevent_product_duplicate IS '상품 중복 금지 여부';
COMMENT ON COLUMN campaigns.prevent_store_duplicate IS '스토어 중복 금지 여부';
COMMENT ON COLUMN campaigns.duplicate_prevent_days IS '중복 금지 기간 (일)';
COMMENT ON COLUMN campaigns.payment_method IS '지급 방법 (platform/direct)';
COMMENT ON COLUMN campaigns.total_cost IS '총 비용';

-- ============================================================================
-- RPC 함수: 비용 계산
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_campaign_cost(
  p_payment_method TEXT,
  p_payment_amount INTEGER,
  p_review_reward INTEGER,
  p_max_participants INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_payment_method = 'platform' THEN
    -- 플랫폼 지급: (결제금액 + 리뷰비 + 500) * 인원
    RETURN (p_payment_amount + p_review_reward + 500) * p_max_participants;
  ELSE
    -- 직접 지급: 500 * 인원
    RETURN 500 * p_max_participants;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION calculate_campaign_cost TO authenticated;

-- ============================================================================
-- RPC 함수: 캠페인 생성 (확장 버전)
-- ============================================================================

CREATE OR REPLACE FUNCTION create_campaign_with_points_v2(
  -- 필수 기본 정보
  p_title TEXT,
  p_description TEXT,
  p_campaign_type TEXT,
  p_review_reward INTEGER,
  p_max_participants INTEGER,
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ,
  
  -- 선택적 기본 정보
  p_platform TEXT DEFAULT NULL,
  p_platform_logo_url TEXT DEFAULT NULL,
  
  -- 상품 정보
  p_keyword TEXT DEFAULT NULL,
  p_option TEXT DEFAULT NULL,
  p_quantity INTEGER DEFAULT 1,
  p_seller TEXT DEFAULT NULL,
  p_product_number TEXT DEFAULT NULL,
  p_product_image_url TEXT DEFAULT NULL,
  
  -- 금액 정보
  p_payment_amount INTEGER DEFAULT 0,
  p_purchase_method TEXT DEFAULT 'mobile',
  
  -- 리뷰 설정
  p_product_description TEXT DEFAULT NULL,
  p_review_type TEXT DEFAULT 'star_only',
  p_review_text_length INTEGER DEFAULT 100,
  p_review_image_count INTEGER DEFAULT 0,
  
  -- 중복 방지
  p_prevent_product_duplicate BOOLEAN DEFAULT false,
  p_prevent_store_duplicate BOOLEAN DEFAULT false,
  p_duplicate_prevent_days INTEGER DEFAULT 0,
  
  -- 비용 설정
  p_payment_method TEXT DEFAULT 'platform'
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id UUID;
  v_company_id UUID;
  v_current_points INTEGER;
  v_total_cost INTEGER;
  v_campaign_id UUID;
  v_result JSONB;
BEGIN
  -- 1. 현재 사용자
  v_user_id := (SELECT auth.uid());
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  
  -- 2. 사용자의 활성 회사 조회
  SELECT cu.company_id INTO v_company_id
  FROM public.company_users cu
  WHERE cu.user_id = v_user_id
    AND cu.status = 'active'
    AND cu.company_role IN ('owner', 'manager')
  LIMIT 1;
  
  IF v_company_id IS NULL THEN
    RAISE EXCEPTION '회사에 소속되지 않았습니다';
  END IF;
  
  -- 3. 총 비용 계산
  v_total_cost := calculate_campaign_cost(
    p_payment_method,
    p_payment_amount,
    p_review_reward,
    p_max_participants
  );
  
  -- 4. 회사 지갑 조회 및 잔액 확인
  SELECT cw.current_points INTO v_current_points
  FROM public.company_wallets cw
  WHERE cw.company_id = v_company_id
  FOR UPDATE;
  
  IF v_current_points IS NULL THEN
    RAISE EXCEPTION '회사 지갑이 없습니다';
  END IF;
  
  IF v_current_points < v_total_cost THEN
    RAISE EXCEPTION '포인트가 부족합니다 (필요: %, 보유: %)', 
      v_total_cost, v_current_points;
  END IF;
  
  -- 5. 포인트 차감
  UPDATE public.company_wallets
  SET current_points = current_points - v_total_cost,
      updated_at = NOW()
  WHERE company_id = v_company_id;
  
  -- 6. 캠페인 생성
  INSERT INTO public.campaigns (
    title, description, company_id, user_id,
    campaign_type, platform, platform_logo_url,
    keyword, option, quantity, seller, product_number,
    product_image_url, payment_amount, purchase_method,
    product_description, review_type, review_text_length, review_image_count,
    review_reward, max_participants, current_participants,
    start_date, end_date,
    prevent_product_duplicate, prevent_store_duplicate, duplicate_prevent_days,
    payment_method, total_cost,
    status, created_at, updated_at
  ) VALUES (
    p_title, p_description, v_company_id, v_user_id,
    p_campaign_type, p_platform, p_platform_logo_url,
    p_keyword, p_option, p_quantity, p_seller, p_product_number,
    p_product_image_url, p_payment_amount, p_purchase_method,
    p_product_description, p_review_type, p_review_text_length, p_review_image_count,
    p_review_reward, p_max_participants, 0,
    p_start_date, p_end_date,
    p_prevent_product_duplicate, p_prevent_store_duplicate, p_duplicate_prevent_days,
    p_payment_method, v_total_cost,
    'active', NOW(), NOW()
  ) RETURNING id INTO v_campaign_id;
  
  -- 7. 포인트 로그 기록
  INSERT INTO public.company_point_logs (
    company_id, transaction_type, amount,
    description, related_entity_type, related_entity_id,
    created_by_user_id, created_at
  ) VALUES (
    v_company_id, 'spend', -v_total_cost,
    '캠페인 생성: ' || p_title,
    'campaign', v_campaign_id,
    v_user_id, NOW()
  );
  
  -- 8. 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'campaign_id', v_campaign_id,
    'total_cost', v_total_cost,
    'points_spent', v_total_cost,
    'remaining_points', v_current_points - v_total_cost
  ) INTO v_result;
  
  RETURN v_result;
  
EXCEPTION WHEN OTHERS THEN
  RAISE;
END;
$$;

GRANT EXECUTE ON FUNCTION create_campaign_with_points_v2 TO authenticated;

-- ============================================================================
-- 마이그레이션 완료
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ 캠페인 테이블 확장 완료!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📊 추가된 필드:';
  RAISE NOTICE '  - keyword, option, quantity';
  RAISE NOTICE '  - seller, product_number';
  RAISE NOTICE '  - payment_amount, purchase_method';
  RAISE NOTICE '  - prevent_product_duplicate, prevent_store_duplicate';
  RAISE NOTICE '  - duplicate_prevent_days';
  RAISE NOTICE '  - payment_method, total_cost';
  RAISE NOTICE '';
  RAISE NOTICE '🔧 생성된 RPC 함수:';
  RAISE NOTICE '  - calculate_campaign_cost()';
  RAISE NOTICE '  - create_campaign_with_points_v2()';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

