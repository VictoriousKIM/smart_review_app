// ==================== 지갑 모델 ====================

/// 개인 지갑
class UserWallet {
  final String id;
  final String userId;
  final int currentPoints;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserWallet({
    required this.id,
    required this.userId,
    required this.currentPoints,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserWallet.fromJson(Map<String, dynamic> json) {
    return UserWallet(
      id: json['wallet_id'] ?? json['id'] ?? '',
      userId: json['user_id'] ?? '',
      currentPoints: json['current_points'] ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'current_points': currentPoints,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserWallet copyWith({
    String? id,
    String? userId,
    int? currentPoints,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserWallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      currentPoints: currentPoints ?? this.currentPoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 회사 지갑
class CompanyWallet {
  final String id;
  final String companyId;
  final String companyName;
  final int currentPoints;
  final String userRole;
  final String status;

  CompanyWallet({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.currentPoints,
    required this.userRole,
    required this.status,
  });

  factory CompanyWallet.fromJson(Map<String, dynamic> json) {
    return CompanyWallet(
      id: json['wallet_id'] ?? json['id'] ?? '',
      companyId: json['company_id'] ?? '',
      companyName: json['company_name'] ?? '',
      currentPoints: json['current_points'] ?? 0,
      userRole: json['user_role'] ?? '',
      status: json['status'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'company_name': companyName,
      'current_points': currentPoints,
      'user_role': userRole,
      'status': status,
    };
  }

  bool get isOwner => userRole == 'owner';
  bool get isManager => userRole == 'manager';
  bool get isActive => status == 'active';

  CompanyWallet copyWith({
    String? id,
    String? companyId,
    String? companyName,
    int? currentPoints,
    String? userRole,
    String? status,
  }) {
    return CompanyWallet(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      currentPoints: currentPoints ?? this.currentPoints,
      userRole: userRole ?? this.userRole,
      status: status ?? this.status,
    );
  }
}

// ==================== 포인트 로그 모델 ====================

/// 개인 포인트 로그
class UserPointLog {
  final String id;
  final String transactionType;
  final int amount;
  final String? description;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final DateTime createdAt;

  UserPointLog({
    required this.id,
    required this.transactionType,
    required this.amount,
    this.description,
    this.relatedEntityType,
    this.relatedEntityId,
    required this.createdAt,
  });

  factory UserPointLog.fromJson(Map<String, dynamic> json) {
    return UserPointLog(
      id: json['log_id'] ?? json['id'] ?? '',
      transactionType: json['transaction_type'] ?? '',
      amount: json['amount'] ?? 0,
      description: json['description'],
      relatedEntityType: json['related_entity_type'],
      relatedEntityId: json['related_entity_id'],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_type': transactionType,
      'amount': amount,
      'description': description,
      'related_entity_type': relatedEntityType,
      'related_entity_id': relatedEntityId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isEarning => amount > 0;
  bool get isSpending => amount < 0;

  String get transactionTypeLabel {
    switch (transactionType) {
      case 'earn':
        return '적립';
      case 'spend':
        return '사용';
      case 'refund':
        return '환불';
      case 'bonus':
        return '보너스';
      case 'penalty':
        return '차감';
      case 'transfer':
        return '이체';
      default:
        return transactionType;
    }
  }

  String get amountFormatted {
    return '${amount > 0 ? '+' : ''}$amount P';
  }
}

/// 회사 포인트 로그
class CompanyPointLog {
  final String id;
  final String transactionType;
  final int amount;
  final String? description;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final String? createdByUserId;
  final String? createdByUserName;
  final DateTime createdAt;

  CompanyPointLog({
    required this.id,
    required this.transactionType,
    required this.amount,
    this.description,
    this.relatedEntityType,
    this.relatedEntityId,
    this.createdByUserId,
    this.createdByUserName,
    required this.createdAt,
  });

  factory CompanyPointLog.fromJson(Map<String, dynamic> json) {
    return CompanyPointLog(
      id: json['log_id'] ?? json['id'] ?? '',
      transactionType: json['transaction_type'] ?? '',
      amount: json['amount'] ?? 0,
      description: json['description'],
      relatedEntityType: json['related_entity_type'],
      relatedEntityId: json['related_entity_id'],
      createdByUserId: json['created_by_user_id'],
      createdByUserName: json['created_by_user_name'],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_type': transactionType,
      'amount': amount,
      'description': description,
      'related_entity_type': relatedEntityType,
      'related_entity_id': relatedEntityId,
      'created_by_user_id': createdByUserId,
      'created_by_user_name': createdByUserName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isCharge => transactionType == 'charge' && amount > 0;
  bool get isSpend => transactionType == 'spend' && amount < 0;

  String get transactionTypeLabel {
    switch (transactionType) {
      case 'charge':
        return '충전';
      case 'spend':
        return '사용';
      case 'refund':
        return '환불';
      case 'bonus':
        return '보너스';
      case 'penalty':
        return '차감';
      case 'transfer':
        return '이체';
      default:
        return transactionType;
    }
  }

  String get amountFormatted {
    return '${amount > 0 ? '+' : ''}$amount P';
  }
}

