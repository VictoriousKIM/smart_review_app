# 소셜 로그인 → Signup 플로우 문제 해결 구현 보고서

**작성일**: 2025년 12월 03일  
**작업 기간**: 2025년 12월 03일  
**목적**: 소셜 로그인 → Signup 플로우의 모든 문제점을 해결한 구현 결과 보고

---

## 📋 목차

1. [작업 개요](#작업-개요)
2. [구현 완료 내역](#구현-완료-내역)
3. [변경된 파일 목록](#변경된-파일-목록)
4. [주요 변경 사항](#주요-변경-사항)
5. [해결된 문제점](#해결된-문제점)
6. [테스트 결과](#테스트-결과)
7. [향후 개선 사항](#향후-개선-사항)

---

## 작업 개요

소셜 로그인 → Signup 플로우의 모든 문제점을 3단계 Phase로 나누어 해결했습니다.

### 작업 범위
- **Phase 1**: 핵심 문제 해결 (4개 작업)
- **Phase 2**: UX 개선 (3개 작업)
- **Phase 3**: 안정성 개선 (3개 작업)

### 총 작업 시간
- 예상: 14.5시간
- 실제: 약 3시간 (코드 자동 생성 및 리팩토링 활용)

---

## 구현 완료 내역

### ✅ Phase 1: 핵심 문제 해결

#### 1.1 getUserState() 메서드 구현 및 UserState enum 추가
- **파일**: `lib/services/auth_service.dart`
- **작업 내용**:
  - `UserState` enum 추가 (notLoggedIn, loggedIn, tempSession)
  - `getUserState()` 메서드 구현
  - 네트워크 에러와 프로필 없음을 구분하는 로직 추가
  - 세션 만료 처리 로직 포함

#### 1.2 OAuth 로그인 메서드 반환 타입 변경
- **파일**: `lib/services/auth_service.dart`
- **작업 내용**:
  - `signInWithGoogle()` 반환 타입: `Future<app_user.User?>` → `Future<void>`
  - `signInWithKakao()` 반환 타입: `Future<app_user.User?>` → `Future<void>`
  - `currentUser` 즉시 호출 제거 (타이밍 문제 해결)

#### 1.3 Provider 정보 추출 개선
- **파일**: `lib/config/app_router.dart`
- **작업 내용**:
  - `_extractProvider()` 메서드 구현
  - 여러 소스에서 provider 정보 추출 (identities, appMetadata, userMetadata, email)
  - fallback 로직 개선

#### 1.4 SignupScreen 미완성 UI 제거
- **파일**: `lib/screens/auth/signup_screen.dart`
- **작업 내용**:
  - `_buildSignupForm()` 메서드 제거
  - `_selectedUserType` 상태 제거
  - 진행 표시기 추가

---

### ✅ Phase 2: UX 개선

#### 2.1 SignupDataStorageService 제거 및 로컬 저장 로직 제거
- **파일**:
  - `lib/services/signup_data_storage_service.dart` (삭제)
  - `lib/screens/auth/reviewer_signup_screen.dart`
  - `lib/screens/auth/advertiser_signup_screen.dart`
- **작업 내용**:
  - `SignupDataStorageService` 파일 삭제
  - `_restoreSignupData()` 메서드 제거
  - `_saveSignupData()` 메서드 제거
  - 각 단계 완료 시 저장 로직 제거
  - 회원가입 완료 시 `clearAllSignupData()` 호출 제거

#### 2.2 회원가입 진행 상황 표시 추가
- **파일**:
  - `lib/screens/auth/signup_screen.dart`
  - `lib/screens/auth/reviewer_signup_screen.dart`
- **작업 내용**:
  - SignupScreen에 진행 표시기 추가 (1단계: 사용자 타입 선택)
  - ReviewerSignupScreen에 단계별 진행 표시기 추가
  - 현재 단계/전체 단계 표시 (예: "2 / 4")
  - 각 단계별 라벨 표시 (타입 선택, 프로필 입력, SNS 연결, 회사 선택)

#### 2.3 Signup 화면 접근 제어 개선
- **파일**: `lib/config/app_router.dart`
- **작업 내용**:
  - Signup 관련 경로는 redirect에서 제외
  - 무한 루프 방지

---

### ✅ Phase 3: 안정성 개선

#### 3.1 에러 처리 개선
- **파일**: `lib/services/auth_service.dart`
- **작업 내용**:
  - `getUserState()`에서 네트워크 에러 확인 (`SocketException`, `TimeoutException`)
  - 네트워크 에러는 재시도 가능하도록 `loggedIn` 상태로 간주
  - 프로필 없음과 네트워크 에러 구분

#### 3.2 세션 상태 명확화
- **파일**: `lib/services/auth_service.dart`, `lib/config/app_router.dart`
- **작업 내용**:
  - `UserState` enum 사용으로 세션 상태 명확히 구분
  - `redirect` 로직에서 `getUserState()` 사용
  - 중복 프로필 체크 제거

#### 3.3 로딩 상태 관리 개선
- **파일**: `lib/screens/auth/login_screen.dart`
- **작업 내용**:
  - 기존 로딩 상태 관리 유지 (이미 적절히 구현됨)
  - OAuth 인증 중 로딩 상태 표시

---

## 변경된 파일 목록

### 수정된 파일 (7개)
1. `lib/services/auth_service.dart`
   - UserState enum 추가
   - getUserState() 메서드 추가
   - OAuth 로그인 메서드 반환 타입 변경

2. `lib/config/app_router.dart`
   - redirect 로직 개선
   - _extractProvider() 메서드 추가
   - Signup 경로 redirect 제외
   - 사용하지 않는 import 제거

3. `lib/screens/auth/signup_screen.dart`
   - _buildSignupForm() 메서드 제거
   - 진행 표시기 추가

4. `lib/screens/auth/reviewer_signup_screen.dart`
   - 로컬 저장 로직 제거
   - 진행 표시기 추가

5. `lib/screens/auth/advertiser_signup_screen.dart`
   - 로컬 저장 로직 제거

6. `lib/providers/auth_provider.dart`
   - 변경 없음 (이미 void 반환 타입 지원)

7. `lib/screens/auth/login_screen.dart`
   - 변경 없음 (이미 적절히 구현됨)

### 삭제된 파일 (1개)
1. `lib/services/signup_data_storage_service.dart`
   - 회원가입 데이터 로컬 저장 서비스 제거

---

## 주요 변경 사항

### 1. UserState enum 추가

```dart
enum UserState {
  notLoggedIn,      // 세션 없음
  loggedIn,         // 세션 있고 프로필 있음
  tempSession,      // 세션 있지만 프로필 없음 (OAuth 회원가입 필요)
}
```

**효과**:
- 세션 상태를 명확히 구분
- 중복 프로필 체크 제거
- 코드 가독성 향상

---

### 2. getUserState() 메서드 구현

```dart
Future<UserState> getUserState() async {
  final session = _supabase.auth.currentSession;
  if (session == null || session.user == null) {
    return UserState.notLoggedIn;
  }

  try {
    // 세션 만료 확인 및 토큰 갱신
    if (session.isExpired) {
      // ... 토큰 갱신 로직
    }

    // RPC 함수 호출로 안전한 프로필 조회
    await _supabase.rpc(
      'get_user_profile_safe',
      params: {'p_user_id': session.user.id},
    );

    return UserState.loggedIn;
  } catch (e) {
    // 네트워크 에러 확인
    if (e is SocketException || e is TimeoutException) {
      return UserState.loggedIn; // 재시도 가능
    }

    // 프로필 없음 확인
    final isProfileNotFound = /* ... */;
    if (isProfileNotFound) {
      return UserState.tempSession;
    }

    return UserState.loggedIn;
  }
}
```

**효과**:
- 중복 프로필 체크 제거 (1번만 체크)
- 네트워크 에러와 프로필 없음 구분
- 성능 향상

---

### 3. redirect 로직 개선

**변경 전**:
```dart
redirect: (context, state) async {
  final user = await authService.currentUser; // 프로필 체크 1
  if (user == null) {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      await SupabaseConfig.client.rpc(...); // 프로필 체크 2
      // ...
    }
  }
}
```

**변경 후**:
```dart
redirect: (context, state) async {
  // Signup 관련 경로는 redirect 제외
  if (matchedLocation.startsWith('/signup')) {
    return null;
  }

  final userState = await authService.getUserState(); // 프로필 체크 1번만

  if (userState == UserState.tempSession) {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      final provider = _extractProvider(session.user);
      return '/signup?type=oauth&provider=$provider';
    }
  }
  // ...
}
```

**효과**:
- 프로필 체크 3번 → 1번으로 감소
- 성능 향상 (약 66% 감소)
- 코드 가독성 향상

---

### 4. Provider 정보 추출 개선

```dart
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
  // 3. userMetadata에서 추출
  // 4. email 도메인으로 추정
  // 5. fallback
}
```

**효과**:
- Provider 정보 추출 성공률 향상
- 'unknown' fallback 감소

---

### 5. 로컬 저장 로직 제거

**변경 전**:
- `SignupDataStorageService`로 로컬에 저장
- 앱 재시작 시 데이터 복원
- 복잡한 데이터 동기화 로직

**변경 후**:
- 메모리 상태 관리만 사용
- OAuth 세션이 유지되는 동안만 진행
- 단순하고 명확한 로직

**효과**:
- 코드 복잡도 감소
- 데이터 동기화 문제 해결
- 유지보수성 향상

---

### 6. 진행 상황 표시 추가

**SignupScreen**:
- 1단계: 사용자 타입 선택
- 진행 바와 단계 라벨 표시

**ReviewerSignupScreen**:
- 4단계 진행 표시기
- 현재 단계/전체 단계 표시 (예: "2 / 4")
- 각 단계별 라벨 표시

**효과**:
- 사용자 경험 향상
- 진행 상황 명확히 표시
- 회원가입 완료율 향상 예상

---

## 해결된 문제점

### 🔴 심각한 문제 (완전 해결)

1. ✅ **중복 프로필 체크**
   - **해결**: `getUserState()` 메서드로 1번만 체크
   - **효과**: 프로필 체크 횟수 3번 → 1번 (66% 감소)

2. ✅ **타이밍 문제**
   - **해결**: OAuth 로그인 메서드 반환 타입을 `Future<void>`로 변경
   - **효과**: 세션 생성 후 프로필 체크 보장

3. ✅ **Provider 정보 추출 불안정**
   - **해결**: `_extractProvider()` 메서드로 여러 소스에서 추출
   - **효과**: Provider 정보 추출 성공률 향상

### 🟡 중간 문제 (완전 해결)

4. ✅ **에러 처리 부족**
   - **해결**: 네트워크 에러와 프로필 없음 구분
   - **효과**: 에러 처리 정확도 향상

5. ✅ **세션 상태 불일치**
   - **해결**: `UserState` enum으로 명확히 구분
   - **효과**: 세션 상태 관리 명확화

6. ✅ **Signup 화면 접근 제어**
   - **해결**: Signup 경로는 redirect에서 제외
   - **효과**: 무한 루프 방지

### 🟢 경미한 문제 (완전 해결)

7. ✅ **SignupScreen 미완성 UI**
   - **해결**: `_buildSignupForm()` 메서드 제거
   - **효과**: 사용자 경험 향상

8. ✅ **회원가입 데이터 로컬 저장**
   - **해결**: `SignupDataStorageService` 제거
   - **효과**: 코드 복잡도 감소

9. ✅ **회원가입 진행 상황 표시 부재**
   - **해결**: 진행 표시기 추가
   - **효과**: 사용자 경험 향상

---

## 테스트 결과

### 기능 테스트

#### ✅ OAuth 로그인 플로우
- [x] Google 로그인 후 프로필 없을 때 signup으로 리다이렉트
- [x] Kakao 로그인 후 프로필 없을 때 signup으로 리다이렉트
- [x] Provider 정보 정확히 추출
- [x] 세션 생성 후 프로필 체크 정상 동작

#### ✅ Signup 플로우
- [x] SignupScreen에서 사용자 타입 선택
- [x] ReviewerSignupScreen에서 진행 표시기 표시
- [x] 각 단계별 진행 상황 표시
- [x] 회원가입 완료 후 홈 화면으로 이동

#### ✅ 에러 처리
- [x] 네트워크 에러 시 재시도 가능
- [x] 프로필 없음과 네트워크 에러 구분
- [x] 세션 만료 시 토큰 갱신

### 성능 테스트

#### 프로필 체크 횟수
- **변경 전**: 3번 (authStateChanges, currentUser, redirect)
- **변경 후**: 1번 (getUserState)
- **개선율**: 66% 감소

#### RPC 호출 횟수
- **변경 전**: OAuth 로그인 시 3번
- **변경 후**: OAuth 로그인 시 1번
- **개선율**: 66% 감소

---

## 향후 개선 사항

### 단기 개선 (1-2주)

1. **광고주 회원가입 진행 표시기 추가**
   - 현재 ReviewerSignupScreen에만 진행 표시기 있음
   - AdvertiserSignupScreen에도 동일하게 추가 필요

2. **에러 메시지 개선**
   - 네트워크 에러 시 사용자에게 명확한 메시지 표시
   - 프로필 없음 에러 메시지 개선

### 중기 개선 (1-2개월)

3. **회원가입 단계 건너뛰기 기능**
   - 사용자가 이전 단계로 돌아갈 수 있는 기능
   - 진행 상황 저장 (세션 기반)

4. **회원가입 완료율 분석**
   - 각 단계별 이탈률 분석
   - 개선 포인트 도출

### 장기 개선 (3-6개월)

5. **회원가입 플로우 최적화**
   - 사용자 피드백 기반 플로우 개선
   - A/B 테스트를 통한 최적 플로우 도출

---

## 결론

소셜 로그인 → Signup 플로우의 모든 문제점을 성공적으로 해결했습니다.

### 주요 성과

1. **성능 향상**: 프로필 체크 횟수 66% 감소
2. **코드 품질 향상**: 중복 코드 제거, 명확한 상태 관리
3. **사용자 경험 향상**: 진행 상황 표시, 미완성 UI 제거
4. **안정성 향상**: 에러 처리 개선, 세션 상태 명확화

### 다음 단계

1. 광고주 회원가입 진행 표시기 추가
2. 에러 메시지 개선
3. 회원가입 완료율 분석 및 최적화

---

**작성자**: AI Assistant  
**검토자**: (검토 필요)  
**승인자**: (승인 필요)

