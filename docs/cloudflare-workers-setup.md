# Cloudflare Workers 설정 가이드

이 가이드는 Smart Review App 프로젝트에서 Cloudflare Workers를 설정하고 사용하는 방법을 설명합니다.

## 목차
1. [필수 요구사항](#필수-요구사항)
2. [Wrangler CLI 설치](#wrangler-cli-설치)
3. [프로젝트 초기화](#프로젝트-초기화)
4. [환경 변수 설정](#환경-변수-설정)
5. [Workers 개발](#workers-개발)
6. [배포](#배포)
7. [R2 연동](#r2-연동)
8. [예제 코드](#예제-코드)

## 필수 요구사항

- Node.js 18 이상
- npm 또는 yarn
- Cloudflare 계정
- Cloudflare API 토큰

## Wrangler CLI 설치

### 1. 전역 설치 (권장)

```bash
npm install -g wrangler
```

### 2. 프로젝트 로컬 설치

```bash
npm install --save-dev wrangler
```

### 3. 버전 확인

```bash
wrangler --version
```

## 프로젝트 초기화

### 1. Workers 디렉토리 생성

프로젝트 루트에 `workers` 디렉토리를 생성합니다:

```bash
mkdir workers
cd workers
```

### 2. 새 Worker 프로젝트 초기화

```bash
npx wrangler init
```

또는 기존 프로젝트에 추가:

```bash
cd workers
npx wrangler init my-worker
```

### 3. wrangler.toml 설정 파일 생성

프로젝트 루트에 `wrangler.toml` 파일을 생성합니다:

```toml
name = "smart-review-api"
main = "workers/index.ts"
compatibility_date = "2024-01-01"

# 개발 환경 설정
[env.development]
name = "smart-review-api-dev"

# 프로덕션 환경 설정
[env.production]
name = "smart-review-api-prod"

# R2 버킷 바인딩
[[r2_buckets]]
binding = "FILES"
bucket_name = "smart-review-files"
preview_bucket_name = "smart-review-files-preview"

# 환경 변수 (비밀 정보는 wrangler secret으로 설정)
[vars]
ENVIRONMENT = "production"
```

## 환경 변수 설정

### 1. Cloudflare 인증

Cloudflare 계정에 로그인:

```bash
wrangler login
```

브라우저에서 인증을 완료합니다.

### 2. 비밀 정보 설정

비밀 정보는 `wrangler secret` 명령어로 설정합니다:

```bash
# R2 자격 증명 설정
wrangler secret put R2_ACCOUNT_ID
wrangler secret put R2_ACCESS_KEY_ID
wrangler secret put R2_SECRET_ACCESS_KEY

# Supabase 자격 증명 설정
wrangler secret put SUPABASE_URL
wrangler secret put SUPABASE_SERVICE_ROLE_KEY
```

각 명령어 실행 시 값을 입력하거나 파이프로 전달할 수 있습니다:

```bash
echo "your-secret-value" | wrangler secret put SECRET_NAME
```

### 3. 환경별 비밀 설정

개발 환경에 비밀 설정:

```bash
wrangler secret put R2_ACCOUNT_ID --env development
```

프로덕션 환경에 비밀 설정:

```bash
wrangler secret put R2_ACCOUNT_ID --env production
```

## Workers 개발

### 1. 기본 Worker 구조

`workers/index.ts` 파일을 생성합니다:

```typescript
export interface Env {
  FILES: R2Bucket;
  R2_ACCOUNT_ID: string;
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
  R2_BUCKET_NAME: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    
    // CORS 헤더 설정
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    // OPTIONS 요청 처리
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // 라우팅
    if (url.pathname === '/health') {
      return new Response(JSON.stringify({ status: 'ok' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (url.pathname === '/api/presigned-url' && request.method === 'POST') {
      return handlePresignedUrl(request, env);
    }

    return new Response('Not Found', { status: 404, headers: corsHeaders });
  },
};

async function handlePresignedUrl(request: Request, env: Env): Promise<Response> {
  // Presigned URL 생성 로직
  // (R2 연동 예제 참조)
  return new Response('Presigned URL', { status: 200 });
}
```

### 2. 로컬 개발 서버 실행

```bash
wrangler dev
```

기본적으로 `http://localhost:8787`에서 실행됩니다.

### 3. 특정 포트로 실행

```bash
wrangler dev --port 3002
```

### 4. 환경별 실행

```bash
# 개발 환경
wrangler dev --env development

# 프로덕션 환경
wrangler dev --env production
```

## 배포

### 1. 프로덕션 배포

```bash
wrangler deploy
```

### 2. 환경별 배포

```bash
# 개발 환경 배포
wrangler deploy --env development

# 프로덕션 환경 배포
wrangler deploy --env production
```

### 3. 배포 확인

배포 후 Cloudflare 대시보드에서 Workers 섹션을 확인하거나:

```bash
wrangler deployments list
```

### 4. Workers 도메인 확인

배포 후 Workers URL은 다음과 같습니다:
- `https://smart-review-api.your-subdomain.workers.dev`

또는 커스텀 도메인을 설정할 수 있습니다.

## R2 연동

### 1. R2 버킷 바인딩 확인

`wrangler.toml`에 R2 버킷 바인딩이 설정되어 있어야 합니다:

```toml
[[r2_buckets]]
binding = "FILES"
bucket_name = "smart-review-files"
```

### 2. R2 작업 예제

```typescript
export interface Env {
  FILES: R2Bucket;
}

// 파일 업로드
async function uploadFile(env: Env, key: string, data: ArrayBuffer): Promise<void> {
  await env.FILES.put(key, data);
}

// 파일 다운로드
async function getFile(env: Env, key: string): Promise<R2ObjectBody | null> {
  return await env.FILES.get(key);
}

// 파일 삭제
async function deleteFile(env: Env, key: string): Promise<void> {
  await env.FILES.delete(key);
}

// 파일 목록 조회
async function listFiles(env: Env, prefix?: string): Promise<R2Objects> {
  return await env.FILES.list({ prefix });
}
```

### 3. Presigned URL 생성 (R2 직접 접근)

R2에 직접 접근하여 Presigned URL을 생성하려면 AWS SDK 호환 API를 사용합니다:

```typescript
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

async function createPresignedUrl(
  env: Env,
  method: 'GET' | 'PUT',
  key: string,
  expiresIn: number = 3600
): Promise<string> {
  const s3Client = new S3Client({
    region: 'auto',
    endpoint: `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: env.R2_ACCESS_KEY_ID,
      secretAccessKey: env.R2_SECRET_ACCESS_KEY,
    },
  });

  const command = method === 'PUT'
    ? new PutObjectCommand({ Bucket: env.R2_BUCKET_NAME, Key: key })
    : new GetObjectCommand({ Bucket: env.R2_BUCKET_NAME, Key: key });

  return await getSignedUrl(s3Client, command, { expiresIn });
}
```

## 예제 코드

### 1. Presigned URL 생성 API

`workers/presigned-url.ts`:

```typescript
export async function handlePresignedUrl(request: Request, env: Env): Promise<Response> {
  try {
    const { fileName, userId, contentType, fileType, method = 'PUT' } = await request.json();

    // 파일 경로 생성
    const date = new Date();
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const timestamp = Date.now();
    
    const filePath = `${fileType}/${year}/${month}/${day}/${userId}_${timestamp}_${fileName}`;

    // Presigned URL 생성
    const expiresIn = method === 'GET' ? 3600 : 900; // GET: 1시간, PUT: 15분
    const presignedUrl = await createPresignedUrl(env, method, filePath, expiresIn);

    return new Response(
      JSON.stringify({
        success: true,
        url: presignedUrl,
        filePath,
        expiresIn,
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  }
}
```

### 2. 파일 업로드 API

`workers/upload.ts`:

```typescript
export async function handleUpload(request: Request, env: Env): Promise<Response> {
  try {
    const formData = await request.formData();
    const file = formData.get('file') as File;
    const userId = formData.get('userId') as string;
    const fileType = formData.get('fileType') as string;

    if (!file || !userId || !fileType) {
      return new Response('Missing required fields', { status: 400 });
    }

    // 파일 경로 생성
    const date = new Date();
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const timestamp = Date.now();
    
    const key = `${fileType}/${year}/${month}/${day}/${userId}_${timestamp}_${file.name}`;

    // R2에 업로드
    await env.FILES.put(key, file.stream(), {
      httpMetadata: {
        contentType: file.type,
      },
    });

    const publicUrl = `https://${env.R2_PUBLIC_URL}/${key}`;

    return new Response(
      JSON.stringify({
        success: true,
        url: publicUrl,
        key,
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  }
}
```

### 3. 완전한 예제

`workers/index.ts`:

```typescript
export interface Env {
  FILES: R2Bucket;
  R2_ACCOUNT_ID: string;
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
  R2_BUCKET_NAME: string;
  R2_PUBLIC_URL: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // OPTIONS 요청 처리
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Health check
    if (url.pathname === '/health') {
      return new Response(JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // API 라우팅
    if (url.pathname === '/api/presigned-url' && request.method === 'POST') {
      return handlePresignedUrl(request, env);
    }

    if (url.pathname === '/api/upload' && request.method === 'POST') {
      return handleUpload(request, env);
    }

    if (url.pathname.startsWith('/api/files/') && request.method === 'GET') {
      return handleGetFile(request, env);
    }

    return new Response('Not Found', { status: 404, headers: corsHeaders });
  },
};

async function handlePresignedUrl(request: Request, env: Env): Promise<Response> {
  // Presigned URL 생성 로직
  // (위 예제 참조)
  return new Response('Presigned URL', { status: 200 });
}

async function handleUpload(request: Request, env: Env): Promise<Response> {
  // 파일 업로드 로직
  // (위 예제 참조)
  return new Response('Upload', { status: 200 });
}

async function handleGetFile(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const key = url.pathname.replace('/api/files/', '');

  const object = await env.FILES.get(key);
  if (!object) {
    return new Response('File not found', { status: 404, headers: corsHeaders });
  }

  return new Response(object.body, {
    headers: {
      ...corsHeaders,
      'Content-Type': object.httpMetadata?.contentType || 'application/octet-stream',
    },
  });
}
```

## 패키지 설치

Workers에서 사용할 패키지가 필요하면 `package.json`에 추가합니다:

```bash
npm install --save-dev @aws-sdk/client-s3 @aws-sdk/s3-request-presigner
```

## 개발 워크플로우

1. **로컬 개발**
   ```bash
   wrangler dev
   ```

2. **테스트**
   ```bash
   curl http://localhost:8787/health
   ```

3. **배포**
   ```bash
   wrangler deploy
   ```

4. **로그 확인**
   ```bash
   wrangler tail
   ```

## 모니터링 및 로그

### 1. 실시간 로그 확인

```bash
wrangler tail
```

### 2. 특정 환경 로그 확인

```bash
wrangler tail --env development
```

### 3. Cloudflare 대시보드

Cloudflare 대시보드에서 Workers 메트릭, 로그, 분석을 확인할 수 있습니다.

## 문제 해결

### 1. 인증 오류

```bash
wrangler logout
wrangler login
```

### 2. 배포 오류

```bash
# 로그 확인
wrangler tail

# 환경 변수 확인
wrangler secret list
```

### 3. R2 접근 오류

- R2 버킷 바인딩 확인
- 비밀 정보 확인
- 버킷 이름 확인

## 참고 자료

- [Cloudflare Workers 문서](https://developers.cloudflare.com/workers/)
- [Wrangler CLI 문서](https://developers.cloudflare.com/workers/wrangler/)
- [Cloudflare R2 문서](https://developers.cloudflare.com/r2/)
- [Workers 예제](https://github.com/cloudflare/workers-examples)

