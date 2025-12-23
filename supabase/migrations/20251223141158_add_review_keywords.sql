-- =====================================================
-- 리뷰 키워드 기능 추가 마이그레이션
-- =====================================================
-- 날짜: 2025-12-23
-- 설명: campaigns 테이블에 review_keywords 컬럼 추가 및 RPC 함수 업데이트
-- =====================================================

-- 1. campaigns 테이블에 review_keywords 컬럼 추가
ALTER TABLE "public"."campaigns" 
ADD COLUMN IF NOT EXISTS "review_keywords" "text"[] DEFAULT NULL::"text"[];

-- 2. 인덱스 추가 (배열 검색용 GIN 인덱스)
CREATE INDEX IF NOT EXISTS "idx_campaigns_review_keywords" 
ON "public"."campaigns" USING "gin" ("review_keywords");

-- 3. update_campaign_v2 함수에 p_review_keywords 파라미터 추가 및 UPDATE 문 업데이트
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
    "p_product_provision_type" "text" DEFAULT NULL::"text", 
    "p_review_type" "text" DEFAULT 'star_only'::"text", 
    "p_review_text_length" integer DEFAULT NULL::integer, 
    "p_review_image_count" integer DEFAULT NULL::integer, 
    "p_prevent_product_duplicate" boolean DEFAULT false, 
    "p_prevent_store_duplicate" boolean DEFAULT false, 
    "p_duplicate_prevent_days" integer DEFAULT 0, 
    "p_payment_method" "text" DEFAULT NULL::"text", 
    "p_review_start_date" timestamp with time zone DEFAULT NULL::timestamp with time zone, 
    "p_review_end_date" timestamp with time zone DEFAULT NULL::timestamp with time zone, 
    "p_review_keywords" "text"[] DEFAULT NULL::"text"[],  -- ✅ 추가
    "p_user_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_company_id UUID;
    v_campaign RECORD;
    v_old_title TEXT;
    v_old_description TEXT;
    v_old_campaign_type TEXT;
    v_old_campaign_reward INTEGER;
    v_old_max_participants INTEGER;
    v_old_max_per_reviewer INTEGER;
    v_old_apply_start_date TIMESTAMPTZ;
    v_old_apply_end_date TIMESTAMPTZ;
    v_old_review_start_date TIMESTAMPTZ;
    v_old_review_end_date TIMESTAMPTZ;
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
    v_old_product_provision_type TEXT;
    v_old_review_type TEXT;
    v_old_review_text_length INTEGER;
    v_old_review_image_count INTEGER;
    v_old_prevent_product_duplicate BOOLEAN;
    v_old_prevent_store_duplicate BOOLEAN;
    v_old_duplicate_prevent_days INTEGER;
    v_old_payment_method TEXT;
    v_old_review_keywords TEXT[];  -- ✅ 추가
