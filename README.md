# Smart Review App

리뷰 캠페인 플랫폼 Flutter 앱입니다.

## 📱 기능

### 인증 시스템
- 이메일/비밀번호 회원가입 및 로그인
- Google 소셜 로그인
- Kakao 소셜 로그인
- Supabase 기반 인증 관리

### 사용자 타입
- **리뷰어**: 리뷰를 작성하고 캠페인에 참여
- **광고주**: 캠페인을 관리하고 리뷰를 확인

### 캠페인 관리
- 캠페인 목록 조회
- 캠페인 상세 정보
- 캠페인 검색 및 필터링
- 캠페인 참여/취소

### 리뷰 시스템
- 리뷰 작성 및 수정
- 리뷰 목록 조회
- 리뷰 좋아요/댓글
- 리뷰 상태 관리 (대기/승인/거부)

### UI/UX
- Material Design 3 기반
- 반응형 디자인
- 다크/라이트 테마 지원
- 직관적인 네비게이션

## 🛠 기술 스택

### Frontend
- **Flutter** 3.9.2
- **Dart** 3.9.2
- **Riverpod** - 상태 관리
- **Go Router** - 라우팅

### Backend
- **Supabase** - 백엔드 서비스
- **PostgreSQL** - 데이터베이스
- **Supabase Auth** - 인증

### 외부 서비스
- **Google Sign-In** - Google 로그인
- **Kakao SDK** - Kakao 로그인

### 주요 패키지
- `supabase_flutter` - Supabase 클라이언트
- `flutter_riverpod` - 상태 관리
- `go_router` - 라우팅
- `cached_network_image` - 이미지 캐싱
- `flutter_rating_bar` - 평점 UI
- `shimmer` - 로딩 애니메이션

## 📁 프로젝트 구조

```
lib/
├── config/           # 설정 파일
│   └── supabase_config.dart
├── models/           # 데이터 모델
│   ├── user.dart
│   ├── campaign.dart
│   ├── review.dart
│   └── api_response.dart
├── services/         # 비즈니스 로직
│   ├── auth_service.dart
│   ├── campaign_service.dart
│   └── review_service.dart
├── providers/        # 상태 관리
│   ├── auth_provider.dart
│   └── campaign_provider.dart
├── screens/          # 화면
│   ├── auth/
│   │   └── login_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── campaign/
│   │   └── campaign_detail_screen.dart
│   ├── profile/
│   │   └── profile_screen.dart
│   └── splash_screen.dart
├── widgets/          # 재사용 가능한 위젯
│   ├── custom_button.dart
│   ├── custom_text_field.dart
│   ├── campaign_card.dart
│   └── bottom_navigation.dart
└── main.dart         # 앱 진입점
```

## 🚀 시작하기

### 필수 요구사항
- Flutter SDK 3.9.2 이상
- Dart SDK 3.9.2 이상
- Android Studio / VS Code
- Android SDK (Android 개발용)
- Xcode (iOS 개발용)

### 설치 및 실행

1. **저장소 클론**
   ```bash
   git clone <repository-url>
   cd smart_review_app
   ```

2. **의존성 설치**
   ```bash
   flutter pub get
   ```

3. **Supabase 설정**
   - Supabase 프로젝트 생성
   - `lib/config/supabase_config.dart`에서 URL과 키 업데이트

4. **앱 실행**
   ```bash
   # 디버그 모드
   flutter run
   
   # 릴리스 모드
   flutter run --release
   ```

### 빌드

```bash
# Android APK
flutter build apk

# iOS IPA
flutter build ios

# 웹
flutter build web
```

## 🔧 설정

### Supabase 설정
1. [Supabase](https://supabase.com)에서 새 프로젝트 생성
2. 프로젝트 URL과 anon key 복사
3. `lib/config/supabase_config.dart` 파일 수정

### Google 로그인 설정
1. [Google Cloud Console](https://console.cloud.google.com)에서 프로젝트 생성
2. OAuth 2.0 클라이언트 ID 생성
3. Android/iOS 앱에 SHA-1 지문 추가

### Kakao 로그인 설정
1. [Kakao Developers](https://developers.kakao.com)에서 앱 등록
2. 플랫폼 설정 (Android/iOS)
3. 네이티브 앱 키 설정

## 📱 지원 플랫폼

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 `LICENSE` 파일을 참조하세요.

## 📞 문의

프로젝트에 대한 문의사항이 있으시면 이슈를 생성해 주세요.

---

**Smart Review App** - 리뷰 캠페인 플랫폼으로 더 나은 리뷰 문화를 만들어가세요! 🚀