# CampaignRealtimeService 설계 근거

## 🤔 왜 별도 서비스를 만드는가?

### 현재 상황
- `CampaignService`: 싱글톤 패턴, REST API 호출 (CRUD 작업)
- `CampaignRealtimeService`: 실시간 구독 관리 (WebSocket)

---

## ✅ 별도 서비스로 분리하는 이유

### 1. **관심사의 분리 (Separation of Concerns)**
```
CampaignService (REST API)
├── getCampaigns()          → HTTP GET 요청
├── createCampaign()        → HTTP POST 요청
├── updateCampaign()        → HTTP PUT 요청
└── deleteCampaign()        → HTTP DELETE 요청

CampaignRealtimeService (WebSocket)
├── subscribeToCampaigns()  → WebSocket 연결
├── unsubscribe()           → 연결 해제
├── 이벤트 스트림 관리      → 지속적인 연결 유지
└── 생명주기 관리           → dispose, 앱 상태 감지
```

**장점**:
- 각 서비스의 책임이 명확함
- 코드 가독성 향상
- 유지보수 용이

### 2. **생명주기 관리의 차이**

#### CampaignService (REST API)
- **요청-응답 패턴**: 요청 시에만 연결, 응답 후 즉시 해제
- **상태 없음**: 각 메서드 호출이 독립적
- **싱글톤**: 앱 전체에서 하나의 인스턴스만 사용

#### CampaignRealtimeService (WebSocket)
- **지속 연결**: 연결을 유지하고 이벤트를 계속 수신
- **상태 관리 필요**: 
  - 연결 상태 (`_isSubscribed`)
  - 채널 상태 (`_channel`)
  - 타이머 (`_inactivityTimer`)
  - 마지막 활동 시간 (`_lastActivityTime`)
- **화면별 인스턴스**: 각 화면에서 독립적으로 구독 관리

### 3. **메모리 및 리소스 관리**

#### CampaignService
```dart
// 싱글톤이므로 메모리 해제 불필요
final service = CampaignService(); // 앱 전체에서 재사용
```

#### CampaignRealtimeService
```dart
// 각 화면에서 독립적으로 생성 및 해제 필요
class MyCampaignsScreen extends StatefulWidget {
  @override
  void initState() {
    _realtimeService = CampaignRealtimeService();
    _realtimeService.subscribeToCampaigns(...);
  }
  
  @override
  void dispose() {
    _realtimeService.unsubscribe(); // ⚠️ 반드시 해제 필요!
    super.dispose();
  }
}
```

**이유**: WebSocket 연결을 해제하지 않으면:
- 메모리 누수 발생
- 이그레스 비용 발생 (연결 유지)
- 배터리 소모 증가

### 4. **선택적 사용 (Optional Feature)**

모든 화면에서 Realtime이 필요한 것은 아님:
- ✅ **필요한 화면**: 나의 캠페인, 캠페인 상세, 홈, 캠페인 목록
- ❌ **불필요한 화면**: 로그인, 프로필 설정, 포인트 충전 등

**별도 서비스의 장점**:
```dart
// 필요한 화면에서만 import
import 'services/campaign_realtime_service.dart';

// 불필요한 화면에서는 import 안 함
// → 번들 크기 최적화
// → 초기 로딩 시간 단축
```

### 5. **테스트 용이성**

#### 분리된 경우
```dart
// CampaignService 테스트 (REST API만)
test('getCampaigns returns list', () async {
  final service = CampaignService();
  final result = await service.getCampaigns();
  expect(result.success, true);
});

// CampaignRealtimeService 테스트 (WebSocket만)
test('subscribeToCampaigns creates channel', () {
  final service = CampaignRealtimeService();
  service.subscribeToCampaigns();
  expect(service.isConnected(), true);
});
```

#### 통합된 경우
```dart
// REST API와 WebSocket을 함께 테스트해야 함
// → 테스트 복잡도 증가
// → Mock 객체 관리 어려움
```

### 6. **의존성 관리**

#### 분리된 경우
```dart
// CampaignService: Supabase REST API만 의존
class CampaignService {
  final SupabaseClient _supabase; // REST API
}

// CampaignRealtimeService: Supabase Realtime만 의존
class CampaignRealtimeService {
  final SupabaseClient _supabase; // Realtime (WebSocket)
  RealtimeChannel? _channel;
}
```

