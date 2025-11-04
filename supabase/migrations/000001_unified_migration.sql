-- ============================================================================
-- 통합 마이그레이션 파일
-- ============================================================================
-- 이 파일은 모든 마이그레이션을 하나로 통합한 파일입니다.
-- 생성일: 2025-01-02
-- 
-- 포함된 마이그레이션:
--   1. 000001_unified_schema.sql - 초기 스키마
--   2. 20251029073201_remote_schema.sql - 원격 스키마 변경
--   3. 20251030000000_fix_companies_update_policy.sql - Companies 업데이트 정책 수정
--   4. 20251030000001_simplify_user_type.sql - 사용자 타입 단순화
--   5. 20251030000002_unify_user_id_foreign_keys.sql - user_id 외래키 통일
--   6. 20251030000003_update_campaigns_and_point_wallets.sql - 캠페인 및 포인트 지갑 업데이트
--   7. 20251030000004_change_point_wallet_user_type_values.sql - 포인트 지갑 타입 값 변경
--   8. 20251030000005_rename_user_type_to_wallet_type.sql - user_type을 wallet_type으로 변경
--   9. 20251030000006_add_user_id_foreign_key_to_companies.sql - Companies에 user_id 외래키 추가
--  10. 20251030000007_rename_companies_name_to_business_name.sql - Companies name을 business_name으로 변경
--  11. 20251031000001_create_sns_platform_connections.sql - SNS 플랫폼 연결 테이블 생성
--  12. 20251031000002_rename_sns_table_and_add_return_address.sql - SNS 테이블 이름 변경 및 회수 주소 추가
--  13. 20250102000001_add_transactions_and_cleanup_orphaned_users.sql - 트랜잭션 적용 및 orphaned users 정리
-- ============================================================================


-- ============================================================================
-- Migration: 000001_unified_schema.sql
-- ============================================================================

-- Unified Schema Migration
-- Generated: 2025-01-30
-- Consolidates: 001_initial_schema.sql, 20251024044655_create_business_registration_table.sql
-- Note: business_registrations and reviews tables are removed (not used)




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


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';


SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" uuid NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "display_name" "text",
    "user_type" "text" DEFAULT 'REVIEWER'::text
);


ALTER TABLE "public"."users" OWNER TO "postgres";



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



-- Sequence users_id_seq removed as users.id is now uuid (not an identity column)
-- GRANT ALL ON SEQUENCE "public"."users_id_seq" TO "anon";
-- GRANT ALL ON SEQUENCE "public"."users_id_seq" TO "authenticated";
-- GRANT ALL ON SEQUENCE "public"."users_id_seq" TO "service_role";



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

-- Additional schema components
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
    v_user_exists boolean;
BEGIN 
    -- 이미 프로필이 존재하는지 확인
    SELECT EXISTS(SELECT 1 FROM public.users WHERE id = p_user_id) INTO v_user_exists;
    
    IF v_user_exists THEN
        -- 프로필이 이미 존재하면 해당 프로필 반환
        SELECT to_jsonb(users.*) INTO v_profile
        FROM public.users 
        WHERE id = p_user_id;
        RETURN v_profile;
    END IF;
    
    -- 현재 사용자 타입 조회 (관리자 권한 확인용)
    -- 새 사용자는 아직 프로필이 없을 수 있으므로 예외 처리
    BEGIN
        SELECT user_type INTO v_current_user_type 
        FROM public.users 
        WHERE id = (select auth.uid());
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_current_user_type := NULL;
    END;
    
    -- 권한 검증: 관리자만 특별한 타입(ADMIN, OWNER) 설정 가능
    -- USER와 REVIEWER는 일반 사용자도 생성 가능
    -- 자기 자신의 프로필 생성은 항상 허용 (자기 자신이거나 user_id == auth.uid())
    IF p_user_type NOT IN ('REVIEWER', 'USER') AND 
       (v_current_user_type IS NULL OR v_current_user_type NOT IN ('ADMIN', 'OWNER')) AND
       p_user_id != (select auth.uid()) THEN 
        RAISE EXCEPTION 'Only admins can create special user types (ADMIN, OWNER)'; 
    END IF; 
    
    -- 사용자 프로필 생성 (권한은 서버에서 제어)
    -- ON CONFLICT로 중복 생성 방지
    INSERT INTO public.users ( 
        id, display_name, user_type, created_at, updated_at 
    ) VALUES ( 
        p_user_id, p_display_name, p_user_type, NOW(), NOW() 
    )
    ON CONFLICT (id) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        updated_at = NOW()
    RETURNING to_jsonb(users.*) INTO v_profile; 
    
    -- 포인트 지갑이 없으면 생성 (중복 체크)
    IF NOT EXISTS (
        SELECT 1 FROM public.point_wallets 
        WHERE owner_type = 'USER' AND owner_id = p_user_id
    ) THEN
        INSERT INTO public.point_wallets ( 
            owner_type, owner_id, current_points, created_at, updated_at 
        ) VALUES ( 
            'USER', p_user_id, 0, NOW(), NOW() 
        );
    END IF;
    
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
  WHERE (("company_users"."company_id" = "companies"."id") AND ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("company_users"."company_role" = 'owner'::"text")))));



CREATE POLICY "Companies are viewable by everyone" ON "public"."companies" FOR SELECT USING (true);



-- Policy: Allow authenticated users to add themselves as owner when creating a new company
-- This handles the case when a company is first created and no owner exists yet
CREATE POLICY "Company users are insertable for new company owners" ON "public"."company_users" FOR INSERT 
WITH CHECK (
  -- Allow if user is adding themselves as owner AND either:
  -- 1. They are the creator of the company (created_by matches), OR
  -- 2. The company has no existing owners yet
  (
    "user_id" = ( SELECT "auth"."uid"() AS "uid") 
    AND "company_role" = 'owner'::text
    AND (
      -- User created the company
      EXISTS (
        SELECT 1 FROM "public"."companies"
        WHERE "companies"."id" = "company_users"."company_id"
        AND "companies"."created_by" = ( SELECT "auth"."uid"() AS "uid")
      )
      OR
      -- No owners exist for this company yet
      NOT EXISTS (
        SELECT 1 FROM "public"."company_users" "cu"
        WHERE "cu"."company_id" = "company_users"."company_id"
        AND "cu"."company_role" = 'owner'::text
      )
    )
  )
);

-- Policy: Allow existing company owners to add new members
CREATE POLICY "Company users are insertable by company owners" ON "public"."company_users" FOR INSERT 
WITH CHECK (
  -- Allow if there's an existing owner (not the user being added) who is the current authenticated user
  EXISTS (
    SELECT 1
    FROM "public"."company_users" "cu"
    WHERE "cu"."company_id" = "company_users"."company_id"
    AND "cu"."user_id" = ( SELECT "auth"."uid"() AS "uid")
    AND "cu"."company_role" = 'owner'::text
    AND "cu"."user_id" != "company_users"."user_id" -- Don't allow adding yourself as non-owner
  )
);

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


-- ============================================================================
-- End of Migration: 000001_unified_schema.sql
-- ============================================================================



-- ============================================================================
-- Migration: 20251029073201_remote_schema.sql
-- ============================================================================

drop policy "Admins can update all business registrations" on "public"."business_registrations";

drop policy "Admins can view all business registrations" on "public"."business_registrations";

drop policy "Users can insert own business registrations" on "public"."business_registrations";

drop policy "Users can update own pending business registrations" on "public"."business_registrations";

drop policy "Users can view own business registrations" on "public"."business_registrations";

revoke delete on table "public"."business_registrations" from "anon";

revoke insert on table "public"."business_registrations" from "anon";

revoke references on table "public"."business_registrations" from "anon";

revoke select on table "public"."business_registrations" from "anon";

revoke trigger on table "public"."business_registrations" from "anon";

revoke truncate on table "public"."business_registrations" from "anon";

revoke update on table "public"."business_registrations" from "anon";

revoke delete on table "public"."business_registrations" from "authenticated";

revoke insert on table "public"."business_registrations" from "authenticated";

revoke references on table "public"."business_registrations" from "authenticated";

revoke select on table "public"."business_registrations" from "authenticated";

revoke trigger on table "public"."business_registrations" from "authenticated";

revoke truncate on table "public"."business_registrations" from "authenticated";

revoke update on table "public"."business_registrations" from "authenticated";

revoke delete on table "public"."business_registrations" from "service_role";

revoke insert on table "public"."business_registrations" from "service_role";

revoke references on table "public"."business_registrations" from "service_role";

revoke select on table "public"."business_registrations" from "service_role";

revoke trigger on table "public"."business_registrations" from "service_role";

revoke truncate on table "public"."business_registrations" from "service_role";

revoke update on table "public"."business_registrations" from "service_role";

alter table "public"."business_registrations" drop constraint "business_registrations_reviewed_by_fkey";

alter table "public"."business_registrations" drop constraint "business_registrations_status_check";

alter table "public"."business_registrations" drop constraint "business_registrations_user_id_fkey";

alter table "public"."business_registrations" drop constraint "business_registrations_pkey";

drop index if exists "public"."business_registrations_pkey";

drop index if exists "public"."idx_business_registrations_business_number";

drop index if exists "public"."idx_business_registrations_status";

drop index if exists "public"."idx_business_registrations_submitted_at";

drop index if exists "public"."idx_business_registrations_user_id";

drop table "public"."business_registrations";




-- ============================================================================
-- End of Migration: 20251029073201_remote_schema.sql
-- ============================================================================



-- ============================================================================
-- Migration: 20251030000000_fix_companies_update_policy.sql
-- ============================================================================

-- Fix RLS policy bug for companies table update
-- The original policy had a bug: company_users.company_id = company_users.id (wrong)
-- Should be: company_users.company_id = companies.id (correct)

DROP POLICY IF EXISTS "Companies are updatable by owners" ON public.companies;

CREATE POLICY "Companies are updatable by owners" ON public.companies 
FOR UPDATE 
USING (
  EXISTS (
    SELECT 1
    FROM public.company_users
    WHERE (
      company_users.company_id = companies.id 
      AND company_users.user_id = auth.uid()
      AND company_users.company_role = 'owner'::text
    )
  )
);


-- ============================================================================
-- End of Migration: 20251030000000_fix_companies_update_policy.sql
-- ============================================================================



-- ============================================================================
-- Migration: 20251030000001_simplify_user_type.sql
-- ============================================================================

-- user_type을 'user'와 'admin'만 사용하도록 단순화
-- 'user': 일반 사용자 (리뷰어 또는 광고주)
-- 'admin': 시스템 관리자 (전역 권한)

-- 1. 기본값 변경
ALTER TABLE "public"."users" 
  ALTER COLUMN "user_type" SET DEFAULT 'user'::text;

-- 2. 기존 데이터 마이그레이션
-- REVIEWER, USER → user
UPDATE "public"."users" 
SET "user_type" = 'user' 
WHERE "user_type" IN ('REVIEWER', 'USER', 'user');

-- ADMIN, OWNER → admin (시스템 관리자)
UPDATE "public"."users" 
SET "user_type" = 'admin' 
WHERE "user_type" IN ('ADMIN', 'OWNER', 'admin');

-- MANAGER는 company_users 테이블로 관리되므로 user로 변경
UPDATE "public"."users" 
SET "user_type" = 'user' 
WHERE "user_type" = 'MANAGER';

-- 3. 함수 업데이트: create_user_profile_safe
CREATE OR REPLACE FUNCTION "public"."create_user_profile_safe"(
  "p_user_id" "uuid", 
  "p_display_name" "text", 
  "p_user_type" "text" DEFAULT 'user'::"text"
) RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$ 
DECLARE 
  v_profile jsonb; 
  v_current_user_type text; 
  v_user_exists boolean;
