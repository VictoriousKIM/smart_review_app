// ==================== 지갑 모델 ====================

/// 개인 지갑
class UserWallet {
  final String id;
  final String userId;
  final int currentPoints;
  final String? withdrawBankName;
  final String? withdrawAccountNumber;
  final String? withdrawAccountHolder;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserWallet({
    required this.id,
    required this.userId,
    required this.currentPoints,
    this.withdrawBankName,
    this.withdrawAccountNumber,
    this.withdrawAccountHolder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserWallet.fromJson(Map<String, dynamic> json) {
    return UserWallet(
      id: json['wallet_id'] ?? json['id'] ?? '',
      userId: json['user_id'] ?? '',
      currentPoints: json['current_points'] ?? 0,
      withdrawBankName: json['withdraw_bank_name'],
      withdrawAccountNumber: json['withdraw_account_number'],
      withdrawAccountHolder: json['withdraw_account_holder'],
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
      'withdraw_bank_name': withdrawBankName,
      'withdraw_account_number': withdrawAccountNumber,
      'withdraw_account_holder': withdrawAccountHolder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserWallet copyWith({
    String? id,
    String? userId,
    int? currentPoints,
    String? withdrawBankName,
    String? withdrawAccountNumber,
    String? withdrawAccountHolder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserWallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      currentPoints: currentPoints ?? this.currentPoints,
      withdrawBankName: withdrawBankName ?? this.withdrawBankName,
      withdrawAccountNumber: withdrawAccountNumber ?? this.withdrawAccountNumber,
      withdrawAccountHolder: withdrawAccountHolder ?? this.withdrawAccountHolder,
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
  final String? withdrawBankName;
  final String? withdrawAccountNumber;
  final String? withdrawAccountHolder;

  CompanyWallet({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.currentPoints,
    required this.userRole,
    required this.status,
    this.withdrawBankName,
    this.withdrawAccountNumber,
    this.withdrawAccountHolder,
  });

  factory CompanyWallet.fromJson(Map<String, dynamic> json) {
    return CompanyWallet(
      id: json['wallet_id'] ?? json['id'] ?? '',
      companyId: json['company_id'] ?? '',
      companyName: json['company_name'] ?? '',
      currentPoints: json['current_points'] ?? 0,
      userRole: json['user_role'] ?? '',
      status: json['status'] ?? '',
      withdrawBankName: json['withdraw_bank_name'],
      withdrawAccountNumber: json['withdraw_account_number'],
      withdrawAccountHolder: json['withdraw_account_holder'],
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
      'withdraw_bank_name': withdrawBankName,
      'withdraw_account_number': withdrawAccountNumber,
      'withdraw_account_holder': withdrawAccountHolder,
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
    String? withdrawBankName,
    String? withdrawAccountNumber,
    String? withdrawAccountHolder,
  }) {
    return CompanyWallet(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      currentPoints: currentPoints ?? this.currentPoints,
      userRole: userRole ?? this.userRole,
      status: status ?? this.status,
      withdrawBankName: withdrawBankName ?? this.withdrawBankName,
      withdrawAccountNumber: withdrawAccountNumber ?? this.withdrawAccountNumber,
      withdrawAccountHolder: withdrawAccountHolder ?? this.withdrawAccountHolder,
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

// ==================== 통합 포인트 거래 모델 ====================

/// 통합 포인트 거래 모델 (캠페인 + 현금 거래 모두 포함)
class UnifiedPointTransaction {
  final String id;
  final String? userId;
  final String? companyId;
  final String? walletId;
  final String transactionType;
  final int amount;
  final String? description;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final String? campaignId;
  final String? createdByUserId;
  final String status;
  final String? approvedBy;
  final String? rejectedBy;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  
  // 거래 카테고리
  final String transactionCategory; // 'campaign' or 'cash'
  
  // 현금 거래 전용 필드
  final double? cashAmount;
  final String? paymentMethod;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolder;

  UnifiedPointTransaction({
    required this.id,
    this.userId,
    this.companyId,
    this.walletId,
    required this.transactionType,
    required this.amount,
    this.description,
    this.relatedEntityType,
    this.relatedEntityId,
    this.campaignId,
    this.createdByUserId,
    required this.status,
    this.approvedBy,
    this.rejectedBy,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    required this.transactionCategory,
    this.cashAmount,
    this.paymentMethod,
    this.bankName,
    this.accountNumber,
    this.accountHolder,
  });

  // 편의 getter
  bool get isUserTransaction => userId != null;
  bool get isCompanyTransaction => companyId != null;
  bool get isCampaignTransaction => transactionCategory == 'campaign';
  bool get isCashTransaction => transactionCategory == 'cash';
  bool get isEarn => transactionType == 'earn';
  bool get isSpend => transactionType == 'spend';
  bool get isDeposit => transactionType == 'deposit';
  bool get isWithdraw => transactionType == 'withdraw';
  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  
  factory UnifiedPointTransaction.fromJson(Map<String, dynamic> json) {
    return UnifiedPointTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      companyId: json['company_id'] as String?,
      walletId: json['wallet_id'] as String?,
      transactionType: json['transaction_type'] as String,
      amount: json['amount'] as int,
      description: json['description'] as String?,
      relatedEntityType: json['related_entity_type'] as String?,
      relatedEntityId: json['related_entity_id'] as String?,
      campaignId: json['campaign_id'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      status: json['status'] as String,
      approvedBy: json['approved_by'] as String?,
      rejectedBy: json['rejected_by'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'] as String) 
          : null,
      transactionCategory: json['transaction_category'] as String,
      cashAmount: json['cash_amount'] != null 
          ? (json['cash_amount'] as num).toDouble() 
          : null,
      paymentMethod: json['payment_method'] as String?,
      bankName: json['bank_name'] as String?,
      accountNumber: json['account_number'] as String?,
      accountHolder: json['account_holder'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'company_id': companyId,
      'wallet_id': walletId,
      'transaction_type': transactionType,
      'amount': amount,
      'description': description,
      'related_entity_type': relatedEntityType,
      'related_entity_id': relatedEntityId,
      'campaign_id': campaignId,
      'created_by_user_id': createdByUserId,
      'status': status,
      'approved_by': approvedBy,
      'rejected_by': rejectedBy,
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'transaction_category': transactionCategory,
      'cash_amount': cashAmount,
      'payment_method': paymentMethod,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_holder': accountHolder,
    };
  }

  String get transactionTypeLabel {
    if (isCampaignTransaction) {
      switch (transactionType) {
        case 'earn':
          return '적립';
        case 'spend':
          return '사용';
        default:
          return transactionType;
      }
    } else {
      switch (transactionType) {
        case 'deposit':
          return '입금';
        case 'withdraw':
          return '출금';
        default:
          return transactionType;
      }
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return '대기';
      case 'approved':
        return '승인';
      case 'rejected':
        return '거절';
      case 'completed':
        return '완료';
      case 'cancelled':
        return '취소';
      default:
        return status;
    }
  }

  String get amountFormatted {
    return '${amount > 0 ? '+' : ''}$amount P';
  }

  // UserPointLog로 변환 (하위 호환성)
  UserPointLog toUserPointLog() {
    return UserPointLog(
      id: id,
      transactionType: transactionType,
      amount: amount,
      description: description,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId ?? campaignId,
      createdAt: createdAt,
    );
  }
}

