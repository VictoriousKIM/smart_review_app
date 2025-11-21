-- 마이그레이션: delete_campaign 제약 조건 강제 재적용
-- 날짜: 2025-11-21
-- 설명: 제약 조건을 강제로 재적용하여 refund 타입이 제대로 작동하도록 함

-- 1. transaction_type_check 제약 조건 강제 재적용
ALTER TABLE public.point_transactions
  DROP CONSTRAINT IF EXISTS point_transactions_transaction_type_check;

ALTER TABLE public.point_transactions
  ADD CONSTRAINT point_transactions_transaction_type_check 
  CHECK (transaction_type = ANY (ARRAY['earn'::text, 'spend'::text, 'refund'::text]));

-- 2. campaign_check 제약 조건 강제 재적용
ALTER TABLE public.point_transactions
  DROP CONSTRAINT IF EXISTS point_transactions_campaign_check;

ALTER TABLE public.point_transactions
  ADD CONSTRAINT point_transactions_campaign_check 
  CHECK (
    (transaction_type <> 'spend'::text) OR 
    ((transaction_type = 'spend'::text) AND (campaign_id IS NOT NULL))
  );

-- 3. delete_campaign 함수 재생성 (campaign_id NULL 처리 확인)
DROP FUNCTION IF EXISTS public.delete_campaign(UUID);

CREATE OR REPLACE FUNCTION delete_campaign(
  p_campaign_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
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

COMMENT ON FUNCTION delete_campaign IS '캠페인 하드 삭제 (inactive 상태이고 참여자가 없을 때만 가능, 포인트 환불 포함, 생성한 매니저만 삭제 가능, refund 타입 campaign_id NULL 처리)';

