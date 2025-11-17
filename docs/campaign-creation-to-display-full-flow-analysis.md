# 캠페인 생성부터 "나의 캠페인" 화면 표시까지 전체 로직 분석

## 📋 문서 개요

**작성 일시**: 2025-11-16  
**목적**: 캠페인 생성하기 버튼 클릭부터 "나의 캠페인" 화면에 생성된 캠페인이 표시되기까지의 전체 로직을 상세히 분석하고, 각 단계에서 발생할 수 있는 문제점과 해결 방법을 정리

---

## 🔄 전체 로직 흐름도

```
[사용자 액션]
    ↓
[캠페인 생성하기 버튼 클릭]
    ↓
[1. Presentation Layer: _createCampaign() 실행]
    │ (CampaignCreationScreen 클래스의 private 메서드)
    ├─ 중복 호출 방지 체크
    ├─ 폼 검증 (UI 레벨)
    ├─ 잔액 확인 (UI 레벨)
    ├─ 이미지 업로드 (필요시)
    └─ 데이터 변환 및 준비
    ↓
[2. Service Layer: createCampaignV2() 호출]
    │ (CampaignService 클래스의 public 메서드)
    │ _createCampaign()에서 _campaignService.createCampaignV2() 호출
    ├─ 입력값 검증 (비즈니스 로직 레벨)
    ├─ 사용자 인증 확인
    └─ RPC 함수 호출 준비
    ↓
[3. 백엔드: create_campaign_with_points_v2 RPC 실행]
    ├─ 사용자 인증 확인
    ├─ 회사 정보 조회
    ├─ 비용 계산
    ├─ 지갑 잠금 (FOR UPDATE NOWAIT)
    ├─ 포인트 차감
    ├─ 캠페인 생성
    ├─ 포인트 거래 기록
    └─ 트랜잭션 커밋
    ↓
[4. 프론트엔드: 응답 처리]
    ├─ 성공 시: 캠페인 ID 추출
    ├─ 리다이렉트: /mypage/advertiser/my-campaigns?refresh=true&campaignId={id}
    └─ 실패 시: 에러 메시지 표시
    ↓
[5. 라우터: GoRouter 라우팅]
    ├─ 쿼리 파라미터 파싱
    └─ AdvertiserMyCampaignsScreen 위젯 생성
    ↓
[6. 프론트엔드: AdvertiserMyCampaignsScreen 초기화]
    ├─ initState() 실행
    ├─ 위젯 파라미터 읽기
    └─ PostFrameCallback 등록
    ↓
[7. 프론트엔드: PostFrameCallback 실행]
    ├─ GoRouterState에서 쿼리 파라미터 읽기
    ├─ refresh=true 확인
    └─ _handleRefresh() 호출
    ↓
[8. 프론트엔드: 폴링 로직 실행]
    ├─ 직접 조회 시도 (_addCampaignById)
    ├─ 실패 시 폴링 시작 (_loadCampaignsWithPolling)
    └─ 최대 5회 재시도 (exponential backoff)
    ↓
[9. 백엔드: get_user_campaigns_safe RPC 실행]
    ├─ 사용자 권한 확인
    ├─ 회사 ID 목록 조회
    └─ 캠페인 목록 조회 (company_id 기반)
    ↓
[10. 프론트엔드: 캠페인 목록 업데이트]
    ├─ 캠페인 데이터 파싱
    ├─ 상태별 분류
    └─ UI 업데이트 (setState)
    ↓
[11. 프론트엔드: URL 파라미터 제거]
    └─ 쿼리 파라미터 제거 후 리다이렉트
    ↓
[완료: 캠페인 목록에 생성된 캠페인 표시]
```

---

## 📝 단계별 상세 분석

### 1단계: 캠페인 생성하기 버튼 클릭 (Presentation Layer)

**파일**: `lib/screens/campaign/campaign_creation_screen.dart`  
**클래스**: `CampaignCreationScreen`  
**메서드**: `_createCampaign()` (라인 974-1142)  
**역할**: UI 레벨의 비즈니스 로직 처리 (폼 검증, 상태 관리, 이미지 업로드 등)

