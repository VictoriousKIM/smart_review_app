# Flutter + Supabase 네이버 소셜 로그인 구현 (Cloudflare Workers)

이 가이드는 Cloudflare Workers를 사용하여 Flutter 앱에서 네이버 소셜 로그인을 구현하는 방법을 설명합니다.

## 아키텍처 개요

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  Flutter App    │────▶│  Cloudflare Workers  │────▶│  Supabase Auth  │
│                 │     │  (naver-auth)        │     │  (admin API)    │
│  1. 네이버 로그인 │     │  2. 토큰 검증 &       │     │  3. 유저 생성    │
│  → access_token │     │     유저 생성/로그인   │     │     /로그인      │
└─────────────────┘     └──────────────────────┘     └─────────────────┘
```

## 1. Flutter 패키지 설치

### pubspec.yaml

```yaml
dependencies:
  flutter_naver_login: ^1.8.0  # 네이버 로그인 (모바일 전용)
  supabase_flutter: ^2.3.0
  http: ^1.1.0  # Workers API 호출용
  universal_html: ^2.2.4  # 웹용 (네이버 JavaScript SDK 사용)
```

**중요**: 
- `flutter_naver_login` 패키지는 **모바일(Android/iOS) 전용**입니다
- 웹에서는 네이버 JavaScript SDK를 사용합니다 (이미 구현됨)

### 패키지 설치

```bash
flutter pub get
```

## 2. 네이버 개발자 센터 설정

### 2.1 네이버 개발자 센터에서 앱 등록

1. [네이버 개발자 센터](https://developers.naver.com/) 접속
2. 애플리케이션 등록
3. 서비스 URL 설정:
   - **서비스 URL**: `https://your-domain.com` (프로덕션)
   - **Callback URL**: 
     - 웹: `https://your-domain.com/loading`
     - 모바일: `com.smart-grow.smart-review://login-callback`

### 2.2 Android 설정

#### android/app/src/main/AndroidManifest.xml

```xml
<manifest>
    <application>
        <!-- 네이버 로그인 -->
        <meta-data
            android:name="com.naver.sdk.clientId"
            android:value="YOUR_NAVER_CLIENT_ID" />
        <meta-data
            android:name="com.naver.sdk.clientSecret"
            android:value="YOUR_NAVER_CLIENT_SECRET" />
        <meta-data
            android:name="com.naver.sdk.clientName"
            android:value="YOUR_APP_NAME" />
    </application>
</manifest>
```

#### android/app/build.gradle.kts

```kotlin
dependencies {
    implementation("com.navercorp.nid:oauth:5.9.0") // 네이버 로그인 SDK
}
```

### 2.3 iOS 설정

#### ios/Runner/Info.plist

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.smart-grow.smart-review</string>
        </array>
    </dict>
</array>

<key>LSApplicationQueriesSchemes</key>
<array>
    <string>naversearchapp</string>
    <string>naversearchthirdlogin</string>
</array>

<key>naverServiceAppUrlScheme</key>
<string>com.smart-grow.smart-review</string>

<key>naverConsumerKey</key>
<string>YOUR_NAVER_CLIENT_ID</string>

<key>naverConsumerSecret</key>
<string>YOUR_NAVER_CLIENT_SECRET</string>

<key>naverServiceAppName</key>
<string>YOUR_APP_NAME</string>
```

## 3. Cloudflare Workers 설정

### 3.1 Workers 함수 생성

이미 `workers/functions/naver-login-callback.ts` 파일이 존재하지만, 개선된 버전으로 업데이트가 필요합니다.

### 3.2 환경 변수 설정

#### wrangler.toml

```toml
name = "smart-review-api"
main = "workers/index.ts"
compatibility_date = "2024-01-01"

[vars]
ENVIRONMENT = "production"

# Secrets는 wrangler CLI로 설정
# wrangler secret put SUPABASE_URL
# wrangler secret put SUPABASE_SERVICE_ROLE_KEY
# wrangler secret put NAVER_PROVIDER_LOGIN_SECRET
```

#### Workers Secrets 설정

```bash
# 로컬 개발용 (.dev.vars 파일 생성)
cd workers
echo "SUPABASE_URL=https://your-project.supabase.co" > .dev.vars
echo "SUPABASE_SERVICE_ROLE_KEY=your-service-role-key" >> .dev.vars
echo "NAVER_PROVIDER_LOGIN_SECRET=your-super-secret-password" >> .dev.vars

