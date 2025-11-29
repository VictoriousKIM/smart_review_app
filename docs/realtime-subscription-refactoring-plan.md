# Realtime 구독 통합 리팩토링 계획서

**작성일**: 2025년 11월 29일  
**목적**: Realtime 구독 관리의 파편화 해소 및 중앙화된 싱글톤 패턴 적용

---

## 📋 현재 상태 분석

### 1. 현재 아키텍처

**구조**:
```
각 화면 (Home, Campaigns, CampaignDetail, AdvertiserMyCampaigns)
  └─ CampaignRealtimeService (개별 인스턴스)
      └─ Supabase RealtimeChannel
```

**문제점**:
- 각 화면에서 개별적으로 `CampaignRealtimeService` 인스턴스 생성
- 구독 상태 추적 어려움
- 중복 구독 가능성
- 생명주기 이벤트 처리 불일치
- 코드 중복

### 2. 현재 사용 현황

**사용 중인 화면**:
1. `lib/screens/home/home_screen.dart`
   - screenId: `'home'`
   - activeOnly: `true`
   - companyId: 없음

2. `lib/screens/campaign/campaigns_screen.dart`
   - screenId: `'campaigns'`
   - activeOnly: `true`
   - companyId: 없음

3. `lib/screens/campaign/campaign_detail_screen.dart`
   - screenId: `'campaign_detail_{campaignId}'`
   - campaignId: 특정 캠페인 ID
   - activeOnly: `true`

4. `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`
   - screenId: `'advertiser_my_campaigns'`
   - companyId: 사용자의 회사 ID
   - activeOnly: `false` (모든 상태의 캠페인)

### 3. 현재 문제점

#### 문제 1: 중복 구독 가능성

**현재 코드**:
```dart
// 각 화면에서 개별적으로 인스턴스 생성
_realtimeService = CampaignRealtimeService();
_realtimeSubscription = _realtimeService!.subscribeToCampaigns(...).listen(...);
```

**문제**:
- 동일한 화면에서 여러 번 `_initRealtimeSubscription()` 호출 시 중복 구독 가능
- `didChangeAppLifecycleState` 반복 호출 시 중복 구독 가능

#### 문제 2: 생명주기 이벤트 처리 불일치

**현재 코드**:
```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
    _realtimeService?.unsubscribe();
  } else if (state == AppLifecycleState.resumed) {
    _initRealtimeSubscription(); // 구독 상태 확인 없이 재구독
  }
}
```

**문제**:
- 웹 환경에서 탭 전환 시에도 생명주기 이벤트 발생
- 구독 상태 확인 없이 재구독 시도
- 반복적인 구독 시작/해제로 이그레스 비용 발생

#### 문제 3: 구독 상태 추적 어려움

**현재 코드**:
- 각 화면에서 개별적으로 구독 상태 관리
- 전역 구독 상태 확인 불가능
- 디버깅 어려움

---

## 🎯 목표 아키텍처

### 1. 중앙화된 싱글톤 패턴

**구조**:
```
각 화면 (Home, Campaigns, CampaignDetail, AdvertiserMyCampaigns)
  └─ CampaignRealtimeManager (싱글톤)
      └─ CampaignRealtimeService (내부적으로 관리)
          └─ Supabase RealtimeChannel
```

**장점**:
- 중앙에서 모든 구독 관리
- 구독 상태 추적 용이
- 중복 구독 방지
- 일관된 생명주기 이벤트 처리

### 2. 계층 구조

```
CampaignRealtimeManager (싱글톤, 공개 API)
  ├─ 구독 관리 (subscribe, unsubscribe, isSubscribed)
  ├─ 생명주기 이벤트 처리 (handleAppLifecycleState)
  └─ CampaignRealtimeService (내부 구현, Manager가 관리)
      ├─ Supabase RealtimeChannel
      ├─ 이벤트 필터링
      └─ 비활성 타임아웃
```

---

## 🏗️ 설계 상세

### 1. CampaignRealtimeManager (싱글톤)

**역할**:
- 모든 Realtime 구독을 중앙에서 관리
- 화면별 구독 상태 추적
- 중복 구독 방지
- 생명주기 이벤트 중앙 처리

**주요 메서드**:
- `subscribe()`: 구독 시작 (중복 방지)
- `unsubscribe()`: 구독 해제
- `unsubscribeAll()`: 모든 구독 해제
- `isSubscribed()`: 구독 상태 확인
- `handleAppLifecycleState()`: 생명주기 이벤트 처리
- `getActiveSubscriptions()`: 활성 구독 목록 조회

### 2. CampaignRealtimeService (내부 구현)

**역할**:
- Supabase RealtimeChannel 관리
- 이벤트 필터링 (companyId, activeOnly)
- 비활성 타임아웃 관리
- 이벤트 스트림 제공

**변경사항**:
- Manager가 Service 인스턴스를 생성하고 관리
- 화면에서 직접 Service 인스턴스 생성하지 않음

---

## 📝 구현 계획

### Phase 1: CampaignRealtimeManager 구현

