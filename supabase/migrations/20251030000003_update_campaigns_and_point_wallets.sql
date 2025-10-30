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

