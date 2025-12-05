# 네이버 로그인 Edge Function → Cloudflare Workers 마이그레이션 로드맵

## 📋 개요

네이버 로그인 인증 로직을 **Supabase Edge Function**에서 **Cloudflare Workers**로 마이그레이션합니다.

---

## 현재 구조

### 현재 플로우

```
Flutter App
    ↓ (supabase.functions.invoke('naver-auth'))
Supabase Edge Function (Deno)
    ↓ (내부 네트워크: kong:8000)
Supabase Admin API
    ↓
Custom JWT 생성
    ↓
Flutter App (세션 설정)
```

### 현재 파일

- `supabase/functions/naver-auth/index.ts` - Edge Function 메인 파일

---

## 목표 구조

### 목표 플로우

```
Flutter App
    ↓ (HTTP POST to Workers URL)
Cloudflare Workers (TypeScript)
    ↓ (외부 API: SUPABASE_URL)
Supabase Admin API
    ↓
Custom JWT 생성
    ↓
Flutter App (세션 설정)
```

### 목표 파일 구조

```
workers/
  ├── index.ts                    # Workers 메인 파일 (라우팅)
  └── functions/
      └── naver-auth.ts          # 네이버 로그인 처리 함수
```

---

## 마이그레이션 단계

### Phase 1: Workers에 네이버 로그인 함수 추가

**파일**: `workers/functions/naver-auth.ts` (신규 생성)

**작업 내용**:
1. Edge Function 코드를 Workers 형식으로 변환
2. Deno → Node.js/TypeScript 변환
3. Supabase 클라이언트 초기화 (외부 URL 사용)
4. JWT 라이브러리 변경 (Deno jose → Node.js jose)

**주요 변경사항**:
- `serve()` → `export default { async fetch() }`
- `Deno.env.get()` → `env.XXX`
- `kong:8000` → `env.SUPABASE_URL` (외부 URL)
- `jose` 라이브러리 import 경로 변경

---

### Phase 2: Workers 라우팅 추가

**파일**: `workers/index.ts`

**작업 내용**:
1. `/api/naver-auth` 엔드포인트 추가
2. `naver-auth.ts` 함수 import 및 호출

**코드 예시**:
```typescript
// workers/index.ts
import handleNaverAuth from './functions/naver-auth';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // ... 기존 라우팅 ...

    if (url.pathname === '/api/naver-auth' && request.method === 'POST') {
      return handleNaverAuth(request, env);
    }

    // ... 기존 라우팅 ...
  },
};
```

---

### Phase 3: 환경 변수 설정

**작업 내용**:
1. Cloudflare Workers Secrets 설정
2. 필요한 환경 변수 추가

**필요한 환경 변수**:
- `NAVER_CLIENT_ID` - 네이버 OAuth Client ID
- `NAVER_CLIENT_SECRET` - 네이버 OAuth Client Secret
- `NAVER_REDIRECT_URI` - 네이버 OAuth Redirect URI
- `SUPABASE_URL` - Supabase 프로젝트 URL
- `SUPABASE_SERVICE_ROLE_KEY` - Supabase Service Role Key
- `JWT_SECRET` - Supabase JWT Secret

**설정 방법**:
```bash
# Cloudflare Workers Secrets 설정
npx wrangler secret put NAVER_CLIENT_ID
npx wrangler secret put NAVER_CLIENT_SECRET
npx wrangler secret put NAVER_REDIRECT_URI
npx wrangler secret put SUPABASE_URL
npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY
npx wrangler secret put JWT_SECRET
```

---

### Phase 4: Flutter 서비스 수정

**파일**: `lib/services/naver_auth_service.dart`

**작업 내용**:
1. Edge Function 호출 → Workers HTTP 호출로 변경
2. URL 변경: `supabase.functions.invoke()` → `http://workers-url/api/naver-auth`

**변경 전**:
```dart
final response = await _supabase.functions
    .invoke('naver-auth', body: {
      'platform': 'web',
      'code': code,
    });
```

**변경 후**:
```dart
final workersUrl = 'https://your-workers-url.workers.dev';
final response = await http.post(
  Uri.parse('$workersUrl/api/naver-auth'),
  headers: {
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'platform': 'web',
    'code': code,
  }),
);
```

---

### Phase 5: 테스트

**테스트 항목**:
1. ✅ 웹 네이버 로그인 (code → access_token)
2. ✅ 모바일 네이버 로그인 (access_token 직접 사용)
3. ✅ 기존 사용자 로그인 (프로필 있음)
4. ✅ 신규 사용자 (프로필 없음 → 회원가입 화면)
5. ✅ Custom JWT 생성 및 저장
6. ✅ 에러 처리

---

### Phase 6: 배포 및 검증

**작업 내용**:
1. Workers 배포
2. Flutter 앱 업데이트
3. 프로덕션 테스트
4. Edge Function 제거 (선택사항)

**배포 명령**:
```bash
# Workers 배포
cd workers
npx wrangler deploy
```

---

## 주요 변경사항 요약

### 1. 런타임 변경
- **Before**: Deno (Edge Function)
- **After**: Node.js/TypeScript (Workers)

### 2. Supabase 접근 방식
- **Before**: 내부 네트워크 (`kong:8000`)
- **After**: 외부 API (`SUPABASE_URL`)

### 3. JWT 라이브러리
- **Before**: `https://deno.land/x/jose@v4.14.4/index.ts`
- **After**: `jose` (npm 패키지)

### 4. 호출 방식
- **Before**: `supabase.functions.invoke('naver-auth')`
- **After**: `http.post('https://workers-url/api/naver-auth')`

### 5. 환경 변수
- **Before**: Supabase Edge Function Secrets
- **After**: Cloudflare Workers Secrets

---

## 완료 체크리스트

### Phase 1: Workers 함수 생성
- [ ] `workers/functions/naver-auth.ts` 생성
- [ ] Edge Function 코드 변환 (Deno → Node.js)
- [ ] Supabase 클라이언트 초기화 수정
- [ ] JWT 라이브러리 변경

### Phase 2: 라우팅 추가
- [ ] `workers/index.ts`에 `/api/naver-auth` 엔드포인트 추가
- [ ] `naver-auth.ts` import 및 호출

### Phase 3: 환경 변수 설정
- [ ] `NAVER_CLIENT_ID` 설정
- [ ] `NAVER_CLIENT_SECRET` 설정
- [ ] `NAVER_REDIRECT_URI` 설정
- [ ] `SUPABASE_URL` 설정
- [ ] `SUPABASE_SERVICE_ROLE_KEY` 설정
- [ ] `JWT_SECRET` 설정

### Phase 4: Flutter 서비스 수정
- [ ] `lib/services/naver_auth_service.dart` 수정
- [ ] Edge Function 호출 → Workers HTTP 호출로 변경
- [ ] Workers URL 설정

### Phase 5: 테스트
- [ ] 웹 네이버 로그인 테스트
- [ ] 모바일 네이버 로그인 테스트
- [ ] 기존 사용자 로그인 테스트
- [ ] 신규 사용자 플로우 테스트
- [ ] 에러 케이스 테스트

### Phase 6: 배포 및 검증
- [ ] Workers 배포
- [ ] 프로덕션 테스트
- [ ] Edge Function 제거 (선택사항)

---

## 참고 문서

- [상세 마이그레이션 가이드](./naver-auth-edge-function-to-workers-migration.md) - 코드 변경 상세 내용
- [Cloudflare Workers 문서](https://developers.cloudflare.com/workers/)
- [Supabase Admin API 문서](https://supabase.com/docs/reference/javascript/auth-admin-api)

