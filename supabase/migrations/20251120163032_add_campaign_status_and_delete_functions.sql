-- 마이그레이션: 캠페인 상태 업데이트 및 삭제 RPC 함수 추가
-- 날짜: 2025-11-20
-- 설명: 
--   1. 캠페인 상태 업데이트 함수 (update_campaign_status)
--   2. 캠페인 삭제 함수 (delete_campaign) - 소프트 삭제

-- 캠페인 상태 업데이트 함수
CREATE OR REPLACE FUNCTION update_campaign_status(
  p_campaign_id UUID,
  p_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
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

-- 캠페인 삭제 함수 (소프트 삭제)
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

  -- 3. 캠페인 소유권 및 참여자 수 확인
  SELECT company_id, current_participants
  INTO v_campaign_company_id, v_current_participants
  FROM public.campaigns
  WHERE id = p_campaign_id;

  IF v_campaign_company_id IS NULL THEN
    RAISE EXCEPTION '캠페인을 찾을 수 없습니다';
  END IF;

  IF v_campaign_company_id != v_company_id THEN
    RAISE EXCEPTION '이 캠페인을 삭제할 권한이 없습니다';
  END IF;

  -- 4. 참여자 수 확인
  IF v_current_participants > 0 THEN
    RAISE EXCEPTION '참여자가 있는 캠페인은 삭제할 수 없습니다';
  END IF;

  -- 5. 소프트 삭제 (status를 inactive로 변경)
  UPDATE public.campaigns
  SET status = 'inactive',
      updated_at = NOW()
  WHERE id = p_campaign_id;

  RETURN jsonb_build_object(
    'success', true,
    'campaign_id', p_campaign_id,
    'message', '캠페인이 삭제되었습니다'
  );
END;
$$;

COMMENT ON FUNCTION update_campaign_status IS '캠페인 상태 업데이트 (active/inactive)';
COMMENT ON FUNCTION delete_campaign IS '캠페인 삭제 (소프트 삭제 - 참여자가 없을 때만 가능)';