**파일**: `lib/services/campaign_realtime_manager.dart`

**구현 내용**:
1. 싱글톤 패턴 구현
2. 화면별 구독 추적 (`Map<String, CampaignRealtimeService>`)
3. 구독 관리 메서드 구현
4. 생명주기 이벤트 처리 메서드 구현
5. 중복 구독 방지 로직

**주요 코드**:
```dart
class CampaignRealtimeManager {
  static final CampaignRealtimeManager _instance = CampaignRealtimeManager._internal();
  factory CampaignRealtimeManager() => _instance;
  CampaignRealtimeManager._internal();

  // 화면별 구독 추적
  final Map<String, _SubscriptionInfo> _subscriptions = {};
  
  // 생명주기 이벤트 처리
  bool _isAppInBackground = false;
  Timer? _lifecycleDebounceTimer;

  /// 구독 시작 (중복 방지)
  bool subscribe({
    required String screenId,
    required void Function(CampaignRealtimeEvent) onEvent,
    String? companyId,
    String? campaignId,
    bool activeOnly = true,
    void Function(Object)? onError,
  }) {
    // 이미 구독 중이면 재구독하지 않음
    if (_subscriptions.containsKey(screenId)) {
      final info = _subscriptions[screenId]!;
      if (info.service.isConnected()) {
        debugPrint('ℹ️ 이미 구독 중입니다: $screenId');
        return false;
      } else {
        // 구독은 있지만 연결이 끊어진 경우 정리 후 재구독
        _unsubscribeInternal(screenId);
      }
    }

    try {
      // 새 구독 시작
      final service = CampaignRealtimeService();
      final stream = service.subscribeToCampaigns(
        screenId: screenId,
        companyId: companyId,
        campaignId: campaignId,
        activeOnly: activeOnly,
      );

      final subscription = stream.listen(
        onEvent,
        onError: onError ?? (error) {
          debugPrint('❌ Realtime 구독 에러 ($screenId): $error');
        },
      );

      // 구독 정보 저장
      _subscriptions[screenId] = _SubscriptionInfo(
        service: service,
        subscription: subscription,
        screenId: screenId,
        companyId: companyId,
        campaignId: campaignId,
        activeOnly: activeOnly,
      );

      debugPrint('✅ Realtime 구독 시작: $screenId');
      return true;
    } catch (e) {
      debugPrint('❌ Realtime 구독 실패 ($screenId): $e');
      return false;
    }
  }

  /// 구독 해제
  void unsubscribe(String screenId) {
    _unsubscribeInternal(screenId);
  }

  /// 내부 구독 해제 메서드
  void _unsubscribeInternal(String screenId) {
    final info = _subscriptions[screenId];
    if (info == null) return;

    info.service.unsubscribe();
    info.subscription.cancel();
    _subscriptions.remove(screenId);

    debugPrint('🔌 Realtime 구독 해제: $screenId');
  }

  /// 모든 구독 해제
  void unsubscribeAll() {
    debugPrint('🔌 모든 Realtime 구독 해제: ${_subscriptions.length}개');
    final screenIds = _subscriptions.keys.toList();
    for (final screenId in screenIds) {
      _unsubscribeInternal(screenId);
    }
  }

  /// 구독 상태 확인
  bool isSubscribed(String screenId) {
    final info = _subscriptions[screenId];
    return info != null && info.service.isConnected();
  }

  /// 앱 생명주기 이벤트 처리
  void handleAppLifecycleState(AppLifecycleState state) {
    // 웹 환경에서는 생명주기 이벤트 무시
    if (kIsWeb) {
      return;
    }

    // 디바운싱: 500ms 이내의 연속된 이벤트는 무시
    _lifecycleDebounceTimer?.cancel();
    _lifecycleDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        if (!_isAppInBackground) {
          _isAppInBackground = true;
          debugPrint('📱 앱이 백그라운드로 전환됨. 모든 Realtime 구독 해제');
          unsubscribeAll();
        }
      } else if (state == AppLifecycleState.resumed) {
        if (_isAppInBackground) {
          _isAppInBackground = false;
          debugPrint('📱 앱이 포그라운드로 전환됨. 구독 재시작 가능');
        }
      }
    });
  }

  /// 활성 구독 목록 조회
  List<String> getActiveSubscriptions() {
    return _subscriptions.keys.toList();
  }

  /// 정리
  void dispose() {
    _lifecycleDebounceTimer?.cancel();
    unsubscribeAll();
  }
}

/// 구독 정보 클래스
class _SubscriptionInfo {
  final CampaignRealtimeService service;
  final StreamSubscription<CampaignRealtimeEvent> subscription;
  final String screenId;
  final String? companyId;
  final String? campaignId;
  final bool activeOnly;

  _SubscriptionInfo({
    required this.service,
    required this.subscription,
    required this.screenId,
    this.companyId,
    this.campaignId,
    required this.activeOnly,
  });
}
```

### Phase 2: 화면별 마이그레이션

