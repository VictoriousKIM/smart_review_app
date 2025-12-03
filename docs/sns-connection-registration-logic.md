# SNS 연결 등록 로직 문서

**작성일**: 2025년 01월 28일  
**작업 기간**: 2025년 01월 28일  
**상태**: 완료

---

## 📋 목차

1. [개요](#개요)
2. [데이터베이스 스키마](#데이터베이스-스키마)
3. [회원가입 시 SNS 연결 등록](#회원가입-시-sns-연결-등록)
4. [마이페이지에서 SNS 연결 등록](#마이페이지에서-sns-연결-등록)
5. [RPC 함수 상세](#rpc-함수-상세)
6. [플랫폼 타입 구분](#플랫폼-타입-구분)
7. [에러 처리](#에러-처리)
8. [캐싱 메커니즘](#캐싱-메커니즘)

---

## 개요

SNS 연결 등록 로직은 사용자가 리뷰 활동에 사용할 SNS 계정을 등록하고 관리하는 기능입니다. 회원가입 시와 마이페이지에서 각각 다른 방식으로 처리됩니다.

### 주요 특징

- **복수 계정 지원**: 같은 플랫폼에 여러 계정 등록 가능
- **플랫폼 타입 구분**: 스토어 플랫폼과 SNS 플랫폼으로 구분
- **주소 필수 검증**: 스토어 플랫폼은 배송주소 필수
- **트랜잭션 보장**: RPC 함수를 통한 안전한 데이터 저장
- **캐싱 지원**: 조회 성능 최적화를 위한 로컬 캐싱

---

## 데이터베이스 스키마

### `sns_connections` 테이블

```sql
CREATE TABLE public.sns_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id),
    platform TEXT NOT NULL,
    platform_account_id TEXT NOT NULL,
    platform_account_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    address TEXT,  -- 스토어 플랫폼만 필수
    return_address TEXT,  -- 선택 사항
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 주요 제약 조건

- **계정 ID 중복 방지**: `(user_id, platform, platform_account_id)` 조합은 유일해야 함 (UNIQUE 제약 조건)
- **배송주소 중복 방지**: 같은 사용자의 같은 플랫폼 내에서 동일한 배송주소는 중복 불가 (RPC 함수 레벨 검증)
- **외래 키**: `user_id`는 `public.users` 테이블 참조
- **RLS 정책**: 사용자는 자신의 SNS 연결만 조회/수정/삭제 가능

---

## 회원가입 시 SNS 연결 등록

### 플로우 다이어그램

```
[ReviewerSignupSNSForm]
    ↓
[SignupPlatformConnectionDialog] (DB 저장 없음, 데이터만 수집)
    ↓
[ReviewerSignupScreen._completeSignup]
    ↓
[create_reviewer_profile_with_company RPC]
    ↓
[create_sns_connection RPC] (각 연결마다 호출)
    ↓
[sns_connections 테이블에 저장]
```

### 1. SNS 연결 폼 (`ReviewerSignupSNSForm`)

**파일**: `lib/screens/auth/reviewer_signup_sns_form.dart`

**기능**:
- 플랫폼별로 복수 계정 추가 가능
- 각 연결 항목에 변경/삭제 버튼 제공
- 추가 버튼은 항상 표시 (같은 플랫폼 여러 개 추가 가능)

**주요 메서드**:

```dart
// 플랫폼 연결 추가
Future<void> _addPlatformConnection(String platform)

// 플랫폼 연결 수정
Future<void> _editPlatformConnection(String platform, int index)

// 플랫폼 연결 삭제
void _deletePlatformConnection(String platform, int index)
```

**데이터 구조**:
```dart
List<Map<String, dynamic>> _snsConnections = [
  {
    'platform': 'coupang',
    'platform_account_id': 'account123',
    'platform_account_name': '내 쿠팡 계정',
    'phone': '010-1234-5678',
    'address': '서울시 강남구 테헤란로 123',
    'return_address': '서울시 강남구 테헤란로 123',
  },
  // ... 더 많은 연결
];
```

### 2. 플랫폼 연결 다이얼로그 (`SignupPlatformConnectionDialog`)

**파일**: `lib/widgets/signup_platform_connection_dialog.dart`

**기능**:
- DB에 저장하지 않고 데이터만 반환
- 스토어 플랫폼: 배송주소 필수, 반품주소 선택
- SNS 플랫폼: 주소 불필요
- 프로필 정보 자동 입력 기능
- 수정 모드 지원 (`initialData` 파라미터)

**입력 필드**:
- 계정 ID (필수)
- 계정 이름 (필수)
- 전화번호 (필수)
- 배송주소 (스토어 플랫폼만 필수)
  - 기본주소 (주소 찾기 버튼)
  - 상세주소
- 반품주소 (선택)
  - 배송주소와 같음 체크박스
  - 기본주소 (주소 찾기 버튼)
  - 상세주소

**반환 데이터**:
```dart
{
  'platform': 'coupang',
  'platform_account_id': 'account123',
  'platform_account_name': '내 쿠팡 계정',
  'phone': '010-1234-5678',
  'address': '서울시 강남구 테헤란로 123 상세주소',  // 기본주소 + 상세주소
  'return_address': '서울시 강남구 테헤란로 123 상세주소',  // 선택
}
```

### 3. 회원가입 완료 처리 (`ReviewerSignupScreen`)

**파일**: `lib/screens/auth/reviewer_signup_screen.dart`

**코드**:
```dart
await SupabaseConfig.client.rpc(
  'create_reviewer_profile_with_company',
  params: {
    'p_user_id': userId,
    'p_display_name': _displayName!,
    'p_phone': _phone ?? '',
    'p_address': fullAddress,
    'p_company_id': _selectedCompanyId,
    'p_sns_connections': _snsConnections.isNotEmpty
        ? _snsConnections  // JSONB 배열로 전달
        : null,
  },
);
```

**특징**:
- SNS 연결이 없어도 회원가입 가능 (선택 사항)
- 여러 SNS 연결을 한 번에 전달
- 개별 연결 실패 시에도 회원가입은 성공 (WARNING만 기록)

---

## 마이페이지에서 SNS 연결 등록

### 플로우 다이어그램

```
[SNSConnectionScreen]
    ↓
[PlatformConnectionDialog] (실제 DB 저장)
    ↓
[SNSPlatformConnectionService.createConnection]
    ↓
[create_sns_connection RPC]
    ↓
[sns_connections 테이블에 저장]
    ↓
[캐시 무효화]
```

### 1. SNS 연결 서비스 (`SNSPlatformConnectionService`)

**파일**: `lib/services/sns_platform_connection_service.dart`

**주요 메서드**:

#### `createConnection` - 연결 생성

```dart
static Future<Map<String, dynamic>> createConnection({
  required String platform,
  required String platformAccountId,
  required String platformAccountName,
  required String phone,
  String? address,
  String? returnAddress,
}) async
```

**처리 과정**:
1. 사용자 인증 확인
2. 스토어 플랫폼 주소 필수 검증 (애플리케이션 레벨)
3. `create_sns_connection` RPC 함수 호출
4. 캐시 무효화
5. 결과 반환

#### `updateConnection` - 연결 수정

```dart
static Future<Map<String, dynamic>> updateConnection({
  required String id,
  String? platformAccountName,
  String? phone,
  String? address,
  String? returnAddress,
}) async
```

#### `deleteConnection` - 연결 삭제

```dart
static Future<void> deleteConnection(String id) async
```

#### `getConnections` - 연결 조회 (캐싱 적용)

```dart
static Future<List<Map<String, dynamic>>> getConnections({
  bool forceRefresh = false,
}) async
```

**캐싱 로직**:
- 24시간 캐시 유지
- `forceRefresh=true` 시 서버에서 강제 조회
- 에러 발생 시 캐시 데이터 사용 (fallback)

---

## RPC 함수 상세

### 1. `create_sns_connection`

**파일**: `supabase/migrations/20251203120001_add_updated_at_to_company_users.sql`

**시그니처**:
```sql
CREATE OR REPLACE FUNCTION create_sns_connection(
  p_user_id UUID,
  p_platform TEXT,
  p_platform_account_id TEXT,
  p_platform_account_name TEXT,
  p_phone TEXT,
  p_address TEXT DEFAULT NULL,
  p_return_address TEXT DEFAULT NULL
) RETURNS JSONB
```

**처리 과정**:

1. **사용자 존재 확인**
   ```sql
   IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id) THEN
       RAISE EXCEPTION '사용자를 찾을 수 없습니다';
   END IF;
   ```

2. **스토어 플랫폼 주소 필수 검증**
   ```sql
   IF p_platform = ANY(v_store_platforms) AND (p_address IS NULL OR p_address = '') THEN
       RAISE EXCEPTION '스토어 플랫폼(%)은 주소 입력이 필수입니다', p_platform;
   END IF;
   ```

3. **계정 ID 중복 확인**
   ```sql
   IF EXISTS (
       SELECT 1 FROM public.sns_connections
       WHERE user_id = p_user_id
         AND platform = p_platform
         AND platform_account_id = p_platform_account_id
   ) THEN
       RAISE EXCEPTION '이미 등록된 계정입니다';
   END IF;
   ```

4. **배송주소 중복 확인** (스토어 플랫폼만)
   ```sql
   IF p_platform = ANY(v_store_platforms) AND p_address IS NOT NULL AND p_address != '' THEN
       IF EXISTS (
           SELECT 1 FROM public.sns_connections
           WHERE user_id = p_user_id
             AND platform = p_platform
             AND address = p_address
       ) THEN
           RAISE EXCEPTION '같은 플랫폼에 동일한 배송주소가 이미 등록되어 있습니다';
       END IF;
   END IF;
   ```

5. **SNS 연결 생성**
   ```sql
   INSERT INTO public.sns_connections (
       user_id, platform, platform_account_id,
       platform_account_name, phone, address, return_address
   ) VALUES (...)
   ```

6. **결과 반환**
   ```sql
   RETURN jsonb_build_object(
       'success', true,
       'data', v_result
   );
   ```

**스토어 플랫폼 목록**:
```sql
v_store_platforms := ARRAY['coupang', 'smartstore', 'kakao', '11st', 'gmarket', 'auction', 'wemakeprice'];
```

**참고**: `kakao`는 최근 추가된 스토어 플랫폼입니다. `create_sns_connection`과 `update_sns_connection` 함수 모두에 포함되어 있습니다.

**참고**: `kakao`는 최근 추가된 스토어 플랫폼입니다.

### 2. `update_sns_connection` - 연결 수정

**시그니처**:
```sql
CREATE OR REPLACE FUNCTION update_sns_connection(
  p_id UUID,
  p_user_id UUID,
  p_platform_account_name TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL,
  p_address TEXT DEFAULT NULL,
  p_return_address TEXT DEFAULT NULL
) RETURNS JSONB
```

**처리 과정**:

1. **연결 존재 확인**
   ```sql
   SELECT platform INTO v_platform
   FROM public.sns_connections
   WHERE id = p_id AND user_id = p_user_id;
   ```

2. **스토어 플랫폼 주소 필수 검증**
   ```sql
   IF v_platform = ANY(v_store_platforms) AND 
      (p_address IS NULL OR p_address = '') AND
      NOT EXISTS (
          SELECT 1 FROM public.sns_connections
          WHERE id = p_id AND address IS NOT NULL AND address != ''
      ) THEN
       RAISE EXCEPTION '스토어 플랫폼은 주소가 필수입니다';
   END IF;
   ```

3. **연결 정보 업데이트**
   ```sql
   UPDATE public.sns_connections
   SET
       platform_account_name = COALESCE(p_platform_account_name, platform_account_name),
       phone = COALESCE(p_phone, phone),
       address = COALESCE(p_address, address),
       return_address = COALESCE(p_return_address, return_address),
       updated_at = NOW()
   WHERE id = p_id AND user_id = p_user_id;
   ```

**특징**:
- NULL 값은 기존 값 유지 (`COALESCE` 사용)
- 스토어 플랫폼의 경우 기존 주소가 있으면 NULL 허용

### 3. `delete_sns_connection` - 연결 삭제

**시그니처**:
```sql
CREATE OR REPLACE FUNCTION delete_sns_connection(
  p_id UUID,
  p_user_id UUID
) RETURNS JSONB
```

**처리 과정**:

1. **연결 삭제**
   ```sql
   DELETE FROM public.sns_connections
   WHERE id = p_id AND user_id = p_user_id
   RETURNING id INTO v_deleted_id;
   ```

2. **삭제 확인**
   ```sql
   IF v_deleted_id IS NULL THEN
       RAISE EXCEPTION 'SNS 연결을 찾을 수 없습니다';
   END IF;
   ```

3. **결과 반환**
   ```sql
   RETURN jsonb_build_object(
       'success', true,
       'id', v_deleted_id
   );
   ```

### 2. `create_reviewer_profile_with_company` (회원가입용)

**파일**: `supabase/migrations/20251202160416_create_signup_rpc_functions.sql`

**SNS 연결 처리 부분**:
```sql
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
        p_user_id, v_platform, v_account_id,
        v_account_name, v_phone, v_address, v_return_address
      );
    EXCEPTION
      WHEN OTHERS THEN
        -- 개별 SNS 연결 실패는 로그만 남기고 계속 진행
        RAISE WARNING 'SNS 연결 생성 실패: %', SQLERRM;
    END;
  END LOOP;
END IF;
```

**특징**:
- 개별 연결 실패 시에도 회원가입은 성공
- WARNING만 기록하고 다음 연결 처리 계속
- 트랜잭션 내에서 처리 (전체 실패 시 롤백)

---

## 플랫폼 타입 구분

### 스토어 플랫폼

**목록**:
- `coupang` (쿠팡)
- `smartstore` (스마트스토어)
- `kakao` (카카오)
- `11st` (11번가)
- `gmarket` (지마켓)
- `auction` (옥션)
- `wemakeprice` (위메프)

**특징**:
- 배송주소 필수
- 반품주소 선택 가능
- 주소 검증은 RPC 함수와 애플리케이션 레벨 모두에서 수행

### SNS 플랫폼

**목록**:
- `blog` (네이버 블로그)
- `instagram` (인스타그램)
- `youtube` (유튜브)
- `tiktok` (틱톡)
- `naver` (네이버)

**특징**:
- 주소 불필요
- `address` 필드는 NULL로 저장

### 플랫폼 타입 확인

**코드**: `lib/services/sns_platform_connection_service.dart`

```dart
static bool isStorePlatform(String platform) {
  return storePlatforms.contains(platform.toLowerCase());
}
```

---

## 에러 처리

### 주요 에러 케이스

1. **사용자 없음**
   - 에러: `사용자를 찾을 수 없습니다`
   - 발생 위치: RPC 함수

2. **스토어 플랫폼 주소 누락**
   - 에러: `스토어 플랫폼(%)은 주소 입력이 필수입니다`
   - 발생 위치: RPC 함수, 애플리케이션 레벨

3. **계정 ID 중복**
   - 에러: `이미 등록된 계정입니다`
   - 발생 위치: RPC 함수
   - 조건: `(user_id, platform, platform_account_id)` 조합 중복

4. **배송주소 중복** (스토어 플랫폼만)
   - 에러: `같은 플랫폼에 동일한 배송주소가 이미 등록되어 있습니다`
   - 발생 위치: RPC 함수
   - 조건: 같은 사용자의 같은 플랫폼 내에서 동일한 배송주소

5. **로그인 필요**
   - 에러: `로그인이 필요합니다`
   - 발생 위치: 애플리케이션 레벨

### 에러 메시지 변환

**코드**: `SNSPlatformConnectionService.getErrorMessage()`

```dart
static String getErrorMessage(dynamic error) {
  // PostgrestException 처리
  // Exception 처리
  // 기본 에러 메시지
}
```

---

## 캐싱 메커니즘

### 캐시 구조

**저장 위치**: `SharedPreferences`

**키 구조**:
- 데이터: `sns_connections_{userId}`
- 타임스탬프: `sns_connections_timestamp_{userId}`

**캐시 만료 시간**: 24시간

### 캐시 무효화 시점

1. 연결 생성 시
2. 연결 수정 시
3. 연결 삭제 시
4. 캐시 만료 시

### 캐시 조회 로직

```dart
// 1. 캐시 존재 확인
// 2. 캐시 만료 확인
// 3. 만료되지 않았으면 캐시 반환
// 4. 만료되었거나 없으면 서버 조회
// 5. 서버 조회 결과 캐시에 저장
```

### Fallback 메커니즘

서버 조회 실패 시 캐시 데이터를 사용하여 사용자 경험 유지

---

## 데이터 흐름 요약

### 회원가입 시

```
[UI 입력] 
  → [SignupPlatformConnectionDialog] (데이터 수집)
  → [ReviewerSignupSNSForm] (리스트 관리)
  → [ReviewerSignupScreen] (회원가입 완료)
  → [create_reviewer_profile_with_company RPC]
  → [create_sns_connection RPC] (각 연결마다)
  → [sns_connections 테이블]
```

### 마이페이지에서

```
[UI 입력]
  → [PlatformConnectionDialog]
  → [SNSPlatformConnectionService.createConnection]
  → [create_sns_connection RPC]
  → [sns_connections 테이블]
  → [캐시 무효화]
  → [UI 새로고침]
```

---

## 주요 파일 목록

### 프론트엔드

- `lib/screens/auth/reviewer_signup_sns_form.dart` - 회원가입 SNS 연결 폼
- `lib/widgets/signup_platform_connection_dialog.dart` - 회원가입용 연결 다이얼로그
- `lib/services/sns_platform_connection_service.dart` - SNS 연결 서비스
- `lib/screens/mypage/reviewer/sns_connection_screen.dart` - 마이페이지 SNS 연결 화면

### 백엔드 (마이그레이션)

- `supabase/migrations/20251202160416_create_signup_rpc_functions.sql` - 회원가입 RPC 함수
- `supabase/migrations/20251203120001_add_updated_at_to_company_users.sql` - SNS 연결 RPC 함수

---

## 참고 사항

1. **복수 계정 지원**: 같은 플랫폼에 여러 계정 등록 가능 (계정 ID가 다르면 가능)
2. **트랜잭션 보장**: RPC 함수를 통한 안전한 데이터 저장
3. **에러 복구**: 회원가입 시 개별 연결 실패해도 전체 실패하지 않음
4. **성능 최적화**: 캐싱을 통한 조회 성능 향상
5. **사용자 경험**: 에러 발생 시 캐시 데이터로 fallback

---

**문서 버전**: 1.0  
**최종 수정일**: 2025년 01월 28일

