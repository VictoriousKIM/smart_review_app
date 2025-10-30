


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
    -- 호출자가 관리자인지 확인
    SELECT user_type INTO v_current_user_type
    FROM public.users 
    WHERE id = (select auth.uid());
    
    IF v_current_user_type NOT IN ('ADMIN', 'OWNER') THEN
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
END;
$$;


ALTER FUNCTION "public"."admin_change_user_role"("p_target_user_id" "uuid", "p_new_role" "text") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."create_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_user_type" "text" DEFAULT 'REVIEWER'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$ 
DECLARE 
    v_profile jsonb; 
    v_current_user_type text; 
BEGIN 
    -- 현재 사용자 타입 조회 (관리자 권한 확인용)
    SELECT user_type INTO v_current_user_type 
    FROM public.users 
    WHERE id = (select auth.uid()); 
    
    -- 권한 검증: 관리자만 특별한 타입(ADMIN, OWNER) 설정 가능
    -- USER와 REVIEWER는 일반 사용자도 생성 가능
    IF p_user_type NOT IN ('REVIEWER', 'USER') AND 
       (v_current_user_type IS NULL OR v_current_user_type NOT IN ('ADMIN', 'OWNER')) THEN 
        RAISE EXCEPTION 'Only admins can create special user types (ADMIN, OWNER)'; 
    END IF; 
    
    -- 사용자 프로필 생성 (권한은 서버에서 제어)
    INSERT INTO public.users ( 
        id, display_name, user_type, created_at, updated_at 
    ) VALUES ( 
        p_user_id, p_display_name, p_user_type, NOW(), NOW() 
    ) RETURNING to_jsonb(users.*) INTO v_profile; 
    
    -- 포인트 지갑 생성
    INSERT INTO public.point_wallets ( 
        owner_type, owner_id, current_points, created_at, updated_at 
    ) VALUES ( 
        'USER', p_user_id, 0, NOW(), NOW() 
    ); 
    
    RETURN v_profile; 
END; 
$$;


ALTER FUNCTION "public"."create_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_user_type" "text") OWNER TO "postgres";


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
        WHERE id = (select auth.uid()) AND user_type IN ('ADMIN', 'OWNER')
    ) THEN
        RAISE EXCEPTION 'Only admins can award points';
    END IF;
    
    -- 사용자 지갑 찾기
    SELECT id, current_points INTO v_wallet_id, v_current_points
    FROM public.point_wallets
    WHERE owner_type = 'USER' AND owner_id = p_user_id
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
    
    -- 결과 반환
    SELECT jsonb_build_object(
        'success', true,
        'log_id', v_log_id,
        'amount_earned', p_amount,
        'new_balance', v_new_balance,
        'description', p_description
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."earn_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") OWNER TO "postgres";


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
           WHERE id = (select auth.uid()) AND user_type IN ('ADMIN', 'OWNER')
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


CREATE OR REPLACE FUNCTION "public"."get_user_participated_campaigns_safe"("p_user_id" "uuid", "p_status" "text" DEFAULT 'approved'::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
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
           WHERE id = (select auth.uid()) AND user_type IN ('ADMIN', 'OWNER')
       ) THEN
        RAISE EXCEPTION 'You can only view your own participated campaigns';
    END IF;
    
    -- 참여 캠페인 조회
    SELECT jsonb_agg(
        jsonb_build_object(
            'campaign', campaigns.*,
            'log', campaign_logs.*
        )
    ) INTO v_campaigns
    FROM public.campaigns
    JOIN public.campaign_logs ON campaigns.id = campaign_logs.campaign_id
    WHERE campaign_logs.user_id = p_user_id
    AND campaign_logs.status = p_status
    ORDER BY campaign_logs.created_at DESC
    LIMIT p_limit OFFSET p_offset;
    
    -- 총 개수 조회
    SELECT COUNT(*) INTO v_total_count
    FROM public.campaign_logs
    WHERE user_id = p_user_id
    AND status = p_status;
    
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


CREATE OR REPLACE FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_profile jsonb;
    v_target_user_id uuid;
    v_current_user_type text;