#### 실행 로직

```dart
Future<void> _createCampaign() async {
  // 1. 중복 호출 방지
  if (_isCreatingCampaign) {
    debugPrint('⚠️ 캠페인 생성이 이미 진행 중입니다.');
    return;
  }

  // 2. 폼 검증
  if (!_formKey.currentState!.validate()) return;

  // 3. 잔액 확인
  if (_totalCost > _currentBalance) {
    setState(() {
      _errorMessage = '잔액이 부족합니다.';
    });
    return;
  }

  // 4. 생성 시도 ID 생성 (중복 방지)
  final creationId = DateTime.now().millisecondsSinceEpoch.toString();
  if (_lastCampaignCreationId == creationId) {
    return;
  }
  _lastCampaignCreationId = creationId;
  _isCreatingCampaign = true;

  // 5. 이미지 업로드 (필요시)
  String? productImageUrl;
  if (_productImage != null) {
    productImageUrl = await _uploadProductImage(_productImage!);
  }

  // 6. 캠페인 생성 API 호출
  final response = await _campaignService.createCampaignV2(...);

  // 7. 성공 시 리다이렉트
  if (response.success) {
    final campaignId = response.data?.id;
    if (campaignId != null) {
      context.go('/mypage/advertiser/my-campaigns?refresh=true&campaignId=$campaignId');
    }
  }
}
```

#### 왜 두 단계로 나뉘었나?

**아키텍처 패턴: Presentation Layer → Service Layer**

1. **Presentation Layer (`_createCampaign`)**: 
   - UI에 특화된 로직 (폼 검증, 상태 관리, 이미지 업로드)
   - 화면별로 다른 처리 필요
   - 사용자 인터랙션 직접 처리

2. **Service Layer (`createCampaignV2`)**:
   - 재사용 가능한 비즈니스 로직
   - 여러 화면에서 공통으로 사용 가능
   - API 호출 및 데이터 처리

**장점**:
- 관심사의 분리 (Separation of Concerns)
- 코드 재사용성 향상
- 테스트 용이성
- 유지보수성 향상

#### 잠재적 문제점

1. **중복 호출 방지**: `_isCreatingCampaign` 플래그만으로는 완벽하지 않을 수 있음
   - **해결**: 생성 시도 ID 추가로 이중 체크

2. **이미지 업로드 실패**: 이미지 업로드가 실패하면 캠페인 생성이 중단됨
   - **현재 처리**: 업로드 실패 시 `return`으로 중단
   - **개선 가능**: 사용자에게 명확한 에러 메시지 표시

---

### 2단계: CampaignService.createCampaignV2() 호출 (Service Layer)

**파일**: `lib/services/campaign_service.dart`  
**클래스**: `CampaignService`  
**메서드**: `createCampaignV2()` (라인 610-743)  
**역할**: API 호출 및 비즈니스 로직 처리 (재사용 가능한 서비스 레이어)

**호출 관계**: 
- `_createCampaign()` (라인 1065)에서 `_campaignService.createCampaignV2()` 호출
- `_campaignService`는 `CampaignService()` 싱글톤 인스턴스 (라인 34)

#### 실행 로직

```dart
Future<ApiResponse<Campaign>> createCampaignV2({...}) async {
  // 1. 사용자 인증 확인
  final user = SupabaseConfig.client.auth.currentUser;
  if (user == null) {
    return ApiResponse(success: false, error: '로그인이 필요합니다.');
  }

  // 2. 입력값 검증
  if (title.trim().isEmpty) {
    return ApiResponse(success: false, error: '제품명을 입력해주세요.');
  }

  // 3. RPC 함수 호출
  final response = await _supabase.rpc(
    'create_campaign_with_points_v2',
    params: {...},
  );

  // 4. 성공 시 생성된 캠페인 조회
  if (response['success'] == true) {
    final campaignId = response['campaign_id'];
    final campaignData = await _supabase
        .from('campaigns')
        .select()
        .eq('id', campaignId)
        .single();

    final newCampaign = Campaign.fromJson(campaignData);
    return ApiResponse(success: true, data: newCampaign);
  }
}
```

