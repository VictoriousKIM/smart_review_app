


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






COMMENT ON SCHEMA "public" IS 'standard public schema';



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


CREATE OR REPLACE FUNCTION "public"."create_campaign_with_points"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_product_price" integer, "p_review_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_product_image_url" "text" DEFAULT NULL::"text", "p_platform" "text" DEFAULT NULL::"text", "p_platform_logo_url" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_user_id uuid;
  v_company_id uuid;
  v_current_points integer;
  v_required_points integer;
  v_campaign_id uuid;
  v_result jsonb;
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
  
  -- 3. 회사 지갑 조회 (FOR UPDATE로 락)
  SELECT cw.current_points 
  INTO v_current_points
  FROM public.company_wallets cw
  WHERE cw.company_id = v_company_id
  FOR UPDATE;
  
  IF v_current_points IS NULL THEN
    RAISE EXCEPTION '회사 지갑이 없습니다';
  END IF;
  
  -- 4. 필요 포인트 계산
  v_required_points := p_review_reward * p_max_participants;
  
  -- 5. 잔액 확인
  IF v_current_points < v_required_points THEN
    RAISE EXCEPTION '포인트가 부족합니다 (필요: %, 보유: %)', 
      v_required_points, v_current_points;
  END IF;
  
  -- 6. 포인트 차감
  UPDATE public.company_wallets
  SET current_points = current_points - v_required_points,
      updated_at = NOW()
  WHERE company_id = v_company_id;
  
  -- 7. 캠페인 생성
  INSERT INTO public.campaigns (
    title, description, company_id, user_id,
    campaign_type, product_price, review_reward,
    max_participants, current_participants,
    start_date, end_date, status,
    product_image_url, platform, platform_logo_url,
    created_at, updated_at
  ) VALUES (
    p_title, p_description, v_company_id, v_user_id,
    p_campaign_type, p_product_price, p_review_reward,
    p_max_participants, 0,
    p_start_date, p_end_date, 'active',
    p_product_image_url, p_platform, p_platform_logo_url,
    NOW(), NOW()
  ) RETURNING id INTO v_campaign_id;
  
  -- 8. 포인트 로그 기록
  INSERT INTO public.company_point_logs (
    company_id, transaction_type, amount,
    description, related_entity_type, related_entity_id,
    created_by_user_id, created_at
  ) VALUES (
    v_company_id, 'spend', -v_required_points,
    '캠페인 생성: ' || p_title,
    'campaign', v_campaign_id,
    v_user_id,
    NOW()
  );
  
  -- 9. 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'campaign_id', v_campaign_id,
    'points_spent', v_required_points,
    'remaining_points', v_current_points - v_required_points
  ) INTO v_result;
  
  RETURN v_result;
  
EXCEPTION WHEN OTHERS THEN
  RAISE;
END;
$$;


ALTER FUNCTION "public"."create_campaign_with_points"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_product_price" integer, "p_review_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_product_image_url" "text", "p_platform" "text", "p_platform_logo_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_company_wallet_on_registration"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.company_wallets (company_id, current_points, created_at, updated_at)
  VALUES (NEW.id, 0, NOW(), NOW())
  ON CONFLICT (company_id) DO NOTHING;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."create_company_wallet_on_registration"() OWNER TO "postgres";


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
    AS $$
BEGIN
  INSERT INTO public.user_wallets (user_id, current_points, created_at, updated_at)
  VALUES (NEW.id, 0, NOW(), NOW())
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."create_user_wallet_on_signup"() OWNER TO "postgres";


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
    cpl.id as log_id,
    cpl.transaction_type,
    cpl.amount,
    cpl.description,
    cpl.related_entity_type,
    cpl.related_entity_id,
    cpl.created_by_user_id,
    COALESCE(u.display_name, '알 수 없음') as created_by_user_name,
    cpl.created_at
  FROM public.company_point_logs cpl
  LEFT JOIN public.users u ON u.id = cpl.created_by_user_id
  WHERE cpl.company_id = p_company_id
  ORDER BY cpl.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;


