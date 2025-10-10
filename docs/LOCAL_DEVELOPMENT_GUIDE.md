# 🚀 로컬 개발 환경 가이드

이 문서는 Supabase CLI를 사용한 로컬 개발 환경 설정 및 사용 방법을 설명합니다.

## 🔄 최근 업데이트 (2025-10-09)

### 인증 시스템 개선
- **GoRouter 통합 개선**: AuthService의 `authStateChanges` Stream을 사용하여 실시간 인증 상태 변화 감지
- **자동 리다이렉션**: 로그인/로그아웃 시 GoRouter가 자동으로 적절한 페이지로 리다이렉션
- **Context 안전성**: `context.mounted` 체크를 통한 안전한 네비게이션 처리
- **로딩 상태 처리**: 인증 상태 로딩 중 `/loading` 페이지로 리다이렉션하여 UX 개선

### 코드 품질 개선
- 모든 deprecated API 제거 (`withOpacity` → `withValues`, Radio API 업데이트)
- 불필요한 언더스코어 사용 제거
- BuildContext async gap 문제 해결
- 린터 오류 전체 해결

## 📋 사전 요구사항

- **Docker Desktop** (필수)
- **Node.js** (npm 포함)
- **Flutter** (이미 설치됨)

## 🛠️ 초기 설정

### 1. Supabase CLI 설치

```bash
# 프로젝트 루트에서 실행
npm install supabase --save-dev
```

### 2. 로컬 Supabase 스택 시작

```bash
# 로컬 Supabase 환경 시작 (스토리지 제외)
npx supabase start -x storage-api
```

### 3. 환경 확인

성공적으로 시작되면 다음과 같은 정보가 출력됩니다:

```
         API URL: http://127.0.0.1:54321
     GraphQL URL: http://127.0.0.1:54321/graphql/v1
    Database URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
      Studio URL: http://127.0.0.1:54323
     Mailpit URL: http://127.0.0.1:54324
 Publishable key: sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
      Secret key: sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz
```

## 🎯 개발용 사용자 계정

로컬 환경에서는 다음 개발용 계정들을 사용할 수 있습니다:

| 역할 | 이메일 | 비밀번호 | 설명 |
|------|--------|----------|------|
| 개발자 | `dev@example.com` | `dev@example.com` | 일반 사용자 |
| 관리자 | `admin@example.com` | `admin@example.com` | 관리자 권한 |
| 리뷰어 | `reviewer@example.com` | `reviewer@example.com` | 리뷰어 권한 |

## 🔧 개발 워크플로우

### 로컬 환경 시작

```bash
# 로컬 Supabase 시작
npx supabase start -x storage-api

# Flutter 앱 실행
flutter run
```

### 로컬 환경 중지

```bash
# 로컬 Supabase 중지
npx supabase stop

# 데이터 백업 없이 중지
npx supabase stop --no-backup
```

### 데이터베이스 리셋

```bash
# 로컬 데이터베이스 리셋 (개발용 사용자 재생성) 시행전에 반드시 관리자에게 물어볼 것
npx supabase db reset
```

## 🌐 접속 URL

- **Supabase Studio**: http://127.0.0.1:54323
  - 로컬 데이터베이스 관리
  - 테이블 데이터 확인 및 수정
  - SQL 쿼리 실행

- **API 엔드포인트**: http://127.0.0.1:54321
  - REST API 접근
  - GraphQL 엔드포인트: http://127.0.0.1:54321/graphql/v1

- **이메일 테스트**: http://127.0.0.1:54324
  - 로컬에서 발송된 이메일 확인

## 📊 데이터베이스 관리

### SQL 쿼리 실행

Supabase Studio에서 직접 SQL을 실행하거나, psql을 사용할 수 있습니다:

```bash
# psql로 데이터베이스 접속
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres
```

### 테이블 구조 확인

```sql
-- 모든 테이블 목록
\dt

-- 특정 테이블 구조 확인
\d users

-- 데이터 조회
SELECT * FROM users;
```

## 🔄 마이그레이션 관리

### 마이그레이션 워크플로우

Supabase CLI는 **마이그레이션 파일이 진실의 원천(Source of Truth)**입니다. 모든 스키마 변경사항은 마이그레이션 파일로 관리됩니다.

#### 1. 로컬 개발에서 스키마 변경

```bash
# 방법 1: Supabase Studio에서 변경
# 1. http://127.0.0.1:54323 접속
# 2. Table Editor에서 테이블 구조 수정
# 3. ⚠️ 반드시 변경사항을 마이그레이션으로 생성해야 함

# 방법 2: SQL Editor에서 직접 변경
# 1. SQL Editor에서 ALTER TABLE 등 실행
# 2. ⚠️ 반드시 변경사항을 마이그레이션으로 생성해야 함
```

