# 빠른 문제 해결 가이드 (Quick Fix Guide)

> ⚡ 문제 발생 시 빠르게 해결하기 위한 체크리스트

## 🔍 문제 진단

### 1️⃣ Supabase 연결 문제

**증상**: Supabase 연결 실패, 인증 오류

**빠른 해결**:
```bash
# 1. 실제 Supabase 키 확인
npx supabase status

# 2. 키를 복사해서 다음 파일들 업데이트:
#    - .dev.vars
#    - workers/.dev.vars  
#    - lib/config/supabase_config.dart
```

**체크리스트**:
- [ ] `npx supabase status` 실행 → 키 복사
- [ ] `.dev.vars`의 `SUPABASE_SERVICE_ROLE_KEY` 업데이트
- [ ] `supabase_config.dart`의 `supabaseAnonKey` 업데이트

---

### 2️⃣ Cloudflare Workers 실행 오류

**증상**: `npx wrangler dev` 실행 시 Account ID 불일치 에러

**빠른 해결**:
```bash
# 1. 현재 로그인된 계정 확인
npx wrangler whoami

# 2. wrangler.toml에 Account ID 추가
# account_id = "7b72031b240604b8e9f88904de2f127c"  # whoami에서 확인한 ID

# 3. 다시 실행
npx wrangler dev
```

**체크리스트**:
- [ ] `npx wrangler whoami` → Account ID 확인
- [ ] `wrangler.toml`에 `account_id = "..."` 추가
- [ ] `npx wrangler dev` 재실행

---

### 3️⃣ Cloudflare 잘못된 계정으로 로그인

**증상**: 잘못된 계정으로 로그인됨, 이전 계정이 계속 나타남

**빠른 해결**:
```bash
# 1. 로그아웃
npx wrangler logout

# 2. npm 캐시 정리
npm cache clean --force

# 3. 시크릿 모드로 브라우저 열고 재로그인
npx wrangler login
```

**체크리스트**:
- [ ] `npx wrangler logout`
- [ ] `npm cache clean --force`
- [ ] 브라우저 시크릿 모드에서 `npx wrangler login`
- [ ] `npx wrangler whoami`로 올바른 계정 확인

---

### 4️⃣ 환경 변수 인식 안 됨

**증상**: Workers에서 환경 변수를 읽지 못함

**빠른 해결**:
```bash
# 1. .dev.vars 파일 위치 확인
#    - wrangler.toml이 루트에 있으면 → 루트/.dev.vars 사용
#    - wrangler.toml이 workers/에 있으면 → workers/.dev.vars 사용

# 2. 환경 변수 형식 확인 (따옴표 없이, 공백 없이)
SUPABASE_URL=http://127.0.0.1:54500
GEMINI_API_KEY=AIzaSyC6tax_NkvdDC9G7Miy4_dXznqHc1HDA8g

# 3. wrangler dev 실행 시 출력 확인
npx wrangler dev
# "Using vars defined in ..\.dev.vars" 메시지 확인
```

**체크리스트**:
- [ ] `.dev.vars` 파일 위치 확인 (루트 vs workers/)
- [ ] 환경 변수 형식 확인 (따옴표, 공백 없음)
- [ ] `npx wrangler dev` 실행 시 환경 변수 목록 확인

---

## 📋 설정 파일 위치

| 파일 | 위치 | 용도 |
|------|------|------|
| `.dev.vars` | 루트 | Workers 환경 변수 (wrangler.toml이 루트에 있을 때) |
| `workers/.dev.vars` | workers/ | Workers 환경 변수 (wrangler.toml이 workers/에 있을 때) |
| `lib/config/supabase_config.dart` | lib/config/ | Flutter 앱 Supabase 설정 |
| `wrangler.toml` | 루트 | Cloudflare Workers 설정 |

---

## 🔧 자주 사용하는 명령어

```bash
# Supabase 상태 확인
npx supabase status

# Cloudflare 로그인 상태 확인
npx wrangler whoami

# Cloudflare 로그아웃
npx wrangler logout

# Cloudflare 로그인
npx wrangler login

# Workers 로컬 실행
npx wrangler dev

# Workers 로컬 실행 (API 호출 없음)
npx wrangler dev --local

# npm 캐시 정리
npm cache clean --force
```

---

## ⚡ 문제별 빠른 참조

### Supabase 키 형식
- **새 형식** (CLI v2.63.1+): `sb_publishable_...`, `sb_secret_...`
- **이전 형식**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
- **확인 방법**: `npx supabase status` 실행

### Account ID 확인
- **명령어**: `npx wrangler whoami`
- **위치**: `wrangler.toml`에 `account_id = "..."` 추가

### 환경 변수 형식
- ✅ **올바름**: `KEY=value` (공백 없음, 따옴표 없음)
- ❌ **잘못됨**: `KEY = value`, `KEY="value"`, `export KEY=value`

---

## 🆘 여전히 해결 안 되면

1. **상세 가이드 확인**: `docs/troubleshooting-guide.md`
2. **로그 확인**: 에러 메시지 전체 내용 확인
3. **캐시 정리**: `.wrangler` 디렉토리 삭제 (wrangler dev 종료 후)

---

**마지막 업데이트**: 2025-01-XX