ALTER FUNCTION "public"."get_company_point_history"("p_company_id" "uuid", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_campaigns_safe"("p_user_id" "uuid", "p_status" "text" DEFAULT 'all'::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
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
    RAISE EXCEPTION 'You can only view your own campaigns';
  END IF;
  
  -- 캠페인 조회
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
  JOIN public.company_wallets cw ON cw.company_id = c.id
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
  
  -- 프로필 조회 및 company_role, company_id 추가
  SELECT jsonb_build_object(
    'id', u.id,
    'created_at', u.created_at,
    'updated_at', u.updated_at,
    'display_name', u.display_name,
    'user_type', u.user_type,
    'status', u.status,
    'company_id', v_company_id,
    'company_role', v_company_role
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



CREATE OR REPLACE FUNCTION "public"."sync_campaign_user_status_on_event"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  -- 1. campaign_user_status 테이블 업데이트 (또는 INSERT)
  INSERT INTO "public"."campaign_user_status" (
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
  -- 중복 카운트 방지: 이전 상태가 '완료'가 아닌 경우에만 증가
  IF (NEW."action" IN ('완료', 'complete') AND NEW."status" = 'completed') THEN
    -- campaign_user_status에서 해당 사용자의 이전 상태 확인
    -- 이전 상태가 '완료'가 아니었다면 카운트 증가 (중복 방지)
    -- 주의: campaign_user_status는 위에서 이미 업데이트되었으므로, 
    -- OLD 상태를 확인하기 위해 별도의 서브쿼리 필요
    UPDATE "public"."campaigns"
    SET "completed_applicants_count" = "completed_applicants_count" + 1
    WHERE "id" = NEW."campaign_id"
      AND NOT EXISTS (
        -- 이전에 '완료' 상태였던 이벤트가 있는지 확인
        SELECT 1
        FROM "public"."campaign_events" ce
        WHERE ce."campaign_id" = NEW."campaign_id"
          AND ce."user_id" = NEW."user_id"
          AND ce."action" IN ('완료', 'complete')
          AND ce."status" = 'completed'
          AND ce."created_at" < NEW."created_at"
      );
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_campaign_user_status_on_event"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_campaign_user_status_on_event"() IS 'campaign_events 테이블에 새 이벤트가 INSERT될 때 campaign_user_status와 campaigns.completed_applicants_count를 자동으로 동기화합니다.';



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

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."campaign_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "campaign_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "action" "text" NOT NULL,
    "application_message" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "campaign_events_action_check" CHECK (("action" = ANY (ARRAY['join'::"text", 'leave'::"text", 'complete'::"text", 'cancel'::"text", '시작'::"text", '진행상황_저장'::"text", '완료'::"text"]))),
    CONSTRAINT "campaign_events_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text", 'completed'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."campaign_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."campaign_user_status" (
    "campaign_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "current_action" "text" NOT NULL,
    "last_updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "campaign_user_status_action_check" CHECK (("current_action" = ANY (ARRAY['join'::"text", 'leave'::"text", 'complete'::"text", 'cancel'::"text", '시작'::"text", '진행상황_저장'::"text", '완료'::"text"])))
);


ALTER TABLE "public"."campaign_user_status" OWNER TO "postgres";


COMMENT ON TABLE "public"."campaign_user_status" IS '사용자의 캠페인별 현재 상태 요약 테이블 (빠른 조회용)';



COMMENT ON COLUMN "public"."campaign_user_status"."campaign_id" IS '캠페인 ID';



COMMENT ON COLUMN "public"."campaign_user_status"."user_id" IS '사용자 ID';



COMMENT ON COLUMN "public"."campaign_user_status"."current_action" IS '현재 행동 상태';



COMMENT ON COLUMN "public"."campaign_user_status"."last_updated_at" IS '마지막 업데이트 시간';



CREATE TABLE IF NOT EXISTS "public"."campaigns" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "company_id" "uuid" NOT NULL,
    "product_name" "text",
    "product_price" integer,
    "review_cost" integer NOT NULL,
    "platform" "text",
    "max_participants" integer DEFAULT 100 NOT NULL,
    "current_participants" integer DEFAULT 0 NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "start_date" timestamp with time zone,
    "end_date" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "product_image_url" "text",
    "user_id" "uuid",
    "campaign_type" "text" DEFAULT 'reviewer'::"text",
    "review_reward" integer,
    "last_used_at" timestamp with time zone,
    "usage_count" integer DEFAULT 0,
    "completed_applicants_count" integer DEFAULT 0 NOT NULL,
    CONSTRAINT "campaigns_campaign_type_check" CHECK (("campaign_type" = ANY (ARRAY['reviewer'::"text", 'journalist'::"text", 'visit'::"text"]))),
    CONSTRAINT "campaigns_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'completed'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."campaigns" OWNER TO "postgres";


COMMENT ON COLUMN "public"."campaigns"."completed_applicants_count" IS '캠페인 완료자 수 (성능 최적화를 위한 캐시 컬럼)';



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



CREATE TABLE IF NOT EXISTS "public"."company_point_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "company_id" "uuid" NOT NULL,
    "transaction_type" "text" NOT NULL,
    "amount" integer NOT NULL,
    "description" "text",
    "related_entity_type" "text",
    "related_entity_id" "uuid",
    "created_by_user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "company_point_logs_transaction_type_check" CHECK (("transaction_type" = ANY (ARRAY['charge'::"text", 'spend'::"text", 'refund'::"text", 'bonus'::"text", 'penalty'::"text", 'transfer'::"text"])))
);


ALTER TABLE "public"."company_point_logs" OWNER TO "postgres";


COMMENT ON TABLE "public"."company_point_logs" IS '회사 포인트 거래 내역';



COMMENT ON COLUMN "public"."company_point_logs"."created_by_user_id" IS '이 거래를 발생시킨 사용자 (owner 또는 manager)';



CREATE TABLE IF NOT EXISTS "public"."company_users" (
    "company_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "company_role" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    CONSTRAINT "company_users_company_role_check" CHECK (("company_role" = ANY (ARRAY['owner'::"text", 'manager'::"text"]))),
    CONSTRAINT "company_users_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'pending'::"text", 'suspended'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."company_users" OWNER TO "postgres";


COMMENT ON TABLE "public"."company_users" IS '회사-사용자 관계 테이블 (복합 기본 키: company_id + user_id). 한 사용자는 한 회사에 대해 하나의 역할만 가질 수 있습니다.';



COMMENT ON COLUMN "public"."company_users"."status" IS '회사-사용자 관계 상태: active(활성), inactive(비활성), pending(대기), suspended(정지), rejected(거절)';



CREATE TABLE IF NOT EXISTS "public"."company_wallets" (
    "company_id" "uuid" NOT NULL,
    "current_points" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "company_wallets_points_check" CHECK (("current_points" >= 0))
);


ALTER TABLE "public"."company_wallets" OWNER TO "postgres";


COMMENT ON TABLE "public"."company_wallets" IS '회사 포인트 지갑 (광고주용)';



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



CREATE TABLE IF NOT EXISTS "public"."user_point_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "transaction_type" "text" NOT NULL,
    "amount" integer NOT NULL,
    "description" "text",
    "related_entity_type" "text",
    "related_entity_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_point_logs_transaction_type_check" CHECK (("transaction_type" = ANY (ARRAY['earn'::"text", 'spend'::"text", 'refund'::"text", 'bonus'::"text", 'penalty'::"text", 'transfer'::"text"])))
);


ALTER TABLE "public"."user_point_logs" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_point_logs" IS '개인 포인트 거래 내역';



CREATE TABLE IF NOT EXISTS "public"."user_wallets" (
    "user_id" "uuid" NOT NULL,
    "current_points" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_wallets_points_check" CHECK (("current_points" >= 0))
);


ALTER TABLE "public"."user_wallets" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_wallets" IS '개인 사용자 포인트 지갑 (리뷰어용)';



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


ALTER TABLE ONLY "public"."campaign_events"
    ADD CONSTRAINT "campaign_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."campaign_user_status"
    ADD CONSTRAINT "campaign_user_status_pkey" PRIMARY KEY ("campaign_id", "user_id");



ALTER TABLE ONLY "public"."campaigns"
    ADD CONSTRAINT "campaigns_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."companies"
    ADD CONSTRAINT "companies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."company_point_logs"
    ADD CONSTRAINT "company_point_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."company_users"
    ADD CONSTRAINT "company_users_pkey" PRIMARY KEY ("company_id", "user_id");



ALTER TABLE ONLY "public"."company_wallets"
    ADD CONSTRAINT "company_wallets_pkey" PRIMARY KEY ("company_id");



ALTER TABLE ONLY "public"."deleted_users"
    ADD CONSTRAINT "deleted_users_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sns_connections"
    ADD CONSTRAINT "sns_connections_unique_user_platform_account" UNIQUE ("user_id", "platform", "platform_account_id");



ALTER TABLE ONLY "public"."sns_connections"
    ADD CONSTRAINT "sns_platform_connections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_point_logs"
    ADD CONSTRAINT "user_point_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_wallets"
    ADD CONSTRAINT "user_wallets_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_campaign_events_action" ON "public"."campaign_events" USING "btree" ("action");



CREATE INDEX "idx_campaign_events_campaign_id" ON "public"."campaign_events" USING "btree" ("campaign_id");



CREATE INDEX "idx_campaign_events_campaign_user" ON "public"."campaign_events" USING "btree" ("campaign_id", "user_id");



CREATE INDEX "idx_campaign_events_created_at" ON "public"."campaign_events" USING "btree" ("created_at");



CREATE INDEX "idx_campaign_events_status" ON "public"."campaign_events" USING "btree" ("status");



CREATE INDEX "idx_campaign_events_user_id" ON "public"."campaign_events" USING "btree" ("user_id");



CREATE INDEX "idx_campaign_user_status_campaign_id" ON "public"."campaign_user_status" USING "btree" ("campaign_id");



CREATE INDEX "idx_campaign_user_status_current_action" ON "public"."campaign_user_status" USING "btree" ("current_action");



CREATE INDEX "idx_campaign_user_status_last_updated_at" ON "public"."campaign_user_status" USING "btree" ("last_updated_at");



CREATE INDEX "idx_campaign_user_status_user_id" ON "public"."campaign_user_status" USING "btree" ("user_id");



CREATE INDEX "idx_campaigns_campaign_type" ON "public"."campaigns" USING "btree" ("campaign_type");



CREATE INDEX "idx_campaigns_company_id" ON "public"."campaigns" USING "btree" ("company_id");



CREATE INDEX "idx_campaigns_created_at" ON "public"."campaigns" USING "btree" ("created_at");



CREATE INDEX "idx_campaigns_current_participants" ON "public"."campaigns" USING "btree" ("current_participants");



CREATE INDEX "idx_campaigns_end_date" ON "public"."campaigns" USING "btree" ("end_date");



CREATE INDEX "idx_campaigns_last_used_at" ON "public"."campaigns" USING "btree" ("last_used_at");



CREATE INDEX "idx_campaigns_max_participants" ON "public"."campaigns" USING "btree" ("max_participants");



CREATE INDEX "idx_campaigns_platform" ON "public"."campaigns" USING "btree" ("platform");



CREATE INDEX "idx_campaigns_review_cost" ON "public"."campaigns" USING "btree" ("review_cost");



CREATE INDEX "idx_campaigns_start_date" ON "public"."campaigns" USING "btree" ("start_date");



CREATE INDEX "idx_campaigns_status" ON "public"."campaigns" USING "btree" ("status");



CREATE INDEX "idx_campaigns_status_type" ON "public"."campaigns" USING "btree" ("status", "campaign_type");



CREATE INDEX "idx_campaigns_title" ON "public"."campaigns" USING "gin" ("to_tsvector"('"english"'::"regconfig", "title"));



CREATE INDEX "idx_campaigns_usage_count" ON "public"."campaigns" USING "btree" ("usage_count");



CREATE INDEX "idx_campaigns_user_id" ON "public"."campaigns" USING "btree" ("user_id");



CREATE INDEX "idx_companies_business_name" ON "public"."companies" USING "gin" ("to_tsvector"('"english"'::"regconfig", "business_name"));



CREATE INDEX "idx_companies_created_at" ON "public"."companies" USING "btree" ("created_at");



CREATE INDEX "idx_companies_user_id" ON "public"."companies" USING "btree" ("user_id");



CREATE INDEX "idx_company_point_logs_company_id" ON "public"."company_point_logs" USING "btree" ("company_id");



CREATE INDEX "idx_company_point_logs_created_at" ON "public"."company_point_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_company_point_logs_created_by" ON "public"."company_point_logs" USING "btree" ("created_by_user_id");



CREATE INDEX "idx_company_point_logs_related_entity" ON "public"."company_point_logs" USING "btree" ("related_entity_type", "related_entity_id");



CREATE INDEX "idx_deleted_users_deleted_at" ON "public"."deleted_users" USING "btree" ("deleted_at");



CREATE INDEX "idx_notifications_created_at" ON "public"."notifications" USING "btree" ("created_at");



CREATE INDEX "idx_notifications_is_read" ON "public"."notifications" USING "btree" ("is_read");



CREATE INDEX "idx_notifications_related_entity" ON "public"."notifications" USING "btree" ("related_entity_type", "related_entity_id");



CREATE INDEX "idx_notifications_type" ON "public"."notifications" USING "btree" ("type");



CREATE INDEX "idx_notifications_user_id" ON "public"."notifications" USING "btree" ("user_id");



CREATE INDEX "idx_notifications_user_read" ON "public"."notifications" USING "btree" ("user_id", "is_read");



CREATE INDEX "idx_notifications_user_type" ON "public"."notifications" USING "btree" ("user_id", "type");



CREATE INDEX "idx_sns_connections_platform" ON "public"."sns_connections" USING "btree" ("platform");



CREATE INDEX "idx_sns_connections_user_id" ON "public"."sns_connections" USING "btree" ("user_id");



CREATE INDEX "idx_sns_connections_user_platform" ON "public"."sns_connections" USING "btree" ("user_id", "platform");



CREATE INDEX "idx_user_point_logs_created_at" ON "public"."user_point_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_user_point_logs_related_entity" ON "public"."user_point_logs" USING "btree" ("related_entity_type", "related_entity_id");



CREATE INDEX "idx_user_point_logs_user_id" ON "public"."user_point_logs" USING "btree" ("user_id");



CREATE INDEX "idx_users_status_active" ON "public"."users" USING "btree" ("id") WHERE ("status" = 'active'::"text");



CREATE OR REPLACE TRIGGER "create_company_wallet_trigger" AFTER INSERT ON "public"."companies" FOR EACH ROW EXECUTE FUNCTION "public"."create_company_wallet_on_registration"();



CREATE OR REPLACE TRIGGER "create_user_wallet_trigger" AFTER INSERT ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."create_user_wallet_on_signup"();



CREATE OR REPLACE TRIGGER "set_sns_connections_updated_at" BEFORE UPDATE ON "public"."sns_connections" FOR EACH ROW EXECUTE FUNCTION "public"."update_sns_connections_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_sync_campaign_user_status" AFTER INSERT ON "public"."campaign_events" FOR EACH ROW EXECUTE FUNCTION "public"."sync_campaign_user_status_on_event"();



CREATE OR REPLACE TRIGGER "update_campaign_logs_updated_at" BEFORE UPDATE ON "public"."campaign_events" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_campaigns_updated_at" BEFORE UPDATE ON "public"."campaigns" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_companies_updated_at" BEFORE UPDATE ON "public"."companies" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_company_wallets_updated_at" BEFORE UPDATE ON "public"."company_wallets" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_user_wallets_updated_at" BEFORE UPDATE ON "public"."user_wallets" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_users_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."campaign_events"
    ADD CONSTRAINT "campaign_events_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "public"."campaigns"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."campaign_events"
    ADD CONSTRAINT "campaign_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."campaign_user_status"
    ADD CONSTRAINT "campaign_user_status_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "public"."campaigns"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."campaign_user_status"
    ADD CONSTRAINT "campaign_user_status_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."campaigns"
    ADD CONSTRAINT "campaigns_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."campaigns"
    ADD CONSTRAINT "campaigns_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."companies"
    ADD CONSTRAINT "companies_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."company_point_logs"
    ADD CONSTRAINT "company_point_logs_company_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."company_wallets"("company_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."company_point_logs"
    ADD CONSTRAINT "company_point_logs_user_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."company_users"
    ADD CONSTRAINT "company_users_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."company_users"
    ADD CONSTRAINT "company_users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."company_wallets"
    ADD CONSTRAINT "company_wallets_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."deleted_users"
    ADD CONSTRAINT "deleted_users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sns_connections"
    ADD CONSTRAINT "sns_platform_connections_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_point_logs"
    ADD CONSTRAINT "user_point_logs_user_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_wallets"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_wallets"
    ADD CONSTRAINT "user_wallets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Campaign events are insertable by authenticated users" ON "public"."campaign_events" FOR INSERT WITH CHECK ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("campaign_id" IN ( SELECT "campaigns"."id"
   FROM "public"."campaigns"
  WHERE ("campaigns"."company_id" IN ( SELECT "company_users"."company_id"
           FROM "public"."company_users"
          WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))))));



