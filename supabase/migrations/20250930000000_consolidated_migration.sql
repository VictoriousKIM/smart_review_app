-- 통합 마이그레이션 파일
-- 모든 이전 마이그레이션을 하나로 합친 파일

-- ===========================================
-- 1. 기본 users 테이블 생성 (Supabase Auth와 호환)
-- ===========================================
create table "public"."users" (
    "id" uuid references auth.users on delete cascade not null,
    "created_at" timestamp with time zone not null default now(),
    "display_name" text,
    "user_type" text,
    "email" text,
    "updated_at" timestamp with time zone DEFAULT now(),
    "points" integer DEFAULT 0,
    "level" integer DEFAULT 1,
    "review_count" integer DEFAULT 0,
    "sns_connections" jsonb
);

alter table "public"."users" enable row level security;

CREATE UNIQUE INDEX users_pkey ON public.users USING btree (id);

alter table "public"."users" add constraint "users_pkey" PRIMARY KEY using index "users_pkey";

-- user_type 필드에 CHECK 제약 조건 추가
ALTER TABLE "public"."users" 
ADD CONSTRAINT users_user_type_check 
CHECK (user_type IN ('user', 'admin'));

-- user_type 필드에 기본값 설정
ALTER TABLE "public"."users" 
ALTER COLUMN user_type SET DEFAULT 'user';

-- 광고주 인증 필드 추가
ALTER TABLE "public"."users" 
ADD COLUMN "is_advertiser_verified" boolean DEFAULT false;

-- 회사 연결 필드 추가 (나중에 companies 테이블 생성 후 외래키 설정)
ALTER TABLE "public"."users" 
ADD COLUMN "company_id" uuid;

-- RLS 정책 추가
create policy "Users can view own profile" on "public"."users"
  for select using (auth.uid() = id);

create policy "Users can update own profile" on "public"."users"
  for update using (auth.uid() = id);

create policy "Users can insert own profile" on "public"."users"
  for insert with check (auth.uid() = id);

-- ===========================================
-- 2. 회사 테이블 생성
-- ===========================================
create table "public"."companies" (
    "id" uuid default gen_random_uuid() not null,
    "created_at" timestamp with time zone not null default now(),
    "name" text not null,
    "business_number" text,
    "contact_email" text,
    "contact_phone" text,
    "address" text,
    "status" text not null default 'active',
    "created_by" uuid references auth.users on delete cascade
);

alter table "public"."companies" enable row level security;

CREATE UNIQUE INDEX companies_pkey ON public.companies USING btree (id);

alter table "public"."companies" add constraint "companies_pkey" PRIMARY KEY using index "companies_pkey";

-- 회사 RLS 정책
create policy "Users can view all companies" on "public"."companies"
  for select using (true);

create policy "Users can create companies" on "public"."companies"
  for insert with check (auth.uid() = created_by);

create policy "Users can update own companies" on "public"."companies"
  for update using (auth.uid() = created_by);

-- 회사-사용자 관계 테이블
create table "public"."company_users" (
    "id" uuid default gen_random_uuid() not null,
    "company_id" uuid references companies(id) on delete cascade,
    "user_id" uuid references auth.users(id) on delete cascade,
    "company_role" text not null, -- 'owner', 'manager'
    "status" text not null default 'active',
    "joined_at" timestamp with time zone not null default now(),
    UNIQUE(company_id, user_id)
);

alter table "public"."company_users" enable row level security;

CREATE UNIQUE INDEX company_users_pkey ON public.company_users USING btree (id);

alter table "public"."company_users" add constraint "company_users_pkey" PRIMARY KEY using index "company_users_pkey";

-- company_role CHECK 제약 조건
ALTER TABLE "public"."company_users" 
ADD CONSTRAINT company_users_role_check 
CHECK (company_role IN ('owner', 'manager'));

-- 회사-사용자 관계 RLS 정책
create policy "Users can view company relationships" on "public"."company_users"
  for select using (true);

create policy "Users can join companies" on "public"."company_users"
  for insert with check (auth.uid() = user_id);

create policy "Company owners can manage relationships" on "public"."company_users"
  for all using (
    company_id IN (
      SELECT company_id FROM company_users 
      WHERE user_id = auth.uid() AND company_role = 'owner'
    )
  );