#### 통합된 경우
```dart
// 하나의 서비스가 REST API와 WebSocket 모두 의존
class CampaignService {
  final SupabaseClient _supabase; // REST API
  RealtimeChannel? _channel;      // WebSocket
  // → 복잡도 증가
  // → 단일 책임 원칙 위반
}
```

---

## ❌ 통합 방식의 단점

### 1. **CampaignService가 너무 커짐**
```dart
class CampaignService {
  // REST API 메서드들 (20개 이상)
  Future<ApiResponse<List<Campaign>>> getCampaigns() { ... }
  Future<ApiResponse<Campaign>> createCampaign() { ... }
  // ... 20개 이상의 메서드
  
  // Realtime 메서드들 (추가)
  Stream<CampaignRealtimeEvent> subscribeToCampaigns() { ... }
  void unsubscribe() { ... }
  // → 클래스가 1000줄 이상으로 커질 수 있음
}
```

### 2. **싱글톤 패턴과의 충돌**
```dart
// CampaignService는 싱글톤
final service = CampaignService(); // 앱 전체에서 하나만 존재

// 하지만 Realtime 구독은 화면별로 다름
// 화면 A: companyId=1 구독
// 화면 B: companyId=2 구독
// → 싱글톤에서는 여러 구독을 동시에 관리하기 어려움
```

### 3. **메모리 관리 복잡도 증가**
```dart
class CampaignService {
  // 싱글톤이므로 dispose 불가능
  // → Realtime 연결을 언제 해제할지 불명확
  // → 메모리 누수 위험
}
```

---

## 🔄 대안: CampaignService에 통합하는 경우

만약 통합한다면 다음과 같이 구현해야 함:

```dart
class CampaignService {
  // 기존 REST API 메서드들...
  
  // Realtime 관련 필드
  final Map<String, RealtimeChannel> _channels = {}; // 화면별 채널 관리
  final Map<String, StreamController> _eventControllers = {};
  
  // Realtime 구독 (화면별로 독립적)
  Stream<CampaignRealtimeEvent> subscribeToCampaigns({
    required String screenId, // 화면 식별자
    String? companyId,
    String? campaignId,
  }) {
    // screenId별로 채널 관리
    if (_channels.containsKey(screenId)) {
      _channels[screenId]?.unsubscribe();
    }
    
    final channel = _supabase
      .channel('campaigns_$screenId')
      .onPostgresChanges(...)
      .subscribe();
    
    _channels[screenId] = channel;
    // ...
  }
  
  // 구독 해제 (화면별)
  void unsubscribe(String screenId) {
    _channels[screenId]?.unsubscribe();
    _channels.remove(screenId);
    _eventControllers[screenId]?.close();
    _eventControllers.remove(screenId);
  }
  
  // 모든 구독 해제
  void unsubscribeAll() {
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
    _channels.clear();
    // ...
  }
}
```

**문제점**:
1. `CampaignService`가 너무 커짐 (1000줄 이상)
2. 화면별 구독 관리 로직이 복잡해짐
3. 싱글톤에서 메모리 관리가 어려움
4. 테스트 복잡도 증가

---

## ✅ 최종 권장사항

### 별도 서비스로 분리 (현재 로드맵 방식) ⭐

**이유**:
1. ✅ **관심사 분리**: REST API와 WebSocket의 책임이 명확히 구분됨
2. ✅ **메모리 관리**: 각 화면에서 독립적으로 생성/해제 가능
3. ✅ **유지보수성**: 각 서비스의 코드가 간결하고 이해하기 쉬움
4. ✅ **테스트 용이성**: 각 서비스를 독립적으로 테스트 가능
5. ✅ **선택적 사용**: 필요한 화면에서만 import하여 사용
6. ✅ **확장성**: 향후 다른 Realtime 기능 추가 시에도 구조가 명확함

### 사용 예시

