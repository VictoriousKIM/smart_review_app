# 네이버 로그인 Workers 마이그레이션 에러 수정 요약

**작성일**: 2025년 1월 28일

---

## 🔴 현재 문제

**에러 메시지**: `invalid_request - wrong client id / client secret pair`

**발생 위치**: Workers에서 네이버 토큰 교환 시

**원인**: Workers Secrets에 설정된 `NAVER_CLIENT_SECRET`이 네이버 개발자 센터의 실제 값과 일치하지 않음

---

## ✅ 완료된 작업

1. ✅ Workers 함수 생성 및 배포
2. ✅ Flutter 서비스 수정 (Workers HTTP 호출)
3. ✅ Workers Secrets 설정 (4개 환경 변수)
4. ✅ 디버깅 로그 추가
5. ✅ 재배포 완료

---

## ⚠️ 남은 문제

**네이버 Client Secret 불일치**

현재 설정된 값:
- `NAVER_CLIENT_ID`: `Gx2IIkdRCTg32kobQj7J` ✅ (정상 - 네이버 로그인 페이지로 리다이렉트됨)
- `NAVER_CLIENT_SECRET`: `mlb3W9kKWE` ❌ (불일치 가능성)

---

## 🔧 해결 방법

### 방법 1: 네이버 개발자 센터에서 실제 Secret 확인

1. 네이버 개발자 센터 접속: https://developers.naver.com/apps/#/list
2. 애플리케이션 선택
3. Client ID와 Client Secret 확인
4. Workers Secrets 재설정:

```bash
cd workers
echo "실제_CLIENT_SECRET" | npx wrangler secret put NAVER_CLIENT_SECRET
npx wrangler deploy
```

### 방법 2: Edge Function과 동일한 값 사용 확인

Edge Function이 정상 작동한다면, Edge Function에서 사용하는 값과 동일한 값이 Workers에도 설정되어 있는지 확인:

- Edge Function: `supabase/config.toml`의 `NAVER_CLIENT_SECRET = "mlb3W9kKWE"`
- Workers: Secrets에 설정된 값

---

## 📊 테스트 결과

### 성공한 부분
- ✅ Flutter 앱 → Workers API 호출
- ✅ 네이버 OAuth 플로우 (리다이렉트, 콜백)
- ✅ Workers 라우팅 및 요청 처리

### 실패한 부분
- ❌ 네이버 토큰 교환 (Client Secret 불일치)

---

## 📝 다음 단계

1. **네이버 개발자 센터에서 실제 Client Secret 확인** (필수)
2. **Workers Secrets 재설정**
3. **Workers 재배포**
4. **재테스트**

---

## 🔍 참고

- **Workers 배포 URL**: `https://smart-review-api.nightkille.workers.dev`
- **엔드포인트**: `/api/naver-auth`
- **현재 설정된 Client ID**: `Gx2IIkdRCTg32kobQj7J`
- **현재 설정된 Client Secret**: `mlb3W9kKWE` (확인 필요)

