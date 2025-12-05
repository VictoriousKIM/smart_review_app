# 네이버 로그인 Edge Function → Cloudflare Workers 마이그레이션 가이드

## 📋 목차

1. [개요](#개요)
2. [현재 구조 (Edge Function)](#현재-구조-edge-function)
3. [목표 구조 (Cloudflare Workers)](#목표-구조-cloudflare-workers)
4. [주요 변경사항](#주요-변경사항)
5. [마이그레이션 단계](#마이그레이션-단계)
6. [코드 변경 상세](#코드-변경-상세)
7. [환경 변수 설정](#환경-변수-설정)
8. [테스트 방법](#테스트-방법)
9. [롤백 방법](#롤백-방법)

---

## 개요

네이버 로그인 인증 로직을 **Supabase Edge Function**에서 **Cloudflare Workers**로 마이그레이션하는 가이드입니다.

### 마이그레이션 이유

- **통합 관리**: 다른 API 엔드포인트(R2 업로드, 사업자등록증 검증 등)와 동일한 Workers에서 관리
- **성능**: Cloudflare의 글로벌 CDN 활용
- **비용**: Workers의 무료 티어 활용 가능
- **일관성**: 모든 외부 API를 Workers로 통합

---

## 현재 구조 (Edge Function)

### 아키텍처

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

### 현재 파일 구조

```
supabase/functions/naver-auth/
  └── index.ts          # Edge Function 메인 파일
```

### 현재 호출 방식

```dart
// lib/services/naver_auth_service.dart
final response = await _supabase.functions
    .invoke('naver-auth', body: {
      'platform': 'web',
      'code': code,
    });
```

### 현재 환경 변수 (Supabase)

```toml
# supabase/config.toml
[edge_runtime.secrets]
NAVER_CLIENT_ID = "..."
NAVER_CLIENT_SECRET = "..."
NAVER_REDIRECT_URI = "http://localhost:3001/loading"
JWT_SECRET = "..."  # Supabase JWT Secret
```

---

## 목표 구조 (Cloudflare Workers)

### 아키텍처

```
Flutter App
    ↓ (HTTP POST to Workers URL)
Cloudflare Workers (Node.js/TypeScript)
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

### 목표 호출 방식

```dart
// lib/services/naver_auth_service.dart
final response = await http.post(
  Uri.parse('https://workers-url.workers.dev/api/auth/naver'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'platform': 'web',
    'code': code,
  }),
);
```

---

## 주요 변경사항

### 1. 런타임 환경

| 항목 | Edge Function | Cloudflare Workers |
|------|--------------|-------------------|
| 런타임 | Deno | Node.js (Workers 런타임) |
| HTTP 서버 | `serve()` from Deno std | `fetch()` handler |
| 패키지 관리 | Deno imports (URL) | npm packages |
| 환경 변수 | `Deno.env.get()` | `env` object (Wrangler) |

### 2. Supabase 접근 방식

| 항목 | Edge Function | Cloudflare Workers |
|------|--------------|-------------------|
| Supabase URL | `http://kong:8000` (내부) | `SUPABASE_URL` (외부) |
| Service Role Key | 하드코딩 (로컬) | `SUPABASE_SERVICE_ROLE_KEY` (환경 변수) |
| JWT Secret | `JWT_SECRET` | `SUPABASE_JWT_SECRET` |

### 3. JWT 라이브러리

| 항목 | Edge Function | Cloudflare Workers |
|------|--------------|-------------------|
| 라이브러리 | `jose` (Deno) | `jose` (npm) 또는 `@tsndr/cloudflare-worker-jwt` |
| 설치 | Deno import | `npm install jose` |

### 4. Flutter 호출 방식

| 항목 | Edge Function | Cloudflare Workers |
|------|--------------|-------------------|
| 호출 방법 | `_supabase.functions.invoke()` | `http.post()` |
| URL | Supabase Functions URL | Workers URL |
| 인증 | Supabase SDK 자동 처리 | 수동 헤더 설정 (필요 시) |

---

## 마이그레이션 단계

### Phase 1: Workers 함수 생성

1. **Workers 함수 파일 생성**
   - `workers/functions/naver-auth.ts` 생성
   - Edge Function 코드를 Workers 형식으로 변환

2. **Workers 라우팅 추가**
   - `workers/index.ts`에 `/api/auth/naver` 라우트 추가

3. **의존성 설치**
   - JWT 라이브러리 설치 (`jose` 또는 `@tsndr/cloudflare-worker-jwt`)
   - Supabase JS 클라이언트는 이미 설치됨

### Phase 2: 환경 변수 설정

1. **Workers Secrets 설정**
   - `NAVER_CLIENT_ID`
   - `NAVER_CLIENT_SECRET`
   - `NAVER_REDIRECT_URI`
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `SUPABASE_JWT_SECRET`

2. **로컬 개발 설정**
   - `.dev.vars` 파일에 환경 변수 추가

### Phase 3: Flutter 코드 수정

1. **NaverAuthService 수정**
   - `_supabase.functions.invoke()` → `http.post()` 변경
   - Workers URL 사용

2. **에러 처리 수정**
   - Workers 응답 형식에 맞게 에러 처리 수정

### Phase 4: 테스트 및 배포

1. **로컬 테스트**
   - `wrangler dev`로 로컬 Workers 실행
   - Flutter 앱에서 로컬 Workers URL로 테스트

2. **프로덕션 배포**
   - `wrangler deploy`로 Workers 배포
   - Flutter 앱에서 프로덕션 Workers URL로 테스트

3. **Edge Function 제거**
   - 테스트 완료 후 `supabase/functions/naver-auth/` 삭제
   - Supabase secrets에서 네이버 관련 변수 제거 (선택사항)

---

## 코드 변경 상세

### 1. Workers 함수 생성 (`workers/functions/naver-auth.ts`)

```typescript
import { createClient } from '@supabase/supabase-js';
import * as jose from 'jose';

interface Env {
  NAVER_CLIENT_ID: string;
  NAVER_CLIENT_SECRET: string;
  NAVER_REDIRECT_URI: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  SUPABASE_JWT_SECRET: string;
}

interface RequestBody {
  platform: 'web' | 'mobile';
  accessToken?: string;
  code?: string;
  state?: string;
}

interface NaverUserInfo {
  id: string;
  email: string;
  name: string;
  profile_image: string;
  nickname: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// 웹용: 네이버 code → access_token 교환
async function exchangeCodeForToken(
  code: string,
  clientId: string,
  clientSecret: string,
  redirectUri: string
): Promise<string> {
  const response = await fetch('https://nid.naver.com/oauth2.0/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: clientId,
      client_secret: clientSecret,
      code: code,
      redirect_uri: redirectUri,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`네이버 토큰 교환 실패: ${response.status} - ${errorText}`);
  }

  const data = await response.json();

  if (data.error) {
    throw new Error(`네이버 토큰 교환 오류: ${data.error} - ${data.error_description}`);
  }

  if (!data.access_token) {
    throw new Error('네이버 access_token이 없습니다');
  }

  return data.access_token;
}

// 네이버 토큰으로 사용자 정보 조회
async function getNaverUserInfo(accessToken: string): Promise<NaverUserInfo> {
  const response = await fetch('https://openapi.naver.com/v1/nid/me', {
    headers: {
      'Authorization': `Bearer ${accessToken}`,
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`네이버 토큰 검증 실패: ${response.status} - ${errorText}`);
  }

  const data = await response.json();

  if (data.resultcode !== '00') {
    throw new Error(`네이버 사용자 정보 조회 실패: ${data.message || '알 수 없는 오류'}`);
  }

  return {
    id: data.response.id,
    email: data.response.email,
    name: data.response.name,
    profile_image: data.response.profile_image || '',
    nickname: data.response.nickname || data.response.name,
  };
}

// Supabase JWT 생성
async function createSupabaseJWT(
  userId: string,
  email: string,
  jwtSecret: string
): Promise<string> {
  const secretKey = new TextEncoder().encode(jwtSecret);
  const now = Math.floor(Date.now() / 1000);

  const token = await new jose.SignJWT({
    aud: 'authenticated',
    exp: now + (60 * 60 * 24), // 24시간
    iat: now,
    sub: userId,
    email: email,
    role: 'authenticated',
    app_metadata: {
      provider: 'naver',
      providers: ['naver'],
    },
    user_metadata: {},
  })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .sign(secretKey);

  return token;
}

export async function handleNaverAuth(
  request: Request,
  env: Env
): Promise<Response> {
  // CORS preflight
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body: RequestBody = await request.json();
    const { platform, accessToken, code, state } = body;

    if (!platform) {
      throw new Error('platform 파라미터가 필요합니다 (web 또는 mobile)');
    }

    let finalAccessToken: string;

    // 플랫폼별 토큰 처리
    if (platform === 'web' && code) {
      // 웹: Workers 내부에서 code → access_token 교환
      const clientId = env.NAVER_CLIENT_ID;
      const clientSecret = env.NAVER_CLIENT_SECRET;
      const redirectUri = env.NAVER_REDIRECT_URI;

      if (!clientId || !clientSecret) {
        throw new Error('NAVER_CLIENT_ID 또는 NAVER_CLIENT_SECRET이 설정되지 않았습니다');
      }

      finalAccessToken = await exchangeCodeForToken(code, clientId, clientSecret, redirectUri);
    } else if (platform === 'mobile' && accessToken) {
      // 모바일: 이미 받은 accessToken 사용
      finalAccessToken = accessToken;
    } else {
      throw new Error('웹의 경우 code가, 모바일의 경우 accessToken이 필요합니다');
    }

    // 1. 네이버에서 사용자 정보 가져오기
    const naverUser = await getNaverUserInfo(finalAccessToken);

    // 2. Supabase Admin 클라이언트 생성
    const supabaseUrl = env.SUPABASE_URL;
    const supabaseServiceKey = env.SUPABASE_SERVICE_ROLE_KEY;

    const supabaseAdmin = createClient(
      supabaseUrl,
      supabaseServiceKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // 3. 기존 사용자 조회 (이메일로)
    const { data: existingUsers } = await supabaseAdmin.auth.admin.listUsers();
    const existingUser = existingUsers?.users.find(u => u.email === naverUser.email);

    let userId: string;

    if (existingUser) {
      // 기존 사용자
      userId = existingUser.id;

      // user_metadata 업데이트
      await supabaseAdmin.auth.admin.updateUserById(userId, {
        user_metadata: {
          ...existingUser.user_metadata,
          full_name: naverUser.name,
          avatar_url: naverUser.profile_image,
          provider: 'naver',
          naver_id: naverUser.id,
        },
      });
    } else {
      // 4. 새 사용자 생성
      const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
        email: naverUser.email,
        email_confirm: true,
        user_metadata: {
          full_name: naverUser.name,
          avatar_url: naverUser.profile_image,
          provider: 'naver',
          naver_id: naverUser.id,
        },
        app_metadata: {
          provider: 'naver',
          providers: ['naver'],
        },
      });

      if (createError) {
        // 이메일 중복인 경우 기존 계정 연결
        if (createError.message.includes('already exists') || 
            createError.message.includes('already registered')) {
          const { data: retryUsers } = await supabaseAdmin.auth.admin.listUsers();
          const retryUser = retryUsers?.users.find(u => u.email === naverUser.email);
          
          if (retryUser) {
            userId = retryUser.id;
            await supabaseAdmin.auth.admin.updateUserById(userId, {
              user_metadata: {
                ...retryUser.user_metadata,
                full_name: naverUser.name,
                avatar_url: naverUser.profile_image,
                provider: 'naver',
                naver_id: naverUser.id,
              },
            });
          } else {
            throw createError;
          }
        } else {
          throw createError;
        }
      } else {
        if (!newUser?.user) {
          throw new Error('사용자 생성 실패: user 객체가 null입니다');
        }
        userId = newUser.user.id;
      }
    }

    // 5. public.users 테이블에 프로필 자동 생성하지 않음
    // 프로필이 없으면 Flutter 앱에서 회원가입 화면으로 리다이렉트됨

    // 6. Supabase JWT 생성
    const customJWT = await createSupabaseJWT(
      userId,
      naverUser.email,
      env.SUPABASE_JWT_SECRET
    );

    // 7. Refresh Token 생성 (선택사항 - UUID 기반)
    const refreshToken = crypto.randomUUID();

    return new Response(
      JSON.stringify({
        access_token: customJWT,
        refresh_token: refreshToken,
        token_type: 'bearer',
        expires_in: 86400, // 24시간
        user: {
          id: userId,
          email: naverUser.email,
          user_metadata: {
            full_name: naverUser.name,
            avatar_url: naverUser.profile_image,
          },
        },
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );

  } catch (error) {
    console.error('Workers 오류:', error);
    
    return new Response(
      JSON.stringify({ 
        error: error instanceof Error ? error.message : '알 수 없는 오류가 발생했습니다',
        details: error instanceof Error ? error.stack : String(error),
        type: error?.constructor?.name || typeof error,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: error instanceof Error && error.message.includes('설정되지 않았습니다') ? 500 : 400,
      }
    );
  }
}
```

### 2. Workers 라우팅 추가 (`workers/index.ts`)

```typescript
// workers/index.ts에 추가

import { handleNaverAuth } from './functions/naver-auth';

export interface Env {
  // ... 기존 환경 변수들 ...
  NAVER_CLIENT_ID: string;
  NAVER_CLIENT_SECRET: string;
  NAVER_REDIRECT_URI: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  SUPABASE_JWT_SECRET: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // OPTIONS 요청 처리
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // ... 기존 라우팅 ...

    // 네이버 로그인 API
    if (url.pathname === '/api/auth/naver' && request.method === 'POST') {
      return handleNaverAuth(request, env);
    }

    // ... 기존 라우팅 ...
  },
};
```

### 3. Flutter 코드 수정 (`lib/services/naver_auth_service.dart`)

```dart
// 기존 코드
final response = await _supabase.functions
    .invoke('naver-auth', body: body);

// 변경 후
import 'package:http/http.dart' as http;
import 'dart:convert';

// Workers URL (환경에 따라 변경)
const String workersUrl = 'https://smart-review-api.workers.dev'; // 프로덕션
// const String workersUrl = 'http://127.0.0.1:8787'; // 로컬 개발

final response = await http.post(
  Uri.parse('$workersUrl/api/auth/naver'),
  headers: {
    'Content-Type': 'application/json',
  },
  body: jsonEncode(body),
).timeout(
  const Duration(seconds: 30),
  onTimeout: () {
    throw Exception('Workers 호출 타임아웃 (30초 초과)');
  },
);

if (response.statusCode != 200) {
  final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
  final errorMessage = errorData?['error'] ?? '인증 실패';
  throw Exception(errorMessage);
}

final data = jsonDecode(response.body) as Map<String, dynamic>;
```

### 4. 의존성 설치

```bash
cd workers
npm install jose
```

---

## 환경 변수 설정

### 1. Workers Secrets 설정 (프로덕션)

```bash
# Cloudflare Workers Secrets 설정
wrangler secret put NAVER_CLIENT_ID
wrangler secret put NAVER_CLIENT_SECRET
wrangler secret put NAVER_REDIRECT_URI
wrangler secret put SUPABASE_URL
wrangler secret put SUPABASE_SERVICE_ROLE_KEY
wrangler secret put SUPABASE_JWT_SECRET
```

### 2. 로컬 개발 설정 (`.dev.vars`)

```bash
# workers/.dev.vars
NAVER_CLIENT_ID=your_naver_client_id
NAVER_CLIENT_SECRET=your_naver_client_secret
NAVER_REDIRECT_URI=http://localhost:3001/loading
SUPABASE_URL=http://127.0.0.1:54500  # 로컬 Supabase
# 또는 프로덕션 Supabase URL
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
SUPABASE_JWT_SECRET=your_jwt_secret
```

**⚠️ 주의**: `.dev.vars` 파일은 `.gitignore`에 추가되어 있어야 합니다.

### 3. `wrangler.toml` 업데이트 (선택사항)

```toml
# wrangler.toml
name = "smart-review-api"
main = "workers/index.ts"
compatibility_date = "2024-01-01"

# 환경 변수는 secrets로 관리하므로 vars에 추가하지 않음
# (민감한 정보는 secrets로만 관리)

[env.production]
name = "smart-review-api"
```

---

## 테스트 방법

### 1. 로컬 테스트

```bash
# Workers 로컬 실행
cd workers
npm run dev

# Flutter 앱에서 로컬 Workers URL 사용
# lib/services/naver_auth_service.dart
const String workersUrl = 'http://127.0.0.1:8787';
```

### 2. 프로덕션 테스트

```bash
# Workers 배포
cd workers
npm run deploy

# Flutter 앱에서 프로덕션 Workers URL 사용
# lib/services/naver_auth_service.dart
const String workersUrl = 'https://smart-review-api.workers.dev';
```

### 3. 테스트 체크리스트

- [ ] 웹 네이버 로그인 (Authorization Code Flow)
- [ ] 모바일 네이버 로그인 (Native SDK)
- [ ] 기존 사용자 로그인
- [ ] 신규 사용자 생성
- [ ] Custom JWT 생성 및 세션 설정
- [ ] 에러 처리 (잘못된 code, 만료된 토큰 등)
- [ ] CORS 설정 확인

---

## 롤백 방법

마이그레이션 후 문제가 발생하면 다음 단계로 롤백할 수 있습니다:

### 1. Flutter 코드 롤백

```dart
// Workers 호출 코드를 Edge Function 호출로 되돌림
final response = await _supabase.functions
    .invoke('naver-auth', body: body);
```

### 2. Edge Function 복원

```bash
# Git에서 Edge Function 복원
git checkout HEAD -- supabase/functions/naver-auth/
```

### 3. Supabase Secrets 복원

```bash
# Supabase secrets 재설정
npx supabase secrets set NAVER_CLIENT_ID=<value>
npx supabase secrets set NAVER_CLIENT_SECRET=<value>
npx supabase secrets set NAVER_REDIRECT_URI=<value>
npx supabase secrets set JWT_SECRET=<value>
```

---

## 주의사항

### 1. Supabase URL 차이

- **로컬 개발**: `http://127.0.0.1:54500` (Supabase 로컬 API)
- **프로덕션**: `https://your-project.supabase.co` (Supabase 프로덕션 API)

### 2. JWT Secret

- Edge Function에서는 `JWT_SECRET` 사용
- Workers에서는 `SUPABASE_JWT_SECRET` 사용 (동일한 값)
- Supabase 프로젝트 설정에서 JWT Secret 확인 가능

### 3. CORS 설정

- Workers에서 CORS 헤더를 올바르게 설정해야 함
- Flutter 웹 앱의 도메인을 `Access-Control-Allow-Origin`에 포함

### 4. 에러 처리

- Workers 응답 형식이 Edge Function과 동일해야 Flutter 코드 수정 최소화
- 에러 메시지 형식 통일

---

## 완료 체크리스트

- [ ] Workers 함수 생성 (`workers/functions/naver-auth.ts`)
- [ ] Workers 라우팅 추가 (`workers/index.ts`)
- [ ] JWT 라이브러리 설치 (`npm install jose`)
- [ ] Workers Secrets 설정 (프로덕션)
- [ ] `.dev.vars` 파일 설정 (로컬)
- [ ] Flutter 코드 수정 (`lib/services/naver_auth_service.dart`)
- [ ] 로컬 테스트 완료
- [ ] 프로덕션 배포 및 테스트 완료
- [ ] Edge Function 제거 (선택사항)
- [ ] 문서 업데이트

---

## 참고 자료

- [Cloudflare Workers 문서](https://developers.cloudflare.com/workers/)
- [Supabase Admin API 문서](https://supabase.com/docs/reference/javascript/auth-admin-api)
- [Jose JWT 라이브러리](https://github.com/panva/jose)
- [네이버 로그인 API 문서](https://developers.naver.com/docs/login/overview/)

