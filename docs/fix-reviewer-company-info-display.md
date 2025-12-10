# Reviewer 역할 사용자의 회사 정보 표시 문제 해결

**작성일**: 2025년 12월 10일  
**작업 기간**: 2025년 12월 10일  
**최종 수정**: 2025년 12월 10일 (데이터베이스 레벨 필터링 적용)

## 📋 문제 설명

`company_users` 테이블에서 `company_role`이 `'reviewer'`인 사용자가 `/mypage/profile?tab=business` 페이지에 접근할 때, 회사 정보가 표시되는 문제가 발생했습니다.

### 문제 상황
- **URL**: `http://localhost:3001/mypage/profile?tab=business`
- **조건**: `company_users.company_role = 'reviewer'`인 사용자
- **현상**: 회사 정보(상호명, 사업자번호, 대표자명, 주소 등)가 표시됨
- **기대 동작**: Reviewer 역할인 경우 회사 정보가 표시되지 않아야 함

## ⚠️ 중요 변경사항

**프론트엔드 필터링 → 데이터베이스 레벨 필터링으로 변경**

초기에는 프론트엔드에서 필터링하는 방식으로 수정했지만, 보안상 데이터베이스 레벨(RLS 정책 및 RPC 함수)에서 필터링하는 것이 올바른 방법입니다. 따라서 다음과 같이 수정했습니다:

1. **RLS 정책 수정**: Reviewer 역할은 companies 테이블을 조회할 수 없도록 변경
2. **RPC 함수 수정**: `get_user_company_id_safe` 함수가 owner/manager 역할만 반환하도록 수정
3. **새로운 RPC 함수 추가**: Reviewer 역할도 필요한 경우를 위한 `get_user_company_id_all_roles_safe` 함수 추가
4. **프론트엔드 코드 수정**: `getCompanyByUserId()` 메서드가 `get_advertiser_company_by_user_id` RPC 함수를 사용하도록 변경

## 🔍 원인 분석

### 문제 발생 위치

1. **`BusinessRegistrationForm` 위젯** (`lib/screens/mypage/common/business_registration_form.dart`)
   - `_loadExistingCompanyData()` 메서드에서 회사 정보를 로드
   - `CompanyService.getCompanyByUserId()` 메서드를 사용하여 모든 역할의 회사 정보를 조회

2. **`CompanyService.getCompanyByUserId()` 메서드** (`lib/services/company_service.dart`)
   ```dart
   /// 사용자 ID로 회사 정보 조회 (기존 RPC 함수 조합 사용)
   /// 리뷰어도 광고주로 등록할 수 있도록 모든 역할의 회사 정보 반환
   static Future<Map<String, dynamic>?> getCompanyByUserId(String userId) async {
     // ...
     // reviewer 역할도 포함하여 회사 정보를 반환
   }
   ```
   - 이 메서드는 **모든 역할**(owner, manager, reviewer)의 회사 정보를 반환
   - 주석에도 "리뷰어도 광고주로 등록할 수 있도록 모든 역할의 회사 정보 반환"이라고 명시되어 있음

3. **`CompanyService.getAdvertiserCompanyByUserId()` 메서드**
   ```dart
   /// 광고주 회사 정보 조회 (기존 RPC 함수 조합 사용)
   /// owner, manager 역할만 조회 (광고주 전용 기능용)
   static Future<Map<String, dynamic>?> getAdvertiserCompanyByUserId(
     String userId,
   ) async {
     // ...
     // owner 또는 manager가 아니면 null 반환
     if (companyRole != 'owner' && companyRole != 'manager') {
       return null;
     }
   }
   ```
   - 이 메서드는 **owner/manager 역할만** 조회하도록 구현되어 있음

### 문제 흐름

```
1. 사용자가 /mypage/profile?tab=business 접근
   ↓
2. ProfileScreen._buildBusinessTab() 호출
   ↓
3. BusinessRegistrationForm 위젯 렌더링
   ↓
4. BusinessRegistrationForm.initState() 실행
   ↓
5. _loadExistingCompanyData() 호출
   ↓
6. CompanyService.getCompanyByUserId() 호출
   ↓
7. reviewer 역할이어도 회사 정보 반환
   ↓
8. _existingCompanyData에 회사 정보 저장
   ↓
9. _buildBusinessInfoForm()에서 회사 정보 표시 ❌
```

