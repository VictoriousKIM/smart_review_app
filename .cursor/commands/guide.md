# Flutter 웹 앱 접근성 활성화 가이드
수파베이스와 플러터를 실행하여 개발자계정으로 로그인하고 새탭에 수파베이스 대시보드를 열어줘
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

**플러터 웹 사용포트**
- http://localhost:3001/
**개발용 계정 정보:**
- 이메일: `dev@example.com`
- 비밀번호: `dev@example.com`
- 역할: 관리자 사용자
- 참고: `test@example.com`
로컬 Supabase 스택 시작

```bash
# 로컬 Supabase 환경 시작
npx supabase start
```

###  환경 확인

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
