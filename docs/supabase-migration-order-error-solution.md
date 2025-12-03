# Supabase 마이그레이션 순서 오류 해결 방법

**작성일**: 2025년 12월 02일

## 문제 상황

`npx supabase db reset --local` 실행 시 다음과 같은 오류가 발생합니다:

```
ERROR: relation "public.company_users" does not exist (SQLSTATE 42P01)
At statement: 0
-- company_users 테이블에 updated_at 컬럼 추가

ALTER TABLE "public"."company_users"
ADD COLUMN IF NOT EXISTS "updated_at" timestamp with time zone DEFAULT "now"()
```

## 원인 분석

마이그레이션 파일의 타임스탬프 순서가 잘못되어 있습니다:

1. **`20251201160630_add_updated_at_to_company_users.sql`** (2025년 12월 1일 16:06:30)
   - `company_users` 테이블에 `updated_at` 컬럼을 추가하려고 시도
   - **문제**: 이 시점에 `company_users` 테이블이 아직 존재하지 않음

2. **`20251203120000_fix_admin_get_users_remove_level_review_count.sql`** (2025년 12월 3일 12:00:00)
   - `company_users` 테이블을 생성하는 마이그레이션
   - **문제**: 이 마이그레이션이 `updated_at` 컬럼 추가 마이그레이션보다 나중에 실행됨

## 해결 방법

### 방법 1: 마이그레이션 파일 이름 변경 (권장)

`updated_at` 컬럼 추가 마이그레이션 파일의 타임스탬프를 `company_users` 테이블 생성 마이그레이션 이후로 변경합니다.

#### 1단계: 기존 마이그레이션 파일 이름 변경

```powershell
# PowerShell에서 실행
cd supabase/migrations
Rename-Item -Path "20251201160630_add_updated_at_to_company_users.sql" -NewName "20251203120001_add_updated_at_to_company_users.sql"
```

또는 수동으로 파일 이름을 변경:
- **기존**: `20251201160630_add_updated_at_to_company_users.sql`
- **변경**: `20251203120001_add_updated_at_to_company_users.sql`

#### 2단계: 데이터베이스 리셋

```powershell
npx supabase db reset --local
```

### 방법 2: 테이블 생성 마이그레이션에 updated_at 컬럼 포함

`20251203120000_fix_admin_get_users_remove_level_review_count.sql` 파일에서 `company_users` 테이블 생성 시 `updated_at` 컬럼을 포함하도록 수정합니다.

#### 1단계: 테이블 생성 부분 수정

`supabase/migrations/20251203120000_fix_admin_get_users_remove_level_review_count.sql` 파일의 6335번째 줄 근처:

```sql
CREATE TABLE IF NOT EXISTS "public"."company_users" (
    "company_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "company_role" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,  -- 추가
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    CONSTRAINT "company_users_company_role_check" CHECK (("company_role" = ANY (ARRAY['owner'::"text", 'manager'::"text", 'reviewer'::"text"]))),
    CONSTRAINT "company_users_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'pending'::"text", 'suspended'::"text", 'rejected'::"text"])))
);
```

#### 2단계: updated_at 자동 업데이트 트리거 추가

같은 파일에 트리거 함수와 트리거를 추가합니다:

```sql
-- updated_at 자동 업데이트 트리거 함수 생성
CREATE OR REPLACE FUNCTION "public"."update_company_users_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW."updated_at" = now();
    RETURN NEW;
END;
$$;

-- 트리거 생성
DROP TRIGGER IF EXISTS "trigger_update_company_users_updated_at" ON "public"."company_users";

CREATE TRIGGER "trigger_update_company_users_updated_at"
    BEFORE UPDATE ON "public"."company_users"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."update_company_users_updated_at"();

COMMENT ON COLUMN "public"."company_users"."updated_at" IS '레코드가 마지막으로 업데이트된 시간';
```

#### 3단계: 중복 마이그레이션 파일 삭제

`20251201160630_add_updated_at_to_company_users.sql` 파일을 삭제합니다:

```powershell
Remove-Item "supabase/migrations/20251201160630_add_updated_at_to_company_users.sql"
```

#### 4단계: 데이터베이스 리셋

```powershell
npx supabase db reset --local
```

## 권장 해결 방법

**방법 1 (마이그레이션 파일 이름 변경)**을 권장합니다. 이유:

1. 마이그레이션 파일의 독립성 유지
2. 각 마이그레이션이 단일 책임을 가지도록 함
3. 마이그레이션 히스토리 추적이 용이함
4. 롤백 시 개별 마이그레이션 단위로 관리 가능

## 마이그레이션 파일 명명 규칙

마이그레이션 파일 이름은 다음 형식을 따릅니다:

```
YYYYMMDDHHMMSS_description.sql
```

- `YYYYMMDDHHMMSS`: 타임스탬프 (년월일시분초)
- `description`: 마이그레이션 내용을 설명하는 영문 설명 (스네이크 케이스)

**중요**: 타임스탬프는 마이그레이션 실행 순서를 결정하므로, 의존성이 있는 마이그레이션의 경우 올바른 순서를 보장해야 합니다.

## 예방 방법

### 1. 마이그레이션 생성 전 의존성 확인

새 마이그레이션을 생성하기 전에:
- 대상 테이블/함수가 이미 존재하는지 확인
- 존재하지 않는 경우, 테이블/함수를 생성하는 마이그레이션이 먼저 실행되도록 타임스탬프 확인

### 2. 마이그레이션 순서 검증

```powershell
# 마이그레이션 파일 목록 확인 (타임스탬프 순서)
Get-ChildItem supabase/migrations/*.sql | Sort-Object Name | Select-Object Name
```

### 3. 로컬 환경에서 테스트

프로덕션에 적용하기 전에 항상 로컬 환경에서 테스트:

```powershell
npx supabase db reset --local
```

## 참고 자료

- [Supabase 마이그레이션 가이드](https://supabase.com/docs/guides/cli/local-development#database-migrations)
- [PostgreSQL ALTER TABLE 문서](https://www.postgresql.org/docs/current/sql-altertable.html)

