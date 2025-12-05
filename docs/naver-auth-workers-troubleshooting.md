# 네이버 로그인 Workers 마이그레이션 문제 해결 보고서

**작성일**: 2025년 1월 28일

---

## 📋 현재 상황

### ✅ 완료된 작업

1. ✅ **Workers 함수 생성 및 배포**
   - `workers/functions/naver-auth.ts` 생성
   - Edge Function 로직을 Workers로 마이그레이션 완료
   - Workers 배포 완료: `https://smart-review-api.nightkille.workers.dev`

2. ✅ **Flutter 서비스 수정**
   - `lib/services/naver_auth_service.dart` 수정
   - Edge Function 호출 → Workers HTTP 호출로 변경

3. ✅ **Workers Secrets 설정**
   - `NAVER_CLIENT_ID`: `Gx2IIkdRCTg32kobQj7J` ✅
   - `NAVER_CLIENT_SECRET`: `mlb3W9kKWE` ✅ (재설정 완료)
   - `NAVER_REDIRECT_URI`: `http://localhost:3001/loading` ✅
   - `JWT_SECRET`: 설정 완료 ✅

4. ✅ **코드 수정**
   - Edge Function과 동일하게 `exchangeCodeForToken` 함수 수정
   - Edge Function과 동일한 네이버 API 호출 방식 적용

---

## 🔴 현재 문제

**에러 메시지**: `invalid_request - wrong client id / client secret pair`

**발생 위치**: Workers에서 네이버 토큰 교환 시

**상태**: 
- Workers Secrets 재설정 완료
- Workers 재배포 완료
- 네이버 개발자 센터에서 값 확인 완료
- Edge Function과 동일하게 코드 수정 완료
- **여전히 동일한 에러 발생**

**참고**: Edge Function은 정상 동작 중

---

## 🔍 문제 분석

### 1. 환경 변수 값 확인

**Edge Function (정상 동작)**:
- `supabase/config.toml`:
  - `NAVER_CLIENT_ID = "Gx2IIkdRCTg32kobQj7J"`
  - `NAVER_CLIENT_SECRET = "mlb3W9kKWE"`
  - `NAVER_REDIRECT_URI = "http://localhost:3001/loading"`

**Workers (에러 발생)**:
- `workers/.dev.vars`:
  - `NAVER_CLIENT_ID=Gx2IIkdRCTg32kobQj7J`
  - `NAVER_CLIENT_SECRET=mlb3W9kKWE`
  - `NAVER_REDIRECT_URI=http://localhost:3001/loading`
- Workers Secrets:
  - `NAVER_CLIENT_ID`: `Gx2IIkdRCTg32kobQj7J` ✅
  - `NAVER_CLIENT_SECRET`: `mlb3W9kKWE` ✅
  - `NAVER_REDIRECT_URI`: `http://localhost:3001/loading` ✅

**결론**: 환경 변수 값은 동일합니다.

### 2. 코드 비교

**Edge Function (정상 동작)**:
```typescript
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
  // ... 에러 처리
}
```

**Workers (에러 발생)**:
```typescript
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
  // ... 에러 처리
}
```

**결론**: 코드도 동일합니다.

### 3. 가능한 원인

1. **Workers Secrets가 실제로 배포되지 않았을 수 있음**
   - Workers Secrets는 배포 시점에 설정되어야 함
   - Secrets를 설정한 후 재배포가 필요할 수 있음

2. **네이버 개발자 센터에서 Client Secret이 변경되었을 수 있음**
   - Edge Function이 정상 동작한다면, 이 가능성은 낮음
   - 하지만 확인이 필요함

3. **네이버 API의 Redirect URI 검증 문제**
   - 네이버 개발자 센터에 등록된 Callback URL과 Workers에서 사용하는 Redirect URI가 정확히 일치해야 함
   - 현재: `http://localhost:3001/loading` ✅

4. **Workers 환경 변수 접근 방식 문제**
   - Edge Function: `Deno.env.get('NAVER_CLIENT_SECRET')`
   - Workers: `env.NAVER_CLIENT_SECRET`
   - 이 차이로 인해 값이 다를 수 있음

---

## 🔧 해결 방안

### 방안 1: Workers Secrets 재설정 및 재배포

1. Workers Secrets를 삭제하고 다시 설정
2. Workers 재배포
3. 테스트

### 방안 2: Edge Function의 실제 환경 변수 값 확인

1. Edge Function 로그에서 실제 사용 중인 환경 변수 값 확인
2. Workers Secrets와 비교
3. 차이점 발견 시 수정

### 방안 3: 네이버 개발자 센터에서 Client Secret 재발급

1. 네이버 개발자 센터에서 Client Secret 재발급
2. Edge Function과 Workers 모두에 새 값 설정
3. 테스트

### 방안 4: Workers 로그 확인

1. Workers 로그에서 실제 사용 중인 환경 변수 값 확인
2. 네이버 API 요청 파라미터 확인
3. 문제점 발견 시 수정

---

## 📝 다음 단계

1. **Workers 로그 확인**
   - `npx wrangler tail` 명령어로 실시간 로그 확인
   - 실제 사용 중인 환경 변수 값 확인

2. **Edge Function 로그 확인**
   - Edge Function이 정상 동작할 때의 로그 확인
   - 실제 사용 중인 환경 변수 값 확인

3. **네이버 개발자 센터 재확인**
   - Client Secret의 실제 값 확인
   - Callback URL 설정 확인

4. **Workers Secrets 재설정**
   - Secrets를 삭제하고 다시 설정
   - 재배포 후 테스트

---

## 📌 참고 사항

- Edge Function은 정상 동작 중이므로, 코드 자체의 문제는 아닙니다.
- 환경 변수 값도 동일하므로, Workers Secrets 설정 문제일 가능성이 높습니다.
- Workers Secrets는 배포 시점에 설정되어야 하므로, Secrets 설정 후 재배포가 필요할 수 있습니다.

