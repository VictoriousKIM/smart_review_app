-- ============================================================================
-- 캠페인 기능 및 company_users 테이블 구조 재설계 마이그레이션
-- 생성일: 2025-11-03
-- ============================================================================
-- PART 1: 캠페인 기능 데이터베이스 구조 재설계 (Hybrid Model)
-- PART 2: company_users 테이블 구조 최적화
-- ============================================================================

-- ============================================================================
-- PART 1-1: campaigns 테이블에 completed_applicants_count 컬럼 추가
-- ============================================================================
ALTER TABLE "public"."campaigns"
  ADD COLUMN IF NOT EXISTS "completed_applicants_count" integer DEFAULT 0 NOT NULL;

COMMENT ON COLUMN "public"."campaigns"."completed_applicants_count" IS '캠페인 완료자 수 (성능 최적화를 위한 캐시 컬럼)';

-- ============================================================================
-- PART 1-2: campaign_logs를 campaign_events로 테이블 이름 변경
-- ============================================================================
-- 주의: completed_applicants_count 업데이트는 테이블 이름 변경 후에 수행됩니다.

-- 1. 외래 키 및 제약조건을 임시로 저장 (나중에 재생성)
-- 2. 테이블 이름 변경
ALTER TABLE "public"."campaign_logs" RENAME TO "campaign_events";

-- 3. 인덱스 이름 변경
ALTER INDEX IF EXISTS "idx_campaign_logs_action" RENAME TO "idx_campaign_events_action";
ALTER INDEX IF EXISTS "idx_campaign_logs_campaign_id" RENAME TO "idx_campaign_events_campaign_id";
ALTER INDEX IF EXISTS "idx_campaign_logs_campaign_user" RENAME TO "idx_campaign_events_campaign_user";
ALTER INDEX IF EXISTS "idx_campaign_logs_created_at" RENAME TO "idx_campaign_events_created_at";
ALTER INDEX IF EXISTS "idx_campaign_logs_status" RENAME TO "idx_campaign_events_status";
ALTER INDEX IF EXISTS "idx_campaign_logs_user_id" RENAME TO "idx_campaign_events_user_id";

-- 4. 제약조건 이름 변경
ALTER TABLE "public"."campaign_events" 
  RENAME CONSTRAINT "campaign_logs_pkey" TO "campaign_events_pkey";
ALTER TABLE "public"."campaign_events"
  RENAME CONSTRAINT "campaign_logs_action_check" TO "campaign_events_action_check";
ALTER TABLE "public"."campaign_events"
  RENAME CONSTRAINT "campaign_logs_status_check" TO "campaign_events_status_check";

-- 5. 외래 키 제약조건 이름 변경
ALTER TABLE "public"."campaign_events"
  RENAME CONSTRAINT "campaign_logs_campaign_id_fkey" TO "campaign_events_campaign_id_fkey";
ALTER TABLE "public"."campaign_events"
  RENAME CONSTRAINT "campaign_logs_user_id_fkey" TO "campaign_events_user_id_fkey";

-- 6. action 컬럼에 새로운 값 추가 ('시작', '진행상황_저장', '완료' 등)
ALTER TABLE "public"."campaign_events"
  DROP CONSTRAINT IF EXISTS "campaign_events_action_check";

ALTER TABLE "public"."campaign_events"
  ADD CONSTRAINT "campaign_events_action_check" 
  CHECK (("action" = ANY (ARRAY[
    'join'::text, 
    'leave'::text, 
    'complete'::text, 
    'cancel'::text,
    '시작'::text,
    '진행상황_저장'::text,
    '완료'::text
  ])));

-- 7. id 컬럼은 이벤트 기록부이므로 유지 (각 이벤트는 고유한 id 필요)

-- ============================================================================
-- PART 1-3: campaign_user_status 테이블 신규 생성
-- ============================================================================

CREATE TABLE IF NOT EXISTS "public"."campaign_user_status" (
  "campaign_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "current_action" text NOT NULL,
  "last_updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  
  -- 복합 기본 키 설정
  CONSTRAINT "campaign_user_status_pkey" PRIMARY KEY ("campaign_id", "user_id"),
  
  -- 외래 키 설정
  CONSTRAINT "campaign_user_status_campaign_id_fkey" 
    FOREIGN KEY ("campaign_id") 
    REFERENCES "public"."campaigns"("id") 
    ON DELETE CASCADE,
    
  CONSTRAINT "campaign_user_status_user_id_fkey" 
    FOREIGN KEY ("user_id") 
    REFERENCES "public"."users"("id") 
    ON DELETE CASCADE,
    
  -- action 값 제약 조건
  CONSTRAINT "campaign_user_status_action_check" 
    CHECK (("current_action" = ANY (ARRAY[
      'join'::text, 
      'leave'::text, 
      'complete'::text, 
      'cancel'::text,
      '시작'::text,
      '진행상황_저장'::text,
      '완료'::text
    ])))
);

ALTER TABLE "public"."campaign_user_status" OWNER TO "postgres";

