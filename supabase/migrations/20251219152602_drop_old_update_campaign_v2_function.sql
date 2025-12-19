-- 기존 update_campaign_v2 함수 중 p_review_keywords가 text 타입인 버전 삭제
-- 함수 오버로딩 충돌 해결을 위해 기존 버전을 삭제하고 text[] 버전만 남김

DROP FUNCTION IF EXISTS "public"."update_campaign_v2"(
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
  "p_review_type" "text",
  "p_review_text_length" integer,
  "p_review_image_count" integer,
  "p_prevent_product_duplicate" boolean,
  "p_prevent_store_duplicate" boolean,
  "p_duplicate_prevent_days" integer,
  "p_payment_method" "text",
  "p_review_start_date" timestamp with time zone,
  "p_review_end_date" timestamp with time zone,
  "p_review_keywords" "text",  -- text 타입 버전 삭제
  "p_user_id" "uuid"
);

-- p_review_keywords 파라미터가 없는 버전도 삭제 (더 이상 사용하지 않음)
DROP FUNCTION IF EXISTS "public"."update_campaign_v2"(
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
  "p_review_type" "text",
  "p_review_text_length" integer,
  "p_review_image_count" integer,
  "p_prevent_product_duplicate" boolean,
  "p_prevent_store_duplicate" boolean,
  "p_duplicate_prevent_days" integer,
  "p_payment_method" "text",
  "p_review_start_date" timestamp with time zone,
  "p_review_end_date" timestamp with time zone,
  "p_user_id" "uuid"
);

