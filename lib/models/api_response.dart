class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? message;

  ApiResponse({required this.success, this.data, this.error, this.message});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'],
      error: json['error'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data,
      'error': error,
      'message': message,
    };
  }
}

class Pagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      total: json['total'] ?? 0,
      totalPages: json['total_pages'] ?? json['totalPages'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'limit': limit,
      'total': total,
      'total_pages': totalPages,
    };
  }
}

class SearchFilters {
  final String? category;
  final String? type;
  final int? rating;
  final DateRange? dateRange;
  final List<String>? keywords;
  final String? sortBy;

  SearchFilters({
    this.category,
    this.type,
    this.rating,
    this.dateRange,
    this.keywords,
    this.sortBy,
  });

  factory SearchFilters.fromJson(Map<String, dynamic> json) {
    return SearchFilters(
      category: json['category'],
      type: json['type'],
      rating: json['rating'],
      dateRange: json['dateRange'] != null
          ? DateRange.fromJson(json['dateRange'])
          : null,
      keywords: List<String>.from(json['keywords'] ?? []),
      sortBy: json['sortBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'type': type,
      'rating': rating,
      'dateRange': dateRange?.toJson(),
      'keywords': keywords,
      'sortBy': sortBy,
    };
  }
}

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});

  factory DateRange.fromJson(Map<String, dynamic> json) {
    return DateRange(
      start: DateTime.parse(json['start']),
      end: DateTime.parse(json['end']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'start': start.toIso8601String(), 'end': end.toIso8601String()};
  }
}

class Notification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? actionUrl;

  Notification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    this.actionUrl,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'system'),
        orElse: () => NotificationType.system,
      ),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? json['isRead'] ?? false,
      createdAt: DateTime.parse(
        json['created_at'] ??
            json['createdAt'] ??
            DateTime.now().toIso8601String(),
      ),
      actionUrl: json['action_url'] ?? json['actionUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.name,
      'title': title,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'action_url': actionUrl,
    };
  }
}

enum NotificationType { reward, campaign, review, system }
