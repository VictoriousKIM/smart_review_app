-- 마이그레이션: review_cost와 review_reward를 campaign_reward로 통합
-- 날짜: 2025-11-20
-- 설명: 
--   1. campaign_reward 필드 추가
--   2. 기존 데이터 마이그레이션 (review_reward 우선, 없으면 review_cost 사용)
--   3. review_cost와 review_reward 필드 삭제
--   4. 인덱스 업데이트
--   5. RPC 함수 업데이트

-- 1. campaign_reward 필드 추가
ALTER TABLE public.campaigns 
ADD COLUMN IF NOT EXISTS campaign_reward integer;

-- 2. 기존 데이터 마이그레이션 (review_reward 우선, 없으면 review_cost 사용)
UPDATE public.campaigns
SET campaign_reward = COALESCE(review_reward, review_cost, 0)
WHERE campaign_reward IS NULL;

-- 3. campaign_reward를 NOT NULL로 변경
ALTER TABLE public.campaigns 
ALTER COLUMN campaign_reward SET NOT NULL;

-- 4. 기본값 설정
ALTER TABLE public.campaigns 
ALTER COLUMN campaign_reward SET DEFAULT 0;

-- 5. 기존 인덱스 삭제
DROP INDEX IF EXISTS public.idx_campaigns_review_cost;

-- 6. 새로운 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_campaigns_campaign_reward 
ON public.campaigns USING btree (campaign_reward);

-- 7. review_cost와 review_reward 필드 삭제
ALTER TABLE public.campaigns 
DROP COLUMN IF EXISTS review_cost;

ALTER TABLE public.campaigns 
DROP COLUMN IF EXISTS review_reward;

-- 8. calculate_campaign_cost 함수 삭제 후 재생성 (파라미터 이름 변경)
DROP FUNCTION IF EXISTS "public"."calculate_campaign_cost"("p_payment_method" "text", "p_payment_amount" integer, "p_review_reward" integer, "p_max_participants" integer);

CREATE FUNCTION "public"."calculate_campaign_cost"(
  "p_payment_method" "text", 
  "p_payment_amount" integer, 
  "p_campaign_reward" integer, 
  "p_max_participants" integer
) RETURNS integer
LANGUAGE "plpgsql"
AS $$
BEGIN
  IF p_payment_method = 'platform' THEN
    -- 플랫폼 지급: (결제금액 + 캠페인 리워드 + 500) * 인원
    RETURN (p_payment_amount + p_campaign_reward + 500) * p_max_participants;
  ELSE
    -- 직접 지급: 500 * 인원
    RETURN 500 * p_max_participants;
  END IF;
END;
$$;

-- 9. create_campaign_with_points 함수 삭제 후 재생성 (파라미터 이름 변경)
DROP FUNCTION IF EXISTS "public"."create_campaign_with_points"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_product_price" integer, "p_review_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_product_image_url" "text", "p_platform" "text");

