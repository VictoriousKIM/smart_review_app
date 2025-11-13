import 'campaign.dart';
import 'user.dart';

/// campaign_action_logs 테이블 모델 (Supabase 스키마 기반)
/// 
/// 참고: 이 모델은 campaign_action_logs 테이블을 나타냅니다.
/// 모델명은 CampaignLog이지만 실제 DB 테이블명은 campaign_action_logs입니다.
/// 
/// DB 스키마:
/// - id: uuid
/// - campaign_id: uuid
/// - user_id: uuid
/// - action: jsonb (예: {"type": "join", "data": {...}})
/// - application_message: text (nullable)
/// - status: text ('pending', 'approved', 'rejected', 'completed', 'cancelled')
/// - created_at: timestamp
/// - updated_at: timestamp
class CampaignLog {
  final String id;
  final String campaignId;
  final String userId;
  final Map<String, dynamic> action; // DB에 있는 필드 (JSONB)
  final String? applicationMessage; // DB에 있는 필드
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 관계 데이터 (JOIN으로 가져옴)
  final Campaign? campaign;
  final User? user;

  CampaignLog({
    required this.id,
    required this.campaignId,
    required this.userId,
    required this.action,
    this.applicationMessage,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.campaign,
    this.user,
  });

  factory CampaignLog.fromJson(Map<String, dynamic> json) {
    // action 필드 처리 (JSONB)
    Map<String, dynamic> actionData;
    if (json['action'] is Map) {
      actionData = Map<String, dynamic>.from(json['action'] as Map);
    } else if (json['action'] is String) {
      // 하위 호환성: 문자열인 경우 {"type": "문자열"} 형식으로 변환
      actionData = {'type': json['action'] as String};
    } else {
      actionData = {'type': ''};
    }

    return CampaignLog(
      id: json['id'] ?? '',
      campaignId: json['campaign_id'] ?? '',
      userId: json['user_id'] ?? '',
      action: actionData,
      applicationMessage: json['application_message'],
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      campaign: json['campaigns'] != null
          ? Campaign.fromJson(json['campaigns'])
          : null,
      user: json['users'] != null ? User.fromJson(json['users']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'user_id': userId,
      'action': action,
      'application_message': applicationMessage,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // 편의 getter: action.type 반환
  String get actionType => action['type'] as String? ?? '';

  // 편의 getter: action.data 반환
  Map<String, dynamic>? get actionData => action['data'] as Map<String, dynamic>?;

  // 편의 메서드들 (action.data에서 가져옴)
  // action 필드가 JSONB로 변경되어 action.data에서 리뷰 상세 정보를 가져올 수 있습니다.
  String get title => actionData?['title'] as String? ?? '';
  
  int get rating => actionData?['rating'] as int? ?? 0;
  
  String get reviewContent => actionData?['content'] as String? ?? '';
  
  String get reviewUrl => actionData?['reviewUrl'] as String? ?? '';
  
  String get rejectionReason => actionData?['rejectionReason'] as String? ?? '';

  // 날짜 관련 편의 메서드들 (하위 호환성)
  // 
  // ⚠️ 주의: 이 메서드들은 DB에 data 필드가 없으므로 항상 null을 반환합니다.
  // 날짜 정보가 필요한 경우 status와 created_at, updated_at 필드를 사용하세요.
  @Deprecated('DB에 data 필드가 없습니다. status와 created_at, updated_at 필드를 사용하세요.')
  DateTime? get appliedAt => null;
  
  @Deprecated('DB에 data 필드가 없습니다. status와 created_at, updated_at 필드를 사용하세요.')
  DateTime? get approvedAt => null;
  
  @Deprecated('DB에 data 필드가 없습니다. status와 created_at, updated_at 필드를 사용하세요.')
  DateTime? get purchaseDate => null;
  
  @Deprecated('DB에 data 필드가 없습니다. status와 created_at, updated_at 필드를 사용하세요.')
  DateTime? get reviewSubmittedAt => null;
  
  @Deprecated('DB에 data 필드가 없습니다. status와 created_at, updated_at 필드를 사용하세요.')
  DateTime? get reviewApprovedAt => null;
  
  @Deprecated('DB에 data 필드가 없습니다. status와 created_at, updated_at 필드를 사용하세요.')
  DateTime? get visitCompletedAt => null;
  
  @Deprecated('DB에 data 필드가 없습니다. status와 created_at, updated_at 필드를 사용하세요.')
  DateTime? get visitVerifiedAt => null;
  
  @Deprecated('DB에 data 필드가 없습니다. status와 created_at, updated_at 필드를 사용하세요.')
  DateTime? get articleSubmittedAt => null;
  
  @Deprecated('DB에 data 필드가 없습니다. status와 created_at, updated_at 필드를 사용하세요.')
  DateTime? get articleApprovedAt => null;
  
  @Deprecated('DB에 data 필드가 없습니다. status와 created_at, updated_at 필드를 사용하세요.')
  DateTime? get paymentCompletedAt => null;
  
  // activityAt은 createdAt을 사용
  DateTime get activityAt => createdAt;

  // 상태별 진행률 계산
  double get progress {
    final campaignType = campaign?.campaignType.name ?? 'review';
    final steps = _getStepsForCampaignType(campaignType);
    final currentStepIndex = steps.indexOf(status);
    return (currentStepIndex + 1) / steps.length;
  }

  // 상태별 단계 이름 반환
  List<String> get statusSteps {
    final campaignType = campaign?.campaignType.name ?? 'review';
    return _getStepsForCampaignType(campaignType);
  }

  // 상태별 한국어 이름 반환
  String get statusDisplayName {
    switch (status) {
      case 'applied':
        return '신청됨';
      case 'approved':
        return '승인됨';
      case 'rejected':
        return '거절됨';
      case 'purchased':
        return '구매완료';
      case 'review_submitted':
        return '리뷰작성완료';
      case 'review_approved':
        return '리뷰승인됨';
      case 'visit_completed':
        return '방문완료';
      case 'visit_verified':
        return '방문검증완료';
      case 'article_submitted':
        return '기사작성완료';
      case 'article_approved':
        return '기사승인됨';
      case 'payment_completed':
        return '지급완료';
      default:
        return status;
    }
  }

  // action 필드의 한국어 이름 반환
  String get actionDisplayName {
    final type = actionType;
    switch (type) {
      case 'join':
        return '참여';
      case 'leave':
        return '탈퇴';
      case 'complete':
        return '완료';
      case 'cancel':
        return '취소';
      case '시작':
        return '시작';
      case '진행상황_저장':
        return '진행상황 저장';
      case '완료':
        return '완료';
      default:
        return type;
    }
  }

  // 상태별 색상 반환
  int get statusColor {
    switch (status) {
      case 'applied':
        return 0xFF2196F3; // 파란색
      case 'approved':
        return 0xFF4CAF50; // 초록색
      case 'rejected':
        return 0xFFF44336; // 빨간색
      case 'purchased':
      case 'review_submitted':
      case 'visit_completed':
      case 'article_submitted':
        return 0xFFFF9800; // 주황색
      case 'review_approved':
      case 'visit_verified':
      case 'article_approved':
        return 0xFF9C27B0; // 보라색
      case 'payment_completed':
        return 0xFF4CAF50; // 초록색
      default:
        return 0xFF757575; // 회색
    }
  }

  List<String> _getStepsForCampaignType(String campaignType) {
    switch (campaignType) {
      case 'review':
        return [
          'applied',
          'approved',
          'purchased',
          'review_submitted',
          'review_approved',
          'payment_completed',
        ];
      case 'visit':
        return [
          'applied',
          'approved',
          'visit_completed',
          'visit_verified',
          'payment_completed',
        ];
      case 'press':
        return [
          'applied',
          'approved',
          'article_submitted',
          'article_approved',
          'payment_completed',
        ];
      default:
        return ['applied', 'approved', 'payment_completed'];
    }
  }

  // 복사 생성자
  CampaignLog copyWith({
    String? id,
    String? campaignId,
    String? userId,
    Map<String, dynamic>? action,
    String? applicationMessage,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Campaign? campaign,
    User? user,
  }) {
    return CampaignLog(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      userId: userId ?? this.userId,
      action: action ?? this.action,
      applicationMessage: applicationMessage ?? this.applicationMessage,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      campaign: campaign ?? this.campaign,
      user: user ?? this.user,
    );
  }

  @override
  String toString() {
    return 'CampaignLog(id: $id, campaignId: $campaignId, userId: $userId, action: $action, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CampaignLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
