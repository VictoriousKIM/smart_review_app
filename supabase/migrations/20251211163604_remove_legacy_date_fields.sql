-- 레거시 날짜 필드 제거 마이그레이션
-- start_date, end_date, expiration_date 필드 제거

-- 1. create_campaign_with_points_v2 함수에서 레거시 필드 INSERT 제거
CREATE OR REPLACE FUNCTION "public"."create_campaign_with_points_v2"(
    "p_title" "text",
    "p_description" "text",
    "p_campaign_type" "text",
    "p_campaign_reward" integer,
    "p_max_participants" integer,
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
    "p_product_description" "text" DEFAULT NULL::"text",
    "p_review_type" "text" DEFAULT 'star_only'::"text",
    "p_review_text_length" integer DEFAULT NULL::integer,
    "p_review_image_count" integer DEFAULT NULL::integer,
    "p_prevent_product_duplicate" boolean DEFAULT false,
    "p_prevent_store_duplicate" boolean DEFAULT false,
    "p_duplicate_prevent_days" integer DEFAULT 0,
    "p_payment_method" "text" DEFAULT 'platform'::"text",
    "p_review_start_date" timestamp with time zone DEFAULT NULL::timestamp with time zone,
    "p_review_end_date" timestamp with time zone DEFAULT NULL::timestamp with time zone,
    "p_max_per_reviewer" integer DEFAULT 1,
    "p_review_keywords" "text"[] DEFAULT NULL::"text"[],
    "p_user_id" "uuid" DEFAULT NULL::"uuid"
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
  v_points_before_deduction INTEGER;
  v_points_after_deduction INTEGER;
  v_review_start_date TIMESTAMPTZ;
  v_review_end_date TIMESTAMPTZ;
BEGIN
  
  -- 1. 사용자 ID 확인
  v_user_id := COALESCE(p_user_id, auth.uid());
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다';
  END IF;
  
  -- 2. 회사 ID 확인
  SELECT company_id INTO v_company_id
  FROM public.company_users
  WHERE user_id = v_user_id
    AND company_role IN ('owner', 'manager')
    AND status = 'active'
  LIMIT 1;
  
  IF v_company_id IS NULL THEN
    RAISE EXCEPTION '회사 소유자 또는 관리자 권한이 필요합니다';
  END IF;
  
  -- 2.1. 날짜 검증 및 기본값 설정
  IF p_apply_start_date IS NULL OR p_apply_end_date IS NULL THEN
    RAISE EXCEPTION '신청 시작일시와 종료일시는 필수입니다';
  END IF;
  
  -- 현재 시간 기준 날짜 범위 검증 (생성 시: 현재 시간 ~ +14일)
  IF p_apply_start_date < NOW() THEN
    RAISE EXCEPTION '신청 시작일시는 현재 시간 이후여야 합니다';
  END IF;
  
  IF p_apply_start_date > NOW() + INTERVAL '14 days' THEN
    RAISE EXCEPTION '신청 시작일시는 현재 시간으로부터 14일 이내여야 합니다';
  END IF;
  
  IF p_apply_end_date > NOW() + INTERVAL '14 days' THEN
    RAISE EXCEPTION '신청 종료일시는 현재 시간으로부터 14일 이내여야 합니다';
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
  
  -- 리뷰 일정도 14일 범위 내인지 검증
  IF v_review_start_date > NOW() + INTERVAL '14 days' THEN
    RAISE EXCEPTION '리뷰 시작일시는 현재 시간으로부터 14일 이내여야 합니다';
  END IF;
  
  IF v_review_end_date > NOW() + INTERVAL '14 days' THEN
    RAISE EXCEPTION '리뷰 종료일시는 현재 시간으로부터 14일 이내여야 합니다';
  END IF;
  
  -- 2.5. max_per_reviewer 검증 (max_participants를 넘지 않아야 함)
  IF COALESCE(p_max_per_reviewer, 1) > p_max_participants THEN
    RAISE EXCEPTION '리뷰어당 신청 가능 개수는 모집 인원을 넘을 수 없습니다 (모집 인원: %, 신청 가능 개수: %)', 
      p_max_participants, COALESCE(p_max_per_reviewer, 1);
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
  
  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION '회사 지갑을 찾을 수 없습니다';
  END IF;
  
  -- 5. 잔액 확인 (비용이 0보다 클 때만)
  IF v_total_cost > 0 THEN
    IF v_current_points < v_total_cost THEN
      RAISE EXCEPTION '잔액이 부족합니다 (필요: % P, 현재: % P)', v_total_cost, v_current_points;
    END IF;
    
    -- 차감 후 잔액이 0 이상인지 확인 (마이너스 방지, 0은 허용)
    IF (v_current_points - v_total_cost) < 0 THEN
      RAISE EXCEPTION '포인트 차감 후 잔액이 마이너스가 될 수 없습니다 (현재: % P, 필요: % P, 차감 후: % P)', 
        v_current_points, v_total_cost, v_current_points - v_total_cost;
    END IF;
  END IF;
  
  -- 6. 포인트 차감 전 잔액 저장
  v_points_before_deduction := v_current_points;
  
  -- 7. 포인트 차감 (비용이 0보다 클 때만)
  IF v_total_cost > 0 THEN
    UPDATE public.wallets
    SET current_points = current_points - v_total_cost,
        updated_at = NOW()
    WHERE id = v_wallet_id;
    
    -- 8. 차감 후 잔액 조회
    SELECT current_points INTO v_points_after_deduction
    FROM public.wallets
    WHERE id = v_wallet_id;
    
    -- 차감 후 잔액이 0 이상인지 재확인 (안전장치)
    IF v_points_after_deduction < 0 THEN
      RAISE EXCEPTION '포인트 차감 후 잔액이 마이너스입니다 (잔액: % P). 롤백이 필요합니다.', v_points_after_deduction;
    END IF;
  ELSE
    -- 비용이 0이면 차감 후 잔액은 차감 전과 동일
    v_points_after_deduction := v_points_before_deduction;
  END IF;
  
  -- 9. 캠페인 생성 (레거시 필드 제거)
  INSERT INTO public.campaigns (
    title,
    description,
    company_id,
    campaign_type,
    platform,
    keyword,
    "option",
    quantity,
    seller,
    product_number,
    product_image_url,
    product_name,
    product_price,
    purchase_method,
    review_type,
    review_text_length,
    review_image_count,
    prevent_product_duplicate,
    prevent_store_duplicate,
    duplicate_prevent_days,
    payment_method,
    campaign_reward,
    max_participants,
    max_per_reviewer,
    apply_start_date,
    apply_end_date,
    review_start_date,
    review_end_date,
    total_cost,
    status,
    user_id,
    review_keywords
  ) VALUES (
    p_title,
    p_description,
    v_company_id,
    p_campaign_type,
    p_platform,
    p_keyword,
    p_option,
    p_quantity,
    p_seller,
    p_product_number,
    p_product_image_url,
    p_product_name,
    p_product_price,
    p_purchase_method,
    p_review_type,
    p_review_text_length,
    p_review_image_count,
    p_prevent_product_duplicate,
    p_prevent_store_duplicate,
    p_duplicate_prevent_days,
    p_payment_method,
    p_campaign_reward,
    p_max_participants,
    COALESCE(p_max_per_reviewer, 1),
    p_apply_start_date,
    p_apply_end_date,
    v_review_start_date,
    v_review_end_date,
    v_total_cost,
    'active',
    v_user_id,
    p_review_keywords
  ) RETURNING id INTO v_campaign_id;
  
  -- 10. 포인트 트랜잭션 기록 (비용이 0보다 클 때만)
  IF v_total_cost > 0 THEN
    INSERT INTO public.point_transactions (
      wallet_id, 
      transaction_type, 
      amount,
      campaign_id, 
      description,
      created_by_user_id, 
      created_at
    ) VALUES (
      v_wallet_id, 
      'spend', 
      -v_total_cost,
      v_campaign_id, 
      '캠페인 생성: ' || p_title,
      v_user_id, 
      NOW()
    );
  END IF;
  
  -- 11. 잔액 일관성 검증 (비용이 0보다 클 때만)
  IF v_total_cost > 0 AND v_points_after_deduction != (v_points_before_deduction - v_total_cost) THEN
    RAISE EXCEPTION '포인트 차감이 정확하지 않습니다. (예상: % P, 실제: % P)', 
      v_points_before_deduction - v_total_cost, v_points_after_deduction;
  END IF;
  
  -- 12. 성공 응답 반환
  RETURN jsonb_build_object(
    'success', true,
    'campaign_id', v_campaign_id,
    'points_spent', v_total_cost,
    'points_before', v_points_before_deduction,
    'points_after', v_points_after_deduction
  );
  
EXCEPTION
  WHEN OTHERS THEN
    -- 에러 로깅
    BEGIN
      INSERT INTO public.error_logs (error_message, error_context, created_at)
      VALUES (
        SQLERRM,
        jsonb_build_object(
          'function', 'create_campaign_with_points_v2',
          'user_id', v_user_id,
          'company_id', v_company_id
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
$$;

-- 2. 레거시 필드 제거 (제약 조건 먼저 제거)
ALTER TABLE "public"."campaigns" DROP CONSTRAINT IF EXISTS "campaigns_dates_legacy_check";

-- 3. 레거시 필드 제거
ALTER TABLE "public"."campaigns" DROP COLUMN IF EXISTS "start_date";
ALTER TABLE "public"."campaigns" DROP COLUMN IF EXISTS "end_date";
ALTER TABLE "public"."campaigns" DROP COLUMN IF EXISTS "expiration_date";

-- 4. 함수 OWNER 설정
ALTER FUNCTION "public"."create_campaign_with_points_v2"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_campaign_reward" integer, "p_max_participants" integer, "p_apply_start_date" timestamp with time zone, "p_apply_end_date" timestamp with time zone, "p_platform" "text", "p_keyword" "text", "p_option" "text", "p_quantity" integer, "p_seller" "text", "p_product_number" "text", "p_product_image_url" "text", "p_product_name" "text", "p_product_price" integer, "p_purchase_method" "text", "p_product_description" "text", "p_review_type" "text", "p_review_text_length" integer, "p_review_image_count" integer, "p_prevent_product_duplicate" boolean, "p_prevent_store_duplicate" boolean, "p_duplicate_prevent_days" integer, "p_payment_method" "text", "p_review_start_date" timestamp with time zone, "p_review_end_date" timestamp with time zone, "p_max_per_reviewer" integer, "p_review_keywords" "text"[], "p_user_id" "uuid") OWNER TO "postgres";

-- 5. 주석 업데이트
COMMENT ON CONSTRAINT "campaigns_dates_check" ON "public"."campaigns" IS '캠페인 날짜 순서 검증: 신청 시작일시 <= 신청 종료일시 <= 리뷰 시작일시 <= 리뷰 종료일시';