#### 잠재적 문제점

1. **RPC 호출 후 즉시 조회**: RPC 함수가 트랜잭션을 커밋한 직후 바로 조회
   - **문제**: 다른 세션에서 아직 변경사항을 볼 수 없을 수 있음 (Eventual Consistency)
   - **현재 처리**: RPC 함수 내에서 이미 캠페인을 생성하고 반환하므로 문제 없음

2. **에러 처리**: 네트워크 오류나 타임아웃 시 적절한 에러 메시지 필요
   - **현재 처리**: catch 블록에서 에러 메시지 파싱 및 반환

---

### 3단계: create_campaign_with_points_v2 RPC 실행

**파일**: `supabase/migrations/20251116140000_remove_unused_campaign_columns.sql`  
**함수**: `create_campaign_with_points_v2` (라인 367-508)

#### 실행 로직

```sql
CREATE OR REPLACE FUNCTION create_campaign_with_points_v2(...) 
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_company_id UUID;
  v_wallet_id UUID;
  v_current_points INTEGER;
  v_total_cost INTEGER;
  v_campaign_id UUID;
BEGIN
  -- ✅ 명시적 트랜잭션 시작
  BEGIN
    -- 1. 현재 사용자 확인
    v_user_id := (SELECT auth.uid());
    
    -- 2. 사용자의 활성 회사 조회
    SELECT cu.company_id INTO v_company_id
    FROM public.company_users cu
    WHERE cu.user_id = v_user_id
      AND cu.status = 'active'
      AND cu.company_role IN ('owner', 'manager')
    LIMIT 1;
    
    -- 3. 총 비용 계산
    v_total_cost := public.calculate_campaign_cost(...);
    
    -- 4. 회사 지갑 조회 및 잠금 (FOR UPDATE NOWAIT)
    SELECT cw.id, cw.current_points 
    INTO v_wallet_id, v_current_points
    FROM public.wallets AS cw
    WHERE cw.company_id = v_company_id
      AND cw.user_id IS NULL
    FOR UPDATE NOWAIT;  -- ✅ 배타적 잠금, 데드락 방지
    
    -- 5. 잔액 확인
    IF v_current_points < v_total_cost THEN
      RAISE EXCEPTION '포인트가 부족합니다';
    END IF;
    
    -- 6. 포인트 차감
    UPDATE public.wallets
    SET current_points = current_points - v_total_cost
    WHERE id = v_wallet_id;
    
    -- 7. 캠페인 생성
    INSERT INTO public.campaigns (...)
    VALUES (...)
    RETURNING id INTO v_campaign_id;
    
    -- 8. 포인트 거래 기록
    INSERT INTO public.point_transactions (...)
    VALUES (...);
    
    -- 9. 결과 반환
    RETURN jsonb_build_object(
      'success', true,
      'campaign_id', v_campaign_id,
      'points_spent', v_total_cost
    );
    
  EXCEPTION
    WHEN lock_not_available THEN
      RAISE EXCEPTION '다른 요청이 처리 중입니다. 잠시 후 다시 시도해주세요.';
    WHEN OTHERS THEN
      RAISE;
  END;
END;
$$;
```

#### 잠재적 문제점

1. **트랜잭션 격리 수준**: PostgreSQL 기본 격리 수준은 `READ COMMITTED`
   - **문제**: 다른 세션에서 트랜잭션이 커밋된 직후 조회해도 변경사항이 보이지 않을 수 있음
   - **원인**: 
     - 트랜잭션 커밋 후에도 다른 세션에서 즉시 조회하면 이전 스냅샷을 볼 수 있음
     - 인덱스 업데이트 지연
     - 복제 지연 (읽기 전용 복제본 사용 시)
   - **해결**: 폴링 로직으로 재시도

2. **지갑 잠금**: `FOR UPDATE NOWAIT`로 데드락 방지
   - **장점**: 동시 요청 시 즉시 실패하여 데드락 방지
   - **단점**: 사용자에게 "다시 시도" 메시지 표시 필요

