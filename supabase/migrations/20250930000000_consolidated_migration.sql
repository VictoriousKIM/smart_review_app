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

-- 회사 연결 필드 추가 (나중에 companies 테이블 생성 후 외래키 설정)
ALTER TABLE "public"."users" 
ADD COLUMN "company_id" uuid;

-- RLS 정책 추가
create policy "Users can view own profile" on "public"."users"
  for select using ((select auth.uid()) = id);

create policy "Users can update own profile" on "public"."users"
  for update using ((select auth.uid()) = id);

create policy "Users can insert own profile" on "public"."users"
  for insert with check ((select auth.uid()) = id);

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
  for insert with check ((select auth.uid()) = created_by);

create policy "Users can update own companies" on "public"."companies"
  for update using ((select auth.uid()) = created_by);

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

-- 회사-사용자 관계 RLS 정책 (통합된 정책)
create policy "Company users management" on "public"."company_users"
  for all using (
    -- 사용자가 자신의 관계를 관리할 수 있음
    user_id = (select auth.uid())
    OR
    -- 회사 소유자가 회사 관계를 관리할 수 있음
    company_id IN (
      SELECT company_id FROM company_users 
      WHERE user_id = (select auth.uid()) AND company_role = 'owner'
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

create policy "Users can update own campaigns" on "public"."campaigns"
  for update using ((select auth.uid()) = created_by);

create policy "Users can insert own campaigns" on "public"."campaigns"
  for insert with check ((select auth.uid()) = created_by);

-- ===========================================
-- 4. 사용자 관련 함수 및 트리거 (보안 강화)
-- ===========================================

-- 사용자 회원가입 시 자동으로 users 테이블에 레코드를 생성하는 함수
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

-- 사용자 등록 시 트리거 실행
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- updated_at을 자동으로 업데이트하는 트리거 함수
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

-- users 테이블에 updated_at 트리거 추가
DROP TRIGGER IF EXISTS update_users_updated_at ON "public"."users";
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
-- 5. 성능 최적화를 위한 추가 인덱스
-- ===========================================

-- RLS 정책에서 자주 사용되는 컬럼들에 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_users_auth_uid ON "public"."users" (id);
CREATE INDEX IF NOT EXISTS idx_companies_created_by ON "public"."companies" (created_by);
CREATE INDEX IF NOT EXISTS idx_company_users_user_id ON "public"."company_users" (user_id);
CREATE INDEX IF NOT EXISTS idx_company_users_company_role ON "public"."company_users" (company_role);
CREATE INDEX IF NOT EXISTS idx_campaigns_created_by ON "public"."campaigns" (created_by);
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON "public"."campaigns" (status);

-- company_users 테이블에 복합 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_company_users_user_company_role 
ON "public"."company_users" (user_id, company_id, company_role);

-- RLS 정책에서 자주 사용되는 패턴을 위한 인덱스
CREATE INDEX IF NOT EXISTS idx_company_users_owner_lookup 
ON "public"."company_users" (company_id, company_role) 
WHERE company_role = 'owner';

-- ===========================================
-- 6. 기존 사용자들을 users 테이블에 추가 (이미 등록된 사용자들용)
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

-- ===========================================
-- 7. 캠페인 로그 테이블 (통합된 캠페인 활동 관리)
-- ===========================================
create table "public"."campaign_logs" (
    "id" uuid default gen_random_uuid() not null,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now(),
    
    -- 기본 참조
    "campaign_id" uuid references campaigns(id) on delete cascade not null,
    "user_id" uuid references auth.users(id) on delete cascade not null,
    
    -- 상태 관리 (세분화된 상태)
    "status" text not null,
    "activity_at" timestamp with time zone not null default now(),
    
    -- 활동 데이터 (각 단계별 데이터 누적 저장)
    "data" jsonb default '{}',
    
    -- 리워드 정보
    "reward_type" text, -- 'platform_points', 'direct_payment', 'mixed'
    "reward_amount" integer,
    
    -- 한 사용자당 한 캠페인당 하나의 로그만 허용
    UNIQUE(campaign_id, user_id)
);

alter table "public"."campaign_logs" enable row level security;

CREATE UNIQUE INDEX campaign_logs_pkey ON public.campaign_logs USING btree (id);
alter table "public"."campaign_logs" add constraint "campaign_logs_pkey" PRIMARY KEY using index "campaign_logs_pkey";

-- 캠페인 로그 관련 인덱스
CREATE INDEX IF NOT EXISTS idx_campaign_logs_campaign_id ON "public"."campaign_logs" (campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_logs_user_id ON "public"."campaign_logs" (user_id);
CREATE INDEX IF NOT EXISTS idx_campaign_logs_status ON "public"."campaign_logs" (status);
CREATE INDEX IF NOT EXISTS idx_campaign_logs_campaign_user ON "public"."campaign_logs" (campaign_id, user_id);

-- Generated Columns (자주 조회되는 필드)
ALTER TABLE campaign_logs 
ADD COLUMN title text GENERATED ALWAYS AS (data->>'title') STORED;

ALTER TABLE campaign_logs 
ADD COLUMN rating integer GENERATED ALWAYS AS ((data->>'rating')::int) STORED;

-- 캠페인 로그 RLS 정책
create policy "Users can view their own campaign logs" on campaign_logs
    FOR SELECT USING (auth.uid() = user_id);

create policy "Users can insert their own campaign logs" on campaign_logs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

create policy "Users can update their own campaign logs" on campaign_logs
    FOR UPDATE USING (auth.uid() = user_id);

create policy "Advertisers can view logs for their campaigns" on campaign_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM campaigns 
            WHERE campaigns.id = campaign_logs.campaign_id 
            AND campaigns.company_id IN (
                SELECT id FROM companies WHERE user_id = auth.uid()
            )
        )
    );

-- ===========================================
-- 8. 알림 테이블
-- ===========================================
create table "public"."notifications" (
    "id" uuid default gen_random_uuid() not null,
    "created_at" timestamp with time zone not null default now(),
    "user_id" uuid references auth.users(id) on delete cascade not null,
    "type" text not null, -- 'application_approved', 'application_rejected', 'review_approved', 'review_rejected', 'campaign_created', etc.
    "title" text not null,
    "message" text not null,
    "is_read" boolean default false,
    "read_at" timestamp with time zone,
    "related_campaign_id" uuid references campaigns(id) on delete set null,
    "related_campaign_log_id" uuid references campaign_logs(id) on delete set null
);

alter table "public"."notifications" enable row level security;

CREATE UNIQUE INDEX notifications_pkey ON public.notifications USING btree (id);
alter table "public"."notifications" add constraint "notifications_pkey" PRIMARY KEY using index "notifications_pkey";

-- 알림 관련 인덱스
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON "public"."notifications" (user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON "public"."notifications" (is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON "public"."notifications" (created_at DESC);

-- 알림 RLS 정책
create policy "Users can view own notifications" on "public"."notifications"
  for select using ((select auth.uid()) = user_id);

create policy "Users can update own notifications" on "public"."notifications"
  for update using ((select auth.uid()) = user_id);

create policy "System can create notifications" on "public"."notifications"
  for insert with check (true);