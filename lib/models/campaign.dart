class Campaign {
  final String id;
  final String title;
  final String description;
  final String productImageUrl;
  final String platform;
  final String platformLogoUrl;
  final CampaignCategory category;
  final CampaignType type;
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

  Campaign({
    required this.id,
    required this.title,
    required this.description,
    required this.productImageUrl,
    required this.platform,
    required this.platformLogoUrl,
    required this.category,
    required this.type,
    required this.productPrice,
    required this.reviewReward,
    this.startDate,
    this.endDate,
    this.currentParticipants = 0,
    this.maxParticipants,
    this.status = CampaignStatus.active,
    required this.createdAt,
    // 새로운 필드들의 기본값 설정
    this.isTemplate = false,
    this.templateName,
    this.lastUsedAt,
    this.usageCount = 0,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      productImageUrl: json['product_image_url'] ?? '',
      platform: json['platform'] ?? '',
      platformLogoUrl: json['platform_logo_url'] ?? '',
      category: CampaignCategory.values.firstWhere(
        (e) => e.name == (json['category'] ?? 'all'),
        orElse: () => CampaignCategory.all,
      ),
      type: CampaignType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'reviewer'),
        orElse: () => CampaignType.reviewer,
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
      // 새로운 필드들 처리 (안전한 기본값 설정)
      isTemplate: json['is_template'] ?? false,
      templateName: json['template_name'],
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'])
          : null,
      usageCount: json['usage_count'] ?? 0,
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
      'category': category.name,
      'type': type.name,
      'product_price': productPrice,
      'review_reward': reviewReward,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'current_participants': currentParticipants,
      'max_participants': maxParticipants,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      // 새로운 필드들 추가
      'is_template': isTemplate,
      'template_name': templateName,
      'last_used_at': lastUsedAt?.toIso8601String(),
      'usage_count': usageCount,
    };
  }

  Campaign copyWith({
    String? id,
    String? title,
    String? description,
    String? productImageUrl,
    String? platform,
    String? platformLogoUrl,
    CampaignCategory? category,
    CampaignType? type,
    int? productPrice,
    int? reviewReward,
    DateTime? startDate,
    DateTime? endDate,
    int? currentParticipants,
    int? maxParticipants,
    CampaignStatus? status,
    DateTime? createdAt,
    // 새로운 필드들 추가
    bool? isTemplate,
    String? templateName,
    DateTime? lastUsedAt,
    int? usageCount,
  }) {
    return Campaign(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      platform: platform ?? this.platform,
      platformLogoUrl: platformLogoUrl ?? this.platformLogoUrl,
      category: category ?? this.category,
      type: type ?? this.type,
      productPrice: productPrice ?? this.productPrice,
      reviewReward: reviewReward ?? this.reviewReward,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      // 새로운 필드들 처리
      isTemplate: isTemplate ?? this.isTemplate,
      templateName: templateName ?? this.templateName,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}

enum CampaignCategory { all, reviewer, press, visit }

enum CampaignType { reviewer, press, visit }

enum CampaignStatus { active, completed, upcoming }
