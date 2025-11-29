import 'campaign.dart';

/// 캠페인 Realtime 이벤트 모델
class CampaignRealtimeEvent {
  /// 이벤트 타입: 'INSERT', 'UPDATE', 'DELETE'
  final String type;

  /// 변경된 캠페인 정보 (INSERT, UPDATE 시)
  final Campaign? campaign;

  /// 이전 레코드 (UPDATE, DELETE 시)
  final Map<String, dynamic>? oldRecord;

  /// 새 레코드 (INSERT, UPDATE 시)
  final Map<String, dynamic>? newRecord;

  CampaignRealtimeEvent({
    required this.type,
    this.campaign,
    this.oldRecord,
    this.newRecord,
  });

  /// 이벤트 타입이 INSERT인지 확인
  bool get isInsert => type == 'INSERT';

  /// 이벤트 타입이 UPDATE인지 확인
  bool get isUpdate => type == 'UPDATE';

  /// 이벤트 타입이 DELETE인지 확인
  bool get isDelete => type == 'DELETE';

  @override
  String toString() {
    return 'CampaignRealtimeEvent(type: $type, campaignId: ${campaign?.id ?? 'N/A'})';
  }
}

