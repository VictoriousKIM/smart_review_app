# 네이버 로그인 Edge Function 마이그레이션 결과 보고서

**작성일**: 2025년 12월 04일  
**작업 기간**: 2025년 12월 04일  
**마이그레이션 타입**: Cloudflare Workers → Supabase Edge Function + Custom JWT

---

## 📋 실행 요약

기존 Cloudflare Workers 기반 네이버 로그인 시스템을 Supabase Edge Function + Custom JWT 방식으로 성공적으로 마이그레이션했습니다. 보안을 강화하고 Supabase 생태계와의 통합을 개선했습니다.

---

## ✅ 완료된 작업

### Phase 1: 기존 코드 삭제 및 정리 ✅

#### 1.1 Cloudflare Workers 네이버 로그인 코드 삭제
- ✅ `workers/index.ts`: 네이버 로그인 콜백 라우팅 제거 (119-123줄 주석 처리)
- ✅ `workers/index.ts`: `NAVER_PROVIDER_LOGIN_SECRET` 환경 변수 제거 (58줄 주석 처리)
- ✅ `workers/functions/naver-login-callback.ts`: 파일 삭제

#### 1.2 Flutter 기존 네이버 로그인 로직 정리
- ✅ `lib/main.dart`: `NaverAuthService.startListeningForHashChange()` 호출 제거
- ✅ `lib/services/naver_auth_service.dart`: 전체 재작성 (아래 Phase 3 참조)

---

### Phase 2: Supabase Edge Function 구현 ✅

#### 2.1 Edge Function 디렉토리 생성
- ✅ `supabase/functions/naver-auth/` 디렉토리 생성

#### 2.2 Edge Function 코드 작성
- ✅ `supabase/functions/naver-auth/index.ts` 생성
- ✅ **주요 기능 구현**:
  - ✅ `exchangeCodeForToken()`: 웹용 code → access_token 교환 (보안 강화)
  - ✅ `getNaverUserInfo()`: 네이버 API로 사용자 정보 조회
  - ✅ `createSupabaseJWT()`: Supabase JWT 생성 (jose 라이브러리 사용)
  - ✅ 플랫폼별 분기 처리 (`platform: 'web' | 'mobile'`)
  - ✅ 기존 사용자 조회 및 업데이트
  - ✅ 새 사용자 생성 (`auth.admin.createUser`)
  - ✅ `public.users` 테이블 프로필 정보 저장
  - ✅ CORS 헤더 처리

#### 2.3 환경 변수 설정
- ✅ 필요한 환경 변수 문서화:
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `SUPABASE_JWT_SECRET` (중요!)
  - `NAVER_CLIENT_ID`
  - `NAVER_CLIENT_SECRET` (보안 필수!)
  - `NAVER_REDIRECT_URI` (선택사항)

**⚠️ 중요**: `NAVER_CLIENT_SECRET`은 Edge Function에서만 사용되며, Flutter 앱에는 포함되지 않습니다.

---

### Phase 3: Flutter 서비스 수정 ✅

#### 3.1 NaverAuthService 재작성
- ✅ `lib/services/naver_auth_service.dart` 완전 재작성
- ✅ **주요 변경사항**:
  - ✅ Edge Function 호출 방식으로 변경 (`supabase.functions.invoke()`)
  - ✅ 웹용: Authorization Code Flow 사용
  - ✅ **보안 강화**: `code`를 그대로 Edge Function에 전달 (토큰 교환은 서버에서)
  - ✅ 모바일용: 네이티브 SDK 사용 유지
  - ✅ `_exchangeNaverToken()` 메서드 구현 (플랫폼별 분기)

#### 3.2 새로운 메서드
- ✅ `signInWithNaverNative()`: 모바일 네이버 로그인
- ✅ `signInWithNaverWeb()`: 웹 네이버 로그인 (Authorization Code Flow)
- ✅ `handleNaverCallback()`: 웹 콜백 처리 (code → Edge Function)
- ✅ `_exchangeNaverToken()`: Edge Function 호출 및 세션 설정
- ✅ `isNaverLoggedIn()`: 네이버 로그인 상태 확인 (모바일)
- ✅ `getNaverAccessToken()`: 네이버 Access Token 가져오기 (모바일)

