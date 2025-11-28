# 카카오 OAuth 설정 가이드

이 문서는 카카오 Developers 콘솔에서 OAuth Redirect URI를 설정하는 방법을 설명합니다.

## 📋 설정 체크리스트

### 1. 카카오 Developers 콘솔 접속
1. [Kakao Developers Console](https://developers.kakao.com/console/app/1277909/product/login) 접속
2. 카카오 계정으로 로그인

### 2. 카카오 로그인 설정 확인
1. **제품 설정** > **카카오 로그인** 메뉴로 이동
2. **Redirect URI** 섹션 확인

### 3. Redirect URI 등록 (필수!)

**중요**: 카카오 Developers 콘솔에는 **앱 딥링크가 아니라 Supabase 콜백 URL**을 등록해야 합니다.

다음 URL들을 모두 등록해야 합니다:

```
https://ythmnhadeyfusmfhcgdr.supabase.co/auth/v1/callback
http://127.0.0.1:54500/auth/v1/callback
http://localhost:54500/auth/v1/callback
```

**설정 방법:**
1. **Redirect URI** 섹션에서 **+ URI 추가** 버튼 클릭
2. 위 URL들을 하나씩 입력하여 추가
3. **저장** 버튼 클릭

### 4. OAuth 흐름 이해

```
[앱] → [카카오 로그인] → [Supabase 콜백] → [앱 딥링크]
  ↓                        ↓                    ↓
카카오 Developers      Supabase 대시보드    Android/iOS 설정
Redirect URI 설정      Redirect URLs 설정   딥링크 처리
```

**설명:**
1. 앱에서 카카오 로그인 시작
2. 카카오가 인증 후 **Supabase 콜백 URL**로 리다이렉트 (여기서 카카오 설정 사용)
3. Supabase가 인증 처리 후 **앱 딥링크**로 리다이렉트 (여기서 Supabase 설정 사용)
4. 앱이 딥링크를 받아서 세션 복원

### 5. 현재 설정 상태

#### ✅ 완료된 설정
- **Flutter 코드**: `redirectTo: 'com.smart_grow.smart_review://login-callback'`
- **Android 설정**: `android:scheme="com.smart_grow.smart_review" android:host="login-callback"`
- **iOS 설정**: `com.smart_grow.smart_review`
- **Supabase 대시보드**: `com.smart_grow.smart_review://login-callback` 등록됨

#### ⚠️ 확인 필요
- **카카오 Developers 콘솔**: Supabase 콜백 URL 등록 확인 필요
  - `https://ythmnhadeyfusmfhcgdr.supabase.co/auth/v1/callback`
  - `http://127.0.0.1:54500/auth/v1/callback` (로컬 개발용)
  - `http://localhost:54500/auth/v1/callback` (로컬 개발용)

## 🔍 문제 해결

### 문제: `localhost:3001/?code=...`로 리다이렉트됨

**원인**: Supabase가 `redirectTo` 파라미터를 무시하고 Site URL로 리다이렉트

**해결 방법**:
1. ✅ Flutter 코드에서 `redirectTo` 파라미터 확인
2. ✅ Supabase 대시보드에서 Redirect URLs 확인
3. ⚠️ **카카오 Developers 콘솔에서 Supabase 콜백 URL 등록 확인** (현재 단계)
4. 앱 재빌드 및 재설치

### 문제: 카카오 로그인 후 앱으로 돌아오지 않음

**원인**: 카카오 Developers 콘솔에 Supabase 콜백 URL이 등록되지 않음

**해결 방법**:
1. 카카오 Developers 콘솔 접속
2. **제품 설정** > **카카오 로그인** > **Redirect URI** 확인
3. Supabase 콜백 URL이 등록되어 있는지 확인
4. 없으면 추가하고 저장

## 📝 참고 사항

### 카카오 Developers 콘솔 설정 위치
- **URL**: [Kakao Developers Console - 카카오 로그인](https://developers.kakao.com/console/app/1277909/product/login)
- **앱 키**: [Kakao Developers Console - 앱 키](https://developers.kakao.com/console/app/1277909/appkey)

### Supabase 콜백 URL 형식
- **프로덕션**: `https://{PROJECT_ID}.supabase.co/auth/v1/callback`
- **로컬**: `http://127.0.0.1:{PORT}/auth/v1/callback` 또는 `http://localhost:{PORT}/auth/v1/callback`

### 앱 딥링크 vs Supabase 콜백 URL
- **카카오 Developers 콘솔**: Supabase 콜백 URL 등록 (앱 딥링크 ❌)
- **Supabase 대시보드**: 앱 딥링크 등록 (Supabase 콜백 URL ❌)

## ✅ 설정 완료 확인

설정이 완료되면 다음을 확인하세요:

1. ✅ 카카오 Developers 콘솔에 Supabase 콜백 URL 등록됨
2. ✅ Supabase 대시보드에 앱 딥링크 등록됨
3. ✅ Android/iOS 매니페스트 파일에 딥링크 설정됨
4. ✅ Flutter 코드에 `redirectTo` 파라미터 설정됨

모든 설정이 완료되면 앱을 재빌드하고 카카오 로그인을 테스트하세요.

