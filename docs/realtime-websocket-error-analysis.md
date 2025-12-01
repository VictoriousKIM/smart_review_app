# Realtime WebSocket 연결 에러 분석 및 해결 로드맵

## 📋 문제 요약

**에러 메시지:**
```
❌ Realtime 구독 에러: advertiser_my_campaigns, WebSocketChannelException: WebSocket connection failed.
❌ Realtime 구독 에러: home, WebSocketChannelException: WebSocket connection failed.
```

**현황:**
- 프로덕션 환경에서는 정상 동작 ✅
- 로컬 개발 환경에서만 실패 ❌
- 여러 화면에서 동일한 에러 발생 (advertiser_my_campaigns, home 등)

## 🔍 원인 분석

### ⚠️ **핵심 원인 발견: MalformedJWT 에러**

**Realtime 서비스 로그 분석 결과:**
```
error_code=MalformedJWT [error] MalformedJWT: The token provided is not a valid JWT
```

**문제:**
- Realtime 서비스는 정상 실행 중 ✅
- WebSocket 연결 시도는 성공 ✅
- 하지만 JWT 토큰 형식이 잘못되어 인증 실패 ❌

**원인:**
- 로컬 Supabase의 anon key: `sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH`
- 이 키는 JWT 형식이 아님 (일반적으로 `eyJ...`로 시작해야 함)
- 프로덕션 키는 정상적인 JWT 형식: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

**영향:**
- WebSocket 연결은 시도되지만 인증 단계에서 실패
- Realtime 구독이 완료되지 않음
- `WebSocketChannelException: WebSocket connection failed` 에러 발생

### 1. 로컬 Supabase Realtime 서비스 상태 확인

**현재 상태:**
- `supabase status` 출력에 Realtime 서비스가 명시적으로 표시되지 않음
- `config.toml`에서 `[realtime] enabled = true`로 설정되어 있음
- 하지만 실제 서비스가 실행 중인지 확인 필요

**확인 사항:**
```bash
# Realtime 서비스가 실제로 실행 중인지 확인
docker ps | grep realtime
# 또는
npx supabase status --output json | jq '.realtime'
```

### 2. WebSocket 연결 URL 문제

**현재 설정:**
- 로컬 Supabase URL: `http://127.0.0.1:54500`
- WebSocket 연결 시 자동으로 `ws://127.0.0.1:54500/realtime/v1/websocket`로 변환됨

**문제 가능성:**
1. **HTTP vs HTTPS**: 로컬은 HTTP, 프로덕션은 HTTPS
   - 웹 브라우저의 Mixed Content 정책으로 인한 차단 가능성
   - 하지만 로컬 개발 환경에서는 일반적으로 문제 없음

2. **WebSocket 포트**: Realtime 서비스가 별도 포트에서 실행될 수 있음
   - Supabase 로컬 환경에서 Realtime은 기본적으로 API 서버와 같은 포트 사용
   - 하지만 Docker 컨테이너 내부 포트 매핑 문제 가능성

### 3. 로컬 Supabase Realtime 설정 문제

**config.toml 확인:**
```toml
[realtime]
enabled = true
# 포트 설정이 없음 - 기본적으로 API 포트 사용
```

**문제 가능성:**
- Realtime 서비스가 제대로 시작되지 않았을 수 있음
- Docker 컨테이너 내부에서 Realtime 서비스가 실패했을 수 있음

### 4. Flutter 웹 환경의 WebSocket 제한

**Flutter 웹 특성:**
- Flutter 웹은 브라우저의 WebSocket API를 사용
- CORS 정책, Mixed Content 정책 등의 제약
- 로컬 개발 환경에서 `localhost` vs `127.0.0.1` 차이

**확인 사항:**
- 브라우저 콘솔에서 WebSocket 연결 시도 로그 확인
- 네트워크 탭에서 WebSocket 연결 상태 확인

### 5. Supabase Flutter SDK 설정 문제

**현재 코드:**
```dart
// lib/config/supabase_config.dart
static String get supabaseUrl {
  return 'http://127.0.0.1:54500';  // 로컬
}
```

**문제 가능성:**
- Supabase Flutter SDK가 WebSocket 연결 시 URL 변환을 제대로 하지 못함
- 로컬 환경에서 WebSocket 연결을 위한 추가 설정 필요

## 🛠️ 해결 로드맵

### ⚡ **즉시 해결 방법 (우선순위: 최우선)**

#### 해결책 1: 로컬 Supabase JWT 키 확인 및 수정

**문제:** 로컬 Supabase의 anon key가 JWT 형식이 아님

**해결:**
1. 로컬 Supabase의 실제 JWT 키 확인:
```bash
# Supabase Studio에서 확인
# http://127.0.0.1:54503 → Settings → API → anon/public key
```

2. `lib/config/supabase_config.dart`에서 올바른 키 사용 확인:
```dart
static String get supabaseAnonKey {
  const useProduction = String.fromEnvironment(
    'USE_PRODUCTION_SUPABASE',
    defaultValue: 'false',
  );
  if (useProduction == 'true') {
    return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'; // 프로덕션 JWT
  } else {
    // 로컬 키가 JWT 형식인지 확인 필요
    // 현재: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH'
    // 이 키가 실제로 JWT 형식이 아닐 수 있음
    return 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';
  }
}
```