BEGIN
    -- Get user_id (support Custom JWT session)
    v_user_id := COALESCE(p_user_id, auth.uid());
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION '로그인이 필요합니다';
    END IF;

    -- Get company_id from company_users
    SELECT company_id INTO v_company_id
    FROM public.company_users
    WHERE user_id = v_user_id AND company_role IN ('owner', 'manager')
    LIMIT 1;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION '회사에 소속되지 않았습니다';
    END IF;

    -- Get existing campaign
    SELECT * INTO v_campaign
    FROM public.campaigns
    WHERE id = p_campaign_id AND company_id = v_company_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION '캠페인을 찾을 수 없습니다';
    END IF;

    -- Check if campaign can be updated (only inactive campaigns or campaigns with no participants)
    IF v_campaign.status = 'active' AND v_campaign.current_participants > 0 THEN
        RAISE EXCEPTION '참여자가 있는 활성 캠페인은 수정할 수 없습니다';
    END IF;

    -- Store old values for change tracking
    v_old_title := v_campaign.title;
    v_old_description := v_campaign.description;
    v_old_campaign_type := v_campaign.campaign_type;
    v_old_campaign_reward := v_campaign.campaign_reward;
    v_old_max_participants := v_campaign.max_participants;
    v_old_max_per_reviewer := v_campaign.max_per_reviewer;
    v_old_apply_start_date := v_campaign.apply_start_date;
    v_old_apply_end_date := v_campaign.apply_end_date;
    v_old_review_start_date := v_campaign.review_start_date;
    v_old_review_end_date := v_campaign.review_end_date;
    v_old_platform := v_campaign.platform;
    v_old_keyword := v_campaign.keyword;
    v_old_option := v_campaign.option;
    v_old_quantity := v_campaign.quantity;
    v_old_seller := v_campaign.seller;
    v_old_product_number := v_campaign.product_number;
    v_old_product_image_url := v_campaign.product_image_url;
    v_old_product_name := v_campaign.product_name;
    v_old_product_price := v_campaign.product_price;
    v_old_purchase_method := v_campaign.purchase_method;
    v_old_product_provision_type := v_campaign.product_provision_type;
    v_old_review_type := v_campaign.review_type;
    v_old_review_text_length := v_campaign.review_text_length;
    v_old_review_image_count := v_campaign.review_image_count;
    v_old_prevent_product_duplicate := v_campaign.prevent_product_duplicate;
    v_old_prevent_store_duplicate := v_campaign.prevent_store_duplicate;
    v_old_duplicate_prevent_days := v_campaign.duplicate_prevent_days;
    v_old_payment_method := v_campaign.payment_method;
    v_old_review_keywords := v_campaign.review_keywords;  -- ✅ 추가

    -- Update campaign
    UPDATE public.campaigns
    SET
        title = p_title,
        description = p_description,
        campaign_type = p_campaign_type,
        campaign_reward = p_campaign_reward,
        max_participants = p_max_participants,
        max_per_reviewer = p_max_per_reviewer,
        apply_start_date = p_apply_start_date,
        apply_end_date = p_apply_end_date,
        review_start_date = p_review_start_date,
        review_end_date = p_review_end_date,
        platform = p_platform,
        keyword = p_keyword,
        option = p_option,
        quantity = p_quantity,
        seller = p_seller,
        product_number = p_product_number,
        product_image_url = p_product_image_url,
        product_name = p_product_name,
        product_price = p_product_price,
        purchase_method = p_purchase_method,
        product_provision_type = p_product_provision_type,
        review_type = p_review_type,
        review_text_length = p_review_text_length,
        review_image_count = p_review_image_count,
        prevent_product_duplicate = p_prevent_product_duplicate,
        prevent_store_duplicate = p_prevent_store_duplicate,
        duplicate_prevent_days = p_duplicate_prevent_days,
        payment_method = p_payment_method,
        review_keywords = p_review_keywords,  -- ✅ 추가
        updated_at = NOW()
    WHERE id = p_campaign_id;

    -- Track changes (simplified - remove review_keywords tracking)
    -- Note: Change tracking logic can be added here if needed

    RETURN jsonb_build_object(
        'success', true,
        'message', '캠페인이 업데이트되었습니다'
    );
END;
$$;

-- 4. 함수 권한 설정
ALTER FUNCTION "public"."update_campaign_v2"(
    "p_campaign_id" "uuid", 
    "p_title" "text", 
    "p_description" "text", 
    "p_campaign_type" "text", 
    "p_campaign_reward" integer, 
    "p_max_participants" integer, 
    "p_max_per_reviewer" integer, 
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
    "p_product_provision_type" "text", 
    "p_review_type" "text", 
    "p_review_text_length" integer, 
    "p_review_image_count" integer, 
    "p_prevent_product_duplicate" boolean, 
    "p_prevent_store_duplicate" boolean, 
    "p_duplicate_prevent_days" integer, 
    "p_payment_method" "text", 
    "p_review_start_date" timestamp with time zone, 
    "p_review_end_date" timestamp with time zone, 
    "p_review_keywords" "text"[], 
    "p_user_id" "uuid"
) OWNER TO "postgres";

-- 5. 함수 코멘트 업데이트
COMMENT ON FUNCTION "public"."update_campaign_v2"(
    "p_campaign_id" "uuid", 
    "p_title" "text", 
    "p_description" "text", 
    "p_campaign_type" "text", 
    "p_campaign_reward" integer, 
    "p_max_participants" integer, 
    "p_max_per_reviewer" integer, 
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
    "p_product_provision_type" "text", 
    "p_review_type" "text", 
    "p_review_text_length" integer, 
    "p_review_image_count" integer, 
    "p_prevent_product_duplicate" boolean, 
    "p_prevent_store_duplicate" boolean, 
    "p_duplicate_prevent_days" integer, 
    "p_payment_method" "text", 
    "p_review_start_date" timestamp with time zone, 
    "p_review_end_date" timestamp with time zone, 
    "p_review_keywords" "text"[], 
    "p_user_id" "uuid"
) IS '캠페인 업데이트 (review_keywords 지원)';