BEGIN 
  -- 이미 프로필이 존재하는지 확인
  SELECT EXISTS(SELECT 1 FROM public.users WHERE id = p_user_id) INTO v_user_exists;
  
  IF v_user_exists THEN
    -- 프로필이 이미 존재하면 해당 프로필 반환
    SELECT to_jsonb(users.*) INTO v_profile
    FROM public.users 
    WHERE id = p_user_id;
    RETURN v_profile;
  END IF;
  
  -- 현재 사용자 타입 조회 (관리자 권한 확인용)
  BEGIN
    SELECT user_type INTO v_current_user_type 
    FROM public.users 
    WHERE id = (select auth.uid());
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_current_user_type := NULL;
  END;
  
  -- 권한 검증: 관리자만 admin 타입 설정 가능
  -- user는 일반 사용자도 생성 가능
  -- 자기 자신의 프로필 생성은 항상 허용
  IF p_user_type = 'admin' AND 
     (v_current_user_type IS NULL OR v_current_user_type != 'admin') AND
     p_user_id != (select auth.uid()) THEN 
    RAISE EXCEPTION 'Only admins can create admin user types'; 
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
  
  -- 포인트 지갑이 없으면 생성 (중복 체크)
  IF NOT EXISTS (
    SELECT 1 FROM public.point_wallets 
    WHERE owner_type = 'USER' AND owner_id = p_user_id
  ) THEN
    INSERT INTO public.point_wallets ( 
      owner_type, owner_id, current_points, created_at, updated_at 
    ) VALUES ( 
      'USER', p_user_id, 0, NOW(), NOW() 
    ); 
  END IF;
  
  RETURN v_profile; 
END; 
$$;

-- 4. 함수 업데이트: admin_change_user_role
CREATE OR REPLACE FUNCTION "public"."admin_change_user_role"(
  "p_target_user_id" "uuid", 
  "p_new_role" "text"
) RETURNS "jsonb"
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
  
  IF v_current_user_type != 'admin' THEN
    RAISE EXCEPTION 'Only admins can change user roles';
  END IF;
  
  -- 새로운 역할이 'user' 또는 'admin'만 허용
  IF p_new_role NOT IN ('user', 'admin') THEN
    RAISE EXCEPTION 'Invalid user role. Only "user" and "admin" are allowed';
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

-- 5. 모든 함수에서 권한 체크 변경 (ADMIN, OWNER → admin)
-- earn_points 함수
CREATE OR REPLACE FUNCTION "public"."earn_points"(
  "p_user_id" "uuid", 
  "p_amount" integer, 
  "p_description" "text", 
  "p_related_entity_type" "text" DEFAULT NULL::"text", 
  "p_related_entity_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
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

-- get_user_campaigns_safe 함수
CREATE OR REPLACE FUNCTION "public"."get_user_campaigns_safe"(
  "p_user_id" "uuid", 
  "p_status" "text" DEFAULT 'all'::"text", 
  "p_limit" integer DEFAULT 20, 
  "p_offset" integer DEFAULT 0
) RETURNS "jsonb"
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

-- get_user_participated_campaigns_safe 함수
CREATE OR REPLACE FUNCTION "public"."get_user_participated_campaigns_safe"(
  "p_user_id" "uuid", 
  "p_status" "text" DEFAULT 'all'::"text", 
  "p_limit" integer DEFAULT 20, 
  "p_offset" integer DEFAULT 0
) RETURNS "jsonb"
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

-- get_user_profile_safe 함수
CREATE OR REPLACE FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
  v_profile jsonb;
  v_current_user_type text;
  v_target_user_id uuid;
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

-- get_user_wallet_safe 함수
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
  WHERE wallets.owner_type = 'USER' AND wallets.owner_id = p_user_id
  LIMIT 1;
  
  IF v_wallet IS NULL THEN
    RAISE EXCEPTION 'Wallet not found';
  END IF;
  
  RETURN v_wallet;
END;
$$;

-- get_user_point_logs_safe 함수
CREATE OR REPLACE FUNCTION "public"."get_user_point_logs_safe"(
  "p_user_id" "uuid", 
  "p_transaction_type" "text" DEFAULT 'all'::"text", 
  "p_limit" integer DEFAULT 50, 
  "p_offset" integer DEFAULT 0
) RETURNS "jsonb"
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
  WHERE owner_type = 'USER' AND owner_id = p_user_id
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

-- request_point_charge_safe 함수
CREATE OR REPLACE FUNCTION "public"."request_point_charge_safe"(
  "p_user_id" "uuid", 
  "p_amount" integer, 
  "p_payment_method" "text"
) RETURNS "jsonb"
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

-- spend_points_safe 함수
CREATE OR REPLACE FUNCTION "public"."spend_points_safe"(
  "p_user_id" "uuid", 
  "p_amount" integer, 
  "p_description" "text", 
  "p_related_entity_type" "text" DEFAULT NULL::"text", 
  "p_related_entity_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
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
  
  -- 지갑 찾기
  SELECT id, current_points INTO v_wallet_id, v_current_points
  FROM public.point_wallets
  WHERE owner_type = 'USER' AND owner_id = p_user_id
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

-- update_user_company_association 함수
CREATE OR REPLACE FUNCTION "public"."update_user_company_association"(
  "p_user_id" "uuid", 
  "p_company_id" "uuid", 
  "p_role" "text"
) RETURNS "jsonb"
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

-- 6. RLS 정책 업데이트 (존재하는 테이블만)
DROP POLICY IF EXISTS "Deleted users are viewable by admins" ON "public"."deleted_users";
CREATE POLICY "Deleted users are viewable by admins" ON "public"."deleted_users" 
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM "public"."users"
    WHERE ("users"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("users"."user_type" = 'admin')
  )
);


-- ============================================================================
-- End of Migration: 20251030000001_simplify_user_type.sql
-- ============================================================================



-- ============================================================================
-- Migration: 20251030000002_unify_user_id_foreign_keys.sql
-- ============================================================================

-- 모든 테이블의 사용자 외래키 필드명을 user_id로 통일
-- companies 테이블에 user_id 필드 추가

-- 1. campaigns 테이블: created_by → user_id
ALTER TABLE "public"."campaigns" 
  RENAME COLUMN "created_by" TO "user_id";

-- 외래키 제약조건 재생성
ALTER TABLE "public"."campaigns"
  DROP CONSTRAINT IF EXISTS "campaigns_created_by_fkey";

ALTER TABLE "public"."campaigns"
  ADD CONSTRAINT "campaigns_user_id_fkey" 
  FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;

-- 인덱스 이름 변경
DROP INDEX IF EXISTS "public"."idx_campaigns_created_by";
CREATE INDEX IF NOT EXISTS "idx_campaigns_user_id" ON "public"."campaigns" USING "btree" ("user_id");

-- 2. companies 테이블: created_by → user_id로 변경 및 추가
-- 먼저 created_by가 있으면 user_id로 변경
DO $$
BEGIN
  -- created_by 컬럼이 존재하는지 확인
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'companies' 
    AND column_name = 'created_by'
  ) THEN
    ALTER TABLE "public"."companies" 
      RENAME COLUMN "created_by" TO "user_id";
  ELSE
    -- created_by가 없으면 user_id 컬럼 추가
    ALTER TABLE "public"."companies" 
      ADD COLUMN "user_id" uuid;
  END IF;
END $$;

-- 외래키 제약조건 재생성
ALTER TABLE "public"."companies"
  DROP CONSTRAINT IF EXISTS "companies_created_by_fkey";

ALTER TABLE "public"."companies"
  ADD CONSTRAINT "companies_user_id_fkey" 
  FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS "idx_companies_user_id" ON "public"."companies" USING "btree" ("user_id");

-- 3. business_registrations 테이블: reviewed_by → user_id로 변경 (reviewed_by_user_id)
-- 이 테이블이 사용되는지 확인 필요하지만, 일단 통일성 위해 변경
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'business_registrations'
  ) THEN
    -- reviewed_by를 reviewed_by_user_id로 변경 (user_id와 구분)
    ALTER TABLE "public"."business_registrations" 
      RENAME COLUMN "reviewed_by" TO "reviewed_by_user_id";
    
    -- 외래키 제약조건 재생성
    ALTER TABLE "public"."business_registrations"
      DROP CONSTRAINT IF EXISTS "business_registrations_reviewed_by_fkey";

    ALTER TABLE "public"."business_registrations"
      ADD CONSTRAINT "business_registrations_reviewed_by_user_id_fkey" 
      FOREIGN KEY ("reviewed_by_user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;
  END IF;
END $$;

-- 4. RLS 정책 업데이트: created_by → user_id
-- campaigns 테이블 RLS 정책 업데이트
DROP POLICY IF EXISTS "Campaigns are insertable by company members" ON "public"."campaigns";
CREATE POLICY "Campaigns are insertable by company members" ON "public"."campaigns" 
FOR INSERT WITH CHECK (
  "company_id" IN (
    SELECT "company_users"."company_id"
    FROM "public"."company_users"
    WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid"))
  )
);

DROP POLICY IF EXISTS "Campaigns are updatable by company members" ON "public"."campaigns";
CREATE POLICY "Campaigns are updatable by company members" ON "public"."campaigns" 
FOR UPDATE USING (
  "company_id" IN (
    SELECT "company_users"."company_id"
    FROM "public"."company_users"
    WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid"))
  )
);

-- companies 테이블 RLS 정책 확인 및 업데이트
-- 기존 정책들이 created_by를 사용하는지 확인하고 업데이트
DROP POLICY IF EXISTS "Companies are insertable by authenticated users" ON "public"."companies";
CREATE POLICY "Companies are insertable by authenticated users" ON "public"."companies" 
FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") IS NOT NULL));

DROP POLICY IF EXISTS "Companies are viewable by everyone" ON "public"."companies";
CREATE POLICY "Companies are viewable by everyone" ON "public"."companies" 
FOR SELECT USING (true);

-- 기존 companies 업데이트 정책 확인 및 업데이트 (created_by → user_id로 변경)
DROP POLICY IF EXISTS "Companies are updatable by owners" ON "public"."companies";
CREATE POLICY "Companies are updatable by owners" ON "public"."companies" 
FOR UPDATE USING (
  EXISTS (
    SELECT 1
    FROM "public"."company_users"
    WHERE (
      ("company_users"."company_id" = "companies"."id") 
      AND ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid")) 
      AND ("company_users"."company_role" = 'owner'::"text")
    )
  )
);

-- company_users 테이블 정책에서 created_by 참조 확인 및 업데이트
DROP POLICY IF EXISTS "Company users are insertable for new company owners" ON "public"."company_users";
CREATE POLICY "Company users are insertable for new company owners" ON "public"."company_users" 
FOR INSERT WITH CHECK (
  -- 1. They are creating a company (user_id matches), OR
  EXISTS (
    SELECT 1 FROM "public"."companies"
    WHERE "companies"."id" = "company_users"."company_id"
    AND "companies"."user_id" = ( SELECT "auth"."uid"() AS "uid")
  )
  OR
  -- 2. They are an owner of the company
  EXISTS (
    SELECT 1 FROM "public"."company_users" AS "cu"
    JOIN "public"."companies" ON "companies"."id" = "cu"."company_id"
    WHERE "cu"."company_id" = "company_users"."company_id"
    AND "cu"."user_id" = ( SELECT "auth"."uid"() AS "uid")
    AND "cu"."company_role" = 'owner'
  )
);

DROP POLICY IF EXISTS "Company users are insertable by company owners" ON "public"."company_users";
CREATE POLICY "Company users are insertable by company owners" ON "public"."company_users" 
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM "public"."company_users" AS "cu"
    WHERE "cu"."company_id" = "company_users"."company_id"
    AND "cu"."user_id" = ( SELECT "auth"."uid"() AS "uid")
    AND "cu"."company_role" = 'owner'
    AND "cu"."user_id" != "company_users"."user_id" -- Don't allow adding yourself as non-owner
  )
);

