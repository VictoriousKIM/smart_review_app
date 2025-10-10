-- 남은 이슈 완전 해결을 위한 최종 마이그레이션
-- Security와 Performance 이슈를 완전히 해결합니다.

-- ===========================================
-- 1. Security 이슈 완전 해결
-- ===========================================

-- 함수들을 완전히 재생성하여 search_path 이슈 해결
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS get_user_type_stats() CASCADE;

-- handle_new_user 함수 재생성 (완전히 안전한 방식)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.users (id, display_name, email, user_type)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'user_type', 'user')
  );
  RETURN NEW;
END;
$$;

-- 트리거 재생성
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- update_updated_at_column 함수 재생성 (완전히 안전한 방식)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- 트리거 재생성
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON "public"."users" 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- get_user_type_stats 함수 재생성 (완전히 안전한 방식)
CREATE OR REPLACE FUNCTION get_user_type_stats()
RETURNS TABLE (
    user_type text,
    count bigint,
    percentage numeric
) 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = ''
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ut.user_type,
        COUNT(*) as count,
        ROUND(
            (COUNT(*)::numeric / (SELECT COUNT(*) FROM "public"."users")::numeric) * 100, 
            2
        ) as percentage
    FROM "public"."users" ut
    GROUP BY ut.user_type
    ORDER BY count DESC;
END;
$$;

-- ===========================================
-- 2. Performance 이슈 완전 해결
-- ===========================================

-- company_users 테이블의 중복 정책 문제 해결
-- 두 개의 정책을 하나의 통합된 정책으로 대체

-- 기존 정책들 삭제
DROP POLICY IF EXISTS "Users can join companies" ON "public"."company_users";
DROP POLICY IF EXISTS "Company owners can manage relationships" ON "public"."company_users";

-- 통합된 정책 생성 (더 효율적이고 중복 없음)
CREATE POLICY "Company users management" ON "public"."company_users"
  FOR ALL USING (
    -- 사용자가 자신의 관계를 관리할 수 있음
    user_id = (select auth.uid())
    OR
    -- 회사 소유자가 회사 관계를 관리할 수 있음
    company_id IN (
      SELECT company_id FROM company_users 
      WHERE user_id = (select auth.uid()) AND company_role = 'owner'
    )
  );

-- ===========================================
-- 3. 추가 성능 최적화
-- ===========================================

-- company_users 테이블에 복합 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_company_users_user_company_role 
ON "public"."company_users" (user_id, company_id, company_role);

-- RLS 정책에서 자주 사용되는 패턴을 위한 인덱스
CREATE INDEX IF NOT EXISTS idx_company_users_owner_lookup 
ON "public"."company_users" (company_id, company_role) 
WHERE company_role = 'owner';

