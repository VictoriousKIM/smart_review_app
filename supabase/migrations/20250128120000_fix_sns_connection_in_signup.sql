-- SNS 연결 회원가입 문제 수정
-- 문제: create_reviewer_profile_with_company 함수에서 SNS 연결 생성 시
--       PERFORM 명령을 사용하여 결과를 확인할 수 없고, 에러가 조용히 무시됨
-- 해결: SELECT ... INTO를 사용하여 결과를 추적하고, 반환값에 포함

CREATE OR REPLACE FUNCTION create_reviewer_profile_with_company(
  p_user_id UUID,
  p_display_name TEXT,
  p_phone TEXT,
  p_address TEXT DEFAULT NULL,
  p_company_id UUID DEFAULT NULL,
  p_sns_connections JSONB DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_profile_id UUID;
  v_result JSONB;
  v_sns_success_count INT := 0;
  v_sns_failed_count INT := 0;
  v_sns_errors JSONB := '[]'::JSONB;
  v_sns_result JSONB;
BEGIN
  -- 트랜잭션 시작 (자동)
  
  -- 1. 프로필 생성
  INSERT INTO public.users (
    id,
    display_name,
    user_type,
    phone,
    address,
    created_at,
    updated_at
  ) VALUES (
    p_user_id,
    p_display_name,
    'user',
    p_phone,
    p_address,
    NOW(),
    NOW()
  ) RETURNING id INTO v_profile_id;
  
  -- 2. 지갑 생성 (트리거로 자동)
  
  -- 3. SNS 연결 생성 (결과 추적)
  IF p_sns_connections IS NOT NULL AND jsonb_array_length(p_sns_connections) > 0 THEN
    FOR i IN 0..jsonb_array_length(p_sns_connections) - 1 LOOP
      DECLARE
        v_conn JSONB := p_sns_connections->i;
        v_platform TEXT := v_conn->>'platform';
        v_account_id TEXT := v_conn->>'platform_account_id';
        v_account_name TEXT := v_conn->>'platform_account_name';
        v_phone TEXT := v_conn->>'phone';
        v_address TEXT := v_conn->>'address';
        v_return_address TEXT := v_conn->>'return_address';
        v_error_text TEXT;
      BEGIN
        -- create_sns_connection 호출 및 결과 저장
        -- PERFORM 대신 SELECT ... INTO를 사용하여 결과를 확인할 수 있도록 수정
        SELECT create_sns_connection(
          p_user_id,
          v_platform,
          v_account_id,
          v_account_name,
          v_phone,
          v_address,
          v_return_address
        ) INTO v_sns_result;
        
        -- 성공 카운트 증가
        v_sns_success_count := v_sns_success_count + 1;
        
        -- 디버깅을 위한 로그 (선택적)
        RAISE NOTICE 'SNS 연결 생성 성공: 플랫폼=%, 계정ID=%', v_platform, v_account_id;
      EXCEPTION
        WHEN OTHERS THEN
          -- 실패 카운트 증가 및 에러 메시지 저장
          v_sns_failed_count := v_sns_failed_count + 1;
          v_error_text := SQLERRM;
          v_sns_errors := v_sns_errors || jsonb_build_object(
            'platform', COALESCE(v_platform, 'unknown'),
            'account_id', COALESCE(v_account_id, 'unknown'),
            'error', v_error_text
          );
          -- WARNING도 남기기
          RAISE WARNING 'SNS 연결 생성 실패 (플랫폼: %, 계정: %): %', 
            COALESCE(v_platform, 'unknown'), 
            COALESCE(v_account_id, 'unknown'), 
            v_error_text;
      END;
    END LOOP;
  END IF;
  
  -- 4. 회사 연결 (선택)
  IF p_company_id IS NOT NULL THEN
    -- 중복 체크
    IF NOT EXISTS (
      SELECT 1 FROM public.company_users
      WHERE company_id = p_company_id AND user_id = p_user_id
    ) THEN
      INSERT INTO public.company_users (
        company_id,
        user_id,
        company_role,
        status,
        created_at,
        updated_at
      ) VALUES (
        p_company_id,
        p_user_id,
        'reviewer',
        'active',
        NOW(),
        NOW()
      );
    END IF;
  END IF;
  
  -- 트랜잭션 커밋 (자동)
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_profile_id,
    'company_id', p_company_id,
    'sns_connections', jsonb_build_object(
      'success', v_sns_success_count,
      'failed', v_sns_failed_count,
      'errors', v_sns_errors
    )
  );
EXCEPTION
  WHEN OTHERS THEN
    -- 트랜잭션 롤백 (자동)
    RAISE EXCEPTION '리뷰어 회원가입 실패: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION create_reviewer_profile_with_company(
  UUID, TEXT, TEXT, TEXT, UUID, JSONB
) IS '리뷰어 프로필, SNS 연결, 회사 연결을 트랜잭션으로 생성합니다. SNS 연결 결과를 추적하여 반환합니다.';