CREATE POLICY "Campaign events are viewable by participants and company" ON "public"."campaign_events" FOR SELECT USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("campaign_id" IN ( SELECT "campaigns"."id"
   FROM "public"."campaigns"
  WHERE ("campaigns"."company_id" IN ( SELECT "company_users"."company_id"
           FROM "public"."company_users"
          WHERE (("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("company_users"."status" = 'active'::"text"))))))));



CREATE POLICY "Campaign user status is viewable by participants and company" ON "public"."campaign_user_status" FOR SELECT USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("campaign_id" IN ( SELECT "campaigns"."id"
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



CREATE POLICY "Company members can view company point logs" ON "public"."company_point_logs" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."company_users" "cu"
  WHERE (("cu"."company_id" = "company_point_logs"."company_id") AND ("cu"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("cu"."status" = 'active'::"text")))));



CREATE POLICY "Company members can view company wallet" ON "public"."company_wallets" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."company_users" "cu"
  WHERE (("cu"."company_id" = "company_wallets"."company_id") AND ("cu"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("cu"."status" = 'active'::"text")))));



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



CREATE POLICY "Only admins can update wallets" ON "public"."user_wallets" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."user_type" = 'admin'::"text")))));



CREATE POLICY "Only owners can update company wallet" ON "public"."company_wallets" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."company_users" "cu"
  WHERE (("cu"."company_id" = "company_wallets"."company_id") AND ("cu"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("cu"."company_role" = 'owner'::"text") AND ("cu"."status" = 'active'::"text")))));



