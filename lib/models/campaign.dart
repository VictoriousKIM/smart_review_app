/// campaigns 테이블 모델 (Supabase 스키마 기반)
class Campaign {
  final String id;
  final String title;
  final String description;
  final String companyId; // DB에 있는 필드 추가
  final String? productName; // DB에 있는 필드 추가
  final String productImageUrl;
  final String platform;
  final CampaignCategory campaignType;
  final int? productPrice;
  final int reviewCost; // DB에 있는 필드 (review_cost)
  final int? reviewReward;
  final DateTime? startDate;
  final DateTime? endDate;
  final int currentParticipants;
  final int? maxParticipants;
  final CampaignStatus status;
  final DateTime createdAt;
  final String? userId; // DB에 있는 필드 추가

  // 상품 상세 정보
  final String? keyword;
  final String? option;
  final int quantity;
  final String? seller;
  final String? productNumber;
  final String purchaseMethod;

  // 리뷰 설정
  final String reviewType; // 'star_only', 'star_text', 'star_text_image'
  final int reviewTextLength;
  final int reviewImageCount;

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
    this.productName,
    required this.productImageUrl,
    required this.platform,
    required this.campaignType,
    this.productPrice,
    required this.reviewCost,
    this.reviewReward,
    this.startDate,
    this.endDate,
    this.currentParticipants = 0,
    this.maxParticipants,
    this.status = CampaignStatus.active,
    required this.createdAt,
    this.userId,
    // 상품 상세 정보
    this.keyword,
    this.option,
    this.quantity = 1,
    this.seller,
    this.productNumber,
    this.purchaseMethod = 'mobile',
    // 리뷰 설정
    this.reviewType = 'star_only',
    this.reviewTextLength = 100,
    this.reviewImageCount = 0,
    // 중복 방지 설정
    this.preventProductDuplicate = false,
    this.preventStoreDuplicate = false,
    this.duplicatePreventDays = 0,
    // 비용 설정
    this.paymentMethod = 'platform',
    this.totalCost = 0,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    // DB의 campaign_type 값 매핑: 'journalist' -> 'press', 'reviewer' -> 'reviewer', 'visit' -> 'visit'
    CampaignCategory mapCampaignType(String? type) {
      switch (type) {
        case 'journalist':
          return CampaignCategory.press;
        case 'reviewer':
          return CampaignCategory.reviewer;
        case 'visit':
          return CampaignCategory.visit;
        default:
          return CampaignCategory.reviewer; // 기본값
      }
    }

    return Campaign(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      companyId: json['company_id'] ?? '',
      productName: json['product_name'],
      productImageUrl: json['product_image_url'] ?? '',
      platform: json['platform'] ?? '',
      campaignType: mapCampaignType(json['campaign_type']),
      productPrice: json['product_price'],
      reviewCost: json['review_cost'] ?? 0,
      reviewReward: json['review_reward'],
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : null,
      currentParticipants: json['current_participants'] ?? 0,
      maxParticipants: json['max_participants'],
      status: CampaignStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'active'),
        orElse: () => CampaignStatus.active,
      ),
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      userId: json['user_id'],
      // 상품 상세 정보
      keyword: json['keyword'],
      option: json['option'],
      quantity: json['quantity'] ?? 1,
      seller: json['seller'],
      productNumber: json['product_number'],
      purchaseMethod: json['purchase_method'] ?? 'mobile',
      // 리뷰 설정
      reviewType: json['review_type'] ?? 'star_only',
      reviewTextLength: json['review_text_length'] ?? 100,
      reviewImageCount: json['review_image_count'] ?? 0,
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
        case CampaignCategory.reviewer:
          return 'reviewer';
        case CampaignCategory.visit:
          return 'visit';
        case CampaignCategory.all:
          return 'reviewer'; // 기본값
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
      'review_cost': reviewCost,
      'review_reward': reviewReward,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'current_participants': currentParticipants,
      'max_participants': maxParticipants,
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
    int? reviewCost,
    int? reviewReward,
    DateTime? startDate,
    DateTime? endDate,
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
      reviewCost: reviewCost ?? this.reviewCost,
      reviewReward: reviewReward ?? this.reviewReward,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
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
/// - reviewer -> 'reviewer'
/// - press -> 'journalist' (DB에서는 'journalist' 사용)
/// - visit -> 'visit'
/// - all -> Flutter 전용 (DB에는 없음, 기본값으로 'reviewer' 사용)
enum CampaignCategory { all, reviewer, press, visit }

enum CampaignStatus { active, completed, upcoming }
