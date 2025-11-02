# Status 필드 vs deleted_at 비교 분석

## 📊 제안: users 테이블에 status 필드 추가

### 구조 제안
```sql
CREATE TABLE "public"."users" (
    "id" uuid NOT NULL PRIMARY KEY,
    "display_name" text,
    "user_type" text DEFAULT 'REVIEWER',
    "status" text DEFAULT 'active' NOT NULL,  -- 'active', 'inactive', 'deleted', 'pending_deletion'
    "deleted_at" timestamp with time zone NULL,  -- 선택적: 삭제 시점 기록
    "deletion_reason" text,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone,
    CONSTRAINT "users_status_check" CHECK (status IN ('active', 'inactive', 'deleted', 'pending_deletion', 'suspended'))
);

-- 부분 인덱스 (활성 사용자만)
CREATE INDEX "idx_users_status_active" 
ON "public"."users" ("id", "status") 
WHERE "status" = 'active';

CREATE INDEX "idx_users_status_deleted" 
ON "public"."users" ("deleted_at") 
WHERE "status" IN ('deleted', 'pending_deletion');
```

---

## 🔍 Status 필드 방식의 장점

### 1. 명확한 상태 구분
```sql
-- 여러 상태를 명확히 구분
'active'          -- 활성 사용자
'inactive'        -- 비활성 (일시 중지)
'deleted'         -- 완전 삭제됨
'pending_deletion'-- 삭제 대기 중 (30일 유예 기간 등)
'suspended'       -- 정지됨 (관리자 조치)
```

**장점:**
- ✅ 비즈니스 로직을 데이터베이스 레벨에서 명확히 표현
- ✅ 여러 삭제 단계 관리 가능 (예: 즉시 삭제 vs 유예 기간)
- ✅ 삭제 외의 다른 상태도 관리 가능 (inactive, suspended 등)

### 2. 쿼리 단순성
```sql
-- 활성 사용자만 조회
SELECT * FROM users WHERE status = 'active';

-- 삭제된 사용자 조회
SELECT * FROM users WHERE status = 'deleted';

-- 삭제 대기 중인 사용자 조회
SELECT * FROM users WHERE status = 'pending_deletion';
```

**장점:**
- ✅ `IS NULL` 체크보다 직관적
- ✅ 코드 가독성 향상
- ✅ 여러 상태를 하나의 WHERE 절로 필터링 가능

### 3. 비즈니스 로직 반영
```dart
// 삭제 요청 (30일 유예 기간)
await supabase
  .from('users')
  .update({'status': 'pending_deletion', 'deleted_at': DateTime.now().add(Duration(days: 30))})
  .eq('id', userId);

// 30일 후 자동 삭제 처리
await supabase
  .from('users')
  .update({'status': 'deleted', 'deleted_at': DateTime.now()})
  .eq('status', 'pending_deletion')
  .lte('deleted_at', DateTime.now());
```

**장점:**
- ✅ 유예 기간 관리 용이
- ✅ 단계별 삭제 프로세스 구현 가능
- ✅ 복구 프로세스 명확화

---

## ⚠️ Status 필드 방식의 단점

### 1. 데이터 중복 가능성
```sql
-- status와 deleted_at을 모두 관리하면 중복
status = 'deleted' AND deleted_at IS NOT NULL  -- 중복 정보
```

**해결책:**
- Option 1: `status`만 사용, `deleted_at` 제거
- Option 2: `status`와 `deleted_at` 모두 사용 (하이브리드)
- Option 3: `status`는 현재 상태, `deleted_at`은 삭제 시점 기록용

### 2. FK 참조 시 체크 복잡성
```sql
-- 다른 테이블에서 활성 사용자만 참조해야 함
SELECT c.* 
FROM campaigns c
JOIN users u ON c.user_id = u.id
WHERE u.status = 'active';  -- 매번 체크 필요
```

**해결책:**
- RLS 정책에서 자동 필터링
- 부분 인덱스로 성능 최적화

### 3. 상태 전이 관리
```sql
-- 잘못된 상태 전이 가능
UPDATE users SET status = 'active' WHERE status = 'deleted';  -- 삭제된 사용자 복구?
```

**해결책:**
- 상태 전이 제약조건 추가
- 애플리케이션 레벨에서 상태 전이 로직 구현

---

## 🔄 deleted_at 방식과의 비교

### deleted_at 방식 (Soft Delete)
```sql
CREATE TABLE "public"."users" (
    "id" uuid NOT NULL,
    "deleted_at" timestamp with time zone NULL,
    ...
);

-- 활성 사용자
SELECT * FROM users WHERE deleted_at IS NULL;

-- 삭제된 사용자
SELECT * FROM users WHERE deleted_at IS NOT NULL;
```

**장점:**
- ✅ 단순함: NULL 체크만 하면 됨
- ✅ 시간 정보 자동 제공
- ✅ SQL 표준 패턴 (널리 사용됨)

**단점:**
- ❌ 상태 구분이 단순함 (활성/비활성 두 가지만)
- ❌ 중간 상태 표현 어려움 (pending_deletion 등)
- ❌ 비즈니스 로직 표현이 제한적