```dart
// 화면에서 사용
class MyCampaignsScreen extends StatefulWidget {
  @override
  _MyCampaignsScreenState createState() => _MyCampaignsScreenState();
}

class _MyCampaignsScreenState extends State<MyCampaignsScreen> {
  final CampaignService _campaignService = CampaignService(); // 싱글톤
  CampaignRealtimeService? _realtimeService; // 화면별 인스턴스
  
  @override
  void initState() {
    super.initState();
    
    // REST API로 초기 데이터 로드
    _campaignService.getUserCampaigns();
    
    // Realtime 구독 시작
    _realtimeService = CampaignRealtimeService();
    _realtimeService!.subscribeToCampaigns(
      companyId: _getCurrentCompanyId(),
    ).listen((event) {
      // 이벤트 처리
      _handleRealtimeUpdate(event);
    });
  }
  
  @override
  void dispose() {
    _realtimeService?.unsubscribe(); // ⚠️ 반드시 해제!
    super.dispose();
  }
}
```

---

## 📊 비교표

| 항목 | 별도 서비스 | 통합 서비스 |
|------|------------|------------|
| **코드 가독성** | ✅ 높음 | ❌ 낮음 (클래스가 너무 큼) |
| **메모리 관리** | ✅ 쉬움 (화면별 해제) | ❌ 어려움 (싱글톤) |
| **테스트** | ✅ 쉬움 (독립적) | ❌ 어려움 (복합적) |
| **유지보수** | ✅ 쉬움 | ❌ 어려움 |
| **확장성** | ✅ 높음 | ❌ 낮음 |
| **번들 크기** | ✅ 최적화 (선택적 import) | ❌ 항상 포함 |

---

## 🎯 결론

**별도 서비스로 분리하는 것이 더 나은 설계입니다.**

이유:
1. REST API와 WebSocket은 **본질적으로 다른 통신 방식**
2. 각각의 **생명주기와 상태 관리 방식이 다름**
3. **메모리 관리**가 중요함 (특히 Realtime)
4. **코드 가독성과 유지보수성** 향상

다만, 만약 프로젝트 규모가 작고 Realtime 기능이 단순하다면 통합도 고려할 수 있습니다. 하지만 현재 프로젝트의 경우:
- 여러 화면에서 Realtime 사용 예정
- 이그레스 비용 관리가 중요
- 메모리 관리가 중요

→ **별도 서비스로 분리하는 것을 강력히 권장합니다.**

---

## 📋 추가 검토 사항 (리뷰 피드백 반영)

### 1. 동시성 문제 및 DB 레벨 방어
- **Realtime의 한계**: 미세한 지연이 있으므로 UI에서 버튼을 막는 것만으로는 부족
- **DB 레벨 방어**: `join_campaign_safe` RPC 함수에서 `current_participants >= max_participants` 체크 수행 (이미 구현됨)
- **권장사항**: 트랜잭션 레벨에서 행 잠금(`FOR UPDATE`) 사용 여부 확인

### 2. 데이터 충돌 및 깜빡임 방지
- **Pull-to-Refresh 충돌**: `isLoading` 상태 확인하여 이벤트를 큐에 저장하거나 무시
- **구현 예시**: 로드맵에 상세 코드 포함

### 3. 플랫폼별 임포트 처리
- **문제**: `dart:html`은 앱 빌드 시 컴파일 에러 발생
- **해결**: `universal_html` 패키지 사용 (웹/앱 모두 호환)

### 4. 성능 최적화
- **StreamBuilder 활용**: 전체 화면 리빌드 대신 일부 위젯만 업데이트
- **Throttle/Debounce 조정**:
  - 참여자 수: Throttle (500ms) - UI 반응성 향상
  - 리스트 갱신: Debounce (1초) - 이그레스 최소화

### 5. 연결 해제 안전장치
- **Global Cleanup**: `unsubscribeAll()` 메서드 추가
- **앱 종료/로그아웃 시 호출**: 모든 구독 해제 보장

### 6. Supabase Replica Identity 확인
- **Replica Identity 설정**: Default 권장 (Full이면 이그레스 비용 높음)
- **확인 위치**: Supabase 대시보드의 Database -> Replication 설정

자세한 내용은 `docs/campaign-realtime-sync-optimization-roadmap.md`를 참고하세요.

