# 네이버 로그인 Edge Function 트러블슈팅 가이드

## 🔍 문제: `/loading` 화면에서 멈춤

### 가능한 원인

#### 1. Edge Function이 배포되지 않음
**증상**: 브라우저 콘솔에 `Edge Function 호출 타임아웃` 또는 `404 Not Found` 에러

**해결 방법**:
```bash
# 로컬 Supabase 실행 확인
npx supabase status

# Edge Function 로컬 테스트
npx supabase functions serve naver-auth

# 프로덕션 배포
npx supabase functions deploy naver-auth
```

#### 2. 환경 변수가 설정되지 않음
**증상**: 브라우저 콘솔에 `NAVER_CLIENT_ID 또는 NAVER_CLIENT_SECRET이 설정되지 않았습니다` 에러

**해결 방법**:
```bash
# 로컬 환경 변수 설정
# supabase/functions/naver-auth/.env 파일 생성
SUPABASE_URL=http://127.0.0.1:54500
SUPABASE_SERVICE_ROLE_KEY=<service_role_key>
SUPABASE_JWT_SECRET=<jwt_secret>
NAVER_CLIENT_ID=<naver_client_id>
NAVER_CLIENT_SECRET=<naver_client_secret>
NAVER_REDIRECT_URI=http://localhost:3001/loading

# 또는 Supabase Secrets 사용
npx supabase secrets set NAVER_CLIENT_ID=<naver_client_id>
npx supabase secrets set NAVER_CLIENT_SECRET=<naver_client_secret>
```

#### 3. setSession 실패
**증상**: 브라우저 콘솔에 `⚠️ setSession 실패` 경고

**원인**: Custom JWT의 refreshToken은 Supabase 표준 refresh token이 아니므로 `setSession`이 실패할 수 있습니다.

**임시 해결 방법**:
- 세션 객체는 생성되지만 Supabase 클라이언트에 설정되지 않을 수 있습니다.
- 이 경우 `authStateChanges`가 트리거되지 않아 라우터가 리다이렉트하지 않을 수 있습니다.

**근본 해결 방법**:
- Edge Function에서 Supabase의 표준 refresh token을 생성하도록 수정 필요
- 또는 세션을 수동으로 관리하는 방법 고려

### 디버깅 체크리스트

1. **브라우저 콘솔 확인** (F12)
   - `📤 Edge Function 호출: naver-auth` 메시지 확인
   - `📥 Edge Function 응답: status=...` 메시지 확인
   - 에러 메시지 확인

2. **Edge Function 로그 확인**
   ```bash
   # 로컬 Supabase 로그 확인
   npx supabase functions logs naver-auth
   ```

3. **네트워크 탭 확인**
   - Edge Function 호출이 실제로 이루어지는지 확인
   - 응답 상태 코드 확인 (200, 400, 500 등)

### 빠른 테스트

1. **Edge Function 직접 호출 테스트**:
   ```bash
   curl -X POST http://127.0.0.1:54321/functions/v1/naver-auth \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <anon_key>" \
     -d '{"platform":"web","code":"test_code"}'
   ```

2. **환경 변수 확인**:
   ```bash
   # 로컬 Supabase 환경 변수 확인
   npx supabase secrets list
   ```

### 다음 단계

문제가 계속되면:
1. 브라우저 콘솔의 전체 에러 메시지를 확인
2. Edge Function 로그 확인
3. 네트워크 탭에서 실제 요청/응답 확인