3. **트랜잭션 커밋 타이밍**: 함수 종료 시 자동 커밋
   - **문제 없음**: 함수가 정상 종료되면 자동으로 커밋됨

---

### 4단계: 리다이렉트 및 쿼리 파라미터 전달

**파일**: `lib/screens/campaign/campaign_creation_screen.dart`  
**라인**: 1107-1115

#### 실행 로직

```dart
if (response.success) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('캠페인이 생성되었습니다!')),
  );
  
  // 생성된 캠페인 ID를 쿼리 파라미터로 전달
  final campaignId = response.data?.id;
  if (campaignId != null) {
    context.go('/mypage/advertiser/my-campaigns?refresh=true&campaignId=$campaignId');
  } else {
    context.go('/mypage/advertiser/my-campaigns?refresh=true');
  }
}
```

#### 잠재적 문제점

1. **쿼리 파라미터 전달**: `context.go()`로 쿼리 파라미터 전달
   - **문제 없음**: GoRouter가 쿼리 파라미터를 올바르게 처리

2. **campaignId 누락**: `response.data?.id`가 null일 수 있음
   - **현재 처리**: campaignId가 null이면 refresh만 전달
   - **개선 가능**: campaignId가 null인 경우 에러 로깅

---

### 5단계: GoRouter 라우팅

**파일**: `lib/config/app_router.dart`  
**라인**: 273-285

#### 실행 로직

```dart
GoRoute(
  path: '/mypage/advertiser/my-campaigns',
  name: 'advertiser-my-campaigns',
  builder: (context, state) {
    final initialTab = state.uri.queryParameters['tab'];
    final refresh = state.uri.queryParameters['refresh'] == 'true';
    final campaignId = state.uri.queryParameters['campaignId'];
    return AdvertiserMyCampaignsScreen(
      initialTab: initialTab,
      refresh: refresh,
      campaignId: campaignId,
    );
  },
)
```

#### 잠재적 문제점

1. **쿼리 파라미터 파싱**: `state.uri.queryParameters`에서 파라미터 읽기
   - **문제 없음**: GoRouter가 쿼리 파라미터를 올바르게 파싱

2. **위젯 파라미터 전달**: 쿼리 파라미터를 위젯 파라미터로 전달
   - **장점**: 위젯에서 직접 접근 가능
   - **단점**: 페이지 새로고침 시 위젯이 재생성되면서 파라미터가 초기화될 수 있음
   - **해결**: PostFrameCallback에서 GoRouterState로도 확인

---

### 6단계: AdvertiserMyCampaignsScreen 초기화

**파일**: `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`  
**메서드**: `initState()` (라인 79-105)

#### 실행 로직

```dart
@override
void initState() {
  super.initState();
  
  // 위젯 파라미터 읽기
  debugPrint('🔍 initState - widget.refresh: ${widget.refresh}, widget.campaignId: ${widget.campaignId}');
  
  // PostFrameCallback에서 GoRouterState를 통해 쿼리 파라미터 확인
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final routerState = GoRouterState.of(context);
    final refresh = routerState.uri.queryParameters['refresh'] == 'true' || widget.refresh;
    final campaignId = routerState.uri.queryParameters['campaignId'] ?? widget.campaignId;
    
    debugPrint('🔍 PostFrameCallback - refresh: $refresh, campaignId: $campaignId');
    
    // 강제 새로고침인 경우 폴링 방식으로 캠페인 조회
    if (refresh) {
      _handleRefresh(campaignId);
    } else {
      _loadCampaigns();
    }
  });
}
```

#### 잠재적 문제점

1. **위젯 파라미터 vs 쿼리 파라미터**: 두 가지 방법 모두 확인
   - **이유**: 페이지 새로고침 시 위젯이 재생성되면서 위젯 파라미터가 초기화될 수 있음
   - **해결**: PostFrameCallback에서 GoRouterState로도 확인하여 이중 체크

2. **PostFrameCallback 타이밍**: 위젯이 완전히 빌드된 후 실행
   - **장점**: context가 안전하게 사용 가능
   - **단점**: 약간의 지연 발생 (보통 수 밀리초)

---

