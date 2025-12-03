# SNS 연결 회원가입 문제 심층 분석 및 해결 방안

**작성일**: 2025년 01월 28일  
**상태**: 분석 완료, 해결 방안 제시

---

## 📋 문제 요약

회원가입 시 SNS 연결 정보를 입력했지만, 실제로 DB에 저장되지 않는 문제가 발생했습니다.

---

## 🔍 문제 분석

### 1. 현재 코드 구조

#### `create_reviewer_profile_with_company` RPC 함수
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
```

### 2. 발견된 문제점

#### 문제 1: 에러가 조용히 무시됨
- `PERFORM` 명령은 반환값을 무시합니다
- `EXCEPTION` 블록에서 `RAISE WARNING`만 하고 계속 진행합니다
- 실제로 에러가 발생했는지 확인할 방법이 없습니다
- **결과**: SNS 연결이 실패해도 회원가입은 성공으로 처리됩니다

#### 문제 2: 결과 추적 불가
- RPC 함수의 반환값에 SNS 연결 결과가 포함되지 않습니다
- Flutter 코드에서 `result['sns_connections']`를 확인하려고 하지만, 실제로는 반환되지 않습니다
- **결과**: 사용자에게 SNS 연결 실패를 알릴 수 없습니다

#### 문제 3: 타임라인 문제 가능성
- `create_reviewer_profile_with_company` 함수는 먼저 `users` 테이블에 INSERT합니다
- 그 다음 SNS 연결을 생성합니다
- 하지만 `create_sns_connection` 함수는 사용자 존재 여부를 확인합니다:
  ```sql
  IF NOT EXISTS (SELECT 1 FROM "public"."users" WHERE "id" = "p_user_id") THEN
      RAISE EXCEPTION '사용자를 찾을 수 없습니다';
  END IF;
  ```
- 트랜잭션 내에서 실행되므로, 같은 트랜잭션 내에서 INSERT한 레코드를 확인할 수 있어야 합니다
- **하지만**: `SET search_path TO ''` 설정으로 인해 스키마 문제가 발생할 수 있습니다

#### 문제 4: search_path 설정 문제
- `create_reviewer_profile_with_company` 함수는 `SET search_path TO ''`로 설정되어 있습니다
- `create_sns_connection` 함수도 `SET search_path TO ''`로 설정되어 있습니다
- 하지만 `public.users`를 명시적으로 참조하고 있으므로 문제가 없어야 합니다
- **하지만**: 트랜잭션 격리 수준이나 타이밍 문제로 인해 새로 INSERT한 레코드를 확인하지 못할 수 있습니다

### 3. 실제 발생 가능한 시나리오

#### 시나리오 1: 사용자 존재 확인 실패
```
1. create_reviewer_profile_with_company 시작
2. users 테이블에 INSERT (트랜잭션 내)
3. create_sns_connection 호출
4. create_sns_connection에서 users 테이블 확인
5. 트랜잭션 격리 수준으로 인해 아직 커밋되지 않은 레코드를 확인하지 못함
6. "사용자를 찾을 수 없습니다" 에러 발생
7. EXCEPTION 블록에서 WARNING만 남기고 계속 진행
8. 회원가입은 성공으로 처리되지만 SNS 연결은 저장되지 않음
```

#### 시나리오 2: 데이터 형식 문제
- Flutter에서 전달하는 JSONB 형식이 예상과 다를 수 있습니다
- `v_conn->>'platform'` 등에서 NULL이 반환될 수 있습니다
- NULL 값이 `create_sns_connection`에 전달되면 검증 실패 가능

#### 시나리오 3: 제약 조건 위반
- UNIQUE 제약 조건 위반 (이미 같은 계정이 존재)
- 하지만 이 경우 `unique_violation` 예외가 발생해야 합니다

---

## 💡 해결 방안

### 방안 1: RPC 함수 개선 (권장)

#### 1-1. SNS 연결 결과 추적 및 반환

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
  v_sns_success_count INT := 0;
  v_sns_failed_count INT := 0;
  v_sns_errors JSONB := '[]'::JSONB;
  v_sns_result JSONB;
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
    'user',
    p_phone,
    p_address,
    NOW(),
    NOW()
  ) RETURNING id INTO v_profile_id;
  
  -- 2. 지갑 생성 (트리거로 자동)
  
  -- 3. SNS 연결 생성 (결과 추적)
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
        v_error_text TEXT;
      BEGIN
        -- create_sns_connection 호출 및 결과 저장
        SELECT create_sns_connection(
          p_user_id,
          v_platform,
          v_account_id,
          v_account_name,
          v_phone,
          v_address,
          v_return_address
        ) INTO v_sns_result;
        
        -- 성공 카운트 증가
        v_sns_success_count := v_sns_success_count + 1;
      EXCEPTION
        WHEN OTHERS THEN
          -- 실패 카운트 증가 및 에러 메시지 저장
          v_sns_failed_count := v_sns_failed_count + 1;
          v_error_text := SQLERRM;
          v_sns_errors := v_sns_errors || jsonb_build_object(
            'platform', v_platform,
            'account_id', v_account_id,
            'error', v_error_text
          );
          -- WARNING도 남기기
          RAISE WARNING 'SNS 연결 생성 실패 (플랫폼: %, 계정: %): %', 
            v_platform, v_account_id, v_error_text;
      END;
    END LOOP;
  END IF;
  
  -- 4. 회사 연결 (선택)
  IF p_company_id IS NOT NULL THEN
    -- 중복 체크
    IF NOT EXISTS (
      SELECT 1 FROM public.company_users
      WHERE company_id = p_company_id AND user_id = p_user_id
    ) THEN
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
        'reviewer',
        'active',
        NOW(),
        NOW()
      );
    END IF;
  END IF;
  
  -- 트랜잭션 커밋 (자동)
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_profile_id,
    'company_id', p_company_id,
    'sns_connections', jsonb_build_object(
      'success', v_sns_success_count,
      'failed', v_sns_failed_count,
      'errors', v_sns_errors
    )
  );
EXCEPTION
  WHEN OTHERS THEN
    -- 트랜잭션 롤백 (자동)
    RAISE EXCEPTION '리뷰어 회원가입 실패: %', SQLERRM;
END;
$$;
```