**마이그레이션 순서 (권장)**:
1. 홈 화면 (가장 단순)
2. 캠페인 목록 화면
3. 캠페인 상세 화면
4. 광고주 마이캠페인 화면 (가장 복잡)

**이유**: 단순한 화면부터 검증 후 복잡한 화면으로 진행

#### 2.1 홈 화면

**파일**: `lib/screens/mypage/advertiser/advertiser_my_campaigns_screen.dart`

**변경 전**:
```dart
class _AdvertiserMyCampaignsScreenState extends ConsumerState<AdvertiserMyCampaignsScreen>
    with WidgetsBindingObserver {
  CampaignRealtimeService? _realtimeService;
  StreamSubscription<CampaignRealtimeEvent>? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initRealtimeSubscription();
  }

  Future<void> _initRealtimeSubscription() async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) return;

      final companyId = await CompanyUserService.getUserCompanyId(user.id);
      if (companyId == null) return;

      _realtimeService = CampaignRealtimeService();
      _realtimeSubscription = _realtimeService!
          .subscribeToCampaigns(
            screenId: 'advertiser_my_campaigns',
            companyId: companyId,
            activeOnly: false,
          )
          .listen(_handleRealtimeUpdate);
    } catch (e) {
      debugPrint('❌ Realtime 구독 초기화 실패: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _realtimeService?.unsubscribe();
    } else if (state == AppLifecycleState.resumed) {
      _initRealtimeSubscription();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeSubscription?.cancel();
    _realtimeService?.unsubscribe();
    super.dispose();
  }
}
```

**변경 후**:
```dart
class _AdvertiserMyCampaignsScreenState extends ConsumerState<AdvertiserMyCampaignsScreen> {
  // WidgetsBindingObserver 제거 (앱 레벨에서 처리)
  final _realtimeManager = CampaignRealtimeManager.instance; // instance getter 사용
  static const String _screenId = 'advertiser_my_campaigns';

  @override
  void initState() {
    super.initState();
    _initRealtimeSubscription();
  }

  Future<void> _initRealtimeSubscription() async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) return;

      final companyId = await CompanyUserService.getUserCompanyId(user.id);
      if (companyId == null) {
        debugPrint('⚠️ 회사 ID를 찾을 수 없어 Realtime 구독을 시작하지 않습니다.');
        return;
      }

      // 중앙 관리자를 통해 구독 (중복 방지, 재시도 포함)
      await _realtimeManager.subscribeWithRetry(
        screenId: _screenId,
        companyId: companyId,
        activeOnly: false,
        onEvent: _handleRealtimeUpdate,
        onError: (error) {
          debugPrint('❌ Realtime 구독 에러: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Realtime 구독 초기화 실패: $e');
    }
  }

  // didChangeAppLifecycleState 제거 (앱 레벨에서 처리)

  @override
  void dispose() {
    // 중앙 관리자를 통해 구독 해제
    _realtimeManager.unsubscribe(_screenId);
    super.dispose();
  }
}
```

#### 2.2 캠페인 목록 화면

**파일**: `lib/screens/campaign/campaigns_screen.dart`

**변경 사항**: 홈 화면과 동일

#### 2.3 캠페인 상세 화면

**파일**: `lib/screens/campaign/campaign_detail_screen.dart`

**변경 사항**:
- `screenId`: `'campaign_detail_${widget.campaignId}'` (동적)
- `campaignId`: 특정 캠페인 ID 전달

#### 2.4 광고주 마이캠페인 화면

### Phase 3: 앱 레벨 생명주기 처리 (필수)

**파일**: `lib/main.dart`

