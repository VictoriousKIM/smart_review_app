-- 캠페인 로그 기록 기능 구현
-- 1. campaign_logs 테이블 재구성 (필수 필드만 사용)
-- 2. 외래키 CASCADE DELETE 설정
-- 3. create_campaign_with_points_v2 함수에 로그 기록 추가
-- 4. update_campaign_v2 함수에 로그 기록 추가
-- 5. delete_campaign 함수에 삭제 조건 확인 추가

-- ============================================
-- 1. campaign_logs 테이블 재구성
-- ============================================

-- 기존 테이블 삭제 (CASCADE로 관련 제약조건도 함께 삭제)
DROP TABLE IF EXISTS "public"."campaign_logs" CASCADE;

-- 새 테이블 생성 (필수 필드만)
CREATE TABLE "public"."campaign_logs" (
  "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
  "campaign_id" "uuid" NOT NULL,
  "user_id" "uuid" NOT NULL,
  "status" "text" NOT NULL CHECK ("status" IN ('create', 'edit')),
  "changes" "jsonb",
  "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
  CONSTRAINT "campaign_logs_pkey" PRIMARY KEY ("id")
);

-- 인덱스 생성 (조회 성능 향상)
CREATE INDEX "idx_campaign_logs_campaign_id" ON "public"."campaign_logs"("campaign_id");
CREATE INDEX "idx_campaign_logs_user_id" ON "public"."campaign_logs"("user_id");
CREATE INDEX "idx_campaign_logs_status" ON "public"."campaign_logs"("status");
CREATE INDEX "idx_campaign_logs_created_at" ON "public"."campaign_logs"("created_at");

-- 외래키 설정 (CASCADE DELETE)
ALTER TABLE "public"."campaign_logs"
  ADD CONSTRAINT "campaign_logs_campaign_id_fkey" 
  FOREIGN KEY ("campaign_id") REFERENCES "public"."campaigns"("id") 
  ON DELETE CASCADE;

ALTER TABLE "public"."campaign_logs"
  ADD CONSTRAINT "campaign_logs_user_id_fkey" 
  FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") 
  ON DELETE CASCADE;

-- 테이블 및 컬럼 코멘트
COMMENT ON TABLE "public"."campaign_logs" IS '캠페인 생성/수정 로그 테이블 (필수 필드만 사용)';
COMMENT ON COLUMN "public"."campaign_logs"."campaign_id" IS '캠페인 ID';
COMMENT ON COLUMN "public"."campaign_logs"."user_id" IS '액션을 수행한 사용자 ID';
COMMENT ON COLUMN "public"."campaign_logs"."status" IS '로그 타입: create(생성), edit(수정)';
COMMENT ON COLUMN "public"."campaign_logs"."changes" IS '변경사항 (JSONB). 생성 시 NULL, 수정 시 변경된 필드만 저장';
COMMENT ON COLUMN "public"."campaign_logs"."created_at" IS '로그 생성 시간';

-- 권한 설정
ALTER TABLE "public"."campaign_logs" OWNER TO "postgres";
GRANT ALL ON TABLE "public"."campaign_logs" TO "anon";
GRANT ALL ON TABLE "public"."campaign_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."campaign_logs" TO "service_role";

-- ============================================
-- 2. campaign_action_logs 외래키 CASCADE DELETE 확인 및 설정
-- ============================================

-- 기존 외래키 제약조건 확인 및 재설정 (이미 CASCADE가 설정되어 있어도 안전하게 재설정)
ALTER TABLE "public"."campaign_action_logs"
  DROP CONSTRAINT IF EXISTS "campaign_action_logs_campaign_id_fkey";

ALTER TABLE "public"."campaign_action_logs"
  ADD CONSTRAINT "campaign_action_logs_campaign_id_fkey" 
  FOREIGN KEY ("campaign_id") REFERENCES "public"."campaigns"("id") 
  ON DELETE CASCADE;