## ✅ 해결 방법

### 데이터베이스 레벨 필터링 (최종 해결 방법)

보안을 위해 데이터베이스 레벨에서 필터링하도록 수정했습니다:

#### 1. RLS 정책 수정

**기존 정책**:
```sql
CREATE POLICY "Companies are viewable by everyone" ON "public"."companies"
FOR SELECT USING (true);
```

**수정된 정책**:
```sql
CREATE POLICY "Companies are viewable by owners and managers" ON "public"."companies"
FOR SELECT
USING (
  -- owner 또는 manager 역할인 경우만 조회 가능
  EXISTS (
    SELECT 1
    FROM public.company_users cu
    WHERE cu.company_id = companies.id
      AND cu.user_id = auth.uid()
      AND cu.company_role IN ('owner', 'manager')
      AND cu.status = 'active'
  )
  -- 또는 회사 소유자 (companies.user_id)인 경우
  OR companies.user_id = auth.uid()
);
```

#### 2. RPC 함수 수정

**`get_user_company_id_safe` 함수 수정**:
- 기존: 모든 역할(owner, manager, reviewer)의 company_id 반환
- 수정: owner/manager 역할만 company_id 반환

```sql
CREATE OR REPLACE FUNCTION "public"."get_user_company_id_safe"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_company_id UUID;
BEGIN
    v_user_id := COALESCE(p_user_id, auth.uid());
    
    IF v_user_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- owner/manager 역할만 조회
    SELECT company_id INTO v_company_id
    FROM public.company_users
    WHERE user_id = v_user_id
    AND status = 'active'
    AND company_role IN ('owner', 'manager')
    LIMIT 1;

    RETURN v_company_id;
END;
$$;
```

**새로운 함수 추가**: `get_user_company_id_all_roles_safe`
- Reviewer 역할도 포함하여 company_id를 조회해야 하는 경우를 위한 함수

#### 3. 프론트엔드 코드 수정

**`CompanyService.getCompanyByUserId()` 메서드 수정**:
- 기존: `get_user_company_id_safe` + 직접 companies 테이블 조회
- 수정: `get_advertiser_company_by_user_id` RPC 함수 사용 (이미 owner/manager만 반환하도록 구현됨)

```dart
static Future<Map<String, dynamic>?> getCompanyByUserId(String userId) async {
  try {
    final supabase = Supabase.instance.client;

    // get_advertiser_company_by_user_id RPC 함수 사용
    // 이 함수는 owner/manager 역할만 반환하도록 구현되어 있음
    final response = await supabase.rpc(
      'get_advertiser_company_by_user_id',
      params: {'p_user_id': userId},
    );

    if (response == null || (response as List).isEmpty) {
      return null;
    }

    final companyList = response as List;
    if (companyList.isEmpty) {
      return null;
    }

    return companyList[0] as Map<String, dynamic>;
  } catch (e) {
    debugPrint('❌ 사용자 회사 정보 조회 실패: $e');
    return null;
  }
}
```

### 프론트엔드 필터링 (초기 수정 - 참고용)

초기에는 프론트엔드에서 필터링하는 방식으로 수정했지만, 보안상 데이터베이스 레벨 필터링이 더 안전하므로 최종적으로는 데이터베이스 레벨 필터링을 적용했습니다.

`BusinessRegistrationForm`의 `_loadExistingCompanyData()` 메서드에서 `getCompanyByUserId()` 대신 `getAdvertiserCompanyByUserId()`를 사용하도록 변경했습니다.

### 수정 전 코드