**구현**:
```dart
class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CampaignRealtimeManager.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 앱 레벨에서 생명주기 이벤트 처리 (중앙 관리)
    CampaignRealtimeManager.instance.handleAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

**주의사항**:
- **앱 레벨에서만 생명주기 이벤트 처리**
- 각 화면에서는 `WidgetsBindingObserver` 제거
- 각 화면의 `didChangeAppLifecycleState` 메서드 제거
- 백그라운드 전환 시 자동 일시정지, 포그라운드 복귀 시 자동 재구독

---

## 🔄 마이그레이션 전략

### 전략 1: 점진적 마이그레이션 (권장)

**장점**:
- 단계별 검증 가능
- 리스크 최소화
- 문제 발생 시 롤백 용이

**단계**:
1. Phase 1: `CampaignRealtimeManager` 구현 및 테스트
2. Phase 2: 화면별 마이그레이션 (홈 → 캠페인 목록 → 캠페인 상세 → 광고주 마이캠페인)
3. Phase 3: 앱 레벨 생명주기 처리 (필수)
4. Phase 4: 정리 및 최적화

### 전략 2: 일괄 마이그레이션

**장점**:
- 빠른 적용
- 일관된 코드베이스

**단점**:
- 리스크 높음
- 문제 발생 시 롤백 어려움

**권장**: 전략 1 (점진적 마이그레이션)

---

## 📊 비교 분석

### 현재 방식 vs 중앙화 방식

| 항목 | 현재 방식 | 중앙화 방식 |
|------|----------|------------|
| **인스턴스 관리** | 각 화면에서 개별 생성 | 중앙 관리자에서 통합 관리 |
| **구독 상태 추적** | 어려움 (각 화면에서 개별 관리) | 쉬움 (중앙에서 추적) |
| **중복 구독 방지** | 어려움 (각 화면에서 개별 처리) | 쉬움 (중앙에서 상태 확인) |
| **생명주기 이벤트** | 각 화면에서 개별 처리 | 중앙에서 일관된 처리 |
| **코드 중복** | 많음 (각 화면마다 동일한 로직) | 없음 (중앙 관리자에서 처리) |
| **이그레스 비용** | 높음 (중복 구독 가능) | 낮음 (중복 구독 방지) |
| **유지보수** | 어려움 (여러 곳 수정 필요) | 쉬움 (중앙 관리자만 수정) |
| **디버깅** | 어려움 (구독 상태 추적 어려움) | 쉬움 (중앙에서 추적) |

---

## ⚠️ 주의사항 및 고려사항

### 1. 기존 구독 정리

**주의**:
- 마이그레이션 전에 기존 구독 정리 필요
- `CampaignRealtimeService.unsubscribeAll()` 호출로 모든 구독 해제

### 2. 생명주기 이벤트 중복 처리

**주의**:
- **앱 레벨에서만 처리** (Phase 3에서 구현)
- 화면 레벨에서는 `WidgetsBindingObserver` 제거
- 중복 처리 방지

### 3. 웹 환경 처리

**주의**:
- 웹 환경에서 생명주기 이벤트 무시
- `beforeunload` 이벤트는 `WebUtils.setupBeforeUnload`로 처리

### 4. 화면 전환 시 구독 관리

**주의**:
- 화면 전환 시 구독 해제/재시작 로직 확인
- `dispose`에서 반드시 구독 해제
- 메모리 누수 방지를 위한 자동 정리 메커니즘 포함

### 5. 에러 처리

**주의**:
- 구독 실패 시 재시도 로직 포함
- 네트워크 오류 시 자동 복구 전략 구현

### 6. 테스트 가능성

**주의**:
- 싱글톤 패턴의 테스트 어려움 해결
- `resetInstance()`, `setInstance()` 메서드 제공

### 7. 경쟁 조건 방지

**주의**:
- 동시 구독 시도 시 경쟁 조건 방지
- `_pendingSubscriptions` Set으로 보호

### 8. 콜백 유실 방지

**주의**:
- 백그라운드 전환 시 구독 해제 대신 일시정지
- 포그라운드 복귀 시 자동 재구독

---

## 🧪 테스트 계획

### 1. 단위 테스트

**테스트 항목**:
- `CampaignRealtimeManager.subscribe()` 중복 구독 방지
- `CampaignRealtimeManager.unsubscribe()` 구독 해제
- `CampaignRealtimeManager.isSubscribed()` 구독 상태 확인
- `CampaignRealtimeManager.handleAppLifecycleState()` 생명주기 이벤트 처리

### 2. 통합 테스트

**테스트 항목**:
- 각 화면에서 구독 시작/해제
- 화면 전환 시 구독 관리
- 생명주기 이벤트 처리
- 중복 구독 방지

### 3. 성능 테스트

**테스트 항목**:
- 이그레스 비용 측정 (구독 시작/해제 횟수)
- 메모리 사용량 측정
- WebSocket 연결 수 측정

---

## 📝 구현 체크리스트

### Phase 1: CampaignRealtimeManager 구현
- [ ] `lib/services/campaign_realtime_manager.dart` 파일 생성
- [ ] 싱글톤 패턴 구현
- [ ] `_SubscriptionInfo` 클래스 구현
- [ ] `subscribe()` 메서드 구현 (중복 방지)
- [ ] `unsubscribe()` 메서드 구현
- [ ] `unsubscribeAll()` 메서드 구현
- [ ] `isSubscribed()` 메서드 구현
- [ ] `handleAppLifecycleState()` 메서드 구현 (웹 환경 무시, 디바운싱)
- [ ] `getActiveSubscriptions()` 메서드 구현
- [ ] `dispose()` 메서드 구현
- [ ] 단위 테스트 작성

### Phase 2: 화면별 마이그레이션 (순서: 홈 → 캠페인 목록 → 캠페인 상세 → 광고주 마이캠페인)

#### 2.1 홈 화면 마이그레이션
- [ ] `CampaignRealtimeService?` 제거
- [ ] `StreamSubscription?` 제거
- [ ] `CampaignRealtimeManager.instance` 싱글톤 사용
- [ ] `_initRealtimeSubscription()` 수정
- [ ] `WidgetsBindingObserver` 제거 (앱 레벨에서 처리)
- [ ] `didChangeAppLifecycleState()` 제거
- [ ] `dispose()` 수정
- [ ] `WebUtils.setupBeforeUnload` 제거 (Manager에서 처리)
- [ ] 테스트 및 검증

#### 2.2 캠페인 목록 화면 마이그레이션
- [ ] 동일한 변경사항 적용
- [ ] 테스트 및 검증

#### 2.3 캠페인 상세 화면 마이그레이션
- [ ] 동일한 변경사항 적용 (동적 screenId 처리)
- [ ] `screenId`: `'campaign_detail_${widget.campaignId}'`
- [ ] `campaignId`: 특정 캠페인 ID 전달
- [ ] 테스트 및 검증

#### 2.4 광고주 마이캠페인 화면 마이그레이션
- [ ] 동일한 변경사항 적용 (companyId 포함)
- [ ] `companyId`: 사용자의 회사 ID
- [ ] `activeOnly: false` (모든 상태의 캠페인)
- [ ] 테스트 및 검증

### Phase 3: 앱 레벨 생명주기 처리 (필수)
- [ ] `main.dart` 수정
- [ ] 앱 레벨 생명주기 이벤트 처리
- [ ] 각 화면에서 `WidgetsBindingObserver` 제거
- [ ] 각 화면에서 `didChangeAppLifecycleState` 메서드 제거
- [ ] 테스트 및 검증

### Phase 4: 정리 및 최적화
- [ ] 사용하지 않는 코드 제거
- [ ] 문서 업데이트
- [ ] 최종 테스트 및 검증
- [ ] 성능 테스트 (이그레스 비용 측정)

---

## 🎯 예상 효과

### 1. 코드 품질 개선

**효과**:
- 코드 중복 제거: 각 화면에서 약 30-40줄 제거
- 일관된 구독 관리: 중앙 관리자에서 일관된 처리
- 유지보수 용이: 중앙 관리자만 수정하면 모든 화면에 적용

### 2. 이그레스 비용 절감

**효과**:
- 중복 구독 방지: 불필요한 구독 시작/해제 제거
- 생명주기 이벤트 최적화: 웹 환경에서 무시, 디바운싱 적용
- 예상 절감: 1일 약 33-58MB → 0MB (추가 비용 없음)

### 3. 안정성 향상

**효과**:
- 구독 상태 추적 용이: 중앙에서 모든 구독 추적
- 디버깅 용이: 활성 구독 목록 조회 가능
- 에러 처리 개선: 중앙에서 일관된 에러 처리

---

## 📋 상세 구현 코드

### CampaignRealtimeManager 전체 코드

```dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, kDebugMode, visibleForTesting;
import 'package:flutter/widgets.dart';
import 'campaign_realtime_service.dart';
import 'campaign_realtime_event.dart';