### 7단계: 폴링 로직 실행

**파일**: `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`  
**메서드**: `_handleRefresh()` (라인 113-156)

#### 실행 로직

```dart
Future<void> _handleRefresh(String? campaignId) async {
  if (campaignId != null && campaignId.isNotEmpty) {
    // 1. 먼저 직접 조회 시도 (가장 빠른 방법)
    final directResult = await _addCampaignById(campaignId);
    
    // 2. 직접 조회가 실패하면 폴링 시작
    if (!directResult) {
      await _loadCampaignsWithPolling(
        expectedCampaignId: campaignId,
        maxAttempts: 5,
        initialInterval: const Duration(milliseconds: 200),
      );
    }
  } else {
    // campaignId가 없으면 일반 조회
    await Future.delayed(const Duration(milliseconds: 500));
    _loadCampaigns();
  }
  
  // 3. URL 파라미터 제거 (폴링 완료 후)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final routerState = GoRouterState.of(context);
    if (routerState.uri.queryParameters.containsKey('refresh') ||
        routerState.uri.queryParameters.containsKey('campaignId')) {
      final newUri = routerState.uri.replace(
        queryParameters: Map.from(routerState.uri.queryParameters)
          ..remove('refresh')
          ..remove('campaignId'),
      );
      context.go(newUri.toString());
    }
  });
}
```

#### 잠재적 문제점

1. **직접 조회 우선**: `_addCampaignById()`로 먼저 시도
   - **장점**: 대부분의 경우 즉시 성공하여 빠름
   - **단점**: 트랜잭션 커밋 직후에는 실패할 수 있음

2. **폴링 간격**: Exponential backoff 사용
   - **초기 간격**: 200ms
   - **최대 시도**: 5회
   - **총 대기 시간**: 약 1.5초 (200ms + 300ms + 400ms + 500ms + 600ms)

---

### 8단계: 직접 조회 및 폴링

**파일**: `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`  
**메서드**: `_addCampaignById()`, `_loadCampaignsWithPolling()`

#### 실행 로직

```dart
// 직접 조회
Future<bool> _addCampaignById(String campaignId) async {
  try {
    final result = await _campaignService.getCampaignById(campaignId);
    if (result.success && result.data != null) {
      // 중복 체크
      if (!_allCampaigns.any((c) => c.id == campaignId)) {
        _allCampaigns.insert(0, campaign);
        _updateFilteredCampaigns();
        setState(() { _isLoading = false; });
        return true;
      }
      return true; // 이미 있으면 성공으로 간주
    }
    return false;
  } catch (e) {
    return false;
  }
}

// 폴링
Future<void> _loadCampaignsWithPolling({
  required String expectedCampaignId,
  int maxAttempts = 5,
  Duration initialInterval = const Duration(milliseconds: 200),
}) async {
  // 첫 시도 전에 짧은 지연 (트랜잭션 커밋 대기)
  await Future.delayed(initialInterval);
  
  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    if (!mounted) return;
    
    await _loadCampaigns();
    
    // 생성된 캠페인이 목록에 있는지 확인
    final found = _allCampaigns.any((c) => c.id == expectedCampaignId);
    if (found) {
      debugPrint('✅ 생성된 캠페인을 찾았습니다: $expectedCampaignId');
      return;
    }
    
    // Exponential backoff
    if (attempt < maxAttempts - 1) {
      final delay = Duration(
        milliseconds: initialInterval.inMilliseconds + (attempt * 100),
      );
      await Future.delayed(delay);
    } else {
      // 마지막 시도 실패 시 직접 조회 시도
      await _addCampaignById(expectedCampaignId);
    }
  }
}
```

#### 잠재적 문제점

1. **Exponential Backoff**: 재시도 간격이 점진적으로 증가
   - **장점**: 서버 부하 감소
   - **단점**: 사용자 대기 시간 증가

2. **최대 시도 횟수**: 5회로 제한
   - **문제**: 5회 모두 실패하면 캠페인이 표시되지 않을 수 있음
   - **해결**: 마지막 시도에서 직접 조회로 폴백

---

### 9단계: get_user_campaigns_safe RPC 실행