-- 5. 함수에서 created_by 참조 업데이트
-- get_user_campaigns_safe 함수는 이미 user_id를 사용하므로 변경 불필요
-- 하지만 campaigns 테이블의 필드명이 변경되었으므로 함수 내부에서 참조하는 부분 확인 필요

-- 참고: point_wallets 테이블의 owner_id는 owner_type에 따라 USER 또는 COMPANY를 가리키므로 변경하지 않음


-- ============================================================================
-- End of Migration: 20251030000002_unify_user_id_foreign_keys.sql
-- ============================================================================



-- ============================================================================
-- Migration: 20251030000003_update_campaigns_and_point_wallets.sql
-- ============================================================================

-- campaigns 테이블에 user_id 추가 (이미 created_by가 user_id로 변경되었으므로 확인)
-- point_wallets 테이블: owner_type → user_type, owner_id → user_id

-- 1. campaigns 테이블에 user_id가 있는지 확인하고 없으면 추가
DO $$
BEGIN
  -- user_id 컬럼이 없으면 추가
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'campaigns' 
    AND column_name = 'user_id'
  ) THEN
    -- created_by가 있으면 user_id로 변경, 없으면 추가
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'campaigns' 
      AND column_name = 'created_by'
    ) THEN
      ALTER TABLE "public"."campaigns" 
        RENAME COLUMN "created_by" TO "user_id";
    ELSE
      ALTER TABLE "public"."campaigns" 
        ADD COLUMN "user_id" uuid;
    END IF;
  END IF;
END $$;

-- 외래키 제약조건 확인 및 생성
ALTER TABLE "public"."campaigns"
  DROP CONSTRAINT IF EXISTS "campaigns_created_by_fkey";

ALTER TABLE "public"."campaigns"
  DROP CONSTRAINT IF EXISTS "campaigns_user_id_fkey";

ALTER TABLE "public"."campaigns"
  ADD CONSTRAINT "campaigns_user_id_fkey" 
  FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS "idx_campaigns_user_id" ON "public"."campaigns" USING "btree" ("user_id");

-- 2. point_wallets 테이블: owner_type → user_type, owner_id → user_id
-- 주의: owner_type이 'COMPANY'인 경우는 company_id를 저장하므로, 
-- 이 경우 user_type은 'COMPANY'로 유지하고 user_id에는 company_id를 저장

-- 먼저 컬럼명 변경
ALTER TABLE "public"."point_wallets" 
  RENAME COLUMN "owner_type" TO "user_type";

ALTER TABLE "public"."point_wallets" 
  RENAME COLUMN "owner_id" TO "user_id";

-- CHECK 제약조건 업데이트
ALTER TABLE "public"."point_wallets"
  DROP CONSTRAINT IF EXISTS "point_wallets_owner_type_check";

ALTER TABLE "public"."point_wallets"
  ADD CONSTRAINT "point_wallets_user_type_check" 
  CHECK (("user_type" = ANY (ARRAY['USER'::"text", 'COMPANY'::"text"])));

-- 인덱스 이름 변경
DROP INDEX IF EXISTS "public"."idx_point_wallets_owner";
CREATE INDEX IF NOT EXISTS "idx_point_wallets_user" ON "public"."point_wallets" USING "btree" ("user_type", "user_id");

-- 3. 함수에서 owner_type, owner_id 참조 업데이트
-- get_user_wallets 함수
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
      'user_type', pw.user_type,
      'user_id', pw.user_id,
      'current_points', pw.current_points,
      'created_at', pw.created_at,
      'updated_at', pw.updated_at
    )
  ) INTO v_wallets
  FROM public.point_wallets pw
  WHERE pw.user_type = 'USER' AND pw.user_id = p_user_id;
  
  RETURN COALESCE(v_wallets, '[]'::jsonb);
END;
$$;