/// 로깅 레벨
enum LogLevel { debug, info, warning, error }

/// 구독 상태 콜백 타입
typedef SubscriptionStateCallback = void Function(String screenId, bool isConnected);

/// Realtime 구독 중앙 관리자
/// 
/// 모든 Realtime 구독을 중앙에서 관리하여:
/// - 중복 구독 방지
/// - 구독 상태 추적
/// - 생명주기 이벤트 중앙 처리
/// - 이그레스 비용 최소화
/// - 자동 재구독 (백그라운드 복귀 시)
class CampaignRealtimeManager {
  // 싱글톤 인스턴스 (테스트 가능하도록 변경)
  static CampaignRealtimeManager? _instance;

  /// 싱글톤 인스턴스 가져오기
  static CampaignRealtimeManager get instance {
    _instance ??= CampaignRealtimeManager._internal();
    return _instance!;
  }

  /// 테스트용: 인스턴스 리셋
  @visibleForTesting
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  /// 테스트용: 인스턴스 주입
  @visibleForTesting
  static void setInstance(CampaignRealtimeManager instance) {
    _instance = instance;
  }

  CampaignRealtimeManager._internal();

  // 화면별 구독 추적
  final Map<String, _SubscriptionInfo> _subscriptions = {};
  
  // 경쟁 조건 방지: 구독 진행 중인 화면 추적
  final Set<String> _pendingSubscriptions = {};
  
  // 생명주기 이벤트 처리
  bool _isAppInBackground = false;
  Timer? _lifecycleDebounceTimer;

  // 로깅 레벨
  LogLevel logLevel = kDebugMode ? LogLevel.debug : LogLevel.warning;

  // 구독 상태 콜백 리스너
  final List<SubscriptionStateCallback> _stateListeners = [];

  /// 로깅 메서드
  void _log(String message, LogLevel level) {
    if (level.index >= logLevel.index) {
      debugPrint(message);
    }
  }

