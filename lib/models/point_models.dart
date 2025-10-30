// 포인트 지갑 모델
class PointWallet {
  final String id;
  final String walletType; // 'reviewer' or 'company'
  final String userId;
  final int currentPoints;
  final DateTime createdAt;
  final DateTime updatedAt;

  PointWallet({
    required this.id,
    required this.walletType,
    required this.userId,
    required this.currentPoints,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PointWallet.fromJson(Map<String, dynamic> json) {
    return PointWallet(
      id: json['id'] ?? '',
      walletType: json['wallet_type'] ?? json['user_type'] ?? json['owner_type'] ?? '', // 호환성 유지
      userId: json['user_id'] ?? json['owner_id'] ?? '', // 호환성 유지
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
      'wallet_type': walletType,
      'user_id': userId,
      'current_points': currentPoints,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PointWallet copyWith({
    String? id,
    String? walletType,
    String? userId,
    int? currentPoints,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PointWallet(
      id: id ?? this.id,
      walletType: walletType ?? this.walletType,
      userId: userId ?? this.userId,
      currentPoints: currentPoints ?? this.currentPoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// 현금 거래 모델
class CashTransaction {
  final String id;
  final String walletId;
  final String transactionType; // 'CHARGE' or 'WITHDRAW'
  final int amount;
  final double? cashAmount;
  final String status; // 'PENDING', 'COMPLETED', 'FAILED'
  final String? paymentMethod;
  final String? requestedBy;
  final String? approvedBy;
  final DateTime createdAt;
  final DateTime? completedAt;

  CashTransaction({
    required this.id,
    required this.walletId,
    required this.transactionType,
    required this.amount,
    this.cashAmount,
    required this.status,
    this.paymentMethod,
    this.requestedBy,
    this.approvedBy,
    required this.createdAt,
    this.completedAt,
  });

  factory CashTransaction.fromJson(Map<String, dynamic> json) {
    return CashTransaction(
      id: json['id'] ?? '',
      walletId: json['wallet_id'] ?? '',
      transactionType: json['transaction_type'] ?? '',
      amount: json['amount'] ?? 0,
      cashAmount: json['cash_amount']?.toDouble(),
      status: json['status'] ?? 'PENDING',
      paymentMethod: json['payment_method'],
      requestedBy: json['requested_by'],
      approvedBy: json['approved_by'],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wallet_id': walletId,
      'transaction_type': transactionType,
      'amount': amount,
      'cash_amount': cashAmount,
      'status': status,
      'payment_method': paymentMethod,
      'requested_by': requestedBy,
      'approved_by': approvedBy,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}

// 포인트 로그 모델
class PointLog {
  final String id;
  final String walletId;
  final int amount;
  final int balanceAfter;
  final String type;
  final String? campaignId;
  final String? actedBy;
  final String? description;
  final DateTime createdAt;

  PointLog({
    required this.id,
    required this.walletId,
    required this.amount,
    required this.balanceAfter,
    required this.type,
    this.campaignId,
    this.actedBy,
    this.description,
    required this.createdAt,
  });

  factory PointLog.fromJson(Map<String, dynamic> json) {
    return PointLog(
      id: json['id'] ?? '',
      walletId: json['wallet_id'] ?? '',
      amount: json['amount'] ?? 0,
      balanceAfter: json['balance_after'] ?? 0,
      type: json['type'] ?? '',
      campaignId: json['campaign_id'],
      actedBy: json['acted_by'],
      description: json['description'],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wallet_id': walletId,
      'amount': amount,
      'balance_after': balanceAfter,
      'type': type,
      'campaign_id': campaignId,
      'acted_by': actedBy,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// 사용자 지갑 정보 모델
class UserWalletInfo {
  final String walletType; // 'PERSONAL' or 'COMPANY'
  final String walletId;
  final int points;
  final bool canWithdraw;

  UserWalletInfo({
    required this.walletType,
    required this.walletId,
    required this.points,
    required this.canWithdraw,
  });

  factory UserWalletInfo.fromJson(Map<String, dynamic> json) {
    return UserWalletInfo(
      walletType: json['wallet_type'] ?? '',
      walletId: json['wallet_id'] ?? '',
      points: json['points'] ?? 0,
      canWithdraw: json['can_withdraw'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wallet_type': walletType,
      'wallet_id': walletId,
      'points': points,
      'can_withdraw': canWithdraw,
    };
  }
}

// 포인트 이동 내역 모델
class TransferHistory {
  final DateTime transferDate;
  final String direction;
  final int amount;
  final String? description;

  TransferHistory({
    required this.transferDate,
    required this.direction,
    required this.amount,
    this.description,
  });

  factory TransferHistory.fromJson(Map<String, dynamic> json) {
    return TransferHistory(
      transferDate: DateTime.parse(
        json['transfer_date'] ?? DateTime.now().toIso8601String(),
      ),
      direction: json['direction'] ?? '',
      amount: json['amount'] ?? 0,
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transfer_date': transferDate.toIso8601String(),
      'direction': direction,
      'amount': amount,
      'description': description,
    };
  }
}

// 포인트 검증 결과 모델
class PointVerificationResult {
  final String walletId;
  final int storedPoints;
  final int calculatedPoints;
  final int difference;
  final bool isMatch;
  final DateTime? lastLogDate;

  PointVerificationResult({
    required this.walletId,
    required this.storedPoints,
    required this.calculatedPoints,
    required this.difference,
    required this.isMatch,
    this.lastLogDate,
  });

  factory PointVerificationResult.fromJson(Map<String, dynamic> json) {
    return PointVerificationResult(
      walletId: json['wallet_id'] ?? '',
      storedPoints: json['stored_points'] ?? 0,
      calculatedPoints: json['calculated_points'] ?? 0,
      difference: json['difference'] ?? 0,
      isMatch: json['is_match'] ?? false,
      lastLogDate: json['last_log_date'] != null
          ? DateTime.parse(json['last_log_date'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wallet_id': walletId,
      'stored_points': storedPoints,
      'calculated_points': calculatedPoints,
      'difference': difference,
      'is_match': isMatch,
      'last_log_date': lastLogDate?.toIso8601String(),
    };
  }
}

// 시스템 통계 모델
class SystemStats {
  final int totalWallets;
  final int totalPoints;
  final int userWallets;
  final int companyWallets;
  final int totalTransactions;
  final int pendingTransactions;
  final int completedTransactions;

  SystemStats({
    required this.totalWallets,
    required this.totalPoints,
    required this.userWallets,
    required this.companyWallets,
    required this.totalTransactions,
    required this.pendingTransactions,
    required this.completedTransactions,
  });

  factory SystemStats.fromJson(Map<String, dynamic> json) {
    return SystemStats(
      totalWallets: json['total_wallets'] ?? 0,
      totalPoints: json['total_points'] ?? 0,
      userWallets: json['user_wallets'] ?? 0,
      companyWallets: json['company_wallets'] ?? 0,
      totalTransactions: json['total_transactions'] ?? 0,
      pendingTransactions: json['pending_transactions'] ?? 0,
      completedTransactions: json['completed_transactions'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_wallets': totalWallets,
      'total_points': totalPoints,
      'user_wallets': userWallets,
      'company_wallets': companyWallets,
      'total_transactions': totalTransactions,
      'pending_transactions': pendingTransactions,
      'completed_transactions': completedTransactions,
    };
  }
}
