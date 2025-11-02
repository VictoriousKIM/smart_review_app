# deleted_users 테이블 재설계 분석

## 📊 현재 구조

### users 테이블
```sql
CREATE TABLE "public"."users" (
    "id" uuid NOT NULL PRIMARY KEY,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now(),
    "display_name" text,
    "user_type" text DEFAULT 'REVIEWER'::text
);
```

### deleted_users 테이블 (현재)
```sql
CREATE TABLE "public"."deleted_users" (
    "id" uuid NOT NULL PRIMARY KEY,  -- users.id와 동일한 값이지만 FK 아님
    "email" text,
    "display_name" text,
    "user_type" text,
    "company_id" uuid,
    "deletion_reason" text,
    "deleted_at" timestamp with time zone DEFAULT now() NOT NULL,
    "original_created_at" timestamp with time zone
);
```

### 문제점
1. ❌ **데이터 중복**: `display_name`, `user_type` 등이 users와 deleted_users 양쪽에 저장됨
2. ❌ **FK 관계 없음**: `deleted_users.id`가 `users.id`를 참조하지 않음 (데이터 무결성 보장 불가)
3. ❌ **불일치 가능성**: users 테이블이 업데이트되어도 deleted_users는 변경되지 않음
4. ❌ **불필요한 필드**: `email`, `company_id` 등 users 테이블에 없는 필드
5. ❌ **id 혼란**: `id`가 PK이지만 동시에 `users.id`를 의미함

---

## 🎯 제안된 구조

### 1. users 테이블에 status 필드 추가

```sql
ALTER TABLE "public"."users"
  ADD COLUMN "status" text DEFAULT 'active' NOT NULL;

ALTER TABLE "public"."users"
  ADD CONSTRAINT "users_status_check" 
  CHECK (status IN ('active', 'inactive', 'pending_deletion', 'deleted', 'suspended'));

-- 부분 인덱스 (활성 사용자만)
CREATE INDEX "idx_users_status_active" 
ON "public"."users" ("id") 
WHERE "status" = 'active';
```

### 2. deleted_users 테이블 재설계

```sql
-- 기존 테이블 삭제 후 재생성
DROP TABLE IF EXISTS "public"."deleted_users";

CREATE TABLE "public"."deleted_users" (
    "user_id" uuid NOT NULL PRIMARY KEY,
    "deletion_reason" text,
    "deleted_at" timestamp with time zone DEFAULT now() NOT NULL,
    
    -- Foreign Key
    CONSTRAINT "deleted_users_user_id_fkey" 
        FOREIGN KEY ("user_id") 
        REFERENCES "public"."users"("id") 
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- 인덱스 (삭제 날짜 기준 조회용)
CREATE INDEX "idx_deleted_users_deleted_at" 
ON "public"."deleted_users" ("deleted_at");
```

---

## ✅ 장점

### 1. **데이터 정규화**
- ❌ 이전: `display_name`, `user_type` 등이 양쪽 테이블에 중복
- ✅ 개선: deleted_users는 삭제 관련 정보만 저장 (user_id, deletion_reason, deleted_at)
- ✅ users 테이블에서 항상 최신 정보 조회 가능

### 2. **참조 무결성 보장**
```sql
-- FK 제약조건으로 인한 자동 검증
CONSTRAINT "deleted_users_user_id_fkey" 
    FOREIGN KEY ("user_id") 
    REFERENCES "public"."users"("id")
```
- ✅ 존재하지 않는 user_id 삭제 불가
- ✅ users 삭제 시 deleted_users도 자동 삭제 (ON DELETE CASCADE)
- ✅ users.id 변경 시 deleted_users.user_id도 자동 업데이트 (ON UPDATE CASCADE)

### 3. **JOIN 쿼리 단순화**
```sql
-- 삭제된 사용자 정보 조회 (JOIN 필요)
SELECT 
    u.id,
    u.display_name,
    u.user_type,
    u.status,
    du.deletion_reason,
    du.deleted_at
FROM "public"."users" u
INNER JOIN "public"."deleted_users" du ON u.id = du.user_id
WHERE u.status = 'deleted';

-- 또는 deleted_users만 조회 (users 정보는 FK로 참조)
SELECT 
    du.user_id,
    du.deletion_reason,
    du.deleted_at,
    u.display_name  -- 필요시 JOIN
FROM "public"."deleted_users" du
LEFT JOIN "public"."users" u ON du.user_id = u.id;
```