  /// 구독 시작 (중복 방지, 경쟁 조건 방지)
  /// 
  /// [screenId]: 화면 식별자 (예: 'advertiser_my_campaigns', 'home', 'campaigns')
  /// [onEvent]: 이벤트 처리 콜백
  /// [companyId]: 회사 ID (광고주 화면에서 사용)
  /// [campaignId]: 캠페인 ID (상세 화면에서 사용)
  /// [activeOnly]: 활성화된 캠페인만 구독 (기본값: true)
  /// 
  /// 반환값: 구독 성공 여부
  bool subscribe({
    required String screenId,
    required void Function(CampaignRealtimeEvent) onEvent,
    String? companyId,
    String? campaignId,
    bool activeOnly = true,
    void Function(Object)? onError,
  }) {
    // 이미 구독 중이거나 구독 진행 중이면 반환
    if (_subscriptions.containsKey(screenId)) {
      final info = _subscriptions[screenId]!;
      if (info.service.isConnected() && !info.isPaused) {
        _log('ℹ️ 이미 구독 중입니다: $screenId', LogLevel.info);
        return false;
      } else {
        // 구독은 있지만 연결이 끊어졌거나 일시정지된 경우 정리 후 재구독
        _log('⚠️ 구독이 있지만 연결이 끊어졌습니다. 정리 후 재구독: $screenId', LogLevel.warning);
        _unsubscribeInternal(screenId);
      }
    }

    // 경쟁 조건 방지: 구독 진행 중이면 반환
    if (_pendingSubscriptions.contains(screenId)) {
      _log('⚠️ 구독이 이미 진행 중입니다: $screenId', LogLevel.warning);
      return false;
    }

    _pendingSubscriptions.add(screenId);

    try {
      // 새 구독 시작
      final service = CampaignRealtimeService();
      final stream = service.subscribeToCampaigns(
        screenId: screenId,
        companyId: companyId,
        campaignId: campaignId,
        activeOnly: activeOnly,
      );

      final subscription = stream.listen(
        (event) {
          // 이벤트 수신 시 비활성 타이머 갱신
          final info = _subscriptions[screenId];
          if (info != null) {
            info.lastEventTime = DateTime.now();
            info.startInactivityTimer(() {
              _log('⏰ 비활성 타임아웃: $screenId', LogLevel.warning);
              _unsubscribeInternal(screenId);
            });
          }
          onEvent(event);
        },
        onError: onError ?? (error) {
          _log('❌ Realtime 구독 에러 ($screenId): $error', LogLevel.error);
        },
      );

      // 구독 정보 저장
      final info = _SubscriptionInfo(
        service: service,
        subscription: subscription,
        screenId: screenId,
        companyId: companyId,
        campaignId: campaignId,
        activeOnly: activeOnly,
        onEvent: onEvent,
        onError: onError,
      );

      // 비활성 타이머 시작
      info.startInactivityTimer(() {
        _log('⏰ 비활성 타임아웃: $screenId', LogLevel.warning);
        _unsubscribeInternal(screenId);
      });

      _subscriptions[screenId] = info;
      _notifyStateChange(screenId, true);

      _log('✅ Realtime 구독 시작: $screenId', LogLevel.info);
      return true;
    } catch (e) {
      _log('❌ Realtime 구독 실패 ($screenId): $e', LogLevel.error);
      return false;
    } finally {
      _pendingSubscriptions.remove(screenId);
    }
  }

