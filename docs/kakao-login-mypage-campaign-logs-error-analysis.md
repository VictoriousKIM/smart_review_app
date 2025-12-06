# 카카오 로그인 마이페이지 캠페인 로그 조회 에러 분석

**작성일**: 2025년 12월 06일  
**에러**: `POST http://127.0.0.1:54500/rest/v1/rpc/get_user_campaign_logs_safe 400 (Bad Request)`  
**발생 시점**: 카카오 로그인 후 마이페이지 접근 시  
**영향 범위**: 리뷰어 마이페이지 > 내 캠페인 화면

---

## 📋 에러 개요

### 에러 메시지
```
POST http://127.0.0.1:54500/rest/v1/rpc/get_user_campaign_logs_safe 400 (Bad Request)
```

### 발생 위치
- **화면**: `/mypage/reviewer/my-campaigns` (내 캠페인 화면)
- **서비스**: `CampaignLogService.getUserCampaignLogs()`
- **RPC 함수**: `get_user_campaign_logs_safe`

---

## 🔍 원인 분석

### 1. 함수 오버로딩 문제 (가능성 높음)

**문제점:**
- 마이그레이션 스쿼시 후 기존 함수 정의가 남아있을 수 있음
- PostgreSQL은 함수 오버로딩을 지원하지만, Supabase PostgREST는 파라미터 타입이 명확하지 않으면 400 에러 발생

**확인 사항:**
```sql
-- 기존 함수가 남아있는지 확인 필요
SELECT proname, pronargs, proargtypes 
FROM pg_proc 
WHERE proname = 'get_user_campaign_logs_safe';
```

### 2. 파라미터 타입 불일치

**현재 함수 정의:**
```sql
CREATE OR REPLACE FUNCTION "public"."get_user_campaign_logs_safe"(
    "p_user_id" "uuid" DEFAULT NULL::"uuid",
    "p_status" "text" DEFAULT NULL::"text",
    "p_limit" integer DEFAULT 50,
    "p_offset" integer DEFAULT 0
) RETURNS "jsonb"
```

**Flutter 호출 코드:**
```dart
final response = await _supabase.rpc(
  'get_user_campaign_logs_safe',
  params: {
    'p_user_id': userId,  // String 타입
    'p_status': status,   // String? 타입
    'p_limit': 100,
    'p_offset': 0,
  },
) as List;
```

**문제점:**
- `userId`는 `String` 타입이지만, 함수는 `uuid` 타입을 기대
- Supabase Flutter SDK가 자동으로 변환하지만, 때때로 실패할 수 있음

### 3. 카카오 로그인 vs 네이버 로그인 차이

**세션 타입 차이:**
- **카카오 로그인**: Supabase 네이티브 세션 사용 (`auth.uid()` 사용 가능)
- **네이버 로그인**: Custom JWT 세션 사용 (`auth.uid()` = NULL)

**함수 내부 로직:**
```sql
v_user_id := COALESCE(p_user_id, auth.uid());
```

**문제점:**
- 카카오 로그인 시 `auth.uid()`가 존재하므로 `p_user_id`가 NULL이어도 작동해야 함
- 하지만 Flutter 코드에서 항상 `p_user_id`를 전달하고 있음
- 만약 `userId`가 잘못된 형식이면 400 에러 발생

### 4. 마이그레이션 스쿼시 후 함수 중복

**가능성:**
- 마이그레이션 스쿼시 과정에서 기존 함수 정의가 완전히 제거되지 않았을 수 있음
- 여러 버전의 함수가 동시에 존재하면 PostgREST가 어떤 함수를 호출할지 결정하지 못함

---

## 🔧 해결 방안

### 방안 1: 함수 명시적 삭제 후 재생성 (권장)

**마이그레이션 파일 수정:**
```sql
-- 기존 함수 완전히 삭제
DROP FUNCTION IF EXISTS "public"."get_user_campaign_logs_safe"("p_user_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer);
DROP FUNCTION IF EXISTS "public"."get_user_campaign_logs_safe"("p_user_id" "uuid", "p_status" "text");
DROP FUNCTION IF EXISTS "public"."get_user_campaign_logs_safe"("p_user_id" "uuid");
DROP FUNCTION IF EXISTS "public"."get_user_campaign_logs_safe"();

-- 새 함수 생성
CREATE OR REPLACE FUNCTION "public"."get_user_campaign_logs_safe"(
    "p_user_id" "uuid" DEFAULT NULL::"uuid",
    "p_status" "text" DEFAULT NULL::"text",
    "p_limit" integer DEFAULT 50,
    "p_offset" integer DEFAULT 0
) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id UUID;
    v_result jsonb;
BEGIN
    -- 사용자 ID 확인: 파라미터가 있으면 사용, 없으면 auth.uid() 사용
    v_user_id := COALESCE(p_user_id, auth.uid());
    
    -- 권한 확인
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 캠페인 로그 조회
    WITH campaign_logs AS (
        SELECT 
            cal.id,
            cal.campaign_id,
            cal.user_id,
            cal.action,
            cal.application_message,
            cal.status,
            cal.created_at,
            cal.updated_at,
            jsonb_build_object(
                'id', c.id,
                'title', c.title,
                'campaign_type', c.campaign_type,
                'product_image_url', c.product_image_url,
                'platform', c.platform,
                'companies', jsonb_build_object(
                    'id', comp.id,
                    'name', comp.name,
                    'logo_url', comp.logo_url
                )
            ) AS campaigns
        FROM public.campaign_action_logs cal
        INNER JOIN public.campaigns c ON c.id = cal.campaign_id
        INNER JOIN public.companies comp ON comp.id = c.company_id
        WHERE cal.user_id = v_user_id
        AND (p_status IS NULL OR cal.status = p_status)
        ORDER BY cal.updated_at DESC NULLS LAST
        LIMIT p_limit
        OFFSET p_offset
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'campaign_id', campaign_id,
            'user_id', user_id,
            'action', action,
            'application_message', application_message,
            'status', status,
            'created_at', created_at,
            'updated_at', updated_at,
            'campaigns', campaigns
        )
    )
    INTO v_result
    FROM campaign_logs;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;
```

