# Supabase 인증 에러 근본 원인 분석 및 해결 방법

## 📋 목차
1. [에러 분석](#에러-분석)
2. [근본 원인](#근본-원인)
3. [해결 방법](#해결-방법)
4. [예방 조치](#예방-조치)
5. [참고 자료](#참고-자료)

---

## 🔍 에러 분석

### 발생하는 에러 메시지
```
AuthRetryableFetchException(message: {"code":"unexpected_failure","message":"missing destination name oauth_client_id in *models.Session"}, statusCode: 500)
Access token is expired and refreshing failed, aborting api request
```

### 에러 발생 시나리오
1. 앱 시작 시 Supabase 초기화 성공
2. 세션 복원 시도 (`Refresh session`)
3. 토큰 갱신 요청 시 서버 측에서 `oauth_client_id` 필드 누락 에러 발생
4. 토큰 갱신 실패로 인한 인증 실패
5. 사용자 프로필 조회 실패

---

## 🎯 근본 원인

### 1. 로컬 Supabase 환경의 OAuth 클라이언트 미설정

**문제점:**
- 로컬 개발 환경(`http://127.0.0.1:54321`)에서 OAuth 클라이언트가 설정되지 않음
- `supabase/config.toml`에서 OAuth 프로바이더가 모두 비활성화되어 있음
- `oauth_clients` 테이블에 데이터가 없음

**증거:**
```toml
# supabase/config.toml
[auth.external.apple]
enabled = false
client_id = ""
# Google, Kakao 등 다른 OAuth 프로바이더도 설정되지 않음
```

### 2. Seed 데이터의 세션 정보 불완전

**문제점:**
- `supabase/seed.sql`의 세션 데이터에 `oauth_client_id`가 모두 `NULL`로 설정됨
- 이메일/비밀번호 로그인으로 생성된 세션도 `oauth_client_id`가 필요함

**증거:**
```sql
-- supabase/seed.sql
INSERT INTO "auth"."sessions" (..., "oauth_client_id", ...) VALUES
  (..., NULL, ...),  -- 모든 세션의 oauth_client_id가 NULL
  (..., NULL, ...),
  ...
```

### 3. Supabase 서버 측 세션 모델 요구사항

**문제점:**
- Supabase Go 서버(`gotrue`)가 토큰 갱신 시 `oauth_client_id`를 필수로 요구
- `oauth_client_id`가 NULL이면 세션 모델 파싱 실패
- 이는 Supabase의 최신 버전에서 추가된 보안 요구사항

### 4. 웹 환경의 세션 저장소 문제

**문제점:**
- 웹 환경에서 LocalStorage에 저장된 세션 정보가 손상되었을 수 있음
- Hot reload/restart 시 세션 복원 과정에서 문제 발생
- 브라우저의 LocalStorage가 만료되거나 손상된 세션 데이터 포함

---

## ✅ 해결 방법

### 방법 1: 로컬 Supabase 환경 재설정 (권장)

#### 1-1. 기존 세션 데이터 삭제

```bash
# 로컬 Supabase 중지
npx supabase stop

# 데이터베이스 리셋 (세션 데이터 포함)
npx supabase db reset

# 또는 특정 테이블만 삭제
npx supabase db execute "DELETE FROM auth.sessions;"
```

#### 1-2. OAuth 클라이언트 설정

**로컬 환경 설정 (이메일/비밀번호 + OAuth 모두 활성화)**

로컬 개발 환경에서도 이메일/비밀번호와 OAuth를 모두 사용할 수 있도록 설정:

```toml
# supabase/config.toml
[auth]
enabled = true
site_url = "http://localhost:3001"
additional_redirect_urls = [
  "http://localhost:3001",
  "http://127.0.0.1:3001",
  "http://127.0.0.1:54321/auth/v1/callback",
  "http://localhost:54321/auth/v1/callback"
]

# 이메일/비밀번호 로그인 활성화
[auth.email]
enable_signup = true
enable_confirmations = false

# Google OAuth 활성화
[auth.external.google]
enabled = true
client_id = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID)"
secret = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET)"
# 로컬 개발 환경에서는 nonce 체크 스킵 (필수)
skip_nonce_check = true

# Kakao OAuth 활성화
[auth.external.kakao]
enabled = true
client_id = "env(SUPABASE_AUTH_EXTERNAL_KAKAO_CLIENT_ID)"
secret = "env(SUPABASE_AUTH_EXTERNAL_KAKAO_SECRET)"
```

**로컬 환경 OAuth 설정 방법**

1. **환경 변수 파일 생성** (`.env` 또는 `.env.local`)
   ```bash
   # .env 파일 (프로젝트 루트에 생성)
   SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=your-google-client-id
   SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=your-google-client-secret
   SUPABASE_AUTH_EXTERNAL_KAKAO_CLIENT_ID=your-kakao-rest-api-key
   SUPABASE_AUTH_EXTERNAL_KAKAO_SECRET=your-kakao-client-secret
   ```

2. **Google Cloud Console 설정 (로컬용)**
   - https://console.cloud.google.com 접속
   - APIs & Services > Credentials
   - OAuth 2.0 클라이언트 ID 생성 또는 기존 ID 사용
   - Authorized redirect URIs에 추가:
     - `http://127.0.0.1:54321/auth/v1/callback`
     - `http://localhost:54321/auth/v1/callback`
     - `http://localhost:3001`
     - `http://127.0.0.1:3001`

3. **Kakao Developers 설정 (로컬용)**
   - https://developers.kakao.com 접속
   - 내 애플리케이션 선택
   - 플랫폼 > Web 플랫폼 등록
   - 사이트 도메인: `localhost`, `127.0.0.1`
   - 제품 설정 > 카카오 로그인 > Redirect URI 추가:
     - `http://127.0.0.1:54321/auth/v1/callback`
     - `http://localhost:54321/auth/v1/callback`

4. **환경 변수 로드 확인**
   ```bash
   # Supabase 시작 전 환경 변수가 로드되는지 확인
   # Windows PowerShell
   $env:SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID
   
   # Linux/Mac
   echo $SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID
   ```

5. **Supabase 재시작**
   ```bash
   npx supabase stop
   npx supabase start
   ```

**프로덕션 환경 설정 (이메일/비밀번호 + OAuth 모두 활성화 또는 OAuth만 사용)**

프로덕션 환경에서도 이메일/비밀번호와 OAuth를 모두 사용하거나, OAuth만 사용할 수 있습니다:

```toml
# supabase/config.toml (프로덕션)
[auth]
enabled = true
site_url = "https://your-production-domain.com"
additional_redirect_urls = [
  "https://your-production-domain.com",
  "https://your-project.supabase.co/auth/v1/callback"
]

# 이메일/비밀번호 로그인 설정
[auth.email]
enable_signup = true  # 이메일 회원가입 허용 (필요시 false로 변경)
enable_confirmations = true  # 프로덕션에서는 이메일 확인 활성화 권장

# Google OAuth 활성화
[auth.external.google]
enabled = true
client_id = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID)"
secret = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET)"
# 프로덕션에서는 nonce 체크 활성화 (보안 강화)
skip_nonce_check = false

# Kakao OAuth 활성화
[auth.external.kakao]
enabled = true
client_id = "env(SUPABASE_AUTH_EXTERNAL_KAKAO_CLIENT_ID)"
secret = "env(SUPABASE_AUTH_EXTERNAL_KAKAO_SECRET)"
```

**참고:** 프로덕션에서 이메일/비밀번호 로그인을 비활성화하려면 `[auth.email]` 섹션에서 `enable_signup = false`로 설정하세요.

**프로덕션 Supabase 대시보드 설정**

1. **Supabase 프로젝트 대시보드 접속**
   - https://supabase.com/dashboard 접속
   - 프로젝트 선택

2. **Authentication > Providers 설정**
   - **Google 설정:**
     - Google OAuth 활성화
     - Client ID: Google Cloud Console에서 발급받은 클라이언트 ID
     - Client Secret: Google Cloud Console에서 발급받은 시크릿
     - Redirect URL: `https://your-project.supabase.co/auth/v1/callback`
   
   - **Kakao 설정:**
     - Kakao OAuth 활성화
     - Client ID: Kakao Developers에서 발급받은 REST API 키
     - Client Secret: Kakao Developers에서 발급받은 Client Secret
     - Redirect URL: `https://your-project.supabase.co/auth/v1/callback`

3. **Redirect URLs 설정**
   - Authentication > URL Configuration
   - Site URL: 프로덕션 도메인
   - Redirect URLs에 다음 추가:
     - `https://your-production-domain.com/**`
     - `https://your-project.supabase.co/auth/v1/callback`

**Google Cloud Console 설정**

1. **프로젝트 생성 및 OAuth 동의 화면 설정**
   - https://console.cloud.google.com 접속
   - 새 프로젝트 생성 또는 기존 프로젝트 선택
   - APIs & Services > OAuth consent screen 설정

2. **OAuth 2.0 클라이언트 ID 생성**
   - APIs & Services > Credentials
   - Create Credentials > OAuth client ID
   - Application type: Web application
   - Authorized redirect URIs:
     - `https://your-project.supabase.co/auth/v1/callback`
     - `https://your-production-domain.com`

3. **클라이언트 ID 및 시크릿 복사**
   - 생성된 Client ID와 Client Secret을 Supabase 대시보드에 입력

**Kakao Developers 설정**

1. **애플리케이션 등록**
   - https://developers.kakao.com 접속
   - 내 애플리케이션 > 애플리케이션 추가하기

2. **플랫폼 설정**
   - 플랫폼 > Web 플랫폼 등록
   - 사이트 도메인: `your-production-domain.com`

3. **카카오 로그인 활성화**
   - 제품 설정 > 카카오 로그인 > 활성화 설정: ON
   - Redirect URI: `https://your-project.supabase.co/auth/v1/callback`

4. **REST API 키 및 Client Secret 확인**
   - 앱 설정 > 앱 키에서 REST API 키 확인
   - 제품 설정 > 카카오 로그인 > Client Secret 확인
   - Supabase 대시보드에 입력

**환경 변수 설정 (프로덕션)**

프로덕션 환경에서는 환경 변수를 사용하여 OAuth 정보를 관리:

```bash
# .env 파일 (프로덕션 서버)
SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=your-google-client-id
SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=your-google-client-secret
SUPABASE_AUTH_EXTERNAL_KAKAO_CLIENT_ID=your-kakao-rest-api-key
SUPABASE_AUTH_EXTERNAL_KAKAO_SECRET=your-kakao-client-secret
```

또는 Supabase 대시보드에서 직접 설정 (권장):
- Settings > API > Project API keys
- 또는 Authentication > Providers에서 직접 입력

**Flutter 앱 코드 설정**

프로덕션 환경에서는 OAuth만 사용하도록 코드 수정:

```dart
// lib/config/supabase_config.dart
static const String supabaseUrl = kDebugMode
    ? 'http://127.0.0.1:54321' // 로컬 개발 환경
    : 'https://ythmnhadeyfusmfhcgdr.supabase.co'; // 프로덕션 환경

// lib/services/auth_service.dart
// 이메일/비밀번호 로그인은 로컬 개발 환경에서만 사용
Future<app_user.User?> signInWithEmail(String email, String password) async {
  if (!kDebugMode) {
    throw Exception('프로덕션 환경에서는 OAuth 로그인만 사용 가능합니다.');
  }
  // ... 기존 코드
}
```

#### 1-3. Seed 데이터 수정

`supabase/seed.sql`에서 세션 데이터를 제거하거나, 최신 Supabase 버전과 호환되도록 수정:

```sql
-- 기존 세션 데이터 삭제 (권장)
-- INSERT INTO "auth"."sessions" ... 문을 주석 처리하거나 삭제

-- 또는 새로운 세션은 앱 실행 시 자동으로 생성되도록 함
```

### 방법 2: 클라이언트 측 에러 처리 강화

#### 2-1. 세션 복원 실패 시 처리

`lib/config/supabase_config.dart` 수정:

```dart
static Future<void> initialize() async {
  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    debugPrint('Supabase 초기화 완료');
    
    // 세션 복원 시도 및 에러 처리
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        // 세션이 있으면 유효성 검증
        await Supabase.instance.client.auth.getUser();
        debugPrint('세션 유효성 검증 성공');
      }
    } catch (sessionError) {
      // 세션이 손상되었거나 유효하지 않으면 삭제
      debugPrint('세션 유효성 검증 실패: $sessionError');
      debugPrint('손상된 세션 삭제 및 로그아웃 처리');
      await Supabase.instance.client.auth.signOut();
    }
  } catch (e) {
    debugPrint('Supabase 초기화 중 에러 발생: $e');
    rethrow;
  }
}
```

#### 2-2. 토큰 갱신 실패 시 재로그인 유도

`lib/services/auth_service.dart` 수정:

```dart
Future<app_user.User?> get currentUser async {
  try {
    final session = _supabase.auth.currentSession;
    if (session?.user != null) {
      // 세션 만료 확인
      if (session!.isExpired) {
        debugPrint('세션이 만료되었습니다. 토큰 갱신 시도...');
        try {
          // 토큰 갱신 시도
          final refreshedSession = await _supabase.auth.refreshSession();
          if (refreshedSession.session == null) {
            debugPrint('토큰 갱신 실패. 로그아웃 처리');
            await _supabase.auth.signOut();
            return null;
          }
        } catch (refreshError) {
          debugPrint('토큰 갱신 중 에러 발생: $refreshError');
          // oauth_client_id 관련 에러인 경우 세션 삭제
          if (refreshError.toString().contains('oauth_client_id')) {
            debugPrint('손상된 세션 감지. 로그아웃 처리');
            await _supabase.auth.signOut();
          }
          return null;
        }
      }
      
      // 프로필 조회 로직...
    }
    return null;
  } catch (e) {
    debugPrint('사용자 프로필 조회 실패: $e');
    // oauth_client_id 관련 에러인 경우 세션 삭제
    if (e.toString().contains('oauth_client_id')) {
      debugPrint('손상된 세션 감지. 로그아웃 처리');
      try {
        await _supabase.auth.signOut();
      } catch (_) {
        // 로그아웃 실패는 무시
      }
    }
    return null;
  }
}
```

### 방법 3: 브라우저 LocalStorage 초기화

웹 환경에서 손상된 세션 데이터를 제거:

```dart
// lib/config/supabase_config.dart에 추가
static Future<void> clearStoredSession() async {
  if (kIsWeb) {
    try {
      // 웹 환경에서 LocalStorage의 Supabase 세션 데이터 삭제
      final storage = html.window.localStorage;
      storage.removeWhere((key, value) => key.startsWith('supabase.auth.'));
      debugPrint('저장된 세션 데이터 삭제 완료');
    } catch (e) {
      debugPrint('세션 데이터 삭제 실패: $e');
    }
  }
}
```

사용 방법:
```dart
// main.dart에서 초기화 전에 호출 (필요시)
await SupabaseConfig.clearStoredSession();
await SupabaseConfig.initialize();
```

### 방법 4: Supabase 버전 확인 및 업데이트

```bash
# Supabase CLI 버전 확인
npx supabase --version

# 최신 버전으로 업데이트
npm install -g supabase@latest

# 로컬 Supabase 재시작
npx supabase stop
npx supabase start
```

---

## 🛡️ 예방 조치

### 1. 세션 데이터 관리 개선

- **Seed 데이터에서 세션 제거**: 앱 실행 시 자동으로 생성되도록 함
- **세션 만료 시간 설정**: `config.toml`에서 `jwt_expiry` 조정
- **토큰 갱신 정책 설정**: `enable_refresh_token_rotation` 활성화

### 2. 에러 모니터링 추가

```dart
// lib/utils/error_handler.dart에 추가
class AuthErrorHandler {
  static bool isOAuthClientIdError(dynamic error) {
    return error.toString().contains('oauth_client_id');
  }
  
  static Future<void> handleAuthError(dynamic error) async {
    if (isOAuthClientIdError(error)) {
      debugPrint('OAuth 클라이언트 ID 관련 에러 감지. 세션 초기화');
      try {
        await SupabaseConfig.client.auth.signOut();
      } catch (_) {
        // 무시
      }
    }
  }
}
```

### 3. 개발 환경 설정 문서화

- 로컬 개발 환경 설정 가이드 작성
- OAuth 설정이 필요한 경우와 불필요한 경우 명확히 구분
- 세션 데이터 관리 정책 문서화

### 4. 테스트 코드 추가

```dart
// 테스트: 세션 복원 실패 시나리오
test('세션 복원 실패 시 로그아웃 처리', () async {
  // 손상된 세션 데이터 시뮬레이션
  // 에러 처리 로직 검증
});
```

---

## 📚 참고 자료

### Supabase 공식 문서
- [Supabase Auth 세션 관리](https://supabase.com/docs/guides/auth/sessions)
- [Supabase 로컬 개발 환경 설정](https://supabase.com/docs/guides/cli/local-development)
- [Supabase Flutter 인증 가이드](https://supabase.com/docs/guides/auth/flutter)

### 관련 이슈
- [Supabase GitHub: oauth_client_id 관련 이슈](https://github.com/supabase/supabase/issues)
- [Supabase Flutter: 세션 복원 이슈](https://github.com/supabase/supabase-flutter/issues)

### 추가 리소스
- [Supabase Go 서버 (gotrue) 소스 코드](https://github.com/supabase/gotrue)
- [Flutter 웹 LocalStorage 관리](https://api.flutter.dev/flutter/dart-html/Storage-class.html)

---

## 🔄 해결 체크리스트

- [ ] 로컬 Supabase 환경 재설정 (`npx supabase db reset`)
- [ ] Seed 데이터에서 세션 데이터 제거 또는 수정
- [ ] 클라이언트 측 에러 처리 강화
- [ ] 토큰 갱신 실패 시 재로그인 유도 로직 추가
- [ ] 브라우저 LocalStorage 초기화 기능 추가 (웹 환경)
- [ ] Supabase CLI 최신 버전으로 업데이트
- [ ] 에러 모니터링 및 로깅 개선
- [ ] 테스트 코드 작성

---

## 💡 요약

**핵심 문제:**
- 로컬 Supabase 환경에서 `oauth_client_id`가 NULL인 세션 데이터로 인한 토큰 갱신 실패

**즉시 해결 방법:**
1. 로컬 Supabase 데이터베이스 리셋 (`npx supabase db reset`)
2. Seed 데이터에서 세션 데이터 제거
3. 클라이언트 측에서 손상된 세션 감지 및 삭제 로직 추가

**장기적 해결 방법:**
1. 세션 데이터 관리 정책 수립
2. 에러 처리 및 모니터링 강화
3. 개발 환경 설정 문서화

---

**작성일:** 2025-01-XX  
**최종 수정일:** 2025-01-XX  
**작성자:** AI Assistant