---

### Phase 4: 세션 관리 유틸리티 ⏭️

- ⏭️ **선택사항으로 보류**: Supabase SDK의 `setSession()`을 직접 사용하므로 별도 유틸리티 불필요

---

### Phase 5: 메인 로직 연결 ✅

#### 5.1 main.dart 수정
- ✅ `_checkNaverLoginStatus()` 함수 추가 (웹 환경용)
- ✅ 네이버 로그인 해시 변경 감지 제거

#### 5.2 LoadingScreen 수정
- ✅ `lib/widgets/loading_screen.dart` 재작성
- ✅ 웹 콜백 처리 로직 추가:
  - URL의 `code` 파라미터 추출
  - `NaverAuthService.handleNaverCallback()` 호출
  - 성공 시 홈으로 이동
  - 실패 시 로그인 화면으로 이동 및 에러 표시

---

## 🔒 보안 개선 사항

### 1. Client Secret 보호
- ✅ **이전**: Flutter 앱에 Client Secret 포함 (웹 빌드 시 노출 위험)
- ✅ **현재**: Edge Function 내부에서만 사용 (서버 사이드 처리)

### 2. 토큰 교환 위치 변경
- ✅ **이전**: Flutter 앱에서 직접 토큰 교환 (Client Secret 필요)
- ✅ **현재**: Edge Function에서 토큰 교환 (Client Secret 안전하게 관리)

### 3. Authorization Code Flow
- ✅ **이전**: Implicit Flow (해시로 토큰 수신)
- ✅ **현재**: Authorization Code Flow (더 안전한 방식)

---

## 📁 변경된 파일 목록

### 생성된 파일
1. `supabase/functions/naver-auth/index.ts` - Edge Function 메인 코드

### 수정된 파일
1. `workers/index.ts` - 네이버 로그인 라우팅 및 환경 변수 제거
2. `lib/services/naver_auth_service.dart` - 완전 재작성
3. `lib/services/auth_service.dart` - Workers API 사용 코드 제거 (`_signInWithNaverWeb`, `_handleNaverCallback` 메서드 삭제)
4. `lib/main.dart` - 네이버 로그인 상태 확인 로직 추가, 주석 처리된 코드 제거
5. `lib/widgets/loading_screen.dart` - 웹 콜백 처리 로직 추가

### 삭제된 파일
1. `workers/functions/naver-login-callback.ts` - 기존 Workers 코드 (삭제됨)

---

## 🚀 배포 전 체크리스트

### Edge Function 환경 변수 설정
- [ ] 로컬 개발 환경 변수 설정
  ```bash
  # supabase/functions/naver-auth/.env 또는 Supabase Secrets
  SUPABASE_URL=http://127.0.0.1:54500
  SUPABASE_SERVICE_ROLE_KEY=<service_role_key>
  SUPABASE_JWT_SECRET=<jwt_secret>
  NAVER_CLIENT_ID=<naver_client_id>
  NAVER_CLIENT_SECRET=<naver_client_secret>
  NAVER_REDIRECT_URI=http://localhost:3001/loading
  ```

- [ ] 프로덕션 환경 변수 설정
  ```bash
  npx supabase secrets set SUPABASE_JWT_SECRET=<jwt_secret>
  npx supabase secrets set SUPABASE_URL=<production_url>
  npx supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<service_role_key>
  npx supabase secrets set NAVER_CLIENT_ID=<naver_client_id>
  npx supabase secrets set NAVER_CLIENT_SECRET=<naver_client_secret>
  npx supabase secrets set NAVER_REDIRECT_URI=<production_redirect_uri>
  ```

### Edge Function 배포
- [ ] 로컬 테스트
  ```bash
  npx supabase functions serve naver-auth
  ```

