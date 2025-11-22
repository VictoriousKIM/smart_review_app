


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS '백업 테이블이 제거되었습니다. 마이그레이션이 완료되었습니다.';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."admin_change_user_role"("p_target_user_id" "uuid", "p_new_role" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_profile jsonb;
  v_current_user_type text;
BEGIN
  -- 트랜잭션 시작: 권한 변경을 원자적으로 처리
  BEGIN
    -- 호출자가 관리자인지 확인
    SELECT user_type INTO v_current_user_type
    FROM public.users 
    WHERE id = (select auth.uid());
    
    IF v_current_user_type NOT IN ('admin', 'ADMIN', 'owner', 'OWNER') THEN
      RAISE EXCEPTION 'Only admins can change user roles';
    END IF;
    
    -- 권한 변경
    UPDATE public.users 
    SET 
      user_type = p_new_role,
      updated_at = NOW()
    WHERE id = p_target_user_id
    RETURNING to_jsonb(users.*) INTO v_profile;
    
    IF v_profile IS NULL THEN
      RAISE EXCEPTION 'User not found';
    END IF;
    
    RETURN v_profile;
    
  EXCEPTION
    WHEN OTHERS THEN
      -- 에러 발생 시 자동으로 롤백됨
      RAISE;
  END;
END;
$$;


ALTER FUNCTION "public"."admin_change_user_role"("p_target_user_id" "uuid", "p_new_role" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."admin_change_user_role"("p_target_user_id" "uuid", "p_new_role" "text") IS '사용자 권한 변경을 원자적으로 처리합니다. 에러 발생 시 모든 작업이 롤백됩니다.';



CREATE OR REPLACE FUNCTION "public"."approve_manager"("p_company_id" "uuid", "p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- 권한 확인: 회사 소유자 또는 활성 매니저만 승인 가능
  IF NOT EXISTS (
    SELECT 1 FROM public.company_users cu
    WHERE cu.company_id = p_company_id
      AND cu.user_id = (SELECT auth.uid())
      AND cu.company_role IN ('owner', 'manager')
      AND cu.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Only company owners and active managers can approve managers';
  END IF;
  
  -- status를 'active'로 업데이트 (복합 키 사용)
  UPDATE public.company_users
  SET status = 'active'
  WHERE company_id = p_company_id
    AND user_id = p_user_id
    AND status = 'pending'
    AND company_role = 'manager';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Manager request not found or already processed';
  END IF;
  
  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'company_id', p_company_id,
    'user_id', p_user_id,
    'status', 'active'
  ) INTO v_result;
  
  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$$;


ALTER FUNCTION "public"."approve_manager"("p_company_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."approve_manager"("p_company_id" "uuid", "p_user_id" "uuid") IS '매니저 승인 (복합 키 사용: company_id + user_id)';



CREATE OR REPLACE FUNCTION "public"."calculate_campaign_cost"("p_payment_method" "text", "p_payment_amount" integer, "p_campaign_reward" integer, "p_max_participants" integer) RETURNS integer
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


ALTER FUNCTION "public"."calculate_campaign_cost"("p_payment_method" "text", "p_payment_amount" integer, "p_campaign_reward" integer, "p_max_participants" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_cash_transaction"("p_transaction_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_current_status TEXT;
    v_wallet_id UUID;
    v_user_id UUID;
BEGIN
    -- 사용자 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 현재 상태 및 지갑 ID 확인
    SELECT status, wallet_id INTO v_current_status, v_wallet_id
    FROM public.cash_transactions
    WHERE id = p_transaction_id;

    IF v_current_status IS NULL THEN
        RAISE EXCEPTION 'Transaction not found';
    END IF;

    -- pending 상태가 아니면 취소 불가
    IF v_current_status != 'pending' THEN
        RAISE EXCEPTION 'Only pending transactions can be cancelled';
    END IF;

    -- 권한 확인: 거래를 생성한 사용자만 취소 가능
    -- wallet을 통해 user_id 또는 company_id 확인
    IF EXISTS (
        SELECT 1 FROM public.wallets w
        WHERE w.id = v_wallet_id
        AND (
            w.user_id = v_user_id
            OR EXISTS (
                SELECT 1 FROM public.company_users cu
                WHERE cu.company_id = w.company_id
                AND cu.user_id = v_user_id
                AND cu.status = 'active'
            )
        )
    ) THEN
        -- 관련 로그 삭제
        DELETE FROM public.cash_transaction_logs
        WHERE transaction_id = p_transaction_id;

        -- 거래 삭제
        DELETE FROM public.cash_transactions
        WHERE id = p_transaction_id;

        RETURN TRUE;
    ELSE
        RAISE EXCEPTION 'You do not have permission to cancel this transaction';
    END IF;
END;
$$;


ALTER FUNCTION "public"."cancel_cash_transaction"("p_transaction_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_user_exists"("p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = p_user_id
    );
END;
$$;


ALTER FUNCTION "public"."check_user_exists"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_campaign_with_points"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_product_price" integer, "p_campaign_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_product_image_url" "text" DEFAULT NULL::"text", "p_platform" "text" DEFAULT NULL::"text") RETURNS "jsonb"
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


ALTER FUNCTION "public"."create_campaign_with_points"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_product_price" integer, "p_campaign_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_product_image_url" "text", "p_platform" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_campaign_with_points_v2"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_campaign_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_platform" "text" DEFAULT NULL::"text", "p_keyword" "text" DEFAULT NULL::"text", "p_option" "text" DEFAULT NULL::"text", "p_quantity" integer DEFAULT 1, "p_seller" "text" DEFAULT NULL::"text", "p_product_number" "text" DEFAULT NULL::"text", "p_product_image_url" "text" DEFAULT NULL::"text", "p_product_name" "text" DEFAULT NULL::"text", "p_product_price" integer DEFAULT NULL::integer, "p_purchase_method" "text" DEFAULT 'mobile'::"text", "p_product_description" "text" DEFAULT NULL::"text", "p_review_type" "text" DEFAULT 'star_only'::"text", "p_review_text_length" integer DEFAULT NULL::integer, "p_review_image_count" integer DEFAULT NULL::integer, "p_prevent_product_duplicate" boolean DEFAULT false, "p_prevent_store_duplicate" boolean DEFAULT false, "p_duplicate_prevent_days" integer DEFAULT 0, "p_payment_method" "text" DEFAULT 'platform'::"text", "p_expiration_date" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
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


ALTER FUNCTION "public"."create_campaign_with_points_v2"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_campaign_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_platform" "text", "p_keyword" "text", "p_option" "text", "p_quantity" integer, "p_seller" "text", "p_product_number" "text", "p_product_image_url" "text", "p_product_name" "text", "p_product_price" integer, "p_purchase_method" "text", "p_product_description" "text", "p_review_type" "text", "p_review_text_length" integer, "p_review_image_count" integer, "p_prevent_product_duplicate" boolean, "p_prevent_store_duplicate" boolean, "p_duplicate_prevent_days" integer, "p_payment_method" "text", "p_expiration_date" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_cash_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_point_amount" integer, "p_cash_amount" numeric DEFAULT NULL::numeric, "p_payment_method" "text" DEFAULT NULL::"text", "p_bank_name" "text" DEFAULT NULL::"text", "p_account_number" "text" DEFAULT NULL::"text", "p_account_holder" "text" DEFAULT NULL::"text", "p_description" "text" DEFAULT NULL::"text", "p_created_by_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_transaction_id UUID;
BEGIN
    -- wallet 존재 확인
    IF NOT EXISTS (SELECT 1 FROM public.wallets WHERE id = p_wallet_id) THEN
        RAISE EXCEPTION 'Wallet not found';
    END IF;
    
    IF p_transaction_type NOT IN ('deposit', 'withdraw') THEN
        RAISE EXCEPTION 'Invalid transaction_type. Must be deposit or withdraw';
    END IF;
    
    -- 출금 시 계좌 정보 필수
    IF p_transaction_type = 'withdraw' AND (
        p_bank_name IS NULL OR 
        p_account_number IS NULL OR 
        p_account_holder IS NULL
    ) THEN
        RAISE EXCEPTION 'Bank account information is required for withdraw transactions';
    END IF;
    
    -- 거래 생성 (status는 기본값 'pending')
    INSERT INTO public.cash_transactions (
        wallet_id,
        transaction_type,
        point_amount,
        cash_amount,
        payment_method,
        bank_name,
        account_number,
        account_holder,
        description,
        created_by_user_id
    ) VALUES (
        p_wallet_id,
        p_transaction_type,
        p_point_amount,
        p_cash_amount,
        p_payment_method,
        p_bank_name,
        p_account_number,
        p_account_holder,
        p_description,
        COALESCE(p_created_by_user_id, auth.uid())
    )
    RETURNING id INTO v_transaction_id;
    
    RETURN v_transaction_id;
END;
$$;


ALTER FUNCTION "public"."create_cash_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_point_amount" integer, "p_cash_amount" numeric, "p_payment_method" "text", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text", "p_description" "text", "p_created_by_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_company_wallet_on_registration"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_wallet_id UUID;
BEGIN
    -- wallets 테이블에 지갑 생성
    INSERT INTO public.wallets (company_id, user_id, current_points, created_at, updated_at)
    VALUES (NEW.id, NULL, 0, NOW(), NOW())
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_wallet_id;
    
    -- 누적 로그 방식에서는 초기 기록을 생성하지 않음 (첫 변경 시 기록됨)
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."create_company_wallet_on_registration"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_point_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_amount" integer, "p_campaign_id" "uuid" DEFAULT NULL::"uuid", "p_related_entity_type" "text" DEFAULT NULL::"text", "p_related_entity_id" "uuid" DEFAULT NULL::"uuid", "p_description" "text" DEFAULT NULL::"text", "p_created_by_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_transaction_id UUID;
    v_wallet RECORD;
BEGIN
    -- wallet 정보 조회
    SELECT user_id, company_id INTO v_wallet
    FROM public.wallets
    WHERE id = p_wallet_id;
    
    IF v_wallet IS NULL THEN
        RAISE EXCEPTION 'Wallet not found';
    END IF;
    
    IF p_transaction_type NOT IN ('earn', 'spend') THEN
        RAISE EXCEPTION 'Invalid transaction_type. Must be earn or spend';
    END IF;
    
    -- company spend는 campaign_id 필수
    IF v_wallet.company_id IS NOT NULL AND p_transaction_type = 'spend' AND p_campaign_id IS NULL THEN
        RAISE EXCEPTION 'campaign_id is required for company spend transactions';
    END IF;
    
    -- 거래 생성
    INSERT INTO public.point_transactions (
        wallet_id,
        transaction_type,
        amount,
        campaign_id,
        related_entity_type,
        related_entity_id,
        description,
        created_by_user_id,
        completed_at
    ) VALUES (
        p_wallet_id,
        p_transaction_type,
        p_amount,
        p_campaign_id,
        p_related_entity_type,
        p_related_entity_id,
        p_description,
        COALESCE(p_created_by_user_id, auth.uid()),
        NOW()
    )
    RETURNING id INTO v_transaction_id;
    
    RETURN v_transaction_id;
END;
$$;


ALTER FUNCTION "public"."create_point_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_amount" integer, "p_campaign_id" "uuid", "p_related_entity_type" "text", "p_related_entity_id" "uuid", "p_description" "text", "p_created_by_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_sns_connection"("p_user_id" "uuid", "p_platform" "text", "p_platform_account_id" "text", "p_platform_account_name" "text", "p_phone" "text", "p_address" "text" DEFAULT NULL::"text", "p_return_address" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_store_platforms text[] := ARRAY['coupang', 'smartstore', '11st', 'gmarket', 'auction', 'wemakeprice'];
    v_result jsonb;
BEGIN
    -- 1. 사용자 존재 확인
    IF NOT EXISTS (SELECT 1 FROM "public"."users" WHERE "id" = "p_user_id") THEN
        RAISE EXCEPTION '사용자를 찾을 수 없습니다';
    END IF;
    
    -- 2. 스토어 플랫폼 주소 필수 검증
    IF "p_platform" = ANY(v_store_platforms) AND ("p_address" IS NULL OR "p_address" = '') THEN
        RAISE EXCEPTION '스토어 플랫폼(%)은 주소 입력이 필수입니다', "p_platform";
    END IF;
    
    -- 3. 중복 확인 (같은 계정 ID 중복 방지)
    IF EXISTS (
        SELECT 1 FROM "public"."sns_connections"
        WHERE "user_id" = "p_user_id"
          AND "platform" = "p_platform"
          AND "platform_account_id" = "p_platform_account_id"
    ) THEN
        RAISE EXCEPTION '이미 등록된 계정입니다';
    END IF;
    
    -- 4. SNS 연결 생성
    INSERT INTO "public"."sns_connections" (
        "user_id",
        "platform",
        "platform_account_id",
        "platform_account_name",
        "phone",
        "address",
        "return_address"
    ) VALUES (
        "p_user_id",
        "p_platform",
        "p_platform_account_id",
        "p_platform_account_name",
        "p_phone",
        CASE 
            WHEN "p_platform" = ANY(v_store_platforms) THEN "p_address"
            ELSE NULL
        END,
        "p_return_address"
    )
    RETURNING jsonb_build_object(
        'id', "id",
        'platform', "platform",
        'platform_account_id', "platform_account_id",
        'platform_account_name', "platform_account_name",
        'phone', "phone",
        'address', "address",
        'return_address', "return_address",
        'created_at', "created_at"
    ) INTO v_result;
    
    RETURN jsonb_build_object(
        'success', true,
        'data', v_result
    );
    
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION '이미 등록된 계정입니다';
    WHEN OTHERS THEN
        RAISE;
END;
$$;


ALTER FUNCTION "public"."create_sns_connection"("p_user_id" "uuid", "p_platform" "text", "p_platform_account_id" "text", "p_platform_account_name" "text", "p_phone" "text", "p_address" "text", "p_return_address" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_user_type" "text" DEFAULT 'user'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$ 
DECLARE 
  v_profile jsonb; 
  v_user_exists boolean;
BEGIN 
  SELECT EXISTS(SELECT 1 FROM public.users WHERE id = p_user_id) 
  INTO v_user_exists;
  
  IF v_user_exists THEN
    SELECT to_jsonb(users.*) INTO v_profile
    FROM public.users 
    WHERE id = p_user_id;
    RETURN v_profile;
  END IF;
  
  -- 사용자 프로필 생성
  INSERT INTO public.users ( 
    id, display_name, user_type, created_at, updated_at 
  ) VALUES ( 
    p_user_id, p_display_name, p_user_type, NOW(), NOW() 
  )
  ON CONFLICT (id) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    updated_at = NOW()
  RETURNING to_jsonb(users.*) INTO v_profile;
  
  -- 트리거가 자동으로 user_wallet 생성하므로 별도 코드 불필요
  
  RETURN v_profile; 
END; 
$$;


ALTER FUNCTION "public"."create_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_user_type" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_user_type" "text") IS '사용자 프로필과 포인트 지갑을 원자적으로 생성합니다. 에러 발생 시 모든 작업이 롤백됩니다.';



CREATE OR REPLACE FUNCTION "public"."create_user_wallet_on_signup"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_wallet_id UUID;
BEGIN
    -- wallets 테이블에 지갑 생성
    INSERT INTO public.wallets (company_id, user_id, current_points, created_at, updated_at)
    VALUES (NULL, NEW.id, 0, NOW(), NOW())
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_wallet_id;
    
    -- 누적 로그 방식에서는 초기 기록을 생성하지 않음 (첫 변경 시 기록됨)
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."create_user_wallet_on_signup"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_campaign"("p_campaign_id" "uuid") RETURNS "jsonb"
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
  -- 1. 현재 사용자 확인
  v_user_id := auth.uid();
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

  -- 4. 삭제 권한 확인: owner이거나, 캠페인을 생성한 매니저만 삭제 가능
  IF v_user_role = 'manager' AND v_campaign_user_id != v_user_id THEN
    RAISE EXCEPTION '캠페인을 생성한 매니저만 삭제할 수 있습니다';
  END IF;

  -- 5. 상태 확인 (inactive만 삭제 가능)
  IF v_campaign_status != 'inactive' THEN
    RAISE EXCEPTION '비활성화된 캠페인만 삭제할 수 있습니다 (현재 상태: %)', v_campaign_status;
  END IF;

  -- 6. 참여자 수 확인
  IF v_current_participants > 0 THEN
    RAISE EXCEPTION '참여자가 있는 캠페인은 삭제할 수 없습니다 (참여자 수: %)', v_current_participants;
  END IF;

  -- 7. 회사 지갑 조회
  SELECT id, current_points
  INTO v_wallet_id, v_current_points
  FROM public.wallets
  WHERE company_id = v_company_id
    AND user_id IS NULL
  FOR UPDATE; -- 행 잠금

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION '회사 지갑을 찾을 수 없습니다';
  END IF;

  -- 8. 포인트 환불 (total_cost가 있는 경우만)
  v_refund_amount := COALESCE(v_total_cost, 0);
  
  IF v_refund_amount > 0 THEN
    -- 지갑 잔액 증가
    UPDATE public.wallets
    SET current_points = current_points + v_refund_amount,
        updated_at = NOW()
    WHERE id = v_wallet_id;

    -- 포인트 트랜잭션 기록 (refund 타입)
    -- refund 타입은 campaign_id가 NULL이어도 됨 (제약 조건에서 허용)
    -- 제약 조건 위반을 방지하기 위해 명시적으로 NULL로 설정
    INSERT INTO public.point_transactions (
      wallet_id,
      transaction_type,
      amount,
      campaign_id,
      description,
      created_by_user_id,
      created_at,
      completed_at
    ) VALUES (
      v_wallet_id,
      'refund',
      v_refund_amount,
      NULL, -- refund 타입이므로 NULL 허용, 제약 조건 위반 방지
      '캠페인 삭제 환불: ' || COALESCE(v_campaign_title, '') || ' (캠페인 ID: ' || p_campaign_id::text || ')',
      v_user_id,
      NOW(),
      NOW()
    );
  END IF;

  -- 9. 하드 삭제 (실제 DELETE)
  DELETE FROM public.campaigns
  WHERE id = p_campaign_id;

  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

  IF v_rows_affected = 0 THEN
    RAISE EXCEPTION '캠페인 삭제에 실패했습니다';
  END IF;

  -- 10. 결과 반환
  RETURN jsonb_build_object(
    'success', true,
    'campaign_id', p_campaign_id,
    'message', '캠페인이 삭제되었습니다',
    'refund_amount', v_refund_amount,
    'rows_affected', v_rows_affected
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;


ALTER FUNCTION "public"."delete_campaign"("p_campaign_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."delete_campaign"("p_campaign_id" "uuid") IS '캠페인 하드 삭제 (inactive 상태이고 참여자가 없을 때만 가능, 포인트 환불 포함, 생성한 매니저만 삭제 가능, refund 타입 campaign_id NULL 처리)';



CREATE OR REPLACE FUNCTION "public"."delete_company"("p_company_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_result jsonb;
  v_user_id uuid;
BEGIN
  -- 현재 사용자 ID 가져오기
  v_user_id := (SELECT auth.uid());
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Must be logged in';
  END IF;

  -- 권한 확인: 자신의 회사만 삭제 가능
  IF NOT EXISTS (
    SELECT 1 FROM public.companies 
    WHERE id = p_company_id 
    AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Can only delete your own company';
  END IF;

  -- company_users 관계 삭제
  DELETE FROM public.company_users 
  WHERE company_id = p_company_id;

  -- 회사 정보 삭제
  DELETE FROM public.companies 
  WHERE id = p_company_id;

  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'company_id', p_company_id
  ) INTO v_result;

  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION '회사 삭제 실패: %', SQLERRM;
END;
$$;


ALTER FUNCTION "public"."delete_company"("p_company_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_sns_connection"("p_id" "uuid", "p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_deleted_id uuid;
BEGIN
    DELETE FROM "public"."sns_connections"
    WHERE "id" = "p_id" AND "user_id" = "p_user_id"
    RETURNING "id" INTO v_deleted_id;
    
    IF v_deleted_id IS NULL THEN
        RAISE EXCEPTION 'SNS 연결을 찾을 수 없습니다';
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'id', v_deleted_id
    );
END;
$$;


ALTER FUNCTION "public"."delete_sns_connection"("p_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."earn_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text" DEFAULT NULL::"text", "p_related_entity_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_wallet_id uuid;
  v_current_points integer;
  v_new_balance integer;
  v_log_id uuid;
  v_result jsonb;
BEGIN
  -- 권한 확인: 관리자만 포인트 적립 가능
  IF NOT EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = (select auth.uid()) AND user_type = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can award points';
  END IF;
  
  -- 트랜잭션 시작: 포인트 지갑 업데이트와 로그 생성을 원자적으로 처리
  -- PostgreSQL 함수는 자동으로 트랜잭션 블록 안에서 실행되지만,
  -- 명시적으로 EXCEPTION 핸들링을 강화하여 에러 발생 시 롤백 보장
  BEGIN
    -- 포인트 지갑 조회 및 업데이트 (행 잠금으로 동시성 제어)
    SELECT id, current_points INTO v_wallet_id, v_current_points
    FROM public.point_wallets
    WHERE wallet_type = 'reviewer' AND user_id = p_user_id
    FOR UPDATE -- 행 잠금으로 동시성 제어
    LIMIT 1;
    
    IF v_wallet_id IS NULL THEN
      RAISE EXCEPTION 'User wallet not found';
    END IF;
    
    -- 포인트 추가
    v_new_balance := v_current_points + p_amount;
    
    UPDATE public.point_wallets
    SET current_points = v_new_balance, updated_at = NOW()
    WHERE id = v_wallet_id;
    
    -- 적립 로그 생성
    INSERT INTO public.point_logs (
      wallet_id, transaction_type, amount, description, related_entity_type, related_entity_id
    ) VALUES (
      v_wallet_id, 'earn', p_amount, p_description, p_related_entity_type, p_related_entity_id
    ) RETURNING id INTO v_log_id;
    
    -- 결과 반환 (기존 형식 유지)
    SELECT jsonb_build_object(
      'success', true,
      'log_id', v_log_id,
      'amount_earned', p_amount,
      'new_balance', v_new_balance,
      'description', p_description
    ) INTO v_result;
    
    RETURN v_result;
    
  EXCEPTION
    WHEN OTHERS THEN
      -- 에러 발생 시 자동으로 롤백됨 (함수 내부의 EXCEPTION 블록)
      RAISE;
  END;
END;
$$;


ALTER FUNCTION "public"."earn_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."earn_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") IS '포인트 적립과 로그 생성을 원자적으로 처리합니다. 에러 발생 시 모든 작업이 롤백됩니다.';



CREATE OR REPLACE FUNCTION "public"."ensure_company_wallet"("p_company_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_wallet_id UUID;
BEGIN
    -- 기존 지갑 확인
    SELECT id INTO v_wallet_id
    FROM public.wallets
    WHERE company_id = p_company_id;
    
    -- 없으면 생성
    IF v_wallet_id IS NULL THEN
        INSERT INTO public.wallets (company_id, user_id, current_points, created_at, updated_at)
        VALUES (p_company_id, NULL, 0, NOW(), NOW())
        RETURNING id INTO v_wallet_id;
        
        -- 누적 로그 방식에서는 초기 기록을 생성하지 않음 (첫 변경 시 기록됨)
    END IF;
    
    RETURN v_wallet_id;
END;
$$;


ALTER FUNCTION "public"."ensure_company_wallet"("p_company_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_user_wallet"("p_user_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_wallet_id UUID;
BEGIN
    -- 기존 지갑 확인
    SELECT id INTO v_wallet_id
    FROM public.wallets
    WHERE user_id = p_user_id;
    
    -- 없으면 생성
    IF v_wallet_id IS NULL THEN
        INSERT INTO public.wallets (company_id, user_id, current_points, created_at, updated_at)
        VALUES (NULL, p_user_id, 0, NOW(), NOW())
        RETURNING id INTO v_wallet_id;
        
        -- 누적 로그 방식에서는 초기 기록을 생성하지 않음 (첫 변경 시 기록됨)
    END IF;
    
    RETURN v_wallet_id;
END;
$$;


ALTER FUNCTION "public"."ensure_user_wallet"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_company_managers"("p_company_id" "uuid") RETURNS TABLE("company_id" "uuid", "user_id" "uuid", "status" "text", "created_at" timestamp with time zone, "email" character varying, "display_name" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  -- 권한 확인: 회사 소유자 또는 관리자만 조회 가능
  IF NOT EXISTS (
    SELECT 1 FROM public.company_users cu
    WHERE cu.company_id = p_company_id
      AND cu.user_id = (SELECT auth.uid())
      AND cu.company_role IN ('owner', 'manager')
      AND cu.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Only company owners and managers can view manager list';
  END IF;

  -- 매니저 목록 조회 (auth.users의 email 포함)
  RETURN QUERY
  SELECT 
    cu.company_id,
    cu.user_id,
    cu.status,
    cu.created_at,
    au.email,
    COALESCE(u.display_name, '이름 없음')::text as display_name
  FROM public.company_users cu
  LEFT JOIN public.users u ON u.id = cu.user_id
  LEFT JOIN auth.users au ON au.id = cu.user_id
  WHERE cu.company_id = p_company_id
    AND cu.company_role = 'manager'
    AND cu.status IN ('pending', 'active')
  ORDER BY 
    CASE cu.status
      WHEN 'pending' THEN 1
      WHEN 'active' THEN 2
      ELSE 3
    END,
    cu.created_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_company_managers"("p_company_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_company_managers"("p_company_id" "uuid") IS '회사 매니저 목록 조회 (company_users의 id 제거 후 복합 키 반환)';



CREATE OR REPLACE FUNCTION "public"."get_company_point_history"("p_company_id" "uuid", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("log_id" "uuid", "transaction_type" "text", "amount" integer, "description" "text", "related_entity_type" "text", "related_entity_id" "uuid", "created_by_user_id" "uuid", "created_by_user_name" "text", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  -- 권한 확인: 회사 멤버만 조회 가능
  IF NOT EXISTS (
    SELECT 1 FROM public.company_users cu
    WHERE cu.company_id = p_company_id
      AND cu.user_id = (SELECT auth.uid())
      AND cu.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Not a company member';
  END IF;
  
  RETURN QUERY
  SELECT 
    pt.id as log_id,
    pt.transaction_type,
    pt.amount,
    pt.description,
    pt.related_entity_type,
    pt.related_entity_id,
    pt.created_by_user_id,
    COALESCE(u.display_name, '알 수 없음') as created_by_user_name,
    pt.created_at
  FROM public.point_transactions pt
  JOIN public.wallets w ON w.id = pt.wallet_id
  LEFT JOIN public.users u ON u.id = pt.created_by_user_id
  WHERE w.company_id = p_company_id
    AND w.user_id IS NULL
  ORDER BY pt.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;


ALTER FUNCTION "public"."get_company_point_history"("p_company_id" "uuid", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_company_point_history_unified"("p_company_id" "uuid", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_result jsonb;
    v_user_id UUID;
BEGIN
    -- 권한 확인: 회사 멤버만 조회 가능
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM public.company_users
        WHERE company_id = p_company_id
        AND user_id = v_user_id
        AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'You do not have permission to view this company point history';
    END IF;
    
    WITH sorted_transactions AS (
        -- 캠페인 거래
        SELECT 
            pt.id,
            w.user_id,
            w.company_id,
            pt.wallet_id,
            pt.transaction_type,
            pt.amount,
            pt.campaign_id,
            pt.related_entity_type,
            pt.related_entity_id,
            pt.description,
            'completed' AS status,
            NULL::uuid AS approved_by,
            NULL::uuid AS rejected_by,
            NULL::text AS rejection_reason,
            pt.created_by_user_id,
            pt.created_at,
            pt.updated_at,
            pt.completed_at,
            'campaign' AS transaction_category,
            NULL::numeric AS cash_amount,
            NULL::text AS payment_method,
            NULL::text AS bank_name,
            NULL::text AS account_number,
            NULL::text AS account_holder
        FROM public.point_transactions pt
        JOIN public.wallets w ON w.id = pt.wallet_id
        WHERE w.company_id = p_company_id
        
        UNION ALL
        
        -- 현금 거래 (completed_at 제거)
        SELECT 
            pt.id,
            w.user_id,
            w.company_id,
            pt.wallet_id,
            pt.transaction_type,
            pt.point_amount AS amount,
            NULL::uuid AS campaign_id,
            NULL::text AS related_entity_type,
            NULL::uuid AS related_entity_id,
            pt.description,
            pt.status,
            pt.approved_by,
            pt.rejected_by,
            pt.rejection_reason,
            pt.created_by_user_id,
            pt.created_at,
            pt.updated_at,
            NULL::timestamp with time zone AS completed_at,
            'cash' AS transaction_category,
            pt.cash_amount,
            pt.payment_method,
            pt.bank_name,
            pt.account_number,
            pt.account_holder
        FROM public.cash_transactions pt
        JOIN public.wallets w ON w.id = pt.wallet_id
        WHERE w.company_id = p_company_id
    ),
    limited_transactions AS (
        SELECT *
        FROM sorted_transactions
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'user_id', user_id,
            'company_id', company_id,
            'wallet_id', wallet_id,
            'transaction_type', transaction_type,
            'amount', amount,
            'campaign_id', campaign_id,
            'related_entity_type', related_entity_type,
            'related_entity_id', related_entity_id,
            'description', description,
            'status', status,
            'approved_by', approved_by,
            'rejected_by', rejected_by,
            'rejection_reason', rejection_reason,
            'created_by_user_id', created_by_user_id,
            'created_at', created_at,
            'updated_at', updated_at,
            'completed_at', completed_at,
            'transaction_category', transaction_category,
            'cash_amount', cash_amount,
            'payment_method', payment_method,
            'bank_name', bank_name,
            'account_number', account_number,
            'account_holder', account_holder
        )
    )
    INTO v_result
    FROM limited_transactions;
    
    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;


ALTER FUNCTION "public"."get_company_point_history_unified"("p_company_id" "uuid", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_pending_cash_transactions"("p_status" "text" DEFAULT 'pending'::"text", "p_transaction_type" "text" DEFAULT NULL::"text", "p_user_type" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_result JSONB;
    v_user_id UUID;
    v_user_type TEXT;
BEGIN
    -- 권한 확인: 관리자만 조회 가능
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 사용자 타입 확인
    SELECT user_type INTO v_user_type
    FROM public.users
    WHERE id = v_user_id;
    
    IF v_user_type != 'admin' THEN
        RAISE EXCEPTION 'Unauthorized: Only admins can view pending cash transactions';
    END IF;
    
    -- 상태 유효성 검사 (completed 제거)
    IF p_status IS NOT NULL AND p_status NOT IN ('pending', 'approved', 'rejected', 'cancelled') THEN
        RAISE EXCEPTION 'Invalid status. Must be one of: pending, approved, rejected, cancelled';
    END IF;
    
    -- 거래 타입 유효성 검사
    IF p_transaction_type IS NOT NULL AND p_transaction_type NOT IN ('deposit', 'withdraw') THEN
        RAISE EXCEPTION 'Invalid transaction_type. Must be deposit or withdraw';
    END IF;
    
    -- 사용자 타입 유효성 검사
    IF p_user_type IS NOT NULL AND p_user_type NOT IN ('advertiser', 'reviewer') THEN
        RAISE EXCEPTION 'Invalid user_type. Must be advertiser or reviewer';
    END IF;
    
    -- 거래 목록 조회 (completed_at 필드 제거)
    WITH filtered_transactions AS (
        SELECT 
            ct.id,
            ct.wallet_id,
            ct.transaction_type,
            ct.point_amount AS amount,
            ct.cash_amount,
            ct.payment_method,
            ct.bank_name,
            ct.account_number,
            ct.account_holder,
            ct.status,
            ct.description,
            ct.approved_by,
            ct.rejected_by,
            ct.rejection_reason,
            ct.created_by_user_id,
            ct.created_at,
            ct.updated_at,
            w.user_id,
            w.company_id,
            u.display_name AS user_name,
            au.email AS user_email,
            NULL::text AS user_phone,
            c.business_name AS company_name,
            c.business_number AS company_business_number
        FROM public.cash_transactions ct
        JOIN public.wallets w ON w.id = ct.wallet_id
        LEFT JOIN public.users u ON u.id = w.user_id
        LEFT JOIN auth.users au ON au.id = w.user_id
        LEFT JOIN public.companies c ON c.id = w.company_id
        WHERE 
            (p_status IS NULL OR ct.status = p_status)
            AND (p_transaction_type IS NULL OR ct.transaction_type = p_transaction_type)
            AND (
                p_user_type IS NULL 
                OR (p_user_type = 'advertiser' AND w.company_id IS NOT NULL)
                OR (p_user_type = 'reviewer' AND w.company_id IS NULL)
            )
    ),
    limited_transactions AS (
        SELECT *
        FROM filtered_transactions
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'wallet_id', wallet_id,
            'transaction_type', transaction_type,
            'amount', amount,
            'cash_amount', cash_amount,
            'payment_method', payment_method,
            'bank_name', bank_name,
            'account_number', account_number,
            'account_holder', account_holder,
            'status', status,
            'description', description,
            'approved_by', approved_by,
            'rejected_by', rejected_by,
            'rejection_reason', rejection_reason,
            'created_by_user_id', created_by_user_id,
            'created_at', created_at,
            'updated_at', updated_at,
            'user_id', user_id,
            'company_id', company_id,
            'user_name', user_name,
            'user_email', user_email,
            'user_phone', user_phone,
            'company_name', company_name,
            'company_business_number', company_business_number,
            'user_type', CASE 
                WHEN company_id IS NOT NULL THEN 'advertiser'
                ELSE 'reviewer'
            END
        )
    )
    INTO v_result
    FROM limited_transactions;
    
    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;


ALTER FUNCTION "public"."get_pending_cash_transactions"("p_status" "text", "p_transaction_type" "text", "p_user_type" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_pending_cash_transactions"("p_status" "text", "p_transaction_type" "text", "p_user_type" "text", "p_limit" integer, "p_offset" integer) IS '관리자용: 대기중인 현금 거래 목록 조회 (필터링 지원)';



CREATE OR REPLACE FUNCTION "public"."get_user_campaigns_safe"("p_user_id" "uuid", "p_status" "text" DEFAULT 'all'::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_campaigns jsonb;
  v_total_count integer;
  v_result jsonb;
  v_company_ids uuid[];
  v_status_filter text;
BEGIN
  -- 파라미터 검증
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id cannot be NULL';
  END IF;
  
  -- NULL 체크 및 기본값 설정
  v_status_filter := COALESCE(NULLIF(p_status, ''), 'all');
  
  -- 권한 확인: 자신의 캠페인이거나 관리자
  IF p_user_id != (SELECT auth.uid()) AND 
     NOT EXISTS (
       SELECT 1 FROM public.users 
       WHERE id = (SELECT auth.uid()) AND user_type = 'admin'
     ) THEN
    RAISE EXCEPTION 'You can only view your own campaigns';
  END IF;
  
  -- 사용자의 활성 회사 ID 목록 조회
  SELECT ARRAY_AGG(company_id) INTO v_company_ids
  FROM public.company_users
  WHERE user_id = p_user_id
    AND status = 'active';
  
  IF v_company_ids IS NULL OR array_length(v_company_ids, 1) IS NULL THEN
    -- 회사에 소속되지 않은 경우 빈 결과 반환
    SELECT jsonb_build_object(
      'campaigns', '[]'::jsonb,
      'total_count', 0,
      'limit', p_limit,
      'offset', p_offset
    ) INTO v_result;
    RETURN v_result;
  END IF;
  
  -- 캠페인 조회 (company_id 기반)
  -- jsonb_agg 사용 시 ORDER BY는 집계 함수 안에 포함해야 함
  SELECT jsonb_agg(
    jsonb_build_object(
      'campaign', row_to_json(c.*)
    ) ORDER BY c.created_at DESC
  ) INTO v_campaigns
  FROM (
    SELECT *
    FROM public.campaigns
    WHERE company_id = ANY(v_company_ids)
      AND (v_status_filter = 'all' OR status = v_status_filter)
    ORDER BY created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) c;
  
  -- 총 개수 조회
  SELECT COUNT(*) INTO v_total_count
  FROM public.campaigns
  WHERE company_id = ANY(v_company_ids)
    AND (v_status_filter = 'all' OR status = v_status_filter);
  
  -- 결과 반환
  SELECT jsonb_build_object(
    'campaigns', COALESCE(v_campaigns, '[]'::jsonb),
    'total_count', v_total_count,
    'limit', p_limit,
    'offset', p_offset
  ) INTO v_result;
  
  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error in get_user_campaigns_safe: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END;
$$;


ALTER FUNCTION "public"."get_user_campaigns_safe"("p_user_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_company_wallets"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("company_id" "uuid", "company_name" "text", "current_points" integer, "user_role" "text", "status" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id as company_id,
    c.business_name as company_name,
    cw.current_points,
    cu.company_role as user_role,
    cu.status
  FROM public.company_users cu
  JOIN public.companies c ON c.id = cu.company_id
  JOIN public.wallets cw ON cw.company_id = c.id AND cw.user_id IS NULL
  WHERE cu.user_id = COALESCE(p_user_id, auth.uid())
    AND cu.status = 'active'
    AND cu.company_role IN ('owner', 'manager')
  ORDER BY cu.company_role, c.business_name;
END;
$$;


ALTER FUNCTION "public"."get_user_company_wallets"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_participated_campaigns_safe"("p_user_id" "uuid", "p_status" "text" DEFAULT 'all'::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_campaigns jsonb;
  v_total_count integer;
  v_result jsonb;
BEGIN
  -- 권한 확인: 자신의 캠페인이거나 관리자
  IF p_user_id != (select auth.uid()) AND 
     NOT EXISTS (
       SELECT 1 FROM public.users 
       WHERE id = (select auth.uid()) AND user_type = 'admin'
     ) THEN
    RAISE EXCEPTION 'You can only view your own participated campaigns';
  END IF;
  
  -- 참여한 캠페인 조회
  SELECT jsonb_agg(
    jsonb_build_object(
      'campaign', campaigns.*,
      'log', campaign_logs.*
    )
  ) INTO v_campaigns
  FROM public.campaigns
  JOIN public.campaign_logs ON campaigns.id = campaign_logs.campaign_id
  WHERE campaign_logs.user_id = p_user_id
  AND (p_status = 'all' OR campaign_logs.status = p_status)
  ORDER BY campaign_logs.created_at DESC
  LIMIT p_limit OFFSET p_offset;
  
  -- 총 개수 조회
  SELECT COUNT(*) INTO v_total_count
  FROM public.campaign_logs
  WHERE user_id = p_user_id
  AND (p_status = 'all' OR status = p_status);
  
  -- 결과 반환
  SELECT jsonb_build_object(
    'campaigns', COALESCE(v_campaigns, '[]'::jsonb),
    'total_count', v_total_count,
    'limit', p_limit,
    'offset', p_offset
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_user_participated_campaigns_safe"("p_user_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_point_history"("p_user_id" "uuid", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("log_id" "uuid", "transaction_type" "text", "amount" integer, "description" "text", "related_entity_type" "text", "related_entity_id" "uuid", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    upl.id as log_id,
    upl.transaction_type,
    upl.amount,
    upl.description,
    upl.related_entity_type,
    upl.related_entity_id,
    upl.created_at
  FROM public.user_point_logs upl
  JOIN public.user_wallets uw ON uw.id = upl.user_wallet_id
  WHERE uw.user_id = p_user_id
  ORDER BY upl.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;


ALTER FUNCTION "public"."get_user_point_history"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_point_history_unified"("p_user_id" "uuid", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_result jsonb;
BEGIN
    WITH sorted_transactions AS (
        -- 캠페인 거래
        SELECT 
            pt.id,
            w.user_id,
            w.company_id,
            pt.wallet_id,
            pt.transaction_type,
            pt.amount,
            pt.campaign_id,
            pt.related_entity_type,
            pt.related_entity_id,
            pt.description,
            'completed' AS status,
            NULL::uuid AS approved_by,
            NULL::uuid AS rejected_by,
            NULL::text AS rejection_reason,
            pt.created_by_user_id,
            pt.created_at,
            pt.updated_at,
            pt.completed_at,
            'campaign' AS transaction_category,
            NULL::numeric AS cash_amount,
            NULL::text AS payment_method,
            NULL::text AS bank_name,
            NULL::text AS account_number,
            NULL::text AS account_holder
        FROM public.point_transactions pt
        JOIN public.wallets w ON w.id = pt.wallet_id
        WHERE w.user_id = p_user_id
        
        UNION ALL
        
        -- 현금 거래 (completed_at 제거)
        SELECT 
            pt.id,
            w.user_id,
            w.company_id,
            pt.wallet_id,
            pt.transaction_type,
            pt.point_amount AS amount,
            NULL::uuid AS campaign_id,
            NULL::text AS related_entity_type,
            NULL::uuid AS related_entity_id,
            pt.description,
            pt.status,
            pt.approved_by,
            pt.rejected_by,
            pt.rejection_reason,
            pt.created_by_user_id,
            pt.created_at,
            pt.updated_at,
            NULL::timestamp with time zone AS completed_at,
            'cash' AS transaction_category,
            pt.cash_amount,
            pt.payment_method,
            pt.bank_name,
            pt.account_number,
            pt.account_holder
        FROM public.cash_transactions pt
        JOIN public.wallets w ON w.id = pt.wallet_id
        WHERE w.user_id = p_user_id
    ),
    limited_transactions AS (
        SELECT *
        FROM sorted_transactions
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'user_id', user_id,
            'company_id', company_id,
            'wallet_id', wallet_id,
            'transaction_type', transaction_type,
            'amount', amount,
            'campaign_id', campaign_id,
            'related_entity_type', related_entity_type,
            'related_entity_id', related_entity_id,
            'description', description,
            'status', status,
            'approved_by', approved_by,
            'rejected_by', rejected_by,
            'rejection_reason', rejection_reason,
            'created_by_user_id', created_by_user_id,
            'created_at', created_at,
            'updated_at', updated_at,
            'completed_at', completed_at,
            'transaction_category', transaction_category,
            'cash_amount', cash_amount,
            'payment_method', payment_method,
            'bank_name', bank_name,
            'account_number', account_number,
            'account_holder', account_holder
        )
    )
    INTO v_result
    FROM limited_transactions;
    
    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;


ALTER FUNCTION "public"."get_user_point_history_unified"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_point_logs_safe"("p_user_id" "uuid", "p_transaction_type" "text" DEFAULT 'all'::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_logs jsonb;
  v_total_count integer;
  v_wallet_id uuid;
  v_result jsonb;
BEGIN
  -- 지갑 찾기
  SELECT id INTO v_wallet_id
  FROM public.point_wallets
  WHERE wallet_type = 'reviewer' AND user_id = p_user_id
  LIMIT 1;
  
  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Wallet not found';
  END IF;
  
  -- 권한 확인: 자신의 로그이거나 관리자
  IF p_user_id != (select auth.uid()) AND 
     NOT EXISTS (
       SELECT 1 FROM public.users 
       WHERE id = (select auth.uid()) AND user_type = 'admin'
     ) THEN
    RAISE EXCEPTION 'You can only view your own point logs';
  END IF;
  
  -- 로그 조회
  SELECT jsonb_agg(logs.* ORDER BY logs.created_at DESC) INTO v_logs
  FROM public.point_logs logs
  WHERE logs.wallet_id = v_wallet_id
  AND (p_transaction_type = 'all' OR logs.transaction_type = p_transaction_type)
  LIMIT p_limit OFFSET p_offset;
  
  -- 총 개수 조회
  SELECT COUNT(*) INTO v_total_count
  FROM public.point_logs
  WHERE wallet_id = v_wallet_id
  AND (p_transaction_type = 'all' OR transaction_type = p_transaction_type);
  
  -- 결과 반환
  SELECT jsonb_build_object(
    'logs', COALESCE(v_logs, '[]'::jsonb),
    'total_count', v_total_count,
    'limit', p_limit,
    'offset', p_offset
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_user_point_logs_safe"("p_user_id" "uuid", "p_transaction_type" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_profile jsonb;
  v_current_user_type text;
  v_target_user_id uuid;
  v_company_role text;
  v_company_id uuid;
BEGIN
  -- 기본값은 현재 사용자
  v_target_user_id := COALESCE(p_user_id, (select auth.uid()));
  
  -- 권한 확인: 자신의 프로필이거나 관리자
  IF v_target_user_id != (select auth.uid()) THEN
    SELECT user_type INTO v_current_user_type
    FROM public.users 
    WHERE id = (select auth.uid());
    
    IF v_current_user_type != 'admin' THEN
      RAISE EXCEPTION 'You can only view your own profile';
    END IF;
  END IF;
  
  -- company_users 테이블에서 company_role과 company_id 조회 (status='active'만)
  SELECT cu.company_role, cu.company_id
  INTO v_company_role, v_company_id
  FROM public.company_users cu
  WHERE cu.user_id = v_target_user_id
    AND cu.status = 'active'
  LIMIT 1;
  
  -- 프로필 조회 및 company_role, company_id, sns_connections 추가
  SELECT jsonb_build_object(
    'id', u.id,
    'created_at', u.created_at,
    'updated_at', u.updated_at,
    'display_name', u.display_name,
    'user_type', u.user_type,
    'status', u.status,
    'company_id', v_company_id,
    'company_role', v_company_role,
    'sns_connections', COALESCE(
      (SELECT jsonb_agg(
        jsonb_build_object(
          'id', sc.id,
          'user_id', sc.user_id,
          'platform', sc.platform,
          'platform_account_id', sc.platform_account_id,
          'platform_account_name', sc.platform_account_name,
          'phone', sc.phone,
          'address', sc.address,
          'return_address', sc.return_address,
          'created_at', sc.created_at,
          'updated_at', sc.updated_at
        )
      )
      FROM public.sns_connections sc
      WHERE sc.user_id = v_target_user_id),
      '[]'::jsonb
    )
  ) INTO v_profile
  FROM public.users u
  WHERE u.id = v_target_user_id;
  
  IF v_profile IS NULL THEN
    RAISE EXCEPTION 'User profile not found';
  END IF;
  
  RETURN v_profile;
END;
$$;


ALTER FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_transfers"("p_user_id" "uuid", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', pt.id,
            'from_wallet_id', pt.from_wallet_id,
            'to_wallet_id', pt.to_wallet_id,
            'amount', pt.amount,
            'description', pt.description,
            'created_by_user_id', pt.created_by_user_id,
            'created_at', pt.created_at,
            'updated_at', pt.updated_at,
            -- 출발 지갑 정보
            'from_wallet', jsonb_build_object(
                'id', w1.id,
                'user_id', w1.user_id,
                'company_id', w1.company_id,
                'current_points', w1.current_points
            ),
            -- 도착 지갑 정보
            'to_wallet', jsonb_build_object(
                'id', w2.id,
                'user_id', w2.user_id,
                'company_id', w2.company_id,
                'current_points', w2.current_points
            )
        )
    )
    INTO v_result
    FROM point_transfers pt
    JOIN public.wallets w1 ON w1.id = pt.from_wallet_id
    JOIN public.wallets w2 ON w2.id = pt.to_wallet_id
    WHERE (w1.user_id = p_user_id OR w2.user_id = p_user_id OR
           (w1.company_id IS NOT NULL AND EXISTS (
               SELECT 1 FROM company_users cu
               WHERE cu.company_id = w1.company_id
               AND cu.user_id = p_user_id
               AND cu.status = 'active'
           )) OR
           (w2.company_id IS NOT NULL AND EXISTS (
               SELECT 1 FROM company_users cu
               WHERE cu.company_id = w2.company_id
               AND cu.user_id = p_user_id
               AND cu.status = 'active'
           )))
    ORDER BY pt.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
    
    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;


ALTER FUNCTION "public"."get_user_transfers"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_user_transfers"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) IS '사용자 관련 포인트 이동 내역 조회 (point_transfers 전용)';



CREATE OR REPLACE FUNCTION "public"."get_user_wallet"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("user_id" "uuid", "current_points" integer, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    uw.user_id,
    uw.current_points,
    uw.created_at,
    uw.updated_at
  FROM public.user_wallets uw
  WHERE uw.user_id = COALESCE(p_user_id, auth.uid());
END;
$$;


ALTER FUNCTION "public"."get_user_wallet"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_wallet_safe"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_wallet jsonb;
BEGIN
  -- 권한 확인: 자신의 지갑이거나 관리자
  IF p_user_id != (select auth.uid()) AND 
     NOT EXISTS (
       SELECT 1 FROM public.users 
       WHERE id = (select auth.uid()) AND user_type = 'admin'
     ) THEN
    RAISE EXCEPTION 'You can only view your own wallets';
  END IF;
  
  -- 지갑 조회
  SELECT jsonb_build_object(
    'wallet', wallets.*,
    'logs', logs.logs
  ) INTO v_wallet
  FROM public.point_wallets wallets
  LEFT JOIN LATERAL (
    SELECT jsonb_agg(logs.* ORDER BY logs.created_at DESC) as logs
    FROM public.point_logs logs
    WHERE logs.wallet_id = wallets.id
  ) logs ON true
  WHERE wallets.wallet_type = 'reviewer' AND wallets.user_id = p_user_id
  LIMIT 1;
  
  IF v_wallet IS NULL THEN
    RAISE EXCEPTION 'Wallet not found';
  END IF;
  
  RETURN v_wallet;
END;
$$;


ALTER FUNCTION "public"."get_user_wallet_safe"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_wallets"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_wallets jsonb;
BEGIN
  -- 권한 확인: 자신의 지갑이거나 관리자
  IF p_user_id != (select auth.uid()) AND 
     NOT EXISTS (
       SELECT 1 FROM public.users 
       WHERE id = (select auth.uid()) AND user_type = 'admin'
     ) THEN
    RAISE EXCEPTION 'You can only view your own wallets';
  END IF;
  
  -- 지갑 조회
  SELECT jsonb_agg(
    jsonb_build_object(
      'wallet_id', pw.id,
      'wallet_type', pw.wallet_type,
      'user_id', pw.user_id,
      'current_points', pw.current_points,
      'created_at', pw.created_at,
      'updated_at', pw.updated_at
    )
  ) INTO v_wallets
  FROM public.point_wallets pw
  WHERE pw.wallet_type = 'reviewer' AND pw.user_id = p_user_id;
  
  RETURN COALESCE(v_wallets, '[]'::jsonb);
END;
$$;


ALTER FUNCTION "public"."get_user_wallets"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_wallet_by_company_id"("p_company_id" "uuid") RETURNS TABLE("id" "uuid", "company_id" "uuid", "user_id" "uuid", "current_points" integer, "withdraw_bank_name" "text", "withdraw_account_number" "text", "withdraw_account_holder" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE
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


ALTER FUNCTION "public"."get_wallet_by_company_id"("p_company_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_wallet_by_user_id"("p_user_id" "uuid") RETURNS TABLE("id" "uuid", "company_id" "uuid", "user_id" "uuid", "current_points" integer, "withdraw_bank_name" "text", "withdraw_account_number" "text", "withdraw_account_holder" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE
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


ALTER FUNCTION "public"."get_wallet_by_user_id"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_wallet_info"("p_wallet_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_wallet jsonb;
BEGIN
  -- 권한 확인: 지갑 소유자이거나 관리자
  IF NOT EXISTS (
    SELECT 1 FROM public.point_wallets pw
    WHERE pw.id = p_wallet_id
    AND (
      (pw.wallet_type = 'reviewer' AND pw.user_id = (select auth.uid())) OR
      (pw.wallet_type = 'company' AND pw.user_id IN (
        SELECT company_id FROM public.company_users WHERE user_id = (select auth.uid())
      )) OR
      EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = (select auth.uid()) AND user_type = 'admin'
      )
    )
  ) THEN
    RAISE EXCEPTION 'You can only view wallets you own or have access to';
  END IF;
  
  -- 지갑 정보 조회
  SELECT jsonb_build_object(
    'wallet_id', pw.id,
    'wallet_type', pw.wallet_type,
    'user_id', pw.user_id,
    'current_points', pw.current_points,
    'created_at', pw.created_at,
    'updated_at', pw.updated_at
  ) INTO v_wallet
  FROM public.point_wallets pw
  WHERE pw.id = p_wallet_id;
  
  IF v_wallet IS NULL THEN
    RAISE EXCEPTION 'Wallet not found';
  END IF;
  
  RETURN v_wallet;
END;
$$;


ALTER FUNCTION "public"."get_wallet_info"("p_wallet_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_wallet_logs"("p_wallet_id" "uuid", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_logs jsonb;
  v_total_count integer;
  v_result jsonb;
BEGIN
  -- 권한 확인: 지갑 소유자이거나 관리자
  IF NOT EXISTS (
    SELECT 1 FROM public.point_wallets pw
    WHERE pw.id = p_wallet_id
    AND (
      (pw.wallet_type = 'reviewer' AND pw.user_id = (select auth.uid())) OR
      (pw.wallet_type = 'company' AND pw.user_id IN (
        SELECT company_id FROM public.company_users WHERE user_id = (select auth.uid())
      )) OR
      EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = (select auth.uid()) AND user_type = 'admin'
      )
    )
  ) THEN
    RAISE EXCEPTION 'You can only view logs for wallets you own or have access to';
  END IF;
  
  -- 로그 조회
  SELECT jsonb_agg(logs.* ORDER BY logs.created_at DESC) INTO v_logs
  FROM public.point_logs logs
  WHERE logs.wallet_id = p_wallet_id
  LIMIT p_limit OFFSET p_offset;
  
  -- 총 개수 조회
  SELECT COUNT(*) INTO v_total_count
  FROM public.point_logs
  WHERE wallet_id = p_wallet_id;
  
  -- 결과 반환
  SELECT jsonb_build_object(
    'logs', COALESCE(v_logs, '[]'::jsonb),
    'total_count', v_total_count,
    'limit', p_limit,
    'offset', p_offset
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_wallet_logs"("p_wallet_id" "uuid", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."join_campaign_safe"("p_campaign_id" "uuid", "p_application_message" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid;
    v_campaign jsonb;
    v_log_id uuid;
    v_result jsonb;
BEGIN
    v_user_id := (select auth.uid());
    
    -- 캠페인 정보 조회
    SELECT to_jsonb(campaigns.*) INTO v_campaign
    FROM public.campaigns 
    WHERE id = p_campaign_id AND status = 'active';
    
    IF v_campaign IS NULL THEN
        RAISE EXCEPTION 'Campaign not found or not active';
    END IF;
    
    -- 중복 신청 확인
    IF EXISTS (
        SELECT 1 FROM public.campaign_logs 
        WHERE campaign_id = p_campaign_id AND user_id = v_user_id
    ) THEN
        RAISE EXCEPTION 'Already applied to this campaign';
    END IF;
    
    -- 최대 참여자 수 확인
    IF (v_campaign->>'current_participants')::integer >= (v_campaign->>'max_participants')::integer THEN
        RAISE EXCEPTION 'Campaign is full';
    END IF;
    
    -- 캠페인 로그 생성
    INSERT INTO public.campaign_logs (
        campaign_id, user_id, action, application_message, status
    ) VALUES (
        p_campaign_id, v_user_id, 'join', p_application_message, 'pending'
    ) RETURNING id INTO v_log_id;
    
    -- 캠페인 참여자 수 증가
    UPDATE public.campaigns 
    SET current_participants = current_participants + 1,
        updated_at = NOW()
    WHERE id = p_campaign_id;
    
    -- 결과 반환
    SELECT jsonb_build_object(
        'success', true,
        'log_id', v_log_id,
        'campaign', v_campaign
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."join_campaign_safe"("p_campaign_id" "uuid", "p_application_message" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."leave_campaign_safe"("p_campaign_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid;
    v_log_id uuid;
    v_result jsonb;
BEGIN
    v_user_id := (select auth.uid());
    
    -- 기존 신청 확인
    SELECT id INTO v_log_id
    FROM public.campaign_logs 
    WHERE campaign_id = p_campaign_id AND user_id = v_user_id;
    
    IF v_log_id IS NULL THEN
        RAISE EXCEPTION 'No application found for this campaign';
    END IF;
    
    -- 캠페인 로그 업데이트
    UPDATE public.campaign_logs 
    SET action = 'leave', status = 'cancelled', updated_at = NOW()
    WHERE id = v_log_id;
    
    -- 캠페인 참여자 수 감소
    UPDATE public.campaigns 
    SET current_participants = GREATEST(current_participants - 1, 0),
        updated_at = NOW()
    WHERE id = p_campaign_id;
    
    -- 결과 반환
    SELECT jsonb_build_object(
        'success', true,
        'log_id', v_log_id
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."leave_campaign_safe"("p_campaign_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_cash_transaction_change"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- 거래 생성 시: pending 상태로 로그 생성
        INSERT INTO public.cash_transaction_logs (
            transaction_id,
            status,
            changed_by
        ) VALUES (
            NEW.id,
            NEW.status, -- 거래 생성 시점의 상태 (보통 'pending')
            NEW.created_by_user_id
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        -- 상태 변경 추적: 상태가 변경될 때만 로그 생성
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            INSERT INTO public.cash_transaction_logs (
                transaction_id,
                status,
                changed_by,
                change_reason
            ) VALUES (
                NEW.id,
                NEW.status, -- 새로운 상태 값
                COALESCE(NEW.approved_by, NEW.rejected_by, NEW.created_by_user_id),
                CASE 
                    WHEN NEW.status = 'rejected' THEN NEW.rejection_reason
                    ELSE 'Status changed to ' || NEW.status
                END
            );
        END IF;
        -- 상태가 변경되지 않은 경우 로그를 생성하지 않음
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."log_cash_transaction_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_point_transaction_change"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.point_transaction_logs (
            transaction_id,
            action,
            changed_by
        ) VALUES (
            NEW.id,
            'created',
            NEW.created_by_user_id
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.point_transaction_logs (
            transaction_id,
            action,
            changed_by,
            change_reason
        ) VALUES (
            NEW.id,
            'updated',
            NEW.created_by_user_id,
            'Transaction updated'
        );
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."log_point_transaction_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_wallet_account_change"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    -- 계좌 정보가 변경된 경우에만 기록
    IF (OLD.withdraw_bank_name IS DISTINCT FROM NEW.withdraw_bank_name) OR
       (OLD.withdraw_account_number IS DISTINCT FROM NEW.withdraw_account_number) OR
       (OLD.withdraw_account_holder IS DISTINCT FROM NEW.withdraw_account_holder) THEN
        
        -- 누적 로그로 INSERT (여러 기록 가능)
        INSERT INTO wallet_histories (
            wallet_id,
            old_bank_name,
            old_account_number,
            old_account_holder,
            new_bank_name,
            new_account_number,
            new_account_holder,
            changed_by,
            created_at
        ) VALUES (
            NEW.id,
            OLD.withdraw_bank_name,
            OLD.withdraw_account_number,
            OLD.withdraw_account_holder,
            NEW.withdraw_bank_name,
            NEW.withdraw_account_number,
            NEW.withdraw_account_holder,
            (SELECT auth.uid()),
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."log_wallet_account_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_company"("p_user_id" "uuid", "p_business_name" "text", "p_business_number" "text", "p_address" "text", "p_representative_name" "text", "p_business_type" "text", "p_registration_file_url" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_company_id uuid;
  v_result jsonb;
  v_cleaned_business_number text;
BEGIN
  -- 권한 확인: 자신의 데이터만 저장 가능
  IF p_user_id != (SELECT auth.uid()) THEN
    RAISE EXCEPTION 'Unauthorized: Can only register company for yourself';
  END IF;

  -- 사업자번호 정리 (하이픈 제거)
  v_cleaned_business_number := REPLACE(p_business_number, '-', '');

  -- 중복 체크 (트랜잭션 내에서)
  IF EXISTS (
    SELECT 1 FROM public.companies 
    WHERE business_number = v_cleaned_business_number
  ) THEN
    RAISE EXCEPTION '이미 등록된 사업자번호입니다.';
  END IF;

  -- 회사 정보 저장
  INSERT INTO public.companies (
    user_id,
    business_name,
    business_number,
    address,
    representative_name,
    business_type,
    registration_file_url,
    created_at,
    updated_at
  ) VALUES (
    p_user_id,
    p_business_name,
    v_cleaned_business_number,
    p_address,
    p_representative_name,
    p_business_type,
    p_registration_file_url,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_company_id;

  -- company_users 관계 추가 (중복 체크 후)
  IF NOT EXISTS (
    SELECT 1 FROM public.company_users 
    WHERE company_id = v_company_id 
    AND user_id = p_user_id
  ) THEN
    INSERT INTO public.company_users (
      company_id,
      user_id,
      company_role,
      status,
      created_at
    ) VALUES (
      v_company_id,
      p_user_id,
      'owner',
      'active',
      NOW()
    );
  END IF;

  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'company_id', v_company_id,
    'business_number', v_cleaned_business_number
  ) INTO v_result;

  RETURN v_result;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION '이미 등록된 사업자번호입니다.';
  WHEN OTHERS THEN
    RAISE EXCEPTION '회사 등록 실패: %', SQLERRM;
END;
$$;


ALTER FUNCTION "public"."register_company"("p_user_id" "uuid", "p_business_name" "text", "p_business_number" "text", "p_address" "text", "p_representative_name" "text", "p_business_type" "text", "p_registration_file_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reject_manager"("p_company_id" "uuid", "p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- 권한 확인: 회사 소유자 또는 활성 매니저만 거절 가능
  IF NOT EXISTS (
    SELECT 1 FROM public.company_users cu
    WHERE cu.company_id = p_company_id
      AND cu.user_id = (SELECT auth.uid())
      AND cu.company_role IN ('owner', 'manager')
      AND cu.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Only company owners and active managers can reject managers';
  END IF;
  
  -- status를 'rejected'로 업데이트 (복합 키 사용)
  UPDATE public.company_users
  SET status = 'rejected'
  WHERE company_id = p_company_id
    AND user_id = p_user_id
    AND status = 'pending'
    AND company_role = 'manager';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Manager request not found or already processed';
  END IF;
  
  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'company_id', p_company_id,
    'user_id', p_user_id,
    'status', 'rejected'
  ) INTO v_result;
  
  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$$;


ALTER FUNCTION "public"."reject_manager"("p_company_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."reject_manager"("p_company_id" "uuid", "p_user_id" "uuid") IS '매니저 거절 (복합 키 사용: company_id + user_id)';



CREATE OR REPLACE FUNCTION "public"."request_manager_role"("p_business_name" "text", "p_business_number" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_user_id uuid;
  v_company_id uuid;
  v_result jsonb;
  v_cleaned_business_number text;
BEGIN
  -- 현재 사용자 ID 가져오기
  v_user_id := (SELECT auth.uid());
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Must be logged in';
  END IF;

  -- 사업자번호 정리 (하이픈 제거)
  v_cleaned_business_number := REPLACE(p_business_number, '-', '');

  -- 회사 존재 여부 확인
  SELECT id INTO v_company_id
  FROM public.companies
  WHERE business_number = v_cleaned_business_number
    AND business_name = p_business_name
  LIMIT 1;

  -- 회사가 존재하지 않으면 에러
  IF v_company_id IS NULL THEN
    RAISE EXCEPTION '등록된 사업자정보가 없습니다.';
  END IF;

  -- 이미 등록된 관계가 있는지 확인
  IF EXISTS (
    SELECT 1 FROM public.company_users
    WHERE company_id = v_company_id
      AND user_id = v_user_id
  ) THEN
    -- 이미 존재하면 status를 pending으로 업데이트
    UPDATE public.company_users
    SET status = 'pending',
        company_role = 'manager',
        created_at = NOW()
    WHERE company_id = v_company_id
      AND user_id = v_user_id;
  ELSE
    -- 없으면 새로 추가
    INSERT INTO public.company_users (
      company_id,
      user_id,
      company_role,
      status,
      created_at
    ) VALUES (
      v_company_id,
      v_user_id,
      'manager',
      'pending',
      NOW()
    );
  END IF;

  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'company_id', v_company_id,
    'business_name', p_business_name,
    'business_number', v_cleaned_business_number,
    'message', '매니저 등록 요청이 완료되었습니다. 승인 대기 중입니다.'
  ) INTO v_result;

  RETURN v_result;

EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$$;


ALTER FUNCTION "public"."request_manager_role"("p_business_name" "text", "p_business_number" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."request_point_charge"("p_user_id" "uuid", "p_amount" integer, "p_cash_amount" double precision, "p_payment_method" "text" DEFAULT '신용카드'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_charge_id uuid;
    v_wallet_id uuid;
    v_result jsonb;
BEGIN
    -- 권한 확인: 자신의 포인트 충전이거나 관리자
    IF p_user_id != (select auth.uid()) AND 
       NOT EXISTS (
           SELECT 1 FROM public.users 
           WHERE id = (select auth.uid()) AND user_type IN ('ADMIN', 'OWNER')
       ) THEN
        RAISE EXCEPTION 'You can only request point charges for yourself';
    END IF;
    
    -- 사용자 지갑 찾기
    SELECT id INTO v_wallet_id
    FROM public.point_wallets
    WHERE owner_type = 'USER' AND owner_id = p_user_id
    LIMIT 1;
    
    IF v_wallet_id IS NULL THEN
        RAISE EXCEPTION 'User wallet not found';
    END IF;
    
    -- 충전 요청 로그 생성 (실제 결제 시스템과 연동 필요)
    INSERT INTO public.point_logs (
        wallet_id, transaction_type, amount, description, related_entity_type, related_entity_id
    ) VALUES (
        v_wallet_id, 'earn', p_amount, 
        CONCAT('포인트 충전 요청 (', p_cash_amount, '원, ', p_payment_method, ')'),
        'charge_request', gen_random_uuid()
    ) RETURNING id INTO v_charge_id;
    
    -- 결과 반환
    SELECT jsonb_build_object(
        'success', true,
        'charge_id', v_charge_id,
        'amount', p_amount,
        'cash_amount', p_cash_amount,
        'payment_method', p_payment_method,
        'status', 'pending'
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."request_point_charge"("p_user_id" "uuid", "p_amount" integer, "p_cash_amount" double precision, "p_payment_method" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."request_point_charge_safe"("p_user_id" "uuid", "p_amount" integer, "p_payment_method" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_charge_id uuid;
  v_result jsonb;
BEGIN
  -- 권한 확인: 자신의 충전 요청이거나 관리자
  IF p_user_id != (select auth.uid()) AND 
     NOT EXISTS (
       SELECT 1 FROM public.users 
       WHERE id = (select auth.uid()) AND user_type = 'admin'
     ) THEN
    RAISE EXCEPTION 'You can only request point charges for yourself';
  END IF;
  
  -- 충전 요청 생성
  INSERT INTO public.point_charges (
    user_id, amount, payment_method, status, created_at
  ) VALUES (
    p_user_id, p_amount, p_payment_method, 'pending', NOW()
  ) RETURNING id INTO v_charge_id;
  
  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'charge_id', v_charge_id,
    'amount', p_amount,
    'status', 'pending'
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."request_point_charge_safe"("p_user_id" "uuid", "p_amount" integer, "p_payment_method" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."spend_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text" DEFAULT NULL::"text", "p_related_entity_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_wallet_id uuid;
    v_current_points integer;
    v_new_balance integer;
    v_log_id uuid;
    v_result jsonb;
BEGIN
    -- 권한 확인: 자신의 포인트 사용이거나 관리자
    IF p_user_id != (select auth.uid()) AND 
       NOT EXISTS (
           SELECT 1 FROM public.users 
           WHERE id = (select auth.uid()) AND user_type IN ('ADMIN', 'OWNER')
       ) THEN
        RAISE EXCEPTION 'You can only spend your own points';
    END IF;
    
    -- 사용자 지갑 찾기
    SELECT id, current_points INTO v_wallet_id, v_current_points
    FROM public.point_wallets
    WHERE owner_type = 'USER' AND owner_id = p_user_id
    LIMIT 1;
    
    IF v_wallet_id IS NULL THEN
        RAISE EXCEPTION 'User wallet not found';
    END IF;
    
    -- 잔액 확인
    IF v_current_points < p_amount THEN
        RAISE EXCEPTION 'Insufficient points';
    END IF;
    
    -- 포인트 차감
    v_new_balance := v_current_points - p_amount;
    
    UPDATE public.point_wallets
    SET current_points = v_new_balance, updated_at = NOW()
    WHERE id = v_wallet_id;
    
    -- 사용 로그 생성
    INSERT INTO public.point_logs (
        wallet_id, transaction_type, amount, description, related_entity_type, related_entity_id
    ) VALUES (
        v_wallet_id, 'spend', -p_amount, p_description, p_related_entity_type, p_related_entity_id
    ) RETURNING id INTO v_log_id;
    
    -- 결과 반환
    SELECT jsonb_build_object(
        'success', true,
        'log_id', v_log_id,
        'amount_spent', p_amount,
        'new_balance', v_new_balance,
        'description', p_description
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."spend_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."spend_points_safe"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text" DEFAULT NULL::"text", "p_related_entity_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_wallet_id uuid;
  v_current_points integer;
  v_new_balance integer;
  v_log_id uuid;
  v_result jsonb;
BEGIN
  -- 권한 확인: 자신의 포인트 사용이거나 관리자
  IF p_user_id != (select auth.uid()) AND 
     NOT EXISTS (
       SELECT 1 FROM public.users 
       WHERE id = (select auth.uid()) AND user_type = 'admin'
     ) THEN
    RAISE EXCEPTION 'You can only spend your own points';
  END IF;
  
  -- 트랜잭션 시작: 포인트 지갑 업데이트와 로그 생성을 원자적으로 처리
  BEGIN
    -- 포인트 지갑 조회 및 업데이트 (행 잠금으로 동시성 제어)
    SELECT id, current_points INTO v_wallet_id, v_current_points
    FROM public.point_wallets
    WHERE wallet_type = 'reviewer' AND user_id = p_user_id
    FOR UPDATE -- 행 잠금으로 동시성 제어
    LIMIT 1;
    
    IF v_wallet_id IS NULL THEN
      RAISE EXCEPTION 'Wallet not found';
    END IF;
    
    -- 잔액 확인
    IF v_current_points < p_amount THEN
      RAISE EXCEPTION 'Insufficient points';
    END IF;
    
    -- 포인트 차감
    v_new_balance := v_current_points - p_amount;
    
    UPDATE public.point_wallets
    SET current_points = v_new_balance, updated_at = NOW()
    WHERE id = v_wallet_id;
    
    -- 사용 로그 생성
    INSERT INTO public.point_logs (
      wallet_id, transaction_type, amount, description, related_entity_type, related_entity_id
    ) VALUES (
      v_wallet_id, 'spend', p_amount, p_description, p_related_entity_type, p_related_entity_id
    ) RETURNING id INTO v_log_id;
    
    -- 결과 반환 (기존 형식 유지)
    SELECT jsonb_build_object(
      'success', true,
      'log_id', v_log_id,
      'amount_spent', p_amount,
      'new_balance', v_new_balance,
      'description', p_description
    ) INTO v_result;
    
    RETURN v_result;
    
  EXCEPTION
    WHEN OTHERS THEN
      -- 에러 발생 시 자동으로 롤백됨 (함수 내부의 EXCEPTION 블록)
      RAISE;
  END;
END;
$$;


ALTER FUNCTION "public"."spend_points_safe"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."spend_points_safe"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") IS '포인트 사용과 로그 생성을 원자적으로 처리합니다. 에러 발생 시 모든 작업이 롤백됩니다.';



CREATE OR REPLACE FUNCTION "public"."sync_campaign_actions_on_event"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  -- 1. campaign_actions 테이블 업데이트 (또는 INSERT)
  INSERT INTO "public"."campaign_actions" (
    "campaign_id",
    "user_id",
    "current_action",
    "last_updated_at"
  )
  VALUES (
    NEW."campaign_id",
    NEW."user_id",
    NEW."action",
    NEW."created_at"
  )
  ON CONFLICT ("campaign_id", "user_id") 
  DO UPDATE SET
    "current_action" = EXCLUDED."current_action",
    "last_updated_at" = EXCLUDED."last_updated_at";

  -- 2. 이벤트가 '완료' 또는 'complete'이고 status가 'completed'인 경우 completed_applicants_count 증가
  -- jsonb 필드에서 type 값을 추출하여 비교
  IF (
    (NEW."action"->>'type' IN ('완료', 'complete')) 
    AND NEW."status" = 'completed'
  ) THEN
    UPDATE "public"."campaigns"
    SET "completed_applicants_count" = "completed_applicants_count" + 1
    WHERE "id" = NEW."campaign_id"
      AND NOT EXISTS (
        -- 이전에 '완료' 상태였던 이벤트가 있는지 확인
        SELECT 1
        FROM "public"."campaign_action_logs" ce
        WHERE ce."campaign_id" = NEW."campaign_id"
          AND ce."user_id" = NEW."user_id"
          AND ce."action"->>'type' IN ('완료', 'complete')
          AND ce."status" = 'completed'
          AND ce."created_at" < NEW."created_at"
      );
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_campaign_actions_on_event"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_campaign_actions_on_event"() IS 'campaign_action_logs 테이블에 새 이벤트가 INSERT될 때 campaign_actions와 campaigns.completed_applicants_count를 자동으로 동기화합니다.';



CREATE OR REPLACE FUNCTION "public"."transfer_points_between_wallets"("p_from_wallet_id" "uuid", "p_to_wallet_id" "uuid", "p_amount" integer, "p_description" "text" DEFAULT NULL::"text", "p_created_by_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_from_wallet RECORD;
    v_to_wallet RECORD;
    v_user_id UUID;
    v_transfer_id UUID;
    v_result JSONB;
BEGIN
    -- 현재 사용자 확인
    v_user_id := COALESCE(p_created_by_user_id, auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    
    -- 출발 지갑 정보 조회
    SELECT id, user_id, company_id, current_points INTO v_from_wallet
    FROM wallets
    WHERE id = p_from_wallet_id;
    
    IF v_from_wallet IS NULL THEN
        RAISE EXCEPTION 'From wallet not found';
    END IF;
    
    -- 도착 지갑 정보 조회
    SELECT id, user_id, company_id INTO v_to_wallet
    FROM wallets
    WHERE id = p_to_wallet_id;
    
    IF v_to_wallet IS NULL THEN
        RAISE EXCEPTION 'To wallet not found';
    END IF;
    
    -- 금액 검증
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be positive';
    END IF;
    
    -- 잔액 검증
    IF v_from_wallet.current_points < p_amount THEN
        RAISE EXCEPTION 'Insufficient balance';
    END IF;
    
    -- 권한 검증: 회사 소유자만 이동 가능
    -- 케이스 1: 개인 → 회사
    IF v_from_wallet.user_id = v_user_id AND v_to_wallet.company_id IS NOT NULL THEN
        -- 사용자가 해당 회사의 owner인지 확인
        IF NOT EXISTS (
            SELECT 1 FROM company_users
            WHERE company_id = v_to_wallet.company_id
            AND user_id = v_user_id
            AND company_role = 'owner'
            AND status = 'active'
        ) THEN
            RAISE EXCEPTION 'Only company owner can transfer points to company wallet';
        END IF;
    -- 케이스 2: 회사 → 개인
    ELSIF v_from_wallet.company_id IS NOT NULL AND v_to_wallet.user_id = v_user_id THEN
        -- 사용자가 해당 회사의 owner인지 확인
        IF NOT EXISTS (
            SELECT 1 FROM company_users
            WHERE company_id = v_from_wallet.company_id
            AND user_id = v_user_id
            AND company_role = 'owner'
            AND status = 'active'
        ) THEN
            RAISE EXCEPTION 'Only company owner can transfer points from company wallet';
        END IF;
    ELSE
        RAISE EXCEPTION 'Invalid transfer: must be between user wallet and company wallet owned by the user';
    END IF;
    
    -- point_transfers 테이블에 이동 기록 생성
    INSERT INTO point_transfers (
        from_wallet_id,
        to_wallet_id,
        amount,
        description,
        created_by_user_id
    ) VALUES (
        p_from_wallet_id,
        p_to_wallet_id,
        p_amount,
        COALESCE(p_description, '포인트 이동'),
        v_user_id
    )
    RETURNING id INTO v_transfer_id;
    
    -- 출발 지갑 거래 생성 (point_transactions에 차감 기록)
    INSERT INTO public.point_transactions (
        wallet_id,
        transaction_type,
        amount,
        related_entity_type,
        related_entity_id,
        description,
        created_by_user_id,
        completed_at
    ) VALUES (
        p_from_wallet_id,
        'spend',  -- 차감
        -p_amount,  -- 음수
        'transfer',
        v_transfer_id,  -- point_transfers.id 참조
        COALESCE(p_description, '포인트 이동'),
        v_user_id,
        NOW()
    );
    
    -- 도착 지갑 거래 생성 (point_transactions에 증가 기록)
    INSERT INTO public.point_transactions (
        wallet_id,
        transaction_type,
        amount,
        related_entity_type,
        related_entity_id,
        description,
        created_by_user_id,
        completed_at
    ) VALUES (
        p_to_wallet_id,
        'earn',  -- 증가
        p_amount,  -- 양수
        'transfer',
        v_transfer_id,  -- point_transfers.id 참조
        COALESCE(p_description, '포인트 이동'),
        v_user_id,
        NOW()
    );
    
    -- 결과 반환
    v_result := jsonb_build_object(
        'transfer_id', v_transfer_id,
        'from_wallet_id', p_from_wallet_id,
        'to_wallet_id', p_to_wallet_id,
        'amount', p_amount
    );
    
    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."transfer_points_between_wallets"("p_from_wallet_id" "uuid", "p_to_wallet_id" "uuid", "p_amount" integer, "p_description" "text", "p_created_by_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."transfer_points_between_wallets"("p_from_wallet_id" "uuid", "p_to_wallet_id" "uuid", "p_amount" integer, "p_description" "text", "p_created_by_user_id" "uuid") IS '포인트 지갑 간 이동 (회사 소유자만 가능, 개인 ↔ 회사, point_transfers 테이블 사용)';



CREATE OR REPLACE FUNCTION "public"."update_campaign_status"("p_campaign_id" "uuid", "p_status" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_user_id UUID;
  v_company_id UUID;
  v_campaign_company_id UUID;
  v_current_participants INTEGER;
BEGIN
  -- 1. 현재 사용자 확인
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 2. 사용자의 회사 ID 조회
  SELECT cu.company_id INTO v_company_id
  FROM public.company_users cu
  WHERE cu.user_id = v_user_id
    AND cu.status = 'active'
    AND cu.company_role IN ('owner', 'manager')
  LIMIT 1;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION '회사에 소속되지 않았거나 권한이 없습니다';
  END IF;

  -- 3. 캠페인 소유권 확인
  SELECT company_id, current_participants
  INTO v_campaign_company_id, v_current_participants
  FROM public.campaigns
  WHERE id = p_campaign_id;

  IF v_campaign_company_id IS NULL THEN
    RAISE EXCEPTION '캠페인을 찾을 수 없습니다';
  END IF;

  IF v_campaign_company_id != v_company_id THEN
    RAISE EXCEPTION '이 캠페인을 수정할 권한이 없습니다';
  END IF;

  -- 4. 상태 유효성 검증
  IF p_status NOT IN ('active', 'inactive') THEN
    RAISE EXCEPTION '유효하지 않은 상태입니다';
  END IF;

  -- 5. 상태 업데이트
  UPDATE public.campaigns
  SET status = p_status,
      updated_at = NOW()
  WHERE id = p_campaign_id;

  RETURN jsonb_build_object(
    'success', true,
    'campaign_id', p_campaign_id,
    'status', p_status
  );
END;
$$;


ALTER FUNCTION "public"."update_campaign_status"("p_campaign_id" "uuid", "p_status" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."update_campaign_status"("p_campaign_id" "uuid", "p_status" "text") IS '캠페인 상태 업데이트 (active/inactive)';



CREATE OR REPLACE FUNCTION "public"."update_cash_transaction_status"("p_transaction_id" "uuid", "p_status" "text", "p_rejection_reason" "text" DEFAULT NULL::"text", "p_updated_by_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_current_status TEXT;
BEGIN
    -- 현재 상태 확인
    SELECT status INTO v_current_status
    FROM public.cash_transactions
    WHERE id = p_transaction_id;
    
    IF v_current_status IS NULL THEN
        RAISE EXCEPTION 'Transaction not found';
    END IF;
    
    -- 상태 업데이트
    UPDATE public.cash_transactions
    SET 
        status = p_status,
        approved_by = CASE WHEN p_status = 'approved' THEN COALESCE(p_updated_by_user_id, auth.uid()) ELSE approved_by END,
        rejected_by = CASE WHEN p_status = 'rejected' THEN COALESCE(p_updated_by_user_id, auth.uid()) ELSE rejected_by END,
        rejection_reason = CASE WHEN p_status = 'rejected' THEN p_rejection_reason ELSE rejection_reason END,
        updated_at = NOW()
    WHERE id = p_transaction_id;
    
    RETURN TRUE;
END;
$$;


ALTER FUNCTION "public"."update_cash_transaction_status"("p_transaction_id" "uuid", "p_status" "text", "p_rejection_reason" "text", "p_updated_by_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_company_wallet_account"("p_wallet_id" "uuid", "p_company_id" "uuid", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_old_bank_name TEXT;
    v_old_account_number TEXT;
    v_old_account_holder TEXT;
    v_user_id UUID;
BEGIN
    -- 사용자 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION '로그인이 필요합니다';
    END IF;
    
    -- 권한 확인: owner만 가능
    IF NOT EXISTS (
        SELECT 1 FROM public.company_users
        WHERE company_id = p_company_id
        AND user_id = v_user_id
        AND company_role = 'owner'
        AND status = 'active'
    ) THEN
        RAISE EXCEPTION '회사 소유자만 계좌정보를 수정할 수 있습니다';
    END IF;
    
    -- 트랜잭션 시작
    BEGIN
        -- 이전 계좌정보 조회 (행 잠금으로 동시성 제어)
        SELECT withdraw_bank_name, withdraw_account_number, withdraw_account_holder
        INTO v_old_bank_name, v_old_account_number, v_old_account_holder
        FROM public.wallets
        WHERE id = p_wallet_id
        AND company_id = p_company_id
        FOR UPDATE;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION '회사 지갑을 찾을 수 없습니다';
        END IF;
        
        -- wallets 테이블 업데이트
        UPDATE public.wallets
        SET 
            withdraw_bank_name = p_bank_name,
            withdraw_account_number = p_account_number,
            withdraw_account_holder = p_account_holder,
            updated_at = NOW()
        WHERE id = p_wallet_id
        AND company_id = p_company_id;
        
        -- 변경이 있었으면 wallet_histories에 기록
        IF (v_old_bank_name IS DISTINCT FROM p_bank_name) OR
           (v_old_account_number IS DISTINCT FROM p_account_number) OR
           (v_old_account_holder IS DISTINCT FROM p_account_holder) THEN
            
            -- wallet_histories 테이블이 없어도 에러 처리
            BEGIN
                INSERT INTO public.wallet_histories (
                    wallet_id,
                    old_bank_name,
                    old_account_number,
                    old_account_holder,
                    new_bank_name,
                    new_account_number,
                    new_account_holder,
                    changed_by,
                    created_at
                ) VALUES (
                    p_wallet_id,
                    v_old_bank_name,
                    v_old_account_number,
                    v_old_account_holder,
                    p_bank_name,
                    p_account_number,
                    p_account_holder,
                    v_user_id,
                    NOW()
                );
            EXCEPTION WHEN OTHERS THEN
                -- wallet_histories 테이블이 없어도 계좌정보 업데이트는 성공
                RAISE WARNING 'Failed to insert wallet_histories: %', SQLERRM;
            END;
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        -- 에러 발생 시 자동으로 롤백됨
        RAISE;
    END;
END;
$$;


ALTER FUNCTION "public"."update_company_wallet_account"("p_wallet_id" "uuid", "p_company_id" "uuid", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."update_company_wallet_account"("p_wallet_id" "uuid", "p_company_id" "uuid", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text") IS '회사 지갑 계좌정보 업데이트 및 이력 기록을 트랜잭션으로 처리합니다. owner만 수정 가능하며, wallet_histories 테이블이 없어도 계좌정보 업데이트는 성공합니다.';



CREATE OR REPLACE FUNCTION "public"."update_sns_connection"("p_id" "uuid", "p_user_id" "uuid", "p_platform_account_name" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_return_address" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_store_platforms text[] := ARRAY['coupang', 'smartstore', '11st', 'gmarket', 'auction', 'wemakeprice'];
    v_platform text;
    v_result jsonb;
BEGIN
    SELECT "platform" INTO v_platform
    FROM "public"."sns_connections"
    WHERE "id" = "p_id" AND "user_id" = "p_user_id";
    
    IF v_platform IS NULL THEN
        RAISE EXCEPTION 'SNS 연결을 찾을 수 없습니다';
    END IF;
    
    -- 스토어 플랫폼 주소 필수 검증
    IF v_platform = ANY(v_store_platforms) AND 
       ("p_address" IS NULL OR "p_address" = '') AND
       NOT EXISTS (
           SELECT 1 FROM "public"."sns_connections"
           WHERE "id" = "p_id" AND "address" IS NOT NULL AND "address" != ''
       ) THEN
        RAISE EXCEPTION '스토어 플랫폼은 주소가 필수입니다';
    END IF;
    
    UPDATE "public"."sns_connections"
    SET
        "platform_account_name" = COALESCE("p_platform_account_name", "platform_account_name"),
        "phone" = COALESCE("p_phone", "phone"),
        "address" = CASE 
            WHEN v_platform = ANY(v_store_platforms) THEN COALESCE("p_address", "address")
            ELSE NULL
        END,
        "return_address" = COALESCE("p_return_address", "return_address"),
        "updated_at" = now()
    WHERE "id" = "p_id" AND "user_id" = "p_user_id"
    RETURNING jsonb_build_object(
        'id', "id",
        'platform', "platform",
        'platform_account_id', "platform_account_id",
        'platform_account_name', "platform_account_name",
        'phone', "phone",
        'address', "address",
        'return_address', "return_address",
        'updated_at', "updated_at"
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RAISE EXCEPTION 'SNS 연결을 찾을 수 없습니다';
    END IF;
    
    RETURN jsonb_build_object('success', true, 'data', v_result);
END;
$$;


ALTER FUNCTION "public"."update_sns_connection"("p_id" "uuid", "p_user_id" "uuid", "p_platform_account_name" "text", "p_phone" "text", "p_address" "text", "p_return_address" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_sns_connections_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW."updated_at" = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_sns_connections_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_sns_platform_connections_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW."updated_at" = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_sns_platform_connections_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_user_company_association"("p_user_id" "uuid", "p_company_id" "uuid", "p_role" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_current_user_type text;
  v_result jsonb;
BEGIN
  -- 권한 확인: 관리자만 변경 가능
  SELECT user_type INTO v_current_user_type
  FROM public.users 
  WHERE id = (select auth.uid());
  
  IF v_current_user_type != 'admin' THEN
    RAISE EXCEPTION 'Only admins can change company association';
  END IF;
  
  -- company_users 업데이트 또는 삽입
  INSERT INTO public.company_users (company_id, user_id, company_role, created_at)
  VALUES (p_company_id, p_user_id, p_role, NOW())
  ON CONFLICT (company_id, user_id) 
  DO UPDATE SET company_role = p_role;
  
  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'user_id', p_user_id,
    'company_id', p_company_id,
    'role', p_role
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."update_user_company_association"("p_user_id" "uuid", "p_company_id" "uuid", "p_role" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_profile jsonb;
BEGIN
  -- 자신의 프로필만 업데이트 가능
  IF p_user_id != (SELECT auth.uid()) THEN
    RAISE EXCEPTION 'You can only update your own profile';
  END IF;
  
  -- 프로필 업데이트 (display_name만)
  UPDATE public.users 
  SET 
    display_name = COALESCE(p_display_name, display_name),
    updated_at = NOW()
  WHERE id = p_user_id
  RETURNING to_jsonb(users.*) INTO v_profile;
  
  IF v_profile IS NULL THEN
    RAISE EXCEPTION 'User profile not found';
  END IF;
  
  RETURN v_profile;
END;
$$;


ALTER FUNCTION "public"."update_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_user_wallet_account"("p_wallet_id" "uuid", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_old_bank_name TEXT;
    v_old_account_number TEXT;
    v_old_account_holder TEXT;
    v_user_id UUID;
BEGIN
    -- 사용자 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION '로그인이 필요합니다';
    END IF;
    
    -- 트랜잭션 시작 (PostgreSQL 함수는 자동으로 트랜잭션 블록)
    BEGIN
        -- 이전 계좌정보 조회 (행 잠금으로 동시성 제어)
        SELECT withdraw_bank_name, withdraw_account_number, withdraw_account_holder
        INTO v_old_bank_name, v_old_account_number, v_old_account_holder
        FROM public.wallets
        WHERE id = p_wallet_id
        AND user_id = v_user_id
        FOR UPDATE;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION '지갑을 찾을 수 없습니다';
        END IF;
        
        -- wallets 테이블 업데이트
        UPDATE public.wallets
        SET 
            withdraw_bank_name = p_bank_name,
            withdraw_account_number = p_account_number,
            withdraw_account_holder = p_account_holder,
            updated_at = NOW()
        WHERE id = p_wallet_id
        AND user_id = v_user_id;
        
        -- 변경이 있었으면 wallet_histories에 기록
        IF (v_old_bank_name IS DISTINCT FROM p_bank_name) OR
           (v_old_account_number IS DISTINCT FROM p_account_number) OR
           (v_old_account_holder IS DISTINCT FROM p_account_holder) THEN
            
            -- wallet_histories 테이블이 없어도 에러 처리
            BEGIN
                INSERT INTO public.wallet_histories (
                    wallet_id,
                    old_bank_name,
                    old_account_number,
                    old_account_holder,
                    new_bank_name,
                    new_account_number,
                    new_account_holder,
                    changed_by,
                    created_at
                ) VALUES (
                    p_wallet_id,
                    v_old_bank_name,
                    v_old_account_number,
                    v_old_account_holder,
                    p_bank_name,
                    p_account_number,
                    p_account_holder,
                    v_user_id,
                    NOW()
                );
            EXCEPTION WHEN OTHERS THEN
                -- wallet_histories 테이블이 없어도 계좌정보 업데이트는 성공
                RAISE WARNING 'Failed to insert wallet_histories: %', SQLERRM;
            END;
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        -- 에러 발생 시 자동으로 롤백됨
        RAISE;
    END;
END;
$$;


ALTER FUNCTION "public"."update_user_wallet_account"("p_wallet_id" "uuid", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."update_user_wallet_account"("p_wallet_id" "uuid", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text") IS '개인 지갑 계좌정보 업데이트 및 이력 기록을 트랜잭션으로 처리합니다. wallet_histories 테이블이 없어도 계좌정보 업데이트는 성공합니다.';



CREATE OR REPLACE FUNCTION "public"."update_wallet_balance_on_cash_transaction"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    -- 입금(deposit)과 출금(withdraw) 모두 approved 상태일 때만 잔액 변경
    IF NEW.transaction_type = 'deposit' THEN
        -- 입금: approved 상태로 변경될 때 잔액 증가
        IF NEW.status = 'approved' 
           AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
            UPDATE public.wallets
            SET current_points = current_points + NEW.point_amount,
                updated_at = NOW()
            WHERE id = NEW.wallet_id;
        -- 입금: approved에서 다른 상태로 변경될 때 잔액 차감 (롤백)
        ELSIF OLD.status = 'approved' AND NEW.status != 'approved' THEN
            UPDATE public.wallets
            SET current_points = current_points - OLD.point_amount,
                updated_at = NOW()
            WHERE id = NEW.wallet_id;
        END IF;
    ELSIF NEW.transaction_type = 'withdraw' THEN
        -- 출금: approved 상태로 변경될 때 잔액 차감
        IF NEW.status = 'approved' 
           AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
            UPDATE public.wallets
            SET current_points = current_points - NEW.point_amount,
                updated_at = NOW()
            WHERE id = NEW.wallet_id;
        -- 출금: approved에서 다른 상태로 변경될 때 잔액 증가 (롤백)
        ELSIF OLD.status = 'approved' AND NEW.status != 'approved' THEN
            UPDATE public.wallets
            SET current_points = current_points + OLD.point_amount,
                updated_at = NOW()
            WHERE id = NEW.wallet_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_wallet_balance_on_cash_transaction"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_wallet_balance_on_transaction"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    UPDATE public.wallets
    SET current_points = current_points + NEW.amount,
        updated_at = NOW()
    WHERE id = NEW.wallet_id;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_wallet_balance_on_transaction"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_wallets_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_wallets_updated_at"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."campaign_action_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "campaign_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "action" "jsonb" NOT NULL,
    "application_message" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "campaign_action_logs_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text", 'completed'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."campaign_action_logs" OWNER TO "postgres";


COMMENT ON TABLE "public"."campaign_action_logs" IS '캠페인 액션 로그 테이블';



COMMENT ON COLUMN "public"."campaign_action_logs"."action" IS '행동 정보 (JSONB). 예: {"type": "join", "data": {...}}';



CREATE TABLE IF NOT EXISTS "public"."campaign_actions" (
    "campaign_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "current_action" "jsonb" NOT NULL,
    "last_updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."campaign_actions" OWNER TO "postgres";


COMMENT ON TABLE "public"."campaign_actions" IS '사용자의 캠페인별 현재 상태 요약 테이블 (빠른 조회용)';



COMMENT ON COLUMN "public"."campaign_actions"."campaign_id" IS '캠페인 ID';



COMMENT ON COLUMN "public"."campaign_actions"."user_id" IS '사용자 ID';



COMMENT ON COLUMN "public"."campaign_actions"."current_action" IS '현재 행동 상태 (JSONB). 예: {"type": "join", "data": {...}}';



COMMENT ON COLUMN "public"."campaign_actions"."last_updated_at" IS '마지막 업데이트 시간';



CREATE TABLE IF NOT EXISTS "public"."campaigns" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "company_id" "uuid" NOT NULL,
    "product_name" "text",
    "product_price" integer,
    "platform" "text",
    "max_participants" integer DEFAULT 100 NOT NULL,
    "current_participants" integer DEFAULT 0 NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "start_date" timestamp with time zone NOT NULL,
    "end_date" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "product_image_url" "text",
    "user_id" "uuid",
    "campaign_type" "text" DEFAULT 'reviewer'::"text",
    "completed_applicants_count" integer DEFAULT 0 NOT NULL,
    "keyword" "text",
    "option" "text",
    "quantity" integer DEFAULT 1,
    "seller" "text",
    "product_number" "text",
    "purchase_method" "text" DEFAULT 'mobile'::"text",
    "review_type" "text" DEFAULT 'star_only'::"text",
    "review_text_length" integer DEFAULT 100,
    "review_image_count" integer DEFAULT 0,
    "prevent_product_duplicate" boolean DEFAULT false,
    "prevent_store_duplicate" boolean DEFAULT false,
    "duplicate_prevent_days" integer DEFAULT 0,
    "payment_method" "text" DEFAULT 'platform'::"text",
    "total_cost" integer DEFAULT 0 NOT NULL,
    "expiration_date" timestamp with time zone NOT NULL,
    "campaign_reward" integer DEFAULT 0 NOT NULL,
    CONSTRAINT "campaigns_campaign_type_check" CHECK (("campaign_type" = ANY (ARRAY['reviewer'::"text", 'journalist'::"text", 'visit'::"text"]))),
    CONSTRAINT "campaigns_dates_check" CHECK ((("start_date" <= "end_date") AND ("end_date" <= "expiration_date"))),
    CONSTRAINT "campaigns_payment_method_check" CHECK (("payment_method" = ANY (ARRAY['platform'::"text", 'direct'::"text"]))),
    CONSTRAINT "campaigns_purchase_method_check" CHECK (("purchase_method" = ANY (ARRAY['mobile'::"text", 'pc'::"text"]))),
    CONSTRAINT "campaigns_review_type_check" CHECK (("review_type" = ANY (ARRAY['star_only'::"text", 'star_text'::"text", 'star_text_image'::"text"]))),
    CONSTRAINT "campaigns_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text"])))
);


ALTER TABLE "public"."campaigns" OWNER TO "postgres";


COMMENT ON COLUMN "public"."campaigns"."completed_applicants_count" IS '캠페인 완료자 수 (성능 최적화를 위한 캐시 컬럼)';



COMMENT ON COLUMN "public"."campaigns"."keyword" IS '검색 키워드';



COMMENT ON COLUMN "public"."campaigns"."option" IS '제품 옵션 (색상, 사이즈 등)';



COMMENT ON COLUMN "public"."campaigns"."quantity" IS '구매 개수';



COMMENT ON COLUMN "public"."campaigns"."seller" IS '판매자명';



COMMENT ON COLUMN "public"."campaigns"."product_number" IS '상품번호';



COMMENT ON COLUMN "public"."campaigns"."purchase_method" IS '구매방법 (mobile/pc)';



COMMENT ON COLUMN "public"."campaigns"."review_text_length" IS '텍스트 리뷰 길이';



COMMENT ON COLUMN "public"."campaigns"."prevent_product_duplicate" IS '상품 중복 금지 여부';



COMMENT ON COLUMN "public"."campaigns"."prevent_store_duplicate" IS '스토어 중복 금지 여부';



COMMENT ON COLUMN "public"."campaigns"."duplicate_prevent_days" IS '중복 금지 기간 (일)';



COMMENT ON COLUMN "public"."campaigns"."payment_method" IS '지급 방법 (platform/direct)';



COMMENT ON COLUMN "public"."campaigns"."total_cost" IS '총 비용';



COMMENT ON COLUMN "public"."campaigns"."expiration_date" IS '캠페인 만료일 (종료일 이후 리뷰 등록 기간)';



COMMENT ON COLUMN "public"."campaigns"."campaign_reward" IS '캠페인 리워드 (review_cost와 review_reward 통합)';



COMMENT ON CONSTRAINT "campaigns_dates_check" ON "public"."campaigns" IS '캠페인 날짜 순서 검증: 시작일 <= 종료일 <= 만료일';



CREATE TABLE IF NOT EXISTS "public"."cash_transaction_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "transaction_id" "uuid" NOT NULL,
    "status" "text" NOT NULL,
    "changed_by" "uuid",
    "change_reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "cash_transaction_logs_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."cash_transaction_logs" OWNER TO "postgres";


COMMENT ON TABLE "public"."cash_transaction_logs" IS '현금 입출금 거래 진행 이력 로그 (상태 변경 이력)';



COMMENT ON COLUMN "public"."cash_transaction_logs"."status" IS '거래 상태: pending(대기), approved(승인), rejected(거절), cancelled(취소)';



CREATE TABLE IF NOT EXISTS "public"."cash_transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "wallet_id" "uuid" NOT NULL,
    "transaction_type" "text" NOT NULL,
    "cash_amount" integer,
    "payment_method" "text",
    "bank_name" "text",
    "account_number" "text",
    "account_holder" "text",
    "status" "text" DEFAULT 'pending'::"text",
    "approved_by" "uuid",
    "rejected_by" "uuid",
    "rejection_reason" "text",
    "description" "text",
    "created_by_user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "point_amount" integer NOT NULL,
    CONSTRAINT "cash_transactions_point_amount_check" CHECK (("point_amount" <> 0)),
    CONSTRAINT "cash_transactions_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text", 'cancelled'::"text"]))),
    CONSTRAINT "cash_transactions_transaction_type_check" CHECK (("transaction_type" = ANY (ARRAY['deposit'::"text", 'withdraw'::"text"]))),
    CONSTRAINT "cash_transactions_withdraw_account_check" CHECK (((("transaction_type" = 'withdraw'::"text") AND ("bank_name" IS NOT NULL) AND ("account_number" IS NOT NULL) AND ("account_holder" IS NOT NULL)) OR ("transaction_type" <> 'withdraw'::"text")))
);


ALTER TABLE "public"."cash_transactions" OWNER TO "postgres";


COMMENT ON TABLE "public"."cash_transactions" IS '현금 입출금 거래 테이블 (deposit, withdraw)';



COMMENT ON COLUMN "public"."cash_transactions"."wallet_id" IS '지갑 ID (wallets 테이블 참조, user_id/company_id는 wallets를 통해 조회)';



COMMENT ON COLUMN "public"."cash_transactions"."status" IS '거래 상태: pending(대기) → approved(승인)';



CREATE TABLE IF NOT EXISTS "public"."companies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "business_name" "text" NOT NULL,
    "business_number" "text",
    "contact_email" "text",
    "contact_phone" "text",
    "address" "text",
    "representative_name" "text",
    "business_type" "text",
    "registration_file_url" "text",
    "user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."companies" OWNER TO "postgres";


COMMENT ON COLUMN "public"."companies"."business_name" IS '상호명 (사업자등록증의 상호명)';



COMMENT ON COLUMN "public"."companies"."user_id" IS '회사를 등록한 사용자 ID (외래키: users.id)';



CREATE TABLE IF NOT EXISTS "public"."company_users" (
    "company_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "company_role" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    CONSTRAINT "company_users_company_role_check" CHECK (("company_role" = ANY (ARRAY['owner'::"text", 'manager'::"text", 'reviewer'::"text"]))),
    CONSTRAINT "company_users_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'pending'::"text", 'suspended'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."company_users" OWNER TO "postgres";


COMMENT ON TABLE "public"."company_users" IS '회사-사용자 관계 테이블 (복합 기본 키: company_id + user_id). 한 사용자는 한 회사에 대해 하나의 역할만 가질 수 있습니다.';



COMMENT ON COLUMN "public"."company_users"."status" IS '회사-사용자 관계 상태: active(활성), inactive(비활성), pending(대기), suspended(정지), rejected(거절)';



COMMENT ON CONSTRAINT "company_users_company_role_check" ON "public"."company_users" IS 'company_role은 owner(회사 소유자), manager(회사 관리자), reviewer(리뷰어) 중 하나여야 합니다. owner와 manager는 광고주, reviewer는 리뷰어입니다.';



CREATE TABLE IF NOT EXISTS "public"."deleted_users" (
    "user_id" "uuid" NOT NULL,
    "deletion_reason" "text",
    "deleted_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."deleted_users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "message" "text" NOT NULL,
    "type" "text" NOT NULL,
    "is_read" boolean DEFAULT false NOT NULL,
    "related_entity_type" "text",
    "related_entity_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "notifications_type_check" CHECK (("type" = ANY (ARRAY['campaign'::"text", 'review'::"text", 'point'::"text", 'system'::"text"])))
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."point_transaction_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "transaction_id" "uuid" NOT NULL,
    "action" "text" NOT NULL,
    "changed_by" "uuid",
    "change_reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "point_transaction_logs_action_check" CHECK (("action" = ANY (ARRAY['created'::"text", 'updated'::"text", 'cancelled'::"text", 'refunded'::"text"])))
);


ALTER TABLE "public"."point_transaction_logs" OWNER TO "postgres";


COMMENT ON TABLE "public"."point_transaction_logs" IS '캠페인 포인트 거래 진행 이력 로그 (적산 방식)';



CREATE TABLE IF NOT EXISTS "public"."point_transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "wallet_id" "uuid" NOT NULL,
    "transaction_type" "text" NOT NULL,
    "amount" integer NOT NULL,
    "campaign_id" "uuid",
    "related_entity_type" "text",
    "related_entity_id" "uuid",
    "description" "text",
    "created_by_user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "completed_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "point_transactions_amount_check" CHECK (("amount" <> 0)),
    CONSTRAINT "point_transactions_campaign_check" CHECK ((("transaction_type" <> 'spend'::"text") OR (("transaction_type" = 'spend'::"text") AND ("campaign_id" IS NOT NULL)))),
    CONSTRAINT "point_transactions_transaction_type_check" CHECK (("transaction_type" = ANY (ARRAY['earn'::"text", 'spend'::"text", 'refund'::"text"])))
);


ALTER TABLE "public"."point_transactions" OWNER TO "postgres";


COMMENT ON TABLE "public"."point_transactions" IS '캠페인 관련 포인트 거래 테이블 (earn, spend)';



COMMENT ON COLUMN "public"."point_transactions"."wallet_id" IS '지갑 ID (wallets 테이블 참조, user_id/company_id는 wallets를 통해 조회)';



COMMENT ON COLUMN "public"."point_transactions"."transaction_type" IS '거래 타입: earn(적립), spend(사용), refund(환불)';



COMMENT ON COLUMN "public"."point_transactions"."campaign_id" IS '캠페인 ID (company spend는 필수, user earn은 선택)';



CREATE TABLE IF NOT EXISTS "public"."point_transfers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "from_wallet_id" "uuid" NOT NULL,
    "to_wallet_id" "uuid" NOT NULL,
    "amount" integer NOT NULL,
    "description" "text",
    "created_by_user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "point_transfers_amount_check" CHECK (("amount" > 0)),
    CONSTRAINT "point_transfers_wallets_check" CHECK (("from_wallet_id" <> "to_wallet_id"))
);


ALTER TABLE "public"."point_transfers" OWNER TO "postgres";


COMMENT ON TABLE "public"."point_transfers" IS '포인트 지갑 간 이동 전용 테이블 (회사 소유자만 가능, 개인 ↔ 회사)';



COMMENT ON COLUMN "public"."point_transfers"."from_wallet_id" IS '출발 지갑 ID';



COMMENT ON COLUMN "public"."point_transfers"."to_wallet_id" IS '도착 지갑 ID';



COMMENT ON COLUMN "public"."point_transfers"."amount" IS '이동 금액 (양수)';



CREATE TABLE IF NOT EXISTS "public"."sns_connections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "platform" "text" NOT NULL,
    "platform_account_id" "text" NOT NULL,
    "platform_account_name" "text" NOT NULL,
    "phone" "text" NOT NULL,
    "address" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "return_address" "text"
);


ALTER TABLE "public"."sns_connections" OWNER TO "postgres";


COMMENT ON TABLE "public"."sns_connections" IS 'SNS 플랫폼 연결 정보 (다계정 허용)';



COMMENT ON COLUMN "public"."sns_connections"."platform" IS '플랫폼 이름 (coupang, smartstore, blog, instagram 등)';



COMMENT ON COLUMN "public"."sns_connections"."platform_account_id" IS '플랫폼 내 계정 ID';



COMMENT ON COLUMN "public"."sns_connections"."platform_account_name" IS '플랫폼 내 표시 이름';



COMMENT ON COLUMN "public"."sns_connections"."address" IS '주소 (스토어 플랫폼만 필수, SNS 플랫폼은 NULL)';



COMMENT ON COLUMN "public"."sns_connections"."return_address" IS '회수 주소 (선택 사항)';



CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "display_name" "text",
    "user_type" "text" DEFAULT 'user'::"text",
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    CONSTRAINT "users_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'pending_deletion'::"text", 'deleted'::"text", 'suspended'::"text"])))
);


ALTER TABLE "public"."users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wallet_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "wallet_id" "uuid" NOT NULL,
    "old_bank_name" "text",
    "old_account_number" "text",
    "old_account_holder" "text",
    "new_bank_name" "text",
    "new_account_number" "text",
    "new_account_holder" "text",
    "changed_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."wallet_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wallets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "company_id" "uuid",
    "user_id" "uuid",
    "current_points" integer DEFAULT 0 NOT NULL,
    "withdraw_bank_name" "text",
    "withdraw_account_number" "text",
    "withdraw_account_holder" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "wallets_current_points_check" CHECK (("current_points" >= 0)),
    CONSTRAINT "wallets_owner_check" CHECK (((("company_id" IS NOT NULL) AND ("user_id" IS NULL)) OR (("company_id" IS NULL) AND ("user_id" IS NOT NULL))))
);


ALTER TABLE "public"."wallets" OWNER TO "postgres";


COMMENT ON TABLE "public"."wallets" IS '통합 지갑 테이블 (회사 및 유저 지갑)';



COMMENT ON COLUMN "public"."wallets"."company_id" IS '회사 지갑인 경우 회사 ID (FK)';



COMMENT ON COLUMN "public"."wallets"."user_id" IS '유저 지갑인 경우 유저 ID (FK)';



COMMENT ON CONSTRAINT "wallets_owner_check" ON "public"."wallets" IS 'company_id 또는 user_id 중 하나는 반드시 있어야 함';



ALTER TABLE ONLY "public"."campaign_action_logs"
    ADD CONSTRAINT "campaign_action_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."campaign_actions"
    ADD CONSTRAINT "campaign_actions_pkey" PRIMARY KEY ("campaign_id", "user_id");



ALTER TABLE ONLY "public"."campaigns"
    ADD CONSTRAINT "campaigns_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cash_transaction_logs"
    ADD CONSTRAINT "cash_transaction_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cash_transactions"
    ADD CONSTRAINT "cash_transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."companies"
    ADD CONSTRAINT "companies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."company_users"
    ADD CONSTRAINT "company_users_pkey" PRIMARY KEY ("company_id", "user_id");



ALTER TABLE ONLY "public"."deleted_users"
    ADD CONSTRAINT "deleted_users_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."point_transaction_logs"
    ADD CONSTRAINT "point_transaction_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."point_transactions"
    ADD CONSTRAINT "point_transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."point_transfers"
    ADD CONSTRAINT "point_transfers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sns_connections"
    ADD CONSTRAINT "sns_connections_unique_user_platform_account" UNIQUE ("user_id", "platform", "platform_account_id");



ALTER TABLE ONLY "public"."sns_connections"
    ADD CONSTRAINT "sns_platform_connections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."wallet_logs"
    ADD CONSTRAINT "wallet_histories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."wallets"
    ADD CONSTRAINT "wallets_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_campaign_action_logs_action" ON "public"."campaign_action_logs" USING "btree" ("action");



CREATE INDEX "idx_campaign_action_logs_campaign_id" ON "public"."campaign_action_logs" USING "btree" ("campaign_id");



CREATE INDEX "idx_campaign_action_logs_campaign_user" ON "public"."campaign_action_logs" USING "btree" ("campaign_id", "user_id");



CREATE INDEX "idx_campaign_action_logs_created_at" ON "public"."campaign_action_logs" USING "btree" ("created_at");



CREATE INDEX "idx_campaign_action_logs_status" ON "public"."campaign_action_logs" USING "btree" ("status");



CREATE INDEX "idx_campaign_action_logs_user_id" ON "public"."campaign_action_logs" USING "btree" ("user_id");



CREATE INDEX "idx_campaign_action_logs_user_status" ON "public"."campaign_action_logs" USING "btree" ("user_id", "status");



CREATE INDEX "idx_campaign_actions_campaign_id" ON "public"."campaign_actions" USING "btree" ("campaign_id");



CREATE INDEX "idx_campaign_actions_current_action" ON "public"."campaign_actions" USING "btree" ("current_action");



CREATE INDEX "idx_campaign_actions_last_updated_at" ON "public"."campaign_actions" USING "btree" ("last_updated_at");



CREATE INDEX "idx_campaign_actions_user_id" ON "public"."campaign_actions" USING "btree" ("user_id");



CREATE INDEX "idx_campaigns_campaign_reward" ON "public"."campaigns" USING "btree" ("campaign_reward");



CREATE INDEX "idx_campaigns_campaign_type" ON "public"."campaigns" USING "btree" ("campaign_type");



CREATE INDEX "idx_campaigns_company_id" ON "public"."campaigns" USING "btree" ("company_id");



CREATE INDEX "idx_campaigns_created_at" ON "public"."campaigns" USING "btree" ("created_at");



CREATE INDEX "idx_campaigns_current_participants" ON "public"."campaigns" USING "btree" ("current_participants");



CREATE INDEX "idx_campaigns_duplicate_prevent" ON "public"."campaigns" USING "btree" ("prevent_product_duplicate", "prevent_store_duplicate") WHERE (("prevent_product_duplicate" = true) OR ("prevent_store_duplicate" = true));



CREATE INDEX "idx_campaigns_end_date" ON "public"."campaigns" USING "btree" ("end_date");



CREATE INDEX "idx_campaigns_keyword" ON "public"."campaigns" USING "btree" ("keyword");



CREATE INDEX "idx_campaigns_max_participants" ON "public"."campaigns" USING "btree" ("max_participants");



CREATE INDEX "idx_campaigns_payment_method" ON "public"."campaigns" USING "btree" ("payment_method");



CREATE INDEX "idx_campaigns_platform" ON "public"."campaigns" USING "btree" ("platform");



CREATE INDEX "idx_campaigns_product_number" ON "public"."campaigns" USING "btree" ("product_number");



CREATE INDEX "idx_campaigns_seller" ON "public"."campaigns" USING "btree" ("seller");



CREATE INDEX "idx_campaigns_start_date" ON "public"."campaigns" USING "btree" ("start_date");



CREATE INDEX "idx_campaigns_status" ON "public"."campaigns" USING "btree" ("status");



CREATE INDEX "idx_campaigns_status_type" ON "public"."campaigns" USING "btree" ("status", "campaign_type");



CREATE INDEX "idx_campaigns_title" ON "public"."campaigns" USING "gin" ("to_tsvector"('"english"'::"regconfig", "title"));



CREATE INDEX "idx_campaigns_user_id" ON "public"."campaigns" USING "btree" ("user_id");



CREATE INDEX "idx_cash_transaction_logs_changed_by" ON "public"."cash_transaction_logs" USING "btree" ("changed_by");



CREATE INDEX "idx_cash_transaction_logs_created_at" ON "public"."cash_transaction_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_cash_transaction_logs_status" ON "public"."cash_transaction_logs" USING "btree" ("status");



CREATE INDEX "idx_cash_transaction_logs_transaction_id" ON "public"."cash_transaction_logs" USING "btree" ("transaction_id");



CREATE INDEX "idx_cash_transactions_created_at" ON "public"."cash_transactions" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_cash_transactions_pending" ON "public"."cash_transactions" USING "btree" ("status") WHERE ("status" = 'pending'::"text");



CREATE INDEX "idx_cash_transactions_status" ON "public"."cash_transactions" USING "btree" ("status");



CREATE INDEX "idx_cash_transactions_type" ON "public"."cash_transactions" USING "btree" ("transaction_type");



CREATE INDEX "idx_cash_transactions_wallet_id" ON "public"."cash_transactions" USING "btree" ("wallet_id");



CREATE INDEX "idx_companies_business_name" ON "public"."companies" USING "gin" ("to_tsvector"('"english"'::"regconfig", "business_name"));



CREATE INDEX "idx_companies_created_at" ON "public"."companies" USING "btree" ("created_at");



CREATE INDEX "idx_companies_user_id" ON "public"."companies" USING "btree" ("user_id");



CREATE INDEX "idx_deleted_users_deleted_at" ON "public"."deleted_users" USING "btree" ("deleted_at");



CREATE INDEX "idx_notifications_created_at" ON "public"."notifications" USING "btree" ("created_at");



CREATE INDEX "idx_notifications_is_read" ON "public"."notifications" USING "btree" ("is_read");



CREATE INDEX "idx_notifications_related_entity" ON "public"."notifications" USING "btree" ("related_entity_type", "related_entity_id");



CREATE INDEX "idx_notifications_type" ON "public"."notifications" USING "btree" ("type");



CREATE INDEX "idx_notifications_user_id" ON "public"."notifications" USING "btree" ("user_id");



CREATE INDEX "idx_notifications_user_read" ON "public"."notifications" USING "btree" ("user_id", "is_read");



CREATE INDEX "idx_notifications_user_type" ON "public"."notifications" USING "btree" ("user_id", "type");



CREATE INDEX "idx_point_transaction_logs_action" ON "public"."point_transaction_logs" USING "btree" ("action");



CREATE INDEX "idx_point_transaction_logs_changed_by" ON "public"."point_transaction_logs" USING "btree" ("changed_by");



CREATE INDEX "idx_point_transaction_logs_created_at" ON "public"."point_transaction_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_point_transaction_logs_transaction_id" ON "public"."point_transaction_logs" USING "btree" ("transaction_id");



CREATE INDEX "idx_point_transactions_campaign_id" ON "public"."point_transactions" USING "btree" ("campaign_id") WHERE ("campaign_id" IS NOT NULL);



CREATE INDEX "idx_point_transactions_created_at" ON "public"."point_transactions" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_point_transactions_related_entity" ON "public"."point_transactions" USING "btree" ("related_entity_type", "related_entity_id") WHERE ("related_entity_type" IS NOT NULL);



CREATE INDEX "idx_point_transactions_type" ON "public"."point_transactions" USING "btree" ("transaction_type");



CREATE INDEX "idx_point_transactions_wallet_id" ON "public"."point_transactions" USING "btree" ("wallet_id");



CREATE INDEX "idx_point_transfers_created_at" ON "public"."point_transfers" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_point_transfers_created_by" ON "public"."point_transfers" USING "btree" ("created_by_user_id") WHERE ("created_by_user_id" IS NOT NULL);



CREATE INDEX "idx_point_transfers_from_wallet_id" ON "public"."point_transfers" USING "btree" ("from_wallet_id");



CREATE INDEX "idx_point_transfers_to_wallet_id" ON "public"."point_transfers" USING "btree" ("to_wallet_id");



CREATE INDEX "idx_sns_connections_platform" ON "public"."sns_connections" USING "btree" ("platform");



CREATE INDEX "idx_sns_connections_user_id" ON "public"."sns_connections" USING "btree" ("user_id");



CREATE INDEX "idx_sns_connections_user_platform" ON "public"."sns_connections" USING "btree" ("user_id", "platform");



CREATE INDEX "idx_users_status_active" ON "public"."users" USING "btree" ("id") WHERE ("status" = 'active'::"text");



CREATE INDEX "idx_wallet_histories_changed_by" ON "public"."wallet_logs" USING "btree" ("changed_by");



CREATE INDEX "idx_wallet_histories_created_at" ON "public"."wallet_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_wallet_histories_wallet_id" ON "public"."wallet_logs" USING "btree" ("wallet_id");



CREATE INDEX "idx_wallets_company_id" ON "public"."wallets" USING "btree" ("company_id") WHERE ("company_id" IS NOT NULL);



CREATE INDEX "idx_wallets_created_at" ON "public"."wallets" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_wallets_user_id" ON "public"."wallets" USING "btree" ("user_id") WHERE ("user_id" IS NOT NULL);



CREATE OR REPLACE TRIGGER "cash_transactions_log_trigger" AFTER INSERT OR UPDATE ON "public"."cash_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."log_cash_transaction_change"();



CREATE OR REPLACE TRIGGER "cash_transactions_wallet_balance_trigger" AFTER INSERT OR UPDATE ON "public"."cash_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."update_wallet_balance_on_cash_transaction"();



COMMENT ON TRIGGER "cash_transactions_wallet_balance_trigger" ON "public"."cash_transactions" IS '입금(deposit)과 출금(withdraw) 거래 모두 approved 상태로 변경될 때 지갑 잔액을 업데이트합니다.
입금은 approved 상태일 때 잔액 증가, 출금은 approved 상태일 때 잔액 차감.
함수 내에서 OLD와 NEW 상태를 비교하여 필요한 경우에만 잔액을 업데이트합니다.';



CREATE OR REPLACE TRIGGER "create_company_wallet_trigger" AFTER INSERT ON "public"."companies" FOR EACH ROW EXECUTE FUNCTION "public"."create_company_wallet_on_registration"();



CREATE OR REPLACE TRIGGER "create_user_wallet_trigger" AFTER INSERT ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."create_user_wallet_on_signup"();



CREATE OR REPLACE TRIGGER "point_transactions_log_trigger" AFTER INSERT OR UPDATE ON "public"."point_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."log_point_transaction_change"();



CREATE OR REPLACE TRIGGER "point_transactions_wallet_balance_trigger" AFTER INSERT ON "public"."point_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."update_wallet_balance_on_transaction"();



CREATE OR REPLACE TRIGGER "set_sns_connections_updated_at" BEFORE UPDATE ON "public"."sns_connections" FOR EACH ROW EXECUTE FUNCTION "public"."update_sns_connections_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_sync_campaign_actions" AFTER INSERT ON "public"."campaign_action_logs" FOR EACH ROW EXECUTE FUNCTION "public"."sync_campaign_actions_on_event"();



CREATE OR REPLACE TRIGGER "update_campaign_logs_updated_at" BEFORE UPDATE ON "public"."campaign_action_logs" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_campaigns_updated_at" BEFORE UPDATE ON "public"."campaigns" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_companies_updated_at" BEFORE UPDATE ON "public"."companies" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_users_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_wallets_updated_at_trigger" BEFORE UPDATE ON "public"."wallets" FOR EACH ROW EXECUTE FUNCTION "public"."update_wallets_updated_at"();



ALTER TABLE ONLY "public"."campaign_action_logs"
    ADD CONSTRAINT "campaign_action_logs_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "public"."campaigns"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."campaign_action_logs"
    ADD CONSTRAINT "campaign_action_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."campaign_actions"
    ADD CONSTRAINT "campaign_actions_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "public"."campaigns"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."campaign_actions"
    ADD CONSTRAINT "campaign_actions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."campaigns"
    ADD CONSTRAINT "campaigns_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."campaigns"
    ADD CONSTRAINT "campaigns_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."cash_transaction_logs"
    ADD CONSTRAINT "cash_transaction_logs_changed_by_fkey" FOREIGN KEY ("changed_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."cash_transaction_logs"
    ADD CONSTRAINT "cash_transaction_logs_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "public"."cash_transactions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."cash_transactions"
    ADD CONSTRAINT "cash_transactions_approved_by_fkey" FOREIGN KEY ("approved_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."cash_transactions"
    ADD CONSTRAINT "cash_transactions_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."cash_transactions"
    ADD CONSTRAINT "cash_transactions_rejected_by_fkey" FOREIGN KEY ("rejected_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."cash_transactions"
    ADD CONSTRAINT "cash_transactions_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "public"."wallets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."companies"
    ADD CONSTRAINT "companies_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."company_users"
    ADD CONSTRAINT "company_users_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



COMMENT ON CONSTRAINT "company_users_company_id_fkey" ON "public"."company_users" IS '회사가 삭제되면 관련된 company_users 레코드도 자동으로 삭제됩니다 (CASCADE)';



ALTER TABLE ONLY "public"."company_users"
    ADD CONSTRAINT "company_users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."deleted_users"
    ADD CONSTRAINT "deleted_users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."point_transaction_logs"
    ADD CONSTRAINT "point_transaction_logs_changed_by_fkey" FOREIGN KEY ("changed_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."point_transaction_logs"
    ADD CONSTRAINT "point_transaction_logs_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "public"."point_transactions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."point_transactions"
    ADD CONSTRAINT "point_transactions_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "public"."campaigns"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."point_transactions"
    ADD CONSTRAINT "point_transactions_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."point_transactions"
    ADD CONSTRAINT "point_transactions_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "public"."wallets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."point_transfers"
    ADD CONSTRAINT "point_transfers_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."point_transfers"
    ADD CONSTRAINT "point_transfers_from_wallet_id_fkey" FOREIGN KEY ("from_wallet_id") REFERENCES "public"."wallets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."point_transfers"
    ADD CONSTRAINT "point_transfers_to_wallet_id_fkey" FOREIGN KEY ("to_wallet_id") REFERENCES "public"."wallets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sns_connections"
    ADD CONSTRAINT "sns_platform_connections_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."wallet_logs"
    ADD CONSTRAINT "wallet_histories_changed_by_fkey" FOREIGN KEY ("changed_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."wallet_logs"
    ADD CONSTRAINT "wallet_histories_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "public"."wallets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."wallets"
    ADD CONSTRAINT "wallets_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."wallets"
    ADD CONSTRAINT "wallets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Admins can update all wallets" ON "public"."wallets" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."user_type" = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."user_type" = 'admin'::"text")))));



CREATE POLICY "Admins can update cash transaction status" ON "public"."cash_transactions" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."user_type" = 'admin'::"text")))));



CREATE POLICY "Campaign events are insertable by authenticated users" ON "public"."campaign_action_logs" FOR INSERT WITH CHECK ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("campaign_id" IN ( SELECT "campaigns"."id"
   FROM "public"."campaigns"
  WHERE ("campaigns"."company_id" IN ( SELECT "company_users"."company_id"
           FROM "public"."company_users"
          WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))))));



CREATE POLICY "Campaign events are viewable by participants and company" ON "public"."campaign_action_logs" FOR SELECT USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("campaign_id" IN ( SELECT "campaigns"."id"
   FROM "public"."campaigns"
  WHERE ("campaigns"."company_id" IN ( SELECT "company_users"."company_id"
           FROM "public"."company_users"
          WHERE (("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("company_users"."status" = 'active'::"text"))))))));



CREATE POLICY "Campaign user status is viewable by participants and company" ON "public"."campaign_actions" FOR SELECT USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("campaign_id" IN ( SELECT "campaigns"."id"
   FROM "public"."campaigns"
  WHERE ("campaigns"."company_id" IN ( SELECT "company_users"."company_id"
           FROM "public"."company_users"
          WHERE (("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("company_users"."status" = 'active'::"text"))))))));



CREATE POLICY "Campaigns are insertable by company members" ON "public"."campaigns" FOR INSERT WITH CHECK (("company_id" IN ( SELECT "company_users"."company_id"
   FROM "public"."company_users"
  WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Campaigns are updatable by company members" ON "public"."campaigns" FOR UPDATE USING (("company_id" IN ( SELECT "company_users"."company_id"
   FROM "public"."company_users"
  WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Campaigns are viewable by everyone" ON "public"."campaigns" FOR SELECT USING (true);



CREATE POLICY "Companies are insertable by authenticated users" ON "public"."companies" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") IS NOT NULL));



CREATE POLICY "Companies are updatable by owners" ON "public"."companies" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."company_users"
  WHERE (("company_users"."company_id" = "companies"."id") AND ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("company_users"."company_role" = 'owner'::"text") AND ("company_users"."status" = 'active'::"text")))));



CREATE POLICY "Companies are viewable by everyone" ON "public"."companies" FOR SELECT USING (true);



CREATE POLICY "Company members can create company cash transactions" ON "public"."cash_transactions" FOR INSERT WITH CHECK (("wallet_id" IN ( SELECT "w"."id"
   FROM "public"."wallets" "w"
  WHERE ("w"."company_id" IN ( SELECT "company_users"."company_id"
           FROM "public"."company_users"
          WHERE (("company_users"."user_id" = "auth"."uid"()) AND ("company_users"."status" = 'active'::"text")))))));



CREATE POLICY "Company members can view company cash transactions" ON "public"."cash_transactions" FOR SELECT USING (("wallet_id" IN ( SELECT "w"."id"
   FROM "public"."wallets" "w"
  WHERE ("w"."company_id" IN ( SELECT "company_users"."company_id"
           FROM "public"."company_users"
          WHERE (("company_users"."user_id" = "auth"."uid"()) AND ("company_users"."status" = 'active'::"text")))))));



CREATE POLICY "Company members can view company transactions" ON "public"."point_transactions" FOR SELECT USING (("wallet_id" IN ( SELECT "w"."id"
   FROM "public"."wallets" "w"
  WHERE ("w"."company_id" IN ( SELECT "company_users"."company_id"
           FROM "public"."company_users"
          WHERE (("company_users"."user_id" = "auth"."uid"()) AND ("company_users"."status" = 'active'::"text")))))));



CREATE POLICY "Company members can view company wallet" ON "public"."wallets" FOR SELECT USING ((("company_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."company_users" "cu"
  WHERE (("cu"."company_id" = "wallets"."company_id") AND ("cu"."user_id" = "auth"."uid"()) AND ("cu"."status" = 'active'::"text"))))));



CREATE POLICY "Company members can view logs of company cash transactions" ON "public"."cash_transaction_logs" FOR SELECT USING (("transaction_id" IN ( SELECT "pt"."id"
   FROM ("public"."cash_transactions" "pt"
     JOIN "public"."wallets" "w" ON (("w"."id" = "pt"."wallet_id")))
  WHERE ("w"."company_id" IN ( SELECT "company_users"."company_id"
           FROM "public"."company_users"
          WHERE (("company_users"."user_id" = "auth"."uid"()) AND ("company_users"."status" = 'active'::"text")))))));



CREATE POLICY "Company members can view logs of company transactions" ON "public"."point_transaction_logs" FOR SELECT USING (("transaction_id" IN ( SELECT "pt"."id"
   FROM ("public"."point_transactions" "pt"
     JOIN "public"."wallets" "w" ON (("w"."id" = "pt"."wallet_id")))
  WHERE ("w"."company_id" IN ( SELECT "company_users"."company_id"
           FROM "public"."company_users"
          WHERE (("company_users"."user_id" = "auth"."uid"()) AND ("company_users"."status" = 'active'::"text")))))));



CREATE POLICY "Company owners can update company wallet account" ON "public"."wallets" FOR UPDATE USING ((("company_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."company_users" "cu"
  WHERE (("cu"."company_id" = "wallets"."company_id") AND ("cu"."user_id" = "auth"."uid"()) AND ("cu"."company_role" = 'owner'::"text") AND ("cu"."status" = 'active'::"text")))))) WITH CHECK ((("company_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."company_users" "cu"
  WHERE (("cu"."company_id" = "wallets"."company_id") AND ("cu"."user_id" = "auth"."uid"()) AND ("cu"."company_role" = 'owner'::"text") AND ("cu"."status" = 'active'::"text"))))));



CREATE POLICY "Company users are insertable by company owners" ON "public"."company_users" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."company_users" "cu"
  WHERE (("cu"."company_id" = "company_users"."company_id") AND ("cu"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("cu"."company_role" = 'owner'::"text") AND ("cu"."status" = 'active'::"text")))));



CREATE POLICY "Company users are insertable for new company owners" ON "public"."company_users" FOR INSERT WITH CHECK (((EXISTS ( SELECT 1
   FROM "public"."companies"
  WHERE (("companies"."id" = "company_users"."company_id") AND ("companies"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))) OR (EXISTS ( SELECT 1
   FROM ("public"."company_users" "cu"
     JOIN "public"."companies" ON (("companies"."id" = "cu"."company_id")))
  WHERE (("cu"."company_id" = "company_users"."company_id") AND ("cu"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("cu"."company_role" = 'owner'::"text"))))));



CREATE POLICY "Company users are updatable by company owners" ON "public"."company_users" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."company_users" "cu"
  WHERE (("cu"."company_id" = "company_users"."company_id") AND ("cu"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("cu"."company_role" = ANY (ARRAY['owner'::"text", 'manager'::"text"])) AND ("cu"."status" = 'active'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."company_users" "cu"
  WHERE (("cu"."company_id" = "company_users"."company_id") AND ("cu"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("cu"."company_role" = ANY (ARRAY['owner'::"text", 'manager'::"text"])) AND ("cu"."status" = 'active'::"text")))));



CREATE POLICY "Company users are viewable by everyone" ON "public"."company_users" FOR SELECT USING (true);



CREATE POLICY "Notifications are insertable by system" ON "public"."notifications" FOR INSERT WITH CHECK (true);



CREATE POLICY "Notifications are updatable by owner" ON "public"."notifications" FOR UPDATE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Notifications are viewable by owner" ON "public"."notifications" FOR SELECT USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "System can insert transactions" ON "public"."point_transactions" FOR INSERT WITH CHECK (true);



CREATE POLICY "System can insert wallets" ON "public"."wallets" FOR INSERT WITH CHECK (true);



CREATE POLICY "Users are viewable by everyone" ON "public"."users" FOR SELECT USING (true);



CREATE POLICY "Users can create their own SNS connections" ON "public"."sns_connections" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can create their own cash transactions" ON "public"."cash_transactions" FOR INSERT WITH CHECK (("wallet_id" IN ( SELECT "wallets"."id"
   FROM "public"."wallets"
  WHERE ("wallets"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can delete their own SNS connections" ON "public"."sns_connections" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own profile" ON "public"."users" FOR INSERT WITH CHECK ((("id" = ( SELECT "auth"."uid"() AS "uid")) OR (( SELECT "auth"."uid"() AS "uid") IS NOT NULL)));



CREATE POLICY "Users can insert their own wallet histories" ON "public"."wallet_logs" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."wallets" "w"
  WHERE (("w"."id" = "wallet_logs"."wallet_id") AND (("w"."user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
           FROM "public"."company_users" "cu"
          WHERE (("cu"."company_id" = "w"."company_id") AND ("cu"."user_id" = "auth"."uid"()) AND ("cu"."status" = 'active'::"text") AND ("cu"."company_role" = 'owner'::"text")))))))));



CREATE POLICY "Users can update own profile" ON "public"."users" FOR UPDATE USING (("id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Users can update their own SNS connections" ON "public"."sns_connections" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own wallet account" ON "public"."wallets" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can view logs of their cash transactions" ON "public"."cash_transaction_logs" FOR SELECT USING (("transaction_id" IN ( SELECT "pt"."id"
   FROM ("public"."cash_transactions" "pt"
     JOIN "public"."wallets" "w" ON (("w"."id" = "pt"."wallet_id")))
  WHERE ("w"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can view logs of their transactions" ON "public"."point_transaction_logs" FOR SELECT USING (("transaction_id" IN ( SELECT "pt"."id"
   FROM ("public"."point_transactions" "pt"
     JOIN "public"."wallets" "w" ON (("w"."id" = "pt"."wallet_id")))
  WHERE ("w"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can view their own SNS connections" ON "public"."sns_connections" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own cash transactions" ON "public"."cash_transactions" FOR SELECT USING (("wallet_id" IN ( SELECT "wallets"."id"
   FROM "public"."wallets"
  WHERE ("wallets"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can view their own transactions" ON "public"."point_transactions" FOR SELECT USING (("wallet_id" IN ( SELECT "wallets"."id"
   FROM "public"."wallets"
  WHERE ("wallets"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can view their own wallet" ON "public"."wallets" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can view their own wallet histories" ON "public"."wallet_logs" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."wallets" "w"
  WHERE (("w"."id" = "wallet_logs"."wallet_id") AND (("w"."user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
           FROM "public"."company_users" "cu"
          WHERE (("cu"."company_id" = "w"."company_id") AND ("cu"."user_id" = "auth"."uid"()) AND ("cu"."status" = 'active'::"text")))))))));



CREATE POLICY "Users can view transfers involving their wallets" ON "public"."point_transfers" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."wallets" "w"
  WHERE ((("w"."id" = "point_transfers"."from_wallet_id") OR ("w"."id" = "point_transfers"."to_wallet_id")) AND (("w"."user_id" = "auth"."uid"()) OR (("w"."company_id" IS NOT NULL) AND (EXISTS ( SELECT 1
           FROM "public"."company_users" "cu"
          WHERE (("cu"."company_id" = "w"."company_id") AND ("cu"."user_id" = "auth"."uid"()) AND ("cu"."status" = 'active'::"text"))))))))));



ALTER TABLE "public"."campaign_action_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."campaign_actions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."campaigns" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cash_transaction_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cash_transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."companies" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."company_users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."deleted_users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."point_transaction_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."point_transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."point_transfers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sns_connections" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."wallet_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."wallets" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";





GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";































































































































































GRANT ALL ON FUNCTION "public"."admin_change_user_role"("p_target_user_id" "uuid", "p_new_role" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_change_user_role"("p_target_user_id" "uuid", "p_new_role" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_change_user_role"("p_target_user_id" "uuid", "p_new_role" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."approve_manager"("p_company_id" "uuid", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."approve_manager"("p_company_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."approve_manager"("p_company_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_campaign_cost"("p_payment_method" "text", "p_payment_amount" integer, "p_campaign_reward" integer, "p_max_participants" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_campaign_cost"("p_payment_method" "text", "p_payment_amount" integer, "p_campaign_reward" integer, "p_max_participants" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_campaign_cost"("p_payment_method" "text", "p_payment_amount" integer, "p_campaign_reward" integer, "p_max_participants" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."cancel_cash_transaction"("p_transaction_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."cancel_cash_transaction"("p_transaction_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_cash_transaction"("p_transaction_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_user_exists"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."check_user_exists"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_user_exists"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_campaign_with_points"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_product_price" integer, "p_campaign_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_product_image_url" "text", "p_platform" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_campaign_with_points"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_product_price" integer, "p_campaign_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_product_image_url" "text", "p_platform" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_campaign_with_points"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_product_price" integer, "p_campaign_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_product_image_url" "text", "p_platform" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_campaign_with_points_v2"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_campaign_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_platform" "text", "p_keyword" "text", "p_option" "text", "p_quantity" integer, "p_seller" "text", "p_product_number" "text", "p_product_image_url" "text", "p_product_name" "text", "p_product_price" integer, "p_purchase_method" "text", "p_product_description" "text", "p_review_type" "text", "p_review_text_length" integer, "p_review_image_count" integer, "p_prevent_product_duplicate" boolean, "p_prevent_store_duplicate" boolean, "p_duplicate_prevent_days" integer, "p_payment_method" "text", "p_expiration_date" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."create_campaign_with_points_v2"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_campaign_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_platform" "text", "p_keyword" "text", "p_option" "text", "p_quantity" integer, "p_seller" "text", "p_product_number" "text", "p_product_image_url" "text", "p_product_name" "text", "p_product_price" integer, "p_purchase_method" "text", "p_product_description" "text", "p_review_type" "text", "p_review_text_length" integer, "p_review_image_count" integer, "p_prevent_product_duplicate" boolean, "p_prevent_store_duplicate" boolean, "p_duplicate_prevent_days" integer, "p_payment_method" "text", "p_expiration_date" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_campaign_with_points_v2"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_campaign_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_platform" "text", "p_keyword" "text", "p_option" "text", "p_quantity" integer, "p_seller" "text", "p_product_number" "text", "p_product_image_url" "text", "p_product_name" "text", "p_product_price" integer, "p_purchase_method" "text", "p_product_description" "text", "p_review_type" "text", "p_review_text_length" integer, "p_review_image_count" integer, "p_prevent_product_duplicate" boolean, "p_prevent_store_duplicate" boolean, "p_duplicate_prevent_days" integer, "p_payment_method" "text", "p_expiration_date" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_cash_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_point_amount" integer, "p_cash_amount" numeric, "p_payment_method" "text", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text", "p_description" "text", "p_created_by_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_cash_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_point_amount" integer, "p_cash_amount" numeric, "p_payment_method" "text", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text", "p_description" "text", "p_created_by_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_cash_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_point_amount" integer, "p_cash_amount" numeric, "p_payment_method" "text", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text", "p_description" "text", "p_created_by_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_company_wallet_on_registration"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_company_wallet_on_registration"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_company_wallet_on_registration"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_point_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_amount" integer, "p_campaign_id" "uuid", "p_related_entity_type" "text", "p_related_entity_id" "uuid", "p_description" "text", "p_created_by_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_point_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_amount" integer, "p_campaign_id" "uuid", "p_related_entity_type" "text", "p_related_entity_id" "uuid", "p_description" "text", "p_created_by_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_point_transaction"("p_wallet_id" "uuid", "p_transaction_type" "text", "p_amount" integer, "p_campaign_id" "uuid", "p_related_entity_type" "text", "p_related_entity_id" "uuid", "p_description" "text", "p_created_by_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_sns_connection"("p_user_id" "uuid", "p_platform" "text", "p_platform_account_id" "text", "p_platform_account_name" "text", "p_phone" "text", "p_address" "text", "p_return_address" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_sns_connection"("p_user_id" "uuid", "p_platform" "text", "p_platform_account_id" "text", "p_platform_account_name" "text", "p_phone" "text", "p_address" "text", "p_return_address" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_sns_connection"("p_user_id" "uuid", "p_platform" "text", "p_platform_account_id" "text", "p_platform_account_name" "text", "p_phone" "text", "p_address" "text", "p_return_address" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_user_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_user_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_user_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_user_wallet_on_signup"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_user_wallet_on_signup"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_user_wallet_on_signup"() TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_campaign"("p_campaign_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_campaign"("p_campaign_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_campaign"("p_campaign_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_company"("p_company_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_company"("p_company_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_company"("p_company_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_sns_connection"("p_id" "uuid", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_sns_connection"("p_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_sns_connection"("p_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."earn_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."earn_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."earn_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."ensure_company_wallet"("p_company_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."ensure_company_wallet"("p_company_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_company_wallet"("p_company_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."ensure_user_wallet"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."ensure_user_wallet"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_user_wallet"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_company_managers"("p_company_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_company_managers"("p_company_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_company_managers"("p_company_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_company_point_history"("p_company_id" "uuid", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_company_point_history"("p_company_id" "uuid", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_company_point_history"("p_company_id" "uuid", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_company_point_history_unified"("p_company_id" "uuid", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_company_point_history_unified"("p_company_id" "uuid", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_company_point_history_unified"("p_company_id" "uuid", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_pending_cash_transactions"("p_status" "text", "p_transaction_type" "text", "p_user_type" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_pending_cash_transactions"("p_status" "text", "p_transaction_type" "text", "p_user_type" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_pending_cash_transactions"("p_status" "text", "p_transaction_type" "text", "p_user_type" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_campaigns_safe"("p_user_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_campaigns_safe"("p_user_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_campaigns_safe"("p_user_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_company_wallets"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_company_wallets"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_company_wallets"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_participated_campaigns_safe"("p_user_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_participated_campaigns_safe"("p_user_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_participated_campaigns_safe"("p_user_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_point_history"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_point_history"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_point_history"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_point_history_unified"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_point_history_unified"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_point_history_unified"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_point_logs_safe"("p_user_id" "uuid", "p_transaction_type" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_point_logs_safe"("p_user_id" "uuid", "p_transaction_type" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_point_logs_safe"("p_user_id" "uuid", "p_transaction_type" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_transfers"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_transfers"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_transfers"("p_user_id" "uuid", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_wallet"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_wallet"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_wallet"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_wallet_safe"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_wallet_safe"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_wallet_safe"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_wallets"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_wallets"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_wallets"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_wallet_by_company_id"("p_company_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_wallet_by_company_id"("p_company_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_wallet_by_company_id"("p_company_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_wallet_by_user_id"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_wallet_by_user_id"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_wallet_by_user_id"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_wallet_info"("p_wallet_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_wallet_info"("p_wallet_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_wallet_info"("p_wallet_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_wallet_logs"("p_wallet_id" "uuid", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_wallet_logs"("p_wallet_id" "uuid", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_wallet_logs"("p_wallet_id" "uuid", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."join_campaign_safe"("p_campaign_id" "uuid", "p_application_message" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."join_campaign_safe"("p_campaign_id" "uuid", "p_application_message" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."join_campaign_safe"("p_campaign_id" "uuid", "p_application_message" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."leave_campaign_safe"("p_campaign_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."leave_campaign_safe"("p_campaign_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."leave_campaign_safe"("p_campaign_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."log_cash_transaction_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."log_cash_transaction_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_cash_transaction_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."log_point_transaction_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."log_point_transaction_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_point_transaction_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."log_wallet_account_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."log_wallet_account_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_wallet_account_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."register_company"("p_user_id" "uuid", "p_business_name" "text", "p_business_number" "text", "p_address" "text", "p_representative_name" "text", "p_business_type" "text", "p_registration_file_url" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."register_company"("p_user_id" "uuid", "p_business_name" "text", "p_business_number" "text", "p_address" "text", "p_representative_name" "text", "p_business_type" "text", "p_registration_file_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_company"("p_user_id" "uuid", "p_business_name" "text", "p_business_number" "text", "p_address" "text", "p_representative_name" "text", "p_business_type" "text", "p_registration_file_url" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."reject_manager"("p_company_id" "uuid", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."reject_manager"("p_company_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reject_manager"("p_company_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."request_manager_role"("p_business_name" "text", "p_business_number" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."request_manager_role"("p_business_name" "text", "p_business_number" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."request_manager_role"("p_business_name" "text", "p_business_number" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."request_point_charge"("p_user_id" "uuid", "p_amount" integer, "p_cash_amount" double precision, "p_payment_method" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."request_point_charge"("p_user_id" "uuid", "p_amount" integer, "p_cash_amount" double precision, "p_payment_method" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."request_point_charge"("p_user_id" "uuid", "p_amount" integer, "p_cash_amount" double precision, "p_payment_method" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."request_point_charge_safe"("p_user_id" "uuid", "p_amount" integer, "p_payment_method" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."request_point_charge_safe"("p_user_id" "uuid", "p_amount" integer, "p_payment_method" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."request_point_charge_safe"("p_user_id" "uuid", "p_amount" integer, "p_payment_method" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."spend_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."spend_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."spend_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."spend_points_safe"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."spend_points_safe"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."spend_points_safe"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_campaign_actions_on_event"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_campaign_actions_on_event"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_campaign_actions_on_event"() TO "service_role";



GRANT ALL ON FUNCTION "public"."transfer_points_between_wallets"("p_from_wallet_id" "uuid", "p_to_wallet_id" "uuid", "p_amount" integer, "p_description" "text", "p_created_by_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."transfer_points_between_wallets"("p_from_wallet_id" "uuid", "p_to_wallet_id" "uuid", "p_amount" integer, "p_description" "text", "p_created_by_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."transfer_points_between_wallets"("p_from_wallet_id" "uuid", "p_to_wallet_id" "uuid", "p_amount" integer, "p_description" "text", "p_created_by_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_campaign_status"("p_campaign_id" "uuid", "p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_campaign_status"("p_campaign_id" "uuid", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_campaign_status"("p_campaign_id" "uuid", "p_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_cash_transaction_status"("p_transaction_id" "uuid", "p_status" "text", "p_rejection_reason" "text", "p_updated_by_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."update_cash_transaction_status"("p_transaction_id" "uuid", "p_status" "text", "p_rejection_reason" "text", "p_updated_by_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_cash_transaction_status"("p_transaction_id" "uuid", "p_status" "text", "p_rejection_reason" "text", "p_updated_by_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_company_wallet_account"("p_wallet_id" "uuid", "p_company_id" "uuid", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_company_wallet_account"("p_wallet_id" "uuid", "p_company_id" "uuid", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_company_wallet_account"("p_wallet_id" "uuid", "p_company_id" "uuid", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_sns_connection"("p_id" "uuid", "p_user_id" "uuid", "p_platform_account_name" "text", "p_phone" "text", "p_address" "text", "p_return_address" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_sns_connection"("p_id" "uuid", "p_user_id" "uuid", "p_platform_account_name" "text", "p_phone" "text", "p_address" "text", "p_return_address" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_sns_connection"("p_id" "uuid", "p_user_id" "uuid", "p_platform_account_name" "text", "p_phone" "text", "p_address" "text", "p_return_address" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_sns_connections_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_sns_connections_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_sns_connections_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_sns_platform_connections_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_sns_platform_connections_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_sns_platform_connections_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_company_association"("p_user_id" "uuid", "p_company_id" "uuid", "p_role" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_company_association"("p_user_id" "uuid", "p_company_id" "uuid", "p_role" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_company_association"("p_user_id" "uuid", "p_company_id" "uuid", "p_role" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_wallet_account"("p_wallet_id" "uuid", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_wallet_account"("p_wallet_id" "uuid", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_wallet_account"("p_wallet_id" "uuid", "p_bank_name" "text", "p_account_number" "text", "p_account_holder" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_wallet_balance_on_cash_transaction"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_wallet_balance_on_cash_transaction"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_wallet_balance_on_cash_transaction"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_wallet_balance_on_transaction"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_wallet_balance_on_transaction"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_wallet_balance_on_transaction"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_wallets_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_wallets_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_wallets_updated_at"() TO "service_role";


















GRANT ALL ON TABLE "public"."campaign_action_logs" TO "anon";
GRANT ALL ON TABLE "public"."campaign_action_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."campaign_action_logs" TO "service_role";



GRANT ALL ON TABLE "public"."campaign_actions" TO "anon";
GRANT ALL ON TABLE "public"."campaign_actions" TO "authenticated";
GRANT ALL ON TABLE "public"."campaign_actions" TO "service_role";



GRANT ALL ON TABLE "public"."campaigns" TO "anon";
GRANT ALL ON TABLE "public"."campaigns" TO "authenticated";
GRANT ALL ON TABLE "public"."campaigns" TO "service_role";



GRANT ALL ON TABLE "public"."cash_transaction_logs" TO "anon";
GRANT ALL ON TABLE "public"."cash_transaction_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."cash_transaction_logs" TO "service_role";



GRANT ALL ON TABLE "public"."cash_transactions" TO "anon";
GRANT ALL ON TABLE "public"."cash_transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."cash_transactions" TO "service_role";



GRANT ALL ON TABLE "public"."companies" TO "anon";
GRANT ALL ON TABLE "public"."companies" TO "authenticated";
GRANT ALL ON TABLE "public"."companies" TO "service_role";



GRANT ALL ON TABLE "public"."company_users" TO "anon";
GRANT ALL ON TABLE "public"."company_users" TO "authenticated";
GRANT ALL ON TABLE "public"."company_users" TO "service_role";



GRANT ALL ON TABLE "public"."deleted_users" TO "anon";
GRANT ALL ON TABLE "public"."deleted_users" TO "authenticated";
GRANT ALL ON TABLE "public"."deleted_users" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."point_transaction_logs" TO "anon";
GRANT ALL ON TABLE "public"."point_transaction_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."point_transaction_logs" TO "service_role";



GRANT ALL ON TABLE "public"."point_transactions" TO "anon";
GRANT ALL ON TABLE "public"."point_transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."point_transactions" TO "service_role";



GRANT ALL ON TABLE "public"."point_transfers" TO "anon";
GRANT ALL ON TABLE "public"."point_transfers" TO "authenticated";
GRANT ALL ON TABLE "public"."point_transfers" TO "service_role";



GRANT ALL ON TABLE "public"."sns_connections" TO "anon";
GRANT ALL ON TABLE "public"."sns_connections" TO "authenticated";
GRANT ALL ON TABLE "public"."sns_connections" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



GRANT ALL ON TABLE "public"."wallet_logs" TO "anon";
GRANT ALL ON TABLE "public"."wallet_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."wallet_logs" TO "service_role";



GRANT ALL ON TABLE "public"."wallets" TO "anon";
GRANT ALL ON TABLE "public"."wallets" TO "authenticated";
GRANT ALL ON TABLE "public"."wallets" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































RESET ALL;

--
-- Dumped schema changes for auth and storage
--