**⚠️ 중요: 로컬 대시보드에서 변경한 내용은 반드시 역마이그레이션을 해야 합니다!**
- 대시보드 변경 → 임시적 (db reset 시 사라짐)
- 마이그레이션 파일 → 영구적 (모든 환경에 적용됨)

#### 2. 변경사항 감지 및 마이그레이션 생성

```bash
# 현재 로컬 DB와 마이그레이션 파일의 차이점 확인
npx supabase db diff

# 변경사항이 있으면 마이그레이션 파일 생성
npx supabase db diff -f "변경_설명"

# 예시
npx supabase db diff -f "add_user_phone_column"
npx supabase db diff -f "create_campaign_participants_table"
```

#### 3. 마이그레이션 적용

```bash
# 로컬에 마이그레이션 적용 (데이터 보존)
npx supabase db push

# 로컬에 완전 초기화 (시드 데이터 복원) 시행전에 반드시 관리자에게 물어볼 것
npx supabase db reset

# 원격에 마이그레이션 푸시 (프로덕션 배포 시)
npx supabase db push
```

### 역마이그레이션 (대시보드 → 마이그레이션)

**🚨 필수 작업: 로컬 대시보드에서 수정한 내용을 마이그레이션 파일로 변환하는 과정입니다.**

**대시보드에서 변경한 후 반드시 해야 할 작업:**
1. 변경사항 감지
2. 마이그레이션 파일 생성
3. 적용 및 검증

#### 1. 대시보드에서 변경
- Supabase Studio에서 테이블 구조 수정
- 컬럼 추가/삭제/수정
- 인덱스, 제약조건 등 추가

#### 2. 변경사항 감지
```bash
# 변경사항 확인
npx supabase db diff

# 출력 예시:
# alter table "public"."campaigns" add column "new_field" text;
# create index "idx_new_field" on "public"."campaigns" ("new_field");
```

#### 3. 마이그레이션 파일 생성
```bash
# 변경사항을 마이그레이션으로 생성
npx supabase db diff -f "add_new_field_to_campaigns"

# migrations/ 폴더에 새 파일 생성됨
# 예: 20250930050000_add_new_field_to_campaigns.sql
```

### 마이그레이션 파일 구조

```
supabase/migrations/
├── 20250928000001_init.sql                    # 초기 테이블 생성
├── 20250929000001_add_campaign_template_fields.sql  # 템플릿 필드 추가
├── 20250929000002_add_user_trigger.sql        # 사용자 트리거 추가
└── 20250930045921_remove_shipping_cost_column.sql   # 컬럼 제거
```

### 마이그레이션 히스토리 관리

```bash
# 마이그레이션 상태 확인
npx supabase migration list

# 특정 마이그레이션 상태 변경
npx supabase migration repair --status reverted 20250928093551

# 원격에서 로컬로 마이그레이션 가져오기
npx supabase db pull
```

### 주의사항

1. **🚨 마이그레이션 파일이 우선순위**: 로컬 대시보드 수정은 임시적
   - 대시보드에서 변경한 후 **반드시** `npx supabase db diff -f "설명"` 실행
   - 변경사항을 마이그레이션 파일로 저장하지 않으면 `db reset` 시 사라짐

2. **`db reset` 시 데이터 삭제**: 중요한 데이터는 미리 백업
   - 시행 전에 반드시 관리자에게 물어볼 것

3. **시드 데이터 자동 복원**: `db reset` 후 `seed.sql` 자동 실행

4. **팀 협업**: 마이그레이션 파일을 Git으로 공유하여 동일한 DB 구조 보장

5. **개발 워크플로우 체크리스트**:
   - [ ] 대시보드에서 스키마 변경
   - [ ] `npx supabase db diff`로 변경사항 확인
   - [ ] `npx supabase db diff -f "설명"`으로 마이그레이션 생성
   - [ ] 생성된 마이그레이션 파일 검토
   - [ ] `npx supabase db reset` 또는 `npx supabase db push`로 적용

## 🐛 문제 해결

### 컨테이너 충돌 오류

```bash
# 모든 컨테이너 중지
npx supabase stop --no-backup

# Docker 정리
docker system prune -f

# 다시 시작
npx supabase start -x storage-api
```

### 포트 충돌

다른 애플리케이션이 54321 포트를 사용하는 경우:

```bash
# 사용 중인 포트 확인
netstat -ano | findstr :54321

# 해당 프로세스 종료 후 다시 시작
npx supabase start -x storage-api
```

### 데이터베이스 연결 오류

```bash
# 로컬 환경 상태 확인
npx supabase status

# 로그 확인
npx supabase logs
```

## 📝 개발 팁

### 1. 개발용 데이터 추가

