# 캠페인 생성 후 목록에 표시되지 않는 문제 분석

## 📋 목차
1. [문제 개요](#문제-개요)
2. [현재 구현 분석](#현재-구현-분석)
3. [문제 원인 분석](#문제-원인-분석)
4. [해결 방안](#해결-방안)
5. [권장 수정 사항](#권장-수정-사항)

---

## 문제 개요

**증상**: 캠페인 생성 완료 후 "나의 캠페인" 화면으로 이동했을 때, 방금 생성한 캠페인이 목록에 표시되지 않음

**영향**: 사용자 경험 저하, 캠페인 생성 여부 확인 불가

---

## 현재 구현 분석

### 1. 캠페인 생성 프로세스

**위치**: `lib/screens/campaign/campaign_creation_screen.dart:974`

**프로세스**:
```dart
// 1. 캠페인 생성 RPC 호출
final response = await _campaignService.createCampaignV2(...);

if (response.success) {
  // 2. 성공 메시지 표시
  ScaffoldMessenger.of(context).showSnackBar(...);
  
  // 3. 즉시 "나의 캠페인" 화면으로 이동 (refresh=true 파라미터 포함)
  context.go('/mypage/advertiser/my-campaigns?refresh=true');
}
```

**문제점**:
- 캠페인 생성 RPC가 완료되자마자 즉시 화면 이동
- 데이터베이스 트랜잭션이 완전히 커밋되기 전에 조회가 실행될 수 있음

### 2. 캠페인 생성 RPC 함수

**위치**: `lib/services/campaign_service.dart:611`

**구현**:
```dart
// RPC 함수 호출 (트랜잭션 내에서 실행)
final response = await _supabase.rpc(
  'create_campaign_with_points_v2',
  params: {...},
);

if (response['success'] == true) {
  // ✅ 같은 세션에서 생성된 캠페인 조회 (정상 작동)
  // RPC 함수가 완료되면 트랜잭션이 커밋되므로 조회 가능
  final campaignId = response['campaign_id'];
  final campaignData = await _supabase
      .from('campaigns')
      .select()
      .eq('id', campaignId)
      .single();  // ✅ 이 조회는 정상 작동
  
  return ApiResponse<Campaign>(success: true, data: newCampaign);
}
```

**RPC 함수 내부 트랜잭션 처리**:
```sql
-- supabase/migrations/...sql:382
BEGIN  -- 트랜잭션 시작
  -- 캠페인 생성
  INSERT INTO public.campaigns (...) VALUES (...);
  -- 포인트 차감
  INSERT INTO public.point_transactions (...) VALUES (...);
  -- 결과 반환
  RETURN v_result;  -- 트랜잭션 자동 커밋
END;
```

**특이사항**:
- ✅ RPC 함수가 완료되면 트랜잭션이 자동으로 커밋됨
- ✅ 같은 세션(`createCampaignV2`)에서 조회하면 정상 작동
- ❌ 하지만 다른 RPC 함수(`get_user_campaigns_safe`)에서 조회할 때는 다른 세션/트랜잭션이므로 최신 데이터를 보지 못할 수 있음

### 3. "나의 캠페인" 화면 초기화

**위치**: `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart:36`

**구현**:
```dart
@override
void initState() {
  super.initState();
  
  // URL 파라미터 확인
  final refresh = Uri.base.queryParameters['refresh'] == 'true';
  
  // 강제 새로고침인 경우 약간의 지연 후 조회
  if (refresh) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Supabase 클라이언트 캐싱을 우회하기 위한 짧은 지연
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        _loadCampaigns(forceRefresh: true);
        // URL 파라미터 제거
        final currentUri = Uri.base;
        if (currentUri.queryParameters.containsKey('refresh')) {
          final newUri = currentUri.replace(queryParameters: {});
          context.go(newUri.path);
        }
      }
    });
  } else {
    _loadCampaigns();
  }
}
```

**문제점**:
1. **100ms 지연이 부족**: 다른 세션에서의 조회를 보장하기에 충분하지 않음
   - RPC 함수는 완료되어 트랜잭션이 커밋되었지만, 다른 RPC 함수 호출 시 최신 데이터를 보지 못할 수 있음
2. **`forceRefresh` 파라미터 미사용**: `_loadCampaigns(forceRefresh: true)`로 호출하지만, 실제로는 사용되지 않음
3. **다른 세션 조회 문제**: `createCampaignV2`에서는 같은 세션에서 조회하므로 정상 작동하지만, `get_user_campaigns_safe`는 다른 세션에서 실행되므로 최신 데이터를 보지 못할 수 있음

### 4. 캠페인 목록 조회 로직

**위치**: `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart:101`

**구현**:
```dart
Future<void> _loadCampaigns({bool forceRefresh = false}) async {
  // forceRefresh 파라미터는 받지만 실제로 사용되지 않음
  
  final result = await _campaignService.getUserCampaigns(
    page: 1,
    limit: 100,
  );
  
  // RPC 함수 호출
  // get_user_campaigns_safe(p_user_id, p_status, p_limit, p_offset)
}
```

**문제점**:
- `forceRefresh` 파라미터가 `getUserCampaigns`에 전달되지 않음
- Supabase RPC 함수에 캐시 무효화 메커니즘이 없음

### 5. RPC 함수 구현

**위치**: `supabase/migrations/20251116140000_remove_unused_campaign_columns.sql:1358`

**구현**:
```sql
CREATE OR REPLACE FUNCTION "public"."get_user_campaigns_safe"(
  "p_user_id" "uuid",
  "p_status" "text" DEFAULT 'all'::"text",
  "p_limit" integer DEFAULT 20,
  "p_offset" integer DEFAULT 0
) RETURNS "jsonb"
```

**조회 로직**:
1. 사용자의 활성 회사 ID 목록 조회 (`company_users` 테이블)
2. 해당 회사의 캠페인 조회 (`campaigns` 테이블)
3. `ORDER BY created_at DESC`로 정렬

**문제점**:
- 트랜잭션 격리 수준에 따라 최신 데이터가 즉시 반영되지 않을 수 있음
- RPC 함수 내부에 캐싱 메커니즘이 없지만, Supabase 클라이언트나 네트워크 레벨에서 캐싱될 수 있음

---

## 문제 원인 분석

### 원인 1: 다른 세션에서의 조회 타이밍 문제 ⚠️ **주요 원인**

**설명**:
- `createCampaignV2`에서 RPC 함수 `create_campaign_with_points_v2`가 완료되면 트랜잭션이 커밋됩니다
- 그 후 **같은 세션**에서 생성된 캠페인을 조회하므로 정상적으로 조회됩니다 (697-701줄)
- 하지만 화면 이동 후 `get_user_campaigns_safe` RPC를 호출할 때는 **다른 RPC 함수 호출**이므로, PostgreSQL의 트랜잭션 격리 수준에 따라 최신 데이터를 보지 못할 수 있음
- PostgreSQL의 기본 격리 수준인 `READ COMMITTED`에서는:
  - 같은 트랜잭션 내에서는 최신 데이터를 볼 수 있음
  - 다른 트랜잭션에서는 약간의 지연이 발생할 수 있음
  - 특히 복제 지연이나 WAL(Write-Ahead Log) 처리 지연이 있을 수 있음

**코드 분석**:
```dart
// 1. RPC 함수 호출 (트랜잭션 내에서 실행)
final response = await _supabase.rpc('create_campaign_with_points_v2', ...);

if (response['success'] == true) {
  // 2. 같은 세션에서 생성된 캠페인 조회 (정상 작동)
  final campaignData = await _supabase
      .from('campaigns')
      .select()
      .eq('id', campaignId)
      .single();  // ✅ 이건 정상 작동
  
  // 3. 화면 이동
  context.go('/mypage/advertiser/my-campaigns?refresh=true');
}

// 4. 다른 화면에서 다른 RPC 함수 호출
// get_user_campaigns_safe는 다른 함수이므로 다른 세션/트랜잭션에서 실행
// 이때 최신 데이터를 보지 못할 수 있음
```

**증거**:
- 100ms 지연 후에도 캠페인이 표시되지 않음
- 시간이 지나면 수동 새로고침 시 캠페인이 나타남
- `createCampaignV2`에서 조회한 캠페인은 정상적으로 조회되지만, 목록 조회에서는 나타나지 않음

**영향도**: 🔴 **높음**

### 원인 2: 지연 시간 부족

**설명**:
- 현재 100ms 지연은 데이터베이스 트랜잭션 커밋을 보장하기에 충분하지 않음
- 네트워크 지연, Supabase 처리 시간 등을 고려하면 더 긴 지연이 필요할 수 있음

**증거**:
- 코드에서 "Supabase 클라이언트 캐싱을 우회하기 위한 짧은 지연"이라고 주석 처리되어 있음
- 하지만 실제로는 트랜잭션 커밋을 기다리는 시간이 필요함

**영향도**: 🟡 **중간**

### 원인 3: forceRefresh 파라미터 미사용

**설명**:
- `_loadCampaigns(forceRefresh: true)`로 호출하지만, 실제로 `getUserCampaigns` 메서드에 전달되지 않음
- Supabase RPC 함수에 캐시 무효화 메커니즘이 없음

**증거**:
```dart
// forceRefresh 파라미터를 받지만 사용하지 않음
Future<void> _loadCampaigns({bool forceRefresh = false}) async {
  final result = await _campaignService.getUserCampaigns(
    page: 1,
    limit: 100,
    // forceRefresh 파라미터 없음
  );
}
```

**영향도**: 🟡 **중간**

### 원인 4: 캐시 문제

**설명**:
- Supabase 클라이언트나 네트워크 레벨에서 응답을 캐싱할 수 있음
- RPC 함수 호출 결과가 캐시되어 최신 데이터가 반영되지 않을 수 있음

**증거**:
- 코드 주석에 "Supabase 클라이언트 캐싱을 우회하기 위한 짧은 지연"이라고 명시되어 있음
- 하지만 실제로는 캐시 무효화 메커니즘이 없음

**영향도**: 🟢 **낮음** (트랜잭션 타이밍 문제가 해결되면 함께 해결될 가능성 높음)

### 원인 5: RPC 함수의 트랜잭션 격리

**설명**:
- `get_user_campaigns_safe` RPC 함수가 `SECURITY DEFINER`로 실행됨
- 트랜잭션 격리 수준에 따라 최신 데이터가 즉시 반영되지 않을 수 있음

**증거**:
```sql
CREATE OR REPLACE FUNCTION "public"."get_user_campaigns_safe"(...)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
```

**영향도**: 🟡 **중간**

---

## 해결 방안

### 방안 1: 지연 시간 증가 (임시 해결책) ⚠️

**설명**: 100ms 지연을 500ms~1000ms로 증가

**장점**:
- 구현이 간단함
- 대부분의 경우 문제 해결

**단점**:
- 사용자 경험 저하 (로딩 시간 증가)
- 근본적인 해결책이 아님
- 네트워크 상황에 따라 여전히 실패할 수 있음

**구현**:
```dart
// 100ms → 500ms로 증가
await Future.delayed(const Duration(milliseconds: 500));
```

**권장도**: 🟡 **중간** (임시 해결책으로만 사용)

### 방안 2: 폴링 방식 (권장) ✅

**설명**: 캠페인 목록 조회를 여러 번 시도하여 새로 생성된 캠페인이 나타날 때까지 대기

**장점**:
- 확실한 해결책
- 사용자 경험 향상 (최소한의 지연)

**단점**:
- 구현이 복잡함
- 최대 대기 시간 설정 필요

**구현**:
```dart
Future<void> _loadCampaignsWithPolling({
  String? expectedCampaignId,
  int maxAttempts = 5,
  Duration interval = const Duration(milliseconds: 300),
}) async {
  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    await _loadCampaigns();
    
    if (expectedCampaignId != null) {
      final found = _allCampaigns.any((c) => c.id == expectedCampaignId);
      if (found) {
        break; // 캠페인을 찾았으면 종료
      }
    } else {
      // expectedCampaignId가 없으면 첫 번째 시도에서 종료
      break;
    }
    
    if (attempt < maxAttempts - 1) {
      await Future.delayed(interval);
    }
  }
}
```

**권장도**: 🟢 **높음**

### 방안 3: 생성된 캠페인 ID 전달 및 직접 추가

**설명**: 캠페인 생성 후 생성된 캠페인 ID를 전달하여 목록에 직접 추가

**장점**:
- 즉시 표시 가능
- 네트워크 요청 최소화

**단점**:
- 생성된 캠페인 데이터를 다시 조회해야 함
- 목록 정렬 문제 (created_at 기준)

**구현**:
```dart
// 캠페인 생성 후
if (response.success) {
  final campaignId = response.data?.id;
  
  // 생성된 캠페인 ID를 쿼리 파라미터로 전달
  context.go('/mypage/advertiser/my-campaigns?refresh=true&campaignId=$campaignId');
}

// "나의 캠페인" 화면에서
final campaignId = Uri.base.queryParameters['campaignId'];
if (campaignId != null) {
  // 생성된 캠페인 조회
  final campaign = await _campaignService.getCampaignById(campaignId);
  if (campaign.success && campaign.data != null) {
    // 목록에 추가
    _allCampaigns.insert(0, campaign.data!);
    _updateFilteredCampaigns();
  }
}
```

**권장도**: 🟢 **높음**

### 방안 4: Supabase Realtime 사용

**설명**: Supabase Realtime을 사용하여 캠페인 생성 이벤트를 실시간으로 수신

**장점**:
- 실시간 업데이트
- 확장성 좋음

**단점**:
- 구현이 복잡함
- Realtime 설정 필요
- 오버헤드 증가

**권장도**: 🟡 **중간** (장기적인 해결책)

### 방안 5: RPC 함수에 캐시 무효화 파라미터 추가

**설명**: RPC 함수에 타임스탬프나 랜덤 값을 전달하여 캐시 무효화

**장점**:
- 캐시 문제 해결

**단점**:
- 트랜잭션 타이밍 문제는 해결하지 못함
- RPC 함수 수정 필요

**구현**:
```dart
final result = await _campaignService.getUserCampaigns(
  page: 1,
  limit: 100,
  cacheBuster: DateTime.now().millisecondsSinceEpoch, // 추가
);
```

**권장도**: 🟡 **중간** (보조 해결책)

---

## 권장 수정 사항

### 즉시 적용 가능한 해결책 (방안 2 + 방안 3 조합)

**1단계: 캠페인 생성 후 ID 전달**

```dart
// lib/screens/campaign/campaign_creation_screen.dart
if (response.success) {
  final campaignId = response.data?.id;
  
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(...);
    
    // 생성된 캠페인 ID를 쿼리 파라미터로 전달
    if (campaignId != null) {
      context.go('/mypage/advertiser/my-campaigns?refresh=true&campaignId=$campaignId');
    } else {
      context.go('/mypage/advertiser/my-campaigns?refresh=true');
    }
  }
}
```

**2단계: "나의 캠페인" 화면에서 폴링 및 직접 추가**

```dart
// lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart
@override
void initState() {
  super.initState();
  
  final refresh = Uri.base.queryParameters['refresh'] == 'true';
  final campaignId = Uri.base.queryParameters['campaignId'];
  
  if (refresh) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (campaignId != null) {
        // 폴링 방식으로 캠페인 조회
        await _loadCampaignsWithPolling(
          expectedCampaignId: campaignId,
          maxAttempts: 5,
          interval: const Duration(milliseconds: 300),
        );
      } else {
        // campaignId가 없으면 일반 조회
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _loadCampaigns();
        }
      }
      
      // URL 파라미터 제거
      final currentUri = Uri.base;
      if (currentUri.queryParameters.isNotEmpty) {
        final newUri = currentUri.replace(queryParameters: {});
        context.go(newUri.path);
      }
    });
  } else {
    _loadCampaigns();
  }
}

Future<void> _loadCampaignsWithPolling({
  String? expectedCampaignId,
  int maxAttempts = 5,
  Duration interval = const Duration(milliseconds: 300),
}) async {
  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    await _loadCampaigns();
    
    if (expectedCampaignId != null && mounted) {
      final found = _allCampaigns.any((c) => c.id == expectedCampaignId);
      if (found) {
        debugPrint('✅ 생성된 캠페인을 찾았습니다: $expectedCampaignId');
        break;
      }
      
      if (attempt < maxAttempts - 1) {
        debugPrint('⏳ 캠페인 조회 재시도 중... (${attempt + 1}/$maxAttempts)');
        await Future.delayed(interval);
      } else {
        debugPrint('⚠️ 최대 재시도 횟수 초과. 캠페인을 찾지 못했습니다.');
        // 마지막 시도에서도 찾지 못하면 생성된 캠페인을 직접 조회하여 추가
        await _addCampaignById(expectedCampaignId);
      }
    } else {
      break;
    }
  }
}

Future<void> _addCampaignById(String campaignId) async {
  try {
    final result = await _campaignService.getCampaignById(campaignId);
    if (result.success && result.data != null && mounted) {
      final campaign = result.data!;
      
      // 중복 체크
      if (!_allCampaigns.any((c) => c.id == campaignId)) {
        _allCampaigns.insert(0, campaign);
        _updateFilteredCampaigns();
        setState(() {});
        debugPrint('✅ 생성된 캠페인을 직접 조회하여 추가했습니다.');
      }
    }
  } catch (e) {
    debugPrint('❌ 캠페인 직접 조회 실패: $e');
  }
}
```

**3단계: 지연 시간 조정**

```dart
// 100ms → 300ms로 증가 (폴링 간격)
await Future.delayed(const Duration(milliseconds: 300));
```

### 장기적인 개선 사항

1. **Supabase Realtime 도입**: 실시간 업데이트를 위한 Realtime 구독
2. **캐시 전략 개선**: 클라이언트 측 캐시 무효화 메커니즘 추가
3. **에러 처리 강화**: 캠페인을 찾지 못한 경우 사용자에게 알림

---

## 테스트 시나리오

### 시나리오 1: 정상 케이스
1. 캠페인 생성
2. 생성 완료 후 "나의 캠페인" 화면으로 이동
3. 생성된 캠페인이 목록 최상단에 표시되는지 확인

### 시나리오 2: 네트워크 지연 케이스
1. 네트워크 지연 시뮬레이션
2. 캠페인 생성
3. 폴링이 정상적으로 작동하는지 확인

### 시나리오 3: 트랜잭션 지연 케이스
1. 데이터베이스 부하 시뮬레이션
2. 캠페인 생성
3. 최대 재시도 횟수 내에 캠페인이 표시되는지 확인

---

## 관련 파일

- `lib/screens/campaign/campaign_creation_screen.dart`: 캠페인 생성 화면
- `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`: 나의 캠페인 화면
- `lib/services/campaign_service.dart`: 캠페인 서비스
- `supabase/migrations/20251116140000_remove_unused_campaign_columns.sql`: RPC 함수 정의

---

**문서 작성일**: 2024-01-15  
**최종 수정일**: 2024-01-15  
**작성자**: AI Assistant