BEGIN
    -- 기본값은 현재 사용자
    v_target_user_id := COALESCE(p_user_id, (select auth.uid()));
    
    -- 현재 사용자 타입 조회
    SELECT user_type INTO v_current_user_type
    FROM public.users 
    WHERE id = (select auth.uid());
    
    -- 권한 검증: 자신의 프로필이거나 관리자만 조회 가능
    IF v_target_user_id != (select auth.uid()) AND 
       v_current_user_type NOT IN ('ADMIN', 'OWNER') THEN
        RAISE EXCEPTION 'You can only view your own profile';
    END IF;
    
    -- 프로필 조회
    SELECT to_jsonb(users.*) INTO v_profile
    FROM public.users 
    WHERE id = v_target_user_id;
    
    IF v_profile IS NULL THEN
        RAISE EXCEPTION 'User profile not found';
    END IF;
    
    RETURN v_profile;
END;
$$;


ALTER FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_wallets"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_wallets jsonb;
    v_result jsonb;
BEGIN
    -- 권한 확인: 자신의 지갑이거나 관리자
    IF p_user_id != (select auth.uid()) AND 
       NOT EXISTS (
           SELECT 1 FROM public.users 
           WHERE id = (select auth.uid()) AND user_type IN ('ADMIN', 'OWNER')
       ) THEN
        RAISE EXCEPTION 'You can only view your own wallets';
    END IF;
    
    -- 지갑 정보 조회
    SELECT jsonb_agg(
        jsonb_build_object(
            'wallet_id', pw.id,
            'wallet_type', pw.owner_type,
            'points', pw.current_points,
            'created_at', pw.created_at,
            'updated_at', pw.updated_at
        ) ORDER BY pw.created_at ASC
    ) INTO v_wallets
    FROM public.point_wallets pw
    WHERE pw.owner_id = p_user_id;
    
    -- 결과 반환
    SELECT COALESCE(v_wallets, '[]'::jsonb) INTO v_result;
    
    RETURN v_result;
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
            (pw.owner_type = 'USER' AND pw.owner_id = (select auth.uid())) OR
            (pw.owner_type = 'COMPANY' AND pw.owner_id IN (
                SELECT company_id FROM public.company_users WHERE user_id = (select auth.uid())
            )) OR
            EXISTS (
                SELECT 1 FROM public.users 
                WHERE id = (select auth.uid()) AND user_type IN ('ADMIN', 'OWNER')
            )
        )
    ) THEN
        RAISE EXCEPTION 'You can only view wallets you own or have access to';
    END IF;
    
    -- 지갑 정보 조회
    SELECT jsonb_build_object(
        'wallet_id', pw.id,
        'wallet_type', pw.owner_type,
        'owner_id', pw.owner_id,
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
            (pw.owner_type = 'USER' AND pw.owner_id = (select auth.uid())) OR
            (pw.owner_type = 'COMPANY' AND pw.owner_id IN (
                SELECT company_id FROM public.company_users WHERE user_id = (select auth.uid())
            )) OR
            EXISTS (
                SELECT 1 FROM public.users 
                WHERE id = (select auth.uid()) AND user_type IN ('ADMIN', 'OWNER')
            )
        )
    ) THEN
        RAISE EXCEPTION 'You can only view logs for wallets you own or have access to';
    END IF;
    
    -- 로그 조회
    SELECT jsonb_agg(
        jsonb_build_object(
            'log_id', pl.id,
            'transaction_type', pl.transaction_type,
            'amount', pl.amount,
            'description', pl.description,
            'related_entity_type', pl.related_entity_type,
            'related_entity_id', pl.related_entity_id,
            'created_at', pl.created_at,
            'balance_after', pw.current_points -- 현재 잔액 (실제로는 거래 후 잔액을 계산해야 함)
        )
    ) INTO v_logs
    FROM public.point_logs pl
    JOIN public.point_wallets pw ON pl.wallet_id = pw.id
    WHERE pl.wallet_id = p_wallet_id
    ORDER BY pl.created_at DESC
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


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text" DEFAULT NULL::"text", "p_company_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_profile jsonb;
    v_current_user_type text;