`supabase/seed.sql` 파일을 수정하여 개발용 데이터를 추가할 수 있습니다:

```sql
-- 새로운 개발용 사용자 추가
INSERT INTO auth.users (id, email, encrypted_password, ...) VALUES (...);
```

### 2. 환경별 설정

앱은 자동으로 개발/프로덕션 환경을 감지합니다:

- **개발 모드**: 로컬 Supabase 사용
- **프로덕션 모드**: 원격 Supabase 사용

### 3. 실시간 기능 테스트

로컬 환경에서도 Supabase의 실시간 기능을 테스트할 수 있습니다.

## 🤖 MCP로 Flutter 웹 테스트하기

MCP(Model Context Protocol)를 사용하여 Flutter 웹 앱을 자동화 테스트할 때 웹을 잘 인식하게 하는 방법입니다.

### MCP 테스트 환경 설정

#### 1. Flutter 웹 서버 실행

```bash
# Flutter 웹 앱을 특정 포트에서 실행
flutter run -d web-server --web-port 3001
```

#### 2. MCP 브라우저 접속 시 주의사항

Flutter 웹 앱은 접근성 트리가 기본적으로 비활성화되어 있어 MCP가 UI 요소를 인식하지 못할 수 있습니다.

**해결 방법:**

1. **접근성 활성화**: Flutter 웹 앱 로드 후 "Enable accessibility" 버튼을 클릭해야 실제 UI가 렌더링됩니다.

2. **올바른 URL 사용**: 
   - ❌ `http://127.0.0.1:3001` (IPv4 - 연결 실패 가능)
   - ✅ `http://localhost:3001` 또는 `http://[::1]:3001` (IPv6)

3. **로딩 대기**: Flutter 웹 앱은 초기 로딩에 시간이 걸리므로 충분한 대기 시간을 설정합니다.

#### 3. MCP 테스트 스크립트 예시

```javascript
// 1. Flutter 웹 앱 접속
await page.goto('http://localhost:3001');

// 2. 접근성 활성화 (필수!)
await page.evaluate(() => {
  const accessibilityButton = document.querySelector('flt-semantics-placeholder[aria-label="Enable accessibility"]');
  if (accessibilityButton) {
    accessibilityButton.click();
  }
});

// 3. Flutter UI 로딩 대기
await page.waitForTimeout(3000);

// 4. 이제 실제 UI 요소들이 인식됩니다
const loginButton = await page.getByRole('button', { name: 'Google로 로그인' });
```

#### 4. 일반적인 문제 해결

**문제**: MCP가 Flutter UI 요소를 인식하지 못함
**해결**: 
- 접근성 버튼 클릭 확인
- 충분한 로딩 대기 시간 설정
- 올바른 URL 사용

**문제**: 로그인 폼이 보이지 않음
**해결**:
- "이메일로 로그인" 버튼 클릭
- 개발용 계정 사용: `dev@example.com` / `dev@example.com`

**문제**: 페이지가 계속 로딩 중
**해결**:
- Flutter 서버가 정상 실행 중인지 확인
- 브라우저 새로고침 후 재시도

#### 5. 개발용 계정 정보

MCP 테스트 시 사용할 수 있는 계정:

| 역할 | 이메일 | 비밀번호 | 설명 |
|------|--------|----------|------|
| 개발자 | `dev@example.com` | `dev@example.com` | 일반 사용자 |
| 관리자 | `admin@example.com` | `admin@example.com` | 관리자 권한 |
| 리뷰어 | `reviewer@example.com` | `reviewer@example.com` | 리뷰어 권한 |

#### 6. MCP 테스트 체크리스트

- [ ] Flutter 웹 서버가 3001포트에서 실행 중
- [ ] 올바른 URL로 접속 (`localhost:3001` 또는 `[::1]:3001`)
- [ ] 접근성 버튼 클릭 완료
- [ ] 충분한 로딩 대기 시간 설정
- [ ] 개발용 계정 정보 준비
- [ ] 로그인 후 홈 화면 확인

## 🚀 배포 전 체크리스트

- [ ] 로컬에서 모든 기능 테스트 완료
- [ ] MCP 자동화 테스트 통과
- [ ] 데이터베이스 스키마 최종 확인
- [ ] 마이그레이션 파일 정리
- [ ] 프로덕션 환경 설정 확인

## 📞 지원

문제가 발생하면 다음을 확인하세요:

1. Docker Desktop이 실행 중인지 확인
2. 포트 충돌 여부 확인
3. `npx supabase status`로 서비스 상태 확인
4. `npx supabase logs`로 오류 로그 확인

---

**참고**: 이 가이드는 로컬 개발 환경을 위한 것입니다. 프로덕션 환경에서는 원격 Supabase를 사용합니다.
