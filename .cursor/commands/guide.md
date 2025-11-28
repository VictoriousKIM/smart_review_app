# Flutter 웹 앱 접근성 활성화 가이드

## 🚀 빠른 시작 가이드

다음 순서로 개발 환경을 설정하세요:

1. **Supabase 시작** (Flutter는 별도로 실행할 필요 없음 - 이미 실행 중이어야 함)
   ```bash
   npx supabase start
   ```

2. **브라우저 탭 열기** (Playwright MCP 사용)
   - 첫 번째 탭: Flutter 웹 앱 (http://localhost:3001/) - 개발자 계정으로 로그인
   - 두 번째 탭: Supabase 대시보드 (http://127.0.0.1:54503)
   - 세 번째 탭: Cloudflare Workers 대시보드 (https://dash.cloudflare.com)

3. **접근성 활성화** (Flutter 웹 앱에서 필수!)
   ```javascript
   // 접근성 활성화 (필수!)
   await page.evaluate(() => {
     const accessibilityButton = document.querySelector('flt-semantics-placeholder[aria-label="Enable accessibility"]');
     if (accessibilityButton) {
       accessibilityButton.click();
     }
   });
   ```

4. **개발자 계정으로 로그인**
   - "카카오로 로그인" 버튼 클릭
   <!-- - "이메일로 로그인" 버튼 클릭
   - 이메일 필드에 `dev@example.com` 입력
   - 비밀번호 필드에 `dev@example.com` 입력
   - 로그인 버튼 클릭 -->

**참고사항:**
- 이미 로그인되어 있다면 로그인 시도를 반복할 필요 없음
- Flutter는 별도로 `flutter run`을 실행할 필요 없음 (이미 실행 중이어야 함)
- Playwright MCP를 사용하여 브라우저 자동화

## 📱 Flutter 웹 앱 접근성 활성화

Flutter 웹 앱에서 접근성 버튼을 활성화하는 방법:

```javascript
// 접근성 활성화 (필수!)
await page.evaluate(() => {
  const accessibilityButton = document.querySelector('flt-semantics-placeholder[aria-label="Enable accessibility"]');
  if (accessibilityButton) {
    accessibilityButton.click();
  }
});
```

**사용 시나리오:**
- Flutter 웹 앱이 로딩되었지만 UI가 보이지 않을 때
- Playwright로 Flutter 앱을 테스트할 때
- 접근성 기능이 필요한 경우

## 🌐 접속 정보

**Flutter 웹 앱 포트:**
- http://localhost:3001/

**Supabase 서비스:**
- API URL: http://127.0.0.1:54500
- Studio (대시보드): http://127.0.0.1:54503
- Database: postgresql://postgres:postgres@127.0.0.1:54501/postgres
- Mailpit (이메일 테스트): http://127.0.0.1:54504

**Cloudflare Workers 대시보드:**
- https://dash.cloudflare.com

**참고:** Windows에서 포트 54276-54475 범위가 WSL2/Docker Desktop에 의해 예약되어 있어, Supabase 포트를 54500 이상으로 변경했습니다.

## 👤 개발용 계정 정보

| 역할 | 이메일 | 비밀번호 | 설명 |
|------|--------|----------|------|
| 개발자 | `dev@example.com` | `dev@example.com` | 일반 사용자 |
| 관리자 | `admin@example.com` | `admin@example.com` | 관리자 권한 |
| 리뷰어 | `reviewer@example.com` | `reviewer@example.com` | 리뷰어 권한 |

<!-- - 참고: `test@example.com` -->
<!-- - 참고: `company_owner@example.com` -->
<!-- - 참고: `company_manger@example.com` -->

## 🗄️ 로컬 Supabase 스택 시작

```bash
# 로컬 Supabase 환경 시작
npx supabase start
```

### 환경 확인

성공적으로 시작되면 다음과 같은 정보가 출력됩니다:

```
         API URL: http://127.0.0.1:54500
     GraphQL URL: http://127.0.0.1:54500/graphql/v1
    Database URL: postgresql://postgres:postgres@127.0.0.1:54501/postgres
      Studio URL: http://127.0.0.1:54503
     Mailpit URL: http://127.0.0.1:54504
 Publishable key: sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
      Secret key: sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz
```

## 📦 데이터베이스 워크플로우

### 데이터 덤프 (시드 데이터용)
```bash
# 데이터만 덤프 (스키마 제외)
npx supabase db dump --local --data-only -f supabase/seed.sql
```

### 마이그레이션 파일 압축
```bash
npx supabase migration squash
```

### 로컬대시보드 변경사항 마이그레이션 적용
```bash
npx supabase db diff -f <migration_name>
```

### 스키마 변경 마이그레이션 추가
```bash
# 현재 DB와 마이그레이션 파일 차이점 확인 후 새 마이그레이션 생성
npx supabase db diff --local --schema public -f supabase/migrations/YYYYMMDDHHMMSS_description.sql
```

**베스트 프랙티스:**
- `seed.sql`: 데이터만 저장 (--data-only)
- `migrations/`: 스키마 변경 이력만 관리
- 스키마 변경 시 `db diff`로 자동 생성