CREATE POLICY "System can insert company point logs" ON "public"."company_point_logs" FOR INSERT WITH CHECK (true);



CREATE POLICY "System can insert company wallets" ON "public"."company_wallets" FOR INSERT WITH CHECK (true);



CREATE POLICY "System can insert user point logs" ON "public"."user_point_logs" FOR INSERT WITH CHECK (true);



CREATE POLICY "System can insert wallets" ON "public"."user_wallets" FOR INSERT WITH CHECK (true);



CREATE POLICY "Users are viewable by everyone" ON "public"."users" FOR SELECT USING (true);



CREATE POLICY "Users can create their own SNS connections" ON "public"."sns_connections" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete their own SNS connections" ON "public"."sns_connections" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own profile" ON "public"."users" FOR INSERT WITH CHECK ((("id" = ( SELECT "auth"."uid"() AS "uid")) OR (( SELECT "auth"."uid"() AS "uid") IS NOT NULL)));



CREATE POLICY "Users can update own profile" ON "public"."users" FOR UPDATE USING (("id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Users can update their own SNS connections" ON "public"."sns_connections" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own SNS connections" ON "public"."sns_connections" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own point logs" ON "public"."user_point_logs" FOR SELECT USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Users can view their own wallet" ON "public"."user_wallets" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."campaign_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."campaign_user_status" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."campaigns" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."companies" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."company_point_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."company_users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."company_wallets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."deleted_users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sns_connections" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_point_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_wallets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;




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



GRANT ALL ON FUNCTION "public"."check_user_exists"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."check_user_exists"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_user_exists"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_campaign_with_points"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_product_price" integer, "p_review_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_product_image_url" "text", "p_platform" "text", "p_platform_logo_url" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_campaign_with_points"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_product_price" integer, "p_review_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_product_image_url" "text", "p_platform" "text", "p_platform_logo_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_campaign_with_points"("p_title" "text", "p_description" "text", "p_campaign_type" "text", "p_product_price" integer, "p_review_reward" integer, "p_max_participants" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_product_image_url" "text", "p_platform" "text", "p_platform_logo_url" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_company_wallet_on_registration"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_company_wallet_on_registration"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_company_wallet_on_registration"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_sns_connection"("p_user_id" "uuid", "p_platform" "text", "p_platform_account_id" "text", "p_platform_account_name" "text", "p_phone" "text", "p_address" "text", "p_return_address" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_sns_connection"("p_user_id" "uuid", "p_platform" "text", "p_platform_account_id" "text", "p_platform_account_name" "text", "p_phone" "text", "p_address" "text", "p_return_address" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_sns_connection"("p_user_id" "uuid", "p_platform" "text", "p_platform_account_id" "text", "p_platform_account_name" "text", "p_phone" "text", "p_address" "text", "p_return_address" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_user_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_user_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_user_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_user_wallet_on_signup"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_user_wallet_on_signup"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_user_wallet_on_signup"() TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_company"("p_company_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_company"("p_company_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_company"("p_company_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_sns_connection"("p_id" "uuid", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_sns_connection"("p_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_sns_connection"("p_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."earn_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."earn_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."earn_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_company_managers"("p_company_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_company_managers"("p_company_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_company_managers"("p_company_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_company_point_history"("p_company_id" "uuid", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_company_point_history"("p_company_id" "uuid", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_company_point_history"("p_company_id" "uuid", "p_limit" integer, "p_offset" integer) TO "service_role";



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



GRANT ALL ON FUNCTION "public"."get_user_point_logs_safe"("p_user_id" "uuid", "p_transaction_type" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_point_logs_safe"("p_user_id" "uuid", "p_transaction_type" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_point_logs_safe"("p_user_id" "uuid", "p_transaction_type" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_wallet"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_wallet"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_wallet"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_wallet_safe"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_wallet_safe"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_wallet_safe"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_wallets"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_wallets"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_wallets"("p_user_id" "uuid") TO "service_role";



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



GRANT ALL ON FUNCTION "public"."sync_campaign_user_status_on_event"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_campaign_user_status_on_event"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_campaign_user_status_on_event"() TO "service_role";



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


















GRANT ALL ON TABLE "public"."campaign_events" TO "anon";
GRANT ALL ON TABLE "public"."campaign_events" TO "authenticated";
GRANT ALL ON TABLE "public"."campaign_events" TO "service_role";



GRANT ALL ON TABLE "public"."campaign_user_status" TO "anon";
GRANT ALL ON TABLE "public"."campaign_user_status" TO "authenticated";
GRANT ALL ON TABLE "public"."campaign_user_status" TO "service_role";



GRANT ALL ON TABLE "public"."campaigns" TO "anon";
GRANT ALL ON TABLE "public"."campaigns" TO "authenticated";
GRANT ALL ON TABLE "public"."campaigns" TO "service_role";



GRANT ALL ON TABLE "public"."companies" TO "anon";
GRANT ALL ON TABLE "public"."companies" TO "authenticated";
GRANT ALL ON TABLE "public"."companies" TO "service_role";



GRANT ALL ON TABLE "public"."company_point_logs" TO "anon";
GRANT ALL ON TABLE "public"."company_point_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."company_point_logs" TO "service_role";



GRANT ALL ON TABLE "public"."company_users" TO "anon";
GRANT ALL ON TABLE "public"."company_users" TO "authenticated";
GRANT ALL ON TABLE "public"."company_users" TO "service_role";



GRANT ALL ON TABLE "public"."company_wallets" TO "anon";
GRANT ALL ON TABLE "public"."company_wallets" TO "authenticated";
GRANT ALL ON TABLE "public"."company_wallets" TO "service_role";



GRANT ALL ON TABLE "public"."deleted_users" TO "anon";
GRANT ALL ON TABLE "public"."deleted_users" TO "authenticated";
GRANT ALL ON TABLE "public"."deleted_users" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."sns_connections" TO "anon";
GRANT ALL ON TABLE "public"."sns_connections" TO "authenticated";
GRANT ALL ON TABLE "public"."sns_connections" TO "service_role";



GRANT ALL ON TABLE "public"."user_point_logs" TO "anon";
GRANT ALL ON TABLE "public"."user_point_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."user_point_logs" TO "service_role";



GRANT ALL ON TABLE "public"."user_wallets" TO "anon";
GRANT ALL ON TABLE "public"."user_wallets" TO "authenticated";
GRANT ALL ON TABLE "public"."user_wallets" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";









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
