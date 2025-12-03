# 소셜 로그인 → Signup 플로우 문제 해결 로드맵

**작성일**: 2025년 12월 03일  
**목적**: 소셜 로그인 → Signup 플로우의 모든 문제점을 해결하기 위한 단계별 로드맵

---

## 📋 목차

1. [전체 문제점 요약](#전체-문제점-요약)
2. [해결 우선순위](#해결-우선순위)
3. [Phase별 구현 계획](#phase별-구현-계획)
4. [상세 구현 가이드](#상세-구현-가이드)
5. [테스트 계획](#테스트-계획)

---

## 전체 문제점 요약

### 🔴 심각한 문제 (즉시 해결 필요)

1. **중복 프로필 체크**
   - `currentUser`와 `redirect`에서 모두 프로필 체크
   - 불필요한 RPC 호출로 인한 성능 저하

2. **타이밍 문제**
   - OAuth 콜백 후 세션 생성과 프로필 체크 사이의 타이밍 이슈
   - `signInWithOAuth` 직후 `currentUser` 호출 시 세션이 아직 생성되지 않을 수 있음

3. **Provider 정보 추출 불안정**
   - `appMetadata['provider']`가 항상 존재하지 않음
   - `identities`에서 추출하는 로직이 복잡하고 불안정

### 🟡 중간 문제 (단기 해결 필요)

4. **에러 처리 부족**
   - 네트워크 에러와 프로필 없음을 구분하지 못함
   - 프로필 체크 실패 시 재시도 로직 없음

5. **세션 상태 불일치**
   - 세션은 있지만 프로필이 없는 상태를 명확히 구분하지 못함
   - 임시 세션 상태를 별도로 관리하지 않음

6. **Signup 화면 접근 제어**
   - Signup 화면에서도 redirect가 실행되어 무한 루프 가능성

### 🟢 경미한 문제 (중기 개선)

7. **SignupScreen 미완성 UI**
   - `_buildSignupForm()`에 "회원가입 폼 (구현 예정)" 메시지 표시
   - 사용자 경험 저하

8. **회원가입 데이터 로컬 저장**
   - `SignupDataStorageService`를 사용하여 로컬에 저장
   - 불필요한 복잡도 증가 및 데이터 동기화 문제 가능성

9. **회원가입 진행 상황 표시 부재**
   - 현재 단계와 전체 단계가 표시되지 않음
   - 사용자가 진행 상황을 파악하기 어려움

10. **로딩 상태 관리**
    - OAuth 인증 중 로딩 상태가 명확하지 않음

11. **에러 메시지**
    - 프로필 없음 에러 메시지가 사용자에게 표시되지 않음

---

## 해결 우선순위

### Phase 1: 핵심 문제 해결 (1-2일)
- ✅ 중복 프로필 체크 제거
- ✅ 타이밍 문제 해결
- ✅ Provider 정보 추출 개선
- ✅ SignupScreen 미완성 UI 제거

### Phase 2: UX 개선 (2-3일)
- ✅ 회원가입 데이터 로컬 저장 제거
- ✅ 회원가입 진행 상황 표시 추가
- ✅ Signup 화면 접근 제어 개선

### Phase 3: 안정성 개선 (1-2일)
- ✅ 에러 처리 개선
- ✅ 세션 상태 명확화
- ✅ 로딩 상태 관리 개선

---

## Phase별 구현 계획

## Phase 1: 핵심 문제 해결

### 1.1 중복 프로필 체크 제거

**목표**: `getUserState()` 메서드를 추가하여 프로필 상태를 명확히 구분

**작업 내용**:
1. `AuthService`에 `UserState` enum 추가
2. `getUserState()` 메서드 구현
3. `redirect` 로직에서 `getUserState()` 사용
4. `currentUser`에서 중복 체크 제거

**파일**: `lib/services/auth_service.dart`

**예상 시간**: 2시간

---

### 1.2 타이밍 문제 해결

**목표**: `signInWithOAuth` 직후 `currentUser` 호출 제거

**작업 내용**:
1. `signInWithGoogle()` 반환 타입을 `Future<void>`로 변경
2. `signInWithKakao()` 반환 타입을 `Future<void>`로 변경
3. `AuthProvider`에서 반환 타입 변경에 맞춰 수정
4. `LoginScreen`에서 불필요한 처리 제거

**파일**:
- `lib/services/auth_service.dart`
- `lib/providers/auth_provider.dart`
- `lib/screens/auth/login_screen.dart`

**예상 시간**: 1시간

---

### 1.3 Provider 정보 추출 개선

**목표**: OAuth Provider 정보를 안정적으로 추출

**작업 내용**:
1. `_extractProvider()` 메서드 구현
2. 여러 소스에서 provider 정보 추출 (identities, appMetadata, userMetadata, email)
3. `redirect` 로직에서 `_extractProvider()` 사용

**파일**: `lib/config/app_router.dart`

**예상 시간**: 1.5시간

---

### 1.4 SignupScreen 미완성 UI 제거

**목표**: `_buildSignupForm()` 메서드 제거 및 불필요한 코드 정리

**작업 내용**:
1. `_buildSignupForm()` 메서드 제거
2. `_selectedUserType` 상태 제거 (사용하지 않음)
3. `build()` 메서드에서 `_buildSignupForm()` 호출 제거
4. 사용자 타입 선택 후 바로 다음 화면으로 이동하도록 수정

**파일**: `lib/screens/auth/signup_screen.dart`

**예상 시간**: 30분

---

## Phase 2: UX 개선

### 2.1 회원가입 데이터 로컬 저장 제거

**목표**: `SignupDataStorageService` 제거 및 메모리 상태 관리로 변경

**작업 내용**:
1. `SignupDataStorageService` 파일 삭제
2. `ReviewerSignupScreen`에서 로컬 저장 로직 제거
   - `_restoreSignupData()` 메서드 제거
   - `_saveSignupData()` 메서드 제거
   - `initState()`에서 `_restoreSignupData()` 호출 제거
   - 각 단계 완료 시 `_saveSignupData()` 호출 제거
3. `AdvertiserSignupScreen`에서도 동일하게 제거
4. 회원가입 완료 시 `clearAllSignupData()` 호출 제거

**파일**:
- `lib/services/signup_data_storage_service.dart` (삭제)
- `lib/screens/auth/reviewer_signup_screen.dart`
- `lib/screens/auth/advertiser_signup_screen.dart`

**예상 시간**: 2시간

**참고**: 
- 회원가입은 OAuth 세션이 유지되는 동안에만 진행되므로 로컬 저장이 불필요
- 사용자가 앱을 종료하면 세션이 유지되므로 데이터 손실 없음
- 앱을 완전히 삭제하거나 세션이 만료되면 회원가입을 처음부터 다시 시작하는 것이 정상 동작

---

### 2.2 회원가입 진행 상황 표시 추가

**목표**: 회원가입 화면에 현재 단계와 전체 단계를 표시하는 진행 표시기 추가

**작업 내용**:

#### 2.2.1 SignupScreen에 진행 표시기 추가

**파일**: `lib/screens/auth/signup_screen.dart`

```dart
Widget _buildUserTypeSelection() {
  return SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // 진행 표시기 추가
          _buildProgressIndicator(currentStep: 0, totalSteps: 4),
          const SizedBox(height: 32),
          // 기존 UI...
        ],
      ),
    ),
  );
}

Widget _buildProgressIndicator({required int currentStep, required int totalSteps}) {
  return Column(
    children: [
      Row(
        children: List.generate(totalSteps, (index) {
          final isActive = index < currentStep;
          final isCurrent = index == currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(
                right: index < totalSteps - 1 ? 4 : 0,
              ),
              decoration: BoxDecoration(
                color: isActive || isCurrent
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 8),
      Text(
        '1단계: 사용자 타입 선택',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}
```

#### 2.2.2 ReviewerSignupScreen에 진행 표시기 추가

**파일**: `lib/screens/auth/reviewer_signup_screen.dart`

```dart
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('리뷰어 회원가입'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: _buildProgressIndicator(),
      ),
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildStepContent(),
  );
}

Widget _buildProgressIndicator() {
  // 전체 4단계: 타입 선택(0) → 프로필(1) → SNS(2) → 회사(3)
  final totalSteps = 4;
  final currentStep = _currentStep + 1; // 0-based → 1-based
  
  final stepLabels = [
    '타입 선택',
    '프로필 입력',
    'SNS 연결',
    '회사 선택',
  ];
  
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
    child: Column(
      children: [
        Row(
          children: List.generate(totalSteps, (index) {
            final stepNumber = index + 1;
            final isActive = stepNumber < currentStep;
            final isCurrent = stepNumber == currentStep;
            
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: isActive || isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (index < totalSteps - 1)
                    const SizedBox(width: 4),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(totalSteps, (index) {
            final stepNumber = index + 1;
            final isActive = stepNumber < currentStep;
            final isCurrent = stepNumber == currentStep;
            
            return Expanded(
              child: Text(
                stepLabels[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive || isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[400],
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          '$currentStep / $totalSteps',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
```

**예상 시간**: 3시간

---

### 2.3 Signup 화면 접근 제어 개선

**목표**: Signup 화면에서 redirect 제외하여 무한 루프 방지

**작업 내용**:
1. `redirect` 로직에서 Signup 관련 경로는 redirect 제외
2. Signup 화면 내부에서 세션 확인 로직 추가

**파일**: `lib/config/app_router.dart`

```dart
redirect: (context, state) async {
  final matchedLocation = state.matchedLocation;
  
  // Signup 관련 경로는 redirect 제외
  if (matchedLocation.startsWith('/signup')) {
    return null;
  }
  
  // ... 기존 로직
}
```

**예상 시간**: 30분

---

## Phase 3: 안정성 개선

### 3.1 에러 처리 개선

**목표**: 네트워크 에러와 프로필 없음을 구분

**작업 내용**:
1. `getUserState()`에서 네트워크 에러 확인
2. 네트워크 에러는 재시도 가능하도록 처리
3. 프로필 없음은 명확히 구분

**파일**: `lib/services/auth_service.dart`

**예상 시간**: 2시간

---

### 3.2 세션 상태 명확화

**목표**: `UserState` enum을 사용하여 세션 상태 명확히 구분

**작업 내용**:
1. `UserState` enum 정의
2. `getUserState()` 메서드에서 명확한 상태 반환
3. 각 상태에 따른 적절한 처리

**파일**: `lib/services/auth_service.dart`

**예상 시간**: 1시간

---

### 3.3 로딩 상태 관리 개선

**목표**: OAuth 인증 중 명확한 로딩 상태 표시

**작업 내용**:
1. `LoginScreen`에서 로딩 상태 개선
2. OAuth 인증 중 명확한 피드백 제공

**파일**: `lib/screens/auth/login_screen.dart`

**예상 시간**: 1시간

---

## 상세 구현 가이드

### Phase 1.1: getUserState() 메서드 구현

**파일**: `lib/services/auth_service.dart`

```dart
// UserState enum 추가
enum UserState {
  notLoggedIn,      // 세션 없음
  loggedIn,         // 세션 있고 프로필 있음
  tempSession,      // 세션 있지만 프로필 없음 (OAuth 회원가입 필요)
}

// getUserState() 메서드 추가
Future<UserState> getUserState() async {
  final session = _supabase.auth.currentSession;
  if (session == null || session.user == null) {
    return UserState.notLoggedIn;
  }

  try {
    // 세션 만료 확인 및 토큰 갱신
    if (session.isExpired) {
      try {
        final refreshedSession = await _supabase.auth.refreshSession();
        if (refreshedSession.session == null) {
          return UserState.notLoggedIn;
        }
      } catch (refreshError) {
        // 토큰 갱신 실패 시 로그아웃 처리
        if (ErrorHandler.isMissingDestinationScopesError(refreshError) ||
            ErrorHandler.isOAuthClientIdError(refreshError)) {
          await _supabase.auth.signOut();
          return UserState.notLoggedIn;
        }
        // 네트워크 에러 등은 재시도 가능하므로 현재 상태 유지
        return UserState.loggedIn;
      }
    }

    // RPC 함수 호출로 안전한 프로필 조회
    await _supabase.rpc(
      'get_user_profile_safe',
      params: {'p_user_id': session.user!.id},
    );
    
    return UserState.loggedIn;
  } catch (e) {
    // 네트워크 에러 확인
    if (e is SocketException || e is TimeoutException) {
      // 네트워크 에러는 재시도 가능하므로 loggedIn으로 간주
      debugPrint('네트워크 에러 발생, 재시도 필요: $e');
      return UserState.loggedIn;
    }
    
    // 프로필 없음 확인
    final isProfileNotFound =
        e.toString().contains('User profile not found') ||
        (e is PostgrestException &&
            (e.code == 'PGRST116' ||
                e.message.contains('No rows returned')));
    
    if (isProfileNotFound) {
      return UserState.tempSession;
    }
    
    // 기타 에러는 로그인 상태로 간주 (재시도)
    debugPrint('프로필 조회 실패: $e');
    return UserState.loggedIn;
  }
}
```

---

### Phase 1.2: redirect 로직 개선

**파일**: `lib/config/app_router.dart`

```dart
redirect: (context, state) async {
  final matchedLocation = state.matchedLocation;
  final isLoggingIn = matchedLocation == '/login';
  final isRoot = matchedLocation == '/';
  final isMyPage = matchedLocation.startsWith('/mypage');
  
  // Signup 관련 경로는 redirect 제외
  if (matchedLocation.startsWith('/signup')) {
    return null;
  }

  // 1. 마이페이지 경로는 전역 redirect에서 특별 처리
  if (isMyPage) {
    final userState = await authService.getUserState();
    if (userState == UserState.notLoggedIn || userState == UserState.tempSession) {
      return '/login';
    }
    return null;
  }

  // 2. 사용자 상태 확인
  final userState = await authService.getUserState();

  // 3. 임시 세션 (프로필 없음) → signup으로 리다이렉트
  if (userState == UserState.tempSession) {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null && session.user != null) {
      final provider = _extractProvider(session.user!);
      return '/signup?type=oauth&provider=$provider';
    }
  }

  // 4. 비로그인 상태
  if (userState == UserState.notLoggedIn) {
    if (isLoggingIn) return null;
    return '/login';
  }

  // 5. 로그인 상태
  if (userState == UserState.loggedIn) {
    if (isLoggingIn || isRoot) return '/home';
  }

  return null;
}

// Provider 정보 추출 헬퍼 함수
String _extractProvider(User user) {
  // 1. identities에서 provider 추출 (가장 신뢰할 수 있음)
  if (user.identities != null && user.identities!.isNotEmpty) {
    final identity = user.identities!.firstWhere(
      (i) => i.provider != 'email',
      orElse: () => user.identities!.first,
    );
    if (identity.provider != 'email') {
      return identity.provider;
    }
  }
  
  // 2. appMetadata에서 추출
  final metadata = user.appMetadata;
  if (metadata.containsKey('provider')) {
    return metadata['provider'] as String;
  }
  
  // 3. userMetadata에서 추출
  final userMetadata = user.userMetadata;
  if (userMetadata != null && userMetadata.containsKey('provider')) {
    return userMetadata['provider'] as String;
  }
  
  // 4. email 도메인으로 추정 (google.com → google)
  if (user.email != null) {
    final domain = user.email!.split('@')[1];
    if (domain == 'gmail.com' || domain.contains('google')) {
      return 'google';
    }
  }
  
  // 5. fallback
  return 'unknown';
}
```

---

### Phase 1.3: OAuth 로그인 메서드 수정

**파일**: `lib/services/auth_service.dart`

```dart
// 반환 타입 변경: Future<app_user.User?> → Future<void>
Future<void> signInWithGoogle() async {
  try {
    await _googleSignIn.initialize(
      clientId: kIsWeb
          ? 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com'
          : null,
    );

    final redirectTo = kIsWeb
        ? null
        : 'com.smart-grow.smart-review://login-callback';

    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.inAppWebView
          : LaunchMode.externalApplication,
      redirectTo: redirectTo,
      queryParams: {'access_type': 'offline', 'prompt': 'consent'},
    );

    // ⚠️ currentUser 호출 제거
    // authStateChanges에서 자동으로 처리됨
  } catch (e) {
    throw Exception('Google 로그인 실패: $e');
  }
}

Future<void> signInWithKakao() async {
  try {
    if (kIsWeb) {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.kakao,
        authScreenLaunchMode: LaunchMode.inAppWebView,
      );
      // ⚠️ currentUser 호출 제거
    } else {
      final redirectTo = 'com.smart-grow.smart-review://login-callback';
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.kakao,
        authScreenLaunchMode: LaunchMode.externalApplication,
        redirectTo: redirectTo,
      );
      // ⚠️ currentUser 호출 제거
    }
  } catch (e) {
    throw Exception('Kakao 로그인 실패: $e');
  }
}
```

---

### Phase 1.4: SignupScreen 정리

**파일**: `lib/screens/auth/signup_screen.dart`

```dart
class _SignupScreenState extends ConsumerState<SignupScreen> {
  bool _isLoading = false;

  // ⚠️ _selectedUserType 제거 (사용하지 않음)

  @override
  void initState() {
    super.initState();
    if (widget.companyId != null) {
      _loadCompanyInfo(widget.companyId!);
    }
  }

  // ... 기존 메서드들

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildUserTypeSelection(), // ⚠️ _buildSignupForm() 제거
    );
  }

  Widget _buildUserTypeSelection() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 진행 표시기 추가
            _buildProgressIndicator(currentStep: 0, totalSteps: 4),
            const SizedBox(height: 32),
            const Text(
              '회원가입',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '어떤 용도로 사용하시나요?',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            // 리뷰어 버튼
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _onUserTypeSelected(app_user.UserType.user),
              // ... 기존 스타일
            ),
            const SizedBox(height: 16),
            // 광고주 버튼
            OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('광고주 회원가입은 준비 중입니다')),
                      );
                    },
              // ... 기존 스타일
            ),
          ],
        ),
      ),
    );
  }

  // ⚠️ _buildSignupForm() 메서드 제거

  Widget _buildProgressIndicator({required int currentStep, required int totalSteps}) {
    return Column(
      children: [
        Row(
          children: List.generate(totalSteps, (index) {
            final isActive = index < currentStep;
            final isCurrent = index == currentStep;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(
                  right: index < totalSteps - 1 ? 4 : 0,
                ),
                decoration: BoxDecoration(
                  color: isActive || isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          '1단계: 사용자 타입 선택',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
```

---

### Phase 2.1: SignupDataStorageService 제거

**작업 순서**:
1. `ReviewerSignupScreen`에서 로컬 저장 로직 제거
2. `AdvertiserSignupScreen`에서 로컬 저장 로직 제거
3. `SignupDataStorageService` 파일 삭제
4. import 문 정리

**파일**: `lib/screens/auth/reviewer_signup_screen.dart`

```dart
// ⚠️ import 제거
// import '../../services/signup_data_storage_service.dart';

class _ReviewerSignupScreenState extends ConsumerState<ReviewerSignupScreen> {
  // ... 기존 필드들

  @override
  void initState() {
    super.initState();
    _loadOAuthUserData();
    // ⚠️ _restoreSignupData() 호출 제거
  }

  // ... 기존 메서드들

  // ⚠️ _restoreSignupData() 메서드 제거

  // ⚠️ _saveSignupData() 메서드 제거

  void _onProfileComplete({
    required String displayName,
    required String phone,
    String? address,
  }) {
    setState(() {
      _displayName = displayName;
      _phone = phone;
      _address = address;
      _currentStep = 1;
    });
    // ⚠️ _saveSignupData() 호출 제거
  }

  void _onSNSComplete(List<Map<String, dynamic>> snsConnections) {
    setState(() {
      _snsConnections = snsConnections;
      _currentStep = 2;
    });
    // ⚠️ _saveSignupData() 호출 제거
  }

  void _onCompanyComplete(String? companyId) {
    setState(() {
      _selectedCompanyId = companyId;
    });
    // ⚠️ _saveSignupData() 호출 제거
    _completeSignup();
  }

  Future<void> _completeSignup() async {
    // ... 기존 로직

    if (mounted) {
      // ⚠️ clearAllSignupData() 호출 제거
      // await SignupDataStorageService.clearAllSignupData();
      
      context.go('/home');
      // ... 기존 로직
    }
  }
}
```

---

## 테스트 계획

### Phase 1 테스트

1. **중복 프로필 체크 제거 테스트**
   - OAuth 로그인 후 프로필 체크가 1번만 실행되는지 확인
   - RPC 호출 횟수 확인

2. **타이밍 문제 해결 테스트**
   - OAuth 로그인 후 세션이 정상적으로 생성되는지 확인
   - `authStateChanges`에서 정상적으로 처리되는지 확인

3. **Provider 정보 추출 테스트**
   - Google 로그인 후 provider가 'google'로 추출되는지 확인
   - Kakao 로그인 후 provider가 'kakao'로 추출되는지 확인
   - fallback 케이스 테스트

4. **SignupScreen UI 테스트**
   - "회원가입 폼 (구현 예정)" 메시지가 표시되지 않는지 확인
   - 사용자 타입 선택 후 바로 다음 화면으로 이동하는지 확인

### Phase 2 테스트

1. **로컬 저장 제거 테스트**
   - 회원가입 중 앱을 종료하고 다시 시작했을 때 데이터가 복원되지 않는지 확인
   - 회원가입 완료 후 로컬 저장소에 데이터가 남아있지 않은지 확인

2. **진행 상황 표시 테스트**
   - 각 단계에서 진행 표시기가 정상적으로 표시되는지 확인
   - 현재 단계와 전체 단계가 정확히 표시되는지 확인

3. **Signup 화면 접근 제어 테스트**
   - Signup 화면에서 redirect가 실행되지 않는지 확인
   - 무한 루프가 발생하지 않는지 확인

### Phase 3 테스트

1. **에러 처리 테스트**
   - 네트워크 에러 시 재시도 로직이 동작하는지 확인
   - 프로필 없음과 네트워크 에러를 구분하는지 확인

2. **세션 상태 테스트**
   - 각 상태가 정확히 구분되는지 확인
   - 임시 세션이 정상적으로 처리되는지 확인

3. **로딩 상태 테스트**
   - OAuth 인증 중 로딩 상태가 명확히 표시되는지 확인

---

## 예상 작업 시간

| Phase | 작업 | 예상 시간 |
|-------|------|----------|
| Phase 1 | 핵심 문제 해결 | 5시간 |
| Phase 2 | UX 개선 | 5.5시간 |
| Phase 3 | 안정성 개선 | 4시간 |
| **총계** | | **14.5시간** |

---

## 체크리스트

### Phase 1
- [ ] `getUserState()` 메서드 구현
- [ ] `redirect` 로직 개선
- [ ] `_extractProvider()` 메서드 구현
- [ ] OAuth 로그인 메서드 반환 타입 변경
- [ ] SignupScreen 미완성 UI 제거

### Phase 2
- [ ] SignupDataStorageService 제거
- [ ] ReviewerSignupScreen에서 로컬 저장 로직 제거
- [ ] AdvertiserSignupScreen에서 로컬 저장 로직 제거
- [ ] SignupScreen에 진행 표시기 추가
- [ ] ReviewerSignupScreen에 진행 표시기 추가
- [ ] Signup 화면 접근 제어 개선

### Phase 3
- [ ] 에러 처리 개선
- [ ] 세션 상태 명확화
- [ ] 로딩 상태 관리 개선

---

## 다음 단계

1. Phase 1부터 순차적으로 구현
2. 각 Phase 완료 후 테스트 수행
3. 문제 발견 시 즉시 수정
4. 모든 Phase 완료 후 전체 통합 테스트

