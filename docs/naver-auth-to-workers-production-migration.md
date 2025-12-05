# 네이버 소셜 로그인: Edge Function → Workers 프로덕션 전환 로드맵

**작성일**: 2025년 12월 05일  
**완료일**: 2025년 12월 05일  
**목적**: 로컬 Supabase Edge Function에서 Cloudflare Workers로 완전 전환

## 📋 전환 개요

### 현재 상태
- ✅ **로컬 개발**: Supabase Edge Function 사용 (`http://127.0.0.1:54500/functions/v1/naver-auth`)
- ❌ **프로덕션**: Workers 코드가 주석 처리되어 있음
- 📁 **파일 위치**:
  - Edge Function: `supabase/functions/naver-auth/index.ts` (삭제 예정)
  - Workers: `workers/functions/naver-auth.ts` (활성화 예정)

### 목표 상태
- ✅ **로컬 개발**: 프로덕션 Cloudflare Workers 사용 (`https://smart-review-api.nightkille.workers.dev/api/naver-auth`)
- ✅ **프로덕션**: Cloudflare Workers 사용 (`https://smart-review-api.nightkille.workers.dev/api/naver-auth`)
- 🗑️ **삭제**: `supabase/functions/naver-auth/` 디렉토리
- 💡 **설계**: 로컬/프로덕션 구분 없이 항상 프로덕션 Workers 사용 (간단하고 일관성 유지)

## 🔄 전환 단계

### 1단계: Flutter 코드 수정 ✅
**파일**: `lib/services/naver_auth_service.dart`

- [x] Edge Function 코드 주석 처리
- [x] Workers 코드 활성화
- [x] 주석 업데이트 (Edge Function → Workers)
- [x] `lib/config/supabase_config.dart` 주석 업데이트
- [x] `lib/config/app_router.dart` 주석 업데이트

### 2단계: 불필요한 파일 삭제 ✅
- [x] `supabase/functions/naver-auth/` 디렉토리 삭제 완료

### 3단계: 환경 변수 확인 ✅
**파일**: `workers/.dev.vars` (로컬 개발용) - 확인 완료
**Cloudflare Dashboard**: Workers Secrets (프로덕션용) - 확인 필요

필수 환경 변수:
- `NAVER_CLIENT_ID` ✅
- `NAVER_CLIENT_SECRET` ✅
- `NAVER_REDIRECT_URI` ✅
- `SUPABASE_URL` ✅
- `SUPABASE_SERVICE_ROLE_KEY` ✅
- `JWT_SECRET` ✅

### 4단계: Workers 배포 확인 ✅
- [x] `workers/index.ts`에서 `/api/naver-auth` 라우팅 확인 완료
- [ ] Workers 프로덕션 배포 확인 필요

### 5단계: 테스트 ⏳
- [ ] 프로덕션 Workers 테스트 (로컬 개발 환경에서도 프로덕션 Workers 사용)

## 📝 변경 사항

### 코드 변경 ✅
1. **`lib/services/naver_auth_service.dart`**
   - Edge Function 호출 코드 → Workers 호출 코드로 변경
   - URL: `http://127.0.0.1:54500/functions/v1/naver-auth` → `https://smart-review-api.nightkille.workers.dev/api/naver-auth`
   - 모든 주석에서 "Edge Function" → "Workers API"로 변경

2. **`lib/config/supabase_config.dart`**
   - 주석 업데이트: "네이버 로그인은 Edge Function 사용" → "네이버 로그인도 Workers 사용"

3. **`lib/config/app_router.dart`**
   - 디버그 메시지: "Edge Function 호출 시작" → "Workers API 호출 시작"

### 파일 삭제 ✅
1. **`supabase/functions/naver-auth/`** 디렉토리 전체 삭제 완료

## ⚠️ 주의사항

1. **환경 변수**: Workers Secrets에 모든 환경 변수가 설정되어 있는지 확인
   - `SUPABASE_URL`: 프로덕션 Supabase URL 사용 (또는 로컬 Supabase URL도 가능)
   - `SUPABASE_SERVICE_ROLE_KEY`: 해당 Supabase의 Service Role Key
2. **로컬 개발**: 별도의 로컬 Workers 서버 불필요 - 프로덕션 Workers 사용
3. **프로덕션 배포**: `wrangler deploy`로 Workers 배포 필요
4. **테스트**: 전환 후 반드시 로그인 플로우 테스트 수행
5. **Supabase 연결**: 
   - 로컬 개발 시 로컬 Supabase를 사용하려면 Workers Secrets의 `SUPABASE_URL`을 로컬 URL로 변경
   - 프로덕션 Supabase를 사용하려면 프로덕션 URL로 설정

## 🔗 관련 문서
- `docs/naver-auth-workers-final-status.md` - Workers 구현 상태
- `docs/naver-auth-workers-test-report.md` - Workers 테스트 결과

