# 네이버 로그인 Edge Function + Custom JWT 마이그레이션 로드맵

**작성일**: 2025년 1월 28일  
**목표**: 기존 Cloudflare Workers 기반 네이버 로그인을 Supabase Edge Function + Custom JWT 방식으로 전환

---

## 📋 전체 작업 단계

### Phase 1: 기존 코드 삭제 및 정리
### Phase 2: Supabase Edge Function 구현
### Phase 3: Flutter 서비스 수정
### Phase 4: 세션 관리 유틸리티 추가
### Phase 5: 메인 로직 연결 및 테스트

---

## Phase 1: 기존 코드 삭제 및 정리

### 1.1 Cloudflare Workers 네이버 로그인 코드 삭제

**파일**: `workers/functions/naver-login-callback.ts`
- [x] 파일 삭제 완료

**파일**: `workers/index.ts`
- [ ] 네이버 로그인 콜백 라우팅 제거 (119-123줄)
- [ ] `NAVER_PROVIDER_LOGIN_SECRET` 환경 변수 제거 (58줄)

### 1.2 Flutter 기존 네이버 로그인 로직 정리

**파일**: `lib/services/naver_auth_service.dart`
- [ ] 기존 Workers API 호출 로직 제거
- [ ] 해시 변경 감지 로직 제거 (웹용)
- [ ] `handleNaverCallback` 메서드 수정 준비

**파일**: `lib/main.dart`
- [ ] `NaverAuthService.startListeningForHashChange()` 호출 제거 (18-20줄)

**파일**: `lib/services/auth_service.dart`
- [ ] `signInWithNaver` 메서드 수정 준비 (375-393줄)

---

## Phase 2: Supabase Edge Function 구현

### 2.1 Edge Function 디렉토리 생성

```bash
# supabase/functions/naver-auth 디렉토리 생성
mkdir -p supabase/functions/naver-auth
```

### 2.2 Edge Function 코드 작성

**파일**: `supabase/functions/naver-auth/index.ts`
- [ ] Edge Function 메인 코드 작성
  - **플랫폼별 요청 처리** (웹/앱 분기)
  - 네이버 토큰 검증/교환
  - 사용자 정보 조회
  - Supabase 사용자 생성/조회
  - Custom JWT 생성
  - Refresh Token 생성

**요청 Body 파싱**:
```typescript
interface RequestBody {
  platform: 'web' | 'mobile';  // 플랫폼 구분
  accessToken?: string;         // 모바일: 네이버 SDK에서 받은 토큰
  code?: string;                // 웹: 네이버 OAuth code
  state?: string;               // 웹: OAuth state (선택사항)
}
```

**주요 기능**:
- [ ] `exchangeCodeForToken()` - **웹용**: 네이버 code → access_token 교환
  - Edge Function 내부에서 `NAVER_CLIENT_SECRET` 사용 (보안)
  - `https://nid.naver.com/oauth2.0/token` API 호출
- [ ] `getNaverUserInfo()` - 네이버 API로 사용자 정보 조회
  - `accessToken`으로 `https://openapi.naver.com/v1/nid/me` 호출
- [ ] `createSupabaseJWT()` - Supabase JWT 생성 (jose 라이브러리 사용)
- [ ] 기존 사용자 조회 (`profiles` 테이블의 `naver_id`로)
- [ ] 새 사용자 생성 (`auth.admin.createUser`)
- [ ] `profiles` 테이블 업데이트
  - **프로필 이미지 동기화**: `profile_image`를 `profiles.avatar_url`에 저장
  - `auth.users.user_metadata.avatar_url`에도 저장
- [ ] CORS 헤더 처리

**플로우 분기 처리**:
```typescript
// 슈도 코드
const { platform, accessToken, code } = await req.json();
let finalAccessToken: string;

if (platform === 'web' && code) {
  // 웹: Edge Function 내부에서 code → access_token 교환
  const clientSecret = Deno.env.get('NAVER_CLIENT_SECRET');
  finalAccessToken = await exchangeCodeForToken(code, clientSecret);
} else if (platform === 'mobile' && accessToken) {
  // 모바일: 이미 받은 accessToken 사용
  finalAccessToken = accessToken;
} else {
  throw new Error('Invalid request: platform and token/code required');
}

// 이후 로직은 공통 (finalAccessToken 사용)
const naverUser = await getNaverUserInfo(finalAccessToken);
// ... 사용자 생성/조회, JWT 발급 등
```