# 프로덕션 배포용
wrangler secret put SUPABASE_URL
wrangler secret put SUPABASE_SERVICE_ROLE_KEY
wrangler secret put NAVER_PROVIDER_LOGIN_SECRET
```

**중요**: `NAVER_PROVIDER_LOGIN_SECRET`는 충분히 복잡한 비밀번호로 설정하세요. 네이버 OAuth 사용자는 이 비밀번호로 Supabase에 로그인합니다.

### 3.3 Workers 함수 코드

`workers/functions/naver-login-callback.ts` 파일이 이미 구현되어 있습니다. 
주요 기능:
- 네이버 Access Token으로 사용자 정보 조회
- Supabase Admin API로 사용자 생성/로그인
- 고정 비밀번호를 사용한 세션 생성 정보 반환

**중요**: Workers 함수는 이미 `workers/index.ts`에 라우팅되어 있습니다.

## 4. Flutter 코드 구현

### 4.1 네이버 인증 서비스

`lib/services/naver_auth_service.dart` 파일이 이미 생성되어 있습니다.

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/supabase_config.dart';

class NaverAuthService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// 네이버 로그인 전체 플로우
  Future<AuthResponse?> signInWithNaver() async {
    try {
      if (kIsWeb) {
        // 웹에서는 JavaScript SDK 사용
        return await _signInWithNaverWeb();
      } else {
        // 모바일에서는 네이티브 SDK 사용
        return await _signInWithNaverMobile();
      }
    } catch (e) {
      debugPrint('네이버 로그인 에러: $e');
      rethrow;
    }
  }

  /// 네이버 로그인 (모바일)
  Future<AuthResponse?> _signInWithNaverMobile() async {
    // 1. 네이버 SDK로 로그인
    final NaverLoginResult result = await FlutterNaverLogin.logIn();

    if (result.status != NaverLoginStatus.loggedIn) {
      throw Exception('네이버 로그인 실패: ${result.errorMessage}');
    }

    // 2. Access Token 가져오기
    final NaverAccessToken token = await FlutterNaverLogin.currentAccessToken;

    if (token.accessToken.isEmpty) {
      throw Exception('Access Token이 없습니다');
    }

    // 3. Workers API 호출하여 Supabase 인증 처리
    return await _handleNaverCallback(token.accessToken);
  }

  /// 네이버 로그인 (웹)
  Future<AuthResponse?> _signInWithNaverWeb() async {
    // 웹에서는 기존 auth_service.dart의 _signInWithNaverWeb() 사용
    // 또는 여기에 웹용 구현 추가
    throw UnimplementedError('웹 네이버 로그인은 auth_service.dart에서 처리');
  }

  /// 네이버 콜백 처리 (Workers API 호출)
  Future<AuthResponse?> _handleNaverCallback(String accessToken) async {
    try {
      // Cloudflare Workers API로 토큰 전달
      final response = await http.post(
        Uri.parse('${SupabaseConfig.workersApiUrl}/api/auth/callback/naver'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'accessToken': accessToken}),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? '인증 실패');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final email = data['email'] as String?;
      final isNewUser = data['isNewUser'] as bool? ?? false;
      final accessToken = data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;
      final usePasswordLogin = data['usePasswordLogin'] as bool? ?? false;
      final password = data['password'] as String?;

      debugPrint('네이버 로그인 성공: email=$email, isNewUser=$isNewUser');

      // 세션 생성
      if (accessToken != null && refreshToken != null) {
        // Magic Link로 생성된 토큰 사용
        final sessionResponse = await _supabase.auth.setSession(refreshToken);
        if (sessionResponse.session != null) {
          debugPrint('네이버 로그인 세션 생성 완료 (Magic Link)');
          return sessionResponse;
        }
      }

      if (usePasswordLogin && password != null && email != null) {
        // 비밀번호로 로그인 (임시 방법)
        final authResponse = await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        debugPrint('네이버 로그인 세션 생성 완료 (Password)');
        return authResponse;
      }

      throw Exception('세션 생성에 필요한 정보가 없습니다');
    } catch (e) {
      debugPrint('네이버 콜백 처리 에러: $e');
      rethrow;
    }
  }

  /// 네이버 로그아웃
  Future<void> signOut() async {
    if (!kIsWeb) {
      await FlutterNaverLogin.logOut();
    }
    await _supabase.auth.signOut();
  }
}
```