BEGIN
    -- 자신의 프로필만 업데이트 가능
    IF p_user_id != (select auth.uid()) THEN
        RAISE EXCEPTION 'You can only update your own profile';
    END IF;
    
    -- 현재 사용자 타입 조회
    SELECT user_type INTO v_current_user_type
    FROM public.users 
    WHERE id = p_user_id;
    
    -- company_id 변경 권한 검증 (관리자만 가능)
    IF p_company_id IS NOT NULL AND 
       v_current_user_type NOT IN ('ADMIN', 'OWNER') THEN
        RAISE EXCEPTION 'Only admins can change company association';
    END IF;
    
    -- 프로필 업데이트 (user_type은 변경 불가)
    UPDATE public.users 
    SET 
        display_name = COALESCE(p_display_name, display_name),
        company_id = COALESCE(p_company_id, company_id),
        updated_at = NOW()
    WHERE id = p_user_id
    RETURNING to_jsonb(users.*) INTO v_profile;
    
    IF v_profile IS NULL THEN
        RAISE EXCEPTION 'User profile not found';
    END IF;
    
    RETURN v_profile;
END;
$$;


ALTER FUNCTION "public"."update_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_company_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."business_registrations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "business_name" "text" NOT NULL,
    "business_number" "text" NOT NULL,
    "business_address" "text" NOT NULL,
    "representative_name" "text" NOT NULL,
    "business_type" "text" NOT NULL,
    "registration_file_url" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "admin_notes" "text",
    "rejected_reason" "text",
    "submitted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "reviewed_at" timestamp with time zone,
    "reviewed_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "business_registrations_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."business_registrations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."campaign_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "campaign_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "action" "text" NOT NULL,
    "application_message" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "campaign_logs_action_check" CHECK (("action" = ANY (ARRAY['join'::"text", 'leave'::"text", 'complete'::"text", 'cancel'::"text"]))),
    CONSTRAINT "campaign_logs_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text", 'completed'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."campaign_logs" OWNER TO "postgres";


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
    "created_by" "uuid",
    "campaign_type" "text" DEFAULT 'reviewer'::"text",
    "review_reward" integer,
    "last_used_at" timestamp with time zone,
    "usage_count" integer DEFAULT 0,
    CONSTRAINT "campaigns_campaign_type_check" CHECK (("campaign_type" = ANY (ARRAY['reviewer'::"text", 'journalist'::"text", 'visit'::"text"]))),
    CONSTRAINT "campaigns_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'completed'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."campaigns" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."companies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "business_number" "text",
    "contact_email" "text",
    "contact_phone" "text",
    "address" "text",
    "representative_name" "text",
    "business_type" "text",
    "registration_file_url" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."companies" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."company_users" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "company_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "company_role" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "company_users_company_role_check" CHECK (("company_role" = ANY (ARRAY['owner'::"text", 'manager'::"text"])))
);


ALTER TABLE "public"."company_users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."deleted_users" (
    "id" "uuid" NOT NULL,
    "email" "text",
    "display_name" "text",
    "user_type" "text",
    "company_id" "uuid",
    "deletion_reason" "text",
    "deleted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "original_created_at" timestamp with time zone
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


CREATE TABLE IF NOT EXISTS "public"."point_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "wallet_id" "uuid" NOT NULL,
    "transaction_type" "text" NOT NULL,
    "amount" integer NOT NULL,
    "description" "text",
    "related_entity_type" "text",
    "related_entity_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "point_logs_transaction_type_check" CHECK (("transaction_type" = ANY (ARRAY['earn'::"text", 'spend'::"text", 'refund'::"text", 'bonus'::"text", 'penalty'::"text"])))
);


ALTER TABLE "public"."point_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."point_wallets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_type" "text" NOT NULL,
    "owner_id" "uuid" NOT NULL,
    "current_points" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "point_wallets_owner_type_check" CHECK (("owner_type" = ANY (ARRAY['USER'::"text", 'COMPANY'::"text"])))
);


ALTER TABLE "public"."point_wallets" OWNER TO "postgres";


