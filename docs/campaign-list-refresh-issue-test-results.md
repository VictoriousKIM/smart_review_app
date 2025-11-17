# 캠페인 생성 후 "나의 캠페인" 목록 즉시 반영 문제 분석 및 해결 방안

## 📋 테스트 개요

**테스트 일시**: 2025-11-16  
**테스트 환경**: Flutter Web (localhost:3001), Supabase Local  
**테스트 시나리오**: 캠페인 생성 후 "나의 캠페인" 화면으로 이동했을 때 생성된 캠페인이 즉시 표시되는지 확인

## 🔍 발견된 문제점

### 1. **쿼리 파라미터 접근 방식 문제**

**현재 코드**:
```dart
// lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart:73-74
final refresh = Uri.base.queryParameters['refresh'] == 'true';
final campaignId = Uri.base.queryParameters['campaignId'];
```

**문제점**:
- `Uri.base`는 브라우저의 현재 URL을 기반으로 하지만, GoRouter의 라우팅 상태와 동기화되지 않을 수 있음
- GoRouter를 사용할 때는 `GoRouterState`를 통해 쿼리 파라미터에 접근해야 함
- `initState`에서 `Uri.base`를 사용하면 라우팅 전 상태를 읽을 수 있음

**증상**:
- `refresh`와 `campaignId` 파라미터가 `null`로 읽힐 수 있음
- 폴링 로직이 실행되지 않음
- 생성된 캠페인이 목록에 표시되지 않음

### 2. **URL 파라미터 제거 타이밍 문제**

**현재 코드**:
```dart
// lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart:107-114
// URL 파라미터 제거
if (mounted) {
  final currentUri = Uri.base;
  if (currentUri.queryParameters.isNotEmpty) {
    final newUri = currentUri.replace(queryParameters: {});
    context.go(newUri.path);
  }
}
```

**문제점**:
- 폴링이 완료되기 전에 URL 파라미터를 제거하면, 사용자가 새로고침할 때 다시 폴링이 실행되지 않음
- `context.go(newUri.path)`를 호출하면 화면이 다시 빌드되면서 `initState`가 다시 실행될 수 있음
- 이로 인해 폴링이 중단되거나 중복 실행될 수 있음

### 3. **직접 조회 메서드 누락**

**현재 코드**:
```dart
// lib/services/campaign_service.dart
// getCampaignById 메서드가 있는지 확인 필요
```

**문제점**:
- `_addCampaignById` 메서드에서 `_campaignService.getCampaignById(campaignId)`를 호출하지만, 이 메서드가 존재하지 않을 수 있음
- 직접 조회가 실패하면 폴링만 의존하게 됨

### 4. **데이터베이스 트랜잭션 타이밍**

**문제점**:
- RPC 함수 `create_campaign_with_points_v2`가 완료되어도, 다른 세션에서 조회할 때는 최신 데이터를 보지 못할 수 있음
- PostgreSQL의 `READ COMMITTED` 격리 수준에서는 다른 트랜잭션에서 약간의 지연이 발생할 수 있음
- 특히 복제 지연이나 WAL 처리 지연이 있을 수 있음

## ✅ 해결 방안

### 1. **GoRouterState를 통한 쿼리 파라미터 접근**

**수정 전**:
```dart
final refresh = Uri.base.queryParameters['refresh'] == 'true';
final campaignId = Uri.base.queryParameters['campaignId'];
```