#### 1-2. 사용자 존재 확인 로직 개선

`create_sns_connection` 함수에서 사용자 존재 확인을 더 안전하게 처리:

```sql
-- 기존 코드
IF NOT EXISTS (SELECT 1 FROM "public"."users" WHERE "id" = "p_user_id") THEN
    RAISE EXCEPTION '사용자를 찾을 수 없습니다';
END IF;

-- 개선된 코드 (트랜잭션 내에서도 확인 가능)
IF NOT EXISTS (
  SELECT 1 FROM "public"."users" 
  WHERE "id" = "p_user_id"
  FOR UPDATE  -- 락을 걸어서 트랜잭션 내에서도 확인 가능
) THEN
    RAISE EXCEPTION '사용자를 찾을 수 없습니다';
END IF;
```

### 방안 2: Flutter 코드 개선

#### 2-1. SNS 연결 결과 확인 및 사용자 알림

```dart
// RPC 함수 호출
final result = await SupabaseConfig.client.rpc(
  'create_reviewer_profile_with_company',
  params: {
    'p_user_id': userId,
    'p_display_name': _displayName!,
    'p_phone': _phone ?? '',
    'p_address': fullAddress,
    'p_company_id': _selectedCompanyId,
    'p_sns_connections': _snsConnections.isNotEmpty
        ? _snsConnections
        : null,
  },
);

debugPrint('✅ 회원가입 RPC 결과: $result');

// SNS 연결 결과 확인
if (result != null && result['sns_connections'] != null) {
  final snsResult = result['sns_connections'] as Map<String, dynamic>;
  final success = snsResult['success'] as int? ?? 0;
  final failed = snsResult['failed'] as int? ?? 0;
  final errors = snsResult['errors'] as List<dynamic>? ?? [];
  
  if (failed > 0) {
    debugPrint('⚠️ SNS 연결 일부 실패: 성공 $success개, 실패 $failed개');
    for (var error in errors) {
      debugPrint('  - 플랫폼: ${error['platform']}, 계정: ${error['account_id']}');
      debugPrint('    에러: ${error['error']}');
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SNS 연결 일부 실패: $failed개 연결이 등록되지 않았습니다. 마이페이지에서 다시 등록해주세요.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  } else if (success > 0) {
    debugPrint('✅ SNS 연결 모두 성공: $success개');
  }
}
```