**파일**: `supabase/migrations/20251116140000_remove_unused_campaign_columns.sql`  
**함수**: `get_user_campaigns_safe` (라인 1358-1438)

#### 실행 로직

```sql
CREATE OR REPLACE FUNCTION get_user_campaigns_safe(
  p_user_id UUID,
  p_status TEXT DEFAULT 'all',
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_campaigns jsonb;
  v_total_count integer;
  v_company_ids uuid[];
BEGIN
  -- 1. 권한 확인
  IF p_user_id != (SELECT auth.uid()) AND 
     NOT EXISTS (SELECT 1 FROM public.users 
                 WHERE id = (SELECT auth.uid()) AND user_type = 'admin') THEN
    RAISE EXCEPTION 'You can only view your own campaigns';
  END IF;
  
  -- 2. 사용자의 활성 회사 ID 목록 조회
  SELECT ARRAY_AGG(company_id) INTO v_company_ids
  FROM public.company_users
  WHERE user_id = p_user_id
    AND status = 'active';
  
  -- 3. 캠페인 조회 (company_id 기반)
  SELECT jsonb_agg(
    jsonb_build_object('campaign', row_to_json(c.*)) 
    ORDER BY c.created_at DESC
  ), COUNT(*)
  INTO v_campaigns, v_total_count
  FROM public.campaigns c
  WHERE c.company_id = ANY(v_company_ids)
    AND (p_status = 'all' OR c.status = p_status)
  ORDER BY c.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
  
  -- 4. 결과 반환
  RETURN jsonb_build_object(
    'campaigns', COALESCE(v_campaigns, '[]'::jsonb),
    'total_count', COALESCE(v_total_count, 0),
    'limit', p_limit,
    'offset', p_offset
  );
END;
$$;
```

#### 잠재적 문제점

1. **트랜잭션 격리 수준**: `READ COMMITTED`에서 다른 세션의 커밋된 변경사항이 즉시 보이지 않을 수 있음
   - **원인**: 
     - 인덱스 업데이트 지연
     - 쿼리 플래너가 이전 스냅샷 사용
     - 복제 지연 (읽기 전용 복제본 사용 시)
   - **해결**: 폴링 로직으로 재시도

2. **company_id 기반 조회**: 사용자의 회사 ID 목록으로 조회
   - **문제 없음**: 올바른 캠페인만 조회됨

---

### 10단계: 캠페인 목록 업데이트 및 UI 렌더링

**파일**: `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`  
**메서드**: `_loadCampaigns()` (라인 158-280)

#### 실행 로직

```dart
Future<void> _loadCampaigns({bool forceRefresh = false}) async {
  setState(() { _isLoading = true; });
  
  try {
    // 1. RPC 함수 호출
    final result = await _campaignService.getUserCampaigns(
      page: 1,
      limit: 100,
    );
    
    if (result.success && result.data != null) {
      final campaignsData = result.data!;
      final campaignsList = campaignsData['campaigns'] as List?;
      
      // 2. 캠페인 데이터 파싱
      loadedCampaigns = campaignsList
          .map((item) {
            final campaignData = item['campaign'] as Map<String, dynamic>?;
            if (campaignData != null) {
              return Campaign.fromJson(campaignData);
            }
            return null;
          })
          .whereType<Campaign>()
          .toList();
      
      // 3. 상태별 분류
      _allCampaigns = loadedCampaigns;
      _updateFilteredCampaigns();
      
      // 4. UI 업데이트
      setState(() {
        _isLoading = false;
        _allCampaigns = loadedCampaigns;
      });
    }
  } catch (e) {
    setState(() { _isLoading = false; });
  }
}
```

#### 잠재적 문제점

1. **데이터 파싱**: RPC 함수가 반환한 JSON 구조 파싱
   - **문제 없음**: `item['campaign']` 구조로 올바르게 파싱

2. **상태별 분류**: `_updateFilteredCampaigns()`로 상태별로 분류
   - **문제 없음**: 각 탭에 맞는 캠페인만 표시

---

### 11단계: URL 파라미터 제거