### 2.3 환경 변수 설정

**로컬 개발**:
```bash
# supabase/functions/naver-auth/.env 파일 생성 (선택사항)
# 또는 supabase secrets 사용
```

**필요한 환경 변수**:
- [ ] `SUPABASE_URL` - Supabase 프로젝트 URL
- [ ] `SUPABASE_SERVICE_ROLE_KEY` - Service Role Key
- [ ] `SUPABASE_JWT_SECRET` - JWT 서명용 Secret (중요!)
- [ ] `NAVER_CLIENT_ID` - 네이버 Client ID (웹용 토큰 교환)
- [ ] `NAVER_CLIENT_SECRET` - **네이버 Client Secret (웹용 토큰 교환, 보안 필수!)**
  - ⚠️ **절대 Flutter 앱에 포함하지 말 것** (웹 빌드 시 노출됨)
  - Edge Function 내부에서만 사용

**JWT Secret 확인 방법**:
```bash
# 로컬 Supabase JWT Secret 확인
npx supabase status

# 또는 프로덕션의 경우 Supabase Dashboard > Settings > API > JWT Secret
```

**로컬 환경 변수 설정**:
```bash
# supabase/functions/naver-auth/.env 파일에 추가
SUPABASE_URL=http://127.0.0.1:54500
SUPABASE_SERVICE_ROLE_KEY=<service_role_key>
SUPABASE_JWT_SECRET=<jwt_secret>
NAVER_CLIENT_ID=<naver_client_id>
NAVER_CLIENT_SECRET=<naver_client_secret>  # ⚠️ 보안: 절대 Git에 커밋하지 말 것
```

**또는 Supabase Secrets 사용 (권장)**:
```bash
# 로컬 Supabase Secrets 설정
npx supabase secrets set NAVER_CLIENT_ID=<naver_client_id>
npx supabase secrets set NAVER_CLIENT_SECRET=<naver_client_secret>
```

### 2.4 Edge Function 배포

**로컬 테스트**:
```bash
# 로컬 Supabase 실행 중인지 확인
npx supabase status

# Edge Function 로컬 테스트
npx supabase functions serve naver-auth
```

**프로덕션 배포**:
```bash
# 프로덕션에 배포
npx supabase functions deploy naver-auth

# 환경 변수 설정 (프로덕션)
npx supabase secrets set SUPABASE_JWT_SECRET=<jwt_secret>
npx supabase secrets set SUPABASE_URL=<production_url>
npx supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<service_role_key>
npx supabase secrets set NAVER_CLIENT_ID=<naver_client_id>
npx supabase secrets set NAVER_CLIENT_SECRET=<naver_client_secret>  # ⚠️ 보안 필수
```

---

## Phase 3: Flutter 서비스 수정

### 3.1 NaverAuthService 재작성

**파일**: `lib/services/naver_auth_service.dart`

**주요 변경사항**:
- [ ] Edge Function 호출 방식으로 변경
  - `supabase.functions.invoke('naver-auth')` 사용
- [ ] 웹용 네이버 로그인 수정
  - Authorization Code Flow 사용 (Implicit Flow 대신)
  - **보안**: `code`를 그대로 Edge Function에 전달 (토큰 교환은 Edge Function에서 수행)
  - ⚠️ **절대 Flutter에서 직접 토큰 교환하지 않음** (Client Secret 노출 방지)
- [ ] 모바일용 네이버 로그인 유지
  - `flutter_naver_login` 패키지 사용
  - 네이버 SDK에서 받은 `accessToken`을 Edge Function에 전달
- [ ] `_exchangeNaverToken()` 메서드 구현
  - Edge Function 호출 (platform 파라미터 포함)
  - 받은 JWT로 Supabase 세션 설정
  - `setSession()` 사용

**새로운 메서드**:
- [ ] `signInWithNaverNative()` - 모바일 네이버 로그인
  - 네이버 SDK로 로그인 → `accessToken` 획득
  - `_exchangeNaverToken(accessToken: token, platform: 'mobile')` 호출
- [ ] `signInWithNaverWeb()` - 웹 네이버 로그인 (Authorization Code Flow)
  - 네이버 로그인 페이지로 리다이렉트
  - 콜백 URL에서 `code` 획득
  - `_exchangeNaverToken(code: code, platform: 'web')` 호출