-- get_wallet_info 함수
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
      (pw.user_type = 'USER' AND pw.user_id = (select auth.uid())) OR
      (pw.user_type = 'COMPANY' AND pw.user_id IN (
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
    'user_type', pw.user_type,
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

-- get_wallet_logs 함수
CREATE OR REPLACE FUNCTION "public"."get_wallet_logs"(
  "p_wallet_id" "uuid", 
  "p_limit" integer DEFAULT 50, 
  "p_offset" integer DEFAULT 0
) RETURNS "jsonb"
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
      (pw.user_type = 'USER' AND pw.user_id = (select auth.uid())) OR
      (pw.user_type = 'COMPANY' AND pw.user_id IN (
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

-- earn_points 함수
CREATE OR REPLACE FUNCTION "public"."earn_points"(
  "p_user_id" "uuid", 
  "p_amount" integer, 
  "p_description" "text", 
  "p_related_entity_type" "text" DEFAULT NULL::"text", 
  "p_related_entity_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
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
  
  -- 사용자 지갑 찾기
  SELECT id, current_points INTO v_wallet_id, v_current_points
  FROM public.point_wallets
  WHERE user_type = 'USER' AND user_id = p_user_id
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

-- spend_points_safe 함수
CREATE OR REPLACE FUNCTION "public"."spend_points_safe"(
  "p_user_id" "uuid", 
  "p_amount" integer, 
  "p_description" "text", 
  "p_related_entity_type" "text" DEFAULT NULL::"text", 
  "p_related_entity_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
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
  
  -- 지갑 찾기
  SELECT id, current_points INTO v_wallet_id, v_current_points
  FROM public.point_wallets
  WHERE user_type = 'USER' AND user_id = p_user_id
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

-- request_point_charge_safe 함수
CREATE OR REPLACE FUNCTION "public"."request_point_charge_safe"(
  "p_user_id" "uuid", 
  "p_amount" integer, 
  "p_payment_method" "text"
) RETURNS "jsonb"
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

-- get_user_wallet_safe 함수
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
  WHERE wallets.user_type = 'USER' AND wallets.user_id = p_user_id
  LIMIT 1;
  
  IF v_wallet IS NULL THEN
    RAISE EXCEPTION 'Wallet not found';
  END IF;
  
  RETURN v_wallet;
END;
$$;

-- get_user_point_logs_safe 함수
CREATE OR REPLACE FUNCTION "public"."get_user_point_logs_safe"(
  "p_user_id" "uuid", 
  "p_transaction_type" "text" DEFAULT 'all'::"text", 
  "p_limit" integer DEFAULT 50, 
  "p_offset" integer DEFAULT 0
) RETURNS "jsonb"
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
  WHERE user_type = 'USER' AND user_id = p_user_id
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

-- create_user_profile_safe 함수에서 포인트 지갑 생성 부분 업데이트
CREATE OR REPLACE FUNCTION "public"."create_user_profile_safe"(
  "p_user_id" "uuid", 
  "p_display_name" "text", 
  "p_user_type" "text" DEFAULT 'user'::"text"
) RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$ 
DECLARE 
  v_profile jsonb; 
  v_current_user_type text; 
  v_user_exists boolean;
BEGIN 
  -- 이미 프로필이 존재하는지 확인
  SELECT EXISTS(SELECT 1 FROM public.users WHERE id = p_user_id) INTO v_user_exists;
  
  IF v_user_exists THEN
    -- 프로필이 이미 존재하면 해당 프로필 반환
    SELECT to_jsonb(users.*) INTO v_profile
    FROM public.users 
    WHERE id = p_user_id;
    RETURN v_profile;
  END IF;
  
  -- 현재 사용자 타입 조회 (관리자 권한 확인용)
  BEGIN
    SELECT user_type INTO v_current_user_type 
    FROM public.users 
    WHERE id = (select auth.uid());
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_current_user_type := NULL;
  END;
  
  -- 권한 검증: 관리자만 admin 타입 설정 가능
  IF p_user_type = 'admin' AND 
     (v_current_user_type IS NULL OR v_current_user_type != 'admin') AND
     p_user_id != (select auth.uid()) THEN 
    RAISE EXCEPTION 'Only admins can create admin user types'; 
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
  
  -- 포인트 지갑이 없으면 생성 (중복 체크)
  IF NOT EXISTS (
    SELECT 1 FROM public.point_wallets 
    WHERE user_type = 'USER' AND user_id = p_user_id
  ) THEN
    INSERT INTO public.point_wallets ( 
      user_type, user_id, current_points, created_at, updated_at 
    ) VALUES ( 
      'USER', p_user_id, 0, NOW(), NOW() 
    ); 
  END IF;
  
  RETURN v_profile; 
END; 
$$;

-- 4. RLS 정책 업데이트
DROP POLICY IF EXISTS "Point wallets are insertable by authenticated users" ON "public"."point_wallets";
CREATE POLICY "Point wallets are insertable by authenticated users" ON "public"."point_wallets" 
FOR INSERT WITH CHECK (
  ("user_type" = 'USER'::"text") AND ("user_id" = ( SELECT "auth"."uid"() AS "uid"))
);

DROP POLICY IF EXISTS "Point wallets are updatable by owner" ON "public"."point_wallets";
CREATE POLICY "Point wallets are updatable by owner" ON "public"."point_wallets" 
FOR UPDATE USING (
  (
    ("user_type" = 'USER'::"text") AND ("user_id" = ( SELECT "auth"."uid"() AS "uid"))
  ) OR 
  (
    ("user_type" = 'COMPANY'::"text") AND ("user_id" IN (
      SELECT "company_users"."company_id"
      FROM "public"."company_users"
      WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid"))
    ))
  )
);

DROP POLICY IF EXISTS "Point wallets are viewable by owner" ON "public"."point_wallets";
CREATE POLICY "Point wallets are viewable by owner" ON "public"."point_wallets" 
FOR SELECT USING (
  (
    ("user_type" = 'USER'::"text") AND ("user_id" = ( SELECT "auth"."uid"() AS "uid"))
  ) OR 
  (
    ("user_type" = 'COMPANY'::"text") AND ("user_id" IN (
      SELECT "company_users"."company_id"
      FROM "public"."company_users"
      WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid"))
    ))
  )
);


-- ============================================================================
-- End of Migration: 20251030000003_update_campaigns_and_point_wallets.sql
-- ============================================================================



-- ============================================================================
-- Migration: 20251030000004_change_point_wallet_user_type_values.sql
-- ============================================================================

-- point_wallets 테이블의 user_type 값 변경: 'USER' → 'reviewer', 'COMPANY' → 'company'

-- 1. CHECK 제약조건 먼저 변경 (임시로 제약조건 제거)
ALTER TABLE "public"."point_wallets"
  DROP CONSTRAINT IF EXISTS "point_wallets_user_type_check";

-- 2. 기존 데이터 마이그레이션
UPDATE "public"."point_wallets" 
SET "user_type" = 'reviewer' 
WHERE "user_type" = 'USER';

UPDATE "public"."point_wallets" 
SET "user_type" = 'company' 
WHERE "user_type" = 'COMPANY';

-- 3. 새로운 CHECK 제약조건 추가
ALTER TABLE "public"."point_wallets"
  ADD CONSTRAINT "point_wallets_user_type_check" 
  CHECK (("user_type" = ANY (ARRAY['reviewer'::"text", 'company'::"text"])));

-- 3. 함수 업데이트: get_user_wallets
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
      'user_type', pw.user_type,
      'user_id', pw.user_id,
      'current_points', pw.current_points,
      'created_at', pw.created_at,
      'updated_at', pw.updated_at
    )
  ) INTO v_wallets
  FROM public.point_wallets pw
  WHERE pw.user_type = 'reviewer' AND pw.user_id = p_user_id;
  
  RETURN COALESCE(v_wallets, '[]'::jsonb);
END;
$$;

-- get_wallet_info 함수
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
      (pw.user_type = 'reviewer' AND pw.user_id = (select auth.uid())) OR
      (pw.user_type = 'company' AND pw.user_id IN (
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
    'user_type', pw.user_type,
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

-- get_wallet_logs 함수
CREATE OR REPLACE FUNCTION "public"."get_wallet_logs"(
  "p_wallet_id" "uuid", 
  "p_limit" integer DEFAULT 50, 
  "p_offset" integer DEFAULT 0
) RETURNS "jsonb"
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
      (pw.user_type = 'reviewer' AND pw.user_id = (select auth.uid())) OR
      (pw.user_type = 'company' AND pw.user_id IN (
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

-- earn_points 함수
CREATE OR REPLACE FUNCTION "public"."earn_points"(
  "p_user_id" "uuid", 
  "p_amount" integer, 
  "p_description" "text", 
  "p_related_entity_type" "text" DEFAULT NULL::"text", 
  "p_related_entity_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
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
  
  -- 사용자 지갑 찾기
  SELECT id, current_points INTO v_wallet_id, v_current_points
  FROM public.point_wallets
  WHERE user_type = 'reviewer' AND user_id = p_user_id
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

-- spend_points_safe 함수
CREATE OR REPLACE FUNCTION "public"."spend_points_safe"(
  "p_user_id" "uuid", 
  "p_amount" integer, 
  "p_description" "text", 
  "p_related_entity_type" "text" DEFAULT NULL::"text", 
  "p_related_entity_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
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
  
  -- 지갑 찾기
  SELECT id, current_points INTO v_wallet_id, v_current_points
  FROM public.point_wallets
  WHERE user_type = 'reviewer' AND user_id = p_user_id
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

-- get_user_wallet_safe 함수
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
  WHERE wallets.user_type = 'reviewer' AND wallets.user_id = p_user_id
  LIMIT 1;
  
  IF v_wallet IS NULL THEN
    RAISE EXCEPTION 'Wallet not found';
  END IF;
  
  RETURN v_wallet;
END;
$$;

-- get_user_point_logs_safe 함수
CREATE OR REPLACE FUNCTION "public"."get_user_point_logs_safe"(
  "p_user_id" "uuid", 
  "p_transaction_type" "text" DEFAULT 'all'::"text", 
  "p_limit" integer DEFAULT 50, 
  "p_offset" integer DEFAULT 0
) RETURNS "jsonb"
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
  WHERE user_type = 'reviewer' AND user_id = p_user_id
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

-- create_user_profile_safe 함수
CREATE OR REPLACE FUNCTION "public"."create_user_profile_safe"(
  "p_user_id" "uuid", 
  "p_display_name" "text", 
  "p_user_type" "text" DEFAULT 'user'::"text"
) RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$ 
DECLARE 
  v_profile jsonb; 
  v_current_user_type text; 
  v_user_exists boolean;
BEGIN 
  -- 이미 프로필이 존재하는지 확인
  SELECT EXISTS(SELECT 1 FROM public.users WHERE id = p_user_id) INTO v_user_exists;
  
  IF v_user_exists THEN
    -- 프로필이 이미 존재하면 해당 프로필 반환
    SELECT to_jsonb(users.*) INTO v_profile
    FROM public.users 
    WHERE id = p_user_id;
    RETURN v_profile;
  END IF;
  
  -- 현재 사용자 타입 조회 (관리자 권한 확인용)
  BEGIN
    SELECT user_type INTO v_current_user_type 
    FROM public.users 
    WHERE id = (select auth.uid());
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_current_user_type := NULL;
  END;
  
  -- 권한 검증: 관리자만 admin 타입 설정 가능
  IF p_user_type = 'admin' AND 
     (v_current_user_type IS NULL OR v_current_user_type != 'admin') AND
     p_user_id != (select auth.uid()) THEN 
    RAISE EXCEPTION 'Only admins can create admin user types'; 
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
  
  -- 포인트 지갑이 없으면 생성 (중복 체크)
  IF NOT EXISTS (
    SELECT 1 FROM public.point_wallets 
    WHERE user_type = 'reviewer' AND user_id = p_user_id
  ) THEN
    INSERT INTO public.point_wallets ( 
      user_type, user_id, current_points, created_at, updated_at 
    ) VALUES ( 
      'reviewer', p_user_id, 0, NOW(), NOW() 
    ); 
  END IF;
  
  RETURN v_profile; 
END; 
$$;

-- 4. RLS 정책 업데이트
DROP POLICY IF EXISTS "Point wallets are insertable by authenticated users" ON "public"."point_wallets";
CREATE POLICY "Point wallets are insertable by authenticated users" ON "public"."point_wallets" 
FOR INSERT WITH CHECK (
  ("user_type" = 'reviewer'::"text") AND ("user_id" = ( SELECT "auth"."uid"() AS "uid"))
);

DROP POLICY IF EXISTS "Point wallets are updatable by owner" ON "public"."point_wallets";
CREATE POLICY "Point wallets are updatable by owner" ON "public"."point_wallets" 
FOR UPDATE USING (
  (
    ("user_type" = 'reviewer'::"text") AND ("user_id" = ( SELECT "auth"."uid"() AS "uid"))
  ) OR 
  (
    ("user_type" = 'company'::"text") AND ("user_id" IN (
      SELECT "company_users"."company_id"
      FROM "public"."company_users"
      WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid"))
    ))
  )
);

DROP POLICY IF EXISTS "Point wallets are viewable by owner" ON "public"."point_wallets";
CREATE POLICY "Point wallets are viewable by owner" ON "public"."point_wallets" 
FOR SELECT USING (
  (
    ("user_type" = 'reviewer'::"text") AND ("user_id" = ( SELECT "auth"."uid"() AS "uid"))
  ) OR 
  (
    ("user_type" = 'company'::"text") AND ("user_id" IN (
      SELECT "company_users"."company_id"
      FROM "public"."company_users"
      WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid"))
    ))
  )
);


-- ============================================================================
-- End of Migration: 20251030000004_change_point_wallet_user_type_values.sql
-- ============================================================================



-- ============================================================================
-- Migration: 20251030000005_rename_user_type_to_wallet_type.sql
-- ============================================================================

-- point_wallets 테이블의 user_type 필드명을 wallet_type으로 변경
-- 명확성을 위해: user_type은 사용자 타입(user/admin)을 의미하고,
-- wallet_type은 지갑 소유자 타입(reviewer/company)을 의미함

-- 1. 컬럼명 변경
ALTER TABLE "public"."point_wallets" 
  RENAME COLUMN "user_type" TO "wallet_type";

-- 2. CHECK 제약조건 이름 변경 (내용은 동일)
ALTER TABLE "public"."point_wallets"
  DROP CONSTRAINT IF EXISTS "point_wallets_user_type_check";

ALTER TABLE "public"."point_wallets"
  ADD CONSTRAINT "point_wallets_wallet_type_check" 
  CHECK (("wallet_type" = ANY (ARRAY['reviewer'::"text", 'company'::"text"])));

-- 3. 인덱스 이름 변경
DROP INDEX IF EXISTS "public"."idx_point_wallets_user";
CREATE INDEX IF NOT EXISTS "idx_point_wallets_wallet" ON "public"."point_wallets" USING "btree" ("wallet_type", "user_id");

-- 4. 함수 업데이트: get_user_wallets
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

-- get_wallet_info 함수
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

-- get_wallet_logs 함수
CREATE OR REPLACE FUNCTION "public"."get_wallet_logs"(
  "p_wallet_id" "uuid", 
  "p_limit" integer DEFAULT 50, 
  "p_offset" integer DEFAULT 0
) RETURNS "jsonb"
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

-- earn_points 함수
CREATE OR REPLACE FUNCTION "public"."earn_points"(
  "p_user_id" "uuid", 
  "p_amount" integer, 
  "p_description" "text", 
  "p_related_entity_type" "text" DEFAULT NULL::"text", 
  "p_related_entity_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
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
  
  -- 사용자 지갑 찾기
  SELECT id, current_points INTO v_wallet_id, v_current_points
  FROM public.point_wallets
  WHERE wallet_type = 'reviewer' AND user_id = p_user_id
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

-- spend_points_safe 함수
CREATE OR REPLACE FUNCTION "public"."spend_points_safe"(
  "p_user_id" "uuid", 
  "p_amount" integer, 
  "p_description" "text", 
  "p_related_entity_type" "text" DEFAULT NULL::"text", 
  "p_related_entity_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
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
  
  -- 지갑 찾기
  SELECT id, current_points INTO v_wallet_id, v_current_points
  FROM public.point_wallets
  WHERE wallet_type = 'reviewer' AND user_id = p_user_id
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

-- get_user_wallet_safe 함수
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

-- get_user_point_logs_safe 함수
CREATE OR REPLACE FUNCTION "public"."get_user_point_logs_safe"(
  "p_user_id" "uuid", 
  "p_transaction_type" "text" DEFAULT 'all'::"text", 
  "p_limit" integer DEFAULT 50, 
  "p_offset" integer DEFAULT 0
) RETURNS "jsonb"
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

-- create_user_profile_safe 함수
CREATE OR REPLACE FUNCTION "public"."create_user_profile_safe"(
  "p_user_id" "uuid", 
  "p_display_name" "text", 
  "p_user_type" "text" DEFAULT 'user'::"text"
) RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$ 
DECLARE 
  v_profile jsonb; 
  v_current_user_type text; 
  v_user_exists boolean;
BEGIN 
  -- 이미 프로필이 존재하는지 확인
  SELECT EXISTS(SELECT 1 FROM public.users WHERE id = p_user_id) INTO v_user_exists;
  
  IF v_user_exists THEN
    -- 프로필이 이미 존재하면 해당 프로필 반환
    SELECT to_jsonb(users.*) INTO v_profile
    FROM public.users 
    WHERE id = p_user_id;
    RETURN v_profile;
  END IF;
  
  -- 현재 사용자 타입 조회 (관리자 권한 확인용)
  BEGIN
    SELECT user_type INTO v_current_user_type 
    FROM public.users 
    WHERE id = (select auth.uid());
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_current_user_type := NULL;
  END;
  
  -- 권한 검증: 관리자만 admin 타입 설정 가능
  IF p_user_type = 'admin' AND 
     (v_current_user_type IS NULL OR v_current_user_type != 'admin') AND
     p_user_id != (select auth.uid()) THEN 
    RAISE EXCEPTION 'Only admins can create admin user types'; 
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
  
  -- 포인트 지갑이 없으면 생성 (중복 체크)
  IF NOT EXISTS (
    SELECT 1 FROM public.point_wallets 
    WHERE wallet_type = 'reviewer' AND user_id = p_user_id
  ) THEN
    INSERT INTO public.point_wallets ( 
      wallet_type, user_id, current_points, created_at, updated_at 
    ) VALUES ( 
      'reviewer', p_user_id, 0, NOW(), NOW() 
    ); 
  END IF;
  
  RETURN v_profile; 
END; 
$$;

-- 5. RLS 정책 업데이트
DROP POLICY IF EXISTS "Point wallets are insertable by authenticated users" ON "public"."point_wallets";
CREATE POLICY "Point wallets are insertable by authenticated users" ON "public"."point_wallets" 
FOR INSERT WITH CHECK (
  ("wallet_type" = 'reviewer'::"text") AND ("user_id" = ( SELECT "auth"."uid"() AS "uid"))
);

DROP POLICY IF EXISTS "Point wallets are updatable by owner" ON "public"."point_wallets";
CREATE POLICY "Point wallets are updatable by owner" ON "public"."point_wallets" 
FOR UPDATE USING (
  (
    ("wallet_type" = 'reviewer'::"text") AND ("user_id" = ( SELECT "auth"."uid"() AS "uid"))
  ) OR 
  (
    ("wallet_type" = 'company'::"text") AND ("user_id" IN (
      SELECT "company_users"."company_id"
      FROM "public"."company_users"
      WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid"))
    ))
  )
);

DROP POLICY IF EXISTS "Point wallets are viewable by owner" ON "public"."point_wallets";
CREATE POLICY "Point wallets are viewable by owner" ON "public"."point_wallets" 
FOR SELECT USING (
  (
    ("wallet_type" = 'reviewer'::"text") AND ("user_id" = ( SELECT "auth"."uid"() AS "uid"))
  ) OR 
  (
    ("wallet_type" = 'company'::"text") AND ("user_id" IN (
      SELECT "company_users"."company_id"
      FROM "public"."company_users"
      WHERE ("company_users"."user_id" = ( SELECT "auth"."uid"() AS "uid"))
    ))
  )
);


-- ============================================================================
-- End of Migration: 20251030000005_rename_user_type_to_wallet_type.sql
-- ============================================================================



-- ============================================================================
-- Migration: 20251030000006_add_user_id_foreign_key_to_companies.sql
-- ============================================================================

-- companies 테이블에 user_id 외래키 제약조건 추가 (확인 및 재생성)

-- 1. user_id 컬럼이 없으면 추가
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'companies' 
    AND column_name = 'user_id'
  ) THEN
    ALTER TABLE "public"."companies" 
      ADD COLUMN "user_id" uuid;
  END IF;
END $$;

-- 2. 기존 외래키 제약조건 확인 및 재생성
-- 기존 제약조건 제거 (있다면)
ALTER TABLE "public"."companies"
  DROP CONSTRAINT IF EXISTS "companies_created_by_fkey";

ALTER TABLE "public"."companies"
  DROP CONSTRAINT IF EXISTS "companies_user_id_fkey";

-- 외래키 제약조건 추가
ALTER TABLE "public"."companies"
  ADD CONSTRAINT "companies_user_id_fkey" 
  FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;

-- 3. 인덱스 확인 및 생성
CREATE INDEX IF NOT EXISTS "idx_companies_user_id" ON "public"."companies" USING "btree" ("user_id");

-- 4. 코멘트 추가 (명확성을 위해)
COMMENT ON COLUMN "public"."companies"."user_id" IS '회사를 등록한 사용자 ID (외래키: users.id)';


-- ============================================================================
-- End of Migration: 20251030000006_add_user_id_foreign_key_to_companies.sql
-- ============================================================================



-- ============================================================================
-- Migration: 20251030000007_rename_companies_name_to_business_name.sql
-- ============================================================================

-- companies 테이블의 name 필드를 business_name으로 변경

-- 1. 컬럼명 변경
ALTER TABLE "public"."companies" 
  RENAME COLUMN "name" TO "business_name";

-- 2. 인덱스 업데이트
DROP INDEX IF EXISTS "public"."idx_companies_name";
CREATE INDEX IF NOT EXISTS "idx_companies_business_name" 
ON "public"."companies" 
USING "gin" ("to_tsvector"('"english"'::"regconfig", "business_name"));

-- 3. 코멘트 추가 (명확성을 위해)
COMMENT ON COLUMN "public"."companies"."business_name" IS '상호명 (사업자등록증의 상호명)';


-- ============================================================================
-- End of Migration: 20251030000007_rename_companies_name_to_business_name.sql
-- ============================================================================



-- ============================================================================
-- Migration: 20251031000001_create_sns_platform_connections.sql
-- ============================================================================

-- SNS 플랫폼 연결 테이블 생성
-- 다계정 허용: 같은 사용자가 같은 플랫폼의 여러 계정 등록 가능
-- 스토어 플랫폼: 주소 필수 (쿠팡, 스마트스토어 등)
-- SNS 플랫폼: 주소 불필요 (블로그, 인스타그램 등)

-- 1. 테이블 생성
CREATE TABLE IF NOT EXISTS "public"."sns_platform_connections" (
    "id" uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    "user_id" uuid NOT NULL REFERENCES "public"."users"("id") ON DELETE CASCADE,
    
    -- 플랫폼 정보
    "platform" text NOT NULL, -- 'coupang', 'smartstore', '11st', 'gmarket', 'auction', 'wemakeprice', 'blog', 'instagram', 'youtube', 'tiktok', 'naver' 등
    "platform_account_id" text NOT NULL, -- 플랫폼 내 계정 ID
    "platform_account_name" text NOT NULL, -- 플랫폼 내 표시 이름
    
    -- 연락처 정보
    "phone" text NOT NULL,
    
    -- 주소 정보 (스토어 플랫폼만 필수, 애플리케이션 레벨에서 검증)
    "address" text,
    
    -- 다계정 허용: 같은 사용자가 같은 플랫폼의 다른 계정을 여러 개 등록 가능
    -- 단, 같은 계정 ID는 중복 방지
    CONSTRAINT "sns_platform_connections_unique_user_platform_account" 
        UNIQUE ("user_id", "platform", "platform_account_id"),
    
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

-- 2. 인덱스 생성
CREATE INDEX IF NOT EXISTS "idx_sns_platform_connections_user_id" 
    ON "public"."sns_platform_connections"("user_id");

CREATE INDEX IF NOT EXISTS "idx_sns_platform_connections_platform" 
    ON "public"."sns_platform_connections"("platform");

CREATE INDEX IF NOT EXISTS "idx_sns_platform_connections_user_platform" 
    ON "public"."sns_platform_connections"("user_id", "platform");

-- 3. 코멘트 추가
COMMENT ON TABLE "public"."sns_platform_connections" IS 'SNS 플랫폼 연결 정보 (다계정 허용)';
COMMENT ON COLUMN "public"."sns_platform_connections"."platform" IS '플랫폼 이름 (coupang, smartstore, blog, instagram 등)';
COMMENT ON COLUMN "public"."sns_platform_connections"."platform_account_id" IS '플랫폼 내 계정 ID';
COMMENT ON COLUMN "public"."sns_platform_connections"."platform_account_name" IS '플랫폼 내 표시 이름';
COMMENT ON COLUMN "public"."sns_platform_connections"."address" IS '주소 (스토어 플랫폼만 필수, SNS 플랫폼은 NULL)';

-- 4. RLS 활성화
ALTER TABLE "public"."sns_platform_connections" ENABLE ROW LEVEL SECURITY;

-- 5. RLS 정책 생성
-- 사용자는 자신의 SNS 연결만 조회 가능
CREATE POLICY "Users can view their own SNS connections"
    ON "public"."sns_platform_connections"
    FOR SELECT
    TO authenticated
    USING (auth.uid() = "user_id");

-- 사용자는 자신의 SNS 연결만 생성 가능
CREATE POLICY "Users can create their own SNS connections"
    ON "public"."sns_platform_connections"
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = "user_id");

-- 사용자는 자신의 SNS 연결만 수정 가능
CREATE POLICY "Users can update their own SNS connections"
    ON "public"."sns_platform_connections"
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = "user_id")
    WITH CHECK (auth.uid() = "user_id");

-- 사용자는 자신의 SNS 연결만 삭제 가능
CREATE POLICY "Users can delete their own SNS connections"
    ON "public"."sns_platform_connections"
    FOR DELETE
    TO authenticated
    USING (auth.uid() = "user_id");

-- 6. 권한 설정
GRANT ALL ON TABLE "public"."sns_platform_connections" TO "authenticated";
GRANT ALL ON TABLE "public"."sns_platform_connections" TO "service_role";

-- 7. 트리거 함수: updated_at 자동 업데이트
CREATE OR REPLACE FUNCTION "public"."update_sns_platform_connections_updated_at"()
RETURNS TRIGGER
LANGUAGE "plpgsql"
AS $$
BEGIN
    NEW."updated_at" = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER "set_sns_platform_connections_updated_at"
    BEFORE UPDATE ON "public"."sns_platform_connections"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."update_sns_platform_connections_updated_at"();

-- 8. RPC 함수: SNS 플랫폼 연결 생성 (트랜잭션 포함)
CREATE OR REPLACE FUNCTION "public"."create_sns_platform_connection"(
    "p_user_id" uuid,
    "p_platform" text,
    "p_platform_account_id" text,
    "p_platform_account_name" text,
    "p_phone" text,
    "p_address" text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE "plpgsql"
SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
    v_store_platforms text[] := ARRAY['coupang', 'smartstore', '11st', 'gmarket', 'auction', 'wemakeprice'];
    v_result jsonb;
BEGIN
    -- 트랜잭션 시작 (함수 내부는 자동으로 트랜잭션)
    
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
        SELECT 1 FROM "public"."sns_platform_connections"
        WHERE "user_id" = "p_user_id"
          AND "platform" = "p_platform"
          AND "platform_account_id" = "p_platform_account_id"
    ) THEN
        RAISE EXCEPTION '이미 등록된 계정입니다';
    END IF;
    
    -- 4. SNS 연결 생성
    INSERT INTO "public"."sns_platform_connections" (
        "user_id",
        "platform",
        "platform_account_id",
        "platform_account_name",
        "phone",
        "address"
    ) VALUES (
        "p_user_id",
        "p_platform",
        "p_platform_account_id",
        "p_platform_account_name",
        "p_phone",
        CASE 
            WHEN "p_platform" = ANY(v_store_platforms) THEN "p_address"
            ELSE NULL -- SNS 플랫폼은 주소 무시
        END
    )
    RETURNING jsonb_build_object(
        'id', "id",
        'platform', "platform",
        'platform_account_id', "platform_account_id",
        'platform_account_name', "platform_account_name",
        'phone', "phone",
        'address', "address",
        'created_at', "created_at"
    ) INTO v_result;
    
    -- 5. 성공 응답 반환
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

-- 9. RPC 함수: SNS 플랫폼 연결 수정 (트랜잭션 포함)
CREATE OR REPLACE FUNCTION "public"."update_sns_platform_connection"(
    "p_id" uuid,
    "p_user_id" uuid,
    "p_platform_account_name" text DEFAULT NULL,
    "p_phone" text DEFAULT NULL,
    "p_address" text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE "plpgsql"
SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
    v_store_platforms text[] := ARRAY['coupang', 'smartstore', '11st', 'gmarket', 'auction', 'wemakeprice'];
    v_platform text;
    v_result jsonb;
BEGIN
    -- 플랫폼 확인
    SELECT "platform" INTO v_platform
    FROM "public"."sns_platform_connections"
    WHERE "id" = "p_id" AND "user_id" = "p_user_id";
    
    IF v_platform IS NULL THEN
        RAISE EXCEPTION 'SNS 연결을 찾을 수 없습니다';
    END IF;
    
    -- 스토어 플랫폼 주소 필수 검증
    IF v_platform = ANY(v_store_platforms) AND 
       ("p_address" IS NULL OR "p_address" = '') AND
       NOT EXISTS (
           SELECT 1 FROM "public"."sns_platform_connections"
           WHERE "id" = "p_id" AND "address" IS NOT NULL AND "address" != ''
       ) THEN
        RAISE EXCEPTION '스토어 플랫폼은 주소가 필수입니다';
    END IF;
    
    -- 업데이트
    UPDATE "public"."sns_platform_connections"
    SET
        "platform_account_name" = COALESCE("p_platform_account_name", "platform_account_name"),
        "phone" = COALESCE("p_phone", "phone"),
        "address" = CASE 
            WHEN v_platform = ANY(v_store_platforms) THEN COALESCE("p_address", "address")
            ELSE NULL -- SNS 플랫폼은 주소 제거
        END,
        "updated_at" = now()
    WHERE "id" = "p_id" AND "user_id" = "p_user_id"
    RETURNING jsonb_build_object(
        'id', "id",
        'platform', "platform",
        'platform_account_id', "platform_account_id",
        'platform_account_name', "platform_account_name",
        'phone', "phone",
        'address', "address",
        'updated_at', "updated_at"
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RAISE EXCEPTION 'SNS 연결을 찾을 수 없습니다';
    END IF;
    
    RETURN jsonb_build_object('success', true, 'data', v_result);
END;
$$;

-- 10. RPC 함수: SNS 플랫폼 연결 삭제 (트랜잭션 포함)
CREATE OR REPLACE FUNCTION "public"."delete_sns_platform_connection"(
    "p_id" uuid,
    "p_user_id" uuid
)
RETURNS jsonb
LANGUAGE "plpgsql"
SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
    v_deleted_id uuid;
BEGIN
    DELETE FROM "public"."sns_platform_connections"
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

-- 11. RPC 함수 권한 설정
GRANT EXECUTE ON FUNCTION "public"."create_sns_platform_connection" TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."update_sns_platform_connection" TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."delete_sns_platform_connection" TO "authenticated";


-- ============================================================================
-- End of Migration: 20251031000001_create_sns_platform_connections.sql
-- ============================================================================



-- ============================================================================
-- Migration: 20251031000002_rename_sns_table_and_add_return_address.sql
-- ============================================================================

-- 테이블 이름 변경 및 회수 주소 필드 추가
-- 1. 기존 테이블 이름 변경
ALTER TABLE "public"."sns_platform_connections" RENAME TO "sns_connections";

-- 2. 제약 조건 이름 변경
ALTER TABLE "public"."sns_connections" 
    RENAME CONSTRAINT "sns_platform_connections_unique_user_platform_account" 
    TO "sns_connections_unique_user_platform_account";

-- 3. 인덱스 이름 변경
ALTER INDEX "idx_sns_platform_connections_user_id" RENAME TO "idx_sns_connections_user_id";
ALTER INDEX "idx_sns_platform_connections_platform" RENAME TO "idx_sns_connections_platform";
ALTER INDEX "idx_sns_platform_connections_user_platform" RENAME TO "idx_sns_connections_user_platform";

-- 4. 회수 주소 필드 추가
ALTER TABLE "public"."sns_connections" 
    ADD COLUMN "return_address" text;

COMMENT ON COLUMN "public"."sns_connections"."return_address" IS '회수 주소 (선택 사항)';

-- 5. 코멘트 업데이트
COMMENT ON TABLE "public"."sns_connections" IS 'SNS 플랫폼 연결 정보 (다계정 허용)';

-- 6. RLS 정책은 테이블 이름 변경 시 자동으로 적용되므로 이름 변경 불필요

-- 7. 트리거 함수 이름 변경 및 업데이트
DROP TRIGGER IF EXISTS "set_sns_platform_connections_updated_at" ON "public"."sns_connections";
CREATE OR REPLACE FUNCTION "public"."update_sns_connections_updated_at"()
RETURNS TRIGGER
LANGUAGE "plpgsql"
AS $$
BEGIN
    NEW."updated_at" = now();
    RETURN NEW;
END;
$$;
CREATE TRIGGER "set_sns_connections_updated_at"
    BEFORE UPDATE ON "public"."sns_connections"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."update_sns_connections_updated_at"();

-- 8. RPC 함수 업데이트: create_sns_platform_connection -> create_sns_connection
CREATE OR REPLACE FUNCTION "public"."create_sns_connection"(
    "p_user_id" uuid,
    "p_platform" text,
    "p_platform_account_id" text,
    "p_platform_account_name" text,
    "p_phone" text,
    "p_address" text DEFAULT NULL,
    "p_return_address" text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE "plpgsql"
SECURITY DEFINER
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

-- 9. RPC 함수 업데이트: update_sns_platform_connection -> update_sns_connection
CREATE OR REPLACE FUNCTION "public"."update_sns_connection"(
    "p_id" uuid,
    "p_user_id" uuid,
    "p_platform_account_name" text DEFAULT NULL,
    "p_phone" text DEFAULT NULL,
    "p_address" text DEFAULT NULL,
    "p_return_address" text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE "plpgsql"
SECURITY DEFINER
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

-- 10. RPC 함수 업데이트: delete_sns_platform_connection -> delete_sns_connection
CREATE OR REPLACE FUNCTION "public"."delete_sns_connection"(
    "p_id" uuid,
    "p_user_id" uuid
)
RETURNS jsonb
LANGUAGE "plpgsql"
SECURITY DEFINER
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

-- 11. RPC 함수 권한 설정
GRANT EXECUTE ON FUNCTION "public"."create_sns_connection" TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."update_sns_connection" TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."delete_sns_connection" TO "authenticated";

-- 12. 기존 함수 삭제 (선택사항)
DROP FUNCTION IF EXISTS "public"."create_sns_platform_connection"(uuid, text, text, text, text, text);
DROP FUNCTION IF EXISTS "public"."update_sns_platform_connection"(uuid, uuid, text, text, text);
DROP FUNCTION IF EXISTS "public"."delete_sns_platform_connection"(uuid, uuid);


-- ============================================================================
-- End of Migration: 20251031000002_rename_sns_table_and_add_return_address.sql
-- ============================================================================



-- ============================================================================
-- Migration: 20250102000001_add_transactions_and_cleanup_orphaned_users.sql
-- ============================================================================

-- ============================================================================
-- 통합 마이그레이션: 트랜잭션 적용 및 orphaned users 정리
-- 날짜: 2025-01-02
-- 목적: 
--   1. 모든 데이터베이스 함수에 트랜잭션 적용하여 원자성 보장
--   2. orphaned users 정리 (auth.users에 없는 public.users 레코드 삭제)
-- ============================================================================

-- ============================================================================
-- PART 1: 데이터베이스 함수에 트랜잭션 적용
-- ============================================================================

-- 1. create_user_profile_safe 함수: 트랜잭션으로 감싸기 및 버그 수정
-- 수정 사항:
--   - 프로필이 이미 존재하면 포인트 월렛을 생성하지 않음
--   - 프로필이 새로 생성된 경우에만 포인트 월렛 생성
--   - 중복 생성 방지 로직 명확화
CREATE OR REPLACE FUNCTION "public"."create_user_profile_safe"(
  "p_user_id" "uuid", 
  "p_display_name" "text", 
  "p_user_type" "text" DEFAULT 'user'::"text"
) RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$ 
DECLARE 
  v_profile jsonb; 
  v_current_user_type text; 
  v_user_exists boolean;
BEGIN 
  -- 이미 프로필이 존재하는지 확인
  SELECT EXISTS(SELECT 1 FROM public.users WHERE id = p_user_id) INTO v_user_exists;
  
  IF v_user_exists THEN
    -- 프로필이 이미 존재하면 해당 프로필 반환 (포인트 월렛 생성하지 않음)
    SELECT to_jsonb(users.*) INTO v_profile
    FROM public.users 
    WHERE id = p_user_id;
    RETURN v_profile;
  END IF;
  
  -- 현재 사용자 타입 조회 (관리자 권한 확인용)
  BEGIN
    SELECT user_type INTO v_current_user_type 
    FROM public.users 
    WHERE id = (select auth.uid());
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_current_user_type := NULL;
  END;
  
  -- 권한 검증: 관리자만 admin 타입 설정 가능
  IF p_user_type = 'admin' AND 
     (v_current_user_type IS NULL OR v_current_user_type != 'admin') AND
     p_user_id != (select auth.uid()) THEN 
    RAISE EXCEPTION 'Only admins can create admin user types'; 
  END IF; 
  
  -- 트랜잭션: 프로필이 없을 때만 생성
  BEGIN
    -- 사용자 프로필 생성 (프로필이 없을 때만 실행됨)
    -- ON CONFLICT는 방어적 코드로만 사용 (이미 위에서 체크했지만)
    INSERT INTO public.users ( 
      id, display_name, user_type, created_at, updated_at 
    ) VALUES ( 
      p_user_id, p_display_name, p_user_type, NOW(), NOW() 
    )
    ON CONFLICT (id) DO UPDATE SET
      display_name = EXCLUDED.display_name,
      updated_at = NOW()
    RETURNING to_jsonb(users.*) INTO v_profile;
    
    -- INSERT가 실제로 실행되었는지 확인 (프로필이 새로 생성된 경우)
    -- 프로필이 새로 생성된 경우에만 포인트 월렛 생성
    IF v_profile IS NOT NULL THEN
      -- 포인트 지갑이 없으면 생성 (중복 체크)
      -- 프로필이 새로 생성된 경우에만 포인트 월렛 생성
      IF NOT EXISTS (
        SELECT 1 FROM public.point_wallets 
        WHERE wallet_type = 'reviewer' AND user_id = p_user_id
      ) THEN
        INSERT INTO public.point_wallets ( 
          wallet_type, user_id, current_points, created_at, updated_at 
        ) VALUES ( 
          'reviewer', p_user_id, 0, NOW(), NOW() 
        );
      END IF;
    END IF;
    
    -- 모든 작업이 성공하면 프로필 반환
    RETURN v_profile;
    
  EXCEPTION
    WHEN OTHERS THEN
      -- 에러 발생 시 자동으로 롤백됨 (함수 내부의 EXCEPTION 블록)
      -- 에러를 상위로 전파하여 호출자가 처리할 수 있도록 함
      RAISE;
  END;
END; 
$$;

-- 2. earn_points 함수: 트랜잭션으로 감싸기 (기존 반환 형식 유지)
CREATE OR REPLACE FUNCTION "public"."earn_points"(
  "p_user_id" "uuid", 
  "p_amount" integer, 
  "p_description" "text", 
  "p_related_entity_type" "text" DEFAULT NULL::"text", 
  "p_related_entity_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
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

-- 3. spend_points_safe 함수: 트랜잭션으로 감싸기 (기존 반환 형식 유지)
CREATE OR REPLACE FUNCTION "public"."spend_points_safe"(
  "p_user_id" "uuid", 
  "p_amount" integer, 
  "p_description" "text", 
  "p_related_entity_type" "text" DEFAULT NULL::"text", 
  "p_related_entity_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
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

-- 4. update_user_profile_safe 함수: 트랜잭션으로 감싸기
CREATE OR REPLACE FUNCTION "public"."update_user_profile_safe"(
  "p_user_id" "uuid", 
  "p_display_name" "text" DEFAULT NULL::"text", 
  "p_company_id" "uuid" DEFAULT NULL::"uuid"
) RETURNS "jsonb"
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
  
  -- 트랜잭션 시작: 프로필 업데이트를 원자적으로 처리
  BEGIN
    -- 현재 사용자 타입 조회
    SELECT user_type INTO v_current_user_type
    FROM public.users 
    WHERE id = p_user_id;
    
    IF v_current_user_type IS NULL THEN
      RAISE EXCEPTION 'User profile not found';
    END IF;
    
    -- company_id 변경 권한 검증 (관리자만 가능)
    IF p_company_id IS NOT NULL AND 
       v_current_user_type NOT IN ('admin', 'ADMIN', 'owner', 'OWNER') THEN
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
    
  EXCEPTION
    WHEN OTHERS THEN
      -- 에러 발생 시 자동으로 롤백됨
      RAISE;
  END;
END;
$$;

-- 5. admin_change_user_role 함수: 트랜잭션으로 감싸기
CREATE OR REPLACE FUNCTION "public"."admin_change_user_role"(
  "p_target_user_id" "uuid", 
  "p_new_role" "text"
) RETURNS "jsonb"
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

-- 코멘트 추가: 트랜잭션 보장
COMMENT ON FUNCTION "public"."create_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_user_type" "text") IS 
'사용자 프로필과 포인트 지갑을 원자적으로 생성합니다. 에러 발생 시 모든 작업이 롤백됩니다.';

COMMENT ON FUNCTION "public"."earn_points"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") IS 
'포인트 적립과 로그 생성을 원자적으로 처리합니다. 에러 발생 시 모든 작업이 롤백됩니다.';

COMMENT ON FUNCTION "public"."spend_points_safe"("p_user_id" "uuid", "p_amount" integer, "p_description" "text", "p_related_entity_type" "text", "p_related_entity_id" "uuid") IS 
'포인트 사용과 로그 생성을 원자적으로 처리합니다. 에러 발생 시 모든 작업이 롤백됩니다.';

COMMENT ON FUNCTION "public"."update_user_profile_safe"("p_user_id" "uuid", "p_display_name" "text", "p_company_id" "uuid") IS 
'사용자 프로필 업데이트를 원자적으로 처리합니다. 에러 발생 시 모든 작업이 롤백됩니다.';

COMMENT ON FUNCTION "public"."admin_change_user_role"("p_target_user_id" "uuid", "p_new_role" "text") IS 
'사용자 권한 변경을 원자적으로 처리합니다. 에러 발생 시 모든 작업이 롤백됩니다.';

-- ============================================================================
-- PART 2: orphaned users 정리
-- ============================================================================

-- orphaned users와 관련된 데이터 삭제
-- auth.users에 없는 public.users 레코드(orphaned records)를 삭제합니다.
-- 주의: 이 스크립트는 마이그레이션 후 정리용으로 사용됩니다.

-- 1. 관련 데이터 먼저 삭제
-- point_wallets 테이블: owner_id 또는 user_id 컬럼 지원 (마이그레이션 순서에 따라 다름)
DO $$
DECLARE
  v_orphaned_user_ids uuid[];
BEGIN
  -- orphaned user ID 목록 수집
  SELECT ARRAY_AGG(u.id) INTO v_orphaned_user_ids
  FROM public.users u 
  LEFT JOIN auth.users au ON u.id = au.id 
  WHERE au.id IS NULL;
  
  -- point_wallets 삭제 (owner_id 또는 user_id 컬럼 지원)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'point_wallets' 
    AND column_name = 'user_id'
  ) THEN
    -- user_id 컬럼 사용 (최신 스키마)
    DELETE FROM public.point_wallets 
    WHERE user_id = ANY(v_orphaned_user_ids);
  ELSIF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'point_wallets' 
    AND column_name = 'owner_id'
  ) THEN
    -- owner_id 컬럼 사용 (초기 스키마)
    DELETE FROM public.point_wallets 
    WHERE owner_id = ANY(v_orphaned_user_ids)
    AND owner_type = 'USER';
  END IF;
END $$;

-- company_users 삭제
DELETE FROM public.company_users 
WHERE user_id IN (
    SELECT u.id 
    FROM public.users u 
    LEFT JOIN auth.users au ON u.id = au.id 
    WHERE au.id IS NULL
);

-- sns_connections 삭제 (테이블이 존재하는 경우)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'sns_connections'
  ) THEN
    DELETE FROM public.sns_connections 
    WHERE user_id IN (
        SELECT u.id 
        FROM public.users u 
        LEFT JOIN auth.users au ON u.id = au.id 
        WHERE au.id IS NULL
    );
  END IF;
END $$;

-- 2. orphaned users 삭제
DELETE FROM public.users 
WHERE id IN (
    SELECT u.id 
    FROM public.users u 
    LEFT JOIN auth.users au ON u.id = au.id 
    WHERE au.id IS NULL
);

-- 3. 결과 확인 (선택사항 - 주석 처리 가능)
-- SELECT 
--     (SELECT COUNT(*) FROM auth.users) as auth_users_count,
--     (SELECT COUNT(*) FROM public.users) as public_users_count,
--     (SELECT COUNT(*) FROM public.users u LEFT JOIN auth.users au ON u.id = au.id WHERE au.id IS NULL) as orphaned_users_count;


-- ============================================================================
-- End of Migration: 20250102000001_add_transactions_and_cleanup_orphaned_users.sql
-- ============================================================================


-- ============================================================================
-- Migration: 20250102000002_create_register_company_rpc.sql
-- ============================================================================

-- 회사 정보 저장 RPC 함수 (중복 체크 및 트랜잭션 포함)
CREATE OR REPLACE FUNCTION "public"."register_company"(
  "p_user_id" "uuid",
  "p_business_name" "text",
  "p_business_number" "text",
  "p_address" "text",
  "p_representative_name" "text",
  "p_business_type" "text",
  "p_registration_file_url" "text"
) RETURNS "jsonb"
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

-- 회사 정보 삭제 RPC 함수 (롤백용)
CREATE OR REPLACE FUNCTION "public"."delete_company"(
  "p_company_id" "uuid"
) RETURNS "jsonb"
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

-- RPC 함수 권한 부여
GRANT EXECUTE ON FUNCTION "public"."register_company" TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."delete_company" TO "authenticated";

-- ============================================================================
-- End of Migration: 20250102000002_create_register_company_rpc.sql
-- ============================================================================


-- ============================================================================
-- Migration: 20250102000004_add_status_to_company_users.sql
-- ============================================================================

-- status 필드 추가 (기본값: 'active')
ALTER TABLE "public"."company_users"
  ADD COLUMN IF NOT EXISTS "status" text DEFAULT 'active' NOT NULL;

-- status 값 제약 조건 추가 (active, inactive, pending, suspended)
ALTER TABLE "public"."company_users"
  DROP CONSTRAINT IF EXISTS "company_users_status_check";

ALTER TABLE "public"."company_users"
  ADD CONSTRAINT "company_users_status_check" 
  CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'pending'::"text", 'suspended'::"text"])));

-- 기존 레코드의 status를 'active'로 설정 (NULL인 경우 대비)
UPDATE "public"."company_users"
SET "status" = 'active'
WHERE "status" IS NULL;

-- 코멘트 추가
COMMENT ON COLUMN "public"."company_users"."status" IS '회사-사용자 관계 상태: active(활성), inactive(비활성), pending(대기), suspended(정지)';

-- ============================================================================
-- End of Migration: 20250102000004_add_status_to_company_users.sql
-- ============================================================================


-- ============================================================================
-- Migration: 20250102000005_fix_update_user_profile_safe.sql
-- ============================================================================

-- 기존 함수들 삭제 (모든 오버로딩 버전)
DROP FUNCTION IF EXISTS "public"."update_user_profile_safe"("uuid", "text", "uuid");
DROP FUNCTION IF EXISTS "public"."update_user_profile_safe"("uuid", "text");

-- update_user_profile_safe 함수 재생성 (company_id 제거)
CREATE OR REPLACE FUNCTION "public"."update_user_profile_safe"(
  "p_user_id" "uuid",
  "p_display_name" "text" DEFAULT NULL::"text"
) RETURNS "jsonb"
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

-- 함수 권한 부여
GRANT EXECUTE ON FUNCTION "public"."update_user_profile_safe"("uuid", "text") TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."update_user_profile_safe"("uuid", "text") TO "anon";
GRANT EXECUTE ON FUNCTION "public"."update_user_profile_safe"("uuid", "text") TO "service_role";

-- ============================================================================
-- End of Migration: 20250102000005_fix_update_user_profile_safe.sql
-- ============================================================================


-- ============================================================================
-- Migration: 20250102000006_add_status_to_users_and_redesign_deleted_users.sql
-- ============================================================================

-- Step 1: Add status field to users table
ALTER TABLE "public"."users"
  ADD COLUMN IF NOT EXISTS "status" text DEFAULT 'active' NOT NULL;

ALTER TABLE "public"."users"
  DROP CONSTRAINT IF EXISTS "users_status_check";

ALTER TABLE "public"."users"
  ADD CONSTRAINT "users_status_check" 
  CHECK (status IN ('active', 'inactive', 'pending_deletion', 'deleted', 'suspended'));

-- Update existing users to 'active' if not set
UPDATE "public"."users"
SET status = 'active'
WHERE status IS NULL;

-- Create partial index for active users
CREATE INDEX IF NOT EXISTS "idx_users_status_active" 
ON "public"."users" ("id") 
WHERE "status" = 'active';

-- Step 2: Backup existing deleted_users data
CREATE TEMP TABLE IF NOT EXISTS "temp_deleted_users" AS
SELECT 
    id as user_id,
    deletion_reason,
    deleted_at
FROM "public"."deleted_users"
WHERE EXISTS (
    SELECT 1 FROM "public"."users" u WHERE u.id = "public"."deleted_users".id
);

-- Step 3: Update users.status for existing deleted users
UPDATE "public"."users" u
SET status = 'deleted', updated_at = NOW()
WHERE EXISTS (
    SELECT 1 FROM "temp_deleted_users" tdu 
    WHERE tdu.user_id = u.id
);

-- Step 4: Drop and recreate deleted_users table with FK
DROP TABLE IF EXISTS "public"."deleted_users" CASCADE;

CREATE TABLE "public"."deleted_users" (
    "user_id" uuid NOT NULL PRIMARY KEY,
    "deletion_reason" text,
    "deleted_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "deleted_users_user_id_fkey" 
        FOREIGN KEY ("user_id") 
        REFERENCES "public"."users"("id") 
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

ALTER TABLE "public"."deleted_users" OWNER TO "postgres";

-- Step 5: Migrate existing deleted_users data
INSERT INTO "public"."deleted_users" ("user_id", "deletion_reason", "deleted_at")
SELECT 
    user_id,
    deletion_reason,
    deleted_at
FROM "temp_deleted_users"
ON CONFLICT ("user_id") DO NOTHING;

-- Step 6: Create indexes
CREATE INDEX IF NOT EXISTS "idx_deleted_users_deleted_at" 
ON "public"."deleted_users" ("deleted_at");

-- Step 7: Grant permissions
GRANT ALL ON TABLE "public"."deleted_users" TO "anon";
GRANT ALL ON TABLE "public"."deleted_users" TO "authenticated";
GRANT ALL ON TABLE "public"."deleted_users" TO "service_role";

-- Step 8: Enable RLS
ALTER TABLE "public"."deleted_users" ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- End of Migration: 20250102000006_add_status_to_users_and_redesign_deleted_users.sql
-- ============================================================================


-- ============================================================================
-- Migration: 20250102000007_create_request_manager_role_rpc.sql
-- ============================================================================

-- 매니저 등록 요청 RPC 함수
CREATE OR REPLACE FUNCTION "public"."request_manager_role"(
  "p_business_name" "text",
  "p_business_number" "text"
) RETURNS "jsonb"
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

-- RPC 함수 권한 부여
GRANT EXECUTE ON FUNCTION "public"."request_manager_role"("p_business_name" "text", "p_business_number" "text") TO "authenticated";

-- ============================================================================
-- End of Migration: 20250102000007_create_request_manager_role_rpc.sql
-- ============================================================================


-- ============================================================================
-- Migration: 20250102000008_update_rls_policies_for_company_users_status.sql
-- ============================================================================

-- Point logs 정책 업데이트
DROP POLICY IF EXISTS "Point logs are viewable by wallet owner" ON "public"."point_logs";
CREATE POLICY "Point logs are viewable by wallet owner" ON "public"."point_logs" FOR SELECT USING ((
  "wallet_id" IN (
    SELECT "point_wallets"."id"
    FROM "public"."point_wallets"
    WHERE (
      (("point_wallets"."wallet_type" = 'reviewer'::"text") AND ("point_wallets"."user_id" = (SELECT auth.uid())))
      OR
      (("point_wallets"."wallet_type" = 'company'::"text") AND ("point_wallets"."user_id" IN (
        SELECT "company_users"."company_id"
        FROM "public"."company_users"
        WHERE (
          "company_users"."user_id" = (SELECT auth.uid())
          AND "company_users"."status" = 'active'::text
        )
      )))
    )
  )
));

-- Point wallets 업데이트 정책
DROP POLICY IF EXISTS "Point wallets are updatable by owner" ON "public"."point_wallets";
CREATE POLICY "Point wallets are updatable by owner" ON "public"."point_wallets" FOR UPDATE USING ((
  (("wallet_type" = 'reviewer'::"text") AND ("user_id" = (SELECT auth.uid())))
  OR
  (("wallet_type" = 'company'::"text") AND ("user_id" IN (
    SELECT "company_users"."company_id"
    FROM "public"."company_users"
    WHERE (
      "company_users"."user_id" = (SELECT auth.uid())
      AND "company_users"."status" = 'active'::text
    )
  )))
));

-- Point wallets 조회 정책
DROP POLICY IF EXISTS "Point wallets are viewable by owner" ON "public"."point_wallets";
CREATE POLICY "Point wallets are viewable by owner" ON "public"."point_wallets" FOR SELECT USING ((
  (("wallet_type" = 'reviewer'::"text") AND ("user_id" = (SELECT auth.uid())))
  OR
  (("wallet_type" = 'company'::"text") AND ("user_id" IN (
    SELECT "company_users"."company_id"
    FROM "public"."company_users"
    WHERE (
      "company_users"."user_id" = (SELECT auth.uid())
      AND "company_users"."status" = 'active'::text
    )
  )))
));

-- Companies 업데이트 정책
DROP POLICY IF EXISTS "Companies are updatable by owners" ON "public"."companies";
CREATE POLICY "Companies are updatable by owners" ON "public"."companies" FOR UPDATE USING ((
  EXISTS (
    SELECT 1
    FROM "public"."company_users"
    WHERE (
      "company_users"."company_id" = "companies"."id"
      AND "company_users"."user_id" = (SELECT auth.uid())
      AND "company_users"."company_role" = 'owner'::text
      AND "company_users"."status" = 'active'::text
    )
  )
));

-- Company users 삽입 정책
DROP POLICY IF EXISTS "Company users are insertable by company owners" ON "public"."company_users";
CREATE POLICY "Company users are insertable by company owners" ON "public"."company_users" FOR INSERT WITH CHECK ((
  EXISTS (
    SELECT 1
    FROM "public"."company_users" AS "cu"
    WHERE (
      "cu"."company_id" = "company_users"."company_id"
      AND "cu"."user_id" = (SELECT auth.uid())
      AND "cu"."company_role" = 'owner'::text
      AND "cu"."status" = 'active'::text
    )
  )
));

-- ============================================================================
-- End of Migration: 20250102000008_update_rls_policies_for_company_users_status.sql
-- ============================================================================


-- ============================================================================
-- Migration: 20250102000009_update_get_user_profile_safe_with_company_role.sql
-- ============================================================================

-- get_user_profile_safe 함수 업데이트 (company_users 테이블과 조인)
CREATE OR REPLACE FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") 
RETURNS "jsonb"
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

-- RPC 함수 권한 부여
GRANT EXECUTE ON FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") TO "anon";
GRANT EXECUTE ON FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."get_user_profile_safe"("p_user_id" "uuid") TO "service_role";

-- ============================================================================
-- End of Migration: 20250102000009_update_get_user_profile_safe_with_company_role.sql
-- ============================================================================


-- ============================================================================
-- Migration: 20250102000010_get_manager_list_with_email.sql
-- ============================================================================

-- 회사의 매니저 목록 조회 (이메일 포함)
CREATE OR REPLACE FUNCTION "public"."get_company_managers"("p_company_id" "uuid")
RETURNS TABLE (
  "id" uuid,
  "user_id" uuid,
  "status" text,
  "created_at" timestamp with time zone,
  "email" character varying(255),
  "display_name" text
)
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
    cu.id,
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

-- RPC 함수 권한 부여
GRANT EXECUTE ON FUNCTION "public"."get_company_managers"("p_company_id" "uuid") TO "anon";
GRANT EXECUTE ON FUNCTION "public"."get_company_managers"("p_company_id" "uuid") TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."get_company_managers"("p_company_id" "uuid") TO "service_role";

-- ============================================================================
-- End of Migration: 20250102000010_get_manager_list_with_email.sql
-- ============================================================================


-- ============================================================================
-- Migration: 20250102000011_remove_manager_request_attempts_table.sql
-- ============================================================================

-- RPC 함수 업데이트 (manager_request_attempts 관련 로직 제거)
CREATE OR REPLACE FUNCTION "public"."request_manager_role"(
  "p_business_name" "text",
  "p_business_number" "text"
) RETURNS "jsonb"
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

-- 테이블 삭제
DROP TABLE IF EXISTS "public"."manager_request_attempts" CASCADE;

-- ============================================================================
-- End of Migration: 20250102000011_remove_manager_request_attempts_table.sql
-- ============================================================================


-- ============================================================================
-- Migration: 20250102000012_add_rejected_status_to_company_users.sql
-- ============================================================================

-- status check constraint에 'rejected' 추가
ALTER TABLE "public"."company_users"
  DROP CONSTRAINT IF EXISTS "company_users_status_check";

ALTER TABLE "public"."company_users"
  ADD CONSTRAINT "company_users_status_check" 
  CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'pending'::"text", 'suspended'::"text", 'rejected'::"text"])));

-- 코멘트 업데이트
COMMENT ON COLUMN "public"."company_users"."status" IS '회사-사용자 관계 상태: active(활성), inactive(비활성), pending(대기), suspended(정지), rejected(거절)';

-- ============================================================================
-- End of Migration: 20250102000012_add_rejected_status_to_company_users.sql
-- ============================================================================


-- ============================================================================
-- Migration: 20250102000013_add_update_policy_for_company_users.sql
-- ============================================================================

-- Company users 업데이트 정책 추가
DROP POLICY IF EXISTS "Company users are updatable by company owners" ON "public"."company_users";
CREATE POLICY "Company users are updatable by company owners" 
ON "public"."company_users" 
FOR UPDATE 
USING (
  EXISTS (
    SELECT 1
    FROM "public"."company_users" AS "cu"
    WHERE (
      "cu"."company_id" = "company_users"."company_id"
      AND "cu"."user_id" = (SELECT auth.uid())
      AND "cu"."company_role" IN ('owner', 'manager')
      AND "cu"."status" = 'active'::text
    )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM "public"."company_users" AS "cu"
    WHERE (
      "cu"."company_id" = "company_users"."company_id"
      AND "cu"."user_id" = (SELECT auth.uid())
      AND "cu"."company_role" IN ('owner', 'manager')
      AND "cu"."status" = 'active'::text
    )
  )
);

-- ============================================================================
-- End of Migration: 20250102000013_add_update_policy_for_company_users.sql
-- ============================================================================


-- ============================================================================
-- Migration: 20250102000014_create_approve_reject_manager_rpc.sql
-- ============================================================================

-- 매니저 승인 RPC 함수
CREATE OR REPLACE FUNCTION "public"."approve_manager"("p_company_user_id" "uuid")
RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
  v_company_id uuid;
  v_result jsonb;
BEGIN
  -- company_user_id로 company_id 조회
  SELECT company_id INTO v_company_id
  FROM public.company_users
  WHERE id = p_company_user_id;
  
  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'Company user not found';
  END IF;
  
  -- 권한 확인: 회사 소유자 또는 활성 매니저만 승인 가능
  IF NOT EXISTS (
    SELECT 1 FROM public.company_users cu
    WHERE cu.company_id = v_company_id
      AND cu.user_id = (SELECT auth.uid())
      AND cu.company_role IN ('owner', 'manager')
      AND cu.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Only company owners and active managers can approve managers';
  END IF;
  
  -- status를 'active'로 업데이트
  UPDATE public.company_users
  SET status = 'active'
  WHERE id = p_company_user_id
    AND status = 'pending'
    AND company_role = 'manager';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Manager request not found or already processed';
  END IF;
  
  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'company_user_id', p_company_user_id,
    'status', 'active'
  ) INTO v_result;
  
  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$$;

-- 매니저 거절 RPC 함수
CREATE OR REPLACE FUNCTION "public"."reject_manager"("p_company_user_id" "uuid")
RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
  v_company_id uuid;
  v_result jsonb;
BEGIN
  -- company_user_id로 company_id 조회
  SELECT company_id INTO v_company_id
  FROM public.company_users
  WHERE id = p_company_user_id;
  
  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'Company user not found';
  END IF;
  
  -- 권한 확인: 회사 소유자 또는 활성 매니저만 거절 가능
  IF NOT EXISTS (
    SELECT 1 FROM public.company_users cu
    WHERE cu.company_id = v_company_id
      AND cu.user_id = (SELECT auth.uid())
      AND cu.company_role IN ('owner', 'manager')
      AND cu.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Only company owners and active managers can reject managers';
  END IF;
  
  -- status를 'rejected'로 업데이트
  UPDATE public.company_users
  SET status = 'rejected'
  WHERE id = p_company_user_id
    AND status = 'pending'
    AND company_role = 'manager';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Manager request not found or already processed';
  END IF;
  
  -- 결과 반환
  SELECT jsonb_build_object(
    'success', true,
    'company_user_id', p_company_user_id,
    'status', 'rejected'
  ) INTO v_result;
  
  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$$;

-- RPC 함수 권한 부여
GRANT EXECUTE ON FUNCTION "public"."approve_manager"("p_company_user_id" "uuid") TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."reject_manager"("p_company_user_id" "uuid") TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."approve_manager"("p_company_user_id" "uuid") TO "service_role";
GRANT EXECUTE ON FUNCTION "public"."reject_manager"("p_company_user_id" "uuid") TO "service_role";

-- ============================================================================
-- End of Migration: 20250102000014_create_approve_reject_manager_rpc.sql
-- ============================================================================


-- ============================================================================
-- Migration: 20250102000015_fix_create_user_profile_safe_duplicate.sql
-- ============================================================================
-- Note: create_user_profile_safe 함수는 이미 위에서 최신 버전으로 수정되었으므로
-- 여기서는 주석으로 표시만 합니다. (실제 함수는 5292줄에서 이미 수정됨)

-- ============================================================================
-- End of Migration: 20250102000015_fix_create_user_profile_safe_duplicate.sql
-- ============================================================================