### 4. **데이터 일관성**
- ✅ users 테이블의 `display_name`, `user_type` 변경 시 deleted_users 조회에도 자동 반영
- ✅ 데이터 불일치 가능성 제거

### 5. **저장 공간 절약**
- ✅ 중복 데이터 제거로 저장 공간 감소
- ✅ 테이블 크기 감소로 조회 성능 향상

---

## 🔄 마이그레이션 시나리오

### 시나리오 1: users 테이블에 status 필드 추가

```sql
-- 1. status 필드 추가
ALTER TABLE "public"."users"
  ADD COLUMN "status" text DEFAULT 'active' NOT NULL;

-- 2. 제약조건 추가
ALTER TABLE "public"."users"
  ADD CONSTRAINT "users_status_check" 
  CHECK (status IN ('active', 'inactive', 'pending_deletion', 'deleted', 'suspended'));

-- 3. 기존 데이터 처리 (deleted_users에 있는 사용자는 'deleted'로 설정)
UPDATE "public"."users" u
SET status = 'deleted'
WHERE EXISTS (
    SELECT 1 FROM "public"."deleted_users" du 
    WHERE du.id = u.id
);
```

### 시나리오 2: deleted_users 테이블 재설계

```sql
-- 1. 기존 데이터 백업 (필요시)
CREATE TABLE "public"."deleted_users_backup" AS 
SELECT * FROM "public"."deleted_users";

-- 2. 기존 테이블 삭제
DROP TABLE IF EXISTS "public"."deleted_users";

-- 3. 새 테이블 생성
CREATE TABLE "public"."deleted_users" (
    "user_id" uuid NOT NULL PRIMARY KEY,
    "deletion_reason" text,
    "deleted_at" timestamp with time zone DEFAULT now() NOT NULL,
    
    CONSTRAINT "deleted_users_user_id_fkey" 
        FOREIGN KEY ("user_id") 
        REFERENCES "public"."users"("id") 
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- 4. 기존 데이터 마이그레이션 (users에 존재하는 경우만)
INSERT INTO "public"."deleted_users" ("user_id", "deletion_reason", "deleted_at")
SELECT 
    id as user_id,
    deletion_reason,
    deleted_at
FROM "public"."deleted_users_backup" du
WHERE EXISTS (
    SELECT 1 FROM "public"."users" u WHERE u.id = du.id
);

-- 5. 인덱스 생성
CREATE INDEX "idx_deleted_users_deleted_at" 
ON "public"."deleted_users" ("deleted_at");

-- 6. 백업 테이블 삭제 (마이그레이션 검증 후)
-- DROP TABLE IF EXISTS "public"."deleted_users_backup";
```

---

## 📋 사용 패턴

### 1. 사용자 삭제
```sql
-- 1. users.status를 'deleted'로 변경
UPDATE "public"."users"
SET status = 'deleted', updated_at = NOW()
WHERE id = 'user-uuid';

-- 2. deleted_users에 삭제 정보 저장
INSERT INTO "public"."deleted_users" ("user_id", "deletion_reason", "deleted_at")
VALUES ('user-uuid', '사용자 요청', NOW())
ON CONFLICT ("user_id") DO UPDATE
SET deletion_reason = EXCLUDED.deletion_reason,
    deleted_at = EXCLUDED.deleted_at;
```

### 2. 삭제된 사용자 조회
```sql
-- 방법 1: users와 JOIN
SELECT 
    u.*,
    du.deletion_reason,
    du.deleted_at
FROM "public"."users" u
INNER JOIN "public"."deleted_users" du ON u.id = du.user_id
WHERE u.status = 'deleted'
ORDER BY du.deleted_at DESC;

-- 방법 2: deleted_users만 조회
SELECT * FROM "public"."deleted_users"
ORDER BY deleted_at DESC;
```

### 3. 사용자 복구
```sql
-- 1. users.status를 'active'로 변경
UPDATE "public"."users"
SET status = 'active', updated_at = NOW()
WHERE id = 'user-uuid';

-- 2. deleted_users에서 삭제
DELETE FROM "public"."deleted_users"
WHERE user_id = 'user-uuid';
```