COMMENT ON TABLE "public"."campaign_user_status" IS '사용자의 캠페인별 현재 상태 요약 테이블 (빠른 조회용)';
COMMENT ON COLUMN "public"."campaign_user_status"."campaign_id" IS '캠페인 ID';
COMMENT ON COLUMN "public"."campaign_user_status"."user_id" IS '사용자 ID';
COMMENT ON COLUMN "public"."campaign_user_status"."current_action" IS '현재 행동 상태';
COMMENT ON COLUMN "public"."campaign_user_status"."last_updated_at" IS '마지막 업데이트 시간';

-- 인덱스 생성
CREATE INDEX "idx_campaign_user_status_campaign_id" 
  ON "public"."campaign_user_status" USING btree ("campaign_id");

CREATE INDEX "idx_campaign_user_status_user_id" 
  ON "public"."campaign_user_status" USING btree ("user_id");

CREATE INDEX "idx_campaign_user_status_current_action" 
  ON "public"."campaign_user_status" USING btree ("current_action");

CREATE INDEX "idx_campaign_user_status_last_updated_at" 
  ON "public"."campaign_user_status" USING btree ("last_updated_at");

-- RLS 활성화
ALTER TABLE "public"."campaign_user_status" ENABLE ROW LEVEL SECURITY;

-- 기존 데이터 마이그레이션: campaign_events에서 완료된 사용자 수 계산하여 campaigns 업데이트
UPDATE "public"."campaigns" c
SET "completed_applicants_count" = (
  SELECT COUNT(DISTINCT ce."user_id")
  FROM "public"."campaign_events" ce
  WHERE ce."campaign_id" = c."id"
    AND ce."action" = 'complete'
    AND ce."status" = 'completed'
);

-- 초기 데이터 마이그레이션: campaign_events에서 최신 상태를 campaign_user_status로 마이그레이션
INSERT INTO "public"."campaign_user_status" ("campaign_id", "user_id", "current_action", "last_updated_at", "created_at")
SELECT DISTINCT ON ("campaign_id", "user_id")
  "campaign_id",
  "user_id",
  "action" as "current_action",
  "created_at" as "last_updated_at",
  MIN("created_at") OVER (PARTITION BY "campaign_id", "user_id") as "created_at"
FROM "public"."campaign_events"
ORDER BY "campaign_id", "user_id", "created_at" DESC
ON CONFLICT ("campaign_id", "user_id") DO NOTHING;

-- ============================================================================
-- PART 1-4: campaign_events INSERT 트리거 및 자동 업데이트 함수 생성
-- ============================================================================

-- 함수 생성: campaign_events에 INSERT 시 자동으로 campaign_user_status와 campaigns 업데이트
CREATE OR REPLACE FUNCTION "public"."sync_campaign_user_status_on_event"()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
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

COMMENT ON FUNCTION "public"."sync_campaign_user_status_on_event"() IS 
'campaign_events 테이블에 새 이벤트가 INSERT될 때 campaign_user_status와 campaigns.completed_applicants_count를 자동으로 동기화합니다.';

-- 트리거 생성 (INSERT만 - 이벤트는 INSERT만 가능)
DROP TRIGGER IF EXISTS "trigger_sync_campaign_user_status" ON "public"."campaign_events";

CREATE TRIGGER "trigger_sync_campaign_user_status"
  AFTER INSERT ON "public"."campaign_events"
  FOR EACH ROW
  EXECUTE FUNCTION "public"."sync_campaign_user_status_on_event"();

-- 참고: campaign_events는 이벤트 기록부이므로 UPDATE는 허용하지 않습니다.
-- 하지만 기존 데이터 호환성을 위해 UPDATE 트리거도 추가 (나중에 제거 가능)

-- ============================================================================
-- PART 1-5: RLS 정책 업데이트 (campaign_logs -> campaign_events)
-- ============================================================================

-- 기존 정책 삭제
DROP POLICY IF EXISTS "Campaign logs are insertable by authenticated users" ON "public"."campaign_events";
DROP POLICY IF EXISTS "Campaign logs are updatable by participants and company" ON "public"."campaign_events";
DROP POLICY IF EXISTS "Campaign logs are viewable by participants and company" ON "public"."campaign_events";

-- 새로운 정책 생성 (campaign_events는 이벤트 기록부이므로 UPDATE는 제한)
CREATE POLICY "Campaign events are insertable by authenticated users" 
  ON "public"."campaign_events" 
  FOR INSERT 
  WITH CHECK (
    ("user_id" = (SELECT auth.uid())) 
    OR 
    ("campaign_id" IN (
      SELECT "campaigns"."id"
      FROM "public"."campaigns"
      WHERE "campaigns"."company_id" IN (
        SELECT "company_users"."company_id"
        FROM "public"."company_users"
        WHERE "company_users"."user_id" = (SELECT auth.uid())
      )
    ))
  );

CREATE POLICY "Campaign events are viewable by participants and company" 
  ON "public"."campaign_events" 
  FOR SELECT 
  USING (
    ("user_id" = (SELECT auth.uid())) 
    OR 
    ("campaign_id" IN (
      SELECT "campaigns"."id"
      FROM "public"."campaigns"
      WHERE "campaigns"."company_id" IN (
        SELECT "company_users"."company_id"
        FROM "public"."company_users"
        WHERE "company_users"."user_id" = (SELECT auth.uid())
          AND "company_users"."status" = 'active'
      )
    ))
  );