-- Reviews table removed - not being used (review data is stored in campaign_logs.data)
-- CREATE TABLE IF NOT EXISTS "public"."reviews" (
--     "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
--     "campaign_id" "uuid" NOT NULL,
--     "user_id" "uuid" NOT NULL,
--     "title" "text" NOT NULL,
--     "content" "text" NOT NULL,
--     "rating" integer,
--     "platform" "text",
--     "review_url" "text",
--     "status" "text" DEFAULT 'draft'::"text" NOT NULL,
--     "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
--     "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
--     CONSTRAINT "reviews_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5))),
--     CONSTRAINT "reviews_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'published'::"text", 'rejected'::"text"])))
-- );

-- ALTER TABLE "public"."reviews" OWNER TO "postgres";


-- Users table already created in 001_initial_schema.sql
-- CREATE TABLE IF NOT EXISTS "public"."users" (
--     "id" "uuid" NOT NULL,
--     "display_name" "text",
--     "user_type" "text" DEFAULT 'REVIEWER'::"text" NOT NULL,
--     "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
--     "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
--     CONSTRAINT "users_user_type_check" CHECK (("user_type" = ANY (ARRAY['REVIEWER'::"text", 'MANAGER'::"text", 'OWNER'::"text", 'ADMIN'::"text", 'user'::"text", 'admin'::"text"])))
-- );


-- ALTER TABLE "public"."users" OWNER TO "postgres";


ALTER TABLE ONLY "public"."business_registrations"
    ADD CONSTRAINT "business_registrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."campaign_logs"
    ADD CONSTRAINT "campaign_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."campaigns"
    ADD CONSTRAINT "campaigns_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."companies"
    ADD CONSTRAINT "companies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."company_users"
    ADD CONSTRAINT "company_users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."deleted_users"
    ADD CONSTRAINT "deleted_users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."point_logs"
    ADD CONSTRAINT "point_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."point_wallets"
    ADD CONSTRAINT "point_wallets_pkey" PRIMARY KEY ("id");



-- Reviews table removed
-- ALTER TABLE ONLY "public"."reviews"
--     ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



-- Users primary key already set in 001_initial_schema.sql
-- ALTER TABLE ONLY "public"."users"
--     ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_business_registrations_business_number" ON "public"."business_registrations" USING "btree" ("business_number");



CREATE INDEX "idx_business_registrations_status" ON "public"."business_registrations" USING "btree" ("status");



CREATE INDEX "idx_business_registrations_submitted_at" ON "public"."business_registrations" USING "btree" ("submitted_at");



CREATE INDEX "idx_business_registrations_user_id" ON "public"."business_registrations" USING "btree" ("user_id");



CREATE INDEX "idx_campaign_logs_action" ON "public"."campaign_logs" USING "btree" ("action");



CREATE INDEX "idx_campaign_logs_campaign_id" ON "public"."campaign_logs" USING "btree" ("campaign_id");



CREATE INDEX "idx_campaign_logs_campaign_user" ON "public"."campaign_logs" USING "btree" ("campaign_id", "user_id");



CREATE INDEX "idx_campaign_logs_created_at" ON "public"."campaign_logs" USING "btree" ("created_at");



CREATE INDEX "idx_campaign_logs_status" ON "public"."campaign_logs" USING "btree" ("status");



CREATE INDEX "idx_campaign_logs_user_id" ON "public"."campaign_logs" USING "btree" ("user_id");



CREATE INDEX "idx_campaigns_campaign_type" ON "public"."campaigns" USING "btree" ("campaign_type");



CREATE INDEX "idx_campaigns_company_id" ON "public"."campaigns" USING "btree" ("company_id");



CREATE INDEX "idx_campaigns_created_at" ON "public"."campaigns" USING "btree" ("created_at");



CREATE INDEX "idx_campaigns_created_by" ON "public"."campaigns" USING "btree" ("created_by");



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



CREATE INDEX "idx_companies_created_at" ON "public"."companies" USING "btree" ("created_at");



CREATE INDEX "idx_companies_name" ON "public"."companies" USING "gin" ("to_tsvector"('"english"'::"regconfig", "name"));



CREATE INDEX "idx_deleted_users_company_id" ON "public"."deleted_users" USING "btree" ("company_id");



CREATE INDEX "idx_deleted_users_deleted_at" ON "public"."deleted_users" USING "btree" ("deleted_at");



CREATE INDEX "idx_deleted_users_email" ON "public"."deleted_users" USING "btree" ("email");