### 4.2 네이버 로그인 버튼 위젯

`lib/widgets/naver_login_button.dart` 파일이 이미 생성되어 있습니다.

```dart
import 'package:flutter/material.dart';
import '../services/naver_auth_service.dart';

class NaverLoginButton extends StatefulWidget {
  final VoidCallback? onSuccess;
  final Function(String)? onError;

  const NaverLoginButton({
    super.key,
    this.onSuccess,
    this.onError,
  });

  @override
  State<NaverLoginButton> createState() => _NaverLoginButtonState();
}

class _NaverLoginButtonState extends State<NaverLoginButton> {
  final NaverAuthService _authService = NaverAuthService();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    try {
      final result = await _authService.signInWithNaver();

      if (result?.user != null) {
        widget.onSuccess?.call();
      }
    } catch (e) {
      widget.onError?.call(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF03C75A), // 네이버 그린
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'N',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '네이버로 시작하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}
```

### 4.3 로그인 화면에 버튼 추가

`lib/screens/auth/login_screen.dart` 파일에 네이버 로그인 버튼을 추가합니다.

```dart
import '../widgets/naver_login_button.dart';

// ... 기존 코드 ...

NaverLoginButton(
  onSuccess: () {
    // 로그인 성공 시 처리
    Navigator.pushReplacementNamed(context, '/home');
  },
  onError: (error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('로그인 실패: $error')),
    );
  },
),
```

## 5. 패키지 설치

### 5.1 Flutter 패키지 설치

```bash
flutter pub get
```

## 6. Workers 함수 배포

### 6.1 로컬 개발

```bash
cd workers
wrangler dev
```

### 6.2 프로덕션 배포

```bash
cd workers
wrangler deploy
```

### 6.3 Workers 로그 확인

```bash
wrangler tail
```

## 7. 테스트

### 7.1 로컬 테스트

1. Flutter 앱 실행
2. 네이버 로그인 버튼 클릭
3. 네이버 로그인 화면에서 로그인
4. Workers API 호출 확인
5. Supabase 세션 생성 확인

### 7.2 프로덕션 테스트

1. Workers 배포 확인
2. Flutter 앱에서 네이버 로그인 시도
3. Workers 로그에서 에러 확인

## 8. 보안 고려사항

### 8.1 Service Role Key 보안

- **절대 Flutter 앱에 포함하지 마세요!**
- Workers에서만 사용
- 환경 변수로 관리

### 8.2 고정 비밀번호

- `NAVER_PROVIDER_LOGIN_SECRET`는 충분히 복잡하게 설정
- 최소 32자 이상의 랜덤 문자열 권장
- 환경 변수로 관리

### 9. 문제 해결

### 9.1 네이버 로그인 실패

- 네이버 개발자 센터에서 Client ID/Secret 확인
- Callback URL 설정 확인
- Android/iOS 설정 확인

### 9.2 Workers API 호출 실패

- Workers 배포 상태 확인
- 환경 변수 설정 확인
- CORS 설정 확인

### 9.3 Supabase 세션 생성 실패

- Service Role Key 확인
- Supabase 프로젝트 설정 확인
- Workers 로그 확인

## 10. 추가 개선 사항

### 10.1 Authorization Code Flow (PKCE)

현재는 Implicit Flow를 사용하지만, 더 안전한 Authorization Code Flow로 변경할 수 있습니다.

### 10.2 에러 핸들링 강화

- 네트워크 에러 처리
- 토큰 만료 처리
- 사용자 취소 처리

### 10.3 로그인 상태 관리

- 자동 로그인
- 토큰 갱신
- 로그아웃 처리

## 11. 참고 자료

- [네이버 개발자 센터](https://developers.naver.com/)
- [Flutter Naver Login 패키지](https://pub.dev/packages/flutter_naver_login)
- [Cloudflare Workers 문서](https://developers.cloudflare.com/workers/)
- [Supabase Auth 문서](https://supabase.com/docs/guides/auth)

