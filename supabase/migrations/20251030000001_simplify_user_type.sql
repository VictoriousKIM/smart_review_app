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

