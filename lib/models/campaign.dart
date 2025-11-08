class Campaign {
  final String id;
  final String title;
  final String description;
  final String productImageUrl;
  final String platform;
  final String platformLogoUrl;
  final CampaignCategory campaignType;
  final int productPrice;
  final int reviewReward;
  final DateTime? startDate;
  final DateTime? endDate;
  final int currentParticipants;
  final int? maxParticipants;
  final CampaignStatus status;
  final DateTime createdAt;

  // 템플릿 기능을 위한 새로운 필드들
  final bool isTemplate;
  final String? templateName;
  final DateTime? lastUsedAt;
  final int usageCount;

  // 상품 상세 정보
  final String? keyword;
  final String? option;
  final int quantity;
  final String? seller;
  final String? productNumber;
  final int paymentAmount;
  final String purchaseMethod;
  final String? productDescription;
  
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
    required this.productImageUrl,
    required this.platform,
    required this.platformLogoUrl,
    required this.campaignType,
    required this.productPrice,
    required this.reviewReward,
    this.startDate,
    this.endDate,
    this.currentParticipants = 0,
    this.maxParticipants,
    this.status = CampaignStatus.active,
    required this.createdAt,
    // 템플릿 필드들
    this.isTemplate = false,
    this.templateName,
    this.lastUsedAt,
    this.usageCount = 0,
    // 상품 상세 정보
    this.keyword,
    this.option,
    this.quantity = 1,
    this.seller,
    this.productNumber,
    this.paymentAmount = 0,
    this.purchaseMethod = 'mobile',
    this.productDescription,
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
    return Campaign(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      productImageUrl: json['product_image_url'] ?? '',
      platform: json['platform'] ?? '',
      platformLogoUrl: json['platform_logo_url'] ?? '',
      campaignType: CampaignCategory.values.firstWhere(
        (e) => e.name == (json['campaign_type'] ?? 'all'),
        orElse: () => CampaignCategory.all,
      ),
      productPrice: json['product_price'] ?? 0,
      reviewReward: json['review_reward'] ?? 0,
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
      // 템플릿 필드들
      isTemplate: json['is_template'] ?? false,
      templateName: json['template_name'],
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'])
          : null,
      usageCount: json['usage_count'] ?? 0,
      // 상품 상세 정보
      keyword: json['keyword'],
      option: json['option'],
      quantity: json['quantity'] ?? 1,
      seller: json['seller'],
      productNumber: json['product_number'],
      paymentAmount: json['payment_amount'] ?? 0,
      purchaseMethod: json['purchase_method'] ?? 'mobile',
      productDescription: json['product_description'],
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
    return {
      'id': id,
      'title': title,
      'description': description,
      'product_image_url': productImageUrl,
      'platform': platform,
      'platform_logo_url': platformLogoUrl,
      'campaign_type': campaignType.name,
      'product_price': productPrice,
      'review_reward': reviewReward,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'current_participants': currentParticipants,
      'max_participants': maxParticipants,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      // 템플릿 필드들
      'is_template': isTemplate,
      'template_name': templateName,
      'last_used_at': lastUsedAt?.toIso8601String(),
      'usage_count': usageCount,
      // 상품 상세 정보
      'keyword': keyword,
      'option': option,
      'quantity': quantity,
      'seller': seller,
      'product_number': productNumber,
      'payment_amount': paymentAmount,
      'purchase_method': purchaseMethod,
      'product_description': productDescription,
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
    String? productImageUrl,
    String? platform,
    String? platformLogoUrl,
    CampaignCategory? campaignType,
    int? productPrice,
    int? reviewReward,
    DateTime? startDate,
    DateTime? endDate,
    int? currentParticipants,
    int? maxParticipants,
    CampaignStatus? status,
    DateTime? createdAt,
    // 템플릿 필드들
    bool? isTemplate,
    String? templateName,
    DateTime? lastUsedAt,
    int? usageCount,
    // 상품 상세 정보
    String? keyword,
    String? option,
    int? quantity,
    String? seller,
    String? productNumber,
    int? paymentAmount,
    String? purchaseMethod,
    String? productDescription,
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
      productImageUrl: productImageUrl ?? this.productImageUrl,
      platform: platform ?? this.platform,
      platformLogoUrl: platformLogoUrl ?? this.platformLogoUrl,
      campaignType: campaignType ?? this.campaignType,
      productPrice: productPrice ?? this.productPrice,
      reviewReward: reviewReward ?? this.reviewReward,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      // 템플릿 필드들
      isTemplate: isTemplate ?? this.isTemplate,
      templateName: templateName ?? this.templateName,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      usageCount: usageCount ?? this.usageCount,
      // 상품 상세 정보
      keyword: keyword ?? this.keyword,
      option: option ?? this.option,
      quantity: quantity ?? this.quantity,
      seller: seller ?? this.seller,
      productNumber: productNumber ?? this.productNumber,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      purchaseMethod: purchaseMethod ?? this.purchaseMethod,
      productDescription: productDescription ?? this.productDescription,
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

enum CampaignCategory { all, reviewer, press, visit }

enum CampaignStatus { active, completed, upcoming }