CREATE INDEX "idx_deleted_users_user_type" ON "public"."deleted_users" USING "btree" ("user_type");



CREATE INDEX "idx_notifications_created_at" ON "public"."notifications" USING "btree" ("created_at");



CREATE INDEX "idx_notifications_is_read" ON "public"."notifications" USING "btree" ("is_read");



CREATE INDEX "idx_notifications_related_entity" ON "public"."notifications" USING "btree" ("related_entity_type", "related_entity_id");



CREATE INDEX "idx_notifications_type" ON "public"."notifications" USING "btree" ("type");



CREATE INDEX "idx_notifications_user_id" ON "public"."notifications" USING "btree" ("user_id");



CREATE INDEX "idx_notifications_user_read" ON "public"."notifications" USING "btree" ("user_id", "is_read");



CREATE INDEX "idx_notifications_user_type" ON "public"."notifications" USING "btree" ("user_id", "type");



CREATE INDEX "idx_point_logs_amount" ON "public"."point_logs" USING "btree" ("amount");



CREATE INDEX "idx_point_logs_created_at" ON "public"."point_logs" USING "btree" ("created_at");



CREATE INDEX "idx_point_logs_related_entity" ON "public"."point_logs" USING "btree" ("related_entity_type", "related_entity_id");



CREATE INDEX "idx_point_logs_transaction_type" ON "public"."point_logs" USING "btree" ("transaction_type");



CREATE INDEX "idx_point_logs_wallet_id" ON "public"."point_logs" USING "btree" ("wallet_id");



CREATE INDEX "idx_point_wallets_created_at" ON "public"."point_wallets" USING "btree" ("created_at");



CREATE INDEX "idx_point_wallets_current_points" ON "public"."point_wallets" USING "btree" ("current_points");



CREATE INDEX "idx_point_wallets_owner" ON "public"."point_wallets" USING "btree" ("owner_type", "owner_id");



-- Users indexes already created in 001_initial_schema.sql if needed
-- CREATE INDEX "idx_users_id" ON "public"."users" USING "btree" ("id");



-- CREATE INDEX "idx_users_user_type" ON "public"."users" USING "btree" ("user_type");



CREATE OR REPLACE TRIGGER "update_campaign_logs_updated_at" BEFORE UPDATE ON "public"."campaign_logs" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_campaigns_updated_at" BEFORE UPDATE ON "public"."campaigns" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_companies_updated_at" BEFORE UPDATE ON "public"."companies" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_point_wallets_updated_at" BEFORE UPDATE ON "public"."point_wallets" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



-- Reviews table removed
-- CREATE OR REPLACE TRIGGER "update_reviews_updated_at" BEFORE UPDATE ON "public"."reviews" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_users_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."business_registrations"
    ADD CONSTRAINT "business_registrations_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."business_registrations"
    ADD CONSTRAINT "business_registrations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."campaign_logs"
    ADD CONSTRAINT "campaign_logs_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "public"."campaigns"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."campaign_logs"
    ADD CONSTRAINT "campaign_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."campaigns"
    ADD CONSTRAINT "campaigns_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."campaigns"
    ADD CONSTRAINT "campaigns_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."company_users"
    ADD CONSTRAINT "company_users_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."company_users"
    ADD CONSTRAINT "company_users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."point_logs"
    ADD CONSTRAINT "point_logs_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "public"."point_wallets"("id") ON DELETE CASCADE;



-- Reviews table removed
-- ALTER TABLE ONLY "public"."reviews"
--     ADD CONSTRAINT "reviews_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "public"."campaigns"("id") ON DELETE CASCADE;



-- Reviews table removed
-- ALTER TABLE ONLY "public"."reviews"
--     ADD CONSTRAINT "reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



-- Users foreign key already set in 001_initial_schema.sql if needed
-- ALTER TABLE ONLY "public"."users"
--     ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Admins can update all business registrations" ON "public"."business_registrations" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."user_type" = ANY (ARRAY['ADMIN'::"text", 'OWNER'::"text"]))))));



CREATE POLICY "Admins can view all business registrations" ON "public"."business_registrations" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = "auth"."uid"()) AND ("users"."user_type" = ANY (ARRAY['ADMIN'::"text", 'OWNER'::"text"]))))));