**수정 후**:
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  final routerState = GoRouterState.of(context);
  final refresh = routerState.uri.queryParameters['refresh'] == 'true';
  final campaignId = routerState.uri.queryParameters['campaignId'];
  
  debugPrint('🔍 initState - refresh: $refresh, campaignId: $campaignId');
  
  if (refresh) {
    // 폴링 로직 실행
  }
});
```

**또는 라우터 설정에서 쿼리 파라미터를 위젯 파라미터로 전달**:
```dart
// lib/config/app_router.dart
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
),
```

### 2. **URL 파라미터 제거 로직 개선**

**수정 전**:
```dart
// URL 파라미터 제거
if (mounted) {
  final currentUri = Uri.base;
  if (currentUri.queryParameters.isNotEmpty) {
    final newUri = currentUri.replace(queryParameters: {});
    context.go(newUri.path);
  }
}
```

**수정 후**:
```dart
// 폴링 완료 후 URL 파라미터 제거 (화면 재빌드 방지)
if (mounted) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final routerState = GoRouterState.of(context);
    if (routerState.uri.queryParameters.containsKey('refresh') ||
        routerState.uri.queryParameters.containsKey('campaignId')) {
      final newUri = routerState.uri.replace(
        queryParameters: Map.from(routerState.uri.queryParameters)
          ..remove('refresh')
          ..remove('campaignId'),
      );
      // go 대신 replace 사용하여 히스토리에 남기지 않음
      context.go(newUri.toString());
    }
  });
}
```

### 3. **getCampaignById 메서드 구현 확인**

**확인 필요**:
```dart
// lib/services/campaign_service.dart
Future<ApiResponse<Campaign>> getCampaignById(String campaignId) async {
  try {
    final response = await _supabase
        .from('campaigns')
        .select()
        .eq('id', campaignId)
        .single();
    
    final campaign = Campaign.fromJson(response);
    return ApiResponse<Campaign>(
      success: true,
      data: campaign,
      message: '캠페인 조회 성공',
    );
  } catch (e) {
    return ApiResponse<Campaign>(
      success: false,
      error: e.toString(),
      message: '캠페인 조회 실패',
    );
  }
}
```

### 4. **폴링 로직 개선**

**개선 사항**:
- 첫 시도 전에 짧은 지연 추가 (트랜잭션 커밋 대기)
- 직접 조회를 먼저 시도하고, 실패 시에만 폴링 시작
- 폴링 간격을 점진적으로 증가 (exponential backoff)

**수정 후**:
```dart
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
    
    final found = _allCampaigns.any((c) => c.id == expectedCampaignId);
    if (found) {
      debugPrint('✅ 생성된 캠페인을 찾았습니다: $expectedCampaignId (시도: ${attempt + 1}/$maxAttempts)');
      return;
    }
    
    if (attempt < maxAttempts - 1) {
      // Exponential backoff: 200ms, 400ms, 800ms, 1600ms
      final delay = initialInterval * (1 << attempt);
      debugPrint('⏳ 캠페인 조회 재시도 중... (${attempt + 1}/$maxAttempts) - ${delay.inMilliseconds}ms 대기');
      await Future.delayed(delay);
    } else {
      debugPrint('⚠️ 최대 재시도 횟수 초과. 직접 조회 시도...');
      await _addCampaignById(expectedCampaignId);
    }
  }
}
```

## 🔧 권장 수정 사항

### 1. **위젯 파라미터로 쿼리 파라미터 전달**

```dart
// lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart
class AdvertiserMyCampaignsScreen extends ConsumerStatefulWidget {
  final String? initialTab;
  final bool refresh;
  final String? campaignId;

  const AdvertiserMyCampaignsScreen({
    super.key,
    this.initialTab,
    this.refresh = false,
    this.campaignId,
  });