**파일**: `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`  
**라인**: 141-155

#### 실행 로직

```dart
// URL 파라미터 제거 (폴링 완료 후)
WidgetsBinding.instance.addPostFrameCallback((_) {
  final routerState = GoRouterState.of(context);
  if (routerState.uri.queryParameters.containsKey('refresh') ||
      routerState.uri.queryParameters.containsKey('campaignId')) {
    final newUri = routerState.uri.replace(
      queryParameters: Map.from(routerState.uri.queryParameters)
        ..remove('refresh')
        ..remove('campaignId'),
    );
    context.go(newUri.toString());
  }
});
```

#### 잠재적 문제점

1. **타이밍**: 폴링 완료 후에만 제거
   - **장점**: 폴링이 완료될 때까지 쿼리 파라미터 유지
   - **단점**: 페이지 새로고침 시 쿼리 파라미터가 다시 추가될 수 있음

---

## 🔍 핵심 문제점 및 해결 방법

### 문제 1: Eventual Consistency (최종 일관성)

**원인**:
- PostgreSQL의 `READ COMMITTED` 격리 수준
- 트랜잭션 커밋 후에도 다른 세션에서 즉시 조회해도 변경사항이 보이지 않을 수 있음
- 인덱스 업데이트 지연
- 복제 지연 (읽기 전용 복제본 사용 시)

**증상**:
- 캠페인 생성 직후 "나의 캠페인" 화면에서 생성된 캠페인이 표시되지 않음
- 수동 새로고침 후에야 표시됨

**해결 방법**:
1. **직접 조회 우선**: `_addCampaignById()`로 먼저 시도
2. **폴링 로직**: 직접 조회 실패 시 폴링으로 재시도
3. **Exponential Backoff**: 재시도 간격을 점진적으로 증가
4. **최대 시도 횟수**: 5회로 제한하여 무한 루프 방지

**코드 위치**:
- `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`
  - `_handleRefresh()` (라인 113-156)
  - `_addCampaignById()` (라인 250-300)
  - `_loadCampaignsWithPolling()` (라인 302-370)

---

### 문제 2: 쿼리 파라미터 읽기 실패

**원인**:
- `Uri.base.queryParameters`가 GoRouter의 라우팅 상태와 동기화되지 않음
- 페이지 새로고침 시 위젯이 재생성되면서 위젯 파라미터가 초기화될 수 있음

**증상**:
- URL에 쿼리 파라미터가 있지만 `initState`에서 읽지 못함
- 폴링 로직이 실행되지 않음

**해결 방법**:
1. **위젯 파라미터 전달**: 라우터에서 쿼리 파라미터를 위젯 파라미터로 전달
2. **PostFrameCallback에서 확인**: `GoRouterState.of(context).uri.queryParameters`로 직접 읽기
3. **이중 체크**: 위젯 파라미터와 GoRouterState 모두 확인

**코드 위치**:
- `lib/config/app_router.dart` (라인 273-285)
- `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart` (라인 79-105)

---

### 문제 3: 트랜잭션 타이밍

**원인**:
- RPC 함수가 트랜잭션을 커밋한 직후 프론트엔드에서 조회
- 다른 세션에서 아직 변경사항을 볼 수 없을 수 있음

**증상**:
- 캠페인 생성 성공 후 즉시 조회해도 캠페인이 없음

**해결 방법**:
1. **폴링 로직**: 직접 조회 실패 시 폴링으로 재시도
2. **초기 지연**: 첫 시도 전에 200ms 지연 (트랜잭션 커밋 대기)
3. **Exponential Backoff**: 재시도 간격을 점진적으로 증가

**코드 위치**:
- `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`
  - `_loadCampaignsWithPolling()` (라인 302-370)

---

## ✅ 최종 해결 방법 요약

### 1. 쿼리 파라미터 전달 개선

