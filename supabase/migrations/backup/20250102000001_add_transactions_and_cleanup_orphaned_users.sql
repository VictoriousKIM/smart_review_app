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

-- 1. create_user_profile_safe 함수: 트랜잭션으로 감싸기
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
  
  -- 트랜잭션 시작: 모든 작업이 원자적으로 실행됨
  -- PostgreSQL 함수는 자동으로 트랜잭션 블록 안에서 실행되지만,
  -- 명시적으로 EXCEPTION 핸들링을 강화하여 에러 발생 시 롤백 보장
  
  BEGIN
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