  /// 재시도 로직을 포함한 구독 시작
  /// 
  /// [maxRetries]: 최대 재시도 횟수 (기본값: 3)
  /// [retryDelay]: 재시도 간격 (기본값: 2초)
  Future<bool> subscribeWithRetry({
    required String screenId,
    required void Function(CampaignRealtimeEvent) onEvent,
    String? companyId,
    String? campaignId,
    bool activeOnly = true,
    void Function(Object)? onError,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    int retryCount = 0;

    while (retryCount < maxRetries) {
      final success = subscribe(
        screenId: screenId,
        onEvent: onEvent,
        companyId: companyId,
        campaignId: campaignId,
        activeOnly: activeOnly,
        onError: onError,
      );

      if (success) {
        return true;
      }

      retryCount++;
      if (retryCount < maxRetries) {
        _log('🔄 재시도 중 ($retryCount/$maxRetries): $screenId', LogLevel.warning);
        await Future.delayed(retryDelay * retryCount);
      }
    }

    _log('❌ 구독 실패 (최대 재시도 횟수 초과): $screenId', LogLevel.error);
    return false;
  }

  /// 구독 해제
  /// 
  /// [screenId]: 화면 식별자
  void unsubscribe(String screenId) {
    _unsubscribeInternal(screenId);
  }

  /// 내부 구독 해제 메서드
  void _unsubscribeInternal(String screenId) {
    final info = _subscriptions[screenId];
    if (info == null) {
      _log('ℹ️ 구독이 없습니다: $screenId', LogLevel.info);
      return;
    }

    info.inactivityTimer?.cancel();
    info.service.unsubscribe();
    info.subscription.cancel();
    _subscriptions.remove(screenId);
    _notifyStateChange(screenId, false);

    _log('🔌 Realtime 구독 해제: $screenId', LogLevel.info);
  }

  /// 모든 구독 해제
  void unsubscribeAll() {
    _log('🔌 모든 Realtime 구독 해제: ${_subscriptions.length}개', LogLevel.info);
    final screenIds = _subscriptions.keys.toList();
    for (final screenId in screenIds) {
      _unsubscribeInternal(screenId);
    }
  }

  /// 모든 구독 일시정지 (백그라운드 전환 시)
  void _pauseAllSubscriptions() {
    _log('⏸️ 모든 Realtime 구독 일시정지: ${_subscriptions.length}개', LogLevel.info);
    for (final entry in _subscriptions.entries) {
      final info = entry.value;
      if (!info.isPaused) {
        info.inactivityTimer?.cancel();
        info.service.unsubscribe();
        info.subscription.cancel();
        info.isPaused = true;
        _notifyStateChange(entry.key, false);
        _log('⏸️ 구독 일시정지: ${entry.key}', LogLevel.debug);
      }
    }
  }

  /// 모든 구독 재개 (포그라운드 복귀 시)
  void _resumeAllSubscriptions() {
    _log('▶️ 모든 Realtime 구독 재개: ${_subscriptions.length}개', LogLevel.info);
    final entries = _subscriptions.entries.toList();
    for (final entry in entries) {
      final info = entry.value;
      if (info.isPaused) {
        _resubscribe(entry.key, info);
      }
    }
  }

  /// 구독 재시작 (일시정지된 구독 복원)
  void _resubscribe(String screenId, _SubscriptionInfo oldInfo) {
    try {
      final service = CampaignRealtimeService();
      final stream = service.subscribeToCampaigns(
        screenId: screenId,
        companyId: oldInfo.companyId,
        campaignId: oldInfo.campaignId,
        activeOnly: oldInfo.activeOnly,
      );

      final subscription = stream.listen(
        (event) {
          final info = _subscriptions[screenId];
          if (info != null) {
            info.lastEventTime = DateTime.now();
            info.startInactivityTimer(() {
              _log('⏰ 비활성 타임아웃: $screenId', LogLevel.warning);
              _unsubscribeInternal(screenId);
            });
          }
          oldInfo.onEvent(event);
        },
        onError: oldInfo.onError ?? (error) {
          _log('❌ Realtime 구독 에러 ($screenId): $error', LogLevel.error);
        },
      );

      // 기존 정보 업데이트
      oldInfo.service = service;
      oldInfo.subscription = subscription;
      oldInfo.isPaused = false;
      oldInfo.lastEventTime = DateTime.now();
      oldInfo.startInactivityTimer(() {
        _log('⏰ 비활성 타임아웃: $screenId', LogLevel.warning);
        _unsubscribeInternal(screenId);
      });

      _notifyStateChange(screenId, true);
      _log('▶️ 구독 재개: $screenId', LogLevel.info);
    } catch (e) {
      _log('❌ 구독 재개 실패 ($screenId): $e', LogLevel.error);
      // 재구독 실패 시 구독 정보 제거
      _subscriptions.remove(screenId);
    }
  }

  /// 구독 상태 확인
  bool isSubscribed(String screenId) {
    final info = _subscriptions[screenId];
    return info != null && info.service.isConnected() && !info.isPaused;
  }

  /// 앱 생명주기 이벤트 처리
  /// 
  /// [state]: 앱 생명주기 상태
  void handleAppLifecycleState(AppLifecycleState state) {
    // 웹 환경에서는 생명주기 이벤트 무시 (탭 전환 시에도 구독 유지)
    if (kIsWeb) {
      return;
    }

    // 디바운싱: 500ms 이내의 연속된 이벤트는 무시
    _lifecycleDebounceTimer?.cancel();
    _lifecycleDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        // 백그라운드로 가면 모든 구독 일시정지 (해제 대신)
        if (!_isAppInBackground) {
          _isAppInBackground = true;
          _log('📱 앱이 백그라운드로 전환됨. 모든 Realtime 구독 일시정지', LogLevel.info);
          _pauseAllSubscriptions();
        }
      } else if (state == AppLifecycleState.resumed) {
        // 포그라운드로 돌아오면 자동 재구독
        if (_isAppInBackground) {
          _isAppInBackground = false;
          _log('📱 앱이 포그라운드로 전환됨. 모든 Realtime 구독 재개', LogLevel.info);
          _resumeAllSubscriptions();
        }
      }
    });
  }

  /// 활성 구독 목록 조회 (디버깅용)
  List<String> getActiveSubscriptions() {
    return _subscriptions.keys.toList();
  }

  /// 구독 정보 조회 (디버깅용)
  Map<String, dynamic> getSubscriptionInfo(String screenId) {
    final info = _subscriptions[screenId];
    if (info == null) {
      return {'exists': false};
    }
    return {
      'exists': true,
      'screenId': info.screenId,
      'companyId': info.companyId,
      'campaignId': info.campaignId,
      'activeOnly': info.activeOnly,
      'isConnected': info.service.isConnected() && !info.isPaused,
      'isPaused': info.isPaused,
      'lastEventTime': info.lastEventTime.toIso8601String(),
    };
  }

  /// 구독 상태 콜백 리스너 추가
  void addStateListener(SubscriptionStateCallback callback) {
    _stateListeners.add(callback);
  }

  /// 구독 상태 콜백 리스너 제거
  void removeStateListener(SubscriptionStateCallback callback) {
    _stateListeners.remove(callback);
  }

  /// 구독 상태 변경 알림
  void _notifyStateChange(String screenId, bool isConnected) {
    for (final listener in _stateListeners) {
      listener(screenId, isConnected);
    }
  }

  /// 정리 (앱 종료 시 호출)
  void dispose() {
    _lifecycleDebounceTimer?.cancel();
    unsubscribeAll();
    _stateListeners.clear();
  }
}

