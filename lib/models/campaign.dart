import '../utils/date_time_utils.dart';

/// campaigns 테이블 모델 (Supabase 스키마 기반)
class Campaign {
  final String id;
  final String title;
  final String description;
  final String companyId; // DB에 있는 필드 추가
  final String productName; // DB에 있는 필드 추가 (NOT NULL)
  final String productImageUrl;
  final String platform;
  final CampaignCategory campaignType;
  final int productPrice; // NOT NULL
  final int campaignReward; // DB에 있는 필드 (campaign_reward)
  final DateTime applyStartDate;  // 신청 시작일시 (기존: startDate)
  final DateTime applyEndDate;    // 신청 종료일시 (기존: endDate)
  final DateTime reviewStartDate; // 리뷰 시작일시 (신규)
  final DateTime reviewEndDate;   // 리뷰 종료일시 (기존: expirationDate)
  final int currentParticipants;
  final int? maxParticipants;
  final int maxPerReviewer;  // 리뷰어당 신청 가능 개수
  final CampaignStatus status;
  final DateTime createdAt;
  final String? userId; // DB에 있는 필드 추가

  // 상품 상세 정보
  final String? keyword;
  final String? option;
  final int quantity;
  final String seller; // NOT NULL
  final String? productNumber;
  final String purchaseMethod;

  // 리뷰 설정
  final String reviewType; // 'star_only', 'star_text', 'star_text_image'
  final int reviewTextLength;
  final int reviewImageCount;
  final String? reviewKeywords; // 리뷰 키워드 (콤마로 구분된 문자열)

  // 중복 방지 설정
  final bool preventProductDuplicate;
  final bool preventStoreDuplicate;
  final int duplicatePreventDays;

  // 비용 설정
  final String paymentMethod;
  final int totalCost;

  Campaign({
    required this.id,
    required this.title,
    required this.description,
    required this.companyId,
    required this.productName,
    required this.productImageUrl,
    required this.platform,
    required this.campaignType,
    required this.productPrice,
    required this.campaignReward,
    required this.applyStartDate,
    required this.applyEndDate,
    required this.reviewStartDate,
    required this.reviewEndDate,
      this.currentParticipants = 0,
      this.maxParticipants,
      this.maxPerReviewer = 1,  // 기본값: 1
      this.status = CampaignStatus.active,
    required this.createdAt,
    this.userId,
    // 상품 상세 정보
    this.keyword,
    this.option,
    this.quantity = 1,
    required this.seller,
    this.productNumber,
    this.purchaseMethod = 'mobile',
    // 리뷰 설정
    this.reviewType = 'star_only',
    this.reviewTextLength = 100,
    this.reviewImageCount = 0,
    this.reviewKeywords,
    // 중복 방지 설정
    this.preventProductDuplicate = false,
    this.preventStoreDuplicate = false,
    this.duplicatePreventDays = 0,
    // 비용 설정
    this.paymentMethod = 'platform',
    this.totalCost = 0,
  });

  /// review_keywords를 파싱하는 헬퍼 함수
  /// DB에서는 text[] (배열)로 저장되지만, 모델에서는 String? (콤마로 구분된 문자열)로 사용
  static String? _parseReviewKeywords(dynamic value) {
    if (value == null) return null;
    
    // 배열인 경우
    if (value is List) {
      if (value.isEmpty) return null;
      return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join(',');
    }
    
    // 문자열인 경우 (하위 호환성)
    if (value is String) {
      return value.trim().isEmpty ? null : value.trim();
    }
    
    return null;
  }

