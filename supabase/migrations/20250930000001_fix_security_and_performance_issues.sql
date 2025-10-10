-- 보안 및 성능 이슈 해결 마이그레이션
-- Supabase Studio에서 발견된 24개 이슈를 해결합니다.

-- ===========================================
-- 1. Security 이슈 해결: 함수 search_path 수정
-- ===========================================

-- handle_new_user 함수 수정 (search_path 고정)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- update_updated_at_column 함수 수정 (search_path 고정)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql' SET search_path = public;

-- get_user_type_stats 함수 수정 (search_path 고정)
CREATE OR REPLACE FUNCTION get_user_type_stats()
RETURNS TABLE (
    user_type text,
    count bigint,
    percentage numeric
) AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ===========================================
-- 2. Performance 이슈 해결: RLS 정책 최적화
-- ===========================================

-- users 테이블 RLS 정책 최적화
DROP POLICY IF EXISTS "Users can view own profile" ON "public"."users";
DROP POLICY IF EXISTS "Users can update own profile" ON "public"."users";
DROP POLICY IF EXISTS "Users can insert own profile" ON "public"."users";

CREATE POLICY "Users can view own profile" ON "public"."users"
  FOR SELECT USING ((select auth.uid()) = id);

CREATE POLICY "Users can update own profile" ON "public"."users"
  FOR UPDATE USING ((select auth.uid()) = id);

CREATE POLICY "Users can insert own profile" ON "public"."users"
  FOR INSERT WITH CHECK ((select auth.uid()) = id);

-- companies 테이블 RLS 정책 최적화
DROP POLICY IF EXISTS "Users can create companies" ON "public"."companies";
DROP POLICY IF EXISTS "Users can update own companies" ON "public"."companies";

CREATE POLICY "Users can create companies" ON "public"."companies"
  FOR INSERT WITH CHECK ((select auth.uid()) = created_by);

CREATE POLICY "Users can update own companies" ON "public"."companies"
  FOR UPDATE USING ((select auth.uid()) = created_by);

-- company_users 테이블 RLS 정책 최적화
DROP POLICY IF EXISTS "Users can join companies" ON "public"."company_users";
DROP POLICY IF EXISTS "Company owners can manage relationships" ON "public"."company_users";

CREATE POLICY "Users can join companies" ON "public"."company_users"
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "Company owners can manage relationships" ON "public"."company_users"
  FOR ALL USING (
    company_id IN (
      SELECT company_id FROM company_users 
      WHERE user_id = (select auth.uid()) AND company_role = 'owner'
    )
  );

-- campaigns 테이블 RLS 정책 최적화
DROP POLICY IF EXISTS "Users can update own campaigns" ON "public"."campaigns";
DROP POLICY IF EXISTS "Users can insert own campaigns" ON "public"."campaigns";

CREATE POLICY "Users can update own campaigns" ON "public"."campaigns"
  FOR UPDATE USING ((select auth.uid()) = created_by);

CREATE POLICY "Users can insert own campaigns" ON "public"."campaigns"
  FOR INSERT WITH CHECK ((select auth.uid()) = created_by);

-- ===========================================
-- 3. 중복 정책 정리 (Performance 이슈 해결)
-- ===========================================

-- campaigns 테이블의 중복 SELECT 정책 정리
-- "Anyone can view active campaigns"와 "Users can view all campaigns"가 중복됨
-- 더 구체적인 정책만 유지
DROP POLICY IF EXISTS "Users can view all campaigns" ON "public"."campaigns";

-- company_users 테이블의 중복 정책 정리
-- "Users can view company relationships"와 "Company owners can manage relationships"가 중복됨
-- 더 구체적인 정책만 유지
DROP POLICY IF EXISTS "Users can view company relationships" ON "public"."company_users";

-- ===========================================
-- 4. 추가 성능 최적화를 위한 인덱스
-- ===========================================

-- RLS 정책에서 자주 사용되는 컬럼들에 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_users_auth_uid ON "public"."users" (id);
CREATE INDEX IF NOT EXISTS idx_companies_created_by ON "public"."companies" (created_by);
CREATE INDEX IF NOT EXISTS idx_company_users_user_id ON "public"."company_users" (user_id);
CREATE INDEX IF NOT EXISTS idx_company_users_company_role ON "public"."company_users" (company_role);
CREATE INDEX IF NOT EXISTS idx_campaigns_created_by ON "public"."campaigns" (created_by);
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON "public"."campaigns" (status);