CREATE FUNCTION "public"."create_campaign_with_points"(
  "p_title" "text", 
  "p_description" "text", 
  "p_campaign_type" "text", 
  "p_product_price" integer, 
  "p_campaign_reward" integer, 
  "p_max_participants" integer, 
  "p_start_date" timestamp with time zone, 
  "p_end_date" timestamp with time zone, 
  "p_product_image_url" "text" DEFAULT NULL::"text", 
  "p_platform" "text" DEFAULT NULL::"text"
) RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
  v_user_id UUID;
  v_company_id UUID;
  v_wallet_id UUID;
  v_current_points INTEGER;
  v_total_cost INTEGER;
  v_campaign_id UUID;
  v_result JSONB;
  v_points_before_deduction INTEGER;
  v_points_after_deduction INTEGER;
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
  v_total_cost := public.calculate_campaign_cost(
    'platform',
    COALESCE(p_product_price, 0),
    p_campaign_reward,
    p_max_participants
  );
  
  -- 4. 회사 지갑 조회 및 잠금
  SELECT cw.id, cw.current_points 
  INTO v_wallet_id, v_current_points
  FROM public.wallets AS cw
  WHERE cw.company_id = v_company_id
    AND cw.user_id IS NULL
  FOR UPDATE NOWAIT;
  
  IF v_wallet_id IS NULL OR v_current_points IS NULL THEN
    RAISE EXCEPTION '회사 지갑이 없습니다';
  END IF;
  
  -- 5. 잔액 확인
  v_points_before_deduction := v_current_points;
  
  IF v_current_points < v_total_cost THEN
    RAISE EXCEPTION '포인트가 부족합니다 (필요: %, 보유: %)', 
      v_total_cost, v_current_points;
  END IF;
  
  -- 6. 캠페인 생성
  INSERT INTO public.campaigns (
    title, description, company_id, user_id,
    campaign_type, platform,
    product_image_url, product_price,
    campaign_reward, max_participants, current_participants,
    start_date, end_date,
    status, created_at, updated_at
  ) VALUES (
    p_title, p_description, v_company_id, v_user_id,
    p_campaign_type, p_platform,
    p_product_image_url, p_product_price,
    p_campaign_reward, p_max_participants, 0,
    p_start_date, p_end_date,
    'active', NOW(), NOW()
  ) RETURNING id INTO v_campaign_id;
  
  -- 7. 포인트 로그 기록
  INSERT INTO public.point_transactions (
    wallet_id, transaction_type, amount,
    campaign_id, description,
    created_by_user_id, created_at
  ) VALUES (
    v_wallet_id, 'spend', -v_total_cost,
    v_campaign_id, '캠페인 생성: ' || p_title,
    v_user_id, NOW()
  );
  
  -- 8. 차감 후 잔액 확인
  SELECT current_points INTO v_points_after_deduction
  FROM public.wallets
  WHERE id = v_wallet_id;
  
  IF v_points_after_deduction != (v_points_before_deduction - v_total_cost) THEN
    RAISE EXCEPTION '포인트 차감이 정확하지 않습니다. (예상: %, 실제: %)', 
      v_points_before_deduction - v_total_cost, v_points_after_deduction;
  END IF;
  
  -- 9. 결과 반환
  RETURN jsonb_build_object(
    'success', true,
    'campaign_id', v_campaign_id,
    'points_spent', v_total_cost
  );
END;
$$;

-- 10. create_campaign_with_points_v2 함수 삭제 후 재생성 (파라미터 이름 변경)
DROP FUNCTION IF EXISTS "public"."create_campaign_with_points_v2"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_review_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_platform" "text", "p_keyword" "text", "p_option" "text", "p_quantity" integer, "p_seller" "text", "p_product_number" "text", "p_product_image_url" "text", "p_product_name" "text", "p_product_price" integer, "p_purchase_method" "text", "p_product_description" "text", "p_review_type" "text", "p_review_text_length" integer, "p_review_image_count" integer, "p_prevent_product_duplicate" boolean, "p_prevent_store_duplicate" boolean, "p_duplicate_prevent_days" integer, "p_payment_method" "text", "p_expiration_date" timestamp with time zone);

CREATE FUNCTION "public"."create_campaign_with_points_v2"(
  "p_title" "text", 
  "p_description" "text", 
  "p_campaign_type" "text", 
  "p_campaign_reward" integer, 
  "p_max_participants" integer, 
  "p_start_date" timestamp with time zone, 
  "p_end_date" timestamp with time zone, 
  "p_platform" "text" DEFAULT NULL::"text", 
  "p_keyword" "text" DEFAULT NULL::"text", 
  "p_option" "text" DEFAULT NULL::"text", 
  "p_quantity" integer DEFAULT 1, 
  "p_seller" "text" DEFAULT NULL::"text", 
  "p_product_number" "text" DEFAULT NULL::"text", 
  "p_product_image_url" "text" DEFAULT NULL::"text", 
  "p_product_name" "text" DEFAULT NULL::"text", 
  "p_product_price" integer DEFAULT NULL::integer, 
  "p_purchase_method" "text" DEFAULT 'mobile'::"text", 
  "p_product_description" "text" DEFAULT NULL::"text", 
  "p_review_type" "text" DEFAULT 'star_only'::"text", 
  "p_review_text_length" integer DEFAULT NULL::integer, 
  "p_review_image_count" integer DEFAULT NULL::integer, 
  "p_prevent_product_duplicate" boolean DEFAULT false, 
  "p_prevent_store_duplicate" boolean DEFAULT false, 
  "p_duplicate_prevent_days" integer DEFAULT 0, 
  "p_payment_method" "text" DEFAULT 'platform'::"text", 
  "p_expiration_date" timestamp with time zone DEFAULT NULL::timestamp with time zone
) RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
  v_user_id UUID;
  v_company_id UUID;
  v_wallet_id UUID;
  v_current_points INTEGER;
  v_total_cost INTEGER;
  v_campaign_id UUID;
  v_result JSONB;
  v_points_before_deduction INTEGER;
  v_points_after_deduction INTEGER;