- [ ] `handleNaverCallback()` - 웹 콜백 처리
  - URL의 `code` 파라미터 추출
  - `_exchangeNaverToken(code: code, platform: 'web')` 호출
- [ ] `_exchangeNaverToken()` - Edge Function 호출 및 세션 설정
  - `platform` 파라미터로 웹/모바일 구분
  - 웹: `{ platform: 'web', code: code }` 전달
  - 모바일: `{ platform: 'mobile', accessToken: accessToken }` 전달
  - Edge Function 응답의 JWT로 세션 설정

### 3.2 네이버 OAuth 설정 확인

**네이버 개발자 센터**:
- [ ] 앱 설정 확인
  - 패키지명 (Android)
  - Bundle ID (iOS)
  - Hash Key (Android)
- [ ] 웹 설정 확인
  - Callback URL: `http://localhost:3001/loading` (로컬)
  - Callback URL: `https://your-domain.com/loading` (프로덕션)

**환경 변수 설정** (Flutter):
- [ ] `NAVER_CLIENT_ID` - 네이버 Client ID (웹용 OAuth URL 생성)
- [ ] `NAVER_REDIRECT_URI` - 리다이렉트 URI
- ⚠️ **`NAVER_CLIENT_SECRET`은 절대 Flutter에 포함하지 않음**
  - 웹 빌드 시 JavaScript 코드에 노출되어 보안 위험
  - Edge Function 내부에서만 사용

---

## Phase 4: 세션 관리 유틸리티 추가

### 4.1 Custom Session Manager 생성

**파일**: `lib/services/custom_session_manager.dart` (새로 생성)

**기능**:
- [ ] 세션 저장 (SharedPreferences)
- [ ] 세션 복원
- [ ] 세션 삭제
- [ ] 인증 헤더 가져오기

**주의사항**:
- Supabase SDK의 `setSession()`을 사용하는 것이 더 권장됨
- Custom Session Manager는 선택사항 (필요시에만 사용)

---

## Phase 5: 메인 로직 연결 및 테스트

### 5.1 main.dart 수정

**파일**: `lib/main.dart`

**변경사항**:
- [ ] `_checkLoginStatus()` 메서드 추가
  - 앱 시작 시 네이버 로그인 상태 확인
  - 네이버 토큰이 있으면 Edge Function 호출하여 세션 복원
- [ ] 웹 콜백 처리 로직 추가
  - URL의 `code` 파라미터 확인
  - `handleNaverCallback()` 호출
- [ ] 로딩 화면 추가
  - 세션 복원 중 로딩 표시

### 5.2 로그인 화면 수정

**파일**: `lib/screens/login_screen.dart` (또는 해당 파일)

**변경사항**:
- [ ] 네이버 로그인 버튼 동작 확인
- [ ] 플랫폼별 분기 처리 (웹/모바일)

### 5.3 테스트

**로컬 테스트**:
- [ ] 모바일 네이버 로그인 테스트
- [ ] 웹 네이버 로그인 테스트
- [ ] 세션 복원 테스트 (앱 재시작)
- [ ] 로그아웃 테스트

**프로덕션 테스트**:
- [ ] Edge Function 배포 확인
- [ ] 환경 변수 설정 확인
- [ ] 전체 플로우 테스트

---

## 🔧 기술 스택 및 의존성

### Edge Function
- Deno Runtime
- `@supabase/supabase-js` - Supabase 클라이언트
- `jose` - JWT 생성/서명

### Flutter
- `supabase_flutter` - Supabase 클라이언트
- `flutter_naver_login` - 네이버 네이티브 로그인 (모바일)
- `url_launcher` - 웹 브라우저 열기 (웹, 선택사항)
- ⚠️ **`http` 패키지는 웹용 토큰 교환에 사용하지 않음** (보안상 Edge Function에서 처리)

---

## ⚠️ 주의사항

### 1. 🚨 보안: Client Secret 관리 (최우선)
- **`NAVER_CLIENT_SECRET`은 절대 Flutter 앱에 포함하지 않음**
  - 웹 빌드 시 JavaScript 번들에 포함되어 브라우저에서 노출됨
  - 타인이 내 앱인 척 네이버 API를 호출할 수 있음
- **Edge Function 내부에서만 사용**
  - Supabase Secrets 또는 환경 변수로 관리
  - Git에 커밋하지 않기
- **웹 로그인 플로우**:
  - Flutter: `code` 획득 → Edge Function에 전달
  - Edge Function: `code` + `NAVER_CLIENT_SECRET` → `access_token` 교환
  - 이후 로직은 공통 처리