-- users 테이블의 company_id 외래키 설정
ALTER TABLE "public"."users" 
ADD CONSTRAINT users_company_id_fkey 
FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE SET NULL;

-- ===========================================
-- 3. 캠페인 테이블 생성 (템플릿 기능 포함)
-- ===========================================
create table "public"."campaigns" (
    "id" uuid default gen_random_uuid() not null,
    "created_at" timestamp with time zone not null default now(),
    "title" text not null,
    "description" text,
    "status" text not null default 'active',
    "campaign_type" text not null default 'reviewer', -- 'reviewer', 'press', 'visit'
    "product_price" integer not null default 0,
    "review_reward" integer not null default 0,
    "platform" text not null default 'coupang', -- 'coupang', 'naver', '11st', etc.
    "platform_logo_url" text,
    "product_image_url" text,
    "start_date" timestamp with time zone,
    "end_date" timestamp with time zone,
    "max_participants" integer,
    "current_participants" integer default 0,
    "created_by" uuid references auth.users on delete cascade,
    "company_id" uuid references companies(id) on delete set null,
    -- 템플릿 기능을 위한 필드들
    "is_template" boolean DEFAULT false,
    "template_name" text,
    "last_used_at" timestamp with time zone,
    "usage_count" integer DEFAULT 0
);

alter table "public"."campaigns" enable row level security;

CREATE UNIQUE INDEX campaigns_pkey ON public.campaigns USING btree (id);

alter table "public"."campaigns" add constraint "campaigns_pkey" PRIMARY KEY using index "campaigns_pkey";

-- 캠페인 관련 인덱스들
CREATE INDEX IF NOT EXISTS idx_campaigns_user_template 
ON "public"."campaigns"("created_by", "is_template");

CREATE INDEX IF NOT EXISTS idx_campaigns_last_used 
ON "public"."campaigns"("last_used_at" DESC);

CREATE INDEX IF NOT EXISTS idx_campaigns_usage_count 
ON "public"."campaigns"("usage_count" DESC);

CREATE INDEX IF NOT EXISTS idx_campaigns_user_history 
ON "public"."campaigns"("created_by", "last_used_at" DESC, "usage_count" DESC);

-- 캠페인 RLS 정책
create policy "Anyone can view active campaigns" on "public"."campaigns"
  for select using (status = 'active');

create policy "Users can view all campaigns" on "public"."campaigns"
  for select using (true);

create policy "Users can update own campaigns" on "public"."campaigns"
  for update using (auth.uid() = created_by);

create policy "Users can insert own campaigns" on "public"."campaigns"
  for insert with check (auth.uid() = created_by);

-- ===========================================
-- 3. 사용자 관련 함수 및 트리거
-- ===========================================

-- 사용자 회원가입 시 자동으로 users 테이블에 레코드를 생성하는 함수
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 사용자 등록 시 트리거 실행
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- updated_at을 자동으로 업데이트하는 트리거 함수
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- users 테이블에 updated_at 트리거 추가
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON "public"."users" 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- 사용자 타입별 통계를 위한 함수
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================
-- 4. 기존 사용자들을 users 테이블에 추가 (이미 등록된 사용자들용)
-- ===========================================
INSERT INTO public.users (id, display_name, email, user_type)
SELECT 
  au.id,
  COALESCE(au.raw_user_meta_data->>'display_name', au.email),
  au.email,
  COALESCE(au.raw_user_meta_data->>'user_type', 'user')
FROM auth.users au
WHERE au.id NOT IN (SELECT id FROM public.users)
ON CONFLICT (id) DO NOTHING;

-- 기존 데이터가 있다면 기본값을 'user'로 설정
UPDATE "public"."users" 
SET user_type = 'user' 
WHERE user_type IS NULL OR user_type NOT IN ('user', 'admin');

-- 기존 캠페인 데이터에 대한 기본값 설정
UPDATE "public"."campaigns" 
SET 
    "is_template" = false,
    "usage_count" = 0,
    "last_used_at" = "created_at"
WHERE "is_template" IS NULL OR "usage_count" IS NULL OR "last_used_at" IS NULL;