---

## 🎯 하이브리드 방식: Status + deleted_at

### 구조
```sql
CREATE TABLE "public"."users" (
    "id" uuid NOT NULL PRIMARY KEY,
    "display_name" text,
    "user_type" text DEFAULT 'REVIEWER',
    "status" text DEFAULT 'active' NOT NULL,
    "deleted_at" timestamp with time zone NULL,  -- 삭제 시점 기록
    "deletion_reason" text,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone,
    CONSTRAINT "users_status_check" 
        CHECK (status IN ('active', 'inactive', 'pending_deletion', 'deleted', 'suspended')),
    CONSTRAINT "users_status_deleted_at_consistency" 
        CHECK (
            (status IN ('deleted', 'pending_deletion') AND deleted_at IS NOT NULL) OR
            (status = 'active' AND deleted_at IS NULL)
        )
);
```

### 사용 패턴
```sql
-- 활성 사용자 조회 (두 가지 방법 모두 가능)
SELECT * FROM users WHERE status = 'active';
-- 또는
SELECT * FROM users WHERE deleted_at IS NULL;

-- 삭제 대기 중 (유예 기간)
UPDATE users 
SET status = 'pending_deletion', deleted_at = NOW() + INTERVAL '30 days'
WHERE id = 'user-uuid';

-- 30일 후 완전 삭제
UPDATE users 
SET status = 'deleted'
WHERE status = 'pending_deletion' AND deleted_at < NOW();

-- 복구
UPDATE users 
SET status = 'active', deleted_at = NULL, deletion_reason = NULL
WHERE id = 'user-uuid';
```

**장점:**
- ✅ `status`: 명확한 상태 구분
- ✅ `deleted_at`: 삭제 시점 기록 및 자동 삭제 스크립트 실행
- ✅ 유연성: 두 필드를 함께 활용하여 다양한 시나리오 지원

---

## 📊 최종 비교

| 항목 | Status만 | deleted_at만 | Status + deleted_at (하이브리드) |
|------|----------|--------------|----------------------------------|
| **명확성** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **단순성** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **유연성** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **성능** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **비즈니스 로직 반영** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **구현 복잡도** | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |

---

## 🎯 권장사항

### 현재 프로젝트에 가장 적합한 방식: **Status 필드 단독**

**이유:**
1. **비즈니스 요구사항**: 삭제 요청 → 유예 기간 → 완전 삭제 단계 관리 필요
2. **명확성**: `status = 'pending_deletion'`이 `deleted_at IS NOT NULL`보다 직관적
3. **확장성**: 향후 `suspended`, `inactive` 등 추가 상태 관리 용이
4. **쿼리 단순성**: `WHERE status = 'active'`가 `WHERE deleted_at IS NULL`보다 읽기 쉬움

### 구현 예시
```sql
-- users 테이블에 status 필드 추가
ALTER TABLE "public"."users"
  ADD COLUMN IF NOT EXISTS "status" text DEFAULT 'active' NOT NULL;

-- 제약조건 추가
ALTER TABLE "public"."users"
  ADD CONSTRAINT "users_status_check" 
  CHECK (status IN ('active', 'inactive', 'pending_deletion', 'deleted', 'suspended'));

-- 부분 인덱스 (활성 사용자만)
CREATE INDEX "idx_users_status_active" 
ON "public"."users" ("id") 
WHERE "status" = 'active';

-- 기존 deleted_users 데이터 마이그레이션
UPDATE "public"."users" u
SET status = 'deleted'
FROM "public"."deleted_users" du
WHERE u.id = du.id;

-- deleted_at은 선택적으로 추가 (삭제 시점 기록용)
ALTER TABLE "public"."users"
  ADD COLUMN IF NOT EXISTS "deleted_at" timestamp with time zone NULL;

-- 삭제 처리
UPDATE users 
SET status = 'pending_deletion', deleted_at = NOW()
WHERE id = 'user-uuid';

-- 완전 삭제 (30일 후)
UPDATE users 
SET status = 'deleted'
WHERE status = 'pending_deletion' AND deleted_at < NOW() - INTERVAL '30 days';
```

### RLS 정책 예시
```sql
-- 활성 사용자만 조회 가능 (기본 정책)
CREATE POLICY "Users are viewable when active"
ON "public"."users" FOR SELECT
USING (status = 'active' OR auth.uid() = id);

-- 사용자는 자신의 정보 조회 가능 (상태 상관없이)
CREATE POLICY "Users can view their own data"
ON "public"."users" FOR SELECT
USING (auth.uid() = id);
```

---

## 💡 결론

**Status 필드 방식 추천** ✅

**핵심 이유:**
1. ✅ 명확한 상태 구분으로 비즈니스 로직 표현 용이
2. ✅ 단계별 삭제 프로세스 구현 가능 (pending_deletion → deleted)
3. ✅ 향후 확장성 (suspended, inactive 등)
4. ✅ 쿼리 가독성 향상

**optional로 deleted_at 추가:**
- 삭제 시점 기록 및 자동 삭제 스크립트 실행용
- `status`는 상태, `deleted_at`은 시간 정보로 역할 분리