### 4. 활성 사용자만 조회
```sql
-- status 필드 활용 (부분 인덱스 사용)
SELECT * FROM "public"."users"
WHERE status = 'active';

-- 또는 deleted_users에 없는 사용자 (이전 방식과 호환)
SELECT * FROM "public"."users" u
WHERE NOT EXISTS (
    SELECT 1 FROM "public"."deleted_users" du 
    WHERE du.user_id = u.id
);
```

---

## 🔒 데이터 무결성 고려사항

### 1. ON DELETE CASCADE 동작
```sql
-- users 테이블에서 사용자 삭제 시
DELETE FROM "public"."users" WHERE id = 'user-uuid';

-- 자동으로 deleted_users에서도 삭제됨 (ON DELETE CASCADE)
```

**⚠️ 주의사항:**
- 실제 사용자 삭제는 `users` 테이블에서 직접 DELETE하는 것이 아니라 `status = 'deleted'`로 변경하는 것이 좋습니다.
- ON DELETE CASCADE는 예상치 못한 삭제를 방지하기 위해 주의가 필요합니다.

### 2. 트리거 또는 RPC 함수 권장
```sql
-- 사용자 삭제를 안전하게 처리하는 함수
CREATE OR REPLACE FUNCTION "public"."delete_user_safe"(
    "p_user_id" uuid,
    "p_deletion_reason" text DEFAULT NULL
) RETURNS jsonb
LANGUAGE "plpgsql" SECURITY DEFINER
AS $$
DECLARE
    v_result jsonb;
BEGIN
    -- 1. users.status 업데이트
    UPDATE "public"."users"
    SET status = 'deleted', updated_at = NOW()
    WHERE id = p_user_id;
    
    -- 2. deleted_users에 삭제 정보 저장
    INSERT INTO "public"."deleted_users" ("user_id", "deletion_reason", "deleted_at")
    VALUES (p_user_id, p_deletion_reason, NOW())
    ON CONFLICT ("user_id") DO UPDATE
    SET deletion_reason = EXCLUDED.deletion_reason,
        deleted_at = EXCLUDED.deleted_at;
    
    -- 3. 결과 반환
    SELECT jsonb_build_object(
        'success', true,
        'user_id', p_user_id,
        'deleted_at', NOW()
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;
```

---

## 📊 성능 비교

### 현재 구조 (deleted_users에 중복 데이터)
- **테이블 크기**: 더 큼 (display_name, user_type 등 중복)
- **조회 성능**: JOIN 불필요하지만 데이터 일관성 문제
- **업데이트**: users 업데이트 시 deleted_users도 별도 업데이트 필요

### 제안된 구조 (FK 관계)
- **테이블 크기**: 더 작음 (중복 데이터 없음)
- **조회 성능**: JOIN 필요하지만 인덱스 활용으로 빠름
- **업데이트**: users만 업데이트하면 deleted_users 조회 시 자동 반영

---

## 🎯 권장사항

### 1. **users 테이블에 status 필드 추가** ✅
- 비즈니스 로직 명확화
- 쿼리 단순화 (`WHERE status = 'active'`)
- 확장성 (inactive, suspended 등 추가 상태 관리)

### 2. **deleted_users 테이블 재설계** ✅
- `user_id`를 FK로 설정
- `deletion_reason`과 `deleted_at`만 저장
- 데이터 정규화 및 무결성 보장

### 3. **구현 순서**
1. users 테이블에 status 필드 추가
2. 기존 deleted_users 데이터를 users.status = 'deleted'로 마이그레이션
3. deleted_users 테이블 재설계 (FK 관계 설정)
4. 삭제 로직을 RPC 함수로 구현

---

## 📝 결론

**제안된 구조의 핵심 장점:**
1. ✅ **데이터 정규화**: 중복 데이터 제거
2. ✅ **참조 무결성**: FK 제약조건으로 데이터 일관성 보장
3. ✅ **유지보수성**: users 테이블만 업데이트하면 됨
4. ✅ **확장성**: status 필드로 다양한 상태 관리 가능
5. ✅ **성능**: 부분 인덱스 활용으로 조회 성능 향상

**구현 시 주의사항:**
- 마이그레이션 전 데이터 백업 필수
- 기존 코드에서 deleted_users 조회 로직 수정 필요
- ON DELETE CASCADE 동작 이해 및 필요시 조정

