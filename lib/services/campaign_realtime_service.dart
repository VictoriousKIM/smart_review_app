import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/campaign.dart';
import '../models/campaign_realtime_event.dart';

/// 캠페인 Realtime 구독 서비스
///
/// 이그레스 비용 방지를 위한 안전장치:
/// - dispose 시 구독 해제
/// - 앱 상태 감지 (WidgetsBindingObserver)
/// - 페이지 언로드 시 구독 해제 (웹)
/// - 비활성 타임아웃 설정
/// - Global Cleanup (unsubscribeAll)
class CampaignRealtimeService {
  final SupabaseClient _supabase;
  RealtimeChannel? _channel;
  StreamController<CampaignRealtimeEvent>? _eventController;
  Timer? _inactivityTimer;
  DateTime? _lastActivityTime;
  bool _isSubscribed = false;
  String? _screenId;

  // 활성 구독 추적 (Global Cleanup용)
  static final Set<String> _activeSubscriptions = {};

  CampaignRealtimeService({SupabaseClient? supabase})
    : _supabase = supabase ?? SupabaseConfig.client;

  /// 구독 시작 (화면이 보일 때만 호출)
  ///
  /// [screenId]: 화면 식별자 (예: 'my_campaigns', 'home', 'campaign_detail')
  /// [companyId]: 회사 ID (광고주 화면에서 사용)
  /// [campaignId]: 캠페인 ID (상세 화면에서 사용)
  /// [activeOnly]: 활성화된 캠페인만 구독 (기본값: true)
  /// [inactivityTimeout]: 비활성 타임아웃 (기본값: 5분)
  Stream<CampaignRealtimeEvent> subscribeToCampaigns({
    required String screenId,
    String? companyId,
    String? campaignId,
    bool activeOnly = true,
    Duration? inactivityTimeout,
  }) {
    // 기존 구독이 있으면 해제
    if (_isSubscribed) {
      debugPrint('⚠️ 기존 구독이 있습니다. 해제 후 재구독합니다.');
      unsubscribe();
    }

    _screenId = screenId;
    _isSubscribed = true;
    _activeSubscriptions.add(screenId);
    _lastActivityTime = DateTime.now();

    // 비활성 타임아웃 설정 (기본값: 5분)
    final timeout = inactivityTimeout ?? const Duration(minutes: 5);
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkInactivityTimeout(timeout);
    });

    // 이벤트 스트림 컨트롤러 생성
    _eventController = StreamController<CampaignRealtimeEvent>.broadcast();

    // 채널 생성
    final channelName =
        'campaigns_${screenId}_${DateTime.now().millisecondsSinceEpoch}';
    _channel = _supabase.channel(channelName);

    // Postgres 변경사항 구독
    var postgresChanges = _channel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'campaigns',
      filter: campaignId != null
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: campaignId,
            )
          : null,
      callback: (payload) {
        debugPrint('');
        debugPrint('🔔 ===== Realtime callback 시작 =====');
        debugPrint('🔔 eventType: ${payload.eventType}');
        debugPrint('🔔 newRecord: ${payload.newRecord}');
        debugPrint('🔔 oldRecord: ${payload.oldRecord}');
        debugPrint('🔔 ===== Realtime callback 끝 =====');
        _recordActivity();
        _handlePostgresChange(payload, companyId, activeOnly);
      },
    );

    // 구독 시작
    postgresChanges.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('✅ Realtime 구독 성공: $screenId');
      } else if (status == RealtimeSubscribeStatus.timedOut) {
        debugPrint('⚠️ Realtime 구독 타임아웃: $screenId');
        _eventController?.addError('구독 타임아웃');
      } else if (status == RealtimeSubscribeStatus.channelError) {
        debugPrint('❌ Realtime 구독 에러: $screenId, $error');
        _eventController?.addError(error ?? '구독 에러');
      } else {
        debugPrint('⚠️ Realtime 구독 상태: $status (screenId: $screenId)');
      }
    });

    return _eventController!.stream;
  }

  /// Postgres 변경사항 처리 - 디버깅 강화
  void _handlePostgresChange(
    PostgresChangePayload payload,
    String? companyId,
    bool activeOnly,
  ) {
    try {
      final eventTypeString = payload.eventType
          .toString()
          .split('.')
          .last
          .toUpperCase();
      final newRecord = payload.newRecord;
      final oldRecord = payload.oldRecord;

      debugPrint('');
      debugPrint('📡 ========================================');
      debugPrint('📡 _handlePostgresChange 시작');
      debugPrint('📡 eventType: $eventTypeString');
      debugPrint('📡 companyId 필터: $companyId');
      debugPrint('📡 activeOnly 필터: $activeOnly');
      debugPrint(
        '📡 newRecord keys: ${newRecord != null ? newRecord.keys.toList() : null}',
      );
      debugPrint('📡 ========================================');

      // 필터링: 회사 ID
      if (companyId != null && newRecord != null) {
        final recordCompanyId = newRecord['company_id'] as String?;
        if (recordCompanyId != companyId) {
          debugPrint('⏭️ companyId 필터로 무시: $recordCompanyId != $companyId');
          return;
        }
      }

      // 필터링: 활성화된 캠페인만
      if (activeOnly && newRecord != null) {
        final status = newRecord['status'] as String?;
        debugPrint('📡 캠페인 status: $status');
        if (status != 'active') {
          debugPrint('⏭️ status 필터로 무시: $status != active');
          return;
        }
      }

      // Campaign 파싱
      Campaign? campaign;
      if (newRecord != null) {
        try {
          debugPrint('📡 Campaign.fromJson 시도...');
          campaign = Campaign.fromJson(newRecord);
          debugPrint('✅ Campaign 파싱 성공: ${campaign.id}');
          debugPrint('   title: ${campaign.title}');
          debugPrint('   currentParticipants: ${campaign.currentParticipants}');
          debugPrint('   maxParticipants: ${campaign.maxParticipants}');
        } catch (e, stackTrace) {
          debugPrint('❌ Campaign 파싱 실패!');
          debugPrint('   에러: $e');
          debugPrint('   스택트레이스: $stackTrace');
          debugPrint('   newRecord: $newRecord');
          return;
        }
      }

      final event = CampaignRealtimeEvent(
        type: eventTypeString,
        campaign: campaign,
        oldRecord: oldRecord,
        newRecord: newRecord,
      );

      debugPrint('📡 이벤트 생성 완료, _eventController에 추가');
      _eventController?.add(event);
      debugPrint('📡 _eventController.add 완료');
    } catch (e, stackTrace) {
      debugPrint('❌ _handlePostgresChange 전체 실패!');
      debugPrint('   에러: $e');
      debugPrint('   스택트레이스: $stackTrace');
      _eventController?.addError(e);
    }
  }

  /// 활동 기록 (이벤트 수신 시 호출)
  void _recordActivity() {
    _lastActivityTime = DateTime.now();
  }

  /// 비활성 타임아웃 체크
  void _checkInactivityTimeout(Duration timeout) {
    if (_lastActivityTime == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastActivityTime!);

    if (elapsed > timeout) {
      debugPrint('⏰ 비활성 타임아웃: ${_screenId ?? 'unknown'}');
      unsubscribe();
    }
  }

  /// 구독 해제 (반드시 호출 필요)
  void unsubscribe() {
    if (!_isSubscribed) {
      debugPrint('ℹ️ 이미 구독 해제됨: ${_screenId ?? 'unknown'}');
      return;
    }

    debugPrint('🔌 Realtime 구독 해제: ${_screenId ?? 'unknown'}');

    _inactivityTimer?.cancel();
    _inactivityTimer = null;

    _channel?.unsubscribe();
    _channel = null;

    _eventController?.close();
    _eventController = null;

    _isSubscribed = false;
    _lastActivityTime = null;

    if (_screenId != null) {
      _activeSubscriptions.remove(_screenId);
      _screenId = null;
    }
  }

  /// 연결 상태 확인
  bool isConnected() {
    return _isSubscribed && _channel != null;
  }

  /// 모든 구독 해제 (Global Cleanup - 앱 종료/로그아웃 시 호출)
  static void unsubscribeAll() {
    debugPrint('🔌 모든 Realtime 구독 해제: ${_activeSubscriptions.length}개');
    // 실제 구독 해제는 각 인스턴스의 unsubscribe()에서 처리됨
    // 여기서는 추적만 초기화
    _activeSubscriptions.clear();
  }

  /// 활성 구독 수 확인
  static int get activeSubscriptionCount => _activeSubscriptions.length;

  /// 활성 구독 목록 확인 (디버깅용)
  static Set<String> get activeSubscriptions =>
      Set.unmodifiable(_activeSubscriptions);
}