### 방안 3: 디버깅 강화

#### 3-1. 로그 추가

RPC 함수에 더 자세한 로그 추가:

```sql
-- SNS 연결 생성 전 로그
RAISE NOTICE 'SNS 연결 생성 시도: 플랫폼=%, 계정ID=%, 사용자ID=%', 
  v_platform, v_account_id, p_user_id;

-- 사용자 존재 확인 전 로그
RAISE NOTICE '사용자 존재 확인: 사용자ID=%', p_user_id;
```

#### 3-2. Flutter에서 전송 데이터 검증

```dart
// SNS 연결 데이터 검증
if (_snsConnections.isNotEmpty) {
  debugPrint('📤 SNS 연결 데이터 전송:');
  for (var conn in _snsConnections) {
    // 필수 필드 검증
    if (conn['platform'] == null || conn['platform'].toString().isEmpty) {
      throw Exception('SNS 연결 데이터 오류: platform이 없습니다');
    }
    if (conn['platform_account_id'] == null || conn['platform_account_id'].toString().isEmpty) {
      throw Exception('SNS 연결 데이터 오류: platform_account_id가 없습니다');
    }
    // ... 기타 검증
    
    debugPrint('  - 플랫폼: ${conn['platform']}');
    debugPrint('    계정 ID: ${conn['platform_account_id']}');
    debugPrint('    계정 이름: ${conn['platform_account_name']}');
    debugPrint('    전화번호: ${conn['phone']}');
    debugPrint('    주소: ${conn['address']}');
    debugPrint('    반품주소: ${conn['return_address']}');
  }
}
```

---

## 🎯 권장 해결 순서

1. **즉시 적용**: 방안 1-1 (RPC 함수 개선) - SNS 연결 결과 추적 및 반환
2. **즉시 적용**: 방안 2-1 (Flutter 코드 개선) - 결과 확인 및 사용자 알림
3. **검토 필요**: 방안 1-2 (사용자 존재 확인 로직 개선) - 실제 문제인지 확인 후 적용
4. **선택적**: 방안 3 (디버깅 강화) - 문제 재발 시 상세 로그 확인

---

## 📝 추가 확인 사항

1. **PostgreSQL 로그 확인**: 실제 에러 메시지 확인
2. **트랜잭션 격리 수준**: READ COMMITTED vs SERIALIZABLE
3. **RLS 정책**: `create_sns_connection` 함수 실행 시 RLS 정책 영향 확인
4. **타이밍 이슈**: 트랜잭션 내에서 INSERT 후 즉시 SELECT 시도 시 문제 가능성

---

## 🔧 테스트 방법

1. 마이그레이션 파일 생성 및 적용
2. 회원가입 플로우 재테스트
3. PostgreSQL 로그에서 WARNING 메시지 확인
4. Flutter 콘솔에서 SNS 연결 결과 확인
5. DB에서 실제 데이터 확인

---

## 📌 참고

- `PERFORM` vs `SELECT ... INTO`: `PERFORM`은 반환값을 무시하므로, 결과를 확인하려면 `SELECT ... INTO`를 사용해야 합니다
- 트랜잭션 격리 수준: PostgreSQL의 기본 격리 수준은 READ COMMITTED이며, 같은 트랜잭션 내에서 INSERT한 레코드는 SELECT로 확인 가능해야 합니다
- `SET search_path TO ''`: 빈 search_path는 스키마를 명시적으로 지정해야 하므로, `public.users`처럼 명시적으로 지정해야 합니다