### 방안 2: Flutter 코드에서 UUID 변환 명시

**수정 전:**
```dart
params: {
  'p_user_id': userId,  // String
  'p_status': status,
  'p_limit': 100,
  'p_offset': 0,
},
```

**수정 후:**
```dart
params: {
  'p_user_id': userId,  // Supabase SDK가 자동 변환
  'p_status': status,
  'p_limit': 100,
  'p_offset': 0,
},
```

**참고:** Supabase Flutter SDK는 String을 UUID로 자동 변환하므로, 이 방법은 문제 해결에 도움이 되지 않을 수 있음

### 방안 3: 에러 처리 개선

**현재 코드:**
```dart
} catch (e) {
  return ApiResponse<List<CampaignLog>>(
    success: false,
    error: '캠페인 로그 조회 실패: $e',
  );
}
```

**개선 코드:**
```dart
} catch (e) {
  debugPrint('❌ get_user_campaign_logs_safe 에러: $e');
  debugPrint('   userId: $userId');
  debugPrint('   status: $status');
  
  // 400 에러인 경우 상세 정보 로깅
  if (e is PostgrestException && e.code == 'PGRST203') {
    debugPrint('⚠️ 함수 오버로딩 충돌 가능성');
  }
  
  return ApiResponse<List<CampaignLog>>(
    success: false,
    error: '캠페인 로그 조회 실패: $e',
  );
}
```

---

## 🧪 테스트 방법

### 1. 함수 중복 확인
```sql
-- PostgreSQL에서 실행
SELECT 
    proname,
    pronargs,
    pg_get_function_arguments(oid) as arguments
FROM pg_proc 
WHERE proname = 'get_user_campaign_logs_safe'
ORDER BY pronargs;
```

### 2. 함수 직접 호출 테스트
```sql
-- 카카오 로그인 사용자 ID로 테스트
SELECT get_user_campaign_logs_safe(
    '5243a04d-3ad0-4d07-ad06-ce73aa70d28d'::uuid,
    NULL::text,
    50,
    0
);
```

### 3. Flutter 코드 디버깅
```dart
debugPrint('🔍 getUserCampaignLogs 호출:');
debugPrint('   userId: $userId');
debugPrint('   userId 타입: ${userId.runtimeType}');
debugPrint('   status: $status');
```

---

## 📊 영향 범위

### 영향받는 화면
- ✅ `/mypage/reviewer/my-campaigns` - 내 캠페인 화면
- ✅ `/mypage/reviewer/reviews` - 내 리뷰 화면 (간접 영향)

### 영향받는 기능
- ✅ 캠페인 신청 내역 조회
- ✅ 캠페인 선정 내역 조회
- ✅ 캠페인 등록 내역 조회
- ✅ 캠페인 완료 내역 조회

### 영향받는 로그인 방식
- ❌ **카카오 로그인**: 에러 발생
- ✅ **네이버 로그인**: 정상 작동 (추정)
- ❓ **구글 로그인**: 미확인

---

## 🎯 권장 조치 사항

### 즉시 조치
1. ✅ 함수 중복 확인 및 정리
2. ✅ 마이그레이션 파일에서 기존 함수 명시적 삭제
3. ✅ 데이터베이스 리셋 후 재테스트

### 장기 조치
1. ✅ 모든 RPC 함수에 대한 통합 테스트 작성
2. ✅ 함수 오버로딩 방지 가이드라인 수립
3. ✅ 에러 로깅 및 모니터링 강화

---

## 📝 참고 사항

### 관련 파일
- `supabase/migrations/20251206100536_fix_get_user_wallet_current_safe_for_custom_jwt.sql`
- `lib/services/campaign_log_service.dart`
- `lib/screens/mypage/reviewer/my_campaigns_screen.dart`

### 관련 이슈
- Custom JWT 세션 지원을 위한 RPC 함수 수정
- 함수 오버로딩 충돌 해결
- 카카오/네이버 로그인 세션 차이 처리

---

## 🔄 업데이트 이력

- **2025-12-06**: 초기 문서 작성
- **원인**: 함수 오버로딩 문제 또는 파라미터 타입 불일치 추정
- **상태**: 분석 완료, 해결 방안 제시

