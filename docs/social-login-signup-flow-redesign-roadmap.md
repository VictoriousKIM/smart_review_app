# 소셜 로그인 회원가입 플로우 재설계 로드맵

**작성일**: 2025년 12월 2일  
**목적**: 소셜 로그인 시 프로필 자동 생성 대신 명시적 회원가입 플로우로 변경

---

## 📋 목차

1. [현재 문제점](#현재-문제점)
2. [새로운 플로우 설계](#새로운-플로우-설계)
3. [예상 문제점 및 해결방법](#예상-문제점-및-해결방법)
4. [구현 로드맵](#구현-로드맵)
5. [상세 구현 가이드](#상세-구현-가이드)

---

## 현재 문제점

### 1. 프로필 자동 생성의 문제

**현재 동작**:
- OAuth 로그인 시 프로필이 없으면 자동으로 생성
- 사용자 타입이 항상 `user`로 고정
- 리뷰어/광고주 구분 불가
- 추가 정보 입력 없이 기본값으로 생성

**문제점**:
- 리뷰어와 광고주를 구분할 수 없음
- 광고주는 사업자 인증이 필수인데 자동 생성 시 누락
- 리뷰어는 SNS 연결 정보가 필요한데 자동 생성 시 누락
- 회사 연결 정보 입력 불가

### 2. ⚠️ **심각한 문제: auth 없는데 프로필 자동 생성**

**문제 시나리오**:
1. **세션 만료/손상 시 프로필 자동 생성**
   - 세션이 만료되었거나 손상되었는데 `user` 객체는 남아있음
   - `currentUser` 또는 `authStateChanges`에서 프로필 조회 실패
   - 네트워크 에러를 "프로필 없음"으로 오판
   - 자동으로 프로필 생성 → **잘못된 프로필 생성**

2. **Race Condition (동시 호출)**
   - `currentUser`와 `authStateChanges`가 동시에 호출
   - 둘 다 프로필이 없다고 판단
   - 동시에 프로필 생성 시도 → **중복 생성 시도** (DB 제약으로 실패하지만 불필요한 에러)

3. **네트워크 에러 오판**
   - 프로필 조회 중 네트워크 에러 발생
   - `PGRST116` 에러로 오판하여 "프로필 없음"으로 처리
   - 자동으로 프로필 생성 → **이미 프로필이 있는데 중복 생성 시도**

4. **직접 확인 로직의 한계**
   ```dart
   // 현재 코드: 직접 확인 후에도 프로필 생성 시도
   final directCheck = await _supabase
       .from('users')
       .select('id')
       .eq('id', user.id)
       .maybeSingle();
   
   if (directCheck != null) {
     return; // 프로필 존재
   }
   // 프로필 생성 시도 ← 여기서도 타이밍 이슈 가능
   ```
   - 직접 확인과 프로필 생성 사이에 다른 요청이 프로필을 생성할 수 있음
   - Race condition 여전히 가능

**현재 코드의 문제점**:
```dart
// auth_service.dart - currentUser
if (user != null) {  // ← user 객체만 확인, 세션 유효성 미검증
  try {
    final profileResponse = await _supabase.rpc(...);
  } catch (e) {
    if (isProfileNotFound) {
      if (isOAuthUser) {
        await _ensureUserProfile(...);  // ← 자동 생성
      }
    }
  }
}
```

**문제**:
- `user` 객체가 있으면 세션이 유효하다고 가정
- 하지만 세션이 만료되었거나 손상되었을 수 있음
- 네트워크 에러를 "프로필 없음"으로 오판 가능

---

## 새로운 플로우 설계

### 전체 플로우 다이어그램

```
소셜 로그인 버튼 클릭
    ↓
OAuth 인증 (Google/Kakao)
    ↓
auth.users에 사용자 생성 (Supabase 자동)
    ↓
프로필 확인
    ↓
프로필 없음? → /signup으로 리다이렉트
    ↓
사용자 타입 선택 (리뷰어/광고주)
    ↓
┌─────────────────┬─────────────────┐
│   리뷰어 플로우  │   광고주 플로우  │
├─────────────────┼─────────────────┤
│ 1. 프로필 입력   │ 1. 사업자 인증   │
│ 2. SNS 연결      │ 2. 입출금통장    │
│ 3. 회사 선택     │ 3. 회원가입      │
│ 4. 회원가입      │                 │
└─────────────────┴─────────────────┘
    ↓
트랜잭션으로 auth + DB 생성
    ↓
로그인 완료
```

### 상세 플로우

#### 1단계: 소셜 로그인

```
사용자 → "Google로 로그인" / "Kakao로 로그인" 클릭
    ↓
OAuth 인증 진행
    ↓
auth.users에 사용자 생성 (Supabase 자동)
    ↓
세션 생성 (임시)
```

#### 2단계: 프로필 확인 및 리다이렉트

```
authStateChanges 트리거
    ↓
프로필 조회 시도
    ↓
프로필 없음 감지
    ↓
/signup?type=oauth&provider=google&email=xxx 로 리다이렉트
```

#### 3단계: 사용자 타입 선택

```
/signup 화면 표시
    ↓
"리뷰어로 시작하기" / "광고주로 시작하기" 버튼
    ↓
선택한 타입에 따라 다음 단계로 이동
```

#### 4-A단계: 리뷰어 회원가입 플로우

```
1. 프로필 입력 화면
   - 이름 (OAuth에서 가져온 값 기본값)
   - 전화번호
   - 주소 (선택)
   ↓
2. SNS 연결 화면
   - Instagram, YouTube, TikTok, Blog 등
   - 플랫폼별 계정 ID, 계정명, 전화번호 입력
   - 스토어 플랫폼은 주소 필수
   ↓
3. 회사 선택 화면
   - 회사 검색 (회사명 또는 사업자번호)
   - URL 쿠키에 companyid가 있으면 자동 선택
   - "건너뛰기" 버튼 (선택)
   ↓
4. 회원가입 완료
   - "회원가입하기" 버튼 클릭
   - 트랜잭션으로 프로필 생성
   - 회사 선택 시 company_users 레코드 생성
   - SNS 연결 정보 저장
   - 홈 화면으로 이동
```

#### 4-B단계: 광고주 회원가입 플로우

```
1. 사업자 인증 화면
   - 사업자등록증 이미지 업로드
   - AI 추출 및 검증 (기존 로직 활용)
   - 사업자등록번호, 회사명, 대표자명 등 확인
   ↓
2. 입출금통장 입력 화면
   - 은행명
   - 계좌번호
   - 예금주명
   - 계좌 검증 (선택)
   ↓
3. 회원가입 완료
   - "회원가입하기" 버튼 클릭
   - 트랜잭션으로 프로필 생성
   - 회사 생성 (register_company RPC)
   - company_users 레코드 생성 (owner)
   - 지갑 생성 및 계좌 정보 저장
   - 홈 화면으로 이동
```

---

## 예상 문제점 및 해결방법

### 문제 1: ⚠️ **auth 없는데 프로필 자동 생성 문제 해결**

**현재 문제**:
- 세션이 만료/손상되었는데 `user` 객체는 남아있음
- 네트워크 에러를 "프로필 없음"으로 오판
- 자동으로 프로필 생성 → 잘못된 프로필 생성

**새로운 플로우로 해결**:
- ✅ **프로필 자동 생성 로직 완전 제거**
  - `currentUser`에서 자동 생성 제거
  - `authStateChanges`에서 자동 생성 제거
  - 프로필 없으면 `null` 반환

- ✅ **세션 유효성 검증 강화**
  ```dart
  Future<app_user.User?> get currentUser async {
    final session = _supabase.auth.currentSession;
    
    // 세션 유효성 검증
    if (session == null || session.isExpired) {
      return null;  // 세션 없음/만료 → 프로필 생성 안 함
    }
    
    final user = session.user;
    if (user == null) {
      return null;  // user 객체 없음 → 프로필 생성 안 함
    }
    
    try {
      // 프로필 조회만 수행 (자동 생성 제거)
      final profileResponse = await _supabase.rpc(...);
      // 프로필 있으면 반환
    } catch (e) {
      // 프로필 없으면 null 반환 (자동 생성 안 함)
      return null;
    }
  }
  ```

- ✅ **명시적 회원가입만 프로필 생성**
  - 프로필 생성은 오직 `/signup` 화면에서만 수행
  - 사용자가 명시적으로 "회원가입하기" 버튼 클릭 시에만 생성
  - 트랜잭션으로 안전하게 처리

**결과**:
- ❌ **기존**: auth 없어도 프로필 자동 생성 가능 (문제 발생)
- ✅ **변경**: auth 유효하고 명시적 회원가입 시에만 프로필 생성 (문제 해결)

---

### 문제 2: OAuth 콜백 후 세션 생성 전에 signup 화면으로 이동

**문제**:
- OAuth 인증 완료 후 Supabase가 자동으로 세션 생성
- 세션이 생성되면 `authStateChanges`가 트리거됨
- 프로필이 없어도 세션은 이미 생성된 상태

**해결방법**:
1. **임시 세션 상태 관리**
   - 프로필이 없는 세션을 "임시 세션"으로 표시
   - `authStateChanges`에서 프로필 없음 감지 시 `/signup`으로 리다이렉트
   - 임시 세션은 제한된 권한만 부여

2. **라우터 리다이렉트 로직 수정**
   ```dart
   redirect: (context, state) async {
     final user = await authService.currentUser;
     if (user == null) {
       // 프로필이 없는 임시 세션인 경우
       final session = supabase.auth.currentSession;
       if (session != null && session.user != null) {
         // 프로필 확인
         try {
           await supabase.rpc('get_user_profile_safe', 
             params: {'p_user_id': session.user!.id});
         } catch (e) {
           // 프로필 없음 → signup으로 리다이렉트
           return '/signup?type=oauth&provider=${session.user!.appMetadata['provider']}';
         }
       }
       return '/login';
     }
     // ... 기존 로직
   }
   ```

---

### 문제 2: 트랜잭션 처리 (auth.users + public.users)

**문제**:
- `auth.users`는 Supabase가 자동 생성
- `public.users`는 애플리케이션에서 생성
- 두 작업이 분리되어 있어 트랜잭션 보장 어려움

**해결방법**:
1. **RPC 함수로 트랜잭션 처리**
   ```sql
   CREATE OR REPLACE FUNCTION create_user_profile_with_company(
     p_user_id UUID,
     p_display_name TEXT,
     p_user_type TEXT,
     p_phone TEXT,
     p_address TEXT,
     -- 리뷰어용
     p_company_id UUID DEFAULT NULL,
     p_sns_connections JSONB DEFAULT NULL,
     -- 광고주용
     p_business_name TEXT DEFAULT NULL,
     p_business_number TEXT DEFAULT NULL,
     p_bank_name TEXT DEFAULT NULL,
     p_account_number TEXT DEFAULT NULL,
     p_account_holder TEXT DEFAULT NULL
   ) RETURNS JSONB
   LANGUAGE plpgsql
   SECURITY DEFINER
   AS $$
   DECLARE
     v_profile_id UUID;
     v_company_id UUID;
   BEGIN
     -- 트랜잭션 시작 (자동)
     
     -- 1. 프로필 생성
     INSERT INTO public.users (...) VALUES (...) RETURNING id INTO v_profile_id;
     
     -- 2. 지갑 생성 (트리거로 자동)
     
     -- 3-A. 리뷰어인 경우
     IF p_user_type = 'reviewer' THEN
       -- SNS 연결 생성
       IF p_sns_connections IS NOT NULL THEN
         -- JSONB 배열을 순회하며 INSERT
       END IF;
       
       -- 회사 연결 (선택)
       IF p_company_id IS NOT NULL THEN
         INSERT INTO public.company_users (...) VALUES (...);
       END IF;
     END IF;
     
     -- 3-B. 광고주인 경우
     IF p_user_type = 'advertiser' THEN
       -- 회사 생성
       INSERT INTO public.companies (...) VALUES (...) RETURNING id INTO v_company_id;
       
       -- company_users 생성 (owner)
       INSERT INTO public.company_users (...) VALUES (...);
       
       -- 지갑 계좌 정보 업데이트
       UPDATE public.wallets SET 
         withdraw_bank_name = p_bank_name,
         withdraw_account_number = p_account_number,
         withdraw_account_holder = p_account_holder
       WHERE company_id = v_company_id AND user_id IS NULL;
     END IF;
     
     -- 트랜잭션 커밋 (자동)
     RETURN jsonb_build_object('success', true, 'user_id', v_profile_id);
   EXCEPTION
     WHEN OTHERS THEN
       -- 트랜잭션 롤백 (자동)
       RAISE EXCEPTION '회원가입 실패: %', SQLERRM;
   END;
   $$;
   ```

2. **에러 처리**
   - 프로필 생성 실패 시 `auth.users`는 그대로 유지
   - 사용자가 다시 시도할 수 있도록 세션 유지
   - 또는 Edge Function에서 `auth.admin.deleteUser()` 호출하여 정리

---

### 문제 3: 쿠키/URL 파라미터에서 companyid 전달

**문제**:
- 회사 초대 링크에서 `companyid`를 전달해야 함
- 웹에서는 쿠키, 모바일에서는 딥링크 파라미터 사용

**해결방법**:
1. **URL 파라미터 사용**
   ```
   /signup?type=oauth&provider=google&companyid=xxx-xxx-xxx
   ```

2. **쿠키 사용 (웹)**
   ```dart
   // 쿠키에서 companyid 읽기
   final cookies = await getCookies();
   final companyId = cookies['companyid'];
   ```

3. **딥링크 파라미터 (모바일)**
   ```
   com.smart-grow.smart-review://signup?companyid=xxx-xxx-xxx
   ```

4. **회원가입 화면에서 처리**
   ```dart
   class SignupScreen extends StatefulWidget {
     final String? companyId; // URL 파라미터 또는 쿠키에서 가져온 값
     
     @override
     void initState() {
       super.initState();
       // companyId가 있으면 회사 정보 미리 로드
       if (widget.companyId != null) {
         _loadCompanyInfo(widget.companyId!);
       }
     }
   }
   ```

---

### 문제 4: 사업자 인증 API 연동

**문제**:
- 사업자등록번호 검증 API 연동 필요
- 이미지 업로드 및 AI 추출 로직 필요

**해결방법**:
1. **기존 로직 활용**
   - `workers/index.ts`의 `handleVerifyAndRegister` 함수 활용
   - `business_registration_form.dart`의 UI 재사용

2. **회원가입 플로우에 통합**
   ```dart
   class AdvertiserSignupScreen extends StatefulWidget {
     // 사업자 인증 단계
     Future<void> _verifyBusiness() async {
       // 이미지 업로드
       // Workers API 호출
       // 검증 결과 확인
     }
   }
   ```

---

### 문제 5: 입출금통장 검증

**문제**:
- 계좌번호 유효성 검증 필요
   - 은행 API 연동 또는 간단한 형식 검증

**해결방법**:
1. **형식 검증**
   ```dart
   String? validateAccountNumber(String accountNumber) {
     // 숫자만 허용
     if (!RegExp(r'^\d+$').hasMatch(accountNumber)) {
       return '계좌번호는 숫자만 입력 가능합니다';
     }
     // 길이 검증 (은행별로 다를 수 있음)
     if (accountNumber.length < 10 || accountNumber.length > 20) {
       return '계좌번호 형식이 올바르지 않습니다';
     }
     return null;
   }
   ```

2. **은행 API 연동 (선택)**
   - 오픈뱅킹 API 또는 은행별 API 연동
   - 실명 확인 및 계좌 유효성 검증

---

### 문제 6: SNS 연결 정보 저장

**문제**:
- 여러 SNS 플랫폼 정보를 한 번에 저장
- 스토어 플랫폼은 주소 필수

**해결방법**:
1. **기존 RPC 함수 활용**
   ```sql
   -- create_sns_connection RPC 함수 사용
   -- 여러 번 호출하여 각 플랫폼별로 저장
   ```

2. **배치 저장 RPC 함수 생성**
   ```sql
   CREATE OR REPLACE FUNCTION create_sns_connections_batch(
     p_user_id UUID,
     p_connections JSONB -- [{platform, account_id, account_name, phone, address}, ...]
   ) RETURNS JSONB
   AS $$
   BEGIN
     -- JSONB 배열을 순회하며 각각 create_sns_connection 호출
   END;
   $$;
   ```

---

### 문제 7: ⚠️ **기존 자동 생성 로직 제거 (핵심 해결책)**

**문제**:
- `authStateChanges`와 `currentUser`에서 프로필 자동 생성 로직 제거 필요
- 기존 사용자와의 호환성 유지
- **auth 없는데 프로필 자동 생성 문제의 근본 원인**

**해결방법**:
1. **자동 생성 로직 완전 제거**
   ```dart
   // auth_service.dart - currentUser
   Future<app_user.User?> get currentUser async {
     final session = _supabase.auth.currentSession;
     
     // 세션 유효성 검증 강화
     if (session == null || session.isExpired) {
       return null;  // 세션 없음/만료
     }
     
     final user = session.user;
     if (user == null) {
       return null;  // user 객체 없음
     }
     
     try {
       // 프로필 조회만 수행 (자동 생성 제거)
       final profileResponse = await _supabase.rpc(
         'get_user_profile_safe',
         params: {'p_user_id': user.id},
       );
       
       // 프로필 있으면 반환
       return userProfile;
     } catch (e) {
       // 프로필 없으면 null 반환 (자동 생성 안 함)
       final isProfileNotFound = /* ... */;
       if (isProfileNotFound) {
         debugPrint('프로필이 없습니다. 회원가입이 필요합니다: ${user.id}');
         return null;  // ← 자동 생성 제거
       }
       return null;
     }
   }
   
   // authStateChanges도 동일하게 수정
   Stream<app_user.User?> get authStateChanges {
     return _supabase.auth.onAuthStateChange.asyncMap((authState) async {
       final user = authState.session?.user;
       if (user != null) {
         try {
           // 프로필 조회만 수행 (자동 생성 제거)
           // ...
         } catch (e) {
           // 프로필 없으면 null 반환 (자동 생성 안 함)
           return null;  // ← 자동 생성 제거
         }
       }
       return null;
     });
   }
   ```

2. **기존 사용자 호환성**
   - 이미 프로필이 있는 사용자는 기존 로직 유지 (프로필 조회만 수행)
   - 프로필이 없는 사용자만 signup으로 리다이렉트

3. **라우터에서 signup으로 리다이렉트**
   ```dart
   // app_router.dart
   redirect: (context, state) async {
     final user = await authService.currentUser;
     if (user == null) {
       // 프로필이 없는 임시 세션 확인
       final session = supabase.auth.currentSession;
       if (session != null && session.user != null) {
         // 프로필 확인
         try {
           await supabase.rpc('get_user_profile_safe', 
             params: {'p_user_id': session.user!.id});
         } catch (e) {
           // 프로필 없음 → signup으로 리다이렉트
           return '/signup?type=oauth&provider=${session.user!.appMetadata['provider']}';
         }
       }
       return '/login';
     }
     // ... 기존 로직
   }
   ```

**결과**:
- ✅ **auth 없는데 프로필 자동 생성 문제 완전 해결**
- ✅ **Race condition 문제 해결** (자동 생성 자체가 없으므로)
- ✅ **네트워크 에러 오판 문제 해결** (자동 생성 안 하므로)
- ✅ **명시적 회원가입만 프로필 생성** (안전성 향상)

---

### 문제 8: OAuth 세션 임시 저장 및 회원가입 완료 후 활성화

**문제**:
- OAuth 인증 완료 후 세션이 생성되지만 프로필이 없음
- 회원가입 완료 전까지 세션을 유지해야 함
- 회원가입 중단 시 세션 정리 필요

**해결방법**:
1. **임시 세션 상태 관리**
   ```dart
   // 세션은 그대로 유지하되, 프로필이 없으면 제한된 권한
   // 회원가입 완료 시 프로필 생성으로 정상 세션으로 전환
   ```

2. **회원가입 중단 처리**
   ```dart
   // 사용자가 회원가입을 중단하면
   // 1. 세션 유지 (다시 시도 가능)
   // 2. 또는 세션 삭제 (Edge Function에서 auth.admin.deleteUser 호출)
   ```

---

### 문제 9: 플랫폼별 처리 (웹/모바일)

**문제**:
- 웹과 모바일의 OAuth 처리 방식이 다름
- 딥링크 처리 방식 차이

**해결방법**:
1. **공통 로직 사용**
   - `authStateChanges`에서 프로필 확인 로직 공통화
   - 플랫폼별 차이는 OAuth 인증 단계에서만 처리

2. **딥링크 처리**
   ```dart
   // main.dart
   void _processDeepLink(Uri uri) async {
     if (uri.scheme == 'com.smart-grow.smart-review') {
       if (uri.host == 'signup') {
         // 회원가입 딥링크 처리
         final companyId = uri.queryParameters['companyid'];
         // signup 화면으로 이동
       }
     }
   }
   ```

---

### 문제 10: 회원가입 중 데이터 유실 방지

**문제**:
- 사용자가 회원가입 중 브라우저를 닫거나 앱을 종료할 수 있음
- 입력한 데이터 유실

**해결방법**:
1. **로컬 스토리지에 임시 저장**
   ```dart
   // SharedPreferences 또는 Hive 사용
   await prefs.setString('signup_data', jsonEncode({
     'userType': 'reviewer',
     'displayName': '홍길동',
     'phone': '010-1234-5678',
     // ...
   }));
   ```

2. **세션 복원 시 데이터 복원**
   ```dart
   // signup 화면 진입 시
   final savedData = prefs.getString('signup_data');
   if (savedData != null) {
     final data = jsonDecode(savedData);
     // 폼에 데이터 복원
   }
   ```

---

## 구현 로드맵

### Phase 1: 기반 구조 구축 (3일)

#### 1.1 라우팅 및 리다이렉트 로직 수정
- [ ] `app_router.dart`에 `/signup` 경로 추가
- [ ] 프로필 없음 감지 시 `/signup`으로 리다이렉트 로직 추가
- [ ] URL 파라미터 처리 (type, provider, companyid)

#### 1.2 자동 생성 로직 제거
- [ ] `auth_service.dart`의 `currentUser`에서 자동 생성 로직 제거
- [ ] `authStateChanges`에서 자동 생성 로직 제거
- [ ] 프로필 없으면 `null` 반환하도록 수정

#### 1.3 Signup 화면 기본 구조
- [ ] `SignupScreen` 위젯 생성
- [ ] 사용자 타입 선택 화면 (리뷰어/광고주)
- [ ] 라우팅 연결

---

### Phase 2: 리뷰어 회원가입 플로우 (5일)

#### 2.1 프로필 입력 화면
- [ ] 이름, 전화번호, 주소 입력 폼
- [ ] OAuth에서 가져온 기본값 설정
- [ ] 유효성 검증

#### 2.2 SNS 연결 화면
- [ ] SNS 플랫폼 선택 UI
- [ ] 플랫폼별 계정 정보 입력 폼
- [ ] 스토어 플랫폼 주소 필수 검증
- [ ] 여러 플랫폼 추가/삭제 기능

#### 2.3 회사 선택 화면
- [ ] 회사 검색 기능 (회사명/사업자번호)
- [ ] URL 파라미터/쿠키에서 companyid 읽기
- [ ] 회사 정보 미리 로드 및 표시
- [ ] "건너뛰기" 옵션

#### 2.4 회원가입 완료
- [ ] 모든 데이터 수집
- [ ] RPC 함수 호출 (트랜잭션)
- [ ] 성공 시 홈 화면으로 이동
- [ ] 에러 처리

---

### Phase 3: 광고주 회원가입 플로우 (5일)

#### 3.1 사업자 인증 화면
- [ ] 사업자등록증 이미지 업로드
- [ ] Workers API 연동 (기존 로직 활용)
- [ ] AI 추출 및 검증 결과 표시
- [ ] 사업자 정보 확인 및 수정

#### 3.2 입출금통장 입력 화면
- [ ] 은행명, 계좌번호, 예금주명 입력 폼
- [ ] 계좌번호 형식 검증
- [ ] 유효성 검증

#### 3.3 회원가입 완료
- [ ] 모든 데이터 수집
- [ ] RPC 함수 호출 (트랜잭션)
- [ ] 회사 생성 및 지갑 계좌 정보 저장
- [ ] 성공 시 홈 화면으로 이동
- [ ] 에러 처리

---

### Phase 4: RPC 함수 및 트랜잭션 처리 (3일)

#### 4.1 리뷰어 회원가입 RPC 함수
- [ ] `create_reviewer_profile_with_company` RPC 함수 생성
- [ ] 프로필 생성
- [ ] SNS 연결 배치 생성
- [ ] 회사 연결 (선택)
- [ ] 트랜잭션 보장

#### 4.2 광고주 회원가입 RPC 함수
- [ ] `create_advertiser_profile_with_company` RPC 함수 생성
- [ ] 프로필 생성
- [ ] 회사 생성
- [ ] company_users 생성 (owner)
- [ ] 지갑 계좌 정보 업데이트
- [ ] 트랜잭션 보장

#### 4.3 에러 처리 및 롤백
- [ ] 에러 발생 시 롤백 로직
- [ ] 에러 메시지 사용자 친화적으로 표시
- [ ] 재시도 로직

---

### Phase 5: 쿠키/딥링크 처리 (2일)

#### 5.1 웹 쿠키 처리
- [ ] 쿠키에서 companyid 읽기
- [ ] 회원가입 화면에 전달

#### 5.2 모바일 딥링크 처리
- [ ] 딥링크 파라미터에서 companyid 읽기
- [ ] 회원가입 화면에 전달

#### 5.3 회사 초대 링크 생성
- [ ] 회사 초대 링크 생성 기능
- [ ] companyid 포함된 URL 생성

---

### Phase 6: 데이터 유실 방지 (2일)

#### 6.1 로컬 스토리지 임시 저장
- [ ] SharedPreferences 또는 Hive 설정
- [ ] 회원가입 중 데이터 임시 저장
- [ ] 세션 복원 시 데이터 복원

#### 6.2 회원가입 중단 처리
- [ ] 브라우저/앱 종료 감지
- [ ] 데이터 복원 로직
- [ ] 세션 정리 옵션

---

### Phase 7: 테스트 및 검증 (3일)

#### 7.1 단위 테스트
- [ ] 각 화면별 테스트
- [ ] RPC 함수 테스트
- [ ] 에러 케이스 테스트

#### 7.2 통합 테스트
- [ ] 전체 플로우 테스트
- [ ] 웹/모바일 플랫폼별 테스트
- [ ] 에러 시나리오 테스트

#### 7.3 사용자 테스트
- [ ] 실제 사용자 시나리오 테스트
- [ ] 피드백 수집 및 개선

---

## 상세 구현 가이드

### 1. 라우팅 설정

**파일**: `lib/config/app_router.dart`

```dart
// Signup 경로 추가
GoRoute(
  path: '/signup',
  name: 'signup',
  builder: (context, state) {
    final type = state.uri.queryParameters['type']; // 'oauth'
    final provider = state.uri.queryParameters['provider']; // 'google', 'kakao'
    final companyId = state.uri.queryParameters['companyid'];
    return SignupScreen(
      type: type,
      provider: provider,
      companyId: companyId,
    );
  },
),

// 리다이렉트 로직 수정
redirect: (context, state) async {
  final user = await authService.currentUser;
  if (user == null) {
    // 프로필이 없는 임시 세션 확인
    final session = supabase.auth.currentSession;
    if (session != null && session.user != null) {
      try {
        await supabase.rpc('get_user_profile_safe', 
          params: {'p_user_id': session.user!.id});
      } catch (e) {
        // 프로필 없음 → signup으로 리다이렉트
        final provider = session.user!.appMetadata['provider'] ?? 'unknown';
        return '/signup?type=oauth&provider=$provider';
      }
    }
    return '/login';
  }
  // ... 기존 로직
}
```

---

### 2. Signup 화면 구조

**파일**: `lib/screens/auth/signup_screen.dart`

```dart
class SignupScreen extends ConsumerStatefulWidget {
  final String? type; // 'oauth'
  final String? provider; // 'google', 'kakao'
  final String? companyId; // URL 파라미터 또는 쿠키에서 가져온 값

  const SignupScreen({
    super.key,
    this.type,
    this.provider,
    this.companyId,
  });

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  UserType? _selectedUserType; // 'reviewer' or 'advertiser'
  
  @override
  void initState() {
    super.initState();
    // companyId가 있으면 회사 정보 미리 로드
    if (widget.companyId != null) {
      _loadCompanyInfo(widget.companyId!);
    }
  }

  void _onUserTypeSelected(UserType userType) {
    setState(() {
      _selectedUserType = userType;
    });
    
    // 선택한 타입에 따라 다음 화면으로 이동
    if (userType == UserType.reviewer) {
      context.push('/signup/reviewer', extra: {
        'companyId': widget.companyId,
      });
    } else if (userType == UserType.advertiser) {
      context.push('/signup/advertiser');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: _selectedUserType == null
          ? _buildUserTypeSelection()
          : _buildSignupForm(),
    );
  }

  Widget _buildUserTypeSelection() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => _onUserTypeSelected(UserType.reviewer),
          child: const Text('리뷰어로 시작하기'),
        ),
        ElevatedButton(
          onPressed: () => _onUserTypeSelected(UserType.advertiser),
          child: const Text('광고주로 시작하기'),
        ),
      ],
    );
  }
}
```

---

### 3. 리뷰어 회원가입 RPC 함수

**파일**: `supabase/migrations/YYYYMMDDHHMMSS_create_reviewer_signup_rpc.sql`

```sql
CREATE OR REPLACE FUNCTION create_reviewer_profile_with_company(
  p_user_id UUID,
  p_display_name TEXT,
  p_phone TEXT,
  p_address TEXT DEFAULT NULL,
  p_company_id UUID DEFAULT NULL,
  p_sns_connections JSONB DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_profile_id UUID;
  v_result JSONB;
BEGIN
  -- 트랜잭션 시작 (자동)
  
  -- 1. 프로필 생성
  INSERT INTO public.users (
    id,
    display_name,
    user_type,
    phone,
    address,
    created_at,
    updated_at
  ) VALUES (
    p_user_id,
    p_display_name,
    'reviewer',
    p_phone,
    p_address,
    NOW(),
    NOW()
  ) RETURNING id INTO v_profile_id;
  
  -- 2. 지갑 생성 (트리거로 자동)
  
  -- 3. SNS 연결 생성
  IF p_sns_connections IS NOT NULL AND jsonb_array_length(p_sns_connections) > 0 THEN
    FOR i IN 0..jsonb_array_length(p_sns_connections) - 1 LOOP
      DECLARE
        v_conn JSONB := p_sns_connections->i;
        v_platform TEXT := v_conn->>'platform';
        v_account_id TEXT := v_conn->>'platform_account_id';
        v_account_name TEXT := v_conn->>'platform_account_name';
        v_phone TEXT := v_conn->>'phone';
        v_address TEXT := v_conn->>'address';
        v_return_address TEXT := v_conn->>'return_address';
      BEGIN
        PERFORM create_sns_connection(
          p_user_id,
          v_platform,
          v_account_id,
          v_account_name,
          v_phone,
          v_address,
          v_return_address
        );
      EXCEPTION
        WHEN OTHERS THEN
          -- 개별 SNS 연결 실패는 로그만 남기고 계속 진행
          RAISE WARNING 'SNS 연결 생성 실패: %', SQLERRM;
      END;
    END LOOP;
  END IF;
  
  -- 4. 회사 연결 (선택)
  IF p_company_id IS NOT NULL THEN
    INSERT INTO public.company_users (
      company_id,
      user_id,
      company_role,
      status,
      created_at,
      updated_at
    ) VALUES (
      p_company_id,
      p_user_id,
      'member',
      'active',
      NOW(),
      NOW()
    );
  END IF;
  
  -- 트랜잭션 커밋 (자동)
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_profile_id,
    'company_id', p_company_id
  );
EXCEPTION
  WHEN OTHERS THEN
    -- 트랜잭션 롤백 (자동)
    RAISE EXCEPTION '리뷰어 회원가입 실패: %', SQLERRM;
END;
$$;
```

---

### 4. 광고주 회원가입 RPC 함수

**파일**: `supabase/migrations/YYYYMMDDHHMMSS_create_advertiser_signup_rpc.sql`

```sql
CREATE OR REPLACE FUNCTION create_advertiser_profile_with_company(
  p_user_id UUID,
  p_display_name TEXT,
  p_phone TEXT,
  -- 사업자 정보
  p_business_name TEXT,
  p_business_number TEXT,
  p_address TEXT,
  p_representative_name TEXT,
  p_business_type TEXT,
  p_registration_file_url TEXT,
  -- 계좌 정보
  p_bank_name TEXT,
  p_account_number TEXT,
  p_account_holder TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_profile_id UUID;
  v_company_id UUID;
  v_wallet_id UUID;
  v_result JSONB;
BEGIN
  -- 트랜잭션 시작 (자동)
  
  -- 1. 프로필 생성
  INSERT INTO public.users (
    id,
    display_name,
    user_type,
    phone,
    created_at,
    updated_at
  ) VALUES (
    p_user_id,
    p_display_name,
    'advertiser',
    p_phone,
    NOW(),
    NOW()
  ) RETURNING id INTO v_profile_id;
  
  -- 2. 회사 생성
  SELECT register_company(
    p_user_id,
    p_business_name,
    p_business_number,
    p_address,
    p_representative_name,
    p_business_type,
    p_registration_file_url
  ) INTO v_result;
  
  v_company_id := (v_result->>'company_id')::UUID;
  
  -- 3. company_users 생성 (owner)
  INSERT INTO public.company_users (
    company_id,
    user_id,
    company_role,
    status,
    created_at,
    updated_at
  ) VALUES (
    v_company_id,
    p_user_id,
    'owner',
    'active',
    NOW(),
    NOW()
  );
  
  -- 4. 지갑 계좌 정보 업데이트
  SELECT id INTO v_wallet_id
  FROM public.wallets
  WHERE company_id = v_company_id AND user_id IS NULL;
  
  IF v_wallet_id IS NOT NULL THEN
    UPDATE public.wallets SET
      withdraw_bank_name = p_bank_name,
      withdraw_account_number = p_account_number,
      withdraw_account_holder = p_account_holder,
      updated_at = NOW()
    WHERE id = v_wallet_id;
  END IF;
  
  -- 트랜잭션 커밋 (자동)
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_profile_id,
    'company_id', v_company_id
  );
EXCEPTION
  WHEN OTHERS THEN
    -- 트랜잭션 롤백 (자동)
    RAISE EXCEPTION '광고주 회원가입 실패: %', SQLERRM;
END;
$$;
```

---

### 5. AuthService 수정

**파일**: `lib/services/auth_service.dart`

```dart
// 자동 생성 로직 제거
Future<app_user.User?> get currentUser async {
  final session = _supabase.auth.currentSession;
  final user = session?.user;
  if (user != null) {
    try {
      // 세션 만료 확인 및 토큰 갱신
      // ... (기존 로직)
      
      // 프로필 조회
      final profileResponse = await _supabase.rpc(
        'get_user_profile_safe',
        params: {'p_user_id': user.id},
      );
      
      // 프로필이 있으면 반환
      final userProfile = app_user.User.fromDatabaseProfile(
        profileResponse,
        user,
      );
      final stats = await _userService.getUserStats(userProfile.uid);
      
      return userProfile.copyWith(
        level: stats['level'],
        reviewCount: stats['reviewCount'],
      );
    } catch (e) {
      // 프로필이 없는 경우 null 반환 (자동 생성 제거)
      final isProfileNotFound =
          e.toString().contains('User profile not found') ||
          (e is PostgrestException &&
              (e.code == 'PGRST116' ||
                  e.message.contains('No rows returned')));
      
      if (isProfileNotFound) {
        // 프로필 없음 → null 반환 (라우터에서 signup으로 리다이렉트)
        debugPrint('프로필이 없습니다. 회원가입이 필요합니다: ${user.id}');
        return null;
      }
      
      // 다른 에러
      debugPrint('사용자 프로필 조회 실패: $e');
      return null;
    }
  }
  return null;
}

// authStateChanges도 동일하게 수정
Stream<app_user.User?> get authStateChanges {
  return _supabase.auth.onAuthStateChange.asyncMap((authState) async {
    final user = authState.session?.user;
    if (user != null) {
      try {
        // 프로필 조회
        // ... (currentUser와 동일한 로직)
      } catch (e) {
        // 프로필 없음 → null 반환
        return null;
      }
    }
    return null;
  });
}
```

---

## 요약

### 주요 변경사항

1. **프로필 자동 생성 제거**: OAuth 로그인 시 프로필 자동 생성하지 않음
2. **명시적 회원가입 플로우**: 프로필 없으면 `/signup`으로 리다이렉트
3. **사용자 타입 선택**: 리뷰어/광고주 선택 후 각각의 플로우 진행
4. **트랜잭션 보장**: RPC 함수로 auth + DB 트랜잭션 처리
5. **회사 초대 링크**: URL 파라미터/쿠키로 companyid 전달

### 예상 소요 시간

- **Phase 1**: 3일
- **Phase 2**: 5일
- **Phase 3**: 5일
- **Phase 4**: 3일
- **Phase 5**: 2일
- **Phase 6**: 2일
- **Phase 7**: 3일

**총 예상 소요 시간**: 약 23일 (약 4-5주)

### 우선순위

1. **높음**: Phase 1, 2, 3, 4 (핵심 기능)
2. **중간**: Phase 5, 6 (편의 기능)
3. **낮음**: Phase 7 (테스트 및 검증)

---

## 참고 자료

- [Supabase Auth 문서](https://supabase.com/docs/guides/auth)
- [PostgreSQL 트랜잭션 문서](https://www.postgresql.org/docs/current/tutorial-transactions.html)
- [Flutter Deep Links 문서](https://docs.flutter.dev/development/ui/navigation/deep-linking)

