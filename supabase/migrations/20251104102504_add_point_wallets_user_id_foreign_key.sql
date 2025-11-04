-- ============================================================================
-- Migration: Add foreign key constraint to point_wallets.user_id
-- ============================================================================
-- 
-- point_wallets 테이블의 user_id에 users 테이블의 id로 외래키 제약조건 추가
-- ============================================================================

-- 1. 기존 외래키 제약조건 제거 (있는 경우)
ALTER TABLE "public"."point_wallets"
  DROP CONSTRAINT IF EXISTS "point_wallets_user_id_fkey";

-- 2. 기존 트리거 제거 (있는 경우)
DROP TRIGGER IF EXISTS "check_point_wallets_user_id_trigger" ON "public"."point_wallets";
DROP FUNCTION IF EXISTS "public"."check_point_wallets_user_id"();

-- 3. 데이터 무결성 확인: 모든 user_id가 users 테이블에 존재하는지 확인
DO $$
DECLARE
  v_invalid_count integer;
BEGIN
  SELECT COUNT(*) INTO v_invalid_count
  FROM public.point_wallets pw
  WHERE pw.user_id NOT IN (SELECT id FROM public.users);
  
  IF v_invalid_count > 0 THEN
    RAISE EXCEPTION 'Found % point_wallets with invalid user_id. Please fix data before adding foreign key constraint.', v_invalid_count;
  END IF;
END $$;

-- 4. 외래키 제약조건 추가
ALTER TABLE "public"."point_wallets"
  ADD CONSTRAINT "point_wallets_user_id_fkey" 
  FOREIGN KEY ("user_id") 
  REFERENCES "public"."users"("id") 
  ON DELETE CASCADE;

-- 5. 인덱스 확인 (이미 존재할 수 있음)
CREATE INDEX IF NOT EXISTS "idx_point_wallets_user_id" 
  ON "public"."point_wallets" USING "btree" ("user_id");

-- ============================================================================
-- End of Migration
-- ============================================================================