- [ ] 프로덕션 배포
  ```bash
  npx supabase functions deploy naver-auth
  ```

### 네이버 개발자 센터 설정 확인
- [ ] 웹 Callback URL 설정
  - 로컬: `http://localhost:3001/loading`
  - 프로덕션: `https://your-domain.com/loading`
- [ ] 모바일 앱 설정 확인 (패키지명, Bundle ID, Hash Key)

---

## ⚠️ 알려진 이슈 및 제한사항

### 1. Refresh Token 처리
- **이슈**: Edge Function에서 생성한 Refresh Token은 Supabase의 표준 Refresh Token이 아님
- **영향**: 자동 갱신이 작동하지 않을 수 있음
- **해결책**: 앱 재시작 시 네이버 토큰으로 새 JWT 발급 (모바일만 가능)

### 2. 세션 만료 처리
- **이슈**: Custom JWT 만료 시 (24시간) 자동 갱신 불가
- **영향**: 사용자가 24시간 후 재로그인 필요
- **해결책**: 
  - 모바일: 앱 재시작 시 네이버 토큰으로 새 JWT 발급
  - 웹: 재로그인 필요

### 3. 린터 경고
- `lib/main.dart`: 딥링크 처리 부분에 Dead code 경고 (네이버 로그인과 무관)
- `lib/services/naver_auth_service.dart`: 모든 오류 수정 완료

---

## 🧪 테스트 필요 항목

### 로컬 테스트
- [ ] 모바일 네이버 로그인 테스트
- [ ] 웹 네이버 로그인 테스트
- [ ] 세션 복원 테스트 (앱 재시작)
- [ ] 로그아웃 테스트
- [ ] 에러 처리 테스트 (네이버 로그인 실패 시)

### 프로덕션 테스트
- [ ] Edge Function 배포 확인
- [ ] 환경 변수 설정 확인
- [ ] 전체 플로우 테스트
- [ ] 보안 검증 (Client Secret 노출 여부 확인)

---

## 📊 마이그레이션 전후 비교

| 항목 | 이전 (Workers) | 현재 (Edge Function) |
|------|---------------|---------------------|
| **인증 방식** | 고정 비밀번호 + `signInWithPassword` | Custom JWT 직접 생성 |
| **토큰 교환 위치** | Flutter 앱 (Client Secret 노출 위험) | Edge Function (서버 사이드) |
| **보안** | ⚠️ Client Secret 노출 가능 | ✅ Client Secret 안전하게 관리 |
| **OAuth Flow** | Implicit Flow (해시) | Authorization Code Flow |
| **세션 관리** | Supabase 표준 세션 | Custom JWT 세션 |
| **자동 갱신** | ✅ 가능 | ⚠️ 제한적 (앱 재시작 필요) |

---

## 🎯 다음 단계

1. **환경 변수 설정**: Edge Function 환경 변수 설정 (로컬 및 프로덕션)
2. **Edge Function 배포**: 로컬 테스트 후 프로덕션 배포
3. **테스트**: 전체 플로우 테스트 및 에러 처리 검증
4. **모니터링**: 프로덕션 배포 후 로그 모니터링
5. **문서화**: 운영 가이드 작성 (필요시)

---

## 📚 참고 자료

- [로드맵 문서](./naver-auth-edge-function-migration-roadmap.md)
- [Supabase Edge Functions 문서](https://supabase.com/docs/guides/functions)
- [네이버 로그인 API 가이드](https://developers.naver.com/docs/login/overview/)

---

## ✅ 마이그레이션 완료 확인

- [x] Phase 1: 기존 코드 삭제 및 정리
- [x] Phase 2: Supabase Edge Function 구현
- [x] Phase 3: Flutter 서비스 수정
- [x] Phase 4: 세션 관리 유틸리티 (선택사항, 보류)
- [x] Phase 5: 메인 로직 연결
- [ ] 환경 변수 설정 및 배포
- [ ] 테스트 및 검증

---

**마이그레이션 상태**: ✅ **코드 구현 완료** (배포 및 테스트 대기 중)