3. Supabase 재시작 후 새 키 확인:
```bash
npx supabase stop
npx supabase start
# 출력에서 Publishable key 확인
```

#### 해결책 2: Supabase Flutter SDK의 로컬 환경 처리 확인

**문제:** Supabase Flutter SDK가 로컬 환경에서 JWT 형식이 아닌 키를 처리하지 못함

**해결:**
- Supabase Flutter SDK 버전 확인 및 업데이트
- 로컬 환경에서의 JWT 키 처리 방식 확인

#### 해결책 3: 임시 해결 - 로컬 환경에서 Realtime 비활성화

**시나리오:** 로컬 개발 중 Realtime이 필수적이지 않은 경우

```dart
// lib/services/campaign_realtime_manager.dart
bool subscribe({...}) {
  // 로컬 환경 감지
  final isLocal = SupabaseConfig.supabaseUrl.contains('127.0.0.1') || 
                  SupabaseConfig.supabaseUrl.contains('localhost');
  
  if (isLocal && kDebugMode) {
    _log('⚠️ 로컬 환경: Realtime 구독 건너뜀 (JWT 키 문제)', LogLevel.warning);
    return false;
  }
  // ... 기존 코드
}
```

### Phase 1: 환경 확인 및 진단 (우선순위: 높음)

#### 1.1 Realtime 서비스 상태 확인
```bash
# Docker 컨테이너 상태 확인
docker ps --filter "name=supabase_realtime"

# Realtime 로그 확인
docker logs supabase_realtime_smart_review_app

# Supabase 전체 상태 확인
npx supabase status --output json
```

**예상 결과:**
- Realtime 컨테이너가 실행 중이어야 함
- 로그에 에러가 없어야 함

#### 1.2 WebSocket 연결 테스트
```bash
# WebSocket 연결 테스트 (Node.js 또는 curl 사용)
# Node.js 예시:
node -e "
const WebSocket = require('ws');
const ws = new WebSocket('ws://127.0.0.1:54500/realtime/v1/websocket?apikey=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH');
ws.on('open', () => console.log('✅ WebSocket 연결 성공'));
ws.on('error', (e) => console.error('❌ WebSocket 에러:', e));
"
```

**예상 결과:**
- WebSocket 연결이 성공해야 함
- 연결 실패 시 네트워크/포트 문제

#### 1.3 브라우저 콘솔 확인
- Flutter 웹 앱 실행 후 브라우저 개발자 도구 열기
- Network 탭에서 WebSocket 연결 시도 확인
- Console 탭에서 WebSocket 관련 에러 메시지 확인

### Phase 2: 설정 수정 (우선순위: 중간)

#### 2.1 Supabase 재시작
```bash
# Supabase 완전히 중지
npx supabase stop

# Docker 컨테이너 정리 (필요시)
docker ps -a | grep supabase | awk '{print $1}' | xargs docker rm -f

# Supabase 재시작
npx supabase start
```

**예상 결과:**
- Realtime 서비스가 정상적으로 시작됨
- `supabase status` 출력에 Realtime 관련 정보 표시

#### 2.2 config.toml Realtime 설정 확인/수정
```toml
[realtime]
enabled = true
# 필요시 포트 명시적 설정 (일반적으로 불필요)
# port = 4000
```

**확인 사항:**
- `enabled = true` 확인
- 다른 설정이 Realtime을 방해하지 않는지 확인

#### 2.3 Flutter 코드에서 WebSocket URL 명시적 설정 (필요시)

**현재:** Supabase SDK가 자동으로 WebSocket URL 생성
**대안:** 명시적으로 WebSocket URL 설정

```dart
// lib/config/supabase_config.dart 수정 (필요시)
static Future<void> initialize() async {
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    // WebSocket URL 명시적 설정 (필요시)
    realtimeOptions: RealtimeClientOptions(
      // 로컬 환경에서 WebSocket URL 명시
      // 일반적으로 자동 감지되므로 필요 없을 수 있음
    ),
    // ... 기존 설정
  );
}
```

### Phase 3: 대안 구현 (우선순위: 낮음)

#### 3.1 로컬 환경에서 Realtime 비활성화 옵션

**시나리오:** 로컬 개발 중 Realtime이 필수적이지 않은 경우

```dart
// lib/services/campaign_realtime_manager.dart
bool subscribe({...}) {
  // 로컬 환경에서 Realtime 비활성화 옵션
  if (kDebugMode && !_isProduction) {
    debugPrint('⚠️ 로컬 환경: Realtime 구독 건너뜀');
    return false;
  }
  // ... 기존 코드
}
```

**장점:**
- 로컬 개발 시 에러 방지
- 개발 속도 향상

**단점:**
- 로컬에서 Realtime 기능 테스트 불가

#### 3.2 폴링(Polling) 방식으로 대체

**시나리오:** WebSocket 연결이 불가능한 경우