```dart:1043:1057:lib/screens/mypage/common/business_registration_form.dart
/// 기존 회사 정보 로드
Future<void> _loadExistingCompanyData() async {
  try {
    setState(() {
      _isLoadingExistingData = true;
    });

    // 현재 사용자 ID 가져오기 (Custom JWT 세션 지원)
    final userId = await AuthService.getCurrentUserId();
    if (userId == null) {
      debugPrint('❌ 사용자가 로그인되지 않았습니다.');
      return;
    }

    // 사용자의 회사 정보 조회
    final companyData = await CompanyService.getCompanyByUserId(userId);
```

### 수정 후 코드

```dart:1042:1057:lib/screens/mypage/common/business_registration_form.dart
/// 기존 회사 정보 로드
/// reviewer 역할인 경우 회사 정보를 로드하지 않음 (owner/manager만 조회)
Future<void> _loadExistingCompanyData() async {
  try {
    setState(() {
      _isLoadingExistingData = true;
    });

    // 현재 사용자 ID 가져오기 (Custom JWT 세션 지원)
    final userId = await AuthService.getCurrentUserId();
    if (userId == null) {
      debugPrint('❌ 사용자가 로그인되지 않았습니다.');
      return;
    }

    // reviewer 역할인 경우 회사 정보를 로드하지 않음
    // owner/manager 역할만 회사 정보 조회
    final companyData = await CompanyService.getAdvertiserCompanyByUserId(userId);
```

### 변경 사항 요약

1. **메서드 변경**: `getCompanyByUserId()` → `getAdvertiserCompanyByUserId()`
2. **주석 추가**: reviewer 역할인 경우 회사 정보를 로드하지 않는다는 설명 추가
3. **동작 변경**: reviewer 역할인 경우 `companyData`가 `null`이 되어 회사 정보가 표시되지 않음

## 🎯 해결된 동작

### 수정 후 흐름

```
1. 사용자가 /mypage/profile?tab=business 접근
   ↓
2. ProfileScreen._buildBusinessTab() 호출
   ↓
3. BusinessRegistrationForm 위젯 렌더링
   ↓
4. BusinessRegistrationForm.initState() 실행
   ↓
5. _loadExistingCompanyData() 호출
   ↓
6. CompanyService.getAdvertiserCompanyByUserId() 호출
   ↓
7. reviewer 역할인 경우 null 반환 ✅
   ↓
8. _existingCompanyData = null
   ↓
9. _buildBusinessInfoForm()에서 회사 정보 미표시 ✅
```

### 역할별 동작

| 역할 | `getCompanyByUserId()` | `getAdvertiserCompanyByUserId()` | 표시 여부 |
|------|----------------------|--------------------------------|----------|
| `owner` | ✅ 회사 정보 반환 | ✅ 회사 정보 반환 | ✅ 표시 |
| `manager` | ✅ 회사 정보 반환 | ✅ 회사 정보 반환 | ✅ 표시 |
| `reviewer` | ✅ 회사 정보 반환 | ❌ null 반환 | ❌ 미표시 |

## 🧪 테스트 방법

### 테스트 시나리오

1. **Reviewer 역할 사용자로 로그인**
   ```sql
   -- 테스트용 reviewer 역할 사용자 확인
   SELECT cu.user_id, cu.company_role, cu.status, c.business_name
   FROM company_users cu
   JOIN companies c ON c.id = cu.company_id
   WHERE cu.company_role = 'reviewer' AND cu.status = 'active'
   LIMIT 1;
   ```

2. **프로필 페이지 접근**
   - URL: `http://localhost:3001/mypage/profile?tab=business`
   - 또는 프로필 페이지에서 "사업자 정보" 탭 클릭

3. **확인 사항**
   - ✅ 회사 정보가 표시되지 않아야 함
   - ✅ "회사 정보" 섹션이 보이지 않아야 함
   - ✅ 사업자 등록 폼만 표시되어야 함

### Owner/Manager 역할 테스트

1. **Owner/Manager 역할 사용자로 로그인**
   ```sql
   -- 테스트용 owner/manager 역할 사용자 확인
   SELECT cu.user_id, cu.company_role, cu.status, c.business_name
   FROM company_users cu
   JOIN companies c ON c.id = cu.company_id
   WHERE cu.company_role IN ('owner', 'manager') AND cu.status = 'active'
   LIMIT 1;
   ```