-- campaign_user_status 정책 생성
CREATE POLICY "Campaign user status is viewable by participants and company" 
  ON "public"."campaign_user_status" 
  FOR SELECT 
  USING (
    ("user_id" = (SELECT auth.uid())) 
    OR 
    ("campaign_id" IN (
      SELECT "campaigns"."id"
      FROM "public"."campaigns"
      WHERE "campaigns"."company_id" IN (
        SELECT "company_users"."company_id"
        FROM "public"."company_users"
        WHERE "company_users"."user_id" = (SELECT auth.uid())
          AND "company_users"."status" = 'active'
      )
    ))
  );

-- ============================================================================
-- PART 2: company_users 테이블 구조 최적화 (복합 기본 키 적용)
-- ============================================================================

-- PART 2-1: 기존 데이터 보존을 위한 임시 컬럼 확인 및 외래 키 정리
-- 주의: id 컬럼을 참조하는 다른 테이블이 있는지 확인 필요

-- 1. company_users를 참조하는 다른 테이블이나 함수가 있는지 확인
-- (현재 코드베이스에서는 외부 참조가 없는 것으로 보임)

-- 2. 기존 기본 키 제거 전에 복합 기본 키 생성
-- 먼저 UNIQUE 제약조건 추가 (중복 방지)
ALTER TABLE "public"."company_users"
  ADD CONSTRAINT "company_users_unique_company_user" 
  UNIQUE ("company_id", "user_id");

-- 3. 기존 기본 키(id) 제거
-- 외래 키 의존성을 먼저 제거
ALTER TABLE "public"."company_users"
  DROP CONSTRAINT IF EXISTS "company_users_pkey";

-- 4. 복합 기본 키 설정
ALTER TABLE "public"."company_users"
  ADD CONSTRAINT "company_users_pkey" 
  PRIMARY KEY ("company_id", "user_id");

-- 5. id 컬럼 제거
ALTER TABLE "public"."company_users"
  DROP COLUMN IF EXISTS "id";

-- 6. UNIQUE 제약조건 제거 (이미 기본 키가 됨)
ALTER TABLE "public"."company_users"
  DROP CONSTRAINT IF EXISTS "company_users_unique_company_user";

COMMENT ON TABLE "public"."company_users" IS 
'회사-사용자 관계 테이블 (복합 기본 키: company_id + user_id). 한 사용자는 한 회사에 대해 하나의 역할만 가질 수 있습니다.';

-- ============================================================================
-- PART 2-2: 함수 업데이트 - company_users의 id 참조를 복합 키로 변경
-- ============================================================================

-- 1. get_company_managers 함수 업데이트
-- 반환값에서 id 제거하고 company_id와 user_id를 별도로 반환
-- 먼저 기존 함수 삭제 (반환 타입 변경을 위해)
DROP FUNCTION IF EXISTS "public"."get_company_managers"("p_company_id" "uuid");

CREATE FUNCTION "public"."get_company_managers"("p_company_id" "uuid")
RETURNS TABLE (
  "company_id" uuid,
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

COMMENT ON FUNCTION "public"."get_company_managers"("p_company_id" "uuid") IS 
'회사 매니저 목록 조회 (company_users의 id 제거 후 복합 키 반환)';

-- 2. approve_manager 함수 업데이트
-- 파라미터를 p_company_id와 p_user_id로 변경
-- 먼저 기존 함수 삭제 (파라미터 변경을 위해)
DROP FUNCTION IF EXISTS "public"."approve_manager"("p_company_user_id" "uuid");

CREATE FUNCTION "public"."approve_manager"(
  "p_company_id" "uuid",
  "p_user_id" "uuid"
)
RETURNS "jsonb"
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

COMMENT ON FUNCTION "public"."approve_manager"("p_company_id" "uuid", "p_user_id" "uuid") IS 
'매니저 승인 (복합 키 사용: company_id + user_id)';

-- 3. reject_manager 함수 업데이트
-- 파라미터를 p_company_id와 p_user_id로 변경
-- 먼저 기존 함수 삭제 (파라미터 변경을 위해)
DROP FUNCTION IF EXISTS "public"."reject_manager"("p_company_user_id" "uuid");

CREATE FUNCTION "public"."reject_manager"(
  "p_company_id" "uuid",
  "p_user_id" "uuid"
)
RETURNS "jsonb"
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

COMMENT ON FUNCTION "public"."reject_manager"("p_company_id" "uuid", "p_user_id" "uuid") IS 
'매니저 거절 (복합 키 사용: company_id + user_id)';

-- 기존 함수 오버로드 제거 (선택 사항 - 호환성을 위해 유지 가능)
-- 하지만 복합 키를 사용하는 것이 더 명확하므로 기존 시그니처는 제거 권장

-- ============================================================================
-- 마이그레이션 완료
-- ============================================================================