```dart
// 주기적으로 데이터를 가져오는 방식으로 대체
Timer.periodic(Duration(seconds: 5), (timer) {
  _refreshCampaigns();
});
```

**장점:**
- WebSocket 없이도 실시간성 유지 (약간의 지연)

**단점:**
- 서버 부하 증가
- 실시간성이 떨어짐

#### 3.3 프로덕션 Realtime 사용 (임시 해결책)

**시나리오:** 로컬 개발 중에도 프로덕션 Realtime 사용

```dart
// lib/config/supabase_config.dart
static String get supabaseUrl {
  // 로컬 개발 중에도 프로덕션 Realtime 사용
  if (kDebugMode) {
    // Realtime만 프로덕션 사용
    // (복잡한 설정 필요)
  }
  return 'http://127.0.0.1:54500';
}
```

**주의사항:**
- 프로덕션 데이터에 영향을 줄 수 있음
- 권장하지 않음

### Phase 4: 근본 원인 해결 (우선순위: 높음)

#### 4.1 Docker 컨테이너 네트워크 문제 해결

**문제:** Docker 컨테이너 간 네트워크 통신 문제

**해결:**
```bash
# Docker 네트워크 확인
docker network ls
docker network inspect supabase_network_smart_review_app

# 필요시 네트워크 재생성
npx supabase stop
docker network prune
npx supabase start
```

#### 4.2 Realtime 서비스 로그 분석

**문제:** Realtime 서비스가 시작은 되지만 연결 실패

**해결:**
```bash
# Realtime 서비스 로그 실시간 확인
docker logs -f supabase_realtime_smart_review_app

# 에러 패턴 확인
docker logs supabase_realtime_smart_review_app 2>&1 | grep -i error
```

#### 4.3 Supabase 버전 호환성 확인

**문제:** Supabase CLI 버전과 로컬 서비스 버전 불일치

**해결:**
```bash
# Supabase CLI 버전 확인
npx supabase --version

# 최신 버전으로 업데이트
npm install -g supabase@latest

# 로컬 서비스 재시작
npx supabase stop
npx supabase start
```

## 📝 체크리스트

### ⚡ 즉시 확인 사항 (JWT 키 문제)
- [ ] `npx supabase status` - Publishable key가 JWT 형식인지 확인 (`eyJ...`로 시작해야 함)
- [ ] `lib/config/supabase_config.dart` - 로컬 anon key가 올바른지 확인
- [ ] Supabase Studio (http://127.0.0.1:54503) → Settings → API → anon/public key 확인
- [ ] Realtime 로그에서 `MalformedJWT` 에러 확인: `docker logs supabase_realtime_smart_review_app | grep MalformedJWT`

### 즉시 확인 사항
- [ ] `docker ps | grep realtime` - Realtime 컨테이너 실행 확인
- [ ] `npx supabase status` - Realtime 서비스 상태 확인
- [ ] 브라우저 콘솔 - WebSocket 연결 에러 메시지 확인
- [ ] Network 탭 - WebSocket 연결 시도 확인

### 설정 확인 사항
- [ ] `config.toml` - `[realtime] enabled = true` 확인
- [ ] Supabase 재시작 - `npx supabase stop && npx supabase start`
- [ ] Docker 로그 - Realtime 서비스 에러 확인

### 코드 수정 사항 (필요시)
- [ ] WebSocket URL 명시적 설정
- [ ] 에러 핸들링 개선 (로컬 환경 감지)
- [ ] 로컬 환경에서 Realtime 비활성화 옵션 추가

## 🎯 권장 해결 순서

### 즉시 실행 (JWT 키 문제 해결)
1. **즉시 해결책 1**: Supabase 재시작 후 올바른 JWT 키 확인 (2분)
2. **즉시 해결책 2**: `lib/config/supabase_config.dart`에서 올바른 키 사용 확인 (5분)
3. **즉시 해결책 3**: 로컬 환경에서 Realtime 비활성화 옵션 추가 (임시 해결책, 10분)

### 추가 진단 (JWT 키 문제가 아닌 경우)
4. **Phase 1.1**: Realtime 서비스 상태 확인 (5분)
5. **Phase 1.2**: WebSocket 연결 테스트 (5분)
6. **Phase 1.3**: 브라우저 콘솔 확인 (5분)
7. **Phase 4.2**: Realtime 서비스 로그 분석 (10분)
8. **Phase 4.1**: Docker 네트워크 문제 해결 (10분)

## 📚 참고 자료

- [Supabase Realtime 문서](https://supabase.com/docs/guides/realtime)
- [Supabase 로컬 개발 가이드](https://supabase.com/docs/guides/cli/local-development)
- [Flutter WebSocket 가이드](https://docs.flutter.dev/development/platform-integration/web)

## 🔄 업데이트 이력

- 2025-01-XX: 초기 문서 작성
- 2025-01-XX: **핵심 원인 발견** - MalformedJWT 에러 확인
  - Realtime 서비스 로그에서 `MalformedJWT` 에러 반복 발생 확인
  - 로컬 Supabase의 anon key가 JWT 형식이 아님 (`sb_publishable_...` vs `eyJ...`)
  - 즉시 해결 방법 추가

