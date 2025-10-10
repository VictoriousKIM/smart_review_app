-- Security 이슈 완전 해결을 위한 추가 마이그레이션
-- 함수의 search_path를 명시적으로 설정하여 보안 이슈를 해결합니다.

-- ===========================================
-- 함수 재생성 (search_path 명시적 설정)
-- ===========================================

-- handle_new_user 함수 완전 재생성
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

CREATE FUNCTION public.handle_new_user()
RETURNS trigger 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public
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
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- update_updated_at_column 함수 완전 재생성
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

CREATE FUNCTION update_updated_at_column()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- 트리거 재생성
DROP TRIGGER IF EXISTS update_users_updated_at ON "public"."users";
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON "public"."users" 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- get_user_type_stats 함수 완전 재생성
DROP FUNCTION IF EXISTS get_user_type_stats() CASCADE;

CREATE FUNCTION get_user_type_stats()
RETURNS TABLE (
    user_type text,
    count bigint,
    percentage numeric
) 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public
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