/// 구독 정보 클래스 (내부 사용)
class _SubscriptionInfo {
  /// 재구독 시 업데이트됨
  CampaignRealtimeService service;
  
  /// 재구독 시 업데이트됨
  StreamSubscription<CampaignRealtimeEvent> subscription;
  
  final String screenId;
  final String? companyId;
  final String? campaignId;
  final bool activeOnly;
  final void Function(CampaignRealtimeEvent) onEvent;
  final void Function(Object)? onError;
  
  bool isPaused = false;
  DateTime lastEventTime = DateTime.now();
  Timer? inactivityTimer;

  _SubscriptionInfo({
    required this.service,
    required this.subscription,
    required this.screenId,
    this.companyId,
    this.campaignId,
    required this.activeOnly,
    required this.onEvent,
    this.onError,
  });

  /// 비활성 타이머 시작 (30분 이벤트 없으면 자동 해제)
  void startInactivityTimer(VoidCallback onTimeout) {
    inactivityTimer?.cancel();
    inactivityTimer = Timer(const Duration(minutes: 30), onTimeout);
  }
}
```

---

## 🔄 마이그레이션 단계별 가이드

### Step 1: CampaignRealtimeManager 생성

1. `lib/services/campaign_realtime_manager.dart` 파일 생성
2. 위의 전체 코드 복사
3. 린터 검사 및 수정

### Step 2: 화면별 마이그레이션 (홈 화면 예시)

1. Import 추가:
   ```dart
   import '../../../services/campaign_realtime_manager.dart';
   ```

2. 변수 변경:
   ```dart
   // 제거
   CampaignRealtimeService? _realtimeService;
   StreamSubscription<CampaignRealtimeEvent>? _realtimeSubscription;
   
   // 추가
   final _realtimeManager = CampaignRealtimeManager.instance; // instance getter 사용
   static const String _screenId = 'advertiser_my_campaigns';
   ```

3. `_initRealtimeSubscription()` 수정:
   ```dart
   Future<void> _initRealtimeSubscription() async {
     try {
       final user = SupabaseConfig.client.auth.currentUser;
       if (user == null) return;

       final companyId = await CompanyUserService.getUserCompanyId(user.id);
       if (companyId == null) {
         debugPrint('⚠️ 회사 ID를 찾을 수 없어 Realtime 구독을 시작하지 않습니다.');
         return;
       }

       // 중앙 관리자를 통해 구독 (중복 방지)
       _realtimeManager.subscribe(
         screenId: _screenId,
         companyId: companyId,
         activeOnly: false,
         onEvent: _handleRealtimeUpdate,
       );
     } catch (e) {
       debugPrint('❌ Realtime 구독 초기화 실패: $e');
     }
   }
   ```

4. `WidgetsBindingObserver` 제거 및 `didChangeAppLifecycleState()` 제거:
   ```dart
   // WidgetsBindingObserver 제거 (앱 레벨에서 처리)
   // didChangeAppLifecycleState() 메서드 전체 제거
   ```

5. `dispose()` 수정:
   ```dart
   @override
   void dispose() {
     // WidgetsBinding.instance.removeObserver(this); // 제거 (Observer 제거됨)
     _updateTimer?.cancel();
     _realtimeManager.unsubscribe(_screenId); // 변경
     _tabController.dispose();
     super.dispose();
   }
   ```

6. `WebUtils.setupBeforeUnload` 제거 (Manager에서 처리)

### Step 3: 다른 화면 마이그레이션

동일한 패턴으로 적용:
- 홈 화면
- 캠페인 목록 화면
- 캠페인 상세 화면

---

## 🎉 결론

**중앙화된 Realtime 구독 관리**를 통해:

**해결되는 문제**:
- ✅ 코드 중복 제거
- ✅ 중복 구독 방지
- ✅ 생명주기 이벤트 중앙 처리
- ✅ 구독 상태 추적 용이
- ✅ 이그레스 비용 최소화
- ✅ 유지보수 용이

**구현 계획**:
- Phase 1: CampaignRealtimeManager 구현
- Phase 2: 화면별 마이그레이션 (홈 → 캠페인 목록 → 캠페인 상세 → 광고주 마이캠페인)
- Phase 3: 앱 레벨 생명주기 처리 (필수)
- Phase 4: 정리 및 최적화

**권장 사항**:
- 점진적 마이그레이션 (단계별 검증)
- 각 단계마다 테스트 및 검증
- 문제 발생 시 즉시 롤백 가능

---

**작성자**: AI Assistant  
**우선순위**: 높음 (이그레스 비용 및 코드 품질 개선)  
**권장 조치**: 즉시 Phase 1부터 시작 권장

