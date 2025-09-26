class Campaign {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String brand;
  final CampaignCategory category;
  final CampaignType type;
  final Reward reward;
  final DateTime deadline;
  final int participantCount;
  final int? maxParticipants;
  final CampaignStatus status;
  final List<String> requirements;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Campaign({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.brand,
    required this.category,
    required this.type,
    required this.reward,
    required this.deadline,
    this.participantCount = 0,
    this.maxParticipants,
    this.status = CampaignStatus.active,
    this.requirements = const [],
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? '',
      brand: json['brand'] ?? '',
      category: CampaignCategory.values.firstWhere(
        (e) => e.name == (json['category'] ?? 'product'),
        orElse: () => CampaignCategory.product,
      ),
      type: CampaignType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'ongoing'),
        orElse: () => CampaignType.ongoing,
      ),
      reward: Reward.fromJson(json['reward'] ?? {}),
      deadline: DateTime.parse(
        json['deadline'] ??
            json['end_date'] ??
            DateTime.now().toIso8601String(),
      ),
      participantCount:
          json['participant_count'] ?? json['participantCount'] ?? 0,
      maxParticipants: json['max_participants'] ?? json['maxParticipants'],
      status: CampaignStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'active'),
        orElse: () => CampaignStatus.active,
      ),
      requirements: List<String>.from(json['requirements'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(
        json['created_at'] ??
            json['createdAt'] ??
            DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ??
            json['updatedAt'] ??
            DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'brand': brand,
      'category': category.name,
      'type': type.name,
      'reward': reward.toJson(),
      'deadline': deadline.toIso8601String(),
      'participant_count': participantCount,
      'max_participants': maxParticipants,
      'status': status.name,
      'requirements': requirements,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Campaign copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? brand,
    CampaignCategory? category,
    CampaignType? type,
    Reward? reward,
    DateTime? deadline,
    int? participantCount,
    int? maxParticipants,
    CampaignStatus? status,
    List<String>? requirements,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Campaign(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      type: type ?? this.type,
      reward: reward ?? this.reward,
      deadline: deadline ?? this.deadline,
      participantCount: participantCount ?? this.participantCount,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      status: status ?? this.status,
      requirements: requirements ?? this.requirements,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum CampaignCategory { product, place, service }

enum CampaignType { popular, new_, ongoing }

enum CampaignStatus { active, completed, upcoming }

class Reward {
  final int points;
  final RewardType type;
  final String description;

  Reward({required this.points, required this.type, required this.description});

  factory Reward.fromJson(Map<String, dynamic> json) {
    return Reward(
      points: json['points'] ?? 0,
      type: RewardType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'points'),
        orElse: () => RewardType.points,
      ),
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'points': points, 'type': type.name, 'description': description};
  }
}

enum RewardType { points, product, coupon }