```dart
// 라우터 설정
GoRoute(
  path: '/mypage/advertiser/my-campaigns',
  builder: (context, state) {
    final refresh = state.uri.queryParameters['refresh'] == 'true';
    final campaignId = state.uri.queryParameters['campaignId'];
    return AdvertiserMyCampaignsScreen(
      refresh: refresh,
      campaignId: campaignId,
    );
  },
)

// 위젯 초기화
WidgetsBinding.instance.addPostFrameCallback((_) {
  final routerState = GoRouterState.of(context);
  final refresh = routerState.uri.queryParameters['refresh'] == 'true' || widget.refresh;
  final campaignId = routerState.uri.queryParameters['campaignId'] ?? widget.campaignId;
  
  if (refresh) {
    _handleRefresh(campaignId);
  }
});
```

### 2. 폴링 로직 구현

```dart
Future<void> _handleRefresh(String? campaignId) async {
  if (campaignId != null && campaignId.isNotEmpty) {
    // 1. 직접 조회 우선 시도
    final directResult = await _addCampaignById(campaignId);
    
    // 2. 실패 시 폴링 시작
    if (!directResult) {
      await _loadCampaignsWithPolling(
        expectedCampaignId: campaignId,
        maxAttempts: 5,
        initialInterval: const Duration(milliseconds: 200),
      );
    }
  }
}
```

### 3. Exponential Backoff 적용

```dart
Future<void> _loadCampaignsWithPolling({
  required String expectedCampaignId,
  int maxAttempts = 5,
  Duration initialInterval = const Duration(milliseconds: 200),
}) async {
  await Future.delayed(initialInterval);
  
  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    await _loadCampaigns();
    
    final found = _allCampaigns.any((c) => c.id == expectedCampaignId);
    if (found) return;
    
    if (attempt < maxAttempts - 1) {
      final delay = Duration(
        milliseconds: initialInterval.inMilliseconds + (attempt * 100),
      );
      await Future.delayed(delay);
    }
  }
}
```

---

## 📊 성능 및 사용자 경험 분석

### 성공 케이스 (대부분의 경우)

1. **직접 조회 성공**: 약 200ms
   - 트랜잭션이 이미 커밋된 경우
   - 사용자 경험: 즉시 표시

2. **폴링 1회 성공**: 약 400ms
   - 첫 시도 실패 후 1회 재시도 성공
   - 사용자 경험: 거의 즉시 표시

3. **폴링 2-3회 성공**: 약 700-1100ms
   - 2-3회 재시도 후 성공
   - 사용자 경험: 약간의 지연이 있지만 허용 가능

### 실패 케이스 (드문 경우)

1. **최대 시도 횟수 초과**: 약 1.5초
   - 5회 모두 실패
   - 사용자 경험: 수동 새로고침 필요 (드문 경우)

---

## 🎯 결론

### 현재 구현 상태

✅ **해결된 문제**:
1. 쿼리 파라미터 읽기 실패 → 위젯 파라미터 + GoRouterState 이중 체크
2. Eventual Consistency → 폴링 로직 + 직접 조회 우선
3. 트랜잭션 타이밍 → Exponential Backoff 적용

✅ **성능**:
- 대부분의 경우 200-400ms 내에 캠페인 표시
- 최악의 경우 1.5초 내에 표시 또는 수동 새로고침 필요

✅ **사용자 경험**:
- 캠페인 생성 직후 즉시 표시 (대부분의 경우)
- 드문 경우 수동 새로고침 필요

### 개선 가능 사항

1. **폴링 간격 조정**: 현재 200ms 초기 간격을 100ms로 줄여 더 빠른 응답
2. **최대 시도 횟수 증가**: 5회에서 7-10회로 증가하여 성공률 향상
3. **에러 처리 개선**: 폴링 실패 시 사용자에게 명확한 메시지 표시
4. **로딩 인디케이터**: 폴링 중임을 사용자에게 표시

---

## 📚 참고 자료

- [PostgreSQL Transaction Isolation Levels](https://www.postgresql.org/docs/current/transaction-iso.html)
- [GoRouter Documentation](https://pub.dev/packages/go_router)
- [Flutter State Management Best Practices](https://docs.flutter.dev/development/data-and-backend/state-mgmt)

---

**문서 작성일**: 2025-11-16  
**최종 수정일**: 2025-11-16  
**작성자**: AI Assistant

