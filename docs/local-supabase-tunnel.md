# 로컬 Supabase를 외부에 노출하여 프로덕션 Workers에서 접근 가능하게 하기

## 방법 1: ngrok 사용 (권장)

### 1. ngrok 설치
```bash
# Windows (Chocolatey)
choco install ngrok

# 또는 직접 다운로드
# https://ngrok.com/download
```

### 2. 로컬 Supabase 터널링
```bash
ngrok http 54321
```

### 3. 생성된 ngrok URL 확인
ngrok이 실행되면 다음과 같은 출력이 나타납니다:
```
Forwarding  https://xxxx-xxxx-xxxx.ngrok-free.app -> http://localhost:54321
```

### 4. Workers에 ngrok URL 설정
```bash
# ngrok URL을 Workers에 설정 (예: https://xxxx-xxxx-xxxx.ngrok-free.app)
echo "https://xxxx-xxxx-xxxx.ngrok-free.app" | npx wrangler secret put SUPABASE_URL

# 로컬 Service Role Key는 그대로 사용
echo "sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz" | npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY
```

### 5. ngrok 무료 계정 제한
- 무료 계정은 URL이 매번 변경됩니다
- 매번 새로운 URL을 Workers에 설정해야 합니다

## 방법 2: Cloudflare Tunnel 사용 (더 안정적)

Cloudflare Tunnel을 사용하면 더 안정적인 URL을 얻을 수 있습니다.

### 1. Cloudflare Tunnel 설치
```bash
# Windows
choco install cloudflared
```

### 2. 로컬 Supabase 터널링
```bash
cloudflared tunnel --url http://127.0.0.1:54321
```

### 3. 생성된 URL 확인 및 Workers에 설정
터널이 실행되면 생성된 URL을 Workers에 설정합니다.

## 방법 3: 로컬 네트워크에서만 접근 가능한 경우

만약 로컬 네트워크에서만 접근 가능하다면:
- 프로덕션 Workers는 로컬 Supabase에 접근할 수 없습니다
- 대신 로컬 Workers를 실행해야 합니다: `npx wrangler dev`

## 현재 설정 요약

- **Supabase**: 로컬 (`http://127.0.0.1:54321`)
- **R2**: 프로덕션 (`smart-review-files`)
- **Workers**: 프로덕션 (`https://smart-review-api.nightkille.workers.dev`)

**문제**: 프로덕션 Workers는 로컬 Supabase에 접근할 수 없음
**해결**: ngrok 또는 Cloudflare Tunnel 사용

