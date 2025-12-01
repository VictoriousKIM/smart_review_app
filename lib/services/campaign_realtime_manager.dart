import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrint, kDebugMode, visibleForTesting;
import 'package:flutter/widgets.dart';
import 'campaign_realtime_service.dart';
import '../models/campaign_realtime_event.dart';

/// 로깅 레벨
enum LogLevel { debug, info, warning, error }

/// 구독 상태 콜백 타입
typedef SubscriptionStateCallback =
    void Function(String screenId, bool isConnected);

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
        onError:
            onError ??
            (error) {
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
  /// [force]: true면 강제 해제, false면 일시정지만 (기본값: false)
  void unsubscribe(String screenId, {bool force = false}) {
    if (force) {
      _unsubscribeInternal(screenId);
    } else {
      // 화면이 dispose될 때는 일시정지만 하고, 완전히 제거될 때만 해제
      _pauseSubscription(screenId);
    }
  }

  /// 구독 일시정지 (화면이 dispose될 때 호출)
  void _pauseSubscription(String screenId) {
    final info = _subscriptions[screenId];
    if (info == null) {
      _log('ℹ️ 구독이 없습니다: $screenId', LogLevel.info);
      return;
    }

    if (info.isPaused) {
      _log('ℹ️ 이미 일시정지됨: $screenId', LogLevel.info);
      return;
    }

    info.inactivityTimer?.cancel();
    info.service.unsubscribe();
    info.subscription.cancel();
    info.isPaused = true;
    _notifyStateChange(screenId, false);

    _log('⏸️ Realtime 구독 일시정지: $screenId', LogLevel.info);
  }

  /// 구독 재개 (화면이 다시 활성화될 때 호출)
  void resumeSubscription(String screenId) {
    final info = _subscriptions[screenId];
    if (info == null) {
      _log('ℹ️ 구독이 없습니다: $screenId', LogLevel.info);
      return;
    }

    if (!info.isPaused) {
      _log('ℹ️ 이미 활성화됨: $screenId', LogLevel.info);
      return;
    }

    _resubscribe(screenId, info);
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
        onError:
            oldInfo.onError ??
            (error) {
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