### 2. JWT Secret 보안
- **절대 Git에 커밋하지 않기**
- 환경 변수 또는 Supabase Secrets 사용
- 로컬과 프로덕션의 JWT Secret이 다를 수 있음

### 3. Refresh Token 처리
- Edge Function에서 생성한 Refresh Token은 Supabase의 표준 Refresh Token이 아님
- 자동 갱신이 작동하지 않을 수 있음
- 대안: 앱 재시작 시 네이버 토큰으로 새 JWT 발급

### 4. 세션 만료 처리
- Custom JWT 만료 시 (24시간)
- `main.dart`의 `_checkLoginStatus()`에서 네이버 토큰으로 새 JWT 발급
- 네이버 토큰도 만료된 경우 재로그인 필요

### 5. 웹 vs 모바일
- **웹**: Authorization Code Flow 사용
  - `code`를 Edge Function에 전달 (토큰 교환은 서버에서)
  - 보안상 가장 안전한 방식
- **모바일**: 네이티브 SDK 사용
  - `accessToken`을 Edge Function에 전달
  - 사용자 경험 향상

### 6. 프로필 이미지 동기화
- 네이버에서 받은 `profile_image`를 다음 두 곳에 저장:
  1. `auth.users.user_metadata.avatar_url` - Supabase Auth 메타데이터
  2. `public.profiles.avatar_url` - 앱에서 접근하기 쉬운 공개 테이블
- 이유: `auth` 스키마는 접근이 제한적이므로, 앱에서 프로필 사진을 보여줄 때는 `profiles` 테이블을 읽는 것이 일반적

---

## 📝 체크리스트 요약

### 삭제할 코드
- [x] `workers/functions/naver-login-callback.ts` (삭제 완료)
- [ ] `workers/index.ts`의 네이버 로그인 라우팅
- [ ] `lib/services/naver_auth_service.dart`의 Workers API 호출
- [ ] `lib/main.dart`의 해시 변경 감지

### 생성할 파일
- [ ] `supabase/functions/naver-auth/index.ts`
- [ ] `lib/services/custom_session_manager.dart` (선택사항)

### 수정할 파일
- [ ] `lib/services/naver_auth_service.dart` (전면 수정)
- [ ] `lib/main.dart` (세션 복원 로직 추가)
- [ ] `lib/services/auth_service.dart` (호출 방식 변경)

### 설정
- [ ] Edge Function 환경 변수 설정
  - `SUPABASE_JWT_SECRET` (필수)
  - `NAVER_CLIENT_ID` (필수)
  - `NAVER_CLIENT_SECRET` (필수, 보안)
- [ ] 네이버 개발자 센터 설정 확인
- [ ] Flutter 환경 변수 설정
  - `NAVER_CLIENT_ID` (OAuth URL 생성용)
  - ⚠️ `NAVER_CLIENT_SECRET`은 포함하지 않음

---

## 🚀 배포 순서

1. **로컬 개발 환경**
   - Edge Function 로컬 테스트
   - Flutter 앱 로컬 테스트

2. **프로덕션 배포**
   - Edge Function 배포
   - 환경 변수 설정
   - Flutter 앱 빌드 및 배포

3. **검증**
   - 전체 플로우 테스트
   - 에러 로그 확인
   - 사용자 피드백 수집

---

## 📚 참고 자료

- [Supabase Edge Functions 문서](https://supabase.com/docs/guides/functions)
- [Supabase Auth Admin API](https://supabase.com/docs/reference/javascript/auth-admin)
- [네이버 로그인 API 가이드](https://developers.naver.com/docs/login/overview/)
- [JWT 생성 (jose 라이브러리)](https://github.com/panva/jose)

---

---

## 🔒 보안 체크리스트

마이그레이션 전/후 반드시 확인:

- [ ] `NAVER_CLIENT_SECRET`이 Flutter 코드에 포함되어 있지 않음
- [ ] `NAVER_CLIENT_SECRET`이 Git에 커밋되지 않음
- [ ] Edge Function에서만 `NAVER_CLIENT_SECRET` 사용
- [ ] 웹 빌드 시 JavaScript 번들에 Secret이 포함되지 않음
- [ ] 프로덕션 환경 변수가 올바르게 설정됨

---

**다음 단계**: Phase 1부터 순차적으로 진행하세요.