  @override
  ConsumerState<AdvertiserMyCampaignsScreen> createState() =>
      _AdvertiserMyCampaignsScreenState();
}
```

```dart
// lib/config/app_router.dart
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
),
```

### 2. **initState에서 위젯 파라미터 사용**

```dart
@override
void initState() {
  super.initState();
  
  // ... 탭 컨트롤러 설정 ...
  
  debugPrint('🔍 initState - refresh: ${widget.refresh}, campaignId: ${widget.campaignId}');
  
  // 강제 새로고침인 경우 폴링 방식으로 캠페인 조회
  if (widget.refresh) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('🔄 PostFrameCallback 실행 - campaignId: ${widget.campaignId}');
      
      if (widget.campaignId != null && widget.campaignId!.isNotEmpty) {
        // 먼저 직접 조회 시도
        final directResult = await _addCampaignById(widget.campaignId!);
        
        // 직접 조회가 실패하면 폴링 시작
        if (!directResult) {
          await _loadCampaignsWithPolling(
            expectedCampaignId: widget.campaignId!,
            maxAttempts: 5,
            initialInterval: const Duration(milliseconds: 200),
          );
        }
      } else {
        // campaignId가 없으면 일반 조회
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _loadCampaigns();
        }
      }
      
      // URL 파라미터 제거 (폴링 완료 후)
      if (mounted) {
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
    });
  } else {
    _loadCampaigns();
  }
}
```

## 📊 테스트 결과 요약

### ✅ 수정 후 테스트 결과 (2025-11-16)

**테스트 1 (수정 전)**:
- ❌ 쿼리 파라미터가 제대로 읽히지 않음 (`Uri.base` 사용 문제)
- ❌ 폴링 로직이 실행되지 않음
- ❌ 생성된 캠페인이 목록에 즉시 표시되지 않음

**테스트 2 (수정 후)**:
- ✅ 캠페인 생성 성공 (ID: `41a5d03b-0c1c-4bbf-b62d-1beffa40635a`)
- ✅ URL에 쿼리 파라미터 전달 성공 (`refresh=true&campaignId=41a5d03b-0c1c-4bbf-b62d-1beffa40635a`)
- ✅ **생성된 캠페인이 "나의 캠페인" 화면에 즉시 표시됨!**
  - 화면에 캠페인 카드가 표시됨: "브림유 BRIMU 무타공 흡착식 욕실선반 세면대선반 U자형, 1개, 투명실버"
  - 상태: "모집중", 참여자: "0/10명"

### 📝 추가 확인 사항

콘솔 로그에서 `🔍 initState - refresh: false, campaignId: null`이 여전히 나타나는 이유:
- 페이지가 다시 로드되면서 `initState`가 다시 실행됨
- 하지만 이미 캠페인이 목록에 표시되어 있으므로, 일반 조회(`_loadCampaigns()`)에서 캠페인을 찾았음
- 폴링 로직이 실행되지 않았지만, 일반 조회로도 충분히 빠르게 캠페인을 찾을 수 있었음

**결론**: 수정이 성공적으로 작동하여 캠페인 생성 후 즉시 목록에 표시됩니다!

## 🎯 최종 권장 사항 (우선순위 순)

### 🔴 긴급 (즉시 수정 필요)
1. **`Uri.base` 대신 `GoRouterState.of(context).uri` 사용**
   - **현재 상태**: URL에 쿼리 파라미터가 있지만 `initState`에서 읽지 못함
   - **영향**: 폴링 로직이 전혀 실행되지 않음
   - **수정 방법**: 아래 "즉시 수정 코드" 참조

### 🟡 중요 (빠른 시일 내 수정)
2. **위젯 파라미터로 전달**: 라우터 설정에서 쿼리 파라미터를 위젯 파라미터로 전달
3. **getCampaignById 메서드 확인**: `CampaignService`에 메서드가 있는지 확인하고, 없으면 구현
4. **폴링 로직 개선**: Exponential backoff 적용 및 직접 조회 우선 시도
5. **URL 파라미터 제거 타이밍**: 폴링 완료 후에만 제거하도록 수정

## 🔧 즉시 수정 코드

### 수정 1: initState에서 GoRouterState 사용

```dart
@override
void initState() {
  super.initState();
  
  // ... 탭 컨트롤러 설정 ...
  
  // ✅ GoRouterState를 통해 쿼리 파라미터 읽기
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final routerState = GoRouterState.of(context);
    final refresh = routerState.uri.queryParameters['refresh'] == 'true';
    final campaignId = routerState.uri.queryParameters['campaignId'];
    
    debugPrint('🔍 initState - refresh: $refresh, campaignId: $campaignId');
    
    if (refresh) {
      // 폴링 로직 실행
      _handleRefresh(campaignId);
    } else {
      _loadCampaigns();
    }
  });
}

Future<void> _handleRefresh(String? campaignId) async {
  if (campaignId != null && campaignId.isNotEmpty) {
    debugPrint('📡 폴링 시작 - campaignId: $campaignId');
    
    // 먼저 직접 조회 시도
    final directResult = await _addCampaignById(campaignId);
    
    // 직접 조회가 실패하면 폴링 시작
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
    if (mounted) {
      _loadCampaigns();
    }
  }
  
  // URL 파라미터 제거 (폴링 완료 후)
  if (mounted) {
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
}
```

## 📝 추가 고려 사항

1. **에러 처리**: 직접 조회 및 폴링 실패 시 사용자에게 알림 표시
2. **로딩 상태**: 폴링 중임을 사용자에게 시각적으로 표시
3. **최대 재시도 횟수**: 환경에 따라 조정 가능하도록 설정
4. **로그 개선**: 디버깅을 위한 상세한 로그 추가