  factory Campaign.fromJson(Map<String, dynamic> json) {
    // DB의 campaign_type 값 매핑: 'journalist' -> 'press', 'store' -> 'store', 'visit' -> 'visit'
    CampaignCategory mapCampaignType(String? type) {
      switch (type) {
        case 'journalist':
          return CampaignCategory.press;
        case 'store':
          return CampaignCategory.store;
        case 'visit':
          return CampaignCategory.visit;
        default:
          return CampaignCategory.store; // 기본값
      }
    }

    return Campaign(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      companyId: json['company_id'] ?? '',
      productName: json['product_name'] ?? '',
      productImageUrl: json['product_image_url'] ?? '',
      platform: json['platform'] ?? '',
      campaignType: mapCampaignType(json['campaign_type']),
      productPrice: json['product_price'] ?? 0,
      campaignReward: json['campaign_reward'] ?? 0,
      // DB에서 가져온 UTC 시간을 한국 시간(KST, UTC+9)으로 변환
      applyStartDate: json['apply_start_date'] != null
          ? DateTimeUtils.parseKST(json['apply_start_date'])
          : DateTimeUtils.nowKST().add(const Duration(days: 1)),
      applyEndDate: json['apply_end_date'] != null
          ? DateTimeUtils.parseKST(json['apply_end_date'])
          : DateTimeUtils.nowKST().add(const Duration(days: 8)),
      reviewStartDate: json['review_start_date'] != null
          ? DateTimeUtils.parseKST(json['review_start_date'])
          : (json['apply_end_date'] != null
              ? DateTimeUtils.parseKST(json['apply_end_date']).add(const Duration(days: 1))
              : DateTimeUtils.nowKST().add(const Duration(days: 9))),
      reviewEndDate: json['review_end_date'] != null
          ? DateTimeUtils.parseKST(json['review_end_date'])
          : DateTimeUtils.nowKST().add(const Duration(days: 38)),
      currentParticipants: json['current_participants'] ?? 0,
      maxParticipants: json['max_participants'],
      maxPerReviewer: json['max_per_reviewer'] ?? 1,
      status: CampaignStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'active'),
        orElse: () => CampaignStatus.active,
      ),
      createdAt: json['created_at'] != null
          ? DateTimeUtils.parseKST(json['created_at'])
          : DateTimeUtils.nowKST(),
      userId: json['user_id'],
      // 상품 상세 정보
      keyword: json['keyword'],
      option: json['option'],
      quantity: json['quantity'] ?? 1,
      seller: json['seller'] ?? '',
      productNumber: json['product_number'],
      purchaseMethod: json['purchase_method'] ?? 'mobile',
      // 리뷰 설정
      reviewType: json['review_type'] ?? 'star_only',
      reviewTextLength: json['review_text_length'] ?? 100,
      reviewImageCount: json['review_image_count'] ?? 0,
      reviewKeywords: _parseReviewKeywords(json['review_keywords']),
      // 중복 방지 설정
      preventProductDuplicate: json['prevent_product_duplicate'] ?? false,
      preventStoreDuplicate: json['prevent_store_duplicate'] ?? false,
      duplicatePreventDays: json['duplicate_prevent_days'] ?? 0,
      // 비용 설정
      paymentMethod: json['payment_method'] ?? 'platform',
      totalCost: json['total_cost'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    // Flutter enum을 DB 값으로 변환: 'press' -> 'journalist'
    String mapCampaignTypeToDb(CampaignCategory type) {
      switch (type) {
        case CampaignCategory.press:
          return 'journalist';
        case CampaignCategory.store:
          return 'store';
        case CampaignCategory.visit:
          return 'visit';
        case CampaignCategory.all:
          return 'store'; // 기본값
      }
    }

    return {
      'id': id,
      'title': title,
      'description': description,
      'company_id': companyId,
      'product_name': productName,
      'product_image_url': productImageUrl,
      'platform': platform,
      'campaign_type': mapCampaignTypeToDb(campaignType),
      'product_price': productPrice,
      'campaign_reward': campaignReward,
      'apply_start_date': applyStartDate.toIso8601String(),
      'apply_end_date': applyEndDate.toIso8601String(),
      'review_start_date': reviewStartDate.toIso8601String(),
      'review_end_date': reviewEndDate.toIso8601String(),
      'current_participants': currentParticipants,
      'max_participants': maxParticipants,
      'max_per_reviewer': maxPerReviewer,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
      // 상품 상세 정보
      'keyword': keyword,
      'option': option,
      'quantity': quantity,
      'seller': seller,
      'product_number': productNumber,
      'purchase_method': purchaseMethod,
      // 리뷰 설정
      'review_type': reviewType,
      'review_text_length': reviewTextLength,
      'review_image_count': reviewImageCount,
      'review_keywords': reviewKeywords,
      // 중복 방지 설정
      'prevent_product_duplicate': preventProductDuplicate,
      'prevent_store_duplicate': preventStoreDuplicate,
      'duplicate_prevent_days': duplicatePreventDays,
      // 비용 설정
      'payment_method': paymentMethod,
      'total_cost': totalCost,
    };
  }

