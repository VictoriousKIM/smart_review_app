import 'campaign.dart';
import 'user.dart';

class CampaignLog {
  final String id;
  final String campaignId;
  final String userId;
  final String status;
  final DateTime activityAt;
  final Map<String, dynamic> data;
  final String? rewardType;
  final int? rewardAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 관계 데이터
  final Campaign? campaign;
  final User? user;

  CampaignLog({
    required this.id,
    required this.campaignId,
    required this.userId,
    required this.status,
    required this.activityAt,
    required this.data,
    this.rewardType,
    this.rewardAmount,
    required this.createdAt,
    required this.updatedAt,
    this.campaign,
    this.user,
  });

  factory CampaignLog.fromJson(Map<String, dynamic> json) {
    return CampaignLog(
      id: json['id'],
      campaignId: json['campaign_id'],
      userId: json['user_id'],
      status: json['status'],
      activityAt: DateTime.parse(json['activity_at']),
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      rewardType: json['reward_type'],
      rewardAmount: json['reward_amount'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
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
      'status': status,
      'activity_at': activityAt.toIso8601String(),
      'data': data,
      'reward_type': rewardType,
      'reward_amount': rewardAmount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // 편의 메서드들
  String get title => data['title'] ?? '';
  int get rating => data['rating'] ?? 0;
  String get applicationMessage => data['application_message'] ?? '';
  String get reviewContent => data['review_content'] ?? '';
  String get reviewUrl => data['review_url'] ?? '';
  String get rejectionReason => data['rejection_reason'] ?? '';

  // 날짜 관련 편의 메서드들
  DateTime? get appliedAt =>
      data['applied_at'] != null ? DateTime.parse(data['applied_at']) : null;
  DateTime? get approvedAt =>
      data['approved_at'] != null ? DateTime.parse(data['approved_at']) : null;
  DateTime? get purchaseDate => data['purchase_date'] != null
      ? DateTime.parse(data['purchase_date'])
      : null;
  DateTime? get reviewSubmittedAt => data['review_submitted_at'] != null
      ? DateTime.parse(data['review_submitted_at'])
      : null;
  DateTime? get reviewApprovedAt => data['review_approved_at'] != null
      ? DateTime.parse(data['review_approved_at'])
      : null;
  DateTime? get visitCompletedAt => data['visit_completed_at'] != null
      ? DateTime.parse(data['visit_completed_at'])
      : null;
  DateTime? get visitVerifiedAt => data['visit_verified_at'] != null
      ? DateTime.parse(data['visit_verified_at'])
      : null;
  DateTime? get articleSubmittedAt => data['article_submitted_at'] != null
      ? DateTime.parse(data['article_submitted_at'])
      : null;
  DateTime? get articleApprovedAt => data['article_approved_at'] != null
      ? DateTime.parse(data['article_approved_at'])
      : null;
  DateTime? get paymentCompletedAt => data['payment_completed_at'] != null
      ? DateTime.parse(data['payment_completed_at'])
      : null;

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

  // 리워드 타입별 한국어 이름 반환
  String get rewardTypeDisplayName {
    switch (rewardType) {
      case 'platform_points':
        return '플랫폼 포인트';
      case 'direct_payment':
        return '직접 지급';
      case 'mixed':
        return '혼합 지급';
      default:
        return rewardType ?? '';
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
    String? status,
    DateTime? activityAt,
    Map<String, dynamic>? data,
    String? rewardType,
    int? rewardAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
    Campaign? campaign,
    User? user,
  }) {
    return CampaignLog(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      activityAt: activityAt ?? this.activityAt,
      data: data ?? this.data,
      rewardType: rewardType ?? this.rewardType,
      rewardAmount: rewardAmount ?? this.rewardAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      campaign: campaign ?? this.campaign,
      user: user ?? this.user,
    );
  }

  @override
  String toString() {
    return 'CampaignLog(id: $id, campaignId: $campaignId, userId: $userId, status: $status, rewardType: $rewardType, rewardAmount: $rewardAmount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CampaignLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
