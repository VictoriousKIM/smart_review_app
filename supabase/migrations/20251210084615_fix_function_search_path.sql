-- Fix function search_path security warnings
-- This migration adds SET search_path to all functions that were missing it

-- 1. calculate_campaign_cost
CREATE OR REPLACE FUNCTION "public"."calculate_campaign_cost"("p_payment_method" "text", "p_payment_amount" integer, "p_campaign_reward" integer, "p_max_participants" integer) RETURNS integer
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
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

-- 2. get_active_campaigns_optimized
CREATE OR REPLACE FUNCTION "public"."get_active_campaigns_optimized"() RETURNS "public"."campaign_response"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  result public.campaign_response;
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
  FROM public.campaigns
  WHERE status = 'active'
    AND apply_start_date <= now_ts
    AND apply_end_date > now_ts
    AND (max_participants IS NULL OR current_participants < max_participants);
    -- Phase 3 진행 시: apply_start_date <= now_ts + interval '1 hour' 로 변경 필요

  -- 2. 가장 가까운 "오픈 예정" 시간 계산 (데이터는 안 가져옴, 시간만!)
  SELECT MIN(apply_start_date) INTO result.next_open_at
  FROM public.campaigns
  WHERE status = 'active'
    AND apply_start_date > now_ts;

  RETURN result;
END;
$$;

-- 3. get_wallet_by_user_id
CREATE OR REPLACE FUNCTION "public"."get_wallet_by_user_id"("p_user_id" "uuid") RETURNS TABLE("id" "uuid", "company_id" "uuid", "user_id" "uuid", "current_points" integer, "withdraw_bank_name" "text", "withdraw_account_number" "text", "withdraw_account_holder" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO ''
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        w.id,
        w.company_id,
        w.user_id,
        w.current_points,
        w.withdraw_bank_name,
        w.withdraw_account_number,
        w.withdraw_account_holder,
        w.created_at,
        w.updated_at
    FROM public.wallets w
    WHERE w.user_id = p_user_id;
END;
$$;

-- 4. get_wallet_by_company_id
CREATE OR REPLACE FUNCTION "public"."get_wallet_by_company_id"("p_company_id" "uuid") RETURNS TABLE("id" "uuid", "company_id" "uuid", "user_id" "uuid", "current_points" integer, "withdraw_bank_name" "text", "withdraw_account_number" "text", "withdraw_account_holder" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO ''
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        w.id,
        w.company_id,
        w.user_id,
        w.current_points,
        w.withdraw_bank_name,
        w.withdraw_account_number,
        w.withdraw_account_holder,
        w.created_at,
        w.updated_at
    FROM public.wallets w
    WHERE w.company_id = p_company_id;
END;
$$;

-- 5. update_company_users_updated_at
-- Note: This function may not exist in the database, but we create it for completeness
CREATE OR REPLACE FUNCTION "public"."update_company_users_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
    NEW."updated_at" = now();
    RETURN NEW;
END;
$$;

-- 6. update_sns_connections_updated_at
CREATE OR REPLACE FUNCTION "public"."update_sns_connections_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
    NEW."updated_at" = now();
    RETURN NEW;
END;
$$;

-- 7. update_sns_platform_connections_updated_at
CREATE OR REPLACE FUNCTION "public"."update_sns_platform_connections_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
    NEW."updated_at" = now();
    RETURN NEW;
END;
$$;

-- 8. update_updated_at_column
CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- 9. update_wallets_updated_at
CREATE OR REPLACE FUNCTION "public"."update_wallets_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

