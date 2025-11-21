# Cloudflare Workers 빠른 시작 가이드

이 문서는 Smart Review App에서 Cloudflare Workers를 빠르게 시작하는 방법을 안내합니다.

## ✅ 완료된 설정

- ✅ Wrangler CLI 설치 완료
- ✅ 기본 Worker 코드 생성 (`workers/index.ts`)
- ✅ Wrangler 설정 파일 생성 (`wrangler.toml`)
- ✅ npm 스크립트 추가

## 🚀 다음 단계

### 1. Cloudflare 인증

Cloudflare 계정에 로그인합니다:

```bash
npx wrangler login
```

브라우저에서 인증을 완료하세요.

### 2. 비밀 정보 설정

다음 명령어로 R2 자격 증명을 설정합니다:

```bash
# R2 계정 ID
echo "7b72031b240604b8e9f88904de2f127c" | npx wrangler secret put R2_ACCOUNT_ID

# R2 Access Key ID
echo "e4db9133661a4317e540091157c49da7" | npx wrangler secret put R2_ACCESS_KEY_ID

# R2 Secret Access Key
echo "f8db6f7d4723f36252a12941f87e0df6110229a59afee113228b76b3f2aa2d1e" | npx wrangler secret put R2_SECRET_ACCESS_KEY

# R2 버킷 이름
echo "smart-review-files" | npx wrangler secret put R2_BUCKET_NAME

# R2 Public URL
echo "https://7b72031b240604b8e9f88904de2f127c.r2.cloudflarestorage.com" | npx wrangler secret put R2_PUBLIC_URL
```

Supabase 자격 증명도 설정해야 합니다 (필요시):

```bash
# Supabase URL (로컬 개발용)
echo "http://127.0.0.1:54500" | npx wrangler secret put SUPABASE_URL

# Supabase Service Role Key
npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY
# (값 입력 필요)
```

### 3. 로컬 개발 서버 실행

```bash
npm run workers:dev
```

또는 직접 실행:

```bash
npx wrangler dev
```

기본적으로 `http://localhost:8787`에서 실행됩니다.

### 4. 테스트

새 터미널에서:

```bash
# Health check
curl http://localhost:8787/health

# Presigned URL 생성 테스트
curl -X POST http://localhost:8787/api/presigned-url \
  -H "Content-Type: application/json" \
  -d '{
    "fileName": "test.jpg",
    "userId": "test-user-123",
    "contentType": "image/jpeg",
    "fileType": "profile_image"
  }'
```

### 5. 배포

개발 환경에 배포:

```bash
npm run workers:deploy:dev
```

프로덕션 환경에 배포:

```bash
npm run workers:deploy:prod
```

### 6. 로그 확인

실시간 로그 확인:

```bash
npm run workers:tail
```

## 📁 파일 구조

```
smart_review_app/
├── workers/
│   ├── index.ts          # Worker 메인 코드
│   └── package.json      # Worker 패키지 설정
├── wrangler.toml         # Wrangler 설정 파일
├── package.json          # 프로젝트 패키지 설정
└── docs/
    └── cloudflare-workers-setup.md  # 상세 가이드
```

## 🔧 주요 명령어

| 명령어 | 설명 |
|--------|------|
| `npm run workers:dev` | 로컬 개발 서버 실행 |
| `npm run workers:deploy` | 기본 환경에 배포 |
| `npm run workers:deploy:dev` | 개발 환경에 배포 |
| `npm run workers:deploy:prod` | 프로덕션 환경에 배포 |
| `npm run workers:tail` | 실시간 로그 확인 |
| `npx wrangler secret list` | 설정된 비밀 정보 확인 |
| `npx wrangler secret delete <NAME>` | 비밀 정보 삭제 |

## 📝 API 엔드포인트

### Health Check
```
GET /health
```

### Presigned URL 생성
```
POST /api/presigned-url
Content-Type: application/json

{
  "fileName": "test.jpg",
  "userId": "user-123",
  "contentType": "image/jpeg",
  "fileType": "profile_image",
  "method": "PUT"  // 선택사항: "GET" 또는 "PUT" (기본값: "PUT")
}
```

### 파일 업로드
```
POST /api/upload
Content-Type: multipart/form-data

file: <파일>
userId: <사용자 ID>
fileType: <파일 타입>
```

### 파일 조회
```
GET /api/files/<파일 경로>
```

## 🔍 문제 해결

### 인증 오류
```bash
npx wrangler logout
npx wrangler login
```

### 비밀 정보 확인
```bash
npx wrangler secret list
```

### 상세 로그 확인
```bash
npx wrangler tail --format pretty
```

## 📚 더 자세한 정보

자세한 설정 방법은 `docs/cloudflare-workers-setup.md` 파일을 참조하세요.