  Campaign copyWith({
    String? id,
    String? title,
    String? description,
    String? companyId,
    String? productName,
    String? productImageUrl,
    String? platform,
    CampaignCategory? campaignType,
    int? productPrice,
    int? campaignReward,
    DateTime? applyStartDate,
    DateTime? applyEndDate,
    DateTime? reviewStartDate,
    DateTime? reviewEndDate,
    int? currentParticipants,
    int? maxParticipants,
    CampaignStatus? status,
    DateTime? createdAt,
    String? userId,
    // 상품 상세 정보
    String? keyword,
    String? option,
    int? quantity,
    String? seller,
    String? productNumber,
    String? purchaseMethod,
    // 리뷰 설정
    String? reviewType,
    int? reviewTextLength,
    int? reviewImageCount,
    String? reviewKeywords,
    // 중복 방지 설정
    bool? preventProductDuplicate,
    bool? preventStoreDuplicate,
    int? duplicatePreventDays,
    // 비용 설정
    String? paymentMethod,
    int? totalCost,
  }) {
    return Campaign(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      companyId: companyId ?? this.companyId,
      productName: productName ?? this.productName,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      platform: platform ?? this.platform,
      campaignType: campaignType ?? this.campaignType,
      productPrice: productPrice ?? this.productPrice,
      campaignReward: campaignReward ?? this.campaignReward,
      applyStartDate: applyStartDate ?? this.applyStartDate,
      applyEndDate: applyEndDate ?? this.applyEndDate,
      reviewStartDate: reviewStartDate ?? this.reviewStartDate,
      reviewEndDate: reviewEndDate ?? this.reviewEndDate,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      // 상품 상세 정보
      keyword: keyword ?? this.keyword,
      option: option ?? this.option,
      quantity: quantity ?? this.quantity,
      seller: seller ?? this.seller,
      productNumber: productNumber ?? this.productNumber,
      purchaseMethod: purchaseMethod ?? this.purchaseMethod,
      // 리뷰 설정
      reviewType: reviewType ?? this.reviewType,
      reviewTextLength: reviewTextLength ?? this.reviewTextLength,
      reviewImageCount: reviewImageCount ?? this.reviewImageCount,
      reviewKeywords: reviewKeywords ?? this.reviewKeywords,
      // 중복 방지 설정
      preventProductDuplicate:
          preventProductDuplicate ?? this.preventProductDuplicate,
      preventStoreDuplicate:
          preventStoreDuplicate ?? this.preventStoreDuplicate,
      duplicatePreventDays: duplicatePreventDays ?? this.duplicatePreventDays,
      // 비용 설정
      paymentMethod: paymentMethod ?? this.paymentMethod,
      totalCost: totalCost ?? this.totalCost,
    );
  }
}

/// 캠페인 카테고리
///
/// DB 값 매핑:
/// - store -> 'store'
/// - press -> 'journalist' (DB에서는 'journalist' 사용)
/// - visit -> 'visit'
/// - all -> Flutter 전용 (DB에는 없음, 기본값으로 'store' 사용)
enum CampaignCategory { all, store, press, visit }

enum CampaignStatus { active, inactive }