BEGIN
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
    v_total_cost := public.calculate_campaign_cost(
      p_payment_method,
      COALESCE(p_product_price, 0),
      p_campaign_reward,
      p_max_participants
    );
    
    -- 4. 회사 지갑 조회 및 잠금
    SELECT cw.id, cw.current_points 
    INTO v_wallet_id, v_current_points
    FROM public.wallets AS cw
    WHERE cw.company_id = v_company_id
      AND cw.user_id IS NULL
    FOR UPDATE NOWAIT;
    
    IF v_wallet_id IS NULL OR v_current_points IS NULL THEN
      RAISE EXCEPTION '회사 지갑이 없습니다';
    END IF;
    
    -- 5. 잔액 확인
    v_points_before_deduction := v_current_points;
    
    IF v_current_points < v_total_cost THEN
      RAISE EXCEPTION '포인트가 부족합니다 (필요: %, 보유: %)', 
        v_total_cost, v_current_points;
    END IF;
    
    -- 6. 캠페인 생성
    INSERT INTO public.campaigns (
      title, description, company_id, user_id,
      campaign_type, platform,
      keyword, option, quantity, seller, product_number,
      product_image_url, product_name, product_price,
      purchase_method,
      review_type, review_text_length, review_image_count,
      campaign_reward, max_participants, current_participants,
      start_date, end_date, expiration_date,
      prevent_product_duplicate, prevent_store_duplicate, duplicate_prevent_days,
      payment_method, total_cost,
      status, created_at, updated_at
    ) VALUES (
      p_title, p_description, v_company_id, v_user_id,
      p_campaign_type, p_platform,
      p_keyword, p_option, p_quantity, p_seller, p_product_number,
      p_product_image_url, p_product_name, p_product_price,
      p_purchase_method,
      p_review_type, p_review_text_length, p_review_image_count,
      p_campaign_reward, p_max_participants, 0,
      p_start_date, p_end_date, 
      COALESCE(p_expiration_date, p_end_date + INTERVAL '30 days'),
      p_prevent_product_duplicate, p_prevent_store_duplicate, p_duplicate_prevent_days,
      p_payment_method, v_total_cost,
      'active', NOW(), NOW()
    ) RETURNING id INTO v_campaign_id;
    
    -- 7. 포인트 로그 기록
    INSERT INTO public.point_transactions (
      wallet_id, transaction_type, amount,
      campaign_id, description,
      created_by_user_id, created_at
    ) VALUES (
      v_wallet_id, 'spend', -v_total_cost,
      v_campaign_id, '캠페인 생성: ' || p_title,
      v_user_id, NOW()
    );
    
    -- 8. 차감 후 잔액 확인
    SELECT current_points INTO v_points_after_deduction
    FROM public.wallets
    WHERE id = v_wallet_id;
    
    IF v_points_after_deduction != (v_points_before_deduction - v_total_cost) THEN
      RAISE EXCEPTION '포인트 차감이 정확하지 않습니다. (예상: %, 실제: %)', 
        v_points_before_deduction - v_total_cost, v_points_after_deduction;
    END IF;
    
    -- 9. 결과 반환
    RETURN jsonb_build_object(
      'success', true,
      'campaign_id', v_campaign_id,
      'points_spent', v_total_cost
    );
  EXCEPTION
    WHEN OTHERS THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
      );
  END;
END;
$$;

COMMENT ON COLUMN public.campaigns.campaign_reward IS '캠페인 리워드 (review_cost와 review_reward 통합)';

