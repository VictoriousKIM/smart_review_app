class Review {
  final String id;
  final String campaignId;
  final String userId;
  final int rating;
  final String title;
  final String content;
  final List<String> images;
  final List<String> pros;
  final List<String> cons;
  final List<String> tags;
  final bool isVerified;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ReviewStatus status;
  final int rewardEarned;

  Review({
    required this.id,
    required this.campaignId,
    required this.userId,
    required this.rating,
    required this.title,
    required this.content,
    this.images = const [],
    this.pros = const [],
    this.cons = const [],
    this.tags = const [],
    this.isVerified = false,
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.status = ReviewStatus.pending,
    this.rewardEarned = 0,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] ?? '',
      campaignId: json['campaign_id'] ?? json['campaignId'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      rating: json['rating'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      pros: List<String>.from(json['pros'] ?? []),
      cons: List<String>.from(json['cons'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      isVerified: json['is_verified'] ?? json['isVerified'] ?? false,
      likeCount: json['like_count'] ?? json['likeCount'] ?? 0,
      commentCount: json['comment_count'] ?? json['commentCount'] ?? 0,
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
      status: ReviewStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'pending'),
        orElse: () => ReviewStatus.pending,
      ),
      rewardEarned: json['reward_earned'] ?? json['rewardEarned'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'user_id': userId,
      'rating': rating,
      'title': title,
      'content': content,
      'images': images,
      'pros': pros,
      'cons': cons,
      'tags': tags,
      'is_verified': isVerified,
      'like_count': likeCount,
      'comment_count': commentCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'status': status.name,
      'reward_earned': rewardEarned,
    };
  }

  Review copyWith({
    String? id,
    String? campaignId,
    String? userId,
    int? rating,
    String? title,
    String? content,
    List<String>? images,
    List<String>? pros,
    List<String>? cons,
    List<String>? tags,
    bool? isVerified,
    int? likeCount,
    int? commentCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    ReviewStatus? status,
    int? rewardEarned,
  }) {
    return Review(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      userId: userId ?? this.userId,
      rating: rating ?? this.rating,
      title: title ?? this.title,
      content: content ?? this.content,
      images: images ?? this.images,
      pros: pros ?? this.pros,
      cons: cons ?? this.cons,
      tags: tags ?? this.tags,
      isVerified: isVerified ?? this.isVerified,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      rewardEarned: rewardEarned ?? this.rewardEarned,
    );
  }
}

enum ReviewStatus { pending, approved, rejected }

class Comment {
  final String id;
  final String reviewId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? parentId;
  final int likeCount;

  Comment({
    required this.id,
    required this.reviewId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.likeCount = 0,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? '',
      reviewId: json['review_id'] ?? json['reviewId'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      content: json['content'] ?? '',
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
      parentId: json['parent_id'] ?? json['parentId'],
      likeCount: json['like_count'] ?? json['likeCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'review_id': reviewId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'parent_id': parentId,
      'like_count': likeCount,
    };
  }
}