CREATE POLICY "Campaign logs are insertable by authenticated users" ON "public"."campaign_logs" FOR INSERT WITH CHECK ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("campaign_id" IN ( SELECT "campaigns"."id"
   FROM "public"."campaigns"
  WHERE ("campaigns"."company_id" IN ( SELECT "company_users"."company_id"
           FROM "public"."company_users"
          WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))))));



CREATE POLICY "Campaign logs are updatable by participants and company" ON "public"."campaign_logs" FOR UPDATE USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("campaign_id" IN ( SELECT "campaigns"."id"
   FROM "public"."campaigns"
  WHERE ("campaigns"."company_id" IN ( SELECT "company_users"."company_id"
           FROM "public"."company_users"
          WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))))));



CREATE POLICY "Campaign logs are viewable by participants and company" ON "public"."campaign_logs" FOR SELECT USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("campaign_id" IN ( SELECT "campaigns"."id"
   FROM "public"."campaigns"
  WHERE ("campaigns"."company_id" IN ( SELECT "company_users"."company_id"
           FROM "public"."company_users"
          WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))))));



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
  WHERE (("company_users"."company_id" = "company_users"."id") AND ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("company_users"."company_role" = 'owner'::"text")))));



CREATE POLICY "Companies are viewable by everyone" ON "public"."companies" FOR SELECT USING (true);



CREATE POLICY "Company users are insertable by company owners" ON "public"."company_users" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."company_users" "company_users_1"
  WHERE (("company_users_1"."company_id" = "company_users_1"."company_id") AND ("company_users_1"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("company_users_1"."company_role" = 'owner'::"text")))));



CREATE POLICY "Company users are viewable by everyone" ON "public"."company_users" FOR SELECT USING (true);



CREATE POLICY "Deleted users are insertable by system" ON "public"."deleted_users" FOR INSERT WITH CHECK (true);



CREATE POLICY "Deleted users are viewable by admins" ON "public"."deleted_users" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."user_type" = ANY (ARRAY['ADMIN'::"text", 'OWNER'::"text"]))))));



CREATE POLICY "Notifications are insertable by system" ON "public"."notifications" FOR INSERT WITH CHECK (true);



CREATE POLICY "Notifications are updatable by owner" ON "public"."notifications" FOR UPDATE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Notifications are viewable by owner" ON "public"."notifications" FOR SELECT USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Point logs are insertable by system" ON "public"."point_logs" FOR INSERT WITH CHECK (true);