-- ============================================
-- 3. create_campaign_with_points_v2 함수에 로그 기록 추가
-- ============================================

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
  v_result JSONB;
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
  
  -- 9. 캠페인 생성
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
  
  -- 11. 캠페인 로그 기록 (생성)
  INSERT INTO public.campaign_logs (campaign_id, user_id, status, changes, created_at)
  VALUES (v_campaign_id, v_user_id, 'create', NULL, NOW());
  
  -- 12. 잔액 일관성 검증 (비용이 0보다 클 때만)
  IF v_total_cost > 0 AND v_points_after_deduction != (v_points_before_deduction - v_total_cost) THEN
    RAISE EXCEPTION '포인트 차감이 정확하지 않습니다. (예상: % P, 실제: % P)', 
      v_points_before_deduction - v_total_cost, v_points_after_deduction;
  END IF;
  
  -- 13. 성공 응답 반환
  RETURN jsonb_build_object(
    'success', true,
    'campaign_id', v_campaign_id,
    'points_spent', v_total_cost,
    'points_before', v_points_before_deduction,
    'points_after', v_points_after_deduction
  );
END;
$$;

-- ============================================
-- 4. update_campaign_v2 함수에 로그 기록 추가
-- ============================================

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
  "p_review_keywords" "text"[] DEFAULT NULL::"text"[],
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
  -- 기존 데이터 저장용 변수
  v_old_title TEXT;
  v_old_description TEXT;
  v_old_campaign_type TEXT;
  v_old_platform TEXT;
  v_old_keyword TEXT;
  v_old_option TEXT;
  v_old_quantity INTEGER;
  v_old_seller TEXT;
  v_old_product_number TEXT;
  v_old_product_image_url TEXT;
  v_old_product_name TEXT;
  v_old_product_price INTEGER;
  v_old_purchase_method TEXT;
  v_old_review_type TEXT;
  v_old_review_text_length INTEGER;
  v_old_review_image_count INTEGER;
  v_old_prevent_product_duplicate BOOLEAN;
  v_old_prevent_store_duplicate BOOLEAN;
  v_old_duplicate_prevent_days INTEGER;
  v_old_payment_method TEXT;
  v_old_campaign_reward INTEGER;
  v_old_max_participants INTEGER;
  v_old_max_per_reviewer INTEGER;
  v_old_apply_start_date TIMESTAMPTZ;
  v_old_apply_end_date TIMESTAMPTZ;
  v_old_review_start_date TIMESTAMPTZ;
  v_old_review_end_date TIMESTAMPTZ;
  v_old_review_keywords TEXT[];
  -- 변경사항 추출용 변수
  v_changes JSONB := '{}'::JSONB;
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
    
    -- 3. 캠페인 소유권 확인 및 생성일자 조회 + 기존 데이터 조회
    SELECT 
      company_id, created_at,
      title, description, campaign_type, platform, keyword, "option", quantity,
      seller, product_number, product_image_url, product_name, product_price,
      purchase_method, review_type, review_text_length, review_image_count,
      prevent_product_duplicate, prevent_store_duplicate, duplicate_prevent_days,
      payment_method, campaign_reward, max_participants, max_per_reviewer,
      apply_start_date, apply_end_date, review_start_date, review_end_date,
      review_keywords
    INTO 
      v_campaign_company_id, v_created_at,
      v_old_title, v_old_description, v_old_campaign_type, v_old_platform, v_old_keyword, v_old_option, v_old_quantity,
      v_old_seller, v_old_product_number, v_old_product_image_url, v_old_product_name, v_old_product_price,
      v_old_purchase_method, v_old_review_type, v_old_review_text_length, v_old_review_image_count,
      v_old_prevent_product_duplicate, v_old_prevent_store_duplicate, v_old_duplicate_prevent_days,
      v_old_payment_method, v_old_campaign_reward, v_old_max_participants, v_old_max_per_reviewer,
      v_old_apply_start_date, v_old_apply_end_date, v_old_review_start_date, v_old_review_end_date,
      v_old_review_keywords
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
    -- campaign_action_logs 테이블에서 'join' 액션이 있는지 확인
    IF EXISTS (
      SELECT 1 FROM public.campaign_action_logs 
      WHERE campaign_id = p_campaign_id 
        AND action->>'type' = 'join'
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
    
    -- 9. 변경사항 추출 (변경된 필드만)
    IF v_old_title IS DISTINCT FROM p_title THEN
      v_changes := v_changes || jsonb_build_object('title', jsonb_build_object('old', v_old_title, 'new', p_title));
    END IF;
    
    IF v_old_description IS DISTINCT FROM p_description THEN
      v_changes := v_changes || jsonb_build_object('description', jsonb_build_object('old', v_old_description, 'new', p_description));
    END IF;
    
    IF v_old_campaign_type IS DISTINCT FROM p_campaign_type THEN
      v_changes := v_changes || jsonb_build_object('campaign_type', jsonb_build_object('old', v_old_campaign_type, 'new', p_campaign_type));
    END IF;
    
    IF v_old_platform IS DISTINCT FROM p_platform THEN
      v_changes := v_changes || jsonb_build_object('platform', jsonb_build_object('old', v_old_platform, 'new', p_platform));
    END IF;
    
    IF v_old_keyword IS DISTINCT FROM p_keyword THEN
      v_changes := v_changes || jsonb_build_object('keyword', jsonb_build_object('old', v_old_keyword, 'new', p_keyword));
    END IF;
    
    IF v_old_option IS DISTINCT FROM p_option THEN
      v_changes := v_changes || jsonb_build_object('option', jsonb_build_object('old', v_old_option, 'new', p_option));
    END IF;
    
    IF COALESCE(v_old_quantity, 1) IS DISTINCT FROM COALESCE(p_quantity, 1) THEN
      v_changes := v_changes || jsonb_build_object('quantity', jsonb_build_object('old', v_old_quantity, 'new', COALESCE(p_quantity, 1)));
    END IF;
    
    IF v_old_seller IS DISTINCT FROM p_seller THEN
      v_changes := v_changes || jsonb_build_object('seller', jsonb_build_object('old', v_old_seller, 'new', p_seller));
    END IF;
    
    IF v_old_product_number IS DISTINCT FROM p_product_number THEN
      v_changes := v_changes || jsonb_build_object('product_number', jsonb_build_object('old', v_old_product_number, 'new', p_product_number));
    END IF;
    
    IF v_old_product_image_url IS DISTINCT FROM p_product_image_url THEN
      v_changes := v_changes || jsonb_build_object('product_image_url', jsonb_build_object('old', v_old_product_image_url, 'new', p_product_image_url));
    END IF;
    
    IF v_old_product_name IS DISTINCT FROM p_product_name THEN
      v_changes := v_changes || jsonb_build_object('product_name', jsonb_build_object('old', v_old_product_name, 'new', p_product_name));
    END IF;
    
    IF v_old_product_price IS DISTINCT FROM p_product_price THEN
      v_changes := v_changes || jsonb_build_object('product_price', jsonb_build_object('old', v_old_product_price, 'new', p_product_price));
    END IF;
    
    IF v_old_purchase_method IS DISTINCT FROM p_purchase_method THEN
      v_changes := v_changes || jsonb_build_object('purchase_method', jsonb_build_object('old', v_old_purchase_method, 'new', p_purchase_method));
    END IF;
    
    IF v_old_review_type IS DISTINCT FROM p_review_type THEN
      v_changes := v_changes || jsonb_build_object('review_type', jsonb_build_object('old', v_old_review_type, 'new', p_review_type));
    END IF;
    
    IF v_old_review_text_length IS DISTINCT FROM p_review_text_length THEN
      v_changes := v_changes || jsonb_build_object('review_text_length', jsonb_build_object('old', v_old_review_text_length, 'new', p_review_text_length));
    END IF;
    
    IF v_old_review_image_count IS DISTINCT FROM p_review_image_count THEN
      v_changes := v_changes || jsonb_build_object('review_image_count', jsonb_build_object('old', v_old_review_image_count, 'new', p_review_image_count));
    END IF;
    
    IF v_old_prevent_product_duplicate IS DISTINCT FROM p_prevent_product_duplicate THEN
      v_changes := v_changes || jsonb_build_object('prevent_product_duplicate', jsonb_build_object('old', v_old_prevent_product_duplicate, 'new', p_prevent_product_duplicate));
    END IF;
    
    IF v_old_prevent_store_duplicate IS DISTINCT FROM p_prevent_store_duplicate THEN
      v_changes := v_changes || jsonb_build_object('prevent_store_duplicate', jsonb_build_object('old', v_old_prevent_store_duplicate, 'new', p_prevent_store_duplicate));
    END IF;
    
    IF v_old_duplicate_prevent_days IS DISTINCT FROM p_duplicate_prevent_days THEN
      v_changes := v_changes || jsonb_build_object('duplicate_prevent_days', jsonb_build_object('old', v_old_duplicate_prevent_days, 'new', p_duplicate_prevent_days));
    END IF;
    
    IF v_old_payment_method IS DISTINCT FROM p_payment_method THEN
      v_changes := v_changes || jsonb_build_object('payment_method', jsonb_build_object('old', v_old_payment_method, 'new', p_payment_method));
    END IF;
    
    IF v_old_campaign_reward IS DISTINCT FROM p_campaign_reward THEN
      v_changes := v_changes || jsonb_build_object('campaign_reward', jsonb_build_object('old', v_old_campaign_reward, 'new', p_campaign_reward));
    END IF;
    
    IF v_old_max_participants IS DISTINCT FROM p_max_participants THEN
      v_changes := v_changes || jsonb_build_object('max_participants', jsonb_build_object('old', v_old_max_participants, 'new', p_max_participants));
    END IF;
    
    IF COALESCE(v_old_max_per_reviewer, 1) IS DISTINCT FROM COALESCE(p_max_per_reviewer, 1) THEN
      v_changes := v_changes || jsonb_build_object('max_per_reviewer', jsonb_build_object('old', v_old_max_per_reviewer, 'new', COALESCE(p_max_per_reviewer, 1)));
    END IF;
    
    IF v_old_apply_start_date IS DISTINCT FROM p_apply_start_date THEN
      v_changes := v_changes || jsonb_build_object('apply_start_date', jsonb_build_object('old', v_old_apply_start_date::text, 'new', p_apply_start_date::text));
    END IF;
    
    IF v_old_apply_end_date IS DISTINCT FROM p_apply_end_date THEN
      v_changes := v_changes || jsonb_build_object('apply_end_date', jsonb_build_object('old', v_old_apply_end_date::text, 'new', p_apply_end_date::text));
    END IF;
    
    -- review_start_date는 기본값이 설정되므로 비교 전에 계산
    v_review_start_date := COALESCE(p_review_start_date, p_apply_end_date + INTERVAL '1 day');
    IF v_old_review_start_date IS DISTINCT FROM v_review_start_date THEN
      v_changes := v_changes || jsonb_build_object('review_start_date', jsonb_build_object('old', v_old_review_start_date::text, 'new', v_review_start_date::text));
    END IF;
    
    v_review_end_date := COALESCE(p_review_end_date, v_review_start_date + INTERVAL '30 days');
    IF v_old_review_end_date IS DISTINCT FROM v_review_end_date THEN
      v_changes := v_changes || jsonb_build_object('review_end_date', jsonb_build_object('old', v_old_review_end_date::text, 'new', v_review_end_date::text));
    END IF;
    
    -- review_keywords 배열 비교 (NULL 처리 포함)
    IF (v_old_review_keywords IS NULL AND p_review_keywords IS NOT NULL) OR
       (v_old_review_keywords IS NOT NULL AND p_review_keywords IS NULL) OR
       (v_old_review_keywords IS NOT NULL AND p_review_keywords IS NOT NULL AND v_old_review_keywords::text != p_review_keywords::text) THEN
      v_changes := v_changes || jsonb_build_object(
        'review_keywords',
        jsonb_build_object(
          'old',
          CASE WHEN v_old_review_keywords IS NULL THEN NULL ELSE array_to_json(v_old_review_keywords) END,
          'new',
          CASE WHEN p_review_keywords IS NULL THEN NULL ELSE array_to_json(p_review_keywords) END
        )
      );
    END IF;
    
    -- 10. 캠페인 업데이트
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
      review_keywords = p_review_keywords,
      updated_at = NOW()
    WHERE id = p_campaign_id;
    
    -- 11. 캠페인 로그 기록 (변경사항이 있는 경우에만)
    IF jsonb_object_keys(v_changes) IS NOT NULL THEN
      INSERT INTO public.campaign_logs (campaign_id, user_id, status, changes, created_at)
      VALUES (p_campaign_id, v_user_id, 'edit', v_changes, NOW());
    END IF;
    
    -- 12. 성공 응답 반환
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

-- ============================================
-- 5. delete_campaign 함수에 삭제 조건 확인 추가
-- ============================================

CREATE OR REPLACE FUNCTION "public"."delete_campaign"(
  "p_campaign_id" "uuid",
  "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_user_id UUID;
  v_company_id UUID;
  v_user_role TEXT;
  v_campaign_company_id UUID;
  v_campaign_status TEXT;
  v_campaign_user_id UUID;
  v_campaign_title TEXT;
  v_current_participants INTEGER;
  v_total_cost INTEGER;
  v_wallet_id UUID;
  v_current_points INTEGER;
  v_refund_amount INTEGER;
  v_rows_affected INTEGER;
BEGIN
  -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
  v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 2. 사용자의 회사 ID 및 역할 조회
  SELECT cu.company_id, cu.company_role INTO v_company_id, v_user_role
  FROM public.company_users cu
  WHERE cu.user_id = v_user_id
    AND cu.status = 'active'
    AND cu.company_role IN ('owner', 'manager')
  LIMIT 1;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION '회사에 소속되지 않았거나 권한이 없습니다';
  END IF;

  -- 3. 캠페인 정보 조회 (소유권, 상태, 참여자 수, 총 비용, 생성자, 제목)
  SELECT company_id, status, current_participants, total_cost, user_id, title
  INTO v_campaign_company_id, v_campaign_status, v_current_participants, v_total_cost, v_campaign_user_id, v_campaign_title
  FROM public.campaigns
  WHERE id = p_campaign_id
  FOR UPDATE; -- 행 잠금으로 동시성 제어

  IF v_campaign_company_id IS NULL THEN
    RAISE EXCEPTION '캠페인을 찾을 수 없습니다';
  END IF;

  IF v_campaign_company_id != v_company_id THEN
    RAISE EXCEPTION '이 캠페인을 삭제할 권한이 없습니다';
  END IF;

  -- 4. 삭제 가능 여부 확인 (campaign_action_logs에 로그가 있으면 삭제 불가)
  IF EXISTS (
    SELECT 1 FROM public.campaign_action_logs 
    WHERE campaign_id = p_campaign_id
  ) THEN
    RAISE EXCEPTION '캠페인에 참여한 유저가 있어 삭제할 수 없습니다';
  END IF;

  -- 5. 캠페인 상태 확인 (진행 중인 캠페인은 삭제 불가)
  IF v_campaign_status = 'active' AND v_current_participants > 0 THEN
    RAISE EXCEPTION '참여자가 있는 활성 캠페인은 삭제할 수 없습니다. 먼저 캠페인을 종료해주세요.';
  END IF;

  -- 6. 회사 지갑 조회 및 포인트 확인
  SELECT id, current_points INTO v_wallet_id, v_current_points
  FROM public.wallets
  WHERE company_id = v_company_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION '회사 지갑을 찾을 수 없습니다';
  END IF;

  -- 7. 환불 금액 계산 (총 비용 - 사용된 비용)
  -- 참여자가 없으면 전체 환불, 있으면 부분 환불
  IF v_current_participants = 0 THEN
    v_refund_amount := v_total_cost;
  ELSE
    -- 참여자당 비용 계산 (총 비용 / 최대 참여자 수)
    v_refund_amount := v_total_cost - ((v_total_cost / GREATEST((SELECT max_participants FROM public.campaigns WHERE id = p_campaign_id), 1)) * v_current_participants);
  END IF;

  -- 8. 캠페인 삭제 (CASCADE DELETE로 campaign_logs도 함께 삭제됨)
  DELETE FROM public.campaigns
  WHERE id = p_campaign_id;
  
  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
  
  IF v_rows_affected = 0 THEN
    RAISE EXCEPTION '캠페인 삭제에 실패했습니다';
  END IF;

  -- 9. 환불 처리 (환불 금액이 0보다 큰 경우에만)
  IF v_refund_amount > 0 THEN
    -- 포인트 트랜잭션 생성 (충전)
    INSERT INTO public.point_transactions (
      wallet_id,
      transaction_type,
      amount,
      description,
      related_entity_type,
      related_entity_id,
      created_by_user_id
    ) VALUES (
      v_wallet_id,
      'charge',
      v_refund_amount,
      '캠페인 삭제 환불: ' || v_campaign_title,
      'campaign',
      p_campaign_id,
      v_user_id
    );

    -- 지갑 포인트 업데이트
    UPDATE public.wallets
    SET current_points = current_points + v_refund_amount,
        updated_at = NOW()
    WHERE id = v_wallet_id;
  END IF;

  -- 10. 결과 반환
  RETURN jsonb_build_object(
    'success', true,
    'campaign_id', p_campaign_id,
    'refund_amount', v_refund_amount,
    'message', '캠페인이 삭제되었습니다' || CASE WHEN v_refund_amount > 0 THEN '. 환불 금액: ' || v_refund_amount || 'P' ELSE '' END
  );
END;
$$;

