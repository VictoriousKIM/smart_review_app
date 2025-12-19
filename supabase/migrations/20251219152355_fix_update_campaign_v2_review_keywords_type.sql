-- update_campaign_v2 함수의 p_review_keywords 파라미터 타입을 text에서 text[]로 변경
-- campaigns 테이블의 review_keywords 컬럼은 text[] 타입이므로 일치시켜야 함

CREATE OR REPLACE FUNCTION "public"."update_campaign_v2"(
  "p_campaign_id" "uuid",
  "p_title" "text",
  "p_description" "text",
  "p_campaign_type" "text",
  "p_campaign_reward" integer,
  "p_max_participants" integer,
  "p_max_per_reviewer" integer,
  "p_apply_start_date" timestamp with time zone,
  "p_apply_end_date" timestamp with time zone,
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
  "p_review_type" "text" DEFAULT 'star_only'::"text",
  "p_review_text_length" integer DEFAULT NULL::integer,
  "p_review_image_count" integer DEFAULT NULL::integer,
  "p_prevent_product_duplicate" boolean DEFAULT false,
  "p_prevent_store_duplicate" boolean DEFAULT false,
  "p_duplicate_prevent_days" integer DEFAULT 0,
  "p_payment_method" "text" DEFAULT 'platform'::"text",
  "p_review_start_date" timestamp with time zone DEFAULT NULL::timestamp with time zone,
  "p_review_end_date" timestamp with time zone DEFAULT NULL::timestamp with time zone,
  "p_review_keywords" "text"[] DEFAULT NULL::"text"[],  -- ✅ text[] 타입으로 변경
  "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_user_id UUID;
  v_company_id UUID;
  v_campaign_company_id UUID;
  v_created_at TIMESTAMPTZ;
  v_review_start_date TIMESTAMPTZ;
  v_review_end_date TIMESTAMPTZ;
  v_total_cost INTEGER;
BEGIN
  BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
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
    
    -- 3. 캠페인 소유권 확인 및 생성일자 조회
    SELECT company_id, created_at INTO v_campaign_company_id, v_created_at
    FROM public.campaigns
    WHERE id = p_campaign_id;
    
    IF v_campaign_company_id IS NULL THEN
      RAISE EXCEPTION '캠페인을 찾을 수 없습니다';
    END IF;
    
    IF v_campaign_company_id != v_company_id THEN
      RAISE EXCEPTION '이 캠페인을 수정할 권한이 없습니다';
    END IF;
    
    -- 4. 캠페인 상태 확인 (비활성화된 캠페인만 수정 가능)
    IF EXISTS (
      SELECT 1 FROM public.campaigns 
      WHERE id = p_campaign_id 
        AND status != 'inactive'
    ) THEN
      RAISE EXCEPTION '비활성화된 캠페인만 수정할 수 있습니다';
    END IF;
    
    -- 5. 신청자 확인 (신청자가 있으면 수정 불가)
    IF EXISTS (
      SELECT 1 FROM public.campaign_logs 
      WHERE campaign_id = p_campaign_id 
        AND action = 'join'
    ) THEN
      RAISE EXCEPTION '신청자가 있는 캠페인은 수정할 수 없습니다';
    END IF;
    
    -- 5.1. 필수 필드 검증
    IF p_product_name IS NULL OR p_product_name = '' THEN
      RAISE EXCEPTION '상품명은 필수입니다';
    END IF;
    
    IF p_product_price IS NULL THEN
      RAISE EXCEPTION '상품 가격은 필수입니다';
    END IF;
    
    IF p_product_image_url IS NULL OR p_product_image_url = '' THEN
      RAISE EXCEPTION '상품 이미지 URL은 필수입니다';
    END IF;
    
    IF p_seller IS NULL OR p_seller = '' THEN
      RAISE EXCEPTION '판매자명은 필수입니다';
    END IF;
    
    IF p_platform IS NULL OR p_platform = '' THEN
      RAISE EXCEPTION '플랫폼은 필수입니다';
    END IF;
    
    IF p_purchase_method IS NULL OR p_purchase_method = '' THEN
      RAISE EXCEPTION '구매방법은 필수입니다';
    END IF;
    
    IF p_review_type IS NULL OR p_review_type = '' THEN
      RAISE EXCEPTION '리뷰 타입은 필수입니다';
    END IF;
    
    IF p_payment_method IS NULL OR p_payment_method = '' THEN
      RAISE EXCEPTION '지급 방법은 필수입니다';
    END IF;
    
    -- 6. 날짜 검증 및 기본값 설정
    IF p_apply_start_date IS NULL OR p_apply_end_date IS NULL THEN
      RAISE EXCEPTION '신청 시작일시와 종료일시는 필수입니다';
    END IF;
    
    -- 생성일자 기준 날짜 범위 검증 (편집 시: 생성일자 ~ 생성일자 + 14일)
    IF p_apply_start_date < v_created_at THEN
      RAISE EXCEPTION '신청 시작일시는 캠페인 생성일자 이후여야 합니다';
    END IF;
    
    IF p_apply_start_date > v_created_at + INTERVAL '14 days' THEN
      RAISE EXCEPTION '신청 시작일시는 캠페인 생성일자로부터 14일 이내여야 합니다';
    END IF;
    
    IF p_apply_end_date > v_created_at + INTERVAL '14 days' THEN
      RAISE EXCEPTION '신청 종료일시는 캠페인 생성일자로부터 14일 이내여야 합니다';
    END IF;
    
    IF p_apply_start_date > p_apply_end_date THEN
      RAISE EXCEPTION '신청 시작일시는 종료일시보다 이전이어야 합니다';
    END IF;
    
    -- review_start_date 기본값: apply_end_date + 1일
    v_review_start_date := COALESCE(p_review_start_date, p_apply_end_date + INTERVAL '1 day');
    
    -- review_end_date 기본값: review_start_date + 30일
    v_review_end_date := COALESCE(p_review_end_date, v_review_start_date + INTERVAL '30 days');
    
    -- 날짜 순서 검증
    IF p_apply_end_date > v_review_start_date THEN
      RAISE EXCEPTION '신청 종료일시는 리뷰 시작일시보다 이전이어야 합니다';
    END IF;
    
    IF v_review_start_date > v_review_end_date THEN
      RAISE EXCEPTION '리뷰 시작일시는 종료일시보다 이전이어야 합니다';
    END IF;
    
    -- 리뷰 일정도 생성일자 + 14일 범위 내인지 검증
    IF v_review_start_date > v_created_at + INTERVAL '14 days' THEN
      RAISE EXCEPTION '리뷰 시작일시는 캠페인 생성일자로부터 14일 이내여야 합니다';
    END IF;
    
    IF v_review_end_date > v_created_at + INTERVAL '14 days' THEN
      RAISE EXCEPTION '리뷰 종료일시는 캠페인 생성일자로부터 14일 이내여야 합니다';
    END IF;
    
    -- 7. max_per_reviewer 검증
    IF COALESCE(p_max_per_reviewer, 1) > p_max_participants THEN
      RAISE EXCEPTION '리뷰어당 신청 가능 개수는 모집 인원을 넘을 수 없습니다';
    END IF;
    
    -- 8. 총 비용 계산 (기존 total_cost 업데이트용)
    v_total_cost := public.calculate_campaign_cost(
      p_payment_method,
      COALESCE(p_product_price, 0),
      p_campaign_reward,
      p_max_participants
    );
    
    -- 9. 캠페인 업데이트
    UPDATE public.campaigns SET
      title = p_title,
      description = p_description,
      campaign_type = p_campaign_type,
      platform = p_platform,
      keyword = p_keyword,
      "option" = p_option,
      quantity = COALESCE(p_quantity, 1),
      seller = p_seller,
      product_number = p_product_number,
      product_image_url = p_product_image_url,
      product_name = p_product_name,
      product_price = p_product_price,
      purchase_method = p_purchase_method,
      review_type = p_review_type,
      review_text_length = p_review_text_length,
      review_image_count = p_review_image_count,
      prevent_product_duplicate = p_prevent_product_duplicate,
      prevent_store_duplicate = p_prevent_store_duplicate,
      duplicate_prevent_days = p_duplicate_prevent_days,
      payment_method = p_payment_method,
      campaign_reward = p_campaign_reward,
      max_participants = p_max_participants,
      max_per_reviewer = COALESCE(p_max_per_reviewer, 1),
      apply_start_date = p_apply_start_date,
      apply_end_date = p_apply_end_date,
      review_start_date = v_review_start_date,
      review_end_date = v_review_end_date,
      total_cost = v_total_cost,
      review_keywords = p_review_keywords,  -- ✅ text[] 타입으로 직접 할당 가능
      updated_at = NOW()
    WHERE id = p_campaign_id;
    
    -- 10. 성공 응답 반환
    RETURN jsonb_build_object(
      'success', true,
      'campaign_id', p_campaign_id,
      'total_cost', v_total_cost
    );
    
  EXCEPTION
    WHEN OTHERS THEN
      -- 에러 로깅
      BEGIN
        INSERT INTO public.error_logs (error_message, error_context, created_at)
        VALUES (
          SQLERRM,
          jsonb_build_object(
            'function', 'update_campaign_v2',
            'user_id', v_user_id,
            'company_id', v_company_id,
            'campaign_id', p_campaign_id
          ),
          NOW()
        );
      EXCEPTION
        WHEN OTHERS THEN
          -- 로그 기록 실패는 무시 (무한 루프 방지)
          NULL;
      END;
      
      RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
      );
  END;
END;
$$;

COMMENT ON FUNCTION "public"."update_campaign_v2"("p_campaign_id" "uuid", "p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_campaign_reward" integer, "p_max_participants" integer, "p_max_per_reviewer" integer, "p_apply_start_date" timestamp with time zone, "p_apply_end_date" timestamp with time zone, "p_platform" "text", "p_keyword" "text", "p_option" "text", "p_quantity" integer, "p_seller" "text", "p_product_number" "text", "p_product_image_url" "text", "p_product_name" "text", "p_product_price" integer, "p_purchase_method" "text", "p_review_type" "text", "p_review_text_length" integer, "p_review_image_count" integer, "p_prevent_product_duplicate" boolean, "p_prevent_store_duplicate" boolean, "p_duplicate_prevent_days" integer, "p_payment_method" "text", "p_review_start_date" timestamp with time zone, "p_review_end_date" timestamp with time zone, "p_review_keywords" "text"[], "p_user_id" "uuid") IS '캠페인 업데이트 (비활성화된 캠페인만, 신청자 없을 때만). p_review_keywords는 text[] 타입입니다.';