CREATE POLICY "Point logs are viewable by wallet owner" ON "public"."point_logs" FOR SELECT USING (("wallet_id" IN ( SELECT "point_wallets"."id"
   FROM "public"."point_wallets"
  WHERE ((("point_wallets"."owner_type" = 'USER'::"text") AND ("point_wallets"."owner_id" = ( SELECT "auth"."uid"() AS "uid"))) OR (("point_wallets"."owner_type" = 'COMPANY'::"text") AND ("point_wallets"."owner_id" IN ( SELECT "company_users"."company_id"
           FROM "public"."company_users"
          WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))))));



CREATE POLICY "Point wallets are insertable by authenticated users" ON "public"."point_wallets" FOR INSERT WITH CHECK ((("owner_type" = 'USER'::"text") AND ("owner_id" = ( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Point wallets are updatable by owner" ON "public"."point_wallets" FOR UPDATE USING (((("owner_type" = 'USER'::"text") AND ("owner_id" = ( SELECT "auth"."uid"() AS "uid"))) OR (("owner_type" = 'COMPANY'::"text") AND ("owner_id" IN ( SELECT "company_users"."company_id"
   FROM "public"."company_users"
  WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "Point wallets are viewable by owner" ON "public"."point_wallets" FOR SELECT USING (((("owner_type" = 'USER'::"text") AND ("owner_id" = ( SELECT "auth"."uid"() AS "uid"))) OR (("owner_type" = 'COMPANY'::"text") AND ("owner_id" IN ( SELECT "company_users"."company_id"
   FROM "public"."company_users"
  WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))));



-- Reviews table removed
-- CREATE POLICY "Reviews are insertable by participants" ON "public"."reviews" FOR INSERT WITH CHECK ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("campaign_id" IN ( SELECT "campaign_logs"."campaign_id"
--    FROM "public"."campaign_logs"
--   WHERE (("campaign_logs"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("campaign_logs"."status" = 'approved'::"text"))))));
--
--
--
-- CREATE POLICY "Reviews are updatable by author" ON "public"."reviews" FOR UPDATE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));
--
--
--
-- CREATE POLICY "Reviews are viewable by everyone" ON "public"."reviews" FOR SELECT USING (true);



CREATE POLICY "Users are viewable by everyone" ON "public"."users" FOR SELECT USING (true);



CREATE POLICY "Users can insert own business registrations" ON "public"."business_registrations" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own profile" ON "public"."users" FOR INSERT WITH CHECK ((("id" = ( SELECT "auth"."uid"() AS "uid")) OR (( SELECT "auth"."uid"() AS "uid") IS NOT NULL)));



CREATE POLICY "Users can update own pending business registrations" ON "public"."business_registrations" FOR UPDATE USING ((("auth"."uid"() = "user_id") AND ("status" = 'pending'::"text")));



CREATE POLICY "Users can update own profile" ON "public"."users" FOR UPDATE USING (("id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Users can view own business registrations" ON "public"."business_registrations" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."business_registrations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."campaign_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."campaigns" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."companies" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."company_users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."deleted_users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."point_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."point_wallets" ENABLE ROW LEVEL SECURITY;


-- Reviews table removed
-- ALTER TABLE "public"."reviews" ENABLE ROW LEVEL SECURITY;


-- RLS already enabled in 001_initial_schema.sql
-- ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";





GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";































































































































































GRANT ALL ON FUNCTION "public"."admin_change_user_role"("p_target_user_id" "uuid", "p_new_role" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_change_user_role"("p_target_user_id" "uuid", "p_new_role" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_change_user_role"("p_target_user_id" "uuid", "p_new_role" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_user_exists"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."check_user_exists"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_user_exists"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_user_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_user_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_user_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."earn_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."earn_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."earn_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_campaigns_safe"("p_user_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_campaigns_safe"("p_user_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_campaigns_safe"("p_user_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_participated_campaigns_safe"("p_user_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_participated_campaigns_safe"("p_user_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_participated_campaigns_safe"("p_user_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") TO "service_role";



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



GRANT ALL ON FUNCTION "public"."request_point_charge"("p_user_id" "uuid", "p_amount" integer, "p_cash_amount" double precision, "p_payment_method" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."request_point_charge"("p_user_id" "uuid", "p_amount" integer, "p_cash_amount" double precision, "p_payment_method" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."request_point_charge"("p_user_id" "uuid", "p_amount" integer, "p_cash_amount" double precision, "p_payment_method" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."spend_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."spend_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."spend_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_company_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_company_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_company_id" "uuid") TO "service_role";


















GRANT ALL ON TABLE "public"."business_registrations" TO "anon";
GRANT ALL ON TABLE "public"."business_registrations" TO "authenticated";
GRANT ALL ON TABLE "public"."business_registrations" TO "service_role";



GRANT ALL ON TABLE "public"."campaign_logs" TO "anon";
GRANT ALL ON TABLE "public"."campaign_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."campaign_logs" TO "service_role";



GRANT ALL ON TABLE "public"."campaigns" TO "anon";
GRANT ALL ON TABLE "public"."campaigns" TO "authenticated";
GRANT ALL ON TABLE "public"."campaigns" TO "service_role";



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



GRANT ALL ON TABLE "public"."point_logs" TO "anon";
GRANT ALL ON TABLE "public"."point_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."point_logs" TO "service_role";



GRANT ALL ON TABLE "public"."point_wallets" TO "anon";
GRANT ALL ON TABLE "public"."point_wallets" TO "authenticated";
GRANT ALL ON TABLE "public"."point_wallets" TO "service_role";



-- Reviews table removed
-- GRANT ALL ON TABLE "public"."reviews" TO "anon";
-- GRANT ALL ON TABLE "public"."reviews" TO "authenticated";
-- GRANT ALL ON TABLE "public"."reviews" TO "service_role";



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

--
-- Dumped schema changes for auth and storage
--

