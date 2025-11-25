-- create_campaign_with_points_v2 함수 수정
-- start_date와 end_date 컬럼도 설정하도록 추가
-- (기존 컬럼이 NOT NULL로 남아있어서 발생하는 에러 수정)

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
    "p_max_per_reviewer" integer DEFAULT 1
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
  v_review_start_date TIMESTAMPTZ;
  v_review_end_date TIMESTAMPTZ;
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
    
    -- 2.1. 날짜 검증 및 기본값 설정
    IF p_apply_start_date IS NULL OR p_apply_end_date IS NULL THEN
      RAISE EXCEPTION '신청 시작일시와 종료일시는 필수입니다';
    END IF;
    
    IF p_apply_start_date > p_apply_end_date THEN
      RAISE EXCEPTION '신청 시작일시는 종료일시보다 이전이어야 합니다';
    END IF;
    
    -- review_start_date 기본값: apply_end_date + 1일
    v_review_start_date := COALESCE(p_review_start_date, p_apply_end_date + INTERVAL '1 day');
    
    -- review_end_date 기본값: review_start_date + 30일
    v_review_end_date := COALESCE(p_review_end_date, v_review_start_date + INTERVAL '30 days');
    
    -- 날짜 순서 검증
    IF p_apply_start_date > p_apply_end_date THEN
      RAISE EXCEPTION '신청 시작일시는 종료일시보다 이전이어야 합니다';
    END IF;
    
    IF p_apply_end_date > v_review_start_date THEN
      RAISE EXCEPTION '신청 종료일시는 리뷰 시작일시보다 이전이어야 합니다';
    END IF;
    
    IF v_review_start_date > v_review_end_date THEN
      RAISE EXCEPTION '리뷰 시작일시는 종료일시보다 이전이어야 합니다';
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
    
    IF v_wallet_id IS NULL OR v_current_points IS NULL THEN
      RAISE EXCEPTION '회사 지갑이 없습니다';
    END IF;
    
    -- 5. 잔액 확인
    v_points_before_deduction := v_current_points;
    
    IF v_current_points < v_total_cost THEN
      -- 실패 로그 기록
      INSERT INTO public.campaign_logs (
        company_id, user_id,
        log_type, action, status,
        error_message, points_spent, points_before,
        created_at
      ) VALUES (
        v_company_id, v_user_id,
        'creation', 'create', 'failed',
        '포인트가 부족합니다 (필요: ' || v_total_cost || ', 보유: ' || v_current_points || ')',
        v_total_cost, v_points_before_deduction,
        NOW()
      );
      
      RAISE EXCEPTION '포인트가 부족합니다 (필요: %, 보유: %)', 
        v_total_cost, v_current_points;
    END IF;
    
    -- 6. 캠페인 생성 (start_date, end_date, expiration_date도 설정 - 하위 호환성)
    INSERT INTO public.campaigns (
      title, description, company_id, user_id,
      campaign_type, platform,
      keyword, option, quantity, seller, product_number,
      product_image_url, product_name, product_price,
      purchase_method,
      review_type, review_text_length, review_image_count,
      campaign_reward, max_participants, current_participants,
      max_per_reviewer,
      start_date, end_date, expiration_date,  -- ✅ 기존 컬럼도 설정 (하위 호환성)
      apply_start_date, apply_end_date, review_start_date, review_end_date,
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
      COALESCE(p_max_per_reviewer, 1),
      p_apply_start_date, p_apply_end_date, v_review_end_date,  -- ✅ start_date = apply_start_date, end_date = apply_end_date, expiration_date = review_end_date
      p_apply_start_date, p_apply_end_date, v_review_start_date, v_review_end_date,
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
      -- 실패 로그 기록
      INSERT INTO public.campaign_logs (
        campaign_id, company_id, user_id,
        log_type, action, status,
        error_message, points_spent, points_before, points_after,
        created_at
      ) VALUES (
        v_campaign_id, v_company_id, v_user_id,
        'creation', 'create', 'failed',
        '포인트 차감이 정확하지 않습니다. (예상: ' || (v_points_before_deduction - v_total_cost) || ', 실제: ' || v_points_after_deduction || ')',
        v_total_cost, v_points_before_deduction, v_points_after_deduction,
        NOW()
      );
      
      RAISE EXCEPTION '포인트 차감이 정확하지 않습니다. (예상: %, 실제: %)', 
        v_points_before_deduction - v_total_cost, v_points_after_deduction;
    END IF;
    
    -- 9. 캠페인 생성 성공 로그 기록
    INSERT INTO public.campaign_logs (
      campaign_id, company_id, user_id,
      log_type, action, status,
      new_data, points_spent, points_before, points_after,
      created_at
    ) VALUES (
      v_campaign_id, v_company_id, v_user_id,
      'creation', 'create', 'success',
      jsonb_build_object(
        'title', p_title,
        'campaign_type', p_campaign_type,
        'total_cost', v_total_cost,
        'max_participants', p_max_participants,
        'max_per_reviewer', COALESCE(p_max_per_reviewer, 1),
        'campaign_reward', p_campaign_reward,
        'platform', p_platform
      ),
      v_total_cost, v_points_before_deduction, v_points_after_deduction,
      NOW()
    );
    
    -- 10. 결과 반환
    RETURN jsonb_build_object(
      'success', true,
      'campaign_id', v_campaign_id,
      'points_spent', v_total_cost
    );
  EXCEPTION
    WHEN OTHERS THEN
      -- 실패 로그 기록 (다른 예외들)
      BEGIN
        INSERT INTO public.campaign_logs (
          company_id, user_id,
          log_type, action, status,
          error_message, points_spent, points_before,
          created_at
        ) VALUES (
          COALESCE(v_company_id, (SELECT company_id FROM public.company_users WHERE user_id = v_user_id AND status = 'active' LIMIT 1)),
          v_user_id,
          'creation', 'create', 'failed',
          SQLERRM, 
          COALESCE(v_total_cost, 0), 
          COALESCE(v_points_before_deduction, 0),
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

ALTER FUNCTION "public"."create_campaign_with_points_v2"(
    "p_title" "text", 
    "p_description" "text", 
    "p_campaign_type" "text", 
    "p_campaign_reward" integer, 
    "p_max_participants" integer, 
    "p_apply_start_date" timestamp with time zone, 
    "p_apply_end_date" timestamp with time zone, 
    "p_platform" "text", 
    "p_keyword" "text", 
    "p_option" "text", 
    "p_quantity" integer, 
    "p_seller" "text", 
    "p_product_number" "text", 
    "p_product_image_url" "text", 
    "p_product_name" "text", 
    "p_product_price" integer, 
    "p_purchase_method" "text", 
    "p_product_description" "text", 
    "p_review_type" "text", 
    "p_review_text_length" integer, 
    "p_review_image_count" integer, 
    "p_prevent_product_duplicate" boolean, 
    "p_prevent_store_duplicate" boolean, 
    "p_duplicate_prevent_days" integer, 
    "p_payment_method" "text", 
    "p_review_start_date" timestamp with time zone, 
    "p_review_end_date" timestamp with time zone, 
    "p_max_per_reviewer" integer
) OWNER TO "postgres";