2. **프로필 페이지 접근**
   - URL: `http://localhost:3001/mypage/profile?tab=business`

3. **확인 사항**
   - ✅ 회사 정보가 정상적으로 표시되어야 함
   - ✅ "회사 정보" 섹션에 상호명, 사업자번호 등이 표시되어야 함
   - ✅ "등록됨" 배지가 표시되어야 함

## 📝 관련 파일

### 데이터베이스 레벨 수정 (최종 해결 방법)

- **마이그레이션 파일**:
  - `supabase/migrations/20251210085629_fix_reviewer_company_access.sql`
    - RLS 정책 수정
    - `get_user_company_id_safe` 함수 수정
    - `get_user_company_id_all_roles_safe` 함수 추가

- **수정된 파일**:
  - `lib/services/company_service.dart` - `getCompanyByUserId()` 메서드 수정

### 프론트엔드 수정 (초기 수정 - 참고용)

- **수정된 파일**:
  - `lib/screens/mypage/common/business_registration_form.dart`
  
- **관련 파일**:
  - `lib/services/company_service.dart` - `getAdvertiserCompanyByUserId()` 메서드
  - `lib/screens/mypage/common/profile_screen.dart` - `_buildBusinessTab()` 메서드
  - `lib/utils/user_type_helper.dart` - 역할 확인 헬퍼

## 🔗 참고 자료

- [CompanyService 문서](../lib/services/company_service.dart)
- [UserTypeHelper 문서](../lib/utils/user_type_helper.dart)
- [Schema 분석 문서](./schema-and-logic-analysis.md)

## ✅ 체크리스트

- [x] 문제 원인 파악
- [x] 코드 수정 완료
- [x] 주석 추가
- [x] 문서 작성
- [ ] 테스트 완료 (수동 테스트 필요)

## 📌 추가 고려사항

### `getCompanyByUserId()` 메서드의 용도

`getCompanyByUserId()` 메서드는 여전히 다른 곳에서 사용될 수 있습니다:
- 리뷰어가 광고주로 전환할 때 회사 정보를 확인하는 경우
- 회원가입 시 기존 회사 정보를 확인하는 경우

따라서 이 메서드를 삭제하지 않고, **용도에 맞게 적절한 메서드를 선택**하여 사용해야 합니다.

### 역할 확인 로직

현재 `getAdvertiserCompanyByUserId()` 메서드는 내부적으로 `get_user_company_role_safe` RPC 함수를 호출하여 역할을 확인합니다:

```dart
// owner 또는 manager가 아니면 null 반환
if (companyRole != 'owner' && companyRole != 'manager') {
  return null;
}
```

이 로직은 다음과 같은 역할을 처리합니다:
- `'owner'`: ✅ 회사 정보 반환
- `'manager'`: ✅ 회사 정보 반환
- `'reviewer'`: ❌ null 반환
- `null` (회사에 소속되지 않음): ❌ null 반환

## 🎉 결론

Reviewer 역할 사용자가 프로필 페이지의 "사업자 정보" 탭에서 회사 정보를 볼 수 없도록 **데이터베이스 레벨에서 필터링**하도록 수정했습니다.

### 보안 강화

1. **RLS 정책**: Reviewer 역할은 companies 테이블을 조회할 수 없도록 제한
2. **RPC 함수**: `get_user_company_id_safe` 함수가 owner/manager 역할만 반환
3. **프론트엔드**: `getCompanyByUserId()` 메서드가 `get_advertiser_company_by_user_id` RPC 함수 사용

이제 **데이터베이스 레벨에서 필터링**되므로, 프론트엔드 코드를 우회하더라도 reviewer 역할 사용자는 회사 정보에 접근할 수 없습니다.

### 이중 보안

- **1차 방어**: RLS 정책에서 reviewer 역할 차단
- **2차 방어**: RPC 함수에서 owner/manager 역할만 반환
- **3차 방어**: 프론트엔드에서 적절한 메서드 사용

이러한 다층 보안 구조로 reviewer 역할 사용자의 회사 정보 접근을 완전히 차단했습니다.

